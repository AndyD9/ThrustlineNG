import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const featureRoot = resolve(import.meta.dirname);
const transport = readFileSync(resolve(featureRoot, "flightSummary.ts"), "utf8");

describe("invariants du résumé de vol desktop", () => {
  it("n’atteint jamais le contrat local : la seule dépendance est la commande injectée", () => {
    expect(transport).not.toMatch(/\bfetch\b|XMLHttpRequest|WebSocket|EventSource|navigator\./);
    expect(transport).not.toMatch(/127\.0\.0\.1|localhost|https?:|wss?:|:\d{4,5}\b/);
    expect(transport).not.toMatch(/__TAURI/);
  });

  it("ne connaît ni le jeton, ni le port, ni le chemin de trace", () => {
    expect(transport).not.toMatch(/\btoken\b|\bjeton\b|\bport\b|X-Thrustline|\btrace\b/i);
  });

  it("ne persiste ni ne journalise le résumé", () => {
    expect(transport).not.toMatch(
      /localStorage|sessionStorage|indexedDB|document\.cookie|console\.(?:debug|error|info|log|warn)/,
    );
  });

  it("borne le contrat aux trois clés attendues", () => {
    expect(transport).toContain('"blockMinutes,contractVersion,state"');
  });
});
