import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { CompanyAircraft } from "@/features/aircraft-fleet/aircraftFleet";
import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { DesktopSessionManager } from "@/features/auth/session";
import { FlightDispatchPanel } from "@/features/flight-dispatch/FlightDispatchPanel";
import {
  type CreateDispatchDraftInput,
  type DispatchDraft,
  DispatchDraftError,
} from "@/features/flight-dispatch/flightDispatch";

const firstAircraftId = "92000000-0000-4000-8000-000000000001";
const secondAircraftId = "92000000-0000-4000-8000-000000000002";
const dispatchId = "92000000-0000-4000-8000-000000000003";
const firstKey = "92000000-0000-4000-8000-000000000004";
const secondKey = "92000000-0000-4000-8000-000000000005";

const fleet: CompanyAircraft[] = [
  {
    acquiredAt: "2026-08-01T08:00:00Z",
    acquisitionKind: "purchase",
    aircraftTypeCode: "C172",
    displayName: "Synthetic Cessna",
    id: firstAircraftId,
    schemaVersion: 1,
    serialNumber: "SYN-001",
  },
  {
    acquiredAt: "2026-08-02T08:00:00Z",
    acquisitionKind: "purchase",
    aircraftTypeCode: "DA40",
    displayName: "Synthetic Diamond",
    id: secondAircraftId,
    schemaVersion: 1,
    serialNumber: "SYN-002",
  },
];

const draft: DispatchDraft = {
  aircraftId: firstAircraftId,
  arrivalIcao: "LFBO",
  createdAt: "2026-08-04T09:15:00Z",
  departureIcao: "LFPG",
  dispatchId,
  schemaVersion: 1,
  state: "draft",
};

const config: DesktopConnectionConfig = {
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
  target: "local",
};

function createSessionManager(accessToken = "private-user-token") {
  const manager = new DesktopSessionManager(config, vi.fn(), () => 1_000);
  manager.setSession({
    accessToken,
    expiresAtEpochSeconds: 4_600,
    refreshToken: "private-refresh-token",
  });
  return manager;
}

