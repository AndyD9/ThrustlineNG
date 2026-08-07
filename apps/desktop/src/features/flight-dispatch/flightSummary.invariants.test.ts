import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const featureRoot = resolve(import.meta.dirname);
const transport = readFileSync(resolve(featureRoot, "flightSummary.ts"), "utf8");
const shell = readFileSync(resolve(featureRoot, "flightSummaryShell.ts"), "utf8");
const control = readFileSync(resolve(featureRoot, "FlightSummaryControl.tsx"), "utf8");

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

describe("invariants du câblage shell F0004 J3", () => {
  it("relaie la commande au shell sans aucun autre argument", () => {
    expect(shell).toContain("__TAURI_INTERNALS__");
    expect(shell).toMatch(/return invoke\(command\);/);
    expect(shell).not.toMatch(/invoke\([^)]*,/);
  });

  it("n’atteint jamais le contrat local et ne connaît ni jeton ni port", () => {
    expect(shell).not.toMatch(/\bfetch\b|XMLHttpRequest|WebSocket|EventSource/);
    expect(shell).not.toMatch(/127\.0\.0\.1|localhost|https?:|wss?:|:\d{4,5}\b/);
    expect(shell).not.toMatch(/\btoken\b|\bjeton\b|\bport\b|X-Thrustline|\btrace\b/i);
  });

  it("ne persiste ni ne journalise", () => {
    expect(shell).not.toMatch(
      /localStorage|sessionStorage|indexedDB|document\.cookie|console\.(?:debug|error|info|log|warn)/,
    );
  });
});

describe("invariants de l’affichage F0004 J3", () => {
  it("dépend exclusivement du résumé typé, sans transport propre", () => {
    expect(control).not.toMatch(/\bfetch\b|XMLHttpRequest|WebSocket|EventSource|navigator\./);
    expect(control).not.toMatch(/127\.0\.0\.1|localhost|https?:|wss?:|__TAURI/);
    expect(control).not.toMatch(/\btoken\b|\bjeton\b|\bport\b|X-Thrustline/i);
  });

  it("ne calcule aucun temps dans la WebView", () => {
    expect(control).not.toMatch(/blockMinutes\s*[-+*/%]|[-+*/%]\s*blockMinutes/);
    expect(control).not.toMatch(/\bDate\b|\bMath\b|performance\./);
  });

  it("ne persiste ni ne journalise le résumé affiché", () => {
    expect(control).not.toMatch(
      /localStorage|sessionStorage|indexedDB|document\.cookie|console\.(?:debug|error|info|log|warn)/,
    );
  });
});
