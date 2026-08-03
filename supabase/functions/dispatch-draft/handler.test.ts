import assert from "node:assert/strict";
import test from "node:test";

import { createDispatchDraftHandler, type DispatchDraftEnvironment } from "./handler.ts";

const environment: DispatchDraftEnvironment = {
  SUPABASE_URL: "http://127.0.0.1:54321",
  SUPABASE_ANON_KEY: "synthetic-anon-key",
  SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-role-key",
};

const userId = "91000000-0000-4000-8000-000000000001";
const aircraftId = "92abcdef-0000-4000-8000-000000000002";
const idempotencyKey = "93000000-0000-4000-8000-000000000003";
const dispatchId = "94000000-0000-4000-8000-000000000004";
const createdAt = "2026-08-03T14:15:16.123+00:00";

function request(body: unknown, authorization = "Bearer synthetic-user-jwt"): Request {
  return new Request("http://127.0.0.1/functions/v1/dispatch-draft", {
    method: "POST",
    headers: { authorization, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function validBody(): Record<string, string> {
  return { aircraftId, departureIcao: "LFPG", arrivalIcao: "EGLL", idempotencyKey };
}

function publicResponse(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    aircraftId,
    arrivalIcao: "EGLL",
    createdAt,
    departureIcao: "LFPG",
    dispatchId,
    schemaVersion: 1,
    state: "draft",
    ...overrides,
  };
}

function successfulFetch(calls: Array<{ input: string; init?: RequestInit }>) {
  return async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    calls.push({ input: String(input), init });
    if (String(input).endsWith("/auth/v1/user")) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    return Response.json(publicResponse());
  };
}

test("rejects methods other than POST", async () => {
  const response = await createDispatchDraftHandler(environment)(
    new Request("http://127.0.0.1/functions/v1/dispatch-draft", { method: "GET" }),
  );
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("allow"), "POST");
});

test("requires a bearer session", async () => {
  const response = await createDispatchDraftHandler(environment)(request(validBody(), "Basic ignored"));
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, "authentication_required");
});

test("rejects oversized bodies before reading them", async () => {
  const response = await createDispatchDraftHandler(environment)(
    new Request("http://127.0.0.1/functions/v1/dispatch-draft", {
      method: "POST",
      headers: { authorization: "Bearer synthetic-user-jwt", "content-length": "4097" },
      body: "{}",
    }),
  );
  assert.equal(response.status, 413);
});

test("rejects owner, company, state, time, route, and other client-controlled fields", async () => {
  let fetchCalled = false;
  const handler = createDispatchDraftHandler(environment, async () => {
    fetchCalled = true;
    return new Response();
  });
  const response = await handler(
    request({
      ...validBody(),
      ownerId: userId,
      companyId: "95000000-0000-4000-8000-000000000005",
      state: "draft",
      createdAt,
      route: "DCT",
      simbriefResult: {},
    }),
  );
  assert.equal(response.status, 400);
  assert.equal((await response.json()).error.code, "invalid_request");
  assert.equal(fetchCalled, false);
});

test("requires canonical aircraft and idempotency UUIDs", async () => {
  const handler = createDispatchDraftHandler(environment);
  assert.equal((await handler(request({ ...validBody(), aircraftId: aircraftId.toUpperCase() }))).status, 400);
  assert.equal((await handler(request({ ...validBody(), idempotencyKey: "not-a-uuid" }))).status, 400);
});

test("normalizes valid airports and rejects invalid or identical ICAO codes", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const normalized = await createDispatchDraftHandler(environment, successfulFetch(calls))(
    request({ ...validBody(), departureIcao: " lfpg ", arrivalIcao: "egll" }),
  );
  assert.equal(normalized.status, 200);

  const handler = createDispatchDraftHandler(environment);
  assert.equal((await handler(request({ ...validBody(), departureIcao: "LF-P" }))).status, 400);
  assert.equal((await handler(request({ ...validBody(), arrivalIcao: "LFPG" }))).status, 400);
});

test("rejects an invalid or anonymous Auth session", async () => {
  const invalid = createDispatchDraftHandler(environment, async () => new Response(null, { status: 401 }));
  const anonymous = createDispatchDraftHandler(
    environment,
    async () => Response.json({ id: userId, is_anonymous: true }),
  );
  assert.equal((await invalid(request(validBody()))).status, 401);
  assert.equal((await anonymous(request(validBody()))).status, 401);
});

