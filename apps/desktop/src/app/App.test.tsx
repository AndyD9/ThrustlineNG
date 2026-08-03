import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { App, type DesktopAuthRuntime } from "@/app/App";
import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import type { PasswordSignInInput } from "@/features/auth/passwordSignIn";
import { DesktopSessionManager, type UserSessionTokens } from "@/features/auth/session";
import type { AircraftCatalogOffer } from "@/features/aircraft-catalog/aircraftCatalog";
import {
  AircraftPurchaseError,
  type PurchaseAircraftInput,
} from "@/features/aircraft-purchase/aircraftPurchase";
import { CompanyOnboardingError } from "@/features/company-onboarding/companyOnboarding";

const config: DesktopConnectionConfig = {
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
  target: "local",
};
const session: UserSessionTokens = {
  accessToken: "private-access-token",
  expiresAtEpochSeconds: 4_600,
  refreshToken: "private-refresh-token",
};
const catalogOffer: AircraftCatalogOffer = {
  aircraftTypeCode: "C172",
  currencyCode: "EUR",
  displayName: "Cessna 172 Skyhawk",
  id: "96000000-0000-4000-8000-000000000001",
  priceMinor: 12_500_000,
  schemaVersion: 1,
  serialNumber: "SYN-001",
};

function createRuntime(initialSession?: UserSessionTokens): DesktopAuthRuntime {
  const sessionManager = new DesktopSessionManager(config, vi.fn(), () => 1_000);
  if (initialSession !== undefined) {
    sessionManager.setSession(initialSession);
  }
  return { config, sessionManager };
}

async function fillLogin(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText("Adresse email"), "pilot@thrustline.invalid");
  await user.type(screen.getByLabelText("Mot de passe"), "synthetic-password");
}

