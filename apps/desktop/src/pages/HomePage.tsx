import { useCallback, useState } from "react";

import {
  AircraftCatalogPanel,
  type AircraftCatalogCommand,
} from "@/features/aircraft-catalog/AircraftCatalogPanel";
import type { CompanyAircraft } from "@/features/aircraft-fleet/aircraftFleet";
import type { AircraftPurchaseCommand } from "@/features/aircraft-purchase/AircraftPurchasePanel";
import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import type { DesktopSessionManager } from "@/features/auth/session";
import {
  AircraftFleetPanel,
  type AircraftFleetCommand,
} from "@/features/aircraft-fleet/AircraftFleetPanel";
import {
  CompanyOnboardingPanel,
  type CompanyOnboardingCommand,
} from "@/features/company-onboarding/CompanyOnboardingPanel";
import {
  CompanyPresencePanel,
  type CompanyPresenceCommand,
} from "@/features/company-state/CompanyPresencePanel";
import {
  type DispatchDraftCommand,
  FlightDispatchPanel,
} from "@/features/flight-dispatch/FlightDispatchPanel";
import { StatusCard } from "@/shared/ui/StatusCard";

export interface HomePageProps {
  aircraftCatalogCommand?: AircraftCatalogCommand | undefined;
  aircraftFleetCommand?: AircraftFleetCommand | undefined;
  aircraftPurchaseCommand?: AircraftPurchaseCommand | undefined;
  companyOnboardingCommand?: CompanyOnboardingCommand | undefined;
  companyPresenceCommand?: CompanyPresenceCommand | undefined;
  config: DesktopConnectionConfig;
  dispatchDraftCommand?: DispatchDraftCommand | undefined;
  onAuthenticationRequired: () => void;
  onSignOut: () => void;
  sessionManager: DesktopSessionManager;
}

export function HomePage({
  aircraftCatalogCommand,
  aircraftFleetCommand,
  aircraftPurchaseCommand,
  companyOnboardingCommand,
  companyPresenceCommand,
  config,
  dispatchDraftCommand,
  onAuthenticationRequired,
  onSignOut,
  sessionManager,
}: HomePageProps) {
  const [companyState, setCompanyState] = useState<"unchecked" | "absent" | "present">(
    "unchecked",
  );
  const [fleetRefreshVersion, setFleetRefreshVersion] = useState(0);
  const [fleet, setFleet] = useState<CompanyAircraft[]>([]);
  const handleFleetLoaded = useCallback((aircraft: CompanyAircraft[]) => setFleet(aircraft), []);

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
        <>
          <AircraftFleetPanel
            command={aircraftFleetCommand}
            config={config}
            onAuthenticationRequired={onAuthenticationRequired}
            onFleetLoaded={handleFleetLoaded}
            refreshVersion={fleetRefreshVersion}
            sessionManager={sessionManager}
          />
          {fleet.length > 0 && (
            <FlightDispatchPanel
              aircraft={fleet}
              command={dispatchDraftCommand}
              config={config}
              onAuthenticationRequired={onAuthenticationRequired}
              sessionManager={sessionManager}
            />
          )}
          <AircraftCatalogPanel
            command={aircraftCatalogCommand}
            config={config}
            onAuthenticationRequired={onAuthenticationRequired}
            onPurchaseSucceeded={() => setFleetRefreshVersion((version) => version + 1)}
            purchaseCommand={aircraftPurchaseCommand}
            sessionManager={sessionManager}
          />
        </>
      )}
      <button className="primary-action" type="button" onClick={onSignOut}>
        Se déconnecter
      </button>
    </main>
  );
}
