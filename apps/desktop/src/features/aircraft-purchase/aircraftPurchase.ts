const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const RESPONSE_LIMIT_BYTES = 16_384;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;

export type AircraftPurchaseFailure =
  | "authentication-required"
  | "invalid-response"
  | "rejected"
  | "unavailable";

export interface AircraftPurchaseResult {
  aircraftId: string;
  ledgerEntryId: string;
  offerId: string;
  schemaVersion: 1;
  state: "owned";
}

export interface PurchaseAircraftInput {
  accessToken: string;
  anonKey: string;
  idempotencyKey: string;
  offerId: string;
  signal?: AbortSignal;
  supabaseUrl: string;
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class AircraftPurchaseError extends Error {
  readonly failure: AircraftPurchaseFailure;

  constructor(failure: AircraftPurchaseFailure) {
    super(failure);
    this.name = "AircraftPurchaseError";
    this.failure = failure;
  }
}

function requireCanonicalUuid(value: string): void {
  if (!UUID_PATTERN.test(value)) {
    throw new AircraftPurchaseError("rejected");
  }
}

function requireHeaderValue(value: string): void {
  if (value.length === 0 || /[\r\n\s]/.test(value)) {
    throw new AircraftPurchaseError("authentication-required");
  }
}

function createEndpoint(rawBaseUrl: string): URL {
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    throw new AircraftPurchaseError("unavailable");
  }

  const isLoopback = ["127.0.0.1", "::1", "[::1]", "localhost"].includes(baseUrl.hostname);
  const secureProtocol = baseUrl.protocol === "https:";
  if (
    (!secureProtocol && !(isLoopback && baseUrl.protocol === "http:")) ||
    baseUrl.username.length > 0 ||
    baseUrl.password.length > 0 ||
    baseUrl.search.length > 0 ||
    baseUrl.hash.length > 0 ||
    (baseUrl.pathname !== "/" && baseUrl.pathname !== "")
  ) {
    throw new AircraftPurchaseError("unavailable");
  }

  return new URL("/functions/v1/aircraft-purchase", baseUrl);
}

function isPurchaseResult(value: unknown, expectedOfferId: string): value is AircraftPurchaseResult {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }

  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).sort().join(",") !==
    "aircraftId,ledgerEntryId,offerId,schemaVersion,state"
  ) {
    return false;
  }

  return (
    record.schemaVersion === 1 &&
    record.state === "owned" &&
    record.offerId === expectedOfferId &&
    typeof record.aircraftId === "string" &&
    UUID_PATTERN.test(record.aircraftId) &&
    typeof record.ledgerEntryId === "string" &&
    UUID_PATTERN.test(record.ledgerEntryId)
  );
}

async function parseSuccessfulResponse(
  response: Response,
  expectedOfferId: string,
): Promise<AircraftPurchaseResult> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const byteLength = Number(declaredLength);
    if (!Number.isSafeInteger(byteLength) || byteLength < 0 || byteLength > RESPONSE_LIMIT_BYTES) {
      throw new AircraftPurchaseError("invalid-response");
    }
  }

  const rawBody = await response.text();
  if (new TextEncoder().encode(rawBody).byteLength > RESPONSE_LIMIT_BYTES) {
    throw new AircraftPurchaseError("invalid-response");
  }

  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    throw new AircraftPurchaseError("invalid-response");
  }
  if (!isPurchaseResult(value, expectedOfferId)) {
    throw new AircraftPurchaseError("invalid-response");
  }
  return value;
}

function classifyStatus(status: number): AircraftPurchaseError {
  if (status === 401 || status === 403) {
    return new AircraftPurchaseError("authentication-required");
  }
  if (status === 400 || status === 409 || status === 422) {
    return new AircraftPurchaseError("rejected");
  }
  return new AircraftPurchaseError("unavailable");
}

export async function purchaseAircraft(
  input: PurchaseAircraftInput,
  fetchImplementation: Fetch = fetch,
): Promise<AircraftPurchaseResult> {
  requireCanonicalUuid(input.offerId);
  requireCanonicalUuid(input.idempotencyKey);
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
        offerId: input.offerId,
        idempotencyKey: input.idempotencyKey,
      }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
      signal,
    });
  } catch {
    throw new AircraftPurchaseError("unavailable");
  }

  if (!response.ok) {
    throw classifyStatus(response.status);
  }
  return parseSuccessfulResponse(response, input.offerId);
}
