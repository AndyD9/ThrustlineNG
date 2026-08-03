import { Navigate, Route, Routes } from "react-router";

import type { AircraftCatalogCommand } from "@/features/aircraft-catalog/AircraftCatalogPanel";
import type { AircraftPurchaseCommand } from "@/features/aircraft-purchase/AircraftPurchasePanel";
import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import type { SignInCommand } from "@/features/auth/PasswordSignInPanel";
import type { DesktopSessionManager } from "@/features/auth/session";
import type { CompanyOnboardingCommand } from "@/features/company-onboarding/CompanyOnboardingPanel";
import type { CompanyPresenceCommand } from "@/features/company-state/CompanyPresencePanel";
import { HomePage } from "@/pages/HomePage";
import { LoginPage } from "@/pages/LoginPage";
import { NotFoundPage } from "@/pages/NotFoundPage";

export interface AppRoutesProps {
  aircraftCatalogCommand?: AircraftCatalogCommand | undefined;
  aircraftPurchaseCommand?: AircraftPurchaseCommand | undefined;
  authenticated: boolean;
  companyOnboardingCommand?: CompanyOnboardingCommand | undefined;
  companyPresenceCommand?: CompanyPresenceCommand | undefined;
  config: DesktopConnectionConfig;
  onAuthenticated: () => void;
  onSignOut: () => void;
  sessionManager: DesktopSessionManager;
  signInCommand?: SignInCommand | undefined;
}

export function AppRoutes({
  aircraftCatalogCommand,
  aircraftPurchaseCommand,
  authenticated,
  companyOnboardingCommand,
  companyPresenceCommand,
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
                aircraftCatalogCommand={aircraftCatalogCommand}
                aircraftPurchaseCommand={aircraftPurchaseCommand}
                companyOnboardingCommand={companyOnboardingCommand}
                companyPresenceCommand={companyPresenceCommand}
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
