import { useEffect, useId, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  CompanyPresenceError,
  loadCompanyPresence,
  type LoadCompanyPresenceInput,
} from "@/features/company-state/companyState";

export type CompanyPresenceCommand = (
  input: LoadCompanyPresenceInput,
) => Promise<boolean>;

export interface CompanyPresencePanelProps {
  command?: CompanyPresenceCommand | undefined;
  config: DesktopConnectionConfig;
  onAuthenticationRequired: () => void;
  onResolved: (hasCompany: boolean) => void;
  sessionManager: DesktopSessionManager;
}

type PanelState = "ready" | "pending" | "unavailable";

export function CompanyPresencePanel({
  command = loadCompanyPresence,
  config,
  onAuthenticationRequired,
  onResolved,
  sessionManager,
}: CompanyPresencePanelProps) {
  const titleId = useId();
  const [state, setState] = useState<PanelState>("ready");
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
    setState("pending");

    try {
      const accessToken = await sessionManager.getAccessToken();
      if (abortController.signal.aborted) {
        return;
      }
      const hasCompany = await command({
        accessToken,
        anonKey: config.anonKey,
        signal: abortController.signal,
        supabaseUrl: config.supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        onResolved(hasCompany);
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (
          (error instanceof SessionError && error.failure === "authentication-required") ||
          (error instanceof CompanyPresenceError &&
            error.failure === "authentication-required")
        ) {
          sessionManager.clear();
          onAuthenticationRequired();
        } else {
          setState("unavailable");
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
    <section className="company-presence-panel" aria-labelledby={titleId}>
      <h2 id={titleId}>Reprendre votre compagnie</h2>
      <p>Vérifiez votre état avant de poursuivre.</p>
      <button type="button" disabled={state === "pending"} onClick={() => void load()}>
        {state === "pending"
          ? "Vérification…"
          : state === "unavailable"
            ? "Réessayer"
            : "Vérifier ma compagnie"}
      </button>
      <div aria-live="polite" aria-atomic="true">
        {state === "pending" && <p>Vérification sécurisée en cours.</p>}
      </div>
      {state === "unavailable" && (
        <p role="alert">L’état de votre compagnie est indisponible. Réessayez.</p>
      )}
    </section>
  );
}
