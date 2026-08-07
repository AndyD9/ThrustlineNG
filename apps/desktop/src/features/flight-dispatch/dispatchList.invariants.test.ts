import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const featureRoot = resolve(import.meta.dirname);
const read = (name: string) => readFileSync(resolve(featureRoot, name), "utf8");

const transport = read("dispatchList.ts");
const sources = [transport, read("DispatchListPanel.tsx")].join("\n");
const dataApiPrefix = "/rest/" + "v1/";
const dataApiResource = `${dataApiPrefix}flight_dispatches`;

describe("invariants de la lecture des dispatchs", () => {
  it("ne persiste ni ne journalise session, requête ou réponse", () => {
    expect(sources).not.toMatch(
      /localStorage|sessionStorage|indexedDB|document\.cookie|console\.(?:debug|error|info|log|warn)/,
    );
  });

  it("ne contient aucun credential de test ni marqueur privilégié", () => {
    expect(sources).not.toMatch(/service.role|\bsecret\b|\brefresh_token\b/i);
    expect(sources).not.toMatch(/eyJ[A-Za-z0-9_-]{10}/);
    expect(sources).not.toMatch(/(?:apikey|anonKey|accessToken)\s*[:=]\s*["'`]/i);
  });

  it("borne la cible à une seule ressource Data API loopback", () => {
    expect(transport).toContain(dataApiResource);
    expect(sources.match(new RegExp(dataApiPrefix, "g"))).toHaveLength(1);
    expect(sources).not.toMatch(/https:\/\//);
    expect(sources).not.toContain("/functions/v1/");
  });

  it("n’émet aucune mutation depuis le client", () => {
    expect(sources).toMatch(/method:\s*"GET"/);
    expect(sources).not.toMatch(/method:\s*["'](?:POST|PUT|PATCH|DELETE)["']/i);
    expect(sources).not.toMatch(/\b(?:insert|upsert|\.delete\(|update\()/i);
  });

  it("ne construit aucun filtre de propriété côté client", () => {
    const parameters = Array.from(
      transport.matchAll(/searchParams\.set\(\s*"([a-z_]+)"/g),
      (match) => match[1],
    );
    expect(parameters).toEqual(["select", "order", "limit", "state"]);
    expect(transport).toContain('"in.(active,draft)"');
    expect(sources).not.toMatch(/\b(?:owner_id|ownerId|company_id|companyId)\b/);
  });
});
