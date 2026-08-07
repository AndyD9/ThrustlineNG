import { useCallback, useEffect, useId, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  type CompanyDispatch,
  type DispatchState,
  DispatchListError,
  loadDispatchList,
  type LoadDispatchListInput,
} from "@/features/flight-dispatch/dispatchList";
import {
  DispatchStartControl,
  type FlightStartCommand,
} from "@/features/flight-dispatch/DispatchStartControl";
import {
  FlightSummaryControl,
  type FlightSummaryCommand,
} from "@/features/flight-dispatch/FlightSummaryControl";

export type DispatchListCommand = (
  input: LoadDispatchListInput,
) => Promise<CompanyDispatch[]>;

export interface DispatchListPanelProps {
  command?: DispatchListCommand | undefined;
  config: DesktopConnectionConfig;
  createIdempotencyKey?: (() => string) | undefined;
  onAuthenticationRequired: () => void;
  refreshVersion?: number | undefined;
  sessionManager: DesktopSessionManager;
  startCommand?: FlightStartCommand | undefined;
  summaryCommand?: FlightSummaryCommand | undefined;
}

type PanelState =
  | { kind: "ready" }
  | { kind: "pending" }
  | { dispatches: CompanyDispatch[]; kind: "loaded" }
  | { kind: "unavailable" };

const stateLabels: Record<DispatchState, string> = {
  active: "En vol",
  draft: "Brouillon",
};

const createdAtFormatter = new Intl.DateTimeFormat("fr-FR", {
  dateStyle: "short",
  timeStyle: "short",
  timeZone: "UTC",
});

export function DispatchListPanel({
  command = loadDispatchList,
  config,
  createIdempotencyKey,
  onAuthenticationRequired,
  refreshVersion = 0,
  sessionManager,
  startCommand,
  summaryCommand,
}: DispatchListPanelProps) {
  const titleId = useId();
  const [state, setState] = useState<PanelState>({ kind: "ready" });
  const abortControllerRef = useRef<AbortController | null>(null);
  const handledRefreshVersionRef = useRef(0);
  const loadedOnceRef = useRef(false);
  const pendingRef = useRef(false);

  const load = useCallback(async () => {
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
      const dispatches = await command({
        accessToken,
        anonKey: config.anonKey,
        signal: abortController.signal,
        supabaseUrl: config.supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        loadedOnceRef.current = true;
        setState({ dispatches, kind: "loaded" });
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (
          (error instanceof SessionError && error.failure === "authentication-required") ||
          (error instanceof DispatchListError && error.failure === "authentication-required")
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
  }, [command, config.anonKey, config.supabaseUrl, onAuthenticationRequired, sessionManager]);

  useEffect(() => () => abortControllerRef.current?.abort(), []);

  // Le résumé du bridge est global et sans identité de vol : il ne peut être
  // rattaché à une ligne que lorsqu'un seul vol est actif (l'exclusivité
  // serveur est par avion, pas par compagnie).
  const activeCount =
    state.kind === "loaded"
      ? state.dispatches.filter((dispatch) => dispatch.state === "active").length
      : 0;
  useEffect(() => {
    if (
      refreshVersion > handledRefreshVersionRef.current &&
      loadedOnceRef.current &&
      !pendingRef.current
    ) {
      handledRefreshVersionRef.current = refreshVersion;
      void load();
    }
  }, [load, refreshVersion, state.kind]);

  return (
    <section aria-labelledby={titleId}>
      <h2 id={titleId}>Mes dispatchs</h2>
      <button type="button" disabled={state.kind === "pending"} onClick={() => void load()}>
        {state.kind === "pending"
          ? "Actualisation…"
          : state.kind === "unavailable"
            ? "Réessayer"
            : state.kind === "loaded"
              ? "Actualiser les dispatchs"
              : "Afficher mes dispatchs"}
      </button>

      <div aria-live="polite" aria-atomic="true">
        {state.kind === "ready" && <p>Chargez vos dispatchs lorsque vous êtes prêt.</p>}
        {state.kind === "pending" && <p>Chargement sécurisé des dispatchs.</p>}
        {state.kind === "loaded" && state.dispatches.length === 0 && (
          <p>Aucun dispatch n’est encore préparé.</p>
        )}
      </div>

      {state.kind === "loaded" && state.dispatches.length > 0 && (
        <ul aria-label="Dispatchs de la compagnie">
          {state.dispatches.map((dispatch) => (
            <li key={dispatch.id}>
              <strong>
                {dispatch.departureIcao} → {dispatch.arrivalIcao}
              </strong>{" "}
              <span>
                {stateLabels[dispatch.state]} ·{" "}
                {createdAtFormatter.format(new Date(dispatch.createdAt))} UTC
                {dispatch.state === "active" && dispatch.startedAt !== null && (
                  <>
                    {" "}· départ {createdAtFormatter.format(new Date(dispatch.startedAt))} UTC
                  </>
                )}
              </span>
              {dispatch.state === "active" && activeCount === 1 && (
                <FlightSummaryControl
                  command={summaryCommand}
                  flightLabel={`${dispatch.departureIcao} → ${dispatch.arrivalIcao}`}
                />
              )}
              {dispatch.state === "draft" && (
                <DispatchStartControl
                  command={startCommand}
                  config={config}
                  createIdempotencyKey={createIdempotencyKey}
                  dispatchId={dispatch.id}
                  flightLabel={`${dispatch.departureIcao} → ${dispatch.arrivalIcao}`}
                  onAuthenticationRequired={onAuthenticationRequired}
                  onFlightStarted={() => void load()}
                  sessionManager={sessionManager}
                />
              )}
            </li>
          ))}
        </ul>
      )}
      {state.kind === "unavailable" && (
        <p role="alert">Les dispatchs sont indisponibles. Réessayez dans quelques instants.</p>
      )}
    </section>
  );
}
