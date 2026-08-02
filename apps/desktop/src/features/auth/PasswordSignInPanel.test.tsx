import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { PasswordSignInPanel } from "@/features/auth/PasswordSignInPanel";
import { PasswordSignInError, type PasswordSignInInput } from "@/features/auth/passwordSignIn";
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

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((promiseResolve) => {
    resolve = promiseResolve;
  });
  return { promise, resolve };
}

async function fillForm(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText("Adresse email"), "pilot@thrustline.invalid");
  await user.type(screen.getByLabelText("Mot de passe"), "synthetic-password");
}

describe("PasswordSignInPanel", () => {
  it("installe atomiquement la session, bloque le double submit et efface les champs", async () => {
    const user = userEvent.setup();
    const pending = deferred<UserSessionTokens>();
    const command = vi.fn((_input: PasswordSignInInput) => pending.promise);
    const sessionManager = new DesktopSessionManager(config, vi.fn(), () => 1_000);
    const { container } = render(
      <PasswordSignInPanel command={command} config={config} sessionManager={sessionManager} />,
    );
    await fillForm(user);

    const button = screen.getByRole("button", { name: "Se connecter" });
    await user.dblClick(button);

    expect(command).toHaveBeenCalledOnce();
    expect(sessionManager.hasSession()).toBe(false);
    expect(screen.getByLabelText("Mot de passe")).toHaveValue("");
    expect(button).toBeDisabled();
    expect(container).not.toHaveTextContent("synthetic-password");
    expect(container).not.toHaveTextContent("private-access-token");
    expect(container).not.toHaveTextContent("private-refresh-token");

    pending.resolve(session);

    expect(await screen.findByText("Connexion réussie pour cette session.")).toBeInTheDocument();
    expect(sessionManager.hasSession()).toBe(true);
    await expect(sessionManager.getAccessToken()).resolves.toBe("private-access-token");
    expect(screen.getByLabelText("Adresse email")).toHaveValue("");
    expect(screen.getByRole("button", { name: "Connecté" })).toBeDisabled();
  });

  it.each([
    [new PasswordSignInError("rejected"), "Email ou mot de passe incorrect"],
    [new PasswordSignInError("invalid-response"), "service de connexion est indisponible"],
    [new PasswordSignInError("unavailable"), "service de connexion est indisponible"],
    [new Error("private failure detail"), "service de connexion est indisponible"],
  ])("présente une erreur redigée et permet un nouvel essai", async (failure, message) => {
    const user = userEvent.setup();
    const command = vi.fn(async (): Promise<UserSessionTokens> => {
      throw failure;
    });
    const sessionManager = new DesktopSessionManager(config, vi.fn());
    const { container } = render(
      <PasswordSignInPanel command={command} config={config} sessionManager={sessionManager} />,
    );
    await fillForm(user);
    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(message);
    expect(screen.getByRole("button", { name: "Se connecter" })).toBeEnabled();
    expect(screen.getByLabelText("Mot de passe")).toHaveValue("");
    expect(sessionManager.hasSession()).toBe(false);
    expect(container).not.toHaveTextContent(String(failure));
  });

  it("annule la requête lors du démontage", async () => {
    const user = userEvent.setup();
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn((input: PasswordSignInInput) => {
      receivedSignal = input.signal;
      return new Promise<UserSessionTokens>(() => undefined);
    });
    const sessionManager = new DesktopSessionManager(config, vi.fn());
    const { unmount } = render(
      <PasswordSignInPanel command={command} config={config} sessionManager={sessionManager} />,
    );
    await fillForm(user);
    await user.click(screen.getByRole("button", { name: "Se connecter" }));

    unmount();

    expect(receivedSignal?.aborted).toBe(true);
    expect(sessionManager.hasSession()).toBe(false);
  });
});
