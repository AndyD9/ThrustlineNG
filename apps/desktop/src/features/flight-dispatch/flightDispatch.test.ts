import { describe, expect, it, vi } from "vitest";

import {
  type CreateDispatchDraftInput,
  createDispatchDraft,
  DispatchDraftError,
  normalizeDispatchIntention,
} from "@/features/flight-dispatch/flightDispatch";

const aircraftId = "91000000-0000-4000-8000-000000000001";
const idempotencyKey = "91000000-0000-4000-8000-000000000002";
const dispatchId = "91000000-0000-4000-8000-000000000003";
const createdAt = "2026-08-04T09:15:00Z";

const input: CreateDispatchDraftInput = {
  accessToken: "user-access-token",
  aircraftId,
  anonKey: "public-anon-key",
  arrivalIcao: "LFBO",
  departureIcao: "LFPG",
  idempotencyKey,
  supabaseUrl: "http://127.0.0.1:54321",
};

function draftResponse(overrides: Record<string, unknown> = {}) {
  return Response.json({
    aircraftId,
    arrivalIcao: "LFBO",
    createdAt,
    departureIcao: "LFPG",
    dispatchId,
    schemaVersion: 1,
    state: "draft",
    ...overrides,
  });
}

async function expectFailure(
  promise: Promise<unknown>,
  failure: DispatchDraftError["failure"],
) {
  await expect(promise).rejects.toMatchObject({ name: "DispatchDraftError", failure });
}

describe("normalizeDispatchIntention", () => {
  it("normalise les ICAO en majuscules après trim", () => {
    expect(
      normalizeDispatchIntention({
        aircraftId: ` ${aircraftId} `,
        arrivalIcao: " lfbo ",
        departureIcao: "lfpg",
      }),
    ).toEqual({ aircraftId, arrivalIcao: "LFBO", departureIcao: "LFPG" });
  });

  it.each([
    ["avion hors UUID canonique", { aircraftId: "not-a-uuid" }],
    ["avion en hexadécimal majuscule", { aircraftId: "91000000-0000-4000-8000-00000000000A" }],
    ["ICAO trop court", { departureIcao: "LFP" }],
    ["ICAO trop long", { departureIcao: "LFPGX" }],
    ["ICAO non alphanumérique", { departureIcao: "LF-G" }],
    ["ICAO non ASCII", { departureIcao: "LFPÉ" }],
    ["ICAO identiques", { arrivalIcao: "lfpg" }],
  ] as const)("refuse %s", (_name, override) => {
    expect(() =>
      normalizeDispatchIntention({
        aircraftId,
        arrivalIcao: "LFBO",
        departureIcao: "LFPG",
        ...override,
      }),
    ).toThrow(new DispatchDraftError("rejected"));
  });
});

