import { useEffect, useId, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  AircraftCatalogError,
  type AircraftCatalogOffer,
  loadAircraftCatalog,
  type LoadAircraftCatalogInput,
} from "@/features/aircraft-catalog/aircraftCatalog";

export type AircraftCatalogCommand = (
  input: LoadAircraftCatalogInput,
) => Promise<AircraftCatalogOffer[]>;

export interface AircraftCatalogPanelProps {
  command?: AircraftCatalogCommand | undefined;
  config: DesktopConnectionConfig;
  onAuthenticationRequired: () => void;
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
  onAuthenticationRequired,
  sessionManager,
}: AircraftCatalogPanelProps) {
  const titleId = useId();
  const [state, setState] = useState<PanelState>({ kind: "ready" });
  const abortControllerRef = useRef<AbortController | null>(null);
  const pendingRef = useRef(false);

  useEffect(() => () => abortControllerRef.current?.abort(), []);

  const load = async () => {
    if (pendingRef.current) {
      return;
    }
    pendingRef.current = true;
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
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
            </li>
          ))}
        </ul>
      )}
      {state.kind === "unavailable" && (
        <p role="alert">Le catalogue est indisponible. Réessayez dans quelques instants.</p>
      )}
    </section>
  );
}
