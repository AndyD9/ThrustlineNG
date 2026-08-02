const AIRCRAFT_TYPE_PATTERN = /^[A-Z0-9][A-Z0-9_-]{1,31}$/;
const SERIAL_NUMBER_PATTERN = /^[A-Z0-9][A-Z0-9-]{2,31}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const RESPONSE_LIMIT_BYTES = 32_768;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;
const OFFER_LIMIT = 20;
const HEADER_LIMIT_BYTES = 8_192;

export type AircraftCatalogFailure =
  | "authentication-required"
  | "invalid-response"
  | "unavailable";

export interface AircraftCatalogOffer {
  aircraftTypeCode: string;
  currencyCode: "EUR";
  displayName: string;
  id: string;
  priceMinor: number;
  schemaVersion: 1;
  serialNumber: string;
}

export interface LoadAircraftCatalogInput {
  accessToken: string;
  anonKey: string;
  signal?: AbortSignal;
  supabaseUrl: string;
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class AircraftCatalogError extends Error {
  readonly failure: AircraftCatalogFailure;

  constructor(failure: AircraftCatalogFailure) {
    super(failure);
    this.name = "AircraftCatalogError";
    this.failure = failure;
  }
}

function requireHeaderValue(value: string): void {
  if (
    value.length === 0 ||
    new TextEncoder().encode(value).byteLength > HEADER_LIMIT_BYTES ||
    /[\r\n\s]/.test(value)
  ) {
    throw new AircraftCatalogError("authentication-required");
  }
}

function createEndpoint(rawBaseUrl: string): URL {
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    throw new AircraftCatalogError("unavailable");
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
    throw new AircraftCatalogError("unavailable");
  }

  const endpoint = new URL("/rest/v1/aircraft_purchase_offers", baseUrl);
  endpoint.searchParams.set(
    "select",
    "id,aircraft_type_code,serial_number,display_name,price_minor,currency_code,schema_version",
  );
  endpoint.searchParams.set("status", "eq.available");
  endpoint.searchParams.set("order", "created_at.asc,id.asc");
  endpoint.searchParams.set("limit", String(OFFER_LIMIT));
  return endpoint;
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const length = Number(declaredLength);
    if (!Number.isSafeInteger(length) || length < 0 || length > RESPONSE_LIMIT_BYTES) {
      throw new AircraftCatalogError("invalid-response");
    }
  }
  if (response.body === null) {
    throw new AircraftCatalogError("invalid-response");
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let byteLength = 0;
  let body = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        body += decoder.decode();
        break;
      }
      byteLength += value.byteLength;
      if (byteLength > RESPONSE_LIMIT_BYTES) {
        await reader.cancel();
        throw new AircraftCatalogError("invalid-response");
      }
      body += decoder.decode(value, { stream: true });
    }
  } finally {
    reader.releaseLock();
  }

  try {
    return JSON.parse(body);
  } catch {
    throw new AircraftCatalogError("invalid-response");
  }
}

function parseOffer(value: unknown): AircraftCatalogOffer {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new AircraftCatalogError("invalid-response");
  }
  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).sort().join(",") !==
      "aircraft_type_code,currency_code,display_name,id,price_minor,schema_version,serial_number" ||
    typeof record.id !== "string" ||
    !UUID_PATTERN.test(record.id) ||
    typeof record.aircraft_type_code !== "string" ||
    !AIRCRAFT_TYPE_PATTERN.test(record.aircraft_type_code) ||
    typeof record.serial_number !== "string" ||
    !SERIAL_NUMBER_PATTERN.test(record.serial_number) ||
    typeof record.display_name !== "string" ||
    record.display_name.trim() !== record.display_name ||
    Array.from(record.display_name).length < 2 ||
    Array.from(record.display_name).length > 80 ||
    !Number.isSafeInteger(record.price_minor) ||
    (record.price_minor as number) < 1 ||
    (record.price_minor as number) > 1_000_000_000_000_000 ||
    record.currency_code !== "EUR" ||
    record.schema_version !== 1
  ) {
    throw new AircraftCatalogError("invalid-response");
  }

  return {
    aircraftTypeCode: record.aircraft_type_code,
    currencyCode: "EUR",
    displayName: record.display_name,
    id: record.id,
    priceMinor: record.price_minor as number,
    schemaVersion: 1,
    serialNumber: record.serial_number,
  };
}

function parseCatalog(value: unknown): AircraftCatalogOffer[] {
  if (!Array.isArray(value) || value.length > OFFER_LIMIT) {
    throw new AircraftCatalogError("invalid-response");
  }
  return value.map(parseOffer);
}

export async function loadAircraftCatalog(
  input: LoadAircraftCatalogInput,
  fetchImplementation: Fetch = fetch,
): Promise<AircraftCatalogOffer[]> {
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
      method: "GET",
      headers: {
        accept: "application/json",
        apikey: input.anonKey,
        authorization: `Bearer ${input.accessToken}`,
      },
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
      signal,
    });
  } catch {
    throw new AircraftCatalogError("unavailable");
  }

  if (response.status === 401 || response.status === 403) {
    throw new AircraftCatalogError("authentication-required");
  }
  if (!response.ok) {
    throw new AircraftCatalogError("unavailable");
  }
  return parseCatalog(await readBoundedJson(response));
}
