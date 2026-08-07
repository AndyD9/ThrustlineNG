import { useRef, useState } from "react";

import {
  type FlightSummary,
  readFlightSummary,
} from "@/features/flight-dispatch/flightSummary";
import { invokeFlightSummaryThroughShell } from "@/features/flight-dispatch/flightSummaryShell";

export type FlightSummaryCommand = () => Promise<FlightSummary>;

export interface FlightSummaryControlProps {
  command?: FlightSummaryCommand | undefined;
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
        {state.kind === "measured" && state.summary.state === "completed" && (
          // Le résumé du bridge ne porte pas d'identité de vol et son tracker
          // est terminal pour la session : le libellé ne rattache donc pas la
          // mesure au vol de la ligne (KI-028, rattachement prévu par F0002).
          <span>
            Dernière mesure de replay de la session : {state.summary.blockMinutes} min.
          </span>
        )}
        {state.kind === "measured" && state.summary.state === "running" && (
          <span>Replay en cours : la mesure se poursuit.</span>
        )}
        {state.kind === "measured" && state.summary.state === "incomplete" && (
          <span>Trace incomplète : aucun temps de bloc mesuré.</span>
        )}
        {state.kind === "measured" && state.summary.state === "idle" && (
          <span>Aucun replay mesuré pour l’instant.</span>
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
