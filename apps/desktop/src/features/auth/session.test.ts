import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import {
  DesktopSessionManager,
  SessionError,
  type UserSessionTokens,
} from "@/features/auth/session";

const config: DesktopConnectionConfig = {
  anonKey: "public-local-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
  target: "local",
};
const session: UserSessionTokens = {
  accessToken: "access-token-1",
  expiresAtEpochSeconds: 2_000,
  refreshToken: "refresh-token-1",
};

function refreshedResponse(overrides: Record<string, unknown> = {}) {
  return Response.json({
    access_token: "access-token-2",
    expires_in: 3_600,
    refresh_token: "refresh-token-2",
    token_type: "bearer",
    user: { id: "not-exposed-by-manager" },
    ...overrides,
  });
}

async function expectFailure(promise: Promise<unknown>, failure: SessionError["failure"]) {
  await expect(promise).rejects.toMatchObject({ name: "SessionError", failure });
}

describe("DesktopSessionManager", () => {
  it("conserve la session uniquement en mémoire et rend un bearer encore valide", async () => {
    const fetchImplementation = vi.fn();
    const manager = new DesktopSessionManager(config, fetchImplementation, () => 1_000);

    expect(manager.hasSession()).toBe(false);
    manager.setSession(session);
    expect(manager.hasSession()).toBe(true);
    await expect(manager.getAccessToken()).resolves.toBe("access-token-1");
    expect(fetchImplementation).not.toHaveBeenCalled();

    manager.clear();
    expect(manager.hasSession()).toBe(false);
    await expectFailure(manager.getAccessToken(), "authentication-required");
  });

  it("rafraîchit avant expiration avec une requête fermée et remplace les deux tokens", async () => {
    let now = 1_980;
    const fetchImplementation = vi.fn(
      async (_input: string | URL | Request, _init?: RequestInit) => refreshedResponse(),
    );
    const manager = new DesktopSessionManager(config, fetchImplementation, () => now);
    manager.setSession(session);

    await expect(manager.getAccessToken()).resolves.toBe("access-token-2");
    const [url, init] = fetchImplementation.mock.calls[0]!;
    expect(url.toString()).toBe(
      "http://127.0.0.1:54321/auth/v1/token?grant_type=refresh_token",
    );
    expect(init).toMatchObject({
      method: "POST",
      headers: {
        accept: "application/json",
        apikey: "public-local-anon-key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ refresh_token: "refresh-token-1" }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    expect(init?.signal).toBeInstanceOf(AbortSignal);

    now = 2_000;
    await expect(manager.getAccessToken()).resolves.toBe("access-token-2");
    expect(fetchImplementation).toHaveBeenCalledOnce();
  });

  it("fait converger deux demandes concurrentes vers un seul refresh", async () => {
    let resolveResponse!: (response: Response) => void;
    const pendingResponse = new Promise<Response>((resolve) => {
      resolveResponse = resolve;
    });
    const fetchImplementation = vi.fn(
      async (_input: string | URL | Request, _init?: RequestInit) => pendingResponse,
    );
    const manager = new DesktopSessionManager(config, fetchImplementation, () => 1_980);
    manager.setSession(session);

    const first = manager.getAccessToken();
    const second = manager.getAccessToken();
    resolveResponse(refreshedResponse());

    await expect(Promise.all([first, second])).resolves.toEqual([
      "access-token-2",
      "access-token-2",
    ]);
    expect(fetchImplementation).toHaveBeenCalledOnce();
  });

  it("ne ressuscite pas une session effacée pendant un refresh", async () => {
    let resolveResponse!: (response: Response) => void;
    const pendingResponse = new Promise<Response>((resolve) => {
      resolveResponse = resolve;
    });
    const manager = new DesktopSessionManager(
      config,
      async () => pendingResponse,
      () => 1_980,
    );
    manager.setSession(session);

    const refresh = manager.getAccessToken();
    manager.clear();
    resolveResponse(refreshedResponse());

    await expectFailure(refresh, "authentication-required");
    expect(manager.hasSession()).toBe(false);
  });

  it.each([400, 401, 403])("efface la session après un refus Auth HTTP %s", async (status) => {
    const manager = new DesktopSessionManager(
      config,
      async () => new Response("sensitive auth detail", { status }),
      () => 1_980,
    );
    manager.setSession(session);

    await expectFailure(manager.getAccessToken(), "authentication-required");
    expect(manager.hasSession()).toBe(false);
  });

  it("conserve une session récupérable après une panne transitoire sans exposer le détail", async () => {
    const manager = new DesktopSessionManager(
      config,
      async () => Promise.reject(new Error("refresh-token-1")),
      () => 1_980,
    );
    manager.setSession(session);

    await expectFailure(manager.getAccessToken(), "unavailable");
    expect(manager.hasSession()).toBe(true);
  });

  it.each([
    ["type invalide", { token_type: "mac" }],
    ["durée trop courte", { expires_in: 30 }],
    ["token vide", { access_token: "" }],
    ["corps surdimensionné", null],
  ])("refuse une réponse Auth non conforme : %s", async (_name, override) => {
    const response = override === null
      ? new Response(`"${"x".repeat(16_385)}"`)
      : refreshedResponse(override);
    const manager = new DesktopSessionManager(config, async () => response, () => 1_980);
    manager.setSession(session);

    await expectFailure(manager.getAccessToken(), "invalid-response");
  });

  it("refuse une session injectée non conforme sans conserver de credential", () => {
    const manager = new DesktopSessionManager(config, vi.fn(), () => 1_000);

    expect(() => manager.setSession({ ...session, refreshToken: "bad token" })).toThrowError(
      new SessionError("authentication-required"),
    );
    expect(manager.hasSession()).toBe(false);
  });
});
