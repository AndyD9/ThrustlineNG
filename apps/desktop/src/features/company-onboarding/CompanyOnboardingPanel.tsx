import { type FormEvent, useEffect, useId, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { type DesktopSessionManager, SessionError } from "@/features/auth/session";
import {
  CompanyOnboardingError,
  type CompanyOnboardingResult,
  normalizeCompanyName,
  onboardCompany,
  type OnboardCompanyInput,
} from "@/features/company-onboarding/companyOnboarding";

export type CompanyOnboardingCommand = (
  input: OnboardCompanyInput,
) => Promise<CompanyOnboardingResult>;

export interface CompanyOnboardingPanelProps {
  command?: CompanyOnboardingCommand | undefined;
  config: DesktopConnectionConfig;
  createIdempotencyKey?: (() => string) | undefined;
  onAuthenticationRequired: () => void;
  sessionManager: DesktopSessionManager;
}

type PanelState = "active" | "pending" | "ready" | "rejected" | "unavailable";

interface OnboardingIntention {
  companyName: string;
  idempotencyKey: string;
}

const defaultIdempotencyKeyFactory = () => crypto.randomUUID();

export function CompanyOnboardingPanel({
  command = onboardCompany,
  config,
  createIdempotencyKey = defaultIdempotencyKeyFactory,
  onAuthenticationRequired,
  sessionManager,
}: CompanyOnboardingPanelProps) {
  const nameId = useId();
  const [companyName, setCompanyName] = useState("");
  const [state, setState] = useState<PanelState>("ready");
  const abortControllerRef = useRef<AbortController | null>(null);
  const intentionRef = useRef<OnboardingIntention | null>(null);
  const pendingRef = useRef(false);

  useEffect(() => () => abortControllerRef.current?.abort(), []);

  const requireAuthentication = () => {
    sessionManager.clear();
    onAuthenticationRequired();
  };

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (pendingRef.current || state === "active") {
      return;
    }

    let normalizedName: string;
    try {
      normalizedName = normalizeCompanyName(companyName);
    } catch {
      setState("rejected");
      return;
    }

    pendingRef.current = true;
    const previousIntention = intentionRef.current;
    const intention = previousIntention?.companyName === normalizedName
      ? previousIntention
      : { companyName: normalizedName, idempotencyKey: createIdempotencyKey() };
    intentionRef.current = intention;
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
    setState("pending");

    try {
      const accessToken = await sessionManager.getAccessToken();
      if (abortController.signal.aborted) {
        return;
      }
      await command({
        accessToken,
        anonKey: config.anonKey,
        companyName: intention.companyName,
        idempotencyKey: intention.idempotencyKey,
        signal: abortController.signal,
        supabaseUrl: config.supabaseUrl,
      });
      if (!abortController.signal.aborted) {
        setCompanyName("");
        setState("active");
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        if (
          (error instanceof SessionError && error.failure === "authentication-required") ||
          (error instanceof CompanyOnboardingError &&
            error.failure === "authentication-required")
        ) {
          requireAuthentication();
        } else if (
          error instanceof CompanyOnboardingError &&
          error.failure === "rejected"
        ) {
          setState("rejected");
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

  const disabled = state === "pending" || state === "active";

  return (
    <section className="onboarding-panel" aria-labelledby={`${nameId}-title`}>
      <h2 id={`${nameId}-title`}>Créer votre compagnie</h2>
      <form onSubmit={(event) => void submit(event)}>
        <label htmlFor={nameId}>Nom de la compagnie</label>
        <input
          id={nameId}
          type="text"
          autoComplete="off"
          disabled={disabled}
          maxLength={80}
          minLength={2}
          required
          value={companyName}
          onChange={(event) => setCompanyName(event.currentTarget.value)}
        />
        <button type="submit" disabled={disabled}>
          {state === "pending"
            ? "Création…"
            : state === "active"
              ? "Compagnie créée"
              : state === "unavailable"
                ? "Réessayer"
                : "Créer la compagnie"}
        </button>
      </form>

      <div aria-live="polite" aria-atomic="true">
        {state === "ready" && <p>Choisissez le nom de votre compagnie pour commencer.</p>}
        {state === "pending" && <p>Création sécurisée en cours.</p>}
        {state === "active" && <p>Votre compagnie est active.</p>}
      </div>
      {state === "rejected" && (
        <p role="alert">
          La création a été refusée. Vérifiez le nom ou l’état de votre compte.
        </p>
      )}
      {state === "unavailable" && (
        <p role="alert">
          Le service de création est indisponible. Réessayez dans quelques instants.
        </p>
      )}
    </section>
  );
}
