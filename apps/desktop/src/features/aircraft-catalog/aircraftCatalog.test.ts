import { describe, expect, it, vi } from "vitest";

import {
  AircraftCatalogError,
  loadAircraftCatalog,
} from "@/features/aircraft-catalog/aircraftCatalog";

const input = {
  accessToken: "private-access-token",
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
};
const rawOffer = {
  aircraft_type_code: "C172",
  currency_code: "EUR",
  display_name: "Cessna 172 Skyhawk",
  id: "93abcdef-0000-4000-8000-000000000001",
  price_minor: 12_500_000,
  schema_version: 1,
  serial_number: "SYN-001",
};

function response(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    headers: { "content-type": "application/json" },
    status: 200,
    ...init,
  });
}

describe("loadAircraftCatalog", () => {
  it("ferme la requête et transforme une offre strictement validée", async () => {
    const fetchImplementation = vi.fn<
      (request: string | URL | Request, init?: RequestInit) => Promise<Response>
    >(async () => response([rawOffer]));

    const result = await loadAircraftCatalog(input, fetchImplementation);

    expect(result).toEqual([{
      aircraftTypeCode: "C172",
      currencyCode: "EUR",
      displayName: "Cessna 172 Skyhawk",
      id: rawOffer.id,
      priceMinor: 12_500_000,
      schemaVersion: 1,
      serialNumber: "SYN-001",
    }]);
    const [url, init] = fetchImplementation.mock.calls[0]!;
    const endpoint = new URL(url.toString());
    expect(`${endpoint.origin}${endpoint.pathname}`).toBe(
      "http://127.0.0.1:54321/rest/" + "v1/aircraft_purchase_offers",
    );
    expect(Object.fromEntries(endpoint.searchParams)).toEqual({
      limit: "20",
      order: "created_at.asc,id.asc",
      select: "id,aircraft_type_code,serial_number,display_name,price_minor,currency_code,schema_version",
      status: "eq.available",
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

  it.each([
    ["cible distante HTTP", { supabaseUrl: "http://example.com" }, "unavailable"],
    ["chemin de base", { supabaseUrl: "http://127.0.0.1:54321/project" }, "unavailable"],
    ["bearer avec espace", { accessToken: "bad token" }, "authentication-required"],
    ["clé avec retour ligne", { anonKey: "bad\nkey" }, "authentication-required"],
    ["bearer excessif", { accessToken: "x".repeat(8_193) }, "authentication-required"],
  ])("refuse %s avant le réseau", async (_label, override, failure) => {
    const fetchImplementation = vi.fn();
    await expect(
      loadAircraftCatalog({ ...input, ...override }, fetchImplementation),
    ).rejects.toMatchObject({ failure });
    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it.each([
    ["champ supplémentaire", [{ ...rawOffer, status: "available" }]],
    ["UUID non canonique", [{ ...rawOffer, id: rawOffer.id.toUpperCase() }]],
    ["devise divergente", [{ ...rawOffer, currency_code: "USD" }]],
    ["prix fractionnaire", [{ ...rawOffer, price_minor: 12.5 }]],
    ["plus de vingt offres", Array.from({ length: 21 }, () => rawOffer)],
    ["objet au lieu d'un tableau", rawOffer],
  ])("rejette une réponse invalide : %s", async (_label, body) => {
    await expect(loadAircraftCatalog(input, async () => response(body))).rejects.toMatchObject({
      failure: "invalid-response",
    });
  });

  it("rejette un corps déclaré ou reçu au-delà de la limite", async () => {
    await expect(loadAircraftCatalog(input, async () => response([], {
      headers: { "content-length": "32769" },
    }))).rejects.toMatchObject({ failure: "invalid-response" });
    await expect(loadAircraftCatalog(input, async () => new Response(`"${"x".repeat(33_000)}"`)))
      .rejects.toMatchObject({ failure: "invalid-response" });
  });

  it("classe Auth et les pannes sans exposer la réponse", async () => {
    await expect(loadAircraftCatalog(input, async () => new Response("secret", { status: 401 })))
      .rejects.toMatchObject({ failure: "authentication-required" });
    await expect(loadAircraftCatalog(input, async () => new Response("secret", { status: 500 })))
      .rejects.toMatchObject({ failure: "unavailable" });
    await expect(loadAircraftCatalog(input, async () => {
      throw new Error("private upstream detail");
    })).rejects.toEqual(new AircraftCatalogError("unavailable"));
  });

  it("applique le délai borné à la requête", async () => {
    vi.spyOn(AbortSignal, "timeout").mockReturnValueOnce(AbortSignal.abort());
    await expect(loadAircraftCatalog(input, async (_request, init) => {
      expect(init?.signal?.aborted).toBe(true);
      throw new DOMException("aborted", "AbortError");
    })).rejects.toMatchObject({ failure: "unavailable" });
  });
});
