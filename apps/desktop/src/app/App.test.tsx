import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { App } from "@/app/App";

describe("App", () => {
  beforeEach(() => {
    window.location.hash = "#/";
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("monte la page d’accueil avec ses landmarks et la stack locale", () => {
    render(<App />);

    expect(screen.getByRole("banner")).toBeInTheDocument();
    expect(screen.getByRole("main")).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 1, name: "Thrustline" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 2, name: "Ready" })).toBeInTheDocument();
    expect(screen.getByText(/React 19.*TypeScript 6.*Vite 8/s)).toBeInTheDocument();
  });

  it("affiche une route inconnue puis permet de revenir à l’accueil", async () => {
    const user = userEvent.setup();
    window.location.hash = "#/inconnue";

    render(<App />);

    expect(screen.getByRole("heading", { name: "Page introuvable" })).toBeInTheDocument();
    const homeLink = screen.getByRole("link", { name: "Retour à l’accueil" });
    homeLink.focus();
    expect(homeLink).toHaveFocus();
    await user.click(homeLink);
    expect(await screen.findByRole("heading", { name: "Thrustline" })).toBeInTheDocument();
  });

  it("n’effectue aucun appel réseau pendant le rendu", () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const xhrSpy = vi.spyOn(XMLHttpRequest.prototype, "open");

    render(<App />);

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(xhrSpy).not.toHaveBeenCalled();
  });
});
