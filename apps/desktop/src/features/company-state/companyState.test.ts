import { describe, expect, it, vi } from "vitest";

import {
  CompanyPresenceError,
  loadCompanyPresence,
} from "@/features/company-state/companyState";

const input = {
  accessToken: "private-access-token",
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
};
const companyId = "94abcdef-0000-4000-8000-000000000001";

function response(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    headers: { "content-type": "application/json" },
    status: 200,
    ...init,
  });
}

describe("loadCompanyPresence", () => {
  it("ferme la requête et réduit une compagnie propriétaire à sa présence", async () => {
    const fetchImplementation = vi.fn<
      (request: string | URL | Request, init?: RequestInit) => Promise<Response>
    >(async () => response([{ id: companyId }]));

    await expect(loadCompanyPresence(input, fetchImplementation)).resolves.toBe(true);

    const [url, init] = fetchImplementation.mock.calls[0]!;
    const endpoint = new URL(url.toString());
    expect(`${endpoint.origin}${endpoint.pathname}`).toBe(
      "http://127.0.0.1:54321/rest/" + "v1/companies",
    );
    expect(Object.fromEntries(endpoint.searchParams)).toEqual({
      limit: "2",
      select: "id",
    });
    expect(init).toMatchObject({
      cache: "no-store",
      credentials: "omit",
      headers: {
        accept: "application/json",
        apikey: "public-anon-key",
        authorization: "Bearer private-access-token",
      },
      method: "GET",
      referrerPolicy: "no-referrer",
    });
    expect(init?.body).toBeUndefined();
  });

  it("représente une réponse vide sans conserver de donnée", async () => {
    await expect(loadCompanyPresence(input, async () => response([]))).resolves.toBe(false);
  });

  it.each([
    ["cible distante HTTP", { supabaseUrl: "http://example.com" }, "unavailable"],
    ["chemin de base", { supabaseUrl: "http://127.0.0.1:54321/project" }, "unavailable"],
    ["bearer avec espace", { accessToken: "bad token" }, "authentication-required"],
    ["clé avec retour ligne", { anonKey: "bad\nkey" }, "authentication-required"],
    ["bearer excessif", { accessToken: "x".repeat(8_193) }, "authentication-required"],
  ])("refuse %s avant le réseau", async (_label, override, failure) => {
    const fetchImplementation = vi.fn();
    await expect(
      loadCompanyPresence({ ...input, ...override }, fetchImplementation),
    ).rejects.toMatchObject({ failure });
    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it.each([
    ["champ supplémentaire", [{ id: companyId, name: "Private Airways" }]],
    ["UUID non canonique", [{ id: companyId.toUpperCase() }]],
    ["deux compagnies", [{ id: companyId }, { id: companyId }]],
    ["objet au lieu d'un tableau", { id: companyId }],
  ])("rejette une réponse invalide : %s", async (_label, body) => {
    await expect(loadCompanyPresence(input, async () => response(body))).rejects.toMatchObject({
      failure: "invalid-response",
    });
  });

  it("rejette un corps déclaré ou reçu au-delà de la limite", async () => {
    await expect(loadCompanyPresence(input, async () => response([], {
      headers: { "content-length": "8193" },
    }))).rejects.toMatchObject({ failure: "invalid-response" });
    await expect(loadCompanyPresence(input, async () => new Response(`"${"x".repeat(8_300)}"`)))
      .rejects.toMatchObject({ failure: "invalid-response" });
  });

  it("classe Auth et les pannes sans exposer la réponse", async () => {
    for (const status of [401, 403]) {
      await expect(loadCompanyPresence(input, async () => new Response("secret", { status })))
        .rejects.toMatchObject({ failure: "authentication-required" });
    }
    await expect(loadCompanyPresence(input, async () => new Response("secret", { status: 500 })))
      .rejects.toMatchObject({ failure: "unavailable" });
    await expect(loadCompanyPresence(input, async () => {
      throw new Error("private upstream detail");
    })).rejects.toEqual(new CompanyPresenceError("unavailable"));
  });

  it("applique le délai borné à la requête", async () => {
    vi.spyOn(AbortSignal, "timeout").mockReturnValueOnce(AbortSignal.abort());
    await expect(loadCompanyPresence(input, async (_request, init) => {
      expect(init?.signal?.aborted).toBe(true);
      throw new DOMException("aborted", "AbortError");
    })).rejects.toMatchObject({ failure: "unavailable" });
  });
});
