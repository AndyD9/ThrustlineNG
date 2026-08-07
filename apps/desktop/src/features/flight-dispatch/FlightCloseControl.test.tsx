import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { DesktopSessionManager } from "@/features/auth/session";
import type { ClosedFlight } from "@/features/flight-dispatch/flightClose";
import { FlightCloseError } from "@/features/flight-dispatch/flightClose";
import {
  FlightCloseControl,
  type FlightCloseCommand,
} from "@/features/flight-dispatch/FlightCloseControl";
import type { FlightSummaryCommand } from "@/features/flight-dispatch/FlightSummaryControl";
import type { FlightSummary } from "@/features/flight-dispatch/flightSummary";

const dispatchId = "97000000-0000-4000-8000-000000000001";
const aircraftId = "97000000-0000-4000-8000-000000000003";
const firstKey = "97000000-0000-4000-8000-000000000004";
const secondKey = "97000000-0000-4000-8000-000000000005";

const closedFlight: ClosedFlight = {
  aircraftId,
  blockMinutes: 42,
  closedAt: "2026-08-07T11:30:00Z",
  currencyCode: "EUR",
  dispatchId,
  distanceNm: 188.34,
  outcome: "completed",
  schemaVersion: 1,
  settledAmountMinor: 50201,
  state: "completed",
};

const measuredSummary: FlightSummary = {
  blockMinutes: 42,
  contractVersion: "1",
  state: "completed",
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
    flightLabel: "LFPG → EGLL",
    onAuthenticationRequired: vi.fn(),
    sessionManager,
    summaryCommand: vi.fn<FlightSummaryCommand>(async () => measuredSummary),
  };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((promiseResolve) => {
    resolve = promiseResolve;
  });
  return { promise, resolve };
}

