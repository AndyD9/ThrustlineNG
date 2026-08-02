import { describe, expect, it, vi } from "vitest";

import {
  AircraftPurchaseError,
  purchaseAircraft,
  type PurchaseAircraftInput,
} from "@/features/aircraft-purchase/aircraftPurchase";

const offerId = "81000000-0000-4000-8000-000000000001";
const idempotencyKey = "81000000-0000-4000-8000-000000000002";
const aircraftId = "81000000-0000-4000-8000-000000000003";
const ledgerEntryId = "81000000-0000-4000-8000-000000000004";

const input: PurchaseAircraftInput = {
  accessToken: "user-access-token",
  anonKey: "public-anon-key",
  idempotencyKey,
  offerId,
  supabaseUrl: "https://example.supabase.co",
};

function successfulResponse(overrides: Record<string, unknown> = {}) {
  return Response.json({
    aircraftId,
    ledgerEntryId,
    offerId,
    schemaVersion: 1,
    state: "owned",
    ...overrides,
  });
}

async function expectFailure(
  promise: Promise<unknown>,
  failure: AircraftPurchaseError["failure"],
) {
  await expect(promise).rejects.toMatchObject({
    name: "AircraftPurchaseError",
    failure,
  });
}

describe("purchaseAircraft", () => {
  it("appelle uniquement l’Edge Function avec les headers et le payload fermés", async () => {
    const fetchImplementation = vi.fn(
      async (_request: string | URL | Request, _init?: RequestInit) => successfulResponse(),
    );

    const result = await purchaseAircraft(input, fetchImplementation);

    expect(result).toEqual({ aircraftId, ledgerEntryId, offerId, schemaVersion: 1, state: "owned" });
    expect(fetchImplementation).toHaveBeenCalledOnce();
    const [url, init] = fetchImplementation.mock.calls[0]!;
    expect(url.toString()).toBe("https://example.supabase.co/functions/v1/aircraft-purchase");
    expect(init).toMatchObject({
      method: "POST",
      headers: {
        accept: "application/json",
        apikey: "public-anon-key",
        authorization: "Bearer user-access-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({ offerId, idempotencyKey }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("autorise HTTP uniquement sur loopback", async () => {
    const fetchImplementation = vi.fn(async () => successfulResponse());

    await purchaseAircraft({ ...input, supabaseUrl: "http://127.0.0.1:54321" }, fetchImplementation);
    await purchaseAircraft({ ...input, supabaseUrl: "http://[::1]:54321" }, fetchImplementation);
    await expectFailure(
      purchaseAircraft({ ...input, supabaseUrl: "http://supabase.example.test" }, fetchImplementation),
      "unavailable",
    );

    expect(fetchImplementation).toHaveBeenCalledTimes(2);
  });

  it.each([
    ["UUID offre invalide", { offerId: "not-a-uuid" }, "rejected"],
    ["UUID d’idempotence invalide", { idempotencyKey: "not-a-uuid" }, "rejected"],
    ["token vide", { accessToken: "" }, "authentication-required"],
    ["token avec espace", { accessToken: "bad token" }, "authentication-required"],
    ["clé anonyme avec retour ligne", { anonKey: "bad\nkey" }, "authentication-required"],
    ["URL avec credentials", { supabaseUrl: "https://user@example.test" }, "unavailable"],
    ["URL avec chemin", { supabaseUrl: "https://example.test/project" }, "unavailable"],
  ] as const)("refuse localement %s", async (_name, override, failure) => {
    const fetchImplementation = vi.fn(async () => successfulResponse());

    await expectFailure(purchaseAircraft({ ...input, ...override }, fetchImplementation), failure);

    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it.each([
    [401, "authentication-required"],
    [403, "authentication-required"],
    [400, "rejected"],
    [409, "rejected"],
    [422, "rejected"],
    [429, "unavailable"],
    [500, "unavailable"],
  ] as const)("classe HTTP %s sans lire ni exposer son corps", async (status, failure) => {
    const response = new Response("sensitive upstream detail", { status });

    await expectFailure(purchaseAircraft(input, async () => response), failure);
  });

  it.each([
    ["JSON invalide", new Response("not-json")],
    ["offre divergente", successfulResponse({ offerId: idempotencyKey })],
    ["champ supplémentaire", successfulResponse({ ownerId: aircraftId })],
    ["identifiant invalide", successfulResponse({ aircraftId: "invalid" })],
    ["corps surdimensionné", new Response(`"${"x".repeat(16_385)}"`)],
    [
      "longueur annoncée surdimensionnée",
      new Response("{}", { headers: { "content-length": "16385" } }),
    ],
  ] as const)("refuse une réponse v1 non conforme : %s", async (_name, response) => {
    await expectFailure(purchaseAircraft(input, async () => response), "invalid-response");
  });

  it("classe une panne fetch comme indisponible sans propager son détail", async () => {
    const upstreamError = new Error("token=user-access-token");

    await expectFailure(
      purchaseAircraft(input, async () => Promise.reject(upstreamError)),
      "unavailable",
    );
  });
});
