import { useState } from "react";
import { HashRouter } from "react-router";

import { AppErrorBoundary } from "@/app/AppErrorBoundary";
import { AppRoutes } from "@/app/routes";
import {
  readBundledDesktopConnectionConfig,
  type DesktopConnectionConfig,
} from "@/features/auth/connectionConfig";
import type { SignInCommand } from "@/features/auth/PasswordSignInPanel";
import { DesktopSessionManager } from "@/features/auth/session";

export interface DesktopAuthRuntime {
  config: DesktopConnectionConfig;
  sessionManager: DesktopSessionManager;
}

export interface AppProps {
  authRuntime?: DesktopAuthRuntime;
  signInCommand?: SignInCommand | undefined;
}

function createBundledAuthRuntime(): DesktopAuthRuntime {
  const config = readBundledDesktopConnectionConfig();
  return { config, sessionManager: new DesktopSessionManager(config) };
}

function AppContent({ authRuntime, signInCommand }: AppProps) {
  const [runtime] = useState(() => authRuntime ?? createBundledAuthRuntime());
  const [authenticated, setAuthenticated] = useState(() => runtime.sessionManager.hasSession());

  const signOut = () => {
    runtime.sessionManager.clear();
    setAuthenticated(false);
  };

  return (
    <HashRouter>
      <div className="app-shell">
        <header className="app-header">
          <span className="brand">Thrustline</span>
          <span className="baseline-label">
            {authenticated ? "Session locale" : "Connexion requise"}
          </span>
        </header>
        <AppRoutes
          authenticated={authenticated}
          config={runtime.config}
          onAuthenticated={() => setAuthenticated(runtime.sessionManager.hasSession())}
          onSignOut={signOut}
          sessionManager={runtime.sessionManager}
          signInCommand={signInCommand}
        />
      </div>
    </HashRouter>
  );
}

export function App(props: AppProps) {
  return (
    <AppErrorBoundary>
      <AppContent {...props} />
    </AppErrorBoundary>
  );
}
