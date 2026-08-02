import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { App, type DesktopAuthRuntime } from "@/app/App";
import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import type { PasswordSignInInput } from "@/features/auth/passwordSignIn";
import { DesktopSessionManager, type UserSessionTokens } from "@/features/auth/session";

const config: DesktopConnectionConfig = {
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
  target: "local",
};
const session: UserSessionTokens = {
  accessToken: "private-access-token",
  expiresAtEpochSeconds: 4_600,
  refreshToken: "private-refresh-token",
};

function createRuntime(initialSession?: UserSessionTokens): DesktopAuthRuntime {
  const sessionManager = new DesktopSessionManager(config, vi.fn(), () => 1_000);
  if (initialSession !== undefined) {
    sessionManager.setSession(initialSession);
  }
  return { config, sessionManager };
}

async function fillLogin(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText("Adresse email"), "pilot@thrustline.invalid");
  await user.type(screen.getByLabelText("Mot de passe"), "synthetic-password");
}

describe("App", () => {
  beforeEach(() => {
    window.location.hash = "#/";
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("redirige l’accueil vers la connexion tant que la session est absente", async () => {
    render(<App authRuntime={createRuntime()} />);

    expect(screen.getByRole("banner")).toBeInTheDocument();
    expect(await screen.findByRole("heading", { name: "Connexion à Thrustline" })).toBeInTheDocument();
    expect(screen.queryByText("Session locale active")).not.toBeInTheDocument();
    expect(window.location.hash).toBe("#/login");
  });

  it("installe une connexion réussie avant d’afficher l’accueil protégé", async () => {
    const user = userEvent.setup();
    const runtime = createRuntime();
    const command = vi.fn(async (_input: PasswordSignInInput) => session);
    const { container } = render(<App authRuntime={runtime} signInCommand={command} />);
    await screen.findByRole("heading", { name: "Connexion à Thrustline" });
    await fillLogin(user);

    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    expect(await screen.findByRole("heading", { level: 1, name: "Thrustline" })).toBeInTheDocument();
    expect(runtime.sessionManager.hasSession()).toBe(true);
    expect(command).toHaveBeenCalledOnce();
    expect(window.location.hash).toBe("#/");
    expect(container).not.toHaveTextContent("pilot@thrustline.invalid");
    expect(container).not.toHaveTextContent("synthetic-password");
    expect(container).not.toHaveTextContent("private-access-token");
    expect(container).not.toHaveTextContent("private-refresh-token");
  });

  it("écarte /login avec une session et déconnecte sans appel réseau", async () => {
    const user = userEvent.setup();
    const runtime = createRuntime(session);
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    window.location.hash = "#/login";
    render(<App authRuntime={runtime} />);

    expect(await screen.findByRole("heading", { level: 1, name: "Thrustline" })).toBeInTheDocument();
    expect(window.location.hash).toBe("#/");
    await user.click(screen.getByRole("button", { name: "Se déconnecter" }));

    expect(await screen.findByRole("heading", { name: "Connexion à Thrustline" })).toBeInTheDocument();
    expect(runtime.sessionManager.hasSession()).toBe(false);
    expect(window.location.hash).toBe("#/login");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("affiche une route inconnue puis revient vers la garde de connexion", async () => {
    const user = userEvent.setup();
    window.location.hash = "#/inconnue";
    render(<App authRuntime={createRuntime()} />);

    expect(screen.getByRole("heading", { name: "Page introuvable" })).toBeInTheDocument();
    const homeLink = screen.getByRole("link", { name: "Retour à l’accueil" });
    homeLink.focus();
    expect(homeLink).toHaveFocus();
    await user.click(homeLink);
    expect(await screen.findByRole("heading", { name: "Connexion à Thrustline" })).toBeInTheDocument();
  });

  it("n’effectue aucun appel réseau pendant le rendu ou la redirection", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const xhrSpy = vi.spyOn(XMLHttpRequest.prototype, "open");

    render(<App authRuntime={createRuntime()} />);
    await screen.findByRole("heading", { name: "Connexion à Thrustline" });

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(xhrSpy).not.toHaveBeenCalled();
  });
});
