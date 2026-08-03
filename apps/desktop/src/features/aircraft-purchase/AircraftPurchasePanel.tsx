import { useEffect, useId, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  AircraftPurchaseError,
  type AircraftPurchaseResult,
  purchaseAircraft,
  type PurchaseAircraftInput,
} from "@/features/aircraft-purchase/aircraftPurchase";

export type AircraftPurchaseCommand = (
  input: PurchaseAircraftInput,
) => Promise<AircraftPurchaseResult>;

export interface PurchaseOffer {
  id: string;
  label: string;
}

export interface AircraftPurchasePanelProps {
  command?: AircraftPurchaseCommand | undefined;
  config: DesktopConnectionConfig;
  createIdempotencyKey?: (() => string) | undefined;
  onAuthenticationRequired: () => void;
  onPendingChange?: ((pending: boolean) => void) | undefined;
  onPurchased?: (() => void) | undefined;
  offer: PurchaseOffer;
  sessionManager: DesktopSessionManager;
}

type PanelState =
  | { kind: "ready" }
  | { kind: "pending" }
  | { kind: "owned"; aircraftId: string }
  | { kind: "rejected" }
  | { kind: "unavailable" };

const defaultIdempotencyKeyFactory = () => crypto.randomUUID();

export function AircraftPurchasePanel({
  command = purchaseAircraft,
  config,
  createIdempotencyKey = defaultIdempotencyKeyFactory,
  onAuthenticationRequired,
  onPendingChange,
  onPurchased,
  offer,
  sessionManager,
}: AircraftPurchasePanelProps) {
  const titleId = useId();
  const [state, setState] = useState<PanelState>({ kind: "ready" });
  const abortControllerRef = useRef<AbortController | null>(null);
  const idempotencyKeyRef = useRef<string | null>(null);
  const pendingRef = useRef(false);

  useEffect(() => {
    abortControllerRef.current?.abort();
    abortControllerRef.current = null;
    idempotencyKeyRef.current = null;
    pendingRef.current = false;
    setState({ kind: "ready" });

    return () => {
      abortControllerRef.current?.abort();
      onPendingChange?.(false);
    };
  }, [offer.id, onPendingChange]);

  const submitPurchase = async () => {
    if (pendingRef.current || state.kind === "owned") {
      return;
    }

    pendingRef.current = true;
    onPendingChange?.(true);
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
    setState({ kind: "pending" });

    try {
      const idempotencyKey = idempotencyKeyRef.current ?? createIdempotencyKey();
      idempotencyKeyRef.current = idempotencyKey;
      const accessToken = await sessionManager.getAccessToken();
      if (abortController.signal.aborted) {
        return;
      }
      const result = await command({
        accessToken,
        anonKey: config.anonKey,
        idempotencyKey,
        offerId: offer.id,
        signal: abortController.signal,
        supabaseUrl: config.supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        setState({ kind: "owned", aircraftId: result.aircraftId });
        onPurchased?.();
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (
          (error instanceof SessionError && error.failure === "authentication-required") ||
          (error instanceof AircraftPurchaseError &&
            error.failure === "authentication-required")
        ) {
          sessionManager.clear();
          onAuthenticationRequired();
        } else if (error instanceof AircraftPurchaseError) {
          if (error.failure === "rejected") {
            setState({ kind: "rejected" });
          } else {
            setState({ kind: "unavailable" });
          }
        } else {
          setState({ kind: "unavailable" });
        }
      }
    } finally {
      if (abortControllerRef.current === abortController) {
        abortControllerRef.current = null;
        pendingRef.current = false;
        onPendingChange?.(false);
      }
    }
  };

  const disabled = state.kind === "pending" || state.kind === "owned";
  const actionLabel = state.kind === "pending"
    ? "Achat en cours…"
    : state.kind === "owned"
      ? "Avion acquis"
      : state.kind === "unavailable"
        ? "Réessayer"
        : "Acheter cet avion";

  return (
    <section aria-labelledby={titleId}>
      <h2 id={titleId}>Acheter {offer.label}</h2>
      <button type="button" disabled={disabled} onClick={() => void submitPurchase()}>
        {actionLabel}
      </button>

      <div aria-live="polite" aria-atomic="true">
        {state.kind === "ready" && <p>Prêt à envoyer une demande d’achat sécurisée.</p>}
        {state.kind === "pending" && <p>Achat en cours. Ne fermez pas cette fenêtre.</p>}
        {state.kind === "owned" && <p>Avion acquis. Il est maintenant dans votre flotte.</p>}
      </div>

      {state.kind === "rejected" && (
        <p role="alert">L’achat a été refusé. Actualisez l’offre et votre solde avant de réessayer.</p>
      )}
      {state.kind === "unavailable" && (
        <p role="alert">Le service d’achat est indisponible. Réessayez dans quelques instants.</p>
      )}
    </section>
  );
}
