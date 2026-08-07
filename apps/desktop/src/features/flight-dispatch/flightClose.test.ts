import { describe, expect, it, vi } from "vitest";

import {
  type CloseFlightInput,
  closeFlight,
  FlightCloseError,
} from "@/features/flight-dispatch/flightClose";

const dispatchId = "96000000-0000-4000-8000-000000000001";
const idempotencyKey = "96000000-0000-4000-8000-000000000002";
const aircraftId = "96000000-0000-4000-8000-000000000003";
const closedAt = "2026-08-07T11:30:00Z";

const input: CloseFlightInput = {
  accessToken: "user-access-token",
  anonKey: "public-anon-key",
  blockMinutes: 42,
  dispatchId,
  idempotencyKey,
  supabaseUrl: "http://127.0.0.1:54321",
};

function closeResponse(overrides: Record<string, unknown> = {}) {
  return Response.json({
    aircraftId,
    blockMinutes: 42,
    closedAt,
    currencyCode: "EUR",
    dispatchId,
    distanceNm: 188.34,
    outcome: "completed",
    schemaVersion: 1,
    settledAmountMinor: 50201,
    state: "completed",
    ...overrides,
  });
}

async function expectFailure(
  promise: Promise<unknown>,
  failure: FlightCloseError["failure"],
) {
  await expect(promise).rejects.toMatchObject({ name: "FlightCloseError", failure });
}

describe("closeFlight", () => {
  it("appelle uniquement l’Edge Function avec les headers et le rapport fermés", async () => {
    const fetchImplementation = vi.fn(
      async (_request: string | URL | Request, _init?: RequestInit) => closeResponse(),
    );

    const flight = await closeFlight(input, fetchImplementation);

    expect(flight).toEqual({
      aircraftId,
      blockMinutes: 42,
      closedAt,
      currencyCode: "EUR",
      dispatchId,
      distanceNm: 188.34,
      outcome: "completed",
      schemaVersion: 1,
      settledAmountMinor: 50201,
      state: "completed",
    });
    expect(fetchImplementation).toHaveBeenCalledOnce();
    const [url, init] = fetchImplementation.mock.calls[0]!;
    expect(url.toString()).toBe("http://127.0.0.1:54321/functions/v1/flight-close");
    expect(init).toMatchObject({
      method: "POST",
      headers: {
        accept: "application/json",
        apikey: "public-anon-key",
        authorization: "Bearer user-access-token",
        "content-type": "application/json",
      },
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    expect(Object.keys(init?.headers as Record<string, string>)).toHaveLength(4);
    expect(JSON.parse(init?.body as string)).toEqual({
      dispatchId,
      idempotencyKey,
      report: { blockMinutes: 42, outcome: "completed" },
    });
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("n’accepte que les cibles loopback en http", async () => {
    const fetchImplementation = vi.fn(async () => closeResponse());

    await closeFlight({ ...input, supabaseUrl: "http://[::1]:54321" }, fetchImplementation);
    await closeFlight({ ...input, supabaseUrl: "http://localhost:54321" }, fetchImplementation);

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
    ["clé d’idempotence non canonique", { idempotencyKey: "not-a-uuid" }, "rejected"],
    ["temps de bloc nul", { blockMinutes: 0 }, "rejected"],
    ["temps de bloc négatif", { blockMinutes: -1 }, "rejected"],
    ["temps de bloc non entier", { blockMinutes: 41.5 }, "rejected"],
    ["temps de bloc au-delà de la borne", { blockMinutes: 1441 }, "rejected"],
    ["token vide", { accessToken: "" }, "authentication-required"],
    ["token avec espace", { accessToken: "bad token" }, "authentication-required"],
    ["clé anonyme avec retour ligne", { anonKey: "bad\nkey" }, "authentication-required"],
  ] as const)("refuse localement %s avant tout appel réseau", async (_name, override, failure) => {
    const fetchImplementation = vi.fn(async () => closeResponse());

    await expectFailure(closeFlight({ ...input, ...override }, fetchImplementation), failure);

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

    await expectFailure(closeFlight(input, async () => response), failure);
  });

  it.each([
    ["JSON invalide", new Response("not-json")],
    ["tableau", Response.json([])],
    ["état non clôturé", closeResponse({ outcome: "interrupted", state: "interrupted" })],
    ["issue divergente de l’état", closeResponse({ outcome: "interrupted" })],
    ["version de schéma inconnue", closeResponse({ schemaVersion: 2 })],
    ["champ supplémentaire", closeResponse({ ledgerEntryId: aircraftId })],
    [
      "champ manquant",
      Response.json({
        aircraftId,
        blockMinutes: 42,
        closedAt,
        currencyCode: "EUR",
        dispatchId,
        distanceNm: 188.34,
        outcome: "completed",
        schemaVersion: 1,
        state: "completed",
      }),
    ],
    ["dispatch divergent de la demande", closeResponse({ dispatchId: aircraftId })],
    ["identifiant d’avion invalide", closeResponse({ aircraftId: "invalid" })],
    ["horodatage invalide", closeResponse({ closedAt: "2026-13-45T99:99:99Z" })],
    ["montant nul", closeResponse({ settledAmountMinor: 0 })],
    ["montant non entier", closeResponse({ settledAmountMinor: 12.5 })],
    ["devise hors format", closeResponse({ currencyCode: "eur" })],
    ["distance négative", closeResponse({ distanceNm: -1 })],
    ["temps de bloc hors borne", closeResponse({ blockMinutes: 1441 })],
    ["corps surdimensionné", new Response(`"${"x".repeat(16_385)}"`)],
    [
      "longueur annoncée surdimensionnée",
      new Response("{}", { headers: { "content-length": "16385" } }),
    ],
  ] as const)("refuse une réponse v1 non conforme : %s", async (_name, response) => {
    await expectFailure(closeFlight(input, async () => response), "invalid-response");
  });

  it("classe une panne réseau comme indisponible sans propager son détail", async () => {
    const upstreamError = new Error("token=user-access-token");

    await expectFailure(
      closeFlight(input, async () => Promise.reject(upstreamError)),
      "unavailable",
    );
  });

  it("n’émet jamais de second appel pour une même invocation, même sur réponse perdue", async () => {
    const fetchImplementation = vi.fn(async (): Promise<Response> => {
      throw new Error("lost response");
    });

    await expectFailure(closeFlight(input, fetchImplementation), "unavailable");

    expect(fetchImplementation).toHaveBeenCalledOnce();
  });

  it("combine l’annulation appelante et le délai borné", async () => {
    const abortController = new AbortController();

    await expectFailure(
      closeFlight({ ...input, signal: abortController.signal }, async (_request, init) => {
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
      closeFlight(input, async (_request, init) => {
        expect(init?.signal?.aborted).toBe(true);
        throw new DOMException("aborted", "AbortError");
      }),
      "unavailable",
    );
  });
});
