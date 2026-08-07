import { useRef, useState } from "react";

import {
  type FlightSummary,
  readFlightSummary,
} from "@/features/flight-dispatch/flightSummary";
import { invokeFlightSummaryThroughShell } from "@/features/flight-dispatch/flightSummaryShell";

export type FlightSummaryCommand = () => Promise<FlightSummary>;

export interface FlightSummaryControlProps {
  command?: FlightSummaryCommand | undefined;
  dispatchId: string;
  flightLabel: string;
}

type ControlState =
  | { kind: "ready" }
  | { kind: "pending" }
  | { kind: "measured"; summary: FlightSummary }
  | { kind: "unavailable" };

const defaultCommand: FlightSummaryCommand = () =>
  readFlightSummary(invokeFlightSummaryThroughShell);

export function FlightSummaryControl({
  command = defaultCommand,
  dispatchId,
  flightLabel,
}: FlightSummaryControlProps) {
  const [state, setState] = useState<ControlState>({ kind: "ready" });
  const pendingRef = useRef(false);

  const measure = async () => {
    if (pendingRef.current) {
      return;
    }
    pendingRef.current = true;
    setState({ kind: "pending" });
    try {
      const summary = await command();
      setState({ kind: "measured", summary });
    } catch {
      setState({ kind: "unavailable" });
    } finally {
      pendingRef.current = false;
    }
  };

  const actionLabel =
    state.kind === "pending"
      ? "Lecture…"
      : state.kind === "measured"
        ? "Actualiser la mesure"
        : state.kind === "unavailable"
          ? "Réessayer"
          : "Afficher le temps de bloc";

  // Fail-closed : seule une mesure rattachée à ce dispatch est parlée pour
  // cette ligne (F0006) ; une mesure d'un autre vol ou d'une session non
  // armée n'est jamais attribuée.
  const attached =
    state.kind === "measured" && state.summary.attachedDispatchId === dispatchId;

  return (
    <span className="flight-summary-control">
      <button
        type="button"
        aria-label={`${actionLabel} · ${flightLabel}`}
        disabled={state.kind === "pending"}
        onClick={() => void measure()}
      >
        {actionLabel}
      </button>

      <span aria-live="polite" aria-atomic="true">
        {state.kind === "pending" && <span>Lecture du résumé de vol.</span>}
        {state.kind === "measured" && !attached && (
          <span>Aucune mesure rattachée à ce vol.</span>
        )}
        {attached && state.kind === "measured" && state.summary.state === "completed" && (
          <span>Temps de bloc mesuré : {state.summary.blockMinutes} min.</span>
        )}
        {attached && state.kind === "measured" && state.summary.state === "running" && (
          <span>Replay en cours : la mesure se poursuit.</span>
        )}
        {attached && state.kind === "measured" && state.summary.state === "incomplete" && (
          <span>Trace incomplète : aucun temps de bloc mesuré.</span>
        )}
        {attached && state.kind === "measured" && state.summary.state === "idle" && (
          <span>Mesure armée : aucun replay mesuré pour l’instant.</span>
        )}
      </span>

      {state.kind === "unavailable" && (
        <span role="alert">
          La mesure du temps de bloc est indisponible. Réessayez dans quelques instants.
        </span>
      )}
    </span>
  );
}
