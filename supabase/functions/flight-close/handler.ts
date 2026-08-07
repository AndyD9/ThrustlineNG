const MAX_BODY_BYTES = 4_096;
const UPSTREAM_TIMEOUT_MILLISECONDS = 5_000;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const TIMESTAMP_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;
const CURRENCY_PATTERN = /^[A-Z]{3}$/;
const MAXIMUM_BLOCK_MINUTES = 1_440;
const LANDING_RATE_BOUND_FPM = 6_000;
const MAXIMUM_FUEL_USED_KG = 400_000;
const MAXIMUM_DISTANCE_NM = 20_000;

export interface FlightCloseEnvironment {
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
}

interface FlightReport {
  blockMinutes: number;
  fuelUsedKg?: number;
  landingVerticalSpeedFpm?: number;
  outcome: "completed" | "interrupted";
}

interface FlightCloseRequest {
  dispatchId: string;
  idempotencyKey: string;
  report: FlightReport;
}

interface AuthenticatedUser {
  id: string;
  is_anonymous: boolean;
}

interface FlightCloseResponse {
  aircraftId: string;
  blockMinutes: number;
  closedAt: string;
  currencyCode: string;
  dispatchId: string;
  distanceNm: number;
  outcome: "completed" | "interrupted";
  schemaVersion: 1;
  settledAmountMinor: number;
  state: "completed" | "interrupted";
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

function isBoundedInteger(value: unknown, minimum: number, maximum: number): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}

function parseReport(value: unknown): FlightReport {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, "invalid_report", "Flight report is invalid.");
  }

  const record = value as Record<string, unknown>;
  const allowedKeys = ["blockMinutes", "fuelUsedKg", "landingVerticalSpeedFpm", "outcome"];
  const keys = Object.keys(record).sort();
  if (
    keys.some((key) => !allowedKeys.includes(key)) ||
    !keys.includes("blockMinutes") ||
    !keys.includes("outcome")
  ) {
    throw new HttpError(400, "invalid_report", "Flight report contains unsupported fields.");
  }

  if (record.outcome !== "completed" && record.outcome !== "interrupted") {
    throw new HttpError(400, "invalid_report", "Flight report is invalid.");
  }
  if (!isBoundedInteger(record.blockMinutes, 0, MAXIMUM_BLOCK_MINUTES)) {
    throw new HttpError(400, "invalid_report", "Flight report is invalid.");
  }

  const report: FlightReport = {
    blockMinutes: record.blockMinutes,
    outcome: record.outcome,
  };

  if ("landingVerticalSpeedFpm" in record) {
    if (!isBoundedInteger(record.landingVerticalSpeedFpm, -LANDING_RATE_BOUND_FPM, LANDING_RATE_BOUND_FPM)) {
      throw new HttpError(400, "invalid_report", "Flight report is invalid.");
    }
    report.landingVerticalSpeedFpm = record.landingVerticalSpeedFpm;
  }
  if ("fuelUsedKg" in record) {
    if (!isBoundedInteger(record.fuelUsedKg, 0, MAXIMUM_FUEL_USED_KG)) {
      throw new HttpError(400, "invalid_report", "Flight report is invalid.");
    }
    report.fuelUsedKg = record.fuelUsedKg;
  }

  return report;
}

function parseRequestBody(rawBody: string): FlightCloseRequest {
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
  if (keys.length !== 3 || keys[0] !== "dispatchId" || keys[1] !== "idempotencyKey" || keys[2] !== "report") {
    throw new HttpError(400, "invalid_request", "Request body contains unsupported fields.");
  }

  if (typeof record.dispatchId !== "string" || !UUID_PATTERN.test(record.dispatchId)) {
    throw new HttpError(400, "invalid_dispatch_id", "Dispatch identifier must be a canonical UUID.");
  }
  if (typeof record.idempotencyKey !== "string" || !UUID_PATTERN.test(record.idempotencyKey)) {
    throw new HttpError(400, "invalid_idempotency_key", "Idempotency key must be a canonical UUID.");
  }

  return {
    dispatchId: record.dispatchId,
    idempotencyKey: record.idempotencyKey,
    report: parseReport(record.report),
  };
}

