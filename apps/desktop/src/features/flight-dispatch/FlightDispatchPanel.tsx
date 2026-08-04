import { type FormEvent, useEffect, useId, useRef, useState } from "react";

import type { CompanyAircraft } from "@/features/aircraft-fleet/aircraftFleet";
import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  type CreateDispatchDraftInput,
  createDispatchDraft,
  type DispatchDraft,
  DispatchDraftError,
  type DispatchIntention,
  normalizeDispatchIntention,
} from "@/features/flight-dispatch/flightDispatch";

export type DispatchDraftCommand = (input: CreateDispatchDraftInput) => Promise<DispatchDraft>;

export interface FlightDispatchPanelProps {
  aircraft: CompanyAircraft[];
  command?: DispatchDraftCommand | undefined;
  config: DesktopConnectionConfig;
  createIdempotencyKey?: (() => string) | undefined;
  onAuthenticationRequired: () => void;
  sessionManager: DesktopSessionManager;
}

type PanelState =
  | { kind: "ready" }
  | { kind: "pending" }
  | { draft: DispatchDraft; intentionKey: string; kind: "created" }
  | { kind: "rejected" }
  | { kind: "unavailable" };

const defaultIdempotencyKeyFactory = () => crypto.randomUUID();

const createdAtFormatter = new Intl.DateTimeFormat("fr-FR", {
  dateStyle: "short",
  timeStyle: "short",
  timeZone: "UTC",
});

function toIntentionKey(intention: DispatchIntention): string {
  return `${intention.aircraftId}|${intention.departureIcao}|${intention.arrivalIcao}`;
}

export function FlightDispatchPanel({
  aircraft,
  command = createDispatchDraft,
  config,
  createIdempotencyKey = defaultIdempotencyKeyFactory,
  onAuthenticationRequired,
  sessionManager,
}: FlightDispatchPanelProps) {
  const fieldId = useId();
  const [selectedAircraftId, setSelectedAircraftId] = useState("");
  const [departureIcao, setDepartureIcao] = useState("");
  const [arrivalIcao, setArrivalIcao] = useState("");
  const [state, setState] = useState<PanelState>({ kind: "ready" });
  const abortControllerRef = useRef<AbortController | null>(null);
  const intentionRef = useRef<(DispatchIntention & { idempotencyKey: string }) | null>(null);
  const pendingRef = useRef(false);

  useEffect(() => () => abortControllerRef.current?.abort(), []);

  const selectedAircraft = aircraft.find((item) => item.id === selectedAircraftId);
  const submittedIntentionKey = state.kind === "created" ? state.intentionKey : null;
  const currentIntentionKey = toIntentionKey({
    aircraftId: selectedAircraft?.id ?? "",
    arrivalIcao: arrivalIcao.trim().toUpperCase(),
    departureIcao: departureIcao.trim().toUpperCase(),
  });
  const disabled = state.kind === "pending" || submittedIntentionKey === currentIntentionKey;

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (pendingRef.current || disabled) {
      return;
    }

    let intention: DispatchIntention;
    try {
      intention = normalizeDispatchIntention({
        aircraftId: selectedAircraft?.id ?? "",
        arrivalIcao,
        departureIcao,
      });
    } catch {
      setState({ kind: "rejected" });
      return;
    }

    pendingRef.current = true;
    const previousIntention = intentionRef.current;
    const idempotencyKey =
      previousIntention !== null && toIntentionKey(previousIntention) === toIntentionKey(intention)
        ? previousIntention.idempotencyKey
        : createIdempotencyKey();
    intentionRef.current = { ...intention, idempotencyKey };
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
    setState({ kind: "pending" });

    try {
      const accessToken = await sessionManager.getAccessToken();
      if (abortController.signal.aborted) {
        return;
      }
      const draft = await command({
        accessToken,
        aircraftId: intention.aircraftId,
        anonKey: config.anonKey,
        arrivalIcao: intention.arrivalIcao,
        departureIcao: intention.departureIcao,
        idempotencyKey,
        signal: abortController.signal,
        supabaseUrl: config.supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        setState({ draft, intentionKey: toIntentionKey(intention), kind: "created" });
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (
          (error instanceof SessionError && error.failure === "authentication-required") ||
          (error instanceof DispatchDraftError && error.failure === "authentication-required")
        ) {
          sessionManager.clear();
          onAuthenticationRequired();
        } else if (error instanceof DispatchDraftError && error.failure === "rejected") {
          setState({ kind: "rejected" });
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
    <section className="dispatch-panel" aria-labelledby={`${fieldId}-title`}>
      <h2 id={`${fieldId}-title`}>Préparer un vol</h2>
      <form onSubmit={(event) => void submit(event)}>
        <label htmlFor={`${fieldId}-aircraft`}>Avion</label>
        <select
          id={`${fieldId}-aircraft`}
          aria-required="true"
          disabled={state.kind === "pending"}
          value={selectedAircraft?.id ?? ""}
          onChange={(event) => setSelectedAircraftId(event.currentTarget.value)}
        >
          <option value="">Choisir un avion de la flotte</option>
          {aircraft.map((item) => (
            <option key={item.id} value={item.id}>
              {item.displayName} · {item.aircraftTypeCode} · {item.serialNumber}
            </option>
          ))}
        </select>

        <label htmlFor={`${fieldId}-departure`}>Aérodrome de départ (OACI)</label>
        <input
          id={`${fieldId}-departure`}
          type="text"
          autoComplete="off"
          disabled={state.kind === "pending"}
          maxLength={4}
          required
          value={departureIcao}
          onChange={(event) => setDepartureIcao(event.currentTarget.value)}
        />

        <label htmlFor={`${fieldId}-arrival`}>Aérodrome d’arrivée (OACI)</label>
        <input
          id={`${fieldId}-arrival`}
          type="text"
          autoComplete="off"
          disabled={state.kind === "pending"}
          maxLength={4}
          required
          value={arrivalIcao}
          onChange={(event) => setArrivalIcao(event.currentTarget.value)}
        />

        <button type="submit" disabled={disabled}>
          {state.kind === "pending"
            ? "Préparation…"
            : submittedIntentionKey === currentIntentionKey
              ? "Brouillon créé"
              : state.kind === "unavailable"
                ? "Réessayer"
                : "Préparer le vol"}
        </button>
      </form>

      <div aria-live="polite" aria-atomic="true">
        {state.kind === "ready" && (
          <p>Choisissez un avion et deux aérodromes distincts pour préparer un vol.</p>
        )}
        {state.kind === "pending" && <p>Préparation sécurisée du brouillon.</p>}
        {state.kind === "created" && (
          <p>
            Brouillon créé pour {state.draft.departureIcao} → {state.draft.arrivalIcao}, préparé le
            {" "}
            {createdAtFormatter.format(new Date(state.draft.createdAt))} UTC.
          </p>
        )}
      </div>

      {state.kind === "rejected" && (
        <p role="alert">
          La préparation a été refusée. Vérifiez l’avion choisi et deux codes OACI distincts de
          quatre caractères.
        </p>
      )}
      {state.kind === "unavailable" && (
        <p role="alert">
          Le service de préparation est indisponible. Réessayez dans quelques instants.
        </p>
      )}
    </section>
  );
}