describe("App", () => {
  beforeEach(() => {
    window.location.hash = "#/";
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("redirige l’accueil vers la connexion tant que la session est absente", async () => {
    render(<App authRuntime={createRuntime()} />);

    expect(screen.getByRole("banner")).toBeInTheDocument();
    expect(await screen.findByRole("heading", { name: "Connexion à Thrustline" })).toBeInTheDocument();
    expect(screen.queryByText("Session locale active")).not.toBeInTheDocument();
    expect(window.location.hash).toBe("#/login");
  });

  it("installe une connexion réussie avant d’afficher l’accueil protégé", async () => {
    const user = userEvent.setup();
    const runtime = createRuntime();
    const command = vi.fn(async (_input: PasswordSignInInput) => session);
    const { container } = render(<App authRuntime={runtime} signInCommand={command} />);
    await screen.findByRole("heading", { name: "Connexion à Thrustline" });
    await fillLogin(user);

    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    expect(await screen.findByRole("heading", { level: 1, name: "Thrustline" })).toBeInTheDocument();
    expect(runtime.sessionManager.hasSession()).toBe(true);
    expect(command).toHaveBeenCalledOnce();
    expect(window.location.hash).toBe("#/");
    expect(container).not.toHaveTextContent("pilot@thrustline.invalid");
    expect(container).not.toHaveTextContent("synthetic-password");
    expect(container).not.toHaveTextContent("private-access-token");
    expect(container).not.toHaveTextContent("private-refresh-token");
  });

  it("écarte /login avec une session et déconnecte sans appel réseau", async () => {
    const user = userEvent.setup();
    const runtime = createRuntime(session);
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    window.location.hash = "#/login";
    render(<App authRuntime={runtime} />);

    expect(await screen.findByRole("heading", { level: 1, name: "Thrustline" })).toBeInTheDocument();
    expect(window.location.hash).toBe("#/");
    await user.click(screen.getByRole("button", { name: "Se déconnecter" }));

    expect(await screen.findByRole("heading", { name: "Connexion à Thrustline" })).toBeInTheDocument();
    expect(runtime.sessionManager.hasSession()).toBe(false);
    expect(window.location.hash).toBe("#/login");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("affiche une route inconnue puis revient vers la garde de connexion", async () => {
    const user = userEvent.setup();
    window.location.hash = "#/inconnue";
    render(<App authRuntime={createRuntime()} />);

    expect(screen.getByRole("heading", { name: "Page introuvable" })).toBeInTheDocument();
    const homeLink = screen.getByRole("link", { name: "Retour à l’accueil" });
    homeLink.focus();
    expect(homeLink).toHaveFocus();
    await user.click(homeLink);
    expect(await screen.findByRole("heading", { name: "Connexion à Thrustline" })).toBeInTheDocument();
  });

  it("efface une session refusée pendant l'onboarding puis revient au login", async () => {
    const user = userEvent.setup();
    const runtime = createRuntime(session);
    const companyOnboardingCommand = vi.fn(async () => {
      throw new CompanyOnboardingError("authentication-required");
    });
    render(
      <App
        authRuntime={runtime}
        companyOnboardingCommand={companyOnboardingCommand}
        companyPresenceCommand={async () => false}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    await user.type(screen.getByLabelText("Nom de la compagnie"), "Synthetic Airways");
    await user.click(screen.getByRole("button", { name: "Créer la compagnie" }));

    expect(await screen.findByRole("heading", { name: "Connexion à Thrustline" })).toBeInTheDocument();
    expect(runtime.sessionManager.hasSession()).toBe(false);
    expect(window.location.hash).toBe("#/login");
  });

  it("aiguille une compagnie existante vers le catalogue sans chargement implicite", async () => {
    const user = userEvent.setup();
    const companyPresenceCommand = vi.fn(async () => true);
    const aircraftCatalogCommand = vi.fn(async () => []);
    render(
      <App
        aircraftCatalogCommand={aircraftCatalogCommand}
        authRuntime={createRuntime(session)}
        companyPresenceCommand={companyPresenceCommand}
      />,
    );

    expect(companyPresenceCommand).not.toHaveBeenCalled();
    expect(aircraftCatalogCommand).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));

    expect(await screen.findByRole("heading", { name: "Catalogue d’avions" })).toBeInTheDocument();
    expect(companyPresenceCommand).toHaveBeenCalledOnce();
    expect(aircraftCatalogCommand).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Afficher les offres" }));
    expect(await screen.findByText("Aucune offre n’est disponible actuellement.")).toBeInTheDocument();
  });

  it("aiguille une nouvelle compagnie vers le catalogue après l'onboarding", async () => {
    const user = userEvent.setup();
    const companyOnboardingCommand = vi.fn(async () => ({
      companyId: "95000000-0000-4000-8000-000000000001",
      openingEntryId: "95000000-0000-4000-8000-000000000002",
      schemaVersion: 1 as const,
      state: "active" as const,
    }));
    render(
      <App
        authRuntime={createRuntime(session)}
        companyOnboardingCommand={companyOnboardingCommand}
        companyPresenceCommand={async () => false}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    await user.type(screen.getByLabelText("Nom de la compagnie"), "Synthetic Airways");
    await user.click(screen.getByRole("button", { name: "Créer la compagnie" }));

    expect(await screen.findByRole("heading", { name: "Catalogue d’avions" })).toBeInTheDocument();
    expect(companyOnboardingCommand).toHaveBeenCalledOnce();
  });

  it("compose catalogue et achat sans réseau implicite ni autorité économique cliente", async () => {
    const user = userEvent.setup();
    const aircraftCatalogCommand = vi.fn(async () => [catalogOffer]);
    const aircraftPurchaseCommand = vi.fn(async (input: PurchaseAircraftInput) => ({
      aircraftId: "96000000-0000-4000-8000-000000000002",
      ledgerEntryId: "96000000-0000-4000-8000-000000000003",
      offerId: input.offerId,
      schemaVersion: 1 as const,
      state: "owned" as const,
    }));
    render(
      <App
        aircraftCatalogCommand={aircraftCatalogCommand}
        aircraftPurchaseCommand={aircraftPurchaseCommand}
        authRuntime={createRuntime(session)}
        companyPresenceCommand={async () => true}
      />,
    );

    expect(aircraftCatalogCommand).not.toHaveBeenCalled();
    expect(aircraftPurchaseCommand).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    await user.click(await screen.findByRole("button", { name: "Afficher les offres" }));
    await user.click(await screen.findByRole("button", { name: "Choisir Cessna 172 Skyhawk" }));
    await user.click(screen.getByRole("button", { name: "Acheter cet avion" }));

    expect(await screen.findByText("Avion acquis. Il est maintenant dans votre flotte."))
      .toBeInTheDocument();
    expect(aircraftPurchaseCommand).toHaveBeenCalledOnce();
    expect(aircraftPurchaseCommand.mock.calls[0]![0]).toMatchObject({
      accessToken: "private-access-token",
      anonKey: "public-anon-key",
      offerId: catalogOffer.id,
    });
    expect(aircraftPurchaseCommand.mock.calls[0]![0]).not.toHaveProperty("priceMinor");
    expect(aircraftPurchaseCommand.mock.calls[0]![0]).not.toHaveProperty("companyId");
    expect(aircraftPurchaseCommand.mock.calls[0]![0]).not.toHaveProperty("ownerId");
  });

  it("efface la session et revient au login quand Auth refuse l’achat", async () => {
    const user = userEvent.setup();
    const runtime = createRuntime(session);
    render(
      <App
        aircraftCatalogCommand={async () => [catalogOffer]}
        aircraftPurchaseCommand={async () => {
          throw new AircraftPurchaseError("authentication-required");
        }}
        authRuntime={runtime}
        companyPresenceCommand={async () => true}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    await user.click(await screen.findByRole("button", { name: "Afficher les offres" }));
    await user.click(await screen.findByRole("button", { name: "Choisir Cessna 172 Skyhawk" }));
    await user.click(screen.getByRole("button", { name: "Acheter cet avion" }));

    expect(await screen.findByRole("heading", { name: "Connexion à Thrustline" }))
      .toBeInTheDocument();
    expect(runtime.sessionManager.hasSession()).toBe(false);
    expect(window.location.hash).toBe("#/login");
  });

  it("n’effectue aucun appel réseau pendant le rendu ou la redirection", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const xhrSpy = vi.spyOn(XMLHttpRequest.prototype, "open");

    render(<App authRuntime={createRuntime()} />);
    await screen.findByRole("heading", { name: "Connexion à Thrustline" });

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(xhrSpy).not.toHaveBeenCalled();
  });
});
