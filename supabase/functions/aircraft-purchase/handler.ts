const MAX_BODY_BYTES = 4_096;
const UPSTREAM_TIMEOUT_MILLISECONDS = 5_000;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export interface AircraftPurchaseEnvironment {
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
}

interface AircraftPurchaseRequest {
  offerId: string;
  idempotencyKey: string;
}

interface AuthenticatedUser {
  id: string;
  is_anonymous: boolean;
}

interface AircraftPurchaseResponse {
  aircraftId: string;
  ledgerEntryId: string;
  offerId: string;
  schemaVersion: 1;
  state: "owned";
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

class HttpError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function jsonResponse(status: number, body: unknown, extraHeaders?: HeadersInit): Response {
  const headers = new Headers(extraHeaders);
  headers.set("cache-control", "no-store");
  headers.set("content-type", "application/json; charset=utf-8");
  return new Response(JSON.stringify(body), { status, headers });
}

async function readBoundedBody(request: Request): Promise<string> {
  const declaredLength = request.headers.get("content-length");
  if (declaredLength !== null) {
    const parsedLength = Number(declaredLength);
    if (!Number.isSafeInteger(parsedLength) || parsedLength < 0 || parsedLength > MAX_BODY_BYTES) {
      throw new HttpError(413, "request_too_large", "Request body is too large.");
    }
  }

  if (request.body === null) {
    return "";
  }

  const reader = request.body.getReader();
  const decoder = new TextDecoder();
  let byteCount = 0;
  let body = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        return body + decoder.decode();
      }
      byteCount += value.byteLength;
      if (byteCount > MAX_BODY_BYTES) {
        throw new HttpError(413, "request_too_large", "Request body is too large.");
      }
      body += decoder.decode(value, { stream: true });
    }
  } finally {
    reader.releaseLock();
  }
}

function parseRequestBody(rawBody: string): AircraftPurchaseRequest {
  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    throw new HttpError(400, "invalid_request", "Request body must be valid JSON.");
  }

  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, "invalid_request", "Request body is invalid.");
  }

  const record = value as Record<string, unknown>;
  const keys = Object.keys(record).sort();
  if (keys.length !== 2 || keys[0] !== "idempotencyKey" || keys[1] !== "offerId") {
    throw new HttpError(400, "invalid_request", "Request body contains unsupported fields.");
  }

  if (typeof record.offerId !== "string" || !UUID_PATTERN.test(record.offerId)) {
    throw new HttpError(400, "invalid_offer_id", "Offer identifier must be a canonical UUID.");
  }
  if (typeof record.idempotencyKey !== "string" || !UUID_PATTERN.test(record.idempotencyKey)) {
    throw new HttpError(400, "invalid_idempotency_key", "Idempotency key must be a canonical UUID.");
  }

  return { offerId: record.offerId, idempotencyKey: record.idempotencyKey };
}

function requireBearerToken(request: Request): string {
  const authorization = request.headers.get("authorization");
  const token = authorization?.match(/^Bearer ([^\s]+)$/)?.[1];
  if (token === undefined) {
    throw new HttpError(401, "authentication_required", "A valid session is required.");
  }
  return token;
}

function readRuntimeConfiguration(environment: AircraftPurchaseEnvironment): {
  anonKey: string;
  serviceRoleKey: string;
  supabaseUrl: string;
} {
  const supabaseUrl = environment.SUPABASE_URL?.replace(/\/$/, "");
  const anonKey = environment.SUPABASE_ANON_KEY;
  const serviceRoleKey = environment.SUPABASE_SERVICE_ROLE_KEY;
  if (
    supabaseUrl === undefined ||
    !/^https?:\/\//.test(supabaseUrl) ||
    anonKey === undefined ||
    anonKey.length === 0 ||
    serviceRoleKey === undefined ||
    serviceRoleKey.length === 0
  ) {
    throw new HttpError(503, "configuration_unavailable", "Aircraft purchase is not configured.");
  }
  return { anonKey, serviceRoleKey, supabaseUrl };
}

