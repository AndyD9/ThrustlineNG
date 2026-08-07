import assert from "node:assert/strict";
import test from "node:test";

import { createFlightCloseHandler, type FlightCloseEnvironment } from "./handler.ts";

const environment: FlightCloseEnvironment = {
  SUPABASE_URL: "http://127.0.0.1:54321",
  SUPABASE_ANON_KEY: "synthetic-anon-key",
  SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-role-key",
};

const userId = "91000000-0000-4000-8000-000000000001";
const aircraftId = "92abcdef-0000-4000-8000-000000000002";
const idempotencyKey = "93000000-0000-4000-8000-000000000003";
const dispatchId = "94abcdef-0000-4000-8000-000000000004";
const ledgerEntryId = "95000000-0000-4000-8000-000000000005";
const closedAt = "2026-08-07T10:15:16.123+00:00";

function request(body: unknown, authorization = "Bearer synthetic-user-jwt"): Request {
  return new Request("http://127.0.0.1/functions/v1/flight-close", {
    method: "POST",
    headers: { authorization, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function validBody(): Record<string, unknown> {
  return {
    dispatchId,
    idempotencyKey,
    report: { blockMinutes: 42, outcome: "completed" },
  };
}

function publicResponse(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
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
  };
}

function successfulFetch(calls: Array<{ input: string; init?: RequestInit }>) {
  return async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    calls.push({ input: String(input), init });
    if (String(input).endsWith("/auth/v1/user")) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    return Response.json({ ...publicResponse(), ledgerEntryId });
  };
}

test("rejects methods other than POST", async () => {
  const response = await createFlightCloseHandler(environment)(
    new Request("http://127.0.0.1/functions/v1/flight-close", { method: "GET" }),
  );
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("allow"), "POST");
});

test("requires a bearer session", async () => {
  const response = await createFlightCloseHandler(environment)(request(validBody(), "Basic ignored"));
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, "authentication_required");
});

test("rejects oversized bodies before reading them", async () => {
  const response = await createFlightCloseHandler(environment)(
    new Request("http://127.0.0.1/functions/v1/flight-close", {
      method: "POST",
      headers: { authorization: "Bearer synthetic-user-jwt", "content-length": "4097" },
      body: "{}",
    }),
  );
  assert.equal(response.status, 413);
});

test("rejects owner, company, state, time, aircraft and other client-controlled fields", async () => {
  let fetchCalled = false;
  const handler = createFlightCloseHandler(environment, async () => {
    fetchCalled = true;
    return new Response();
  });
  const response = await handler(
    request({
      ...validBody(),
      ownerId: userId,
      companyId: "96000000-0000-4000-8000-000000000006",
      aircraftId,
      state: "completed",
      closedAt,
    }),
  );
  assert.equal(response.status, 400);
  assert.equal((await response.json()).error.code, "invalid_request");
  assert.equal(fetchCalled, false);
});

test("rejects amount, distance, multiplier and currency from a client report", async () => {
  const handler = createFlightCloseHandler(environment);
  for (const forged of [
    { settledAmountMinor: 2_000_000 },
    { amountMinor: 2_000_000 },
    { distanceNm: 9_000 },
    { hubMultiplier: 2 },
    { currencyCode: "EUR" },
  ]) {
    const response = await handler(
      request({
        dispatchId,
        idempotencyKey,
        report: { blockMinutes: 42, outcome: "completed", ...forged },
      }),
    );
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, "invalid_report");
  }
});

test("requires canonical dispatch and idempotency UUIDs", async () => {
  const handler = createFlightCloseHandler(environment);
  assert.equal((await handler(request({ ...validBody(), dispatchId: dispatchId.toUpperCase() }))).status, 400);
  assert.equal((await handler(request({ ...validBody(), idempotencyKey: "not-a-uuid" }))).status, 400);
});

test("rejects a report outside the closed outcome and bounds", async () => {
  const handler = createFlightCloseHandler(environment);
  for (const report of [
    { blockMinutes: 42, outcome: "aborted" },
    { blockMinutes: -1, outcome: "completed" },
    { blockMinutes: 1441, outcome: "completed" },
    { blockMinutes: 41.5, outcome: "completed" },
    { blockMinutes: "42", outcome: "completed" },
    { outcome: "completed" },
    { blockMinutes: 42 },
    { blockMinutes: 42, outcome: "completed", landingVerticalSpeedFpm: -6001 },
    { blockMinutes: 42, outcome: "completed", fuelUsedKg: 400_001 },
    { blockMinutes: 42, outcome: "completed", fuelUsedKg: 10.5 },
    null,
    [],
    "report",
  ]) {
    const response = await handler(request({ dispatchId, idempotencyKey, report }));
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, "invalid_report");
  }
});

test("rejects an invalid or anonymous Auth session", async () => {
  const invalid = createFlightCloseHandler(environment, async () => new Response(null, { status: 401 }));
  const anonymous = createFlightCloseHandler(
    environment,
    async () => Response.json({ id: userId, is_anonymous: true }),
  );
  assert.equal((await invalid(request(validBody()))).status, 401);
  assert.equal((await anonymous(request(validBody()))).status, 401);
});

