import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { DesktopSessionManager } from "@/features/auth/session";
import {
  DispatchStartControl,
  type FlightStartCommand,
} from "@/features/flight-dispatch/DispatchStartControl";
import {
  FlightStartError,
  type StartedFlight,
} from "@/features/flight-dispatch/flightStart";

const dispatchId = "96000000-0000-4000-8000-000000000001";
const otherDispatchId = "96000000-0000-4000-8000-000000000002";
const aircraftId = "96000000-0000-4000-8000-000000000003";
const firstKey = "96000000-0000-4000-8000-000000000004";
const secondKey = "96000000-0000-4000-8000-000000000005";

const flight: StartedFlight = {
  aircraftId,
  dispatchId,
  schemaVersion: 1,
  startedAt: "2026-08-06T10:30:00Z",
  state: "active",
};

const config: DesktopConnectionConfig = {
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
  target: "local",
};

function createSessionManager() {
  const manager = new DesktopSessionManager(config, vi.fn(), () => 1_000);
  manager.setSession({
    accessToken: "private-user-token",
    expiresAtEpochSeconds: 4_600,
    refreshToken: "private-refresh-token",
  });
  return manager;
}

function createBaseProps(sessionManager = createSessionManager()) {
  return {
    config,
    createIdempotencyKey: () => firstKey,
    dispatchId,
    flightLabel: "LFPG → LFBO",
    onAuthenticationRequired: vi.fn(),
    sessionManager,
  };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((promiseResolve) => {
    resolve = promiseResolve;
  });
  return { promise, resolve };
}

