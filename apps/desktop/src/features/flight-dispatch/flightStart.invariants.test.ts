import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const featureRoot = resolve(import.meta.dirname);
const read = (name: string) => readFileSync(resolve(featureRoot, name), "utf8");

const transport = read("flightStart.ts");
const sources = [transport, read("DispatchStartControl.tsx")].join("\n");

describe("invariants du départ de vol desktop", () => {
  it("ne persiste ni ne journalise session, demande ou réponse", () => {
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
    expect(sources).not.toMatch(/ownerId|owner_id|companyId|company_id/);
    expect(sources).not.toMatch(/insert|update|upsert|delete|\/rest\/v1\//i);
    expect(sources).not.toMatch(/\bprice\b|\bcurrency\b/i);
    expect(transport).not.toMatch(/Date\.now|toISOString/);
  });

  it("n’envoie que l’identifiant du dispatch et la clé d’idempotence", () => {
    expect(transport.match(/JSON\.stringify/g)).toHaveLength(1);
    expect(transport).toMatch(
      /body:\s*JSON\.stringify\(\{\s*dispatchId:\s*input\.dispatchId,\s*idempotencyKey:\s*input\.idempotencyKey,\s*\}\)/,
    );
  });

  it("borne la cible au chemin public de l’Edge Function", () => {
    expect(sources).toContain("/functions/v1/flight-start");
    expect(sources.match(/\/functions\/v1\//g)).toHaveLength(1);
    expect(sources).not.toMatch(/https:\/\//);
  });
});
