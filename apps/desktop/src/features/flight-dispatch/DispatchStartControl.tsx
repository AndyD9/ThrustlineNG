import { useEffect, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  FlightStartError,
  type StartFlightInput,
  startFlight,
  type StartedFlight,
} from "@/features/flight-dispatch/flightStart";

export type FlightStartCommand = (input: StartFlightInput) => Promise<StartedFlight>;

export interface DispatchStartControlProps {
  command?: FlightStartCommand | undefined;
  config: DesktopConnectionConfig;
  createIdempotencyKey?: (() => string) | undefined;
  dispatchId: string;
  flightLabel: string;
  onAuthenticationRequired: () => void;
  onFlightStarted?: (() => void) | undefined;
  sessionManager: DesktopSessionManager;
}

type ControlState =
  | { kind: "ready" }
  | { kind: "pending" }
  | { kind: "started"; startedAt: string }
  | { kind: "rejected" }
  | { kind: "unavailable" };

const defaultIdempotencyKeyFactory = () => crypto.randomUUID();

const startedAtFormatter = new Intl.DateTimeFormat("fr-FR", {
  dateStyle: "short",
  timeStyle: "short",
  timeZone: "UTC",
});

export function DispatchStartControl({
  command = startFlight,
  config,
  createIdempotencyKey = defaultIdempotencyKeyFactory,
  dispatchId,
  flightLabel,
  onAuthenticationRequired,
  onFlightStarted,
  sessionManager,
}: DispatchStartControlProps) {
  const [state, setState] = useState<ControlState>({ kind: "ready" });
  const abortControllerRef = useRef<AbortController | null>(null);
  const intentionRef = useRef<{ dispatchId: string; idempotencyKey: string } | null>(null);
  const pendingRef = useRef(false);

  useEffect(() => () => abortControllerRef.current?.abort(), []);

  const disabled = state.kind === "pending" || state.kind === "started";

  const start = async () => {
    if (pendingRef.current || disabled) {
      return;
    }

    pendingRef.current = true;
    const previousIntention = intentionRef.current;
    const idempotencyKey =
      previousIntention !== null && previousIntention.dispatchId === dispatchId
        ? previousIntention.idempotencyKey
        : createIdempotencyKey();
    intentionRef.current = { dispatchId, idempotencyKey };
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
    setState({ kind: "pending" });

    try {
      const accessToken = await sessionManager.getAccessToken();
      if (abortController.signal.aborted) {
        return;
      }
      const flight = await command({
        accessToken,
        anonKey: config.anonKey,
        dispatchId,
        idempotencyKey,
        signal: abortController.signal,
        supabaseUrl: config.supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        setState({ kind: "started", startedAt: flight.startedAt });
        onFlightStarted?.();
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (
          (error instanceof SessionError && error.failure === "authentication-required") ||
          (error instanceof FlightStartError && error.failure === "authentication-required")
        ) {
          sessionManager.clear();
          onAuthenticationRequired();
        } else if (error instanceof FlightStartError && error.failure === "rejected") {
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

  const actionLabel =
    state.kind === "pending"
      ? "Démarrage…"
      : state.kind === "started"
        ? "Vol démarré"
        : state.kind === "unavailable"
          ? "Réessayer"
          : "Démarrer le vol";

  return (
    <span className="dispatch-start-control">
      <button
        type="button"
        aria-label={`${actionLabel} · ${flightLabel}`}
        disabled={disabled}
        onClick={() => void start()}
      >
        {actionLabel}
      </button>

      <span aria-live="polite" aria-atomic="true">
        {state.kind === "pending" && <span>Démarrage sécurisé du vol.</span>}
        {state.kind === "started" && (
          <span>
            Vol démarré le {startedAtFormatter.format(new Date(state.startedAt))} UTC.
          </span>
        )}
      </span>

      {state.kind === "rejected" && (
        <span role="alert">
          Le démarrage a été refusé. Actualisez vos dispatchs puis réessayez.
        </span>
      )}
      {state.kind === "unavailable" && (
        <span role="alert">
          Le service de démarrage est indisponible. Réessayez dans quelques instants.
        </span>
      )}
    </span>
  );
}
