const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const TIMESTAMP_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/;
const RESPONSE_LIMIT_BYTES = 16_384;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;
const HEADER_LIMIT_BYTES = 8_192;

export type FlightStartFailure =
  | "authentication-required"
  | "invalid-response"
  | "rejected"
  | "unavailable";

export interface StartedFlight {
  aircraftId: string;
  dispatchId: string;
  schemaVersion: 1;
  startedAt: string;
  state: "active";
}

export interface StartFlightInput {
  accessToken: string;
  anonKey: string;
  dispatchId: string;
  idempotencyKey: string;
  signal?: AbortSignal;
  supabaseUrl: string;
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class FlightStartError extends Error {
  readonly failure: FlightStartFailure;

  constructor(failure: FlightStartFailure) {
    super(failure);
    this.name = "FlightStartError";
    this.failure = failure;
  }
}

function requireHeaderValue(value: string): void {
  if (
    value.length === 0 ||
    new TextEncoder().encode(value).byteLength > HEADER_LIMIT_BYTES ||
    /[\r\n\s]/.test(value)
  ) {
    throw new FlightStartError("authentication-required");
  }
}

function createEndpoint(rawBaseUrl: string): URL {
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    throw new FlightStartError("unavailable");
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
    throw new FlightStartError("unavailable");
  }

  return new URL("/functions/v1/flight-start", baseUrl);
}

function isStartedFlight(value: unknown, requestedDispatchId: string): value is StartedFlight {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }

  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).sort().join(",") !==
    "aircraftId,dispatchId,schemaVersion,startedAt,state"
  ) {
    return false;
  }

  return (
    record.schemaVersion === 1 &&
    record.state === "active" &&
    record.dispatchId === requestedDispatchId &&
    typeof record.aircraftId === "string" &&
    UUID_PATTERN.test(record.aircraftId) &&
    typeof record.startedAt === "string" &&
    TIMESTAMP_PATTERN.test(record.startedAt) &&
    Number.isFinite(Date.parse(record.startedAt))
  );
}

async function parseSuccessfulResponse(
  response: Response,
  requestedDispatchId: string,
): Promise<StartedFlight> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const byteLength = Number(declaredLength);
    if (!Number.isSafeInteger(byteLength) || byteLength < 0 || byteLength > RESPONSE_LIMIT_BYTES) {
      throw new FlightStartError("invalid-response");
    }
  }

  const rawBody = await response.text();
  if (new TextEncoder().encode(rawBody).byteLength > RESPONSE_LIMIT_BYTES) {
    throw new FlightStartError("invalid-response");
  }

  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    throw new FlightStartError("invalid-response");
  }
  if (!isStartedFlight(value, requestedDispatchId)) {
    throw new FlightStartError("invalid-response");
  }
  return value;
}

function classifyStatus(status: number): FlightStartError {
  if (status === 401 || status === 403) {
    return new FlightStartError("authentication-required");
  }
  if (status === 400 || status === 409 || status === 422) {
    return new FlightStartError("rejected");
  }
  return new FlightStartError("unavailable");
}

export async function startFlight(
  input: StartFlightInput,
  fetchImplementation: Fetch = fetch,
): Promise<StartedFlight> {
  if (!UUID_PATTERN.test(input.dispatchId) || !UUID_PATTERN.test(input.idempotencyKey)) {
    throw new FlightStartError("rejected");
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
      }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
      signal,
    });
  } catch {
    throw new FlightStartError("unavailable");
  }

  if (!response.ok) {
    throw classifyStatus(response.status);
  }
  return parseSuccessfulResponse(response, input.dispatchId);
}