function createBaseProps(sessionManager = createSessionManager()) {
  return {
    aircraft: fleet,
    config,
    createIdempotencyKey: () => firstKey,
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

async function fillIntention(
  user: ReturnType<typeof userEvent.setup>,
  options: { arrival?: string; departure?: string; aircraft?: string } = {},
) {
  await user.selectOptions(
    screen.getByLabelText("Avion"),
    options.aircraft ?? firstAircraftId,
  );
  await user.type(screen.getByLabelText("Aérodrome de départ (OACI)"), options.departure ?? "lfpg");
  await user.type(screen.getByLabelText("Aérodrome d’arrivée (OACI)"), options.arrival ?? "lfbo");
}

describe("FlightDispatchPanel", () => {
  it("n’exécute aucun appel avant une soumission explicite", async () => {
    const user = userEvent.setup();
    const command = vi.fn(async () => draft);
    render(<FlightDispatchPanel {...createBaseProps()} command={command} />);

    expect(command).not.toHaveBeenCalled();
    expect(
      screen.getByText("Choisissez un avion et deux aérodromes distincts pour préparer un vol."),
    ).toBeInTheDocument();

    await fillIntention(user);

    expect(command).not.toHaveBeenCalled();
  });

  it("limite la sélection aux avions chargés depuis la flotte", () => {
    render(<FlightDispatchPanel {...createBaseProps()} />);

    const select = screen.getByLabelText("Avion");

    expect(select.tagName).toBe("SELECT");
    expect(
      Array.from(select.querySelectorAll("option")).map((option) => option.value),
    ).toEqual(["", firstAircraftId, secondAircraftId]);
    expect(screen.queryByLabelText(/identifiant/i)).not.toBeInTheDocument();
  });

  it("crée un brouillon depuis la réponse serveur et bloque le double clic", async () => {
    const user = userEvent.setup();
    const pending = deferred<DispatchDraft>();
    const command = vi.fn((_input: CreateDispatchDraftInput) => pending.promise);
    const { container } = render(
      <FlightDispatchPanel {...createBaseProps()} command={command} />,
    );

    await fillIntention(user);
    await user.dblClick(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(command).toHaveBeenCalledOnce();
    expect(screen.getByRole("button", { name: "Préparation…" })).toBeDisabled();
    expect(screen.getByText("Préparation sécurisée du brouillon.")).toBeInTheDocument();

    pending.resolve(draft);

    expect(await screen.findByText(/Brouillon créé pour LFPG/)).toHaveTextContent(
      "Brouillon créé pour LFPG → LFBO, préparé le 04/08/2026 09:15 UTC.",
    );
    expect(screen.getByRole("button", { name: "Brouillon créé" })).toBeDisabled();
    expect(command.mock.calls[0]![0]).toEqual({
      accessToken: "private-user-token",
      aircraftId: firstAircraftId,
      anonKey: "public-anon-key",
      arrivalIcao: "LFBO",
      departureIcao: "LFPG",
      idempotencyKey: firstKey,
      signal: expect.any(AbortSignal),
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(container).not.toHaveTextContent("private-user-token");
    expect(container).not.toHaveTextContent("public-anon-key");
    expect(container).not.toHaveTextContent(dispatchId);
  });

  it("refuse une intention invalide sans obtenir de bearer ni appeler la commande", async () => {
    const user = userEvent.setup();
    const command = vi.fn(async () => draft);
    const manager = createSessionManager();
    const getAccessToken = vi.spyOn(manager, "getAccessToken");
    render(
      <FlightDispatchPanel {...createBaseProps(manager)} command={command} />,
    );

    await fillIntention(user, { arrival: "lfpg" });
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("La préparation a été refusée.");
    expect(command).not.toHaveBeenCalled();
    expect(getAccessToken).not.toHaveBeenCalled();
  });

  it("refuse une soumission sans avion sélectionné", async () => {
    const user = userEvent.setup();
    const command = vi.fn(async () => draft);
    render(<FlightDispatchPanel {...createBaseProps()} command={command} />);

    await user.type(screen.getByLabelText("Aérodrome de départ (OACI)"), "LFPG");
    await user.type(screen.getByLabelText("Aérodrome d’arrivée (OACI)"), "LFBO");
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("La préparation a été refusée.");
    expect(command).not.toHaveBeenCalled();
  });

  it("conserve la clé pour un retry de la même intention", async () => {
    const user = userEvent.setup();
    const command = vi
      .fn<(input: CreateDispatchDraftInput) => Promise<DispatchDraft>>()
      .mockRejectedValueOnce(new DispatchDraftError("unavailable"))
      .mockResolvedValueOnce(draft);
    const createIdempotencyKey = vi
      .fn<() => string>()
      .mockReturnValueOnce(firstKey)
      .mockReturnValueOnce(secondKey);
    render(
      <FlightDispatchPanel
        {...createBaseProps()}
        command={command}
        createIdempotencyKey={createIdempotencyKey}
      />,
    );

    await fillIntention(user);
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    await user.click(screen.getByRole("button", { name: "Réessayer" }));

    expect(await screen.findByText(/Brouillon créé pour LFPG/)).toBeInTheDocument();
    expect(command).toHaveBeenCalledTimes(2);
    expect(command.mock.calls[0]![0].idempotencyKey).toBe(firstKey);
    expect(command.mock.calls[1]![0].idempotencyKey).toBe(firstKey);
    expect(createIdempotencyKey).toHaveBeenCalledOnce();
  });

  it.each<[string, { aircraft?: string; arrival?: string }]>([
    ["l’avion", { aircraft: secondAircraftId }],
    ["un aérodrome", { arrival: "lfml" }],
  ])("crée une nouvelle clé quand %s change", async (_name, change) => {
    const user = userEvent.setup();
    const command = vi.fn(async (commandInput: CreateDispatchDraftInput) => ({
      ...draft,
      aircraftId: commandInput.aircraftId,
      arrivalIcao: commandInput.arrivalIcao,
    }));
    const createIdempotencyKey = vi
      .fn<() => string>()
      .mockReturnValueOnce(firstKey)
      .mockReturnValueOnce(secondKey);
    render(
      <FlightDispatchPanel
        {...createBaseProps()}
        command={command}
        createIdempotencyKey={createIdempotencyKey}
      />,
    );

    await fillIntention(user);
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));
    expect(await screen.findByText(/Brouillon créé pour LFPG/)).toBeInTheDocument();

    const nextArrival = change.arrival;
    if (nextArrival !== undefined) {
      await user.clear(screen.getByLabelText("Aérodrome d’arrivée (OACI)"));
      await user.type(screen.getByLabelText("Aérodrome d’arrivée (OACI)"), nextArrival);
    } else if (change.aircraft !== undefined) {
      await user.selectOptions(screen.getByLabelText("Avion"), change.aircraft);
    }
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(command).toHaveBeenCalledTimes(2);
    expect(command.mock.calls[0]![0].idempotencyKey).toBe(firstKey);
    expect(command.mock.calls[1]![0].idempotencyKey).toBe(secondKey);
  });

  it("présente un refus serveur sans détail technique", async () => {
    const user = userEvent.setup();
    const command = vi.fn(async (): Promise<DispatchDraft> => {
      throw new DispatchDraftError("rejected");
    });
    const { container } = render(
      <FlightDispatchPanel {...createBaseProps()} command={command} />,
    );

    await fillIntention(user);
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("La préparation a été refusée.");
    expect(container).not.toHaveTextContent("rejected");
    expect(container).not.toHaveTextContent("DispatchDraftError");
  });

  it("présente une indisponibilité pour une réponse invalide", async () => {
    const user = userEvent.setup();
    const command = vi.fn(async (): Promise<DispatchDraft> => {
      throw new DispatchDraftError("invalid-response");
    });
    const { container } = render(
      <FlightDispatchPanel {...createBaseProps()} command={command} />,
    );

    await fillIntention(user);
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Le service de préparation est indisponible.",
    );
    expect(container).not.toHaveTextContent("invalid-response");
  });

  it("efface la session et demande le retour au login sur refus Auth", async () => {
    const user = userEvent.setup();
    const command = vi.fn(async (): Promise<DispatchDraft> => {
      throw new DispatchDraftError("authentication-required");
    });
    const manager = createSessionManager();
    const onAuthenticationRequired = vi.fn();
    render(
      <FlightDispatchPanel
        {...createBaseProps(manager)}
        command={command}
        onAuthenticationRequired={onAuthenticationRequired}
      />,
    );

    await fillIntention(user);
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(onAuthenticationRequired).toHaveBeenCalledOnce();
    expect(manager.hasSession()).toBe(false);
    expect(screen.queryByText("private-user-token")).not.toBeInTheDocument();
  });

  it("annule la commande lors du démontage", async () => {
    const user = userEvent.setup();
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn((commandInput: CreateDispatchDraftInput) => {
      receivedSignal = commandInput.signal;
      return new Promise<DispatchDraft>(() => undefined);
    });
    const { unmount } = render(
      <FlightDispatchPanel {...createBaseProps()} command={command} />,
    );

    await fillIntention(user);
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));
    unmount();

    expect(receivedSignal?.aborted).toBe(true);
  });
});
