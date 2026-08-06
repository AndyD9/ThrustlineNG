import { describe, expect, it, vi } from "vitest";

import {
  FlightStartError,
  type StartFlightInput,
  startFlight,
} from "@/features/flight-dispatch/flightStart";

const dispatchId = "95000000-0000-4000-8000-000000000001";
const idempotencyKey = "95000000-0000-4000-8000-000000000002";
const aircraftId = "95000000-0000-4000-8000-000000000003";
const startedAt = "2026-08-06T10:30:00Z";

const input: StartFlightInput = {
  accessToken: "user-access-token",
  anonKey: "public-anon-key",
  dispatchId,
  idempotencyKey,
  supabaseUrl: "http://127.0.0.1:54321",
};

function startResponse(overrides: Record<string, unknown> = {}) {
  return Response.json({
    aircraftId,
    dispatchId,
    schemaVersion: 1,
    startedAt,
    state: "active",
    ...overrides,
  });
}

async function expectFailure(
  promise: Promise<unknown>,
  failure: FlightStartError["failure"],
) {
  await expect(promise).rejects.toMatchObject({ name: "FlightStartError", failure });
}

describe("startFlight", () => {
  it("appelle uniquement l’Edge Function avec les headers et le payload fermés", async () => {
    const fetchImplementation = vi.fn(
      async (_request: string | URL | Request, _init?: RequestInit) => startResponse(),
    );

    const flight = await startFlight(input, fetchImplementation);

    expect(flight).toEqual({
      aircraftId,
      dispatchId,
      schemaVersion: 1,
      startedAt,
      state: "active",
    });
    expect(fetchImplementation).toHaveBeenCalledOnce();
    const [url, init] = fetchImplementation.mock.calls[0]!;
    expect(url.toString()).toBe("http://127.0.0.1:54321/functions/v1/flight-start");
    expect(init).toMatchObject({
      method: "POST",
      headers: {
        accept: "application/json",
        apikey: "public-anon-key",
        authorization: "Bearer user-access-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        dispatchId,
        idempotencyKey,
      }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    expect(Object.keys(init?.headers as Record<string, string>)).toHaveLength(4);
    expect(JSON.parse(init?.body as string)).toEqual({ dispatchId, idempotencyKey });
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("n’accepte que les cibles loopback en http", async () => {
    const fetchImplementation = vi.fn(async () => startResponse());

    await startFlight({ ...input, supabaseUrl: "http://[::1]:54321" }, fetchImplementation);
    await startFlight({ ...input, supabaseUrl: "http://localhost:54321" }, fetchImplementation);

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
    ["dispatch hors UUID canonique", { dispatchId: "not-a-uuid" }, "rejected"],
    [
      "dispatch en hexadécimal majuscule",
      { dispatchId: "95000000-0000-4000-8000-00000000000A" },
      "rejected",
    ],
    ["dispatch avec espaces", { dispatchId: ` ${dispatchId} ` }, "rejected"],
    ["clé d’idempotence non canonique", { idempotencyKey: "not-a-uuid" }, "rejected"],
    ["token vide", { accessToken: "" }, "authentication-required"],
    ["token avec espace", { accessToken: "bad token" }, "authentication-required"],
    ["clé anonyme avec retour ligne", { anonKey: "bad\nkey" }, "authentication-required"],
  ] as const)("refuse localement %s avant tout appel réseau", async (_name, override, failure) => {
    const fetchImplementation = vi.fn(async () => startResponse());

    await expectFailure(startFlight({ ...input, ...override }, fetchImplementation), failure);

    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it.each([
    [400, "rejected"],
    [401, "authentication-required"],
    [403, "authentication-required"],
    [409, "rejected"],
    [413, "unavailable"],
    [422, "rejected"],
    [429, "unavailable"],
    [500, "unavailable"],
    [503, "unavailable"],
  ] as const)("classe HTTP %s sans exposer son corps", async (status, failure) => {
    const response = new Response("sensitive upstream detail", { status });

    await expectFailure(startFlight(input, async () => response), failure);
  });

  it.each([
    ["JSON invalide", new Response("not-json")],
    ["tableau", Response.json([])],
    ["état non actif", startResponse({ state: "draft" })],
    ["version de schéma inconnue", startResponse({ schemaVersion: 2 })],
    ["champ supplémentaire", startResponse({ ownerId: aircraftId })],
    [
      "champ manquant",
      Response.json({ aircraftId, dispatchId, schemaVersion: 1, state: "active" }),
    ],
    ["dispatch divergent de la demande", startResponse({ dispatchId: aircraftId })],
    ["identifiant d’avion invalide", startResponse({ aircraftId: "invalid" })],
    ["horodatage invalide", startResponse({ startedAt: "2026-13-45T99:99:99Z" })],
    ["corps surdimensionné", new Response(`"${"x".repeat(16_385)}"`)],
    [
      "longueur annoncée surdimensionnée",
      new Response("{}", { headers: { "content-length": "16385" } }),
    ],
  ] as const)("refuse une réponse v1 non conforme : %s", async (_name, response) => {
    await expectFailure(startFlight(input, async () => response), "invalid-response");
  });

  it("classe une panne réseau comme indisponible sans propager son détail", async () => {
    const upstreamError = new Error("token=user-access-token");

    await expectFailure(
      startFlight(input, async () => Promise.reject(upstreamError)),
      "unavailable",
    );
  });

  it("n’émet jamais de second appel pour une même invocation, même sur réponse perdue", async () => {
    const fetchImplementation = vi.fn(async (): Promise<Response> => {
      throw new Error("lost response");
    });

    await expectFailure(startFlight(input, fetchImplementation), "unavailable");

    expect(fetchImplementation).toHaveBeenCalledOnce();
  });

  it("combine l’annulation appelante et le délai borné", async () => {
    const abortController = new AbortController();

    await expectFailure(
      startFlight({ ...input, signal: abortController.signal }, async (_request, init) => {
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
      startFlight(input, async (_request, init) => {
        expect(init?.signal?.aborted).toBe(true);
        throw new DOMException("aborted", "AbortError");
      }),
      "unavailable",
    );
  });
});