describe("DispatchStartControl", () => {
  it("n’exécute aucun appel au rendu", () => {
    const command = vi.fn<FlightStartCommand>(async () => flight);
    render(<DispatchStartControl {...createBaseProps()} command={command} />);

    expect(command).not.toHaveBeenCalled();
    expect(
      screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }),
    ).toBeEnabled();
  });

  it("démarre depuis la réponse serveur et bloque le double clic", async () => {
    const user = userEvent.setup();
    const pending = deferred<StartedFlight>();
    const command = vi.fn<FlightStartCommand>(() => pending.promise);
    const onFlightStarted = vi.fn();
    const { container } = render(
      <DispatchStartControl
        {...createBaseProps()}
        command={command}
        onFlightStarted={onFlightStarted}
      />,
    );

    await user.dblClick(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));

    expect(command).toHaveBeenCalledOnce();
    expect(screen.getByRole("button", { name: "Démarrage… · LFPG → LFBO" })).toBeDisabled();
    expect(screen.getByText("Démarrage sécurisé du vol.")).toBeInTheDocument();
    expect(onFlightStarted).not.toHaveBeenCalled();

    pending.resolve(flight);

    expect(await screen.findByText("Vol démarré le 06/08/2026 10:30 UTC.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Vol démarré · LFPG → LFBO" })).toBeDisabled();
    expect(onFlightStarted).toHaveBeenCalledOnce();
    expect(command.mock.calls[0]![0]).toEqual({
      accessToken: "private-user-token",
      anonKey: "public-anon-key",
      dispatchId,
      idempotencyKey: firstKey,
      signal: expect.any(AbortSignal),
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(container).not.toHaveTextContent("private-user-token");
    expect(container).not.toHaveTextContent("public-anon-key");
    expect(container).not.toHaveTextContent(dispatchId);
    expect(container).not.toHaveTextContent(aircraftId);
  });

  it("obtient le bearer au moment de la soumission, jamais avant", async () => {
    const user = userEvent.setup();
    const manager = createSessionManager();
    const getAccessToken = vi.spyOn(manager, "getAccessToken");
    const command = vi.fn<FlightStartCommand>(async () => flight);
    render(
      <DispatchStartControl {...createBaseProps(manager)} command={command} />,
    );

    expect(getAccessToken).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));

    expect(await screen.findByText(/Vol démarré le/)).toBeInTheDocument();
    expect(getAccessToken).toHaveBeenCalledOnce();
  });

  it("conserve la clé pour un retry après une réponse perdue, sans second départ", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightStartCommand>()
      .mockRejectedValueOnce(new FlightStartError("unavailable"))
      .mockResolvedValueOnce(flight);
    const createIdempotencyKey = vi
      .fn<() => string>()
      .mockReturnValueOnce(firstKey)
      .mockReturnValueOnce(secondKey);
    render(
      <DispatchStartControl
        {...createBaseProps()}
        command={command}
        createIdempotencyKey={createIdempotencyKey}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    await user.click(screen.getByRole("button", { name: "Réessayer · LFPG → LFBO" }));

    expect(await screen.findByText(/Vol démarré le/)).toBeInTheDocument();
    expect(command).toHaveBeenCalledTimes(2);
    expect(command.mock.calls[0]![0].idempotencyKey).toBe(firstKey);
    expect(command.mock.calls[1]![0].idempotencyKey).toBe(firstKey);
    expect(createIdempotencyKey).toHaveBeenCalledOnce();
  });

  it("crée une nouvelle clé quand le dispatch change", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightStartCommand>()
      .mockRejectedValueOnce(new FlightStartError("unavailable"))
      .mockImplementationOnce(async (commandInput) => ({
        ...flight,
        dispatchId: commandInput.dispatchId,
      }));
    const createIdempotencyKey = vi
      .fn<() => string>()
      .mockReturnValueOnce(firstKey)
      .mockReturnValueOnce(secondKey);
    const props = createBaseProps();
    const { rerender } = render(
      <DispatchStartControl
        {...props}
        command={command}
        createIdempotencyKey={createIdempotencyKey}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");

    rerender(
      <DispatchStartControl
        {...props}
        command={command}
        createIdempotencyKey={createIdempotencyKey}
        dispatchId={otherDispatchId}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Réessayer · LFPG → LFBO" }));

    expect(await screen.findByText(/Vol démarré le/)).toBeInTheDocument();
    expect(command).toHaveBeenCalledTimes(2);
    expect(command.mock.calls[0]![0].idempotencyKey).toBe(firstKey);
    expect(command.mock.calls[1]![0]).toMatchObject({
      dispatchId: otherDispatchId,
      idempotencyKey: secondKey,
    });
  });

  it("arme la mesure pour le vol démarré, après le départ seulement", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightStartCommand>(async () => flight);
    const armCommand = vi.fn(async (armedDispatchId: string) => ({
      contractVersion: "1",
      dispatchId: armedDispatchId,
    }));
    render(
      <DispatchStartControl
        {...createBaseProps()}
        armCommand={armCommand}
        command={command}
      />,
    );

    expect(armCommand).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));

    expect(await screen.findByText(/Vol démarré le/)).toBeInTheDocument();
    expect(armCommand).toHaveBeenCalledOnce();
    expect(armCommand).toHaveBeenCalledWith(dispatchId);
  });

  it("un armement en échec ne casse ni le départ ni son affichage", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightStartCommand>(async () => flight);
    const armCommand = vi.fn(async () => {
      throw new Error("shell-unavailable");
    });
    const { container } = render(
      <DispatchStartControl
        {...createBaseProps()}
        armCommand={armCommand}
        command={command}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));

    expect(await screen.findByText(/Vol démarré le/)).toBeInTheDocument();
    expect(armCommand).toHaveBeenCalledOnce();
    expect(container).not.toHaveTextContent("shell-unavailable");
  });

  it("n'arme rien quand le départ est refusé", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightStartCommand>(async () => {
      throw new FlightStartError("rejected");
    });
    const armCommand = vi.fn(async () => ({}));
    render(
      <DispatchStartControl
        {...createBaseProps()}
        armCommand={armCommand}
        command={command}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Le démarrage a été refusé.");
    expect(armCommand).not.toHaveBeenCalled();
  });

  it("efface la session et demande le retour au login sur refus Auth", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightStartCommand>(async () => {
      throw new FlightStartError("authentication-required");
    });
    const manager = createSessionManager();
    const onAuthenticationRequired = vi.fn();
    render(
      <DispatchStartControl
        {...createBaseProps(manager)}
        command={command}
        onAuthenticationRequired={onAuthenticationRequired}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));

    expect(onAuthenticationRequired).toHaveBeenCalledOnce();
    expect(manager.hasSession()).toBe(false);
    expect(screen.queryByText("private-user-token")).not.toBeInTheDocument();
  });

  it("présente un refus serveur sans détail technique et permet de réessayer", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightStartCommand>(async () => {
      throw new FlightStartError("rejected");
    });
    const { container } = render(
      <DispatchStartControl {...createBaseProps()} command={command} />,
    );

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Le démarrage a été refusé.");
    expect(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" })).toBeEnabled();
    expect(container).not.toHaveTextContent("rejected");
    expect(container).not.toHaveTextContent("FlightStartError");
  });

  it("présente une indisponibilité pour une réponse invalide", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightStartCommand>(async () => {
      throw new FlightStartError("invalid-response");
    });
    const { container } = render(
      <DispatchStartControl {...createBaseProps()} command={command} />,
    );

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Le service de démarrage est indisponible.",
    );
    expect(container).not.toHaveTextContent("invalid-response");
  });

  it("annule la commande lors du démontage", async () => {
    const user = userEvent.setup();
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn<FlightStartCommand>((commandInput) => {
      receivedSignal = commandInput.signal;
      return new Promise<StartedFlight>(() => undefined);
    });
    const { unmount } = render(
      <DispatchStartControl {...createBaseProps()} command={command} />,
    );

    await user.click(screen.getByRole("button", { name: "Démarrer le vol · LFPG → LFBO" }));
    unmount();

    expect(receivedSignal?.aborted).toBe(true);
  });
});
