import { describe, expect, it, vi } from "vitest";

import { DispatchListError, loadDispatchList } from "@/features/flight-dispatch/dispatchList";

const input = {
  accessToken: "private-access-token",
  anonKey: "public-anon-key",
  supabaseUrl: "http://127.0.0.1:54321",
};
const rawDispatch = {
  aircraft_id: "93000000-0000-4000-8000-000000000001",
  arrival_icao: "LFBO",
  created_at: "2026-08-04T09:15:30.123456+00:00",
  departure_icao: "LFPG",
  id: "93000000-0000-4000-8000-0000000000a1",
  schema_version: 1,
  state: "draft",
};
const expectedResource = "/rest/" + "v1/flight_dispatches";

function response(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    headers: { "content-type": "application/json" },
    status: 200,
    ...init,
  });
}

function fetchReturning(body: unknown, init: ResponseInit = {}) {
  return vi.fn<(request: string | URL | Request, init?: RequestInit) => Promise<Response>>(
    async () => response(body, init),
  );
}

function rawDispatchAt(index: number, overrides: Record<string, unknown> = {}) {
  const suffix = index.toString(16).padStart(12, "0");
  return {
    ...rawDispatch,
    aircraft_id: `93000000-0000-4000-8000-${suffix}`,
    id: `94000000-0000-4000-8000-${suffix}`,
    ...overrides,
  };
}

