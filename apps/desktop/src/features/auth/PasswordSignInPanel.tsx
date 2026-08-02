import { type FormEvent, useEffect, useId, useRef, useState } from "react";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import {
  PasswordSignInError,
  signInWithPassword,
  type PasswordSignInInput,
} from "@/features/auth/passwordSignIn";
import { type DesktopSessionManager, type UserSessionTokens } from "@/features/auth/session";

export type SignInCommand = (input: PasswordSignInInput) => Promise<UserSessionTokens>;

export interface PasswordSignInPanelProps {
  command?: SignInCommand | undefined;
  config: DesktopConnectionConfig;
  onAuthenticated?: () => void;
  sessionManager: DesktopSessionManager;
}

type PanelState = "authenticated" | "pending" | "ready" | "rejected" | "unavailable";

export function PasswordSignInPanel({
  command = signInWithPassword,
  config,
  onAuthenticated,
  sessionManager,
}: PasswordSignInPanelProps) {
  const emailId = useId();
  const passwordId = useId();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [state, setState] = useState<PanelState>("ready");
  const abortControllerRef = useRef<AbortController | null>(null);
  const pendingRef = useRef(false);

  useEffect(() => () => abortControllerRef.current?.abort(), []);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (pendingRef.current || state === "authenticated") {
      return;
    }

    pendingRef.current = true;
    const submittedPassword = password;
    setPassword("");
    const abortController = new AbortController();
    abortControllerRef.current = abortController;
    setState("pending");

    try {
      const session = await command({
        config,
        email,
        password: submittedPassword,
        signal: abortController.signal,
      });
      if (!abortController.signal.aborted) {
        sessionManager.setSession(session);
        setEmail("");
        setState("authenticated");
        onAuthenticated?.();
      }
    } catch (error) {
      if (!abortController.signal.aborted) {
        setState(error instanceof PasswordSignInError && error.failure === "rejected"
          ? "rejected"
          : "unavailable");
      }
    } finally {
      if (abortControllerRef.current === abortController) {
        abortControllerRef.current = null;
        pendingRef.current = false;
      }
    }
  };

  const disabled = state === "pending" || state === "authenticated";

  return (
    <section aria-labelledby={`${emailId}-title`}>
      <h2 id={`${emailId}-title`}>Connexion à Thrustline</h2>
      <form autoComplete="off" onSubmit={(event) => void submit(event)}>
        <label htmlFor={emailId}>Adresse email</label>
        <input
          id={emailId}
          type="email"
          autoComplete="off"
          disabled={disabled}
          maxLength={254}
          required
          value={email}
          onChange={(event) => setEmail(event.currentTarget.value)}
        />
        <label htmlFor={passwordId}>Mot de passe</label>
        <input
          id={passwordId}
          type="password"
          autoComplete="off"
          disabled={disabled}
          maxLength={1_024}
          required
          value={password}
          onChange={(event) => setPassword(event.currentTarget.value)}
        />
        <button type="submit" disabled={disabled}>
          {state === "pending" ? "Connexion…" : state === "authenticated" ? "Connecté" : "Se connecter"}
        </button>
      </form>

      <div aria-live="polite" aria-atomic="true">
        {state === "ready" && <p>Utilisez votre compte Thrustline pour continuer.</p>}
        {state === "pending" && <p>Connexion sécurisée en cours.</p>}
        {state === "authenticated" && <p>Connexion réussie pour cette session.</p>}
      </div>
      {state === "rejected" && (
        <p role="alert">Email ou mot de passe incorrect. Vérifiez vos informations et réessayez.</p>
      )}
      {state === "unavailable" && (
        <p role="alert">Le service de connexion est indisponible. Réessayez dans quelques instants.</p>
      )}
    </section>
  );
}
