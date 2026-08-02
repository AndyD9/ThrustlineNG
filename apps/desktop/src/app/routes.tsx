import { Navigate, Route, Routes } from "react-router";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import type { SignInCommand } from "@/features/auth/PasswordSignInPanel";
import type { DesktopSessionManager } from "@/features/auth/session";
import type { CompanyOnboardingCommand } from "@/features/company-onboarding/CompanyOnboardingPanel";
import { HomePage } from "@/pages/HomePage";
import { LoginPage } from "@/pages/LoginPage";
import { NotFoundPage } from "@/pages/NotFoundPage";

export interface AppRoutesProps {
  authenticated: boolean;
  companyOnboardingCommand?: CompanyOnboardingCommand | undefined;
  config: DesktopConnectionConfig;
  onAuthenticated: () => void;
  onSignOut: () => void;
  sessionManager: DesktopSessionManager;
  signInCommand?: SignInCommand | undefined;
}

export function AppRoutes({
  authenticated,
  companyOnboardingCommand,
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
        element={authenticated
          ? (
              <HomePage
                companyOnboardingCommand={companyOnboardingCommand}
                config={config}
                onAuthenticationRequired={onSignOut}
                onSignOut={onSignOut}
                sessionManager={sessionManager}
              />
            )
          : <Navigate replace to="/login" />}
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