describe("loadDispatchList", () => {
  it("émet un GET constant sans filtre de propriété et transforme les lignes validées", async () => {
    const fetchImplementation = fetchReturning([rawDispatch]);

    const result = await loadDispatchList(input, fetchImplementation);

    expect(result).toEqual([{
      aircraftId: rawDispatch.aircraft_id,
      arrivalIcao: "LFBO",
      createdAt: rawDispatch.created_at,
      departureIcao: "LFPG",
      id: rawDispatch.id,
      schemaVersion: 1,
      state: "draft",
    }]);

    expect(fetchImplementation).toHaveBeenCalledOnce();
    const [url, init] = fetchImplementation.mock.calls[0]!;
    const endpoint = new URL(url.toString());
    expect(`${endpoint.origin}${endpoint.pathname}`).toBe(
      `http://127.0.0.1:54321${expectedResource}`,
    );
    expect(Object.fromEntries(endpoint.searchParams)).toEqual({
      limit: "50",
      order: "created_at.desc,id.desc",
      select: "id,aircraft_id,departure_icao,arrival_icao,state,created_at,schema_version",
    });
    for (const forbidden of ["company_id", "owner_id", "aircraft_id", "id", "state"]) {
      expect(endpoint.searchParams.has(forbidden)).toBe(false);
    }
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

  it("accepte une liste vide", async () => {
    await expect(loadDispatchList(input, fetchReturning([]))).resolves.toEqual([]);
  });

  it("accepte un dispatch déjà actif", async () => {
    const result = await loadDispatchList(
      input,
      fetchReturning([{ ...rawDispatch, state: "active" }]),
    );
    expect(result[0]?.state).toBe("active");
  });

  it("accepte la limite exacte et refuse une ligne de plus", async () => {
    const atLimit = Array.from({ length: 50 }, (_value, index) => rawDispatchAt(index));
    await expect(loadDispatchList(input, fetchReturning(atLimit))).resolves.toHaveLength(50);

    const aboveLimit = Array.from({ length: 51 }, (_value, index) => rawDispatchAt(index));
    await expect(loadDispatchList(input, fetchReturning(aboveLimit))).rejects.toMatchObject({
      failure: "invalid-response",
    });
  });

  it("refuse un identifiant ou un avion dupliqué", async () => {
    await expect(
      loadDispatchList(input, fetchReturning([rawDispatchAt(1), rawDispatchAt(1)])),
    ).rejects.toMatchObject({ failure: "invalid-response" });

    await expect(
      loadDispatchList(
        input,
        fetchReturning([
          rawDispatchAt(1),
          rawDispatchAt(2, { aircraft_id: rawDispatchAt(1).aircraft_id }),
        ]),
      ),
    ).rejects.toMatchObject({ failure: "invalid-response" });
  });

  it.each([
    ["une clé inconnue", { ...rawDispatch, started_at: "2026-08-04T10:00:00Z" }],
    ["une clé manquante", (() => {
      const { state: _state, ...rest } = rawDispatch;
      return rest;
    })()],
    ["un identifiant hors UUID", { ...rawDispatch, id: "93000000-0000-4000-8000-00000000zzz1" }],
    ["un avion hors UUID", { ...rawDispatch, aircraft_id: "not-a-uuid" }],
    ["un OACI trop court", { ...rawDispatch, departure_icao: "LFP" }],
    ["un OACI minuscule", { ...rawDispatch, arrival_icao: "lfbo" }],
    ["des aéroports identiques", { ...rawDispatch, arrival_icao: rawDispatch.departure_icao }],
    ["un état inconnu", { ...rawDispatch, state: "closed" }],
    ["un horodatage non canonique", { ...rawDispatch, created_at: "2026-08-04 09:15:30" }],
    ["un horodatage impossible", { ...rawDispatch, created_at: "2026-02-30T09:15:30Z" }],
    ["une version de schéma inattendue", { ...rawDispatch, schema_version: 2 }],
    ["une ligne nulle", null],
    ["une ligne scalaire", "draft"],
  ])("refuse %s sans rendu partiel", async (_label, row) => {
    await expect(loadDispatchList(input, fetchReturning([row]))).rejects.toMatchObject({
      failure: "invalid-response",
    });
  });

  it("refuse une enveloppe qui n’est pas un tableau", async () => {
    await expect(
      loadDispatchList(input, fetchReturning({ dispatches: [rawDispatch] })),
    ).rejects.toMatchObject({ failure: "invalid-response" });
  });

  it("refuse un corps non JSON", async () => {
    const fetchImplementation = vi.fn<
      (request: string | URL | Request, init?: RequestInit) => Promise<Response>
    >(async () => new Response("<html></html>", { status: 200 }));
    await expect(loadDispatchList(input, fetchImplementation)).rejects.toMatchObject({
      failure: "invalid-response",
    });
  });

  it("refuse une longueur déclarée hors borne sans lire le corps", async () => {
    const fetchImplementation = fetchReturning([rawDispatch], {
      headers: { "content-length": "65537", "content-type": "application/json" },
    });
    await expect(loadDispatchList(input, fetchImplementation)).rejects.toMatchObject({
      failure: "invalid-response",
    });
  });

  it("refuse un corps qui dépasse la borne en cours de lecture", async () => {
    const oversized = "x".repeat(70_000);
    const fetchImplementation = vi.fn<
      (request: string | URL | Request, init?: RequestInit) => Promise<Response>
    >(async () => new Response(JSON.stringify([{ ...rawDispatch, id: oversized }]), {
      headers: { "content-type": "application/json" },
      status: 200,
    }));
    await expect(loadDispatchList(input, fetchImplementation)).rejects.toMatchObject({
      failure: "invalid-response",
    });
  });

  it.each([401, 403])("mappe %i vers authentication-required", async (status) => {
    await expect(
      loadDispatchList(input, fetchReturning([], { status })),
    ).rejects.toMatchObject({ failure: "authentication-required" });
  });

  it.each([404, 429, 500, 503])("mappe %i vers unavailable", async (status) => {
    await expect(
      loadDispatchList(input, fetchReturning([], { status })),
    ).rejects.toMatchObject({ failure: "unavailable" });
  });

  it("mappe une panne réseau vers unavailable sans détail serveur", async () => {
    const fetchImplementation = vi.fn<
      (request: string | URL | Request, init?: RequestInit) => Promise<Response>
    >(async () => {
      throw new Error("ECONNREFUSED 127.0.0.1:54321 upstream détail");
    });

    const failure = await loadDispatchList(input, fetchImplementation).catch(
      (error: unknown) => error,
    );

    expect(failure).toBeInstanceOf(DispatchListError);
    expect(failure).toMatchObject({ failure: "unavailable" });
    expect(String(failure)).not.toContain("ECONNREFUSED");
    expect(String(failure)).not.toContain("détail");
  });

  it.each([
    ["une cible distante", "https://project.supabase.co"],
    ["un hôte non loopback", "http://192.168.1.10:54321"],
    ["des identifiants", "http://user:pass@127.0.0.1:54321"],
    ["une requête", "http://127.0.0.1:54321?debug=1"],
    ["un fragment", "http://127.0.0.1:54321#frag"],
    ["un chemin", "http://127.0.0.1:54321/base"],
    ["une URL invalide", "not-a-url"],
  ])("refuse %s sans émettre de requête", async (_label, supabaseUrl) => {
    const fetchImplementation = fetchReturning([]);
    await expect(
      loadDispatchList({ ...input, supabaseUrl }, fetchImplementation),
    ).rejects.toMatchObject({ failure: "unavailable" });
    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it.each([
    ["un bearer vide", { accessToken: "" }],
    ["un bearer avec saut de ligne", { accessToken: "token\r\ninjected: 1" }],
    ["une clé anonyme vide", { anonKey: "" }],
  ])("refuse %s sans émettre de requête", async (_label, overrides) => {
    const fetchImplementation = fetchReturning([]);
    await expect(
      loadDispatchList({ ...input, ...overrides }, fetchImplementation),
    ).rejects.toMatchObject({ failure: "authentication-required" });
    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it("propage le signal d’annulation fourni", async () => {
    const controller = new AbortController();
    const fetchImplementation = fetchReturning([]);
    await loadDispatchList({ ...input, signal: controller.signal }, fetchImplementation);
    const [, init] = fetchImplementation.mock.calls[0]!;
    expect(init?.signal).toBeInstanceOf(AbortSignal);
    expect(init?.signal?.aborted).toBe(false);
    controller.abort();
    expect(init?.signal?.aborted).toBe(true);
  });
});
