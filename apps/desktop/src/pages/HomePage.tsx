import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import type { DesktopSessionManager } from "@/features/auth/session";
import {
  CompanyOnboardingPanel,
  type CompanyOnboardingCommand,
} from "@/features/company-onboarding/CompanyOnboardingPanel";
import { StatusCard } from "@/shared/ui/StatusCard";

export interface HomePageProps {
  companyOnboardingCommand?: CompanyOnboardingCommand | undefined;
  config: DesktopConnectionConfig;
  onAuthenticationRequired: () => void;
  onSignOut: () => void;
  sessionManager: DesktopSessionManager;
}

export function HomePage({
  companyOnboardingCommand,
  config,
  onAuthenticationRequired,
  onSignOut,
  sessionManager,
}: HomePageProps) {
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
      <CompanyOnboardingPanel
        command={companyOnboardingCommand}
        config={config}
        onAuthenticationRequired={onAuthenticationRequired}
        sessionManager={sessionManager}
      />
      <button className="primary-action" type="button" onClick={onSignOut}>
        Se déconnecter
      </button>
    </main>
  );
}
