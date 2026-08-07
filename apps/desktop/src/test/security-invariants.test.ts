import { readdirSync, readFileSync } from "node:fs";
import { relative, resolve } from "node:path";
import { describe, expect, it } from "vitest";

const desktopRoot = resolve(import.meta.dirname, "../..");
const repositoryRoot = resolve(desktopRoot, "../..");
const read = (path: string) => readFileSync(resolve(repositoryRoot, path), "utf8");

// Parcours récursif : un fichier ajouté dans un sous-module doit être vu aussi.
const listFiles = (root: string, extensions: readonly string[]) =>
  readdirSync(root, { recursive: true, withFileTypes: true })
    .filter(
      (entry) =>
        entry.isFile() && extensions.some((extension) => entry.name.endsWith(extension)),
    )
    .map((entry) => resolve(entry.parentPath, entry.name));

describe("invariants frontend et Tauri", () => {
  it("ne charge aucune ressource distante dans le HTML ou le CSS", () => {
    const sources = [
      read("apps/desktop/index.html"),
      read("apps/desktop/src/styles/index.css"),
    ].join("\n");

    expect(sources).not.toMatch(/https?:\/\//i);
    expect(sources).not.toMatch(/@import\s+url/i);
  });

  it("conserve une capability vide, aucun plugin et les deux seules commandes fermées", () => {
    const capability = JSON.parse(
      read("apps/desktop/src-tauri/capabilities/default.json"),
    ) as { permissions: unknown[] };
    const rustSources = [
      ...listFiles(resolve(repositoryRoot, "apps/desktop/src-tauri/src"), [".rs"]).map(
        (file) => readFileSync(file, "utf8"),
      ),
      read("apps/desktop/src-tauri/Cargo.toml"),
    ].join("\n");

    expect(capability.permissions).toEqual([]);
    // F0004 J2 puis F0006 J2 : exactement deux commandes IPC fermées.
    // flight_summary reste en lecture seule sans paramètre de la WebView ;
    // flight_summary_arm n'accepte qu'un identifiant de dispatch, validé
    // côté Rust. Le motif ne réclame pas le crochet fermant :
    // `#[tauri::command(...)]` compte aussi.
    const commands = rustSources.match(/#\s*\[\s*tauri::command/g) ?? [];
    expect(commands).toHaveLength(2);
    expect(rustSources).toMatch(
      /#\[tauri::command\]\s*async fn flight_summary\(\s*app: tauri::AppHandle,?\s*\)/,
    );
    expect(rustSources).toMatch(
      /#\[tauri::command\]\s*async fn flight_summary_arm\(\s*app: tauri::AppHandle,\s*dispatch_id: String,?\s*\)/,
    );
    expect(rustSources).not.toMatch(/tauri-plugin-/);
  });

  it("réserve __TAURI_INTERNALS__ au seul câblage flightSummaryShell.ts", () => {
    const sourceRoot = resolve(repositoryRoot, "apps/desktop/src");
    const offenders = listFiles(sourceRoot, [".ts", ".tsx"])
      .filter((file) => !/\.test\.tsx?$/.test(file))
      .filter((file) => readFileSync(file, "utf8").includes("__TAURI"))
      .map((file) => relative(sourceRoot, file).replaceAll("\\", "/"));

    expect(offenders).toEqual(["features/flight-dispatch/flightSummaryShell.ts"]);
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
      read("apps/desktop/src/app/App.tsx"),
      read("apps/desktop/src/app/routes.tsx"),
      read("apps/desktop/src/pages/LoginPage.tsx"),
    ].join("\n");

    expect(authSources).not.toMatch(
      /localStorage|sessionStorage|indexedDB|document\.cookie|console\.(?:debug|error|info|log|warn)/,
    );
  });

  it("ne persiste ni ne journalise la session ou l'intention d'onboarding", () => {
    const onboardingSources = [
      read("apps/desktop/src/features/company-onboarding/companyOnboarding.ts"),
      read("apps/desktop/src/features/company-onboarding/CompanyOnboardingPanel.tsx"),
      read("apps/desktop/src/pages/HomePage.tsx"),
    ].join("\n");

    expect(onboardingSources).not.toMatch(
      /localStorage|sessionStorage|indexedDB|document\.cookie|console\.(?:debug|error|info|log|warn)/,
    );
    expect(onboardingSources).not.toMatch(
      /ownerId|openingAmountMinor|currencyCode|service.role/i,
    );
  });

  it("ne persiste ni ne journalise la session ou le catalogue d'avions", () => {
    const catalogSources = [
      read("apps/desktop/src/features/aircraft-catalog/aircraftCatalog.ts"),
      read("apps/desktop/src/features/aircraft-catalog/AircraftCatalogPanel.tsx"),
    ].join("\n");

    expect(catalogSources).not.toMatch(
      /localStorage|sessionStorage|indexedDB|document\.cookie|console\.(?:debug|error|info|log|warn)/,
    );
    expect(catalogSources).not.toMatch(/service.role|insert|update|upsert|delete/i);
  });
});
