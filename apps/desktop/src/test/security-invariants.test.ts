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

  it("n’expose aucune variable d’environnement au bundle", () => {
    const viteConfig = read("apps/desktop/vite.config.ts");

    expect(viteConfig).toContain("envPrefix: []");
    expect(viteConfig).not.toMatch(/loadEnv|import\.meta\.env\.(?!DEV|PROD|MODE)/);
  });
});
