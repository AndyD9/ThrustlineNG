import { useCallback, useEffect, useId, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  AircraftCatalogError,
  type AircraftCatalogOffer,
  loadAircraftCatalog,
  type LoadAircraftCatalogInput,
} from "@/features/aircraft-catalog/aircraftCatalog";
import {
  AircraftPurchasePanel,
  type AircraftPurchaseCommand,
} from "@/features/aircraft-purchase/AircraftPurchasePanel";

export type AircraftCatalogCommand = (
  input: LoadAircraftCatalogInput,
) => Promise<AircraftCatalogOffer[]>;

export interface AircraftCatalogPanelProps {
  command?: AircraftCatalogCommand | undefined;
  config: DesktopConnectionConfig;
  createPurchaseIdempotencyKey?: (() => string) | undefined;
  onAuthenticationRequired: () => void;
  onPurchaseSucceeded?: (() => void) | undefined;
  purchaseCommand?: AircraftPurchaseCommand | undefined;
  sessionManager: DesktopSessionManager;
}

type PanelState =
  | { kind: "ready" }
  | { kind: "pending" }
  | { kind: "loaded"; offers: AircraftCatalogOffer[] }
  | { kind: "unavailable" };

const euroFormatter = new Intl.NumberFormat("fr-FR", {
  currency: "EUR",
  style: "currency",
});

export function AircraftCatalogPanel({
  command = loadAircraftCatalog,
  config,
  createPurchaseIdempotencyKey,
  onAuthenticationRequired,
  onPurchaseSucceeded,
  purchaseCommand,
  sessionManager,
}: AircraftCatalogPanelProps) {
  const titleId = useId();
  const [state, setState] = useState<PanelState>({ kind: "ready" });
  const [selectedOfferId, setSelectedOfferId] = useState<string | null>(null);
  const [purchasePending, setPurchasePending] = useState(false);
  const abortControllerRef = useRef<AbortController | null>(null);
  const pendingRef = useRef(false);

  useEffect(() => () => abortControllerRef.current?.abort(), []);
  const handlePurchasePendingChange = useCallback((pending: boolean) => {
    setPurchasePending(pending);
  }, []);

  const load = async () => {
    if (pendingRef.current) {
      return;
    }
    pendingRef.current = true;
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
    setSelectedOfferId(null);
    setPurchasePending(false);
    setState({ kind: "pending" });

    try {
      const accessToken = await sessionManager.getAccessToken();
      if (abortController.signal.aborted) {
        return;
      }
      const offers = await command({
        accessToken,
        anonKey: config.anonKey,
        signal: abortController.signal,
        supabaseUrl: config.supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        setState({ kind: "loaded", offers });
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (
          (error instanceof SessionError && error.failure === "authentication-required") ||
          (error instanceof AircraftCatalogError &&
            error.failure === "authentication-required")
        ) {
          sessionManager.clear();
          onAuthenticationRequired();
        } else {
          setState({ kind: "unavailable" });
        }
      }
    } finally {
      if (abortControllerRef.current === abortController) {
        abortControllerRef.current = null;
        pendingRef.current = false;
      }
    }
  };

  const selectedOffer = state.kind === "loaded"
    ? state.offers.find((offer) => offer.id === selectedOfferId)
    : undefined;

  return (
    <section aria-labelledby={titleId}>
      <h2 id={titleId}>Catalogue d’avions</h2>
      <button type="button" disabled={state.kind === "pending"} onClick={() => void load()}>
        {state.kind === "pending"
          ? "Chargement…"
          : state.kind === "unavailable"
            ? "Réessayer"
            : "Afficher les offres"}
      </button>

      <div aria-live="polite" aria-atomic="true">
        {state.kind === "ready" && <p>Chargez les offres disponibles lorsque vous êtes prêt.</p>}
        {state.kind === "pending" && <p>Chargement sécurisé du catalogue.</p>}
        {state.kind === "loaded" && state.offers.length === 0 && (
          <p>Aucune offre n’est disponible actuellement.</p>
        )}
      </div>

      {state.kind === "loaded" && state.offers.length > 0 && (
        <ul aria-label="Offres disponibles">
          {state.offers.map((offer) => (
            <li key={offer.id}>
              <strong>{offer.displayName}</strong>{" "}
              <span>{offer.aircraftTypeCode} · {offer.serialNumber}</span>{" "}
              <span>{euroFormatter.format(offer.priceMinor / 100)}</span>
              <button
                type="button"
                disabled={purchasePending || selectedOfferId === offer.id}
                onClick={() => setSelectedOfferId(offer.id)}
              >
                {selectedOfferId === offer.id
                  ? "Offre sélectionnée"
                  : `Choisir ${offer.displayName}`}
              </button>
            </li>
          ))}
        </ul>
      )}
      {selectedOffer !== undefined && (
        <AircraftPurchasePanel
          command={purchaseCommand}
          config={config}
          createIdempotencyKey={createPurchaseIdempotencyKey}
          offer={{ id: selectedOffer.id, label: selectedOffer.displayName }}
          onAuthenticationRequired={onAuthenticationRequired}
          onPendingChange={handlePurchasePendingChange}
          onPurchased={onPurchaseSucceeded}
          sessionManager={sessionManager}
        />
      )}
      {state.kind === "unavailable" && (
        <p role="alert">Le catalogue est indisponible. Réessayez dans quelques instants.</p>
      )}
    </section>
  );
}
