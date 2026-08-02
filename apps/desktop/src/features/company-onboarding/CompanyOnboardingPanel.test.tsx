import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { DesktopSessionManager, type UserSessionTokens } from "@/features/auth/session";
import {
  CompanyOnboardingPanel,
  type CompanyOnboardingCommand,
} from "@/features/company-onboarding/CompanyOnboardingPanel";
import {
  CompanyOnboardingError,
  type CompanyOnboardingResult,
} from "@/features/company-onboarding/companyOnboarding";

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
const firstKey = "92000000-0000-4000-8000-000000000001";
const secondKey = "92000000-0000-4000-8000-000000000002";
const result: CompanyOnboardingResult = {
  companyId: "92000000-0000-4000-8000-000000000003",
  openingEntryId: "92000000-0000-4000-8000-000000000004",
  schemaVersion: 1,
  state: "active",
};

function createSessionManager() {
  const manager = new DesktopSessionManager(config, vi.fn(), () => 1_000);
  manager.setSession(session);
  return manager;
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((promiseResolve) => {
    resolve = promiseResolve;
  });
  return { promise, resolve };
}

describe("CompanyOnboardingPanel", () => {
  it("ne déclenche aucun réseau au rendu et crée une compagnie sans rendre les données soumises", async () => {
    const user = userEvent.setup();
    const command = vi.fn<CompanyOnboardingCommand>(async () => result);
    const onAuthenticationRequired = vi.fn();
    const { container } = render(
      <CompanyOnboardingPanel
        command={command}
        config={config}
        createIdempotencyKey={() => firstKey}
        onAuthenticationRequired={onAuthenticationRequired}
        sessionManager={createSessionManager()}
      />,
    );

    expect(command).not.toHaveBeenCalled();
    await user.type(screen.getByLabelText("Nom de la compagnie"), " Synthetic Airways ");
    await user.click(screen.getByRole("button", { name: "Créer la compagnie" }));

    expect(await screen.findByText("Votre compagnie est active.")).toBeInTheDocument();
    expect(command).toHaveBeenCalledOnce();
    expect(command.mock.calls[0]![0]).toMatchObject({
      accessToken: "private-access-token",
      anonKey: "public-anon-key",
      companyName: "Synthetic Airways",
      idempotencyKey: firstKey,
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(container).not.toHaveTextContent("Synthetic Airways");
    expect(container).not.toHaveTextContent("private-access-token");
    expect(container).not.toHaveTextContent(result.companyId);
    expect(onAuthenticationRequired).not.toHaveBeenCalled();
  });

  it("bloque le double clic et réutilise l'intention après indisponibilité", async () => {
    const user = userEvent.setup();
    const pending = deferred<CompanyOnboardingResult>();
    const command = vi
      .fn<CompanyOnboardingCommand>()
      .mockRejectedValueOnce(new CompanyOnboardingError("unavailable"))
      .mockImplementationOnce(async () => pending.promise);
    render(
      <CompanyOnboardingPanel
        command={command}
        config={config}
        createIdempotencyKey={() => firstKey}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    await user.type(screen.getByLabelText("Nom de la compagnie"), "Synthetic Airways");
    await user.click(screen.getByRole("button", { name: "Créer la compagnie" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");

    await user.dblClick(screen.getByRole("button", { name: "Réessayer" }));
    expect(command).toHaveBeenCalledTimes(2);
    expect(command.mock.calls[0]![0].idempotencyKey).toBe(firstKey);
    expect(command.mock.calls[1]![0].idempotencyKey).toBe(firstKey);

    pending.resolve(result);
    expect(await screen.findByText("Votre compagnie est active.")).toBeInTheDocument();
  });

  it("crée une nouvelle intention quand le nom change après une panne", async () => {
    const user = userEvent.setup();
    const command = vi
      .fn<CompanyOnboardingCommand>()
      .mockRejectedValueOnce(new CompanyOnboardingError("unavailable"))
      .mockResolvedValueOnce(result);
    const createIdempotencyKey = vi
      .fn<() => string>()
      .mockReturnValueOnce(firstKey)
      .mockReturnValueOnce(secondKey);
    render(
      <CompanyOnboardingPanel
        command={command}
        config={config}
        createIdempotencyKey={createIdempotencyKey}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    const input = screen.getByLabelText("Nom de la compagnie");
    await user.type(input, "First Airways");
    await user.click(screen.getByRole("button", { name: "Créer la compagnie" }));
    await screen.findByRole("alert");
    await user.clear(input);
    await user.type(input, "Second Airways");
    await user.click(screen.getByRole("button", { name: "Réessayer" }));

    expect(command.mock.calls[0]![0].idempotencyKey).toBe(firstKey);
    expect(command.mock.calls[1]![0]).toMatchObject({
      companyName: "Second Airways",
      idempotencyKey: secondKey,
    });
  });

  it("efface une session refusée et demande le retour au login", async () => {
    const user = userEvent.setup();
    const manager = createSessionManager();
    const onAuthenticationRequired = vi.fn();
    render(
      <CompanyOnboardingPanel
        command={async () => {
          throw new CompanyOnboardingError("authentication-required");
        }}
        config={config}
        createIdempotencyKey={() => firstKey}
        onAuthenticationRequired={onAuthenticationRequired}
        sessionManager={manager}
      />,
    );
    await user.type(screen.getByLabelText("Nom de la compagnie"), "Synthetic Airways");
    await user.click(screen.getByRole("button", { name: "Créer la compagnie" }));

    expect(onAuthenticationRequired).toHaveBeenCalledOnce();
    expect(manager.hasSession()).toBe(false);
  });

  it("refuse un nom hors bornes sans obtenir de bearer", async () => {
    const user = userEvent.setup();
    const manager = createSessionManager();
    const tokenSpy = vi.spyOn(manager, "getAccessToken");
    const command = vi.fn<CompanyOnboardingCommand>();
    render(
      <CompanyOnboardingPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={manager}
      />,
    );
    await user.type(screen.getByLabelText("Nom de la compagnie"), "A");
    await user.click(screen.getByRole("button", { name: "Créer la compagnie" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("refusée");
    expect(tokenSpy).not.toHaveBeenCalled();
    expect(command).not.toHaveBeenCalled();
  });

  it("annule la commande au démontage", async () => {
    const user = userEvent.setup();
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn<CompanyOnboardingCommand>((commandInput) => {
      receivedSignal = commandInput.signal;
      return new Promise<CompanyOnboardingResult>(() => undefined);
    });
    const { unmount } = render(
      <CompanyOnboardingPanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    await user.type(screen.getByLabelText("Nom de la compagnie"), "Synthetic Airways");
    await user.click(screen.getByRole("button", { name: "Créer la compagnie" }));
    unmount();

    expect(receivedSignal?.aborted).toBe(true);
  });
});