describe("FlightCloseControl", () => {
  it("n’exécute aucun appel au rendu", () => {
    const command = vi.fn<FlightCloseCommand>(async () => closedFlight);
    const props = createBaseProps();
    render(<FlightCloseControl {...props} command={command} />);

    expect(command).not.toHaveBeenCalled();
    expect(props.summaryCommand).not.toHaveBeenCalled();
    expect(
      screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }),
    ).toBeEnabled();
  });

  it("clôture avec le temps de bloc mesuré et affiche le revenu depuis la réponse serveur", async () => {
    const user = userEvent.setup();
    const pending = deferred<ClosedFlight>();
    const command = vi.fn<FlightCloseCommand>(() => pending.promise);
    const onFlightClosed = vi.fn();
    const props = createBaseProps();
    const { container } = render(
      <FlightCloseControl {...props} command={command} onFlightClosed={onFlightClosed} />,
    );

    await user.dblClick(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }));

    expect(command).toHaveBeenCalledOnce();
    expect(props.summaryCommand).toHaveBeenCalledOnce();
    expect(screen.getByRole("button", { name: "Clôture… · LFPG → EGLL" })).toBeDisabled();
    expect(screen.getByText("Clôture sécurisée du vol.")).toBeInTheDocument();
    expect(onFlightClosed).not.toHaveBeenCalled();

    pending.resolve(closedFlight);

    expect(
      await screen.findByText(/Vol clôturé : revenu net 502,01[\s ]€, temps de bloc retenu 42 min\./),
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Vol clôturé · LFPG → EGLL" })).toBeDisabled();
    expect(onFlightClosed).toHaveBeenCalledOnce();
    expect(command.mock.calls[0]![0]).toEqual({
      accessToken: "private-user-token",
      anonKey: "public-anon-key",
      blockMinutes: 42,
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

  it("refuse de clôturer tant que le résumé mesuré n’est pas complet", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightCloseCommand>(async () => closedFlight);
    const props = createBaseProps();
    props.summaryCommand = vi.fn<FlightSummaryCommand>(async () => ({
      blockMinutes: null,
      contractVersion: "1",
      state: "running",
    }));
    render(<FlightCloseControl {...props} command={command} />);

    await user.click(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "La clôture attend le temps de bloc mesuré",
    );
    expect(command).not.toHaveBeenCalled();
    expect(
      screen.getByRole("button", { name: "Réessayer la clôture · LFPG → EGLL" }),
    ).toBeEnabled();
  });

  it("présente une indisponibilité quand le résumé mesuré est injoignable", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightCloseCommand>(async () => closedFlight);
    const props = createBaseProps();
    props.summaryCommand = vi.fn<FlightSummaryCommand>(async () => {
      throw new Error("bridge unreachable");
    });
    const { container } = render(<FlightCloseControl {...props} command={command} />);

    await user.click(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Le service de clôture est indisponible.",
    );
    expect(command).not.toHaveBeenCalled();
    expect(container).not.toHaveTextContent("bridge unreachable");
  });

  it("obtient le bearer au moment de la soumission, jamais avant", async () => {
    const user = userEvent.setup();
    const manager = createSessionManager();
    const getAccessToken = vi.spyOn(manager, "getAccessToken");
    const command = vi.fn<FlightCloseCommand>(async () => closedFlight);
    render(<FlightCloseControl {...createBaseProps(manager)} command={command} />);

    expect(getAccessToken).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }));

    expect(await screen.findByText(/revenu net/)).toBeInTheDocument();
    expect(getAccessToken).toHaveBeenCalledOnce();
  });

  it("conserve la clé pour un retry sur la même mesure, sans second règlement", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightCloseCommand>()
      .mockRejectedValueOnce(new FlightCloseError("unavailable"))
      .mockResolvedValueOnce(closedFlight);
    const createIdempotencyKey = vi
      .fn<() => string>()
      .mockReturnValueOnce(firstKey)
      .mockReturnValueOnce(secondKey);
    render(
      <FlightCloseControl
        {...createBaseProps()}
        command={command}
        createIdempotencyKey={createIdempotencyKey}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    await user.click(screen.getByRole("button", { name: "Réessayer la clôture · LFPG → EGLL" }));

    expect(await screen.findByText(/revenu net/)).toBeInTheDocument();
    expect(command).toHaveBeenCalledTimes(2);
    expect(command.mock.calls[0]![0].idempotencyKey).toBe(firstKey);
    expect(command.mock.calls[1]![0].idempotencyKey).toBe(firstKey);
    expect(createIdempotencyKey).toHaveBeenCalledOnce();
  });

  it("crée une nouvelle clé quand la mesure change entre deux tentatives", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightCloseCommand>()
      .mockRejectedValueOnce(new FlightCloseError("unavailable"))
      .mockImplementationOnce(async (commandInput) => ({
        ...closedFlight,
        blockMinutes: commandInput.blockMinutes,
      }));
    const createIdempotencyKey = vi
      .fn<() => string>()
      .mockReturnValueOnce(firstKey)
      .mockReturnValueOnce(secondKey);
    const props = createBaseProps();
    props.summaryCommand = vi.fn<FlightSummaryCommand>()
      .mockResolvedValueOnce(measuredSummary)
      .mockResolvedValueOnce({ ...measuredSummary, blockMinutes: 43 });
    render(
      <FlightCloseControl
        {...props}
        command={command}
        createIdempotencyKey={createIdempotencyKey}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    await user.click(screen.getByRole("button", { name: "Réessayer la clôture · LFPG → EGLL" }));

    expect(await screen.findByText(/revenu net/)).toBeInTheDocument();
    expect(command).toHaveBeenCalledTimes(2);
    expect(command.mock.calls[0]![0]).toMatchObject({ blockMinutes: 42, idempotencyKey: firstKey });
    expect(command.mock.calls[1]![0]).toMatchObject({ blockMinutes: 43, idempotencyKey: secondKey });
  });

  it("efface la session et demande le retour au login sur refus Auth", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightCloseCommand>(async () => {
      throw new FlightCloseError("authentication-required");
    });
    const manager = createSessionManager();
    const onAuthenticationRequired = vi.fn();
    render(
      <FlightCloseControl
        {...createBaseProps(manager)}
        command={command}
        onAuthenticationRequired={onAuthenticationRequired}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }));

    expect(onAuthenticationRequired).toHaveBeenCalledOnce();
    expect(manager.hasSession()).toBe(false);
    expect(screen.queryByText("private-user-token")).not.toBeInTheDocument();
  });

  it("présente un refus serveur sans détail technique et permet de réessayer", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightCloseCommand>(async () => {
      throw new FlightCloseError("rejected");
    });
    const { container } = render(
      <FlightCloseControl {...createBaseProps()} command={command} />,
    );

    await user.click(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("La clôture a été refusée.");
    expect(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" })).toBeEnabled();
    expect(container).not.toHaveTextContent("rejected");
    expect(container).not.toHaveTextContent("FlightCloseError");
  });

  it("annule la commande lors du démontage", async () => {
    const user = userEvent.setup();
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn<FlightCloseCommand>((commandInput) => {
      receivedSignal = commandInput.signal;
      return new Promise<ClosedFlight>(() => undefined);
    });
    const { unmount } = render(
      <FlightCloseControl {...createBaseProps()} command={command} />,
    );

    await user.click(screen.getByRole("button", { name: "Clôturer le vol · LFPG → EGLL" }));
    unmount();

    expect(receivedSignal?.aborted).toBe(true);
  });
});
