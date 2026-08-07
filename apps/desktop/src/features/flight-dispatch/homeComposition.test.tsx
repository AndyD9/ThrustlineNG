import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import type { CompanyAircraft } from "@/features/aircraft-fleet/aircraftFleet";
import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { DesktopSessionManager } from "@/features/auth/session";
import type { DispatchListCommand } from "@/features/flight-dispatch/DispatchListPanel";
import type { FlightSummaryCommand } from "@/features/flight-dispatch/FlightSummaryControl";
import type { CompanyDispatch } from "@/features/flight-dispatch/dispatchList";
import type {
  CreateDispatchDraftInput,
  DispatchDraft,
} from "@/features/flight-dispatch/flightDispatch";
import { HomePage } from "@/pages/HomePage";

const aircraftId = "93000000-0000-4000-8000-000000000001";
const dispatchId = "93000000-0000-4000-8000-000000000002";

const fleet: CompanyAircraft[] = [
  {
    acquiredAt: "2026-08-01T08:00:00Z",
    acquisitionKind: "purchase",
    aircraftTypeCode: "C172",
    displayName: "Synthetic Cessna",
    id: aircraftId,
    schemaVersion: 1,
    serialNumber: "SYN-001",
  },
];

const draft: DispatchDraft = {
  aircraftId,
  arrivalIcao: "LFBO",
  createdAt: "2026-08-04T09:15:00Z",
  departureIcao: "LFPG",
  dispatchId,
  schemaVersion: 1,
  state: "draft",
};

const persistedDispatch: CompanyDispatch = {
  aircraftId,
  arrivalIcao: "LFBO",
  createdAt: "2026-08-04T09:15:00Z",
  departureIcao: "LFPG",
  id: "94000000-0000-4000-8000-000000000001",
  schemaVersion: 1,
  startedAt: null,
  state: "draft",
};

