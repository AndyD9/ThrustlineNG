import { Link } from "react-router-dom";

export function NotFoundPage() {
  return (
    <main className="centered-page" aria-labelledby="not-found-title">
      <section className="error-panel">
        <p className="eyebrow">Route inconnue</p>
        <h1 id="not-found-title">Page introuvable</h1>
        <p>Cette route ne fait pas partie de la baseline.</p>
        <Link className="primary-action" to="/">
          Retour à l’accueil
        </Link>
      </section>
    </main>
  );
}
