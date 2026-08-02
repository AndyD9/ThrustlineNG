import { Navigate, Route, Routes } from "react-router";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import type { SignInCommand } from "@/features/auth/PasswordSignInPanel";
import type { DesktopSessionManager } from "@/features/auth/session";
import { HomePage } from "@/pages/HomePage";
import { LoginPage } from "@/pages/LoginPage";
import { NotFoundPage } from "@/pages/NotFoundPage";

export interface AppRoutesProps {
  authenticated: boolean;
  config: DesktopConnectionConfig;
  onAuthenticated: () => void;
  onSignOut: () => void;
  sessionManager: DesktopSessionManager;
  signInCommand?: SignInCommand | undefined;
}

export function AppRoutes({
  authenticated,
  config,
  onAuthenticated,
  onSignOut,
  sessionManager,
  signInCommand,
}: AppRoutesProps) {
  return (
    <Routes>
      <Route
        path="/"
        element={authenticated ? <HomePage onSignOut={onSignOut} /> : <Navigate replace to="/login" />}
      />
      <Route
        path="/login"
        element={authenticated
          ? <Navigate replace to="/" />
          : (
              <LoginPage
                command={signInCommand}
                config={config}
                onAuthenticated={onAuthenticated}
                sessionManager={sessionManager}
              />
            )}
      />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
