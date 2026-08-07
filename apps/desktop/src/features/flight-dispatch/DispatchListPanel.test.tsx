import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { DesktopSessionManager } from "@/features/auth/session";
import {
  type DispatchListCommand,
  DispatchListPanel,
} from "@/features/flight-dispatch/DispatchListPanel";
import {
  type CompanyDispatch,
  DispatchListError,
} from "@/features/flight-dispatch/dispatchList";
import type { FlightStartCommand } from "@/features/flight-dispatch/DispatchStartControl";
import type { FlightSummaryCommand } from "@/features/flight-dispatch/FlightSummaryControl";
import type { StartedFlight } from "@/features/flight-dispatch/flightStart";

const config: DesktopConnectionConfig = {
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
  target: "local",
};
const dispatch: CompanyDispatch = {
  aircraftId: "93000000-0000-4000-8000-000000000001",
  arrivalIcao: "LFBO",
  createdAt: "2026-08-04T09:15:30Z",
  departureIcao: "LFPG",
  id: "94000000-0000-4000-8000-000000000001",
  schemaVersion: 1,
  startedAt: null,
  state: "draft",
};
const activeDispatch: CompanyDispatch = {
  ...dispatch,
  aircraftId: "93000000-0000-4000-8000-000000000002",
  arrivalIcao: "EGLL",
  departureIcao: "LFPO",
  id: "94000000-0000-4000-8000-000000000002",
  startedAt: "2026-08-04T10:05:00Z",
  state: "active",
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

describe("DispatchListPanel", () => {
  it("ne lit rien au rendu puis affiche uniquement les dispatchs validés", async () => {
    const user = userEvent.setup();
    const command = vi.fn<DispatchListCommand>(async () => [dispatch, activeDispatch]);
    const { container } = render(
      <DispatchListPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    expect(command).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));

    const list = await screen.findByRole("list", { name: "Dispatchs de la compagnie" });
    expect(list).toHaveTextContent("LFPG → LFBO");
    expect(list).toHaveTextContent("Brouillon");
    expect(list).toHaveTextContent("LFPO → EGLL");
    expect(list).toHaveTextContent("En vol");
    expect(command).toHaveBeenCalledExactlyOnceWith({
      accessToken: "private-access-token",
      anonKey: "public-anon-key",
      signal: expect.any(AbortSignal),
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(container).not.toHaveTextContent("private-access-token");
    expect(container).not.toHaveTextContent(dispatch.id);
    expect(container).not.toHaveTextContent(dispatch.aircraftId);
  });

  it("rend explicitement une liste vide", async () => {
    const user = userEvent.setup();
    render(
      <DispatchListPanel
        command={async () => []}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    expect(await screen.findByText("Aucun dispatch n’est encore préparé.")).toBeInTheDocument();
    expect(screen.queryByRole("list")).not.toBeInTheDocument();
  });

  it("rend l’état de chargement puis l’échec sans rendu partiel", async () => {
    const user = userEvent.setup();
    let reject!: (error: unknown) => void;
    const pending = new Promise<CompanyDispatch[]>((_resolve, promiseReject) => {
      reject = promiseReject;
    });
    render(
      <DispatchListPanel
        command={async () => pending}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    expect(await screen.findByText("Chargement sécurisé des dispatchs.")).toBeInTheDocument();

    reject(new DispatchListError("invalid-response"));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    expect(screen.queryByRole("list")).not.toBeInTheDocument();
  });

  it("efface une session refusée et demande le retour au login", async () => {
    const user = userEvent.setup();
    const manager = createSessionManager();
    const onAuthenticationRequired = vi.fn();
    render(
      <DispatchListPanel
        command={async () => {
          throw new DispatchListError("authentication-required");
        }}
        config={config}
        onAuthenticationRequired={onAuthenticationRequired}
        sessionManager={manager}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    expect(onAuthenticationRequired).toHaveBeenCalledOnce();
    expect(manager.hasSession()).toBe(false);
    expect(screen.queryByRole("list")).not.toBeInTheDocument();
  });

  it("relit la source autoritaire quand la version d’actualisation change", async () => {
    const user = userEvent.setup();
    const command = vi.fn<DispatchListCommand>()
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([dispatch]);
    const sessionManager = createSessionManager();
    const { rerender } = render(
      <DispatchListPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        refreshVersion={0}
        sessionManager={sessionManager}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    await screen.findByText("Aucun dispatch n’est encore préparé.");

    rerender(
      <DispatchListPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        refreshVersion={1}
        sessionManager={sessionManager}
      />,
    );

    expect(await screen.findByRole("list", { name: "Dispatchs de la compagnie" }))
      .toHaveTextContent("LFPG → LFBO");
    expect(command).toHaveBeenCalledTimes(2);
  });

  it("rejoue un signal reçu pendant une lecture en cours", async () => {
    const user = userEvent.setup();
    let resolveFirst!: (dispatches: CompanyDispatch[]) => void;
    const firstLoad = new Promise<CompanyDispatch[]>((resolve) => {
      resolveFirst = resolve;
    });
    const command = vi.fn<DispatchListCommand>()
      .mockImplementationOnce(async () => firstLoad)
      .mockResolvedValueOnce([dispatch]);
    const sessionManager = createSessionManager();
    const { rerender } = render(
      <DispatchListPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        refreshVersion={0}
        sessionManager={sessionManager}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    rerender(
      <DispatchListPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        refreshVersion={1}
        sessionManager={sessionManager}
      />,
    );
    resolveFirst([]);

    expect(await screen.findByRole("list", { name: "Dispatchs de la compagnie" }))
      .toHaveTextContent("LFPG → LFBO");
    expect(command).toHaveBeenCalledTimes(2);
  });

  it("ne lit rien implicitement quand un signal arrive avant toute lecture", () => {
    const command = vi.fn<DispatchListCommand>(async () => [dispatch]);
    render(
      <DispatchListPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        refreshVersion={1}
        sessionManager={createSessionManager()}
      />,
    );
    expect(command).not.toHaveBeenCalled();
  });

  it("bloque les lectures concurrentes et permet un retry", async () => {
    const user = userEvent.setup();
    let resolve!: (dispatches: CompanyDispatch[]) => void;
    const pending = new Promise<CompanyDispatch[]>((promiseResolve) => {
      resolve = promiseResolve;
    });
    const command = vi.fn<DispatchListCommand>()
      .mockRejectedValueOnce(new DispatchListError("unavailable"))
      .mockImplementationOnce(async () => pending);
    render(
      <DispatchListPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    await user.dblClick(screen.getByRole("button", { name: "Réessayer" }));
    expect(command).toHaveBeenCalledTimes(2);
    resolve([dispatch]);
    expect(await screen.findByRole("list")).toBeInTheDocument();
  });

  it("propose le démarrage des seuls brouillons, sans appel au rendu", async () => {
    const user = userEvent.setup();
    const startCommand = vi.fn<FlightStartCommand>();
    render(
      <DispatchListPanel
        command={async () => [dispatch, activeDispatch]}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
        startCommand={startCommand}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    await screen.findByRole("list", { name: "Dispatchs de la compagnie" });

    expect(
      screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }),
    ).toBeEnabled();
    expect(
      screen.queryByRole("button", { name: /Démarrer le vol · LFPO → EGLL/ }),
    ).not.toBeInTheDocument();
    expect(startCommand).not.toHaveBeenCalled();
  });

  it("relit la source autoritaire après un départ réussi, sans état local du vol", async () => {
    const user = userEvent.setup();
    const command = vi.fn<DispatchListCommand>()
      .mockResolvedValueOnce([dispatch])
      .mockResolvedValueOnce([{ ...dispatch, startedAt: "2026-08-06T10:30:00Z", state: "active" }]);
    const startedFlight: StartedFlight = {
      aircraftId: dispatch.aircraftId,
      dispatchId: dispatch.id,
      schemaVersion: 1,
      startedAt: "2026-08-06T10:30:00Z",
      state: "active",
    };
    const startCommand = vi.fn<FlightStartCommand>(async () => startedFlight);
    render(
      <DispatchListPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
        startCommand={startCommand}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    await user.click(
      await screen.findByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }),
    );

    expect(await screen.findByText(/En vol/)).toBeInTheDocument();
    expect(screen.getByRole("list", { name: "Dispatchs de la compagnie" }))
      .toHaveTextContent("LFPG → LFBO");
    expect(screen.getByRole("list", { name: "Dispatchs de la compagnie" }))
      .toHaveTextContent(/départ .+ UTC/);
    expect(command).toHaveBeenCalledTimes(2);
    expect(startCommand).toHaveBeenCalledExactlyOnceWith({
      accessToken: "private-access-token",
      anonKey: "public-anon-key",
      dispatchId: dispatch.id,
      idempotencyKey: expect.stringMatching(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
      ),
      signal: expect.any(AbortSignal),
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(
      screen.queryByRole("button", { name: /Démarrer le vol/ }),
    ).not.toBeInTheDocument();
  });

  it("propose la mesure sur le vol actif et l'affiche seulement rattachée, sans appel au rendu", async () => {
    const user = userEvent.setup();
    const summaryCommand = vi.fn<FlightSummaryCommand>(async () => ({
      attachedDispatchId: activeDispatch.id,
      blockMinutes: 42,
      contractVersion: "1",
      state: "completed",
    }));
    render(
      <DispatchListPanel
        command={async () => [dispatch, activeDispatch]}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
        summaryCommand={summaryCommand}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    await screen.findByRole("list", { name: "Dispatchs de la compagnie" });

    expect(
      screen.getByRole("button", { name: "Afficher le temps de bloc · LFPO → EGLL" }),
    ).toBeEnabled();
    expect(
      screen.queryByRole("button", { name: /Afficher le temps de bloc · LFPG → LFBO/ }),
    ).not.toBeInTheDocument();
    expect(summaryCommand).not.toHaveBeenCalled();

    await user.click(
      screen.getByRole("button", { name: "Afficher le temps de bloc · LFPO → EGLL" }),
    );
    expect(await screen.findByText("Temps de bloc mesuré : 42 min.")).toBeInTheDocument();
    expect(summaryCommand).toHaveBeenCalledExactlyOnceWith();
  });

  it("n'attribue la mesure qu'au vol rattaché quand plusieurs vols sont actifs", async () => {
    const user = userEvent.setup();
    const secondActiveDispatch: CompanyDispatch = {
      ...activeDispatch,
      aircraftId: "93000000-0000-4000-8000-000000000003",
      arrivalIcao: "LFMN",
      departureIcao: "LFLL",
      id: "94000000-0000-4000-8000-000000000003",
    };
    const summaryCommand = vi.fn<FlightSummaryCommand>(async () => ({
      attachedDispatchId: activeDispatch.id,
      blockMinutes: 42,
      contractVersion: "1",
      state: "completed",
    }));
    render(
      <DispatchListPanel
        command={async () => [activeDispatch, secondActiveDispatch]}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
        summaryCommand={summaryCommand}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    await screen.findByRole("list", { name: "Dispatchs de la compagnie" });

    await user.click(
      screen.getByRole("button", { name: "Afficher le temps de bloc · LFLL → LFMN" }),
    );
    expect(await screen.findByText("Aucune mesure rattachée à ce vol.")).toBeInTheDocument();
    expect(screen.queryByText(/min\./)).not.toBeInTheDocument();

    await user.click(
      screen.getByRole("button", { name: "Afficher le temps de bloc · LFPO → EGLL" }),
    );
    expect(await screen.findByText("Temps de bloc mesuré : 42 min.")).toBeInTheDocument();
  });

  it("annule la lecture au démontage", async () => {
    const user = userEvent.setup();
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn<DispatchListCommand>((commandInput) => {
      receivedSignal = commandInput.signal;
      return new Promise<CompanyDispatch[]>(() => undefined);
    });
    const { unmount } = render(
      <DispatchListPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher mes dispatchs" }));
    unmount();
    expect(receivedSignal?.aborted).toBe(true);
  });
});
