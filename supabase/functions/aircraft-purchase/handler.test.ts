import assert from "node:assert/strict";
import test from "node:test";

import {
  createAircraftPurchaseHandler,
  type AircraftPurchaseEnvironment,
} from "./handler.ts";

const environment: AircraftPurchaseEnvironment = {
  SUPABASE_URL: "http://127.0.0.1:54321",
  SUPABASE_ANON_KEY: "synthetic-anon-key",
  SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-role-key",
};

const userId = "81000000-0000-4000-8000-000000000001";
const offerId = "82abcdef-0000-4000-8000-000000000002";
const idempotencyKey = "83000000-0000-4000-8000-000000000003";
const aircraftId = "84000000-0000-4000-8000-000000000004";
const ledgerEntryId = "85000000-0000-4000-8000-000000000005";

function request(body: unknown, authorization = "Bearer synthetic-user-jwt"): Request {
  return new Request("http://127.0.0.1/functions/v1/aircraft-purchase", {
    method: "POST",
    headers: { authorization, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function validBody(): Record<string, string> {
  return { offerId, idempotencyKey };
}

function successfulFetch(calls: Array<{ input: string; init?: RequestInit }>) {
  return async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    calls.push({ input: String(input), init });
    if (String(input).endsWith("/auth/v1/user")) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    return Response.json({ aircraftId, ledgerEntryId, offerId, schemaVersion: 1, state: "owned" });
  };
}

test("rejects methods other than POST", async () => {
  const response = await createAircraftPurchaseHandler(environment)(
    new Request("http://127.0.0.1/functions/v1/aircraft-purchase", { method: "GET" }),
  );
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("allow"), "POST");
});

test("requires a bearer session", async () => {
  const response = await createAircraftPurchaseHandler(environment)(request(validBody(), "Basic ignored"));
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, "authentication_required");
});

test("rejects oversized bodies before reading them", async () => {
  const response = await createAircraftPurchaseHandler(environment)(
    new Request("http://127.0.0.1/functions/v1/aircraft-purchase", {
      method: "POST",
      headers: { authorization: "Bearer synthetic-user-jwt", "content-length": "4097" },
      body: "{}",
    }),
  );
  assert.equal(response.status, 413);
});

test("rejects owner, company, price, currency, and other client-controlled fields", async () => {
  let fetchCalled = false;
  const handler = createAircraftPurchaseHandler(environment, async () => {
    fetchCalled = true;
    return new Response();
  });
  const response = await handler(
    request({
      ...validBody(),
      ownerId: userId,
      companyId: "86000000-0000-4000-8000-000000000006",
      priceMinor: 1,
      currencyCode: "USD",
    }),
  );
  assert.equal(response.status, 400);
  assert.equal((await response.json()).error.code, "invalid_request");
  assert.equal(fetchCalled, false);
});

test("requires canonical offer and idempotency UUIDs", async () => {
  const handler = createAircraftPurchaseHandler(environment);
  const offerResponse = await handler(request({ ...validBody(), offerId: offerId.toUpperCase() }));
  const keyResponse = await handler(request({ ...validBody(), idempotencyKey: "not-a-uuid" }));
  assert.equal(offerResponse.status, 400);
  assert.equal(keyResponse.status, 400);
});

test("rejects an invalid or anonymous Auth session", async () => {
  const invalid = createAircraftPurchaseHandler(environment, async () => new Response(null, { status: 401 }));
  const anonymous = createAircraftPurchaseHandler(
    environment,
    async () => Response.json({ id: userId, is_anonymous: true }),
  );
  assert.equal((await invalid(request(validBody()))).status, 401);
  assert.equal((await anonymous(request(validBody()))).status, 401);
});

test("fails closed when Auth is unavailable", async () => {
  const handler = createAircraftPurchaseHandler(environment, async () => {
    throw new Error("synthetic network failure");
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "authentication_unavailable");
});

test("fails closed when runtime configuration is incomplete", async () => {
  const response = await createAircraftPurchaseHandler({ SUPABASE_URL: "invalid" })(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "configuration_unavailable");
});

test("derives the owner from Auth and sends only the RPC contract", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const response = await createAircraftPurchaseHandler(environment, successfulFetch(calls))(request(validBody()));

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { aircraftId, ledgerEntryId, offerId, schemaVersion: 1, state: "owned" });
  assert.equal(calls.length, 2);
  assert.equal(calls[0].input, "http://127.0.0.1:54321/auth/v1/user");
  assert.equal(new Headers(calls[0].init?.headers).get("apikey"), "synthetic-anon-key");
  assert.equal(new Headers(calls[0].init?.headers).get("authorization"), "Bearer synthetic-user-jwt");
  assert.equal(calls[1].input, "http://127.0.0.1:54321/rest/v1/rpc/purchase_aircraft");
  assert.equal(new Headers(calls[1].init?.headers).get("apikey"), "synthetic-service-role-key");
  assert.equal(
    new Headers(calls[1].init?.headers).get("authorization"),
    "Bearer synthetic-service-role-key",
  );
  assert.deepEqual(JSON.parse(String(calls[1].init?.body)), {
    owner_id: userId,
    idempotency_key: idempotencyKey,
    offer_id: offerId,
  });
});

