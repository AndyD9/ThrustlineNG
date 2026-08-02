import { StatusCard } from "@/shared/ui/StatusCard";

export interface HomePageProps {
  onSignOut: () => void;
}

export function HomePage({ onSignOut }: HomePageProps) {
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
      <button className="primary-action" type="button" onClick={onSignOut}>
        Se déconnecter
      </button>
    </main>
  );
}
