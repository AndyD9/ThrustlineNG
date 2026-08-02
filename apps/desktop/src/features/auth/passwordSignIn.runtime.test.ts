import { describe, expect, it } from "vitest";

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import {
  PasswordSignInError,
  signInWithPassword,
} from "@/features/auth/passwordSignIn";
import { DesktopSessionManager } from "@/features/auth/session";

const runtimeEnvironment = {
  anonKey: process.env.THRUSTLINE_TEST_SUPABASE_ANON_KEY,
  email: process.env.THRUSTLINE_TEST_AUTH_EMAIL,
  password: process.env.THRUSTLINE_TEST_AUTH_PASSWORD,
  signupEmail: process.env.THRUSTLINE_TEST_AUTH_SIGNUP_EMAIL,
};
const hasRuntimeEnvironment = Object.values(runtimeEnvironment).every(
  (value) => typeof value === "string" && value.length > 0,
);

describe.skipIf(!hasRuntimeEnvironment)("local password sign-in runtime", () => {
  it("acquires and installs a real local Auth session", async () => {
    const config: DesktopConnectionConfig = {
      anonKey: runtimeEnvironment.anonKey as string,
      supabaseUrl: "http://127.0.0.1:54321",
      target: "local",
    };

    const session = await signInWithPassword({
      config,
      email: runtimeEnvironment.email as string,
      password: runtimeEnvironment.password as string,
    });
    const manager = new DesktopSessionManager(config);
    expect(manager.hasSession()).toBe(false);

    manager.setSession(session);

    expect(manager.hasSession()).toBe(true);
    await expect(manager.getAccessToken()).resolves.toBe(session.accessToken);
    expect(session.refreshToken).not.toBe(session.accessToken);
  });

  it("rejects a wrong password and keeps public signup closed", async () => {
    const config: DesktopConnectionConfig = {
      anonKey: runtimeEnvironment.anonKey as string,
      supabaseUrl: "http://127.0.0.1:54321",
      target: "local",
    };

    await expect(signInWithPassword({
      config,
      email: runtimeEnvironment.email as string,
      password: `${runtimeEnvironment.password as string}-wrong`,
    })).rejects.toEqual(new PasswordSignInError("rejected"));

    const signupResponse = await fetch(new URL("/auth/v1/signup", config.supabaseUrl), {
      method: "POST",
      headers: {
        apikey: config.anonKey,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        email: runtimeEnvironment.signupEmail,
        password: runtimeEnvironment.password,
      }),
    });

    expect([400, 422]).toContain(signupResponse.status);
    await expect(signupResponse.json()).resolves.toMatchObject({
      error_code: "signup_disabled",
    });
  });
});
