import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const featureRoot = resolve(import.meta.dirname);
const read = (name: string) => readFileSync(resolve(featureRoot, name), "utf8");

const sources = [read("flightDispatch.ts"), read("FlightDispatchPanel.tsx")].join("\n");

describe("invariants du dispatch desktop", () => {
  it("ne persiste ni ne journalise session, intention ou réponse", () => {
    expect(sources).not.toMatch(
      /localStorage|sessionStorage|indexedDB|document\.cookie|console\.(?:debug|error|info|log|warn)/,
    );
  });

  it("ne contient aucun credential de test ni marqueur privilégié", () => {
    expect(sources).not.toMatch(/service.role|\bsecret\b|\brefresh_token\b/i);
    expect(sources).not.toMatch(/eyJ[A-Za-z0-9_-]{10}/);
    expect(sources).not.toMatch(/(?:apikey|anonKey|accessToken)\s*[:=]\s*["'`]/i);
  });

  it("n’émet aucune autorité métier depuis le client", () => {
    expect(sources).not.toMatch(/ownerId|owner_id|companyId|state\s*:\s*["']active["']/);
    expect(sources).not.toMatch(/insert|update|upsert|delete|\/rest\/v1\//i);
  });

  it("borne la cible au chemin public de l’Edge Function", () => {
    expect(sources).toContain("/functions/v1/dispatch-draft");
    expect(sources.match(/\/functions\/v1\//g)).toHaveLength(1);
    expect(sources).not.toMatch(/https:\/\//);
  });
});
