import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { DesktopSessionManager } from "@/features/auth/session";
import {
  AircraftCatalogPanel,
  type AircraftCatalogCommand,
} from "@/features/aircraft-catalog/AircraftCatalogPanel";
import {
  AircraftCatalogError,
  type AircraftCatalogOffer,
} from "@/features/aircraft-catalog/aircraftCatalog";
import type { PurchaseAircraftInput } from "@/features/aircraft-purchase/aircraftPurchase";

const config: DesktopConnectionConfig = {
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
  target: "local",
};
const offer: AircraftCatalogOffer = {
  aircraftTypeCode: "C172",
  currencyCode: "EUR",
  displayName: "Cessna 172 Skyhawk",
  id: "93abcdef-0000-4000-8000-000000000001",
  priceMinor: 12_500_000,
  schemaVersion: 1,
  serialNumber: "SYN-001",
};
const secondOffer: AircraftCatalogOffer = {
  ...offer,
  displayName: "Diamond DA40",
  id: "93abcdef-0000-4000-8000-000000000002",
  serialNumber: "SYN-002",
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

describe("AircraftCatalogPanel", () => {
  it("ne charge rien au rendu puis affiche les offres sur action explicite", async () => {
    const user = userEvent.setup();
    const command = vi.fn<AircraftCatalogCommand>(async () => [offer]);
    const { container } = render(
      <AircraftCatalogPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );

    expect(command).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Afficher les offres" }));

    expect(await screen.findByRole("list", { name: "Offres disponibles" }))
      .toHaveTextContent("Cessna 172 Skyhawk");
    expect(container).toHaveTextContent("C172 · SYN-001");
    expect(container).toHaveTextContent(/125[\s\u202f]000,00/);
    expect(command.mock.calls[0]![0]).toMatchObject({
      accessToken: "private-access-token",
      anonKey: "public-anon-key",
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(container).not.toHaveTextContent("private-access-token");
    expect(container).not.toHaveTextContent(offer.id);
  });

  it("rend explicitement un catalogue vide", async () => {
    const user = userEvent.setup();
    render(
      <AircraftCatalogPanel
        command={async () => []}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher les offres" }));
    expect(await screen.findByText("Aucune offre n’est disponible actuellement."))
      .toBeInTheDocument();
  });

  it("compose uniquement une offre chargée avec l’achat et acquiert le bearer au clic", async () => {
    const user = userEvent.setup();
    const sessionManager = createSessionManager();
    const purchaseCommand = vi.fn(async (input: PurchaseAircraftInput) => ({
      aircraftId: "93abcdef-0000-4000-8000-000000000010",
      ledgerEntryId: "93abcdef-0000-4000-8000-000000000011",
      offerId: input.offerId,
      schemaVersion: 1 as const,
      state: "owned" as const,
    }));
    const { container } = render(
      <AircraftCatalogPanel
        command={async () => [offer]}
        config={config}
        createPurchaseIdempotencyKey={() => "93abcdef-0000-4000-8000-000000000012"}
        onAuthenticationRequired={vi.fn()}
        purchaseCommand={purchaseCommand}
        sessionManager={sessionManager}
      />,
    );

    expect(purchaseCommand).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Afficher les offres" }));
    await user.click(await screen.findByRole("button", { name: "Choisir Cessna 172 Skyhawk" }));
    sessionManager.setSession({
      accessToken: "refreshed-access-token",
      expiresAtEpochSeconds: 4_600,
      refreshToken: "refreshed-private-token",
    });
    expect(screen.getByRole("heading", { name: "Acheter Cessna 172 Skyhawk" }))
      .toBeInTheDocument();
    expect(purchaseCommand).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Acheter cet avion" }));

    expect(await screen.findByText("Avion acquis. Il est maintenant dans votre flotte."))
      .toBeInTheDocument();
    expect(purchaseCommand).toHaveBeenCalledOnce();
    expect(purchaseCommand.mock.calls[0]![0]).toMatchObject({
      accessToken: "refreshed-access-token",
      anonKey: "public-anon-key",
      idempotencyKey: "93abcdef-0000-4000-8000-000000000012",
      offerId: offer.id,
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(container).not.toHaveTextContent("private-access-token");
    expect(container).not.toHaveTextContent("refreshed-access-token");
    expect(container).not.toHaveTextContent(offer.id);
  });

  it("empêche un changement d’offre pendant une commande en cours", async () => {
    const user = userEvent.setup();
    const purchaseCommand = vi.fn(() => new Promise<never>(() => undefined));
    render(
      <AircraftCatalogPanel
        command={async () => [offer, secondOffer]}
        config={config}
        onAuthenticationRequired={vi.fn()}
        purchaseCommand={purchaseCommand}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Afficher les offres" }));
    await user.click(await screen.findByRole("button", { name: "Choisir Cessna 172 Skyhawk" }));
    await user.click(screen.getByRole("button", { name: "Acheter cet avion" }));

    expect(screen.getByRole("button", { name: "Choisir Diamond DA40" })).toBeDisabled();
    expect(purchaseCommand).toHaveBeenCalledOnce();
  });

  it("bloque les chargements concurrents et permet un retry", async () => {
    const user = userEvent.setup();
    let resolve!: (offers: AircraftCatalogOffer[]) => void;
    const pending = new Promise<AircraftCatalogOffer[]>((promiseResolve) => {
      resolve = promiseResolve;
    });
    const command = vi
      .fn<AircraftCatalogCommand>()
      .mockRejectedValueOnce(new AircraftCatalogError("unavailable"))
      .mockImplementationOnce(async () => pending);
    render(
      <AircraftCatalogPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher les offres" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    await user.dblClick(screen.getByRole("button", { name: "Réessayer" }));
    expect(command).toHaveBeenCalledTimes(2);
    resolve([offer]);
    expect(await screen.findByRole("list")).toBeInTheDocument();
  });

  it("efface une session refusée et demande le retour au login", async () => {
    const user = userEvent.setup();
    const manager = createSessionManager();
    const onAuthenticationRequired = vi.fn();
    render(
      <AircraftCatalogPanel
        command={async () => {
          throw new AircraftCatalogError("authentication-required");
        }}
        config={config}
        onAuthenticationRequired={onAuthenticationRequired}
        sessionManager={manager}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher les offres" }));
    expect(onAuthenticationRequired).toHaveBeenCalledOnce();
    expect(manager.hasSession()).toBe(false);
  });

  it("annule la lecture au démontage", async () => {
    const user = userEvent.setup();
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn<AircraftCatalogCommand>((commandInput) => {
      receivedSignal = commandInput.signal;
      return new Promise<AircraftCatalogOffer[]>(() => undefined);
    });
    const { unmount } = render(
      <AircraftCatalogPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Afficher les offres" }));
    unmount();
    expect(receivedSignal?.aborted).toBe(true);
  });
});
