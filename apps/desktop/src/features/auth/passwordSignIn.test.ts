import { describe, expect, it, vi } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import {
  PasswordSignInError,
  signInWithPassword,
  type PasswordSignInInput,
} from "@/features/auth/passwordSignIn";

const config: DesktopConnectionConfig = {
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
  target: "local",
};
const input: PasswordSignInInput = {
  config,
  email: "pilot@thrustline.invalid",
  password: "synthetic-password",
};
const sessionResponse = {
  access_token: "private-access-token",
  expires_in: 3_600,
  refresh_token: "private-refresh-token",
  token_type: "bearer",
  user: { id: "91000000-0000-4000-8000-000000000001" },
};

describe("signInWithPassword", () => {
  it("appelle uniquement Auth local avec le payload et les headers fermés", async () => {
    const fetchImplementation = vi.fn<
      (request: string | URL | Request, init?: RequestInit) => Promise<Response>
    >(async () => Response.json(sessionResponse));

    await expect(signInWithPassword(input, fetchImplementation, () => 1_000)).resolves.toEqual({
      accessToken: "private-access-token",
      expiresAtEpochSeconds: 4_600,
      refreshToken: "private-refresh-token",
    });

    expect(fetchImplementation).toHaveBeenCalledOnce();
    const [url, request] = fetchImplementation.mock.calls[0]!;
    expect(String(url)).toBe("http://127.0.0.1:54321/auth/v1/token?grant_type=password");
    expect(request).toMatchObject({
      method: "POST",
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    expect(new Headers(request?.headers)).toEqual(new Headers({
      accept: "application/json",
      apikey: "public-anon-key",
      "content-type": "application/json",
    }));
    expect(JSON.parse(String(request?.body))).toEqual({
      email: "pilot@thrustline.invalid",
      password: "synthetic-password",
    });
  });

  it.each([
    ["", "synthetic-password"],
    [" pilot@thrustline.invalid", "synthetic-password"],
    ["pilot@@thrustline.invalid", "synthetic-password"],
    ["pilot@thrustline.invalid", ""],
    ["pilot@thrustline.invalid", "x".repeat(1_025)],
  ])("refuse localement des credentials hors bornes", async (email, password) => {
    const fetchImplementation = vi.fn();
    await expect(signInWithPassword({ config, email, password }, fetchImplementation)).rejects.toMatchObject({
      failure: "rejected",
    });
    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it.each([400, 401, 403, 422])("redige le refus Auth HTTP %s", async (status) => {
    const response = new Response(JSON.stringify({ message: "sensitive Auth detail" }), { status });
    const error = await signInWithPassword(input, async () => response).catch((reason: unknown) => reason);
    expect(error).toBeInstanceOf(PasswordSignInError);
    expect(error).toMatchObject({ failure: "rejected", message: "rejected" });
    expect(String(error)).not.toContain("sensitive Auth detail");
  });

  it("classe timeout et panne réseau comme indisponibles", async () => {
    await expect(signInWithPassword(input, async () => {
      throw new Error("private network detail");
    })).rejects.toMatchObject({ failure: "unavailable", message: "unavailable" });

    await expect(signInWithPassword(input, async () => new Response(null, { status: 503 })))
      .rejects.toMatchObject({ failure: "unavailable" });
  });

  it("refuse une réponse surdimensionnée, malformée ou incomplète", async () => {
    const oversized = new Response("{}", { headers: { "content-length": "16385" } });
    await expect(signInWithPassword(input, async () => oversized))
      .rejects.toMatchObject({ failure: "invalid-response" });
    await expect(signInWithPassword(input, async () => new Response("x".repeat(16_385))))
      .rejects.toMatchObject({ failure: "invalid-response" });
    await expect(signInWithPassword(input, async () => new Response("not-json")))
      .rejects.toMatchObject({ failure: "invalid-response" });
    await expect(signInWithPassword(input, async () => Response.json({ ...sessionResponse, refresh_token: "" })))
      .rejects.toMatchObject({ failure: "invalid-response" });
  });

  it("combine annulation appelante et timeout sans exposer la cause", async () => {
    const abortController = new AbortController();
    const fetchImplementation = vi.fn(async (_url: string | URL | Request, request?: RequestInit) => {
      abortController.abort();
      expect(request?.signal?.aborted).toBe(true);
      throw new DOMException("synthetic abort", "AbortError");
    });

    await expect(signInWithPassword({ ...input, signal: abortController.signal }, fetchImplementation))
      .rejects.toMatchObject({ failure: "unavailable" });
  });
});
