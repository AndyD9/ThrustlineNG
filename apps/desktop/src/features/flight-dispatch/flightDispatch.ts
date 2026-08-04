const ICAO_PATTERN = /^[A-Z0-9]{4}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const TIMESTAMP_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/;
const RESPONSE_LIMIT_BYTES = 16_384;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;
const HEADER_LIMIT_BYTES = 8_192;

export type DispatchDraftFailure =
  | "authentication-required"
  | "invalid-response"
  | "rejected"
  | "unavailable";

export interface DispatchDraft {
  aircraftId: string;
  arrivalIcao: string;
  createdAt: string;
  departureIcao: string;
  dispatchId: string;
  schemaVersion: 1;
  state: "draft";
}

export interface DispatchIntention {
  aircraftId: string;
  arrivalIcao: string;
  departureIcao: string;
}

export interface CreateDispatchDraftInput extends DispatchIntention {
  accessToken: string;
  anonKey: string;
  idempotencyKey: string;
  signal?: AbortSignal;
  supabaseUrl: string;
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class DispatchDraftError extends Error {
  readonly failure: DispatchDraftFailure;

  constructor(failure: DispatchDraftFailure) {
    super(failure);
    this.name = "DispatchDraftError";
    this.failure = failure;
  }
}

export function normalizeDispatchIntention(intention: DispatchIntention): DispatchIntention {
  const aircraftId = intention.aircraftId.trim();
  const departureIcao = intention.departureIcao.trim().toUpperCase();
  const arrivalIcao = intention.arrivalIcao.trim().toUpperCase();
  if (
    !UUID_PATTERN.test(aircraftId) ||
    !ICAO_PATTERN.test(departureIcao) ||
    !ICAO_PATTERN.test(arrivalIcao) ||
    departureIcao === arrivalIcao
  ) {
    throw new DispatchDraftError("rejected");
  }
  return { aircraftId, arrivalIcao, departureIcao };
}

function requireHeaderValue(value: string): void {
  if (
    value.length === 0 ||
    new TextEncoder().encode(value).byteLength > HEADER_LIMIT_BYTES ||
    /[\r\n\s]/.test(value)
  ) {
    throw new DispatchDraftError("authentication-required");
  }
}

function createEndpoint(rawBaseUrl: string): URL {
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    throw new DispatchDraftError("unavailable");
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
    throw new DispatchDraftError("unavailable");
  }

  return new URL("/functions/v1/dispatch-draft", baseUrl);
}

function isDispatchDraft(value: unknown, intention: DispatchIntention): value is DispatchDraft {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }

  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).sort().join(",") !==
    "aircraftId,arrivalIcao,createdAt,departureIcao,dispatchId,schemaVersion,state"
  ) {
    return false;
  }

  return (
    record.schemaVersion === 1 &&
    record.state === "draft" &&
    record.aircraftId === intention.aircraftId &&
    record.departureIcao === intention.departureIcao &&
    record.arrivalIcao === intention.arrivalIcao &&
    typeof record.dispatchId === "string" &&
    UUID_PATTERN.test(record.dispatchId) &&
    typeof record.createdAt === "string" &&
    TIMESTAMP_PATTERN.test(record.createdAt) &&
    Number.isFinite(Date.parse(record.createdAt))
  );
}

async function parseSuccessfulResponse(
  response: Response,
  intention: DispatchIntention,
): Promise<DispatchDraft> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const byteLength = Number(declaredLength);
    if (!Number.isSafeInteger(byteLength) || byteLength < 0 || byteLength > RESPONSE_LIMIT_BYTES) {
      throw new DispatchDraftError("invalid-response");
    }
  }

  const rawBody = await response.text();
  if (new TextEncoder().encode(rawBody).byteLength > RESPONSE_LIMIT_BYTES) {
    throw new DispatchDraftError("invalid-response");
  }

  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    throw new DispatchDraftError("invalid-response");
  }
  if (!isDispatchDraft(value, intention)) {
    throw new DispatchDraftError("invalid-response");
  }
  return value;
}

function classifyStatus(status: number): DispatchDraftError {
  if (status === 401 || status === 403) {
    return new DispatchDraftError("authentication-required");
  }
  if (status === 400 || status === 409 || status === 422) {
    return new DispatchDraftError("rejected");
  }
  return new DispatchDraftError("unavailable");
}

export async function createDispatchDraft(
  input: CreateDispatchDraftInput,
  fetchImplementation: Fetch = fetch,
): Promise<DispatchDraft> {
  const intention = normalizeDispatchIntention(input);
  if (!UUID_PATTERN.test(input.idempotencyKey)) {
    throw new DispatchDraftError("rejected");
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
        aircraftId: intention.aircraftId,
        departureIcao: intention.departureIcao,
        arrivalIcao: intention.arrivalIcao,
        idempotencyKey: input.idempotencyKey,
      }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
      signal,
    });
  } catch {
    throw new DispatchDraftError("unavailable");
  }

  if (!response.ok) {
    throw classifyStatus(response.status);
  }
  return parseSuccessfulResponse(response, intention);
}
