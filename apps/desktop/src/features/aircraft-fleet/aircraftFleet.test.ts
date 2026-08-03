import { describe, expect, it, vi } from "vitest";

import {
  AircraftFleetError,
  loadAircraftFleet,
} from "@/features/aircraft-fleet/aircraftFleet";

const input = {
  accessToken: "private-access-token",
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
};
const rawAircraft = {
  acquired_at: "2026-08-03T10:15:30.123456+00:00",
  acquisition_kind: "purchase",
  aircraft_type_code: "C172",
  display_name: "Cessna 172 Skyhawk",
  id: "97abcdef-0000-4000-8000-000000000001",
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

describe("loadAircraftFleet", () => {
  it("ferme la requête sans filtre propriétaire et transforme la flotte validée", async () => {
    const fetchImplementation = vi.fn<
      (request: string | URL | Request, init?: RequestInit) => Promise<Response>
    >(async () => response([rawAircraft]));

    const result = await loadAircraftFleet(input, fetchImplementation);

    expect(result).toEqual([{
      acquiredAt: rawAircraft.acquired_at,
      acquisitionKind: "purchase",
      aircraftTypeCode: "C172",
      displayName: "Cessna 172 Skyhawk",
      id: rawAircraft.id,
      schemaVersion: 1,
      serialNumber: "SYN-001",
    }]);
    const [url, init] = fetchImplementation.mock.calls[0]!;
    const endpoint = new URL(url.toString());
    expect(`${endpoint.origin}${endpoint.pathname}`).toBe(
      "http://127.0.0.1:54321/rest/" + "v1/company_aircraft",
    );
    expect(Object.fromEntries(endpoint.searchParams)).toEqual({
      limit: "50",
      order: "acquired_at.asc,id.asc",
      select: "id,aircraft_type_code,serial_number,display_name,acquisition_kind,acquired_at,schema_version",
    });
    expect(endpoint.searchParams.has("company_id")).toBe(false);
    expect(endpoint.searchParams.has("owner_id")).toBe(false);
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
  ])("refuse %s avant le réseau", async (_label, override, failure) => {
    const fetchImplementation = vi.fn();
    await expect(loadAircraftFleet({ ...input, ...override }, fetchImplementation))
      .rejects.toMatchObject({ failure });
    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it.each([
    ["champ supplémentaire", [{ ...rawAircraft, company_id: rawAircraft.id }]],
    ["UUID non canonique", [{ ...rawAircraft, id: rawAircraft.id.toUpperCase() }]],
    ["type d'acquisition divergent", [{ ...rawAircraft, acquisition_kind: "lease" }]],
    ["date non canonique", [{ ...rawAircraft, acquired_at: "2026-08-03" }]],
    ["date impossible", [{ ...rawAircraft, acquired_at: "2026-02-30T10:15:30Z" }]],
    ["plus de cinquante avions", Array.from({ length: 51 }, () => rawAircraft)],
    ["identifiants dupliqués", [rawAircraft, rawAircraft]],
    ["objet au lieu d'un tableau", rawAircraft],
  ])("rejette une réponse invalide : %s", async (_label, body) => {
    await expect(loadAircraftFleet(input, async () => response(body))).rejects.toMatchObject({
      failure: "invalid-response",
    });
  });

  it("rejette un corps déclaré ou reçu au-delà de la limite", async () => {
    await expect(loadAircraftFleet(input, async () => response([], {
      headers: { "content-length": "65537" },
    }))).rejects.toMatchObject({ failure: "invalid-response" });
    await expect(loadAircraftFleet(input, async () => new Response(`"${"x".repeat(66_000)}"`)))
      .rejects.toMatchObject({ failure: "invalid-response" });
  });

  it("classe Auth et les pannes sans exposer la réponse", async () => {
    await expect(loadAircraftFleet(input, async () => new Response("secret", { status: 403 })))
      .rejects.toMatchObject({ failure: "authentication-required" });
    await expect(loadAircraftFleet(input, async () => new Response("secret", { status: 500 })))
      .rejects.toMatchObject({ failure: "unavailable" });
    await expect(loadAircraftFleet(input, async () => {
      throw new Error("private upstream detail");
    })).rejects.toEqual(new AircraftFleetError("unavailable"));
  });

  it("applique le délai borné à la requête", async () => {
    vi.spyOn(AbortSignal, "timeout").mockReturnValueOnce(AbortSignal.abort());
    await expect(loadAircraftFleet(input, async (_request, init) => {
      expect(init?.signal?.aborted).toBe(true);
      throw new DOMException("aborted", "AbortError");
    })).rejects.toMatchObject({ failure: "unavailable" });
  });
});
