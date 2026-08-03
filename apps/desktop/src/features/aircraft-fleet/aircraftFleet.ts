const AIRCRAFT_TYPE_PATTERN = /^[A-Z0-9][A-Z0-9_-]{1,31}$/;
const SERIAL_NUMBER_PATTERN = /^[A-Z0-9][A-Z0-9-]{2,31}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const RESPONSE_LIMIT_BYTES = 65_536;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;
const AIRCRAFT_LIMIT = 50;
const HEADER_LIMIT_BYTES = 8_192;

export type AircraftFleetFailure =
  | "authentication-required"
  | "invalid-response"
  | "unavailable";

export interface CompanyAircraft {
  acquiredAt: string;
  acquisitionKind: "purchase";
  aircraftTypeCode: string;
  displayName: string;
  id: string;
  schemaVersion: 1;
  serialNumber: string;
}

export interface LoadAircraftFleetInput {
  accessToken: string;
  anonKey: string;
  signal?: AbortSignal;
  supabaseUrl: string;
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class AircraftFleetError extends Error {
  readonly failure: AircraftFleetFailure;

  constructor(failure: AircraftFleetFailure) {
    super(failure);
    this.name = "AircraftFleetError";
    this.failure = failure;
  }
}

function requireHeaderValue(value: string): void {
  if (
    value.length === 0 ||
    new TextEncoder().encode(value).byteLength > HEADER_LIMIT_BYTES ||
    /[\r\n\s]/.test(value)
  ) {
    throw new AircraftFleetError("authentication-required");
  }
}

function createEndpoint(rawBaseUrl: string): URL {
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    throw new AircraftFleetError("unavailable");
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
    throw new AircraftFleetError("unavailable");
  }

  const endpoint = new URL("/rest/v1/company_aircraft", baseUrl);
  endpoint.searchParams.set(
    "select",
    "id,aircraft_type_code,serial_number,display_name,acquisition_kind,acquired_at,schema_version",
  );
  endpoint.searchParams.set("order", "acquired_at.asc,id.asc");
  endpoint.searchParams.set("limit", String(AIRCRAFT_LIMIT));
  return endpoint;
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const length = Number(declaredLength);
    if (!Number.isSafeInteger(length) || length < 0 || length > RESPONSE_LIMIT_BYTES) {
      throw new AircraftFleetError("invalid-response");
    }
  }
  if (response.body === null) {
    throw new AircraftFleetError("invalid-response");
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
        throw new AircraftFleetError("invalid-response");
      }
      body += decoder.decode(value, { stream: true });
    }
  } finally {
    reader.releaseLock();
  }

  try {
    return JSON.parse(body);
  } catch {
    throw new AircraftFleetError("invalid-response");
  }
}

function isCanonicalTimestamp(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/.exec(value);
  if (match === null) {
    return false;
  }
  const [, yearText, monthText, dayText, hourText, minuteText, secondText] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const daysInMonth = month >= 1 && month <= 12
    ? new Date(Date.UTC(year, month, 0)).getUTCDate()
    : 0;
  return day >= 1 && day <= daysInMonth &&
    Number(hourText) <= 23 && Number(minuteText) <= 59 && Number(secondText) <= 59 &&
    Number.isFinite(Date.parse(value));
}

function parseAircraft(value: unknown): CompanyAircraft {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new AircraftFleetError("invalid-response");
  }
  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).sort().join(",") !==
      "acquired_at,acquisition_kind,aircraft_type_code,display_name,id,schema_version,serial_number" ||
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
    record.acquisition_kind !== "purchase" ||
    typeof record.acquired_at !== "string" ||
    !isCanonicalTimestamp(record.acquired_at) ||
    record.schema_version !== 1
  ) {
    throw new AircraftFleetError("invalid-response");
  }

  return {
    acquiredAt: record.acquired_at,
    acquisitionKind: "purchase",
    aircraftTypeCode: record.aircraft_type_code,
    displayName: record.display_name,
    id: record.id,
    schemaVersion: 1,
    serialNumber: record.serial_number,
  };
}

function parseFleet(value: unknown): CompanyAircraft[] {
  if (!Array.isArray(value) || value.length > AIRCRAFT_LIMIT) {
    throw new AircraftFleetError("invalid-response");
  }
  const aircraft = value.map(parseAircraft);
  if (
    new Set(aircraft.map((item) => item.id)).size !== aircraft.length ||
    new Set(aircraft.map((item) => item.serialNumber)).size !== aircraft.length
  ) {
    throw new AircraftFleetError("invalid-response");
  }
  return aircraft;
}

export async function loadAircraftFleet(
  input: LoadAircraftFleetInput,
  fetchImplementation: Fetch = fetch,
): Promise<CompanyAircraft[]> {
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
      cache: "no-store",
      credentials: "omit",
      headers: {
        accept: "application/json",
        apikey: input.anonKey,
        authorization: `Bearer ${input.accessToken}`,
      },
      method: "GET",
      referrerPolicy: "no-referrer",
      signal,
    });
  } catch {
    throw new AircraftFleetError("unavailable");
  }

  if (response.status === 401 || response.status === 403) {
    throw new AircraftFleetError("authentication-required");
  }
  if (!response.ok) {
    throw new AircraftFleetError("unavailable");
  }
  return parseFleet(await readBoundedJson(response));
}