function requireBearerToken(request: Request): string {
  const authorization = request.headers.get("authorization");
  const token = authorization?.match(/^Bearer ([^\s]+)$/)?.[1];
  if (token === undefined) {
    throw new HttpError(401, "authentication_required", "A valid session is required.");
  }
  return token;
}

function readRuntimeConfiguration(environment: FlightCloseEnvironment): {
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
    throw new HttpError(503, "configuration_unavailable", "Flight closure is not configured.");
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

function isFlightCloseResponse(value: unknown): value is FlightCloseResponse & Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const response = value as Partial<FlightCloseResponse>;
  return (
    response.schemaVersion === 1 &&
    (response.state === "completed" || response.state === "interrupted") &&
    response.outcome === response.state &&
    UUID_PATTERN.test(response.aircraftId ?? "") &&
    UUID_PATTERN.test(response.dispatchId ?? "") &&
    TIMESTAMP_PATTERN.test(response.closedAt ?? "") &&
    !Number.isNaN(Date.parse(response.closedAt ?? "")) &&
    isBoundedInteger(response.blockMinutes, 0, MAXIMUM_BLOCK_MINUTES) &&
    typeof response.distanceNm === "number" &&
    Number.isFinite(response.distanceNm) &&
    response.distanceNm >= 0 &&
    response.distanceNm <= MAXIMUM_DISTANCE_NM &&
    typeof response.settledAmountMinor === "number" &&
    Number.isSafeInteger(response.settledAmountMinor) &&
    response.settledAmountMinor > 0 &&
    typeof response.currencyCode === "string" &&
    CURRENCY_PATTERN.test(response.currencyCode)
  );
}

async function closeFlight(
  fetchImplementation: Fetch,
  configuration: ReturnType<typeof readRuntimeConfiguration>,
  user: AuthenticatedUser,
  request: FlightCloseRequest,
): Promise<FlightCloseResponse> {
  let response: Response;
  try {
    response = await fetchImplementation(`${configuration.supabaseUrl}/rest/v1/rpc/close_flight`, {
      method: "POST",
      headers: {
        apikey: configuration.serviceRoleKey,
        authorization: `Bearer ${configuration.serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        owner_id: user.id,
        idempotency_key: request.idempotencyKey,
        dispatch_id: request.dispatchId,
        report: request.report,
      }),
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MILLISECONDS),
    });
  } catch {
    throw new HttpError(503, "flight_close_unavailable", "Flight closure is unavailable.");
  }

  if (!response.ok) {
    throw new HttpError(409, "flight_close_rejected", "Flight could not be closed.");
  }

  let value: unknown;
  try {
    value = await response.json();
  } catch {
    throw new HttpError(502, "invalid_backend_response", "Flight closure returned an invalid response.");
  }
  if (!isFlightCloseResponse(value) || value.dispatchId !== request.dispatchId) {
    throw new HttpError(502, "invalid_backend_response", "Flight closure returned an invalid response.");
  }
  return {
    aircraftId: value.aircraftId,
    blockMinutes: value.blockMinutes,
    closedAt: value.closedAt,
    currencyCode: value.currencyCode,
    dispatchId: value.dispatchId,
    distanceNm: value.distanceNm,
    outcome: value.outcome,
    schemaVersion: 1,
    settledAmountMinor: value.settledAmountMinor,
    state: value.state,
  };
}

export function createFlightCloseHandler(
  environment: FlightCloseEnvironment,
  fetchImplementation: Fetch = fetch,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return jsonResponse(405, { error: { code: "method_not_allowed", message: "Use POST." } }, { allow: "POST" });
    }

    try {
      const bearerToken = requireBearerToken(request);
      const rawBody = await readBoundedBody(request);
      const flightCloseRequest = parseRequestBody(rawBody);
      const configuration = readRuntimeConfiguration(environment);
      const user = await authenticateUser(fetchImplementation, configuration, bearerToken);
      const result = await closeFlight(fetchImplementation, configuration, user, flightCloseRequest);
      return jsonResponse(200, result);
    } catch (error) {
      if (error instanceof HttpError) {
        return jsonResponse(error.status, { error: { code: error.code, message: error.message } });
      }
      return jsonResponse(500, { error: { code: "internal_error", message: "Flight closure failed." } });
    }
  };
}
