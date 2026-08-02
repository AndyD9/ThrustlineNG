import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const desktopRoot = resolve(import.meta.dirname, "../..");
const repositoryRoot = resolve(desktopRoot, "../..");
const read = (path: string) => readFileSync(resolve(repositoryRoot, path), "utf8");

describe("invariants frontend et Tauri", () => {
  it("ne charge aucune ressource distante dans le HTML ou le CSS", () => {
    const sources = [
      read("apps/desktop/index.html"),
      read("apps/desktop/src/styles/index.css"),
    ].join("\n");

    expect(sources).not.toMatch(/https?:\/\//i);
    expect(sources).not.toMatch(/@import\s+url/i);
  });

  it("conserve une capability vide et aucune commande ou plugin Tauri", () => {
    const capability = JSON.parse(
      read("apps/desktop/src-tauri/capabilities/default.json"),
    ) as { permissions: unknown[] };
    const rustSources = [
      read("apps/desktop/src-tauri/src/lib.rs"),
      read("apps/desktop/src-tauri/src/main.rs"),
      read("apps/desktop/src-tauri/Cargo.toml"),
    ].join("\n");

    expect(capability.permissions).toEqual([]);
    expect(rustSources).not.toMatch(/#\[tauri::command\]/);
    expect(rustSources).not.toMatch(/tauri-plugin-/);
  });

  it("maintient une CSP de production fermée au réseau", () => {
    const config = JSON.parse(read("apps/desktop/src-tauri/tauri.conf.json")) as {
      app: { security: { csp: string } };
    };
    const csp = config.app.security.csp;

    expect(csp).toContain("connect-src 'none'");
    expect(csp).not.toMatch(/https?:|wss?:|'unsafe-eval'/);
  });

  it("borne la CSP de développement à Vite et Supabase loopback", () => {
    const config = JSON.parse(read("apps/desktop/src-tauri/tauri.conf.json")) as {
      app: { security: { devCsp: string } };
    };
    const devCsp = config.app.security.devCsp;

    expect(devCsp).toContain(
      "connect-src http://127.0.0.1:1420 ws://127.0.0.1:1420 http://127.0.0.1:54321",
    );
    expect(devCsp).not.toMatch(/localhost|\[::1\]|https:|wss:|'unsafe-eval'/);
  });

  it("n’expose au bundle que les deux paramètres Supabase publics", () => {
    const viteConfig = read("apps/desktop/vite.config.ts");

    expect(viteConfig).toContain("envPrefix: []");
    expect(viteConfig.match(/import\.meta\.env\.VITE_THRUSTLINE_SUPABASE_/g)).toHaveLength(2);
    expect(viteConfig).toContain("VITE_THRUSTLINE_SUPABASE_ANON_KEY");
    expect(viteConfig).toContain("VITE_THRUSTLINE_SUPABASE_URL");
  });

  it("ne persiste ni ne journalise les credentials du module auth", () => {
    const authSources = [
      read("apps/desktop/src/features/auth/connectionConfig.ts"),
      read("apps/desktop/src/features/auth/passwordSignIn.ts"),
      read("apps/desktop/src/features/auth/PasswordSignInPanel.tsx"),
      read("apps/desktop/src/features/auth/session.ts"),
    ].join("\n");

    expect(authSources).not.toMatch(
      /localStorage|sessionStorage|indexedDB|document\.cookie|console\.(?:debug|error|info|log|warn)/,
    );
  });
});
