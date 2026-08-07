import { useEffect, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  type ClosedFlight,
  type CloseFlightInput,
  closeFlight,
  FlightCloseError,
} from "@/features/flight-dispatch/flightClose";
import { readFlightSummary } from "@/features/flight-dispatch/flightSummary";
import type { FlightSummaryCommand } from "@/features/flight-dispatch/FlightSummaryControl";
import { invokeFlightSummaryThroughShell } from "@/features/flight-dispatch/flightSummaryShell";

export type FlightCloseCommand = (input: CloseFlightInput) => Promise<ClosedFlight>;

export interface FlightCloseControlProps {
  command?: FlightCloseCommand | undefined;
  config: DesktopConnectionConfig;
  createIdempotencyKey?: (() => string) | undefined;
  dispatchId: string;
  flightLabel: string;
  onAuthenticationRequired: () => void;
  onFlightClosed?: (() => void) | undefined;
  sessionManager: DesktopSessionManager;
  summaryCommand?: FlightSummaryCommand | undefined;
}

type ControlState =
  | { kind: "ready" }
  | { kind: "pending" }
  | { kind: "unmeasured" }
  | { kind: "unattached" }
  | { kind: "closed"; flight: ClosedFlight }
  | { kind: "rejected" }
  | { kind: "unavailable" };

const defaultIdempotencyKeyFactory = () => crypto.randomUUID();

const defaultSummaryCommand: FlightSummaryCommand = () =>
  readFlightSummary(invokeFlightSummaryThroughShell);

const amountFormatter = (currencyCode: string) =>
  new Intl.NumberFormat("fr-FR", { currency: currencyCode, style: "currency" });

export function FlightCloseControl({
  command = closeFlight,
  config,
  createIdempotencyKey = defaultIdempotencyKeyFactory,
  dispatchId,
  flightLabel,
  onAuthenticationRequired,
  onFlightClosed,
  sessionManager,
  summaryCommand = defaultSummaryCommand,
}: FlightCloseControlProps) {
  const [state, setState] = useState<ControlState>({ kind: "ready" });
  const abortControllerRef = useRef<AbortController | null>(null);
  const intentionRef = useRef<{
    blockMinutes: number;
    dispatchId: string;
    idempotencyKey: string;
  } | null>(null);
  const pendingRef = useRef(false);

  useEffect(() => () => abortControllerRef.current?.abort(), []);

  const disabled = state.kind === "pending" || state.kind === "closed";

  const close = async () => {
    if (pendingRef.current || disabled) {
      return;
    }

    pendingRef.current = true;
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
    setState({ kind: "pending" });

    try {
      const summary = await summaryCommand();
      if (abortController.signal.aborted) {
        return;
      }
      if (summary.state !== "completed" || summary.blockMinutes === null) {
        setState({ kind: "unmeasured" });
        return;
      }
      // Branchement F0006 : la mesure doit être rattachée au vol clôturé —
      // celle d'un autre vol ou d'une session non armée ne règle jamais.
      if (summary.attachedDispatchId !== dispatchId) {
        setState({ kind: "unattached" });
        return;
      }

      // The idempotency key is pinned to the exact report it first signed: a
      // retry replays the same settlement, while a new measurement starts a
      // new intention instead of colliding with the recorded payload.
      const previousIntention = intentionRef.current;
      const idempotencyKey =
        previousIntention !== null &&
        previousIntention.dispatchId === dispatchId &&
        previousIntention.blockMinutes === summary.blockMinutes
          ? previousIntention.idempotencyKey
          : createIdempotencyKey();
      intentionRef.current = { blockMinutes: summary.blockMinutes, dispatchId, idempotencyKey };

      const accessToken = await sessionManager.getAccessToken();
      if (abortController.signal.aborted) {
        return;
      }
      const flight = await command({
        accessToken,
        anonKey: config.anonKey,
        blockMinutes: summary.blockMinutes,
        dispatchId,
        idempotencyKey,
        signal: abortController.signal,
        supabaseUrl: config.supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        setState({ flight, kind: "closed" });
        onFlightClosed?.();
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (
          (error instanceof SessionError && error.failure === "authentication-required") ||
          (error instanceof FlightCloseError && error.failure === "authentication-required")
        ) {
          sessionManager.clear();
          onAuthenticationRequired();
        } else if (error instanceof FlightCloseError && error.failure === "rejected") {
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
      ? "Clôture…"
      : state.kind === "closed"
        ? "Vol clôturé"
        : state.kind === "unavailable" || state.kind === "unmeasured" || state.kind === "unattached"
          ? "Réessayer la clôture"
          : "Clôturer le vol";

  return (
    <span className="flight-close-control">
      <button
        type="button"
        aria-label={`${actionLabel} · ${flightLabel}`}
        disabled={disabled}
        onClick={() => void close()}
      >
        {actionLabel}
      </button>

      <span aria-live="polite" aria-atomic="true">
        {state.kind === "pending" && <span>Clôture sécurisée du vol.</span>}
        {state.kind === "closed" && (
          <span>
            Vol clôturé : revenu net{" "}
            {amountFormatter(state.flight.currencyCode).format(
              state.flight.settledAmountMinor / 100,
            )}
            , temps de bloc retenu {state.flight.blockMinutes} min.
          </span>
        )}
      </span>

      {state.kind === "unmeasured" && (
        <span role="alert">
          La clôture attend le temps de bloc mesuré : terminez le replay puis réessayez.
        </span>
      )}
      {state.kind === "unattached" && (
        <span role="alert">
          La clôture attend une mesure rattachée à ce vol : la dernière mesure
          appartient à un autre vol ou à une session non armée.
        </span>
      )}
      {state.kind === "rejected" && (
        <span role="alert">
          La clôture a été refusée. Actualisez vos dispatchs puis réessayez.
        </span>
      )}
      {state.kind === "unavailable" && (
        <span role="alert">
          Le service de clôture est indisponible. Réessayez dans quelques instants.
        </span>
      )}
    </span>
  );
}