test("does not disclose database rejection details", async () => {
  let call = 0;
  const handler = createAircraftPurchaseHandler(environment, async () => {
    call += 1;
    if (call === 1) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    return Response.json(
      { message: "Company balance is insufficient.", internal: "private ledger detail" },
      { status: 400 },
    );
  });
  const response = await handler(request(validBody()));
  const body = await response.text();
  assert.equal(response.status, 409);
  assert.match(body, /purchase_rejected/);
  assert.doesNotMatch(body, /balance|private ledger/i);
});

test("fails closed when the privileged RPC is unavailable", async () => {
  let call = 0;
  const handler = createAircraftPurchaseHandler(environment, async () => {
    call += 1;
    if (call === 1) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    throw new Error("synthetic RPC timeout");
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "purchase_unavailable");
});

test("fails closed on a malformed privileged response", async () => {
  let call = 0;
  const handler = createAircraftPurchaseHandler(environment, async () => {
    call += 1;
    return call === 1
      ? Response.json({ id: userId, is_anonymous: false })
      : Response.json({ aircraftId, offerId, schemaVersion: 1, state: "owned" });
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 502);
  assert.equal((await response.json()).error.code, "invalid_backend_response");

  let mismatchedCall = 0;
  const mismatchedOffer = createAircraftPurchaseHandler(environment, async () => {
    mismatchedCall += 1;
    return mismatchedCall === 1
      ? Response.json({ id: userId, is_anonymous: false })
      : Response.json({
          aircraftId,
          ledgerEntryId,
          offerId: "86abcdef-0000-4000-8000-000000000006",
          schemaVersion: 1,
          state: "owned",
        });
  });
  const mismatchedResponse = await mismatchedOffer(request(validBody()));
  assert.equal(mismatchedResponse.status, 502);
  assert.equal((await mismatchedResponse.json()).error.code, "invalid_backend_response");
});

test("returns only public fields from a privileged response", async () => {
  let call = 0;
  const handler = createAircraftPurchaseHandler(environment, async () => {
    call += 1;
    return call === 1
      ? Response.json({ id: userId, is_anonymous: false })
      : Response.json({
          aircraftId,
          ledgerEntryId,
          offerId,
          schemaVersion: 1,
          state: "owned",
          ownerId: userId,
          balanceMinor: 33_000_000,
          privateCommandId: "do-not-return",
        });
  });
  const response = await handler(request(validBody()));
  assert.deepEqual(await response.json(), { aircraftId, ledgerEntryId, offerId, schemaVersion: 1, state: "owned" });
});

test("replays the same request without changing the public contract", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const handler = createAircraftPurchaseHandler(environment, successfulFetch(calls));
  const first = await handler(request(validBody()));
  const second = await handler(request(validBody()));
  assert.deepEqual(await first.json(), await second.json());
  assert.equal(calls.length, 4);
});

test("returns no-store JSON responses", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const success = await createAircraftPurchaseHandler(environment, successfulFetch(calls))(request(validBody()));
  const failure = await createAircraftPurchaseHandler(environment)(request({ ...validBody(), offerId: "invalid" }));
  for (const response of [success, failure]) {
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.equal(response.headers.get("content-type"), "application/json; charset=utf-8");
  }
});