describe("createDispatchDraft", () => {
  it("appelle uniquement l’Edge Function avec les headers et le payload fermés", async () => {
    const fetchImplementation = vi.fn(
      async (_request: string | URL | Request, _init?: RequestInit) => draftResponse(),
    );

    const draft = await createDispatchDraft(
      { ...input, arrivalIcao: " lfbo ", departureIcao: " lfpg " },
      fetchImplementation,
    );

    expect(draft).toEqual({
      aircraftId,
      arrivalIcao: "LFBO",
      createdAt,
      departureIcao: "LFPG",
      dispatchId,
      schemaVersion: 1,
      state: "draft",
    });
    expect(fetchImplementation).toHaveBeenCalledOnce();
    const [url, init] = fetchImplementation.mock.calls[0]!;
    expect(url.toString()).toBe("http://127.0.0.1:54321/functions/v1/dispatch-draft");
    expect(init).toMatchObject({
      method: "POST",
      headers: {
        accept: "application/json",
        apikey: "public-anon-key",
        authorization: "Bearer user-access-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        aircraftId,
        departureIcao: "LFPG",
        arrivalIcao: "LFBO",
        idempotencyKey,
      }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    expect(Object.keys(init?.headers as Record<string, string>)).toHaveLength(4);
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("n’accepte que les cibles loopback en http", async () => {
    const fetchImplementation = vi.fn(async () => draftResponse());

    await createDispatchDraft({ ...input, supabaseUrl: "http://[::1]:54321" }, fetchImplementation);
    await createDispatchDraft({ ...input, supabaseUrl: "http://localhost:54321" }, fetchImplementation);

    expect(fetchImplementation).toHaveBeenCalledTimes(2);
  });

  it.each([
    ["cible distante", { supabaseUrl: "https://example.supabase.co" }, "unavailable"],
    ["loopback en https", { supabaseUrl: "https://127.0.0.1:54321" }, "unavailable"],
    ["cible non loopback en http", { supabaseUrl: "http://supabase.example.test" }, "unavailable"],
    ["cible avec credentials", { supabaseUrl: "http://user:pass@127.0.0.1:54321" }, "unavailable"],
    ["cible avec requête", { supabaseUrl: "http://127.0.0.1:54321/?a=1" }, "unavailable"],
    ["cible avec fragment", { supabaseUrl: "http://127.0.0.1:54321/#a" }, "unavailable"],
    ["cible avec chemin", { supabaseUrl: "http://127.0.0.1:54321/project" }, "unavailable"],
    ["cible illisible", { supabaseUrl: "not-a-url" }, "unavailable"],
    ["avion non canonique", { aircraftId: "not-a-uuid" }, "rejected"],
    ["clé d’idempotence non canonique", { idempotencyKey: "not-a-uuid" }, "rejected"],
    ["ICAO invalide", { departureIcao: "LF" }, "rejected"],
    ["ICAO identiques", { arrivalIcao: "LFPG" }, "rejected"],
    ["token vide", { accessToken: "" }, "authentication-required"],
    ["token avec espace", { accessToken: "bad token" }, "authentication-required"],
    ["clé anonyme avec retour ligne", { anonKey: "bad\nkey" }, "authentication-required"],
  ] as const)("refuse localement %s avant tout appel réseau", async (_name, override, failure) => {
    const fetchImplementation = vi.fn(async () => draftResponse());

    await expectFailure(createDispatchDraft({ ...input, ...override }, fetchImplementation), failure);

    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it.each([
    [400, "rejected"],
    [401, "authentication-required"],
    [403, "authentication-required"],
    [409, "rejected"],
    [422, "rejected"],
    [429, "unavailable"],
    [500, "unavailable"],
    [503, "unavailable"],
  ] as const)("classe HTTP %s sans exposer son corps", async (status, failure) => {
    const response = new Response("sensitive upstream detail", { status });

    await expectFailure(createDispatchDraft(input, async () => response), failure);
  });

  it.each([
    ["JSON invalide", new Response("not-json")],
    ["tableau", Response.json([])],
    ["état non brouillon", draftResponse({ state: "active" })],
    ["version de schéma inconnue", draftResponse({ schemaVersion: 2 })],
    ["champ supplémentaire", draftResponse({ ownerId: aircraftId })],
    ["avion divergent", draftResponse({ aircraftId: dispatchId })],
    ["départ divergent", draftResponse({ departureIcao: "LFML" })],
    ["arrivée divergente", draftResponse({ arrivalIcao: "LFML" })],
    ["identifiant de dispatch invalide", draftResponse({ dispatchId: "invalid" })],
    ["horodatage invalide", draftResponse({ createdAt: "2026-13-45T99:99:99Z" })],
    ["corps surdimensionné", new Response(`"${"x".repeat(16_385)}"`)],
    [
      "longueur annoncée surdimensionnée",
      new Response("{}", { headers: { "content-length": "16385" } }),
    ],
  ] as const)("refuse une réponse v1 non conforme : %s", async (_name, response) => {
    await expectFailure(createDispatchDraft(input, async () => response), "invalid-response");
  });

  it("classe une panne réseau comme indisponible sans propager son détail", async () => {
    const upstreamError = new Error("token=user-access-token");

    await expectFailure(
      createDispatchDraft(input, async () => Promise.reject(upstreamError)),
      "unavailable",
    );
  });

  it("combine l’annulation appelante et le délai borné", async () => {
    const abortController = new AbortController();

    await expectFailure(
      createDispatchDraft({ ...input, signal: abortController.signal }, async (_request, init) => {
        abortController.abort();
        expect(init?.signal?.aborted).toBe(true);
        throw new DOMException("synthetic abort", "AbortError");
      }),
      "unavailable",
    );
  });

  it("applique le délai borné à la requête", async () => {
    vi.spyOn(AbortSignal, "timeout").mockReturnValueOnce(AbortSignal.abort());

    await expectFailure(
      createDispatchDraft(input, async (_request, init) => {
        expect(init?.signal?.aborted).toBe(true);
        throw new DOMException("aborted", "AbortError");
      }),
      "unavailable",
    );
  });
});
