import { useEffect, useId, useRef, useState } from "react";

import {
  AircraftPurchaseError,
  type AircraftPurchaseResult,
  purchaseAircraft,
  type PurchaseAircraftInput,
} from "@/features/aircraft-purchase/aircraftPurchase";

type PurchaseCommand = (input: PurchaseAircraftInput) => Promise<AircraftPurchaseResult>;

interface PurchaseOffer {
  id: string;
  label: string;
}

interface UserSession {
  accessToken: string;
}

interface AircraftPurchasePanelProps {
  anonKey: string;
  command?: PurchaseCommand;
  createIdempotencyKey?: () => string;
  offer: PurchaseOffer;
  session: UserSession;
  supabaseUrl: string;
}

type PanelState =
  | { kind: "ready" }
  | { kind: "pending" }
  | { kind: "owned"; aircraftId: string }
  | { kind: "rejected"; authenticationRequired: boolean }
  | { kind: "unavailable" };

const defaultIdempotencyKeyFactory = () => crypto.randomUUID();

export function AircraftPurchasePanel({
  anonKey,
  command = purchaseAircraft,
  createIdempotencyKey = defaultIdempotencyKeyFactory,
  offer,
  session,
  supabaseUrl,
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
    };
  }, [offer.id]);

  const submitPurchase = async () => {
    if (pendingRef.current || state.kind === "owned") {
      return;
    }

    pendingRef.current = true;
    const idempotencyKey = idempotencyKeyRef.current ?? createIdempotencyKey();
    idempotencyKeyRef.current = idempotencyKey;
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
    setState({ kind: "pending" });

    try {
      const result = await command({
        accessToken: session.accessToken,
        anonKey,
        idempotencyKey,
        offerId: offer.id,
        signal: abortController.signal,
        supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        setState({ kind: "owned", aircraftId: result.aircraftId });
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (error instanceof AircraftPurchaseError) {
          if (error.failure === "authentication-required") {
            setState({ kind: "rejected", authenticationRequired: true });
          } else if (error.failure === "rejected") {
            setState({ kind: "rejected", authenticationRequired: false });
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
        : state.kind === "rejected" && state.authenticationRequired
          ? "Réessayer après reconnexion"
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
        <p role="alert">
          {state.authenticationRequired
            ? "Votre session a expiré. Reconnectez-vous avant de réessayer."
            : "L’achat a été refusé. Actualisez l’offre et votre solde avant de réessayer."}
        </p>
      )}
      {state.kind === "unavailable" && (
        <p role="alert">Le service d’achat est indisponible. Réessayez dans quelques instants.</p>
      )}
    </section>
  );
}
