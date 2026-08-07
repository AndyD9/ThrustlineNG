const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const TIMESTAMP_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/;
const CURRENCY_PATTERN = /^[A-Z]{3}$/;
const RESPONSE_LIMIT_BYTES = 16_384;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;
const HEADER_LIMIT_BYTES = 8_192;
const MAXIMUM_BLOCK_MINUTES = 1_440;
const MAXIMUM_DISTANCE_NM = 20_000;

export type FlightCloseFailure =
  | "authentication-required"
  | "invalid-response"
  | "rejected"
  | "unavailable";

export interface ClosedFlight {
  aircraftId: string;
  blockMinutes: number;
  closedAt: string;
  currencyCode: string;
  dispatchId: string;
  distanceNm: number;
  outcome: "completed";
  schemaVersion: 1;
  settledAmountMinor: number;
  state: "completed";
}

export interface CloseFlightInput {
  accessToken: string;
  anonKey: string;
  blockMinutes: number;
  dispatchId: string;
  idempotencyKey: string;
  signal?: AbortSignal;
  supabaseUrl: string;
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class FlightCloseError extends Error {
  readonly failure: FlightCloseFailure;

  constructor(failure: FlightCloseFailure) {
    super(failure);
    this.name = "FlightCloseError";
    this.failure = failure;
  }
}

function requireHeaderValue(value: string): void {
  if (
    value.length === 0 ||
    new TextEncoder().encode(value).byteLength > HEADER_LIMIT_BYTES ||
    /[\r\n\s]/.test(value)
  ) {
    throw new FlightCloseError("authentication-required");
  }
}

function createEndpoint(rawBaseUrl: string): URL {
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    throw new FlightCloseError("unavailable");
  }

  const isLoopback = ["127.0.0.1", "::1", "[::1]", "localhost"].includes(baseUrl.hostname);
  if (
    !(isLoopback && baseUrl.protocol === "http:") ||
    baseUrl.username.length > 0 ||
    baseUrl.password.length > 0 ||
    baseUrl.search.length > 0 ||
    baseUrl.hash.length > 0 ||
    (baseUrl.pathname !== "/" && baseUrl.pathname !== "")
  ) {
    throw new FlightCloseError("unavailable");
  }

  return new URL("/functions/v1/flight-close", baseUrl);
}

function isClosedFlight(value: unknown, requestedDispatchId: string): value is ClosedFlight {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }

  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).sort().join(",") !==
    "aircraftId,blockMinutes,closedAt,currencyCode,dispatchId,distanceNm,outcome,schemaVersion,settledAmountMinor,state"
  ) {
    return false;
  }

  return (
    record.schemaVersion === 1 &&
    record.state === "completed" &&
    record.outcome === "completed" &&
    record.dispatchId === requestedDispatchId &&
    typeof record.aircraftId === "string" &&
    UUID_PATTERN.test(record.aircraftId) &&
    typeof record.closedAt === "string" &&
    TIMESTAMP_PATTERN.test(record.closedAt) &&
    Number.isFinite(Date.parse(record.closedAt)) &&
    typeof record.blockMinutes === "number" &&
    Number.isInteger(record.blockMinutes) &&
    record.blockMinutes >= 0 &&
    record.blockMinutes <= MAXIMUM_BLOCK_MINUTES &&
    typeof record.distanceNm === "number" &&
    Number.isFinite(record.distanceNm) &&
    record.distanceNm >= 0 &&
    record.distanceNm <= MAXIMUM_DISTANCE_NM &&
    typeof record.settledAmountMinor === "number" &&
    Number.isSafeInteger(record.settledAmountMinor) &&
    record.settledAmountMinor > 0 &&
    typeof record.currencyCode === "string" &&
    CURRENCY_PATTERN.test(record.currencyCode)
  );
}

async function parseSuccessfulResponse(
  response: Response,
  requestedDispatchId: string,
): Promise<ClosedFlight> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const byteLength = Number(declaredLength);
    if (!Number.isSafeInteger(byteLength) || byteLength < 0 || byteLength > RESPONSE_LIMIT_BYTES) {
      throw new FlightCloseError("invalid-response");
    }
  }

  const rawBody = await response.text();
  if (new TextEncoder().encode(rawBody).byteLength > RESPONSE_LIMIT_BYTES) {
    throw new FlightCloseError("invalid-response");
  }

  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    throw new FlightCloseError("invalid-response");
  }
  if (!isClosedFlight(value, requestedDispatchId)) {
    throw new FlightCloseError("invalid-response");
  }
  return value;
}

function classifyStatus(status: number): FlightCloseError {
  if (status === 401 || status === 403) {
    return new FlightCloseError("authentication-required");
  }
  if (status === 400 || status === 409 || status === 422) {
    return new FlightCloseError("rejected");
  }
  return new FlightCloseError("unavailable");
}

export async function closeFlight(
  input: CloseFlightInput,
  fetchImplementation: Fetch = fetch,
): Promise<ClosedFlight> {
  if (!UUID_PATTERN.test(input.dispatchId) || !UUID_PATTERN.test(input.idempotencyKey)) {
    throw new FlightCloseError("rejected");
  }
  if (
    !Number.isInteger(input.blockMinutes) ||
    input.blockMinutes < 1 ||
    input.blockMinutes > MAXIMUM_BLOCK_MINUTES
  ) {
    throw new FlightCloseError("rejected");
  }
  requireHeaderValue(input.accessToken);
  requireHeaderValue(input.anonKey);

  const endpoint = createEndpoint(input.supabaseUrl);
  const timeoutSignal = AbortSignal.timeout(REQUEST_TIMEOUT_MILLISECONDS);
  const signal = input.signal === undefined
    ? timeoutSignal
    : AbortSignal.any([input.signal, timeoutSignal]);

  let response: Response;
  try {
    response = await fetchImplementation(endpoint, {
      method: "POST",
      headers: {
        accept: "application/json",
        apikey: input.anonKey,
        authorization: `Bearer ${input.accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        dispatchId: input.dispatchId,
        idempotencyKey: input.idempotencyKey,
        report: { blockMinutes: input.blockMinutes, outcome: "completed" },
      }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
      signal,
    });
  } catch {
    throw new FlightCloseError("unavailable");
  }

  if (!response.ok) {
    throw classifyStatus(response.status);
  }
  return parseSuccessfulResponse(response, input.dispatchId);
}
