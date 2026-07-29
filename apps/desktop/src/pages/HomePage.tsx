import { StatusCard } from "@/shared/ui/StatusCard";

export function HomePage() {
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
        detail="React 19 · TypeScript 6 · Vite 8 · Tailwind CSS 4 · React Router 8"
      />
    </main>
  );
}