test("fails closed when Auth is unavailable", async () => {
  const handler = createFlightCloseHandler(environment, async () => {
    throw new Error("synthetic network failure");
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "authentication_unavailable");
});

test("fails closed when runtime configuration is incomplete", async () => {
  const response = await createFlightCloseHandler({ SUPABASE_URL: "invalid" })(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "configuration_unavailable");
});

test("derives the owner from Auth and sends only the RPC contract", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const response = await createFlightCloseHandler(environment, successfulFetch(calls))(
    request({
      dispatchId,
      idempotencyKey,
      report: {
        blockMinutes: 42,
        fuelUsedKg: 950,
        landingVerticalSpeedFpm: -180,
        outcome: "completed",
      },
    }),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), publicResponse());
  assert.equal(calls.length, 2);
  assert.equal(calls[0].input, "http://127.0.0.1:54321/auth/v1/user");
  assert.equal(new Headers(calls[0].init?.headers).get("apikey"), "synthetic-anon-key");
  assert.equal(new Headers(calls[0].init?.headers).get("authorization"), "Bearer synthetic-user-jwt");
  assert.equal(calls[1].input, "http://127.0.0.1:54321/rest/v1/rpc/close_flight");
  assert.equal(new Headers(calls[1].init?.headers).get("apikey"), "synthetic-service-role-key");
  assert.equal(new Headers(calls[1].init?.headers).get("authorization"), "Bearer synthetic-service-role-key");
  assert.deepEqual(JSON.parse(String(calls[1].init?.body)), {
    owner_id: userId,
    idempotency_key: idempotencyKey,
    dispatch_id: dispatchId,
    report: {
      blockMinutes: 42,
      fuelUsedKg: 950,
      landingVerticalSpeedFpm: -180,
      outcome: "completed",
    },
  });
});

test("does not disclose database rejection details", async () => {
  let call = 0;
  const handler = createFlightCloseHandler(environment, async () => {
    call += 1;
    if (call === 1) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    return Response.json(
      { message: "Dispatch is unavailable for closure.", internal: "private SQL detail" },
      { status: 400 },
    );
  });
  const response = await handler(request(validBody()));
  const body = await response.text();
  assert.equal(response.status, 409);
  assert.match(body, /flight_close_rejected/);
  assert.doesNotMatch(body, /dispatch is unavailable|private SQL/i);
});

test("returns the same redacted refusal for unknown, foreign and already closed dispatches", async () => {
  const refusals: string[] = [];
  for (const message of [
    "Dispatch is unavailable for closure.",
    "Flight closure is unavailable.",
    "Idempotency key was already used with a different payload.",
  ]) {
    let call = 0;
    const handler = createFlightCloseHandler(environment, async () => {
      call += 1;
      return call === 1
        ? Response.json({ id: userId, is_anonymous: false })
        : Response.json({ message }, { status: 400 });
    });
    const response = await handler(request(validBody()));
    assert.equal(response.status, 409);
    refusals.push(await response.text());
  }
  assert.equal(new Set(refusals).size, 1);
});

test("fails closed when the privileged RPC is unavailable", async () => {
  let call = 0;
  const handler = createFlightCloseHandler(environment, async () => {
    call += 1;
    if (call === 1) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    throw new Error("synthetic RPC timeout");
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "flight_close_unavailable");
});

test("fails closed on a malformed or mismatched privileged response", async () => {
  for (const overrides of [
    { closedAt: "not-a-timestamp" },
    { settledAmountMinor: 0 },
    { settledAmountMinor: 12.5 },
    { currencyCode: "eur" },
    { distanceNm: -1 },
    { blockMinutes: 1441 },
    { state: "interrupted" },
  ]) {
    let call = 0;
    const malformed = createFlightCloseHandler(environment, async () => {
      call += 1;
      return call === 1
        ? Response.json({ id: userId, is_anonymous: false })
        : Response.json(publicResponse(overrides));
    });
    assert.equal((await malformed(request(validBody()))).status, 502);
  }

  let mismatchedCall = 0;
  const mismatched = createFlightCloseHandler(environment, async () => {
    mismatchedCall += 1;
    return mismatchedCall === 1
      ? Response.json({ id: userId, is_anonymous: false })
      : Response.json(publicResponse({ dispatchId: "97000000-0000-4000-8000-000000000007" }));
  });
  const response = await mismatched(request(validBody()));
  assert.equal(response.status, 502);
  assert.equal((await response.json()).error.code, "invalid_backend_response");
});

test("returns only public fields from a privileged response", async () => {
  let call = 0;
  const handler = createFlightCloseHandler(environment, async () => {
    call += 1;
    return call === 1
      ? Response.json({ id: userId, is_anonymous: false })
      : Response.json(
          publicResponse({ companyId: "private", ledgerEntryId, ownerId: userId, payloadSha256: "hidden" }),
        );
  });
  const response = await handler(request(validBody()));
  const body = await response.json();
  assert.deepEqual(body, publicResponse());
  assert.equal("ledgerEntryId" in body, false);
});

test("replays the same request without changing the public contract", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const handler = createFlightCloseHandler(environment, successfulFetch(calls));
  const first = await handler(request(validBody()));
  const second = await handler(request(validBody()));
  assert.deepEqual(await first.json(), await second.json());
  assert.equal(calls.length, 4);
});

test("returns no-store JSON responses", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const success = await createFlightCloseHandler(environment, successfulFetch(calls))(request(validBody()));
  const failure = await createFlightCloseHandler(environment)(
    request({ ...validBody(), dispatchId: "invalid" }),
  );
  for (const response of [success, failure]) {
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.equal(response.headers.get("content-type"), "application/json; charset=utf-8");
  }
});
