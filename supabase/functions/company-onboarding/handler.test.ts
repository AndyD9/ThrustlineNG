import assert from "node:assert/strict";
import test from "node:test";

import { createCompanyOnboardingHandler, type CompanyOnboardingEnvironment } from "./handler.ts";

const environment: CompanyOnboardingEnvironment = {
  SUPABASE_URL: "http://127.0.0.1:54321",
  SUPABASE_ANON_KEY: "synthetic-anon-key",
  SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-role-key",
  COMPANY_OPENING_BALANCE_MINOR: "43000000",
  COMPANY_OPENING_CURRENCY: "EUR",
};

const userId = "71000000-0000-4000-8000-000000000001";
const idempotencyKey = "72abcdef-0000-4000-8000-000000000002";
const companyId = "73000000-0000-4000-8000-000000000003";
const openingEntryId = "74000000-0000-4000-8000-000000000004";

function request(body: unknown, authorization = "Bearer synthetic-user-jwt"): Request {
  return new Request("http://127.0.0.1/functions/v1/company-onboarding", {
    method: "POST",
    headers: {
      authorization,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function validBody(): Record<string, string> {
  return { companyName: "Synthetic Airways", idempotencyKey };
}

function successfulFetch(calls: Array<{ input: string; init?: RequestInit }>) {
  return async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    calls.push({ input: String(input), init });
    if (String(input).endsWith("/auth/v1/user")) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    return Response.json({ companyId, openingEntryId, schemaVersion: 1, state: "active" });
  };
}

test("rejects methods other than POST", async () => {
  const response = await createCompanyOnboardingHandler(environment)(
    new Request("http://127.0.0.1/functions/v1/company-onboarding", { method: "GET" }),
  );
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("allow"), "POST");
});

test("requires a bearer session", async () => {
  const response = await createCompanyOnboardingHandler(environment)(request(validBody(), "Basic ignored"));
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, "authentication_required");
});

test("rejects oversized bodies before reading them", async () => {
  const response = await createCompanyOnboardingHandler(environment)(
    new Request("http://127.0.0.1/functions/v1/company-onboarding", {
      method: "POST",
      headers: { authorization: "Bearer synthetic-user-jwt", "content-length": "4097" },
      body: "{}",
    }),
  );
  assert.equal(response.status, 413);
});

test("rejects owner, amount, currency, and other client-controlled fields", async () => {
  let fetchCalled = false;
  const handler = createCompanyOnboardingHandler(environment, async () => {
    fetchCalled = true;
    return new Response();
  });
  const response = await handler(
    request({ ...validBody(), ownerId: userId, openingAmountMinor: 1, currencyCode: "USD" }),
  );
  assert.equal(response.status, 400);
  assert.equal((await response.json()).error.code, "invalid_request");
  assert.equal(fetchCalled, false);
});

test("requires a normalized name and canonical UUID", async () => {
  const handler = createCompanyOnboardingHandler(environment);
  const nameResponse = await handler(request({ ...validBody(), companyName: " Synthetic Airways " }));
  const keyResponse = await handler(request({ ...validBody(), idempotencyKey: idempotencyKey.toUpperCase() }));
  assert.equal(nameResponse.status, 400);
  assert.equal(keyResponse.status, 400);
});

test("fails closed when server economic configuration is invalid", async () => {
  const response = await createCompanyOnboardingHandler({ ...environment, COMPANY_OPENING_CURRENCY: "eur" })(
    request(validBody()),
  );
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "configuration_unavailable");
});

test("rejects an invalid or anonymous Auth session", async () => {
  const invalid = createCompanyOnboardingHandler(environment, async () => new Response(null, { status: 401 }));
  const anonymous = createCompanyOnboardingHandler(
    environment,
    async () => Response.json({ id: userId, is_anonymous: true }),
  );
  assert.equal((await invalid(request(validBody()))).status, 401);
  assert.equal((await anonymous(request(validBody()))).status, 401);
});

test("fails closed when Auth is unavailable", async () => {
  const handler = createCompanyOnboardingHandler(environment, async () => {
    throw new Error("synthetic network failure");
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "authentication_unavailable");
});

test("derives the owner from Auth and keeps economic inputs server-side", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const response = await createCompanyOnboardingHandler(environment, successfulFetch(calls))(request(validBody()));

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { companyId, openingEntryId, schemaVersion: 1, state: "active" });
  assert.equal(calls.length, 2);
  assert.equal(calls[0].input, "http://127.0.0.1:54321/auth/v1/user");
  assert.equal(new Headers(calls[0].init?.headers).get("apikey"), "synthetic-anon-key");
  assert.equal(new Headers(calls[0].init?.headers).get("authorization"), "Bearer synthetic-user-jwt");
  assert.equal(
    calls[1].input,
    "http://127.0.0.1:54321/rest/v1/rpc/create_company_with_opening_balance",
  );
  assert.equal(new Headers(calls[1].init?.headers).get("apikey"), "synthetic-service-role-key");
  assert.deepEqual(JSON.parse(String(calls[1].init?.body)), {
    company_name: "Synthetic Airways",
    currency_code: "EUR",
    idempotency_key: idempotencyKey,
    opening_amount_minor: 43000000,
    owner_id: userId,
  });
});

test("does not disclose database rejection details", async () => {
  let call = 0;
  const handler = createCompanyOnboardingHandler(environment, async () => {
    call += 1;
    if (call === 1) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    return Response.json({ message: "Company already exists.", internal: "private table detail" }, { status: 400 });
  });
  const response = await handler(request(validBody()));
  const body = await response.text();
  assert.equal(response.status, 409);
  assert.match(body, /onboarding_rejected/);
  assert.doesNotMatch(body, /already exists|private table/i);
});

test("fails closed when the privileged RPC is unavailable", async () => {
  let call = 0;
  const handler = createCompanyOnboardingHandler(environment, async () => {
    call += 1;
    if (call === 1) {
      return Response.json({ id: userId, is_anonymous: false });
    }
    throw new Error("synthetic RPC timeout");
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "onboarding_unavailable");
});

test("fails closed on a malformed privileged response", async () => {
  let call = 0;
  const handler = createCompanyOnboardingHandler(environment, async () => {
    call += 1;
    return call === 1
      ? Response.json({ id: userId, is_anonymous: false })
      : Response.json({ companyId, schemaVersion: 1, state: "active" });
  });
  const response = await handler(request(validBody()));
  assert.equal(response.status, 502);
  assert.equal((await response.json()).error.code, "invalid_backend_response");
});

test("returns no-store JSON responses", async () => {
  const calls: Array<{ input: string; init?: RequestInit }> = [];
  const response = await createCompanyOnboardingHandler(environment, successfulFetch(calls))(request(validBody()));
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.headers.get("content-type"), "application/json; charset=utf-8");
});
