import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { DesktopSessionManager } from "@/features/auth/session";
import {
  AircraftFleetPanel,
  type AircraftFleetCommand,
} from "@/features/aircraft-fleet/AircraftFleetPanel";
import {
  AircraftFleetError,
  type CompanyAircraft,
} from "@/features/aircraft-fleet/aircraftFleet";

const config: DesktopConnectionConfig = {
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
  target: "local",
};
const aircraft: CompanyAircraft = {
  acquiredAt: "2026-08-03T10:15:30Z",
  acquisitionKind: "purchase",
  aircraftTypeCode: "C172",
  displayName: "Cessna 172 Skyhawk",
  id: "97abcdef-0000-4000-8000-000000000001",
  schemaVersion: 1,
  serialNumber: "SYN-001",
};

function createSessionManager() {
  const manager = new DesktopSessionManager(config, vi.fn(), () => 1_000);
  manager.setSession({
    accessToken: "private-access-token",
    expiresAtEpochSeconds: 4_600,
    refreshToken: "private-refresh-token",
  });
  return manager;
}

describe("AircraftFleetPanel", () => {
  it("ne charge rien au rendu puis affiche uniquement la flotte validée", async () => {
    const user = userEvent.setup();
    const command = vi.fn<AircraftFleetCommand>(async () => [aircraft]);
    const { container } = render(
      <AircraftFleetPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    expect(command).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));

    expect(await screen.findByRole("list", { name: "Avions de la flotte" }))
      .toHaveTextContent("Cessna 172 Skyhawk");
    expect(container).toHaveTextContent("C172 · SYN-001");
    expect(command.mock.calls[0]![0]).toMatchObject({
      accessToken: "private-access-token",
      anonKey: "public-anon-key",
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(container).not.toHaveTextContent("private-access-token");
    expect(container).not.toHaveTextContent(aircraft.id);
  });

  it("rend explicitement une flotte vide", async () => {
    const user = userEvent.setup();
    render(
      <AircraftFleetPanel
        command={async () => []}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));
    expect(await screen.findByText("Votre flotte ne contient encore aucun avion."))
      .toBeInTheDocument();
  });

  it("expose la flotte chargée sans la charger au rendu", async () => {
    const user = userEvent.setup();
    const onFleetLoaded = vi.fn();
    render(
      <AircraftFleetPanel
        command={async () => [aircraft]}
        config={config}
        onAuthenticationRequired={vi.fn()}
        onFleetLoaded={onFleetLoaded}
        sessionManager={createSessionManager()}
      />,
    );

    expect(onFleetLoaded).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));

    await screen.findByRole("list", { name: "Avions de la flotte" });
    expect(onFleetLoaded).toHaveBeenCalledExactlyOnceWith([aircraft]);
  });

  it("n’expose aucune flotte quand la lecture échoue", async () => {
    const user = userEvent.setup();
    const onFleetLoaded = vi.fn();
    render(
      <AircraftFleetPanel
        command={async () => {
          throw new AircraftFleetError("unavailable");
        }}
        config={config}
        onAuthenticationRequired={vi.fn()}
        onFleetLoaded={onFleetLoaded}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    expect(onFleetLoaded).not.toHaveBeenCalled();
  });

  it("actualise une flotte déjà chargée quand la version change", async () => {
    const user = userEvent.setup();
    const command = vi.fn<AircraftFleetCommand>()
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([aircraft]);
    const { rerender } = render(
      <AircraftFleetPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        refreshVersion={0}
        sessionManager={createSessionManager()}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));
    await screen.findByText("Votre flotte ne contient encore aucun avion.");

    rerender(
      <AircraftFleetPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        refreshVersion={1}
        sessionManager={createSessionManager()}
      />,
    );

    expect(await screen.findByRole("list", { name: "Avions de la flotte" }))
      .toHaveTextContent("Cessna 172 Skyhawk");
    expect(command).toHaveBeenCalledTimes(2);
  });

  it("ne charge pas implicitement une flotte jamais ouverte après un signal de refresh", () => {
    const command = vi.fn<AircraftFleetCommand>(async () => [aircraft]);
    render(
      <AircraftFleetPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        refreshVersion={1}
        sessionManager={createSessionManager()}
      />,
    );
    expect(command).not.toHaveBeenCalled();
  });

  it("rejoue un refresh reçu pendant une lecture en cours", async () => {
    const user = userEvent.setup();
    let resolveFirst!: (fleet: CompanyAircraft[]) => void;
    const firstLoad = new Promise<CompanyAircraft[]>((resolve) => {
      resolveFirst = resolve;
    });
    const command = vi.fn<AircraftFleetCommand>()
      .mockImplementationOnce(async () => firstLoad)
      .mockResolvedValueOnce([aircraft]);
    const sessionManager = createSessionManager();
    const onAuthenticationRequired = vi.fn();
    const { rerender } = render(
      <AircraftFleetPanel
        command={command}
        config={config}
        onAuthenticationRequired={onAuthenticationRequired}
        refreshVersion={0}
        sessionManager={sessionManager}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));
    rerender(
      <AircraftFleetPanel
        command={command}
        config={config}
        onAuthenticationRequired={onAuthenticationRequired}
        refreshVersion={1}
        sessionManager={sessionManager}
      />,
    );
    resolveFirst([]);

    expect(await screen.findByRole("list", { name: "Avions de la flotte" }))
      .toHaveTextContent("Cessna 172 Skyhawk");
    expect(command).toHaveBeenCalledTimes(2);
  });

  it("bloque les chargements concurrents et permet un retry", async () => {
    const user = userEvent.setup();
    let resolve!: (fleet: CompanyAircraft[]) => void;
    const pending = new Promise<CompanyAircraft[]>((promiseResolve) => {
      resolve = promiseResolve;
    });
    const command = vi.fn<AircraftFleetCommand>()
      .mockRejectedValueOnce(new AircraftFleetError("unavailable"))
      .mockImplementationOnce(async () => pending);
    render(
      <AircraftFleetPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    await user.dblClick(screen.getByRole("button", { name: "Réessayer" }));
    expect(command).toHaveBeenCalledTimes(2);
    resolve([aircraft]);
    expect(await screen.findByRole("list")).toBeInTheDocument();
  });

  it("efface une session refusée et demande le retour au login", async () => {
    const user = userEvent.setup();
    const manager = createSessionManager();
    const onAuthenticationRequired = vi.fn();
    render(
      <AircraftFleetPanel
        command={async () => {
          throw new AircraftFleetError("authentication-required");
        }}
        config={config}
        onAuthenticationRequired={onAuthenticationRequired}
        sessionManager={manager}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));
    expect(onAuthenticationRequired).toHaveBeenCalledOnce();
    expect(manager.hasSession()).toBe(false);
  });

  it("annule la lecture au démontage", async () => {
    const user = userEvent.setup();
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn<AircraftFleetCommand>((commandInput) => {
      receivedSignal = commandInput.signal;
      return new Promise<CompanyAircraft[]>(() => undefined);
    });
    const { unmount } = render(
      <AircraftFleetPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));
    unmount();
    expect(receivedSignal?.aborted).toBe(true);
  });
});
