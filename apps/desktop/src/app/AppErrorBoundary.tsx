import { Component, type ErrorInfo, type ReactNode } from "react";

type ReloadPage = () => void;

interface AppErrorBoundaryProps {
  children: ReactNode;
  reloadPage?: ReloadPage;
}

interface AppErrorBoundaryState {
  hasError: boolean;
}

const defaultReloadPage: ReloadPage = () => window.location.reload();

export class AppErrorBoundary extends Component<
  AppErrorBoundaryProps,
  AppErrorBoundaryState
> {
  public override state: AppErrorBoundaryState = { hasError: false };

  public static getDerivedStateFromError(): AppErrorBoundaryState {
    return { hasError: true };
  }

  public override componentDidCatch(error: Error, info: ErrorInfo): void {
    if (import.meta.env.DEV) {
      console.error("Erreur de rendu React interceptée.", error.name, info.componentStack);
    }
  }

  public override render(): ReactNode {
    if (this.state.hasError) {
      const reloadPage = this.props.reloadPage ?? defaultReloadPage;

      return (
        <main className="centered-page" aria-labelledby="render-error-title">
          <section className="error-panel" role="alert">
            <p className="eyebrow">Erreur locale</p>
            <h1 id="render-error-title">L’interface n’a pas pu être affichée</h1>
            <p>Aucune donnée n’a été envoyée. Rechargez l’application pour réessayer.</p>
            <button type="button" className="primary-action" onClick={reloadPage}>
              Recharger
            </button>
          </section>
        </main>
      );
    }

    return this.props.children;
  }
}