async function authenticateUser(
  fetchImplementation: Fetch,
  configuration: ReturnType<typeof readRuntimeConfiguration>,
  bearerToken: string,
): Promise<AuthenticatedUser> {
  let response: Response;
  try {
    response = await fetchImplementation(`${configuration.supabaseUrl}/auth/v1/user`, {
      method: "GET",
      headers: {
        apikey: configuration.anonKey,
        authorization: `Bearer ${bearerToken}`,
      },
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MILLISECONDS),
    });
  } catch {
    throw new HttpError(503, "authentication_unavailable", "Session verification is unavailable.");
  }

  if (!response.ok) {
    throw new HttpError(401, "authentication_required", "A valid session is required.");
  }

  let value: unknown;
  try {
    value = await response.json();
  } catch {
    throw new HttpError(503, "authentication_unavailable", "Session verification is unavailable.");
  }
  const user = value as Partial<AuthenticatedUser>;
  if (!UUID_PATTERN.test(user.id ?? "") || user.is_anonymous !== false) {
    throw new HttpError(401, "authentication_required", "A non-anonymous session is required.");
  }
  return { id: user.id!, is_anonymous: false };
}

function isAircraftPurchaseResponse(value: unknown): value is AircraftPurchaseResponse {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const response = value as Partial<AircraftPurchaseResponse>;
  return (
    response.schemaVersion === 1 &&
    response.state === "owned" &&
    UUID_PATTERN.test(response.aircraftId ?? "") &&
    UUID_PATTERN.test(response.ledgerEntryId ?? "") &&
    UUID_PATTERN.test(response.offerId ?? "")
  );
}

async function purchaseAircraft(
  fetchImplementation: Fetch,
  configuration: ReturnType<typeof readRuntimeConfiguration>,
  user: AuthenticatedUser,
  request: AircraftPurchaseRequest,
): Promise<AircraftPurchaseResponse> {
  let response: Response;
  try {
    response = await fetchImplementation(`${configuration.supabaseUrl}/rest/v1/rpc/purchase_aircraft`, {
      method: "POST",
      headers: {
        apikey: configuration.serviceRoleKey,
        authorization: `Bearer ${configuration.serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        owner_id: user.id,
        idempotency_key: request.idempotencyKey,
        offer_id: request.offerId,
      }),
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MILLISECONDS),
    });
  } catch {
    throw new HttpError(503, "purchase_unavailable", "Aircraft purchase is unavailable.");
  }

  if (!response.ok) {
    throw new HttpError(409, "purchase_rejected", "Aircraft could not be purchased.");
  }

  let value: unknown;
  try {
    value = await response.json();
  } catch {
    throw new HttpError(502, "invalid_backend_response", "Aircraft purchase returned an invalid response.");
  }
  if (!isAircraftPurchaseResponse(value) || value.offerId !== request.offerId) {
    throw new HttpError(502, "invalid_backend_response", "Aircraft purchase returned an invalid response.");
  }
  return {
    aircraftId: value.aircraftId,
    ledgerEntryId: value.ledgerEntryId,
    offerId: value.offerId,
    schemaVersion: 1,
    state: "owned",
  };
}

export function createAircraftPurchaseHandler(
  environment: AircraftPurchaseEnvironment,
  fetchImplementation: Fetch = fetch,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return jsonResponse(405, { error: { code: "method_not_allowed", message: "Use POST." } }, { allow: "POST" });
    }

    try {
      const bearerToken = requireBearerToken(request);
      const rawBody = await readBoundedBody(request);
      const purchaseRequest = parseRequestBody(rawBody);
      const configuration = readRuntimeConfiguration(environment);
      const user = await authenticateUser(fetchImplementation, configuration, bearerToken);
      const result = await purchaseAircraft(fetchImplementation, configuration, user, purchaseRequest);
      return jsonResponse(200, result);
    } catch (error) {
      if (error instanceof HttpError) {
        return jsonResponse(error.status, { error: { code: error.code, message: error.message } });
      }
      return jsonResponse(500, { error: { code: "internal_error", message: "Aircraft purchase failed." } });
    }
  };
}