const activeFlight: CompanyDispatch = {
  ...persistedDispatch,
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

afterEach(() => {
  vi.restoreAllMocks();
});

describe("composition du dispatch sur l’accueil", () => {
  it("n’expose la préparation qu’après une flotte chargée et sans réseau au rendu", async () => {
    const user = userEvent.setup();
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const dispatchDraftCommand = vi.fn(async (_input: CreateDispatchDraftInput) => draft);
    render(
      <HomePage
        aircraftFleetCommand={async () => fleet}
        companyPresenceCommand={async () => true}
        config={config}
        dispatchDraftCommand={dispatchDraftCommand}
        onAuthenticationRequired={vi.fn()}
        onSignOut={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    expect(screen.queryByRole("heading", { name: "Préparer un vol" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    await user.click(await screen.findByRole("button", { name: "Afficher ma flotte" }));

    expect(await screen.findByRole("heading", { name: "Préparer un vol" })).toBeInTheDocument();
    expect(dispatchDraftCommand).not.toHaveBeenCalled();

    await user.selectOptions(screen.getByLabelText("Avion"), aircraftId);
    await user.type(screen.getByLabelText("Aérodrome de départ (OACI)"), "lfpg");
    await user.type(screen.getByLabelText("Aérodrome d’arrivée (OACI)"), "lfbo");
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(await screen.findByText(/Brouillon créé pour LFPG/)).toBeInTheDocument();
    expect(dispatchDraftCommand).toHaveBeenCalledOnce();
    expect(dispatchDraftCommand.mock.calls[0]![0]).toMatchObject({
      accessToken: "private-user-token",
      aircraftId,
      anonKey: "public-anon-key",
      arrivalIcao: "LFBO",
      departureIcao: "LFPG",
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("garde l’accueil sans préparation quand la flotte est vide", async () => {
    const user = userEvent.setup();
    render(
      <HomePage
        aircraftFleetCommand={async () => []}
        companyPresenceCommand={async () => true}
        config={config}
        dispatchDraftCommand={vi.fn(async (_input: CreateDispatchDraftInput) => draft)}
        onAuthenticationRequired={vi.fn()}
        onSignOut={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    await user.click(await screen.findByRole("button", { name: "Afficher ma flotte" }));

    expect(
      await screen.findByText("Votre flotte ne contient encore aucun avion."),
    ).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Préparer un vol" })).not.toBeInTheDocument();
  });

  it("relit la source autoritaire après une création réussie, sans réseau au rendu", async () => {
    const user = userEvent.setup();
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const dispatchListCommand = vi.fn<DispatchListCommand>()
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([persistedDispatch]);
    render(
      <HomePage
        aircraftFleetCommand={async () => fleet}
        companyPresenceCommand={async () => true}
        config={config}
        dispatchDraftCommand={vi.fn(async (_input: CreateDispatchDraftInput) => draft)}
        dispatchListCommand={dispatchListCommand}
        onAuthenticationRequired={vi.fn()}
        onSignOut={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    expect(screen.queryByRole("heading", { name: "Mes dispatchs" })).not.toBeInTheDocument();
    expect(dispatchListCommand).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    expect(await screen.findByRole("heading", { name: "Mes dispatchs" })).toBeInTheDocument();
    expect(dispatchListCommand).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Afficher ma flotte" }));
    await user.click(await screen.findByRole("button", { name: "Afficher mes dispatchs" }));
    expect(await screen.findByText("Aucun dispatch n’est encore préparé.")).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText("Avion"), aircraftId);
    await user.type(screen.getByLabelText("Aérodrome de départ (OACI)"), "lfpg");
    await user.type(screen.getByLabelText("Aérodrome d’arrivée (OACI)"), "lfbo");
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(await screen.findByRole("list", { name: "Dispatchs de la compagnie" }))
      .toHaveTextContent("LFPG → LFBO");
    expect(dispatchListCommand).toHaveBeenCalledTimes(2);
    expect(dispatchListCommand.mock.calls[1]![0]).toMatchObject({
      accessToken: "private-user-token",
      anonKey: "public-anon-key",
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("affiche le temps de bloc mesuré du vol actif, sans réseau ni appel au rendu", async () => {
    const user = userEvent.setup();
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const flightSummaryCommand = vi.fn<FlightSummaryCommand>(async () => ({
      blockMinutes: 42,
      contractVersion: "1",
      state: "completed",
    }));
    render(
      <HomePage
        aircraftFleetCommand={async () => fleet}
        companyPresenceCommand={async () => true}
        config={config}
        dispatchListCommand={async () => [activeFlight]}
        flightSummaryCommand={flightSummaryCommand}
        onAuthenticationRequired={vi.fn()}
        onSignOut={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    await user.click(await screen.findByRole("button", { name: "Afficher mes dispatchs" }));
    await screen.findByRole("list", { name: "Dispatchs de la compagnie" });
    expect(flightSummaryCommand).not.toHaveBeenCalled();

    await user.click(
      screen.getByRole("button", { name: "Afficher le temps de bloc · LFPG → LFBO" }),
    );

    expect(await screen.findByText("Dernière mesure de replay de la session : 42 min.")).toBeInTheDocument();
    expect(flightSummaryCommand).toHaveBeenCalledExactlyOnceWith();
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("n’actualise pas une liste jamais ouverte après une création réussie", async () => {
    const user = userEvent.setup();
    const dispatchListCommand = vi.fn<DispatchListCommand>(async () => [persistedDispatch]);
    render(
      <HomePage
        aircraftFleetCommand={async () => fleet}
        companyPresenceCommand={async () => true}
        config={config}
        dispatchDraftCommand={vi.fn(async (_input: CreateDispatchDraftInput) => draft)}
        dispatchListCommand={dispatchListCommand}
        onAuthenticationRequired={vi.fn()}
        onSignOut={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    await user.click(await screen.findByRole("button", { name: "Afficher ma flotte" }));
    await user.selectOptions(await screen.findByLabelText("Avion"), aircraftId);
    await user.type(screen.getByLabelText("Aérodrome de départ (OACI)"), "lfpg");
    await user.type(screen.getByLabelText("Aérodrome d’arrivée (OACI)"), "lfbo");
    await user.click(screen.getByRole("button", { name: "Préparer le vol" }));

    expect(await screen.findByText(/Brouillon créé pour LFPG/)).toBeInTheDocument();
    expect(dispatchListCommand).not.toHaveBeenCalled();
  });
});
