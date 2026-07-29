import { HashRouter } from "react-router";

import { AppErrorBoundary } from "@/app/AppErrorBoundary";
import { AppRoutes } from "@/app/routes";

export function App() {
  return (
    <AppErrorBoundary>
      <HashRouter>
        <div className="app-shell">
          <header className="app-header">
            <span className="brand">Thrustline</span>
            <span className="baseline-label">Frontend baseline</span>
          </header>
          <AppRoutes />
        </div>
      </HashRouter>
    </AppErrorBoundary>
  );
}
