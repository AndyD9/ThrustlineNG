import { useState } from "react";

import {
  AircraftCatalogPanel,
  type AircraftCatalogCommand,
} from "@/features/aircraft-catalog/AircraftCatalogPanel";
import type { AircraftPurchaseCommand } from "@/features/aircraft-purchase/AircraftPurchasePanel";
import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import type { DesktopSessionManager } from "@/features/auth/session";
import {
  CompanyOnboardingPanel,
  type CompanyOnboardingCommand,
} from "@/features/company-onboarding/CompanyOnboardingPanel";
import {
  CompanyPresencePanel,
  type CompanyPresenceCommand,
} from "@/features/company-state/CompanyPresencePanel";
import { StatusCard } from "@/shared/ui/StatusCard";

export interface HomePageProps {
  aircraftCatalogCommand?: AircraftCatalogCommand | undefined;
  aircraftPurchaseCommand?: AircraftPurchaseCommand | undefined;
  companyOnboardingCommand?: CompanyOnboardingCommand | undefined;
  companyPresenceCommand?: CompanyPresenceCommand | undefined;
  config: DesktopConnectionConfig;
  onAuthenticationRequired: () => void;
  onSignOut: () => void;
  sessionManager: DesktopSessionManager;
}

export function HomePage({
  aircraftCatalogCommand,
  aircraftPurchaseCommand,
  companyOnboardingCommand,
  companyPresenceCommand,
  config,
  onAuthenticationRequired,
  onSignOut,
  sessionManager,
}: HomePageProps) {
  const [companyState, setCompanyState] = useState<"unchecked" | "absent" | "present">(
    "unchecked",
  );

  return (
    <main className="page" id="main-content">
      <section className="hero" aria-labelledby="home-title">
        <p className="eyebrow">Frontend baseline</p>
        <h1 id="home-title">Thrustline</h1>
        <p className="intro">
          Une fondation locale, minimale et mesurable pour l’application desktop.
        </p>
      </section>
      <StatusCard
        status="Ready"
        detail="Session locale active · aucune donnée persistée"
      />
      {companyState === "unchecked" && (
        <CompanyPresencePanel
          command={companyPresenceCommand}
          config={config}
          onAuthenticationRequired={onAuthenticationRequired}
          onResolved={(hasCompany) => setCompanyState(hasCompany ? "present" : "absent")}
          sessionManager={sessionManager}
        />
      )}
      {companyState === "absent" && (
        <CompanyOnboardingPanel
          command={companyOnboardingCommand}
          config={config}
          onAuthenticationRequired={onAuthenticationRequired}
          onCompanyActive={() => setCompanyState("present")}
          sessionManager={sessionManager}
        />
      )}
      {companyState === "present" && (
        <AircraftCatalogPanel
          command={aircraftCatalogCommand}
          config={config}
          onAuthenticationRequired={onAuthenticationRequired}
          purchaseCommand={aircraftPurchaseCommand}
          sessionManager={sessionManager}
        />
      )}
      <button className="primary-action" type="button" onClick={onSignOut}>
        Se déconnecter
      </button>
    </main>
  );
}
