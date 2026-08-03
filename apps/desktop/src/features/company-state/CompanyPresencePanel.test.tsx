import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import { DesktopSessionManager, type UserSessionTokens } from "@/features/auth/session";
import {
  CompanyPresencePanel,
  type CompanyPresenceCommand,
} from "@/features/company-state/CompanyPresencePanel";
import { CompanyPresenceError } from "@/features/company-state/companyState";

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

describe("CompanyPresencePanel", () => {
  it("ne charge rien au rendu puis résout une présence sans rendre de donnée", async () => {
    const user = userEvent.setup();
    const command = vi.fn<CompanyPresenceCommand>(async () => true);
    const onResolved = vi.fn();
    const { container } = render(
      <CompanyPresencePanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        onResolved={onResolved}
        sessionManager={createSessionManager()}
      />,
    );

    expect(command).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));

    expect(onResolved).toHaveBeenCalledWith(true);
    expect(command.mock.calls[0]![0]).toMatchObject({
      accessToken: "private-access-token",
      anonKey: "public-anon-key",
      supabaseUrl: "http://127.0.0.1:54321",
    });
    expect(container).not.toHaveTextContent("private-access-token");
    expect(container).not.toHaveTextContent("private-refresh-token");
  });

  it("borne le double clic puis peut résoudre l'absence", async () => {
    const user = userEvent.setup();
    const pending = deferred<boolean>();
    const command = vi.fn<CompanyPresenceCommand>(async () => pending.promise);
    const onResolved = vi.fn();
    render(
      <CompanyPresencePanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        onResolved={onResolved}
        sessionManager={createSessionManager()}
      />,
    );

    await user.dblClick(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    expect(command).toHaveBeenCalledOnce();
    pending.resolve(false);
    await vi.waitFor(() => expect(onResolved).toHaveBeenCalledWith(false));
  });

  it("rend une panne actionnable puis permet le retry", async () => {
    const user = userEvent.setup();
    const command = vi
      .fn<CompanyPresenceCommand>()
      .mockRejectedValueOnce(new CompanyPresenceError("unavailable"))
      .mockResolvedValueOnce(true);
    const onResolved = vi.fn();
    render(
      <CompanyPresencePanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        onResolved={onResolved}
        sessionManager={createSessionManager()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    await user.click(screen.getByRole("button", { name: "Réessayer" }));
    expect(onResolved).toHaveBeenCalledWith(true);
  });

  it("efface une session refusée et demande le retour au login", async () => {
    const user = userEvent.setup();
    const manager = createSessionManager();
    const onAuthenticationRequired = vi.fn();
    render(
      <CompanyPresencePanel
        command={async () => {
          throw new CompanyPresenceError("authentication-required");
        }}
        config={config}
        onAuthenticationRequired={onAuthenticationRequired}
        onResolved={vi.fn()}
        sessionManager={manager}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    expect(onAuthenticationRequired).toHaveBeenCalledOnce();
    expect(manager.hasSession()).toBe(false);
  });

  it("annule la commande au démontage", async () => {
    const user = userEvent.setup();
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn<CompanyPresenceCommand>((commandInput) => {
      receivedSignal = commandInput.signal;
      return new Promise<boolean>(() => undefined);
    });
    const { unmount } = render(
      <CompanyPresencePanel
        command={command}
        config={config}
        onAuthenticationRequired={vi.fn()}
        onResolved={vi.fn()}
        sessionManager={createSessionManager()}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Vérifier ma compagnie" }));
    unmount();

    expect(receivedSignal?.aborted).toBe(true);
  });
});
