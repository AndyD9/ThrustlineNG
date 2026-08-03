import { useCallback, useEffect, useId, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  AircraftFleetError,
  type CompanyAircraft,
  loadAircraftFleet,
  type LoadAircraftFleetInput,
} from "@/features/aircraft-fleet/aircraftFleet";

export type AircraftFleetCommand = (
  input: LoadAircraftFleetInput,
) => Promise<CompanyAircraft[]>;

export interface AircraftFleetPanelProps {
  command?: AircraftFleetCommand | undefined;
  config: DesktopConnectionConfig;
  onAuthenticationRequired: () => void;
  refreshVersion?: number | undefined;
  sessionManager: DesktopSessionManager;
}

type PanelState =
  | { kind: "ready" }
  | { kind: "pending" }
  | { aircraft: CompanyAircraft[]; kind: "loaded" }
  | { kind: "unavailable" };

export function AircraftFleetPanel({
  command = loadAircraftFleet,
  config,
  onAuthenticationRequired,
  refreshVersion = 0,
  sessionManager,
}: AircraftFleetPanelProps) {
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
      const aircraft = await command({
        accessToken,
        anonKey: config.anonKey,
        signal: abortController.signal,
        supabaseUrl: config.supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        loadedOnceRef.current = true;
        setState({ aircraft, kind: "loaded" });
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (
          (error instanceof SessionError && error.failure === "authentication-required") ||
          (error instanceof AircraftFleetError && error.failure === "authentication-required")
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
      <h2 id={titleId}>Ma flotte</h2>
      <button type="button" disabled={state.kind === "pending"} onClick={() => void load()}>
        {state.kind === "pending"
          ? "Actualisation…"
          : state.kind === "unavailable"
            ? "Réessayer"
            : state.kind === "loaded"
              ? "Actualiser la flotte"
              : "Afficher ma flotte"}
      </button>

      <div aria-live="polite" aria-atomic="true">
        {state.kind === "ready" && <p>Chargez votre flotte lorsque vous êtes prêt.</p>}
        {state.kind === "pending" && <p>Chargement sécurisé de la flotte.</p>}
        {state.kind === "loaded" && state.aircraft.length === 0 && (
          <p>Votre flotte ne contient encore aucun avion.</p>
        )}
      </div>

      {state.kind === "loaded" && state.aircraft.length > 0 && (
        <ul aria-label="Avions de la flotte">
          {state.aircraft.map((aircraft) => (
            <li key={aircraft.id}>
              <strong>{aircraft.displayName}</strong>{" "}
              <span>{aircraft.aircraftTypeCode} · {aircraft.serialNumber}</span>
            </li>
          ))}
        </ul>
      )}
      {state.kind === "unavailable" && (
        <p role="alert">La flotte est indisponible. Réessayez dans quelques instants.</p>
      )}
    </section>
  );
}