test("fails closed when Auth is unavailable", async () => {
  const handler = createDispatchDraftHandler(environment, async () => {
    throw new Error("synthetic network failure");
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "authentication_unavailable");
});

test("fails closed when runtime configuration is incomplete", async () => {
  const response = await createDispatchDraftHandler({ SUPABASE_URL: "invalid" })(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "configuration_unavailable");
});

test("derives the owner from Auth and sends only the normalized RPC contract", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const response = await createDispatchDraftHandler(environment, successfulFetch(calls))(
    request({ ...validBody(), departureIcao: " lfpg ", arrivalIcao: "egll" }),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), publicResponse());
  assert.equal(calls.length, 2);
  assert.equal(calls[0].input, "http://127.0.0.1:54321/auth/v1/user");
  assert.equal(new Headers(calls[0].init?.headers).get("apikey"), "synthetic-anon-key");
  assert.equal(new Headers(calls[0].init?.headers).get("authorization"), "Bearer synthetic-user-jwt");
  assert.equal(calls[1].input, "http://127.0.0.1:54321/rest/v1/rpc/create_dispatch_draft");
  assert.equal(new Headers(calls[1].init?.headers).get("apikey"), "synthetic-service-role-key");
  assert.equal(new Headers(calls[1].init?.headers).get("authorization"), "Bearer synthetic-service-role-key");
  assert.deepEqual(JSON.parse(String(calls[1].init?.body)), {
    owner_id: userId,
    idempotency_key: idempotencyKey,
    aircraft_id: aircraftId,
    departure_icao: "LFPG",
    arrival_icao: "EGLL",
  });
});

test("does not disclose database rejection details", async () => {
  let call = 0;
  const handler = createDispatchDraftHandler(environment, async () => {
    call += 1;
    if (call === 1) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    return Response.json(
      { message: "Aircraft belongs to another company.", internal: "private SQL detail" },
      { status: 400 },
    );
  });
  const response = await handler(request(validBody()));
  const body = await response.text();
  assert.equal(response.status, 409);
  assert.match(body, /dispatch_rejected/);
  assert.doesNotMatch(body, /aircraft belongs|private SQL/i);
});

test("fails closed when the privileged RPC is unavailable", async () => {
  let call = 0;
  const handler = createDispatchDraftHandler(environment, async () => {
    call += 1;
    if (call === 1) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    throw new Error("synthetic RPC timeout");
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "dispatch_unavailable");
});

test("fails closed on a malformed or mismatched privileged response", async () => {
  let malformedCall = 0;
  const malformed = createDispatchDraftHandler(environment, async () => {
    malformedCall += 1;
    return malformedCall === 1
      ? Response.json({ id: userId, is_anonymous: false })
      : Response.json(publicResponse({ createdAt: "not-a-timestamp" }));
  });
  assert.equal((await malformed(request(validBody()))).status, 502);

  let mismatchedCall = 0;
  const mismatched = createDispatchDraftHandler(environment, async () => {
    mismatchedCall += 1;
    return mismatchedCall === 1
      ? Response.json({ id: userId, is_anonymous: false })
      : Response.json(publicResponse({ arrivalIcao: "LFPO" }));
  });
  const response = await mismatched(request(validBody()));
  assert.equal(response.status, 502);
  assert.equal((await response.json()).error.code, "invalid_backend_response");
});

test("returns only public fields from a privileged response", async () => {
  let call = 0;
  const handler = createDispatchDraftHandler(environment, async () => {
    call += 1;
    return call === 1
      ? Response.json({ id: userId, is_anonymous: false })
      : Response.json(publicResponse({ companyId: "private", ownerId: userId, privateCommandId: "hidden" }));
  });
  const response = await handler(request(validBody()));
  assert.deepEqual(await response.json(), publicResponse());
});

test("replays the same request without changing the public contract", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const handler = createDispatchDraftHandler(environment, successfulFetch(calls));
  const first = await handler(request(validBody()));
  const second = await handler(request(validBody()));
  assert.deepEqual(await first.json(), await second.json());
  assert.equal(calls.length, 4);
});

test("returns no-store JSON responses", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const success = await createDispatchDraftHandler(environment, successfulFetch(calls))(request(validBody()));
  const failure = await createDispatchDraftHandler(environment)(
    request({ ...validBody(), departureIcao: "invalid" }),
  );
  for (const response of [success, failure]) {
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.equal(response.headers.get("content-type"), "application/json; charset=utf-8");
  }
});
