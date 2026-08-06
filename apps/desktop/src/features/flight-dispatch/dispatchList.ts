const ICAO_PATTERN = /^[A-Z0-9]{4}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const RESPONSE_LIMIT_BYTES = 65_536;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;
const DISPATCH_LIMIT = 50;
const HEADER_LIMIT_BYTES = 8_192;

const DISPATCH_SELECT =
  "id,aircraft_id,departure_icao,arrival_icao,state,created_at,started_at,schema_version";
const DISPATCH_ORDER = "created_at.desc,id.desc";
const DISPATCH_KEYS =
  "aircraft_id,arrival_icao,created_at,departure_icao,id,schema_version,started_at,state";

export const DISPATCH_STATES = ["active", "draft"] as const;

export type DispatchState = (typeof DISPATCH_STATES)[number];

export type DispatchListFailure =
  | "authentication-required"
  | "invalid-response"
  | "unavailable";

export interface CompanyDispatch {
  aircraftId: string;
  arrivalIcao: string;
  createdAt: string;
  departureIcao: string;
  id: string;
  schemaVersion: 1;
  startedAt: string | null;
  state: DispatchState;
}

export interface LoadDispatchListInput {
  accessToken: string;
  anonKey: string;
  signal?: AbortSignal;
  supabaseUrl: string;
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class DispatchListError extends Error {
  readonly failure: DispatchListFailure;

  constructor(failure: DispatchListFailure) {
    super(failure);
    this.name = "DispatchListError";
    this.failure = failure;
  }
}

function requireHeaderValue(value: string): void {
  if (
    value.length === 0 ||
    new TextEncoder().encode(value).byteLength > HEADER_LIMIT_BYTES ||
    /[\r\n\s]/.test(value)
  ) {
    throw new DispatchListError("authentication-required");
  }
}

function createEndpoint(rawBaseUrl: string): URL {
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    throw new DispatchListError("unavailable");
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
    throw new DispatchListError("unavailable");
  }

  const endpoint = new URL("/rest/v1/flight_dispatches", baseUrl);
  endpoint.searchParams.set("select", DISPATCH_SELECT);
  endpoint.searchParams.set("order", DISPATCH_ORDER);
  endpoint.searchParams.set("limit", String(DISPATCH_LIMIT));
  return endpoint;
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const length = Number(declaredLength);
    if (!Number.isSafeInteger(length) || length < 0 || length > RESPONSE_LIMIT_BYTES) {
      throw new DispatchListError("invalid-response");
    }
  }
  if (response.body === null) {
    throw new DispatchListError("invalid-response");
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
        throw new DispatchListError("invalid-response");
      }
      body += decoder.decode(value, { stream: true });
    }
  } finally {
    reader.releaseLock();
  }

  try {
    return JSON.parse(body);
  } catch {
    throw new DispatchListError("invalid-response");
  }
}

function isCanonicalTimestamp(value: string): boolean {
  const match =
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/.exec(
      value,
    );
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

function isDispatchState(value: unknown): value is DispatchState {
  return typeof value === "string" && (DISPATCH_STATES as readonly string[]).includes(value);
}

function parseDispatch(value: unknown): CompanyDispatch {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new DispatchListError("invalid-response");
  }
  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).sort().join(",") !== DISPATCH_KEYS ||
    typeof record.id !== "string" ||
    !UUID_PATTERN.test(record.id) ||
    typeof record.aircraft_id !== "string" ||
    !UUID_PATTERN.test(record.aircraft_id) ||
    typeof record.departure_icao !== "string" ||
    !ICAO_PATTERN.test(record.departure_icao) ||
    typeof record.arrival_icao !== "string" ||
    !ICAO_PATTERN.test(record.arrival_icao) ||
    record.departure_icao === record.arrival_icao ||
    !isDispatchState(record.state) ||
    typeof record.created_at !== "string" ||
    !isCanonicalTimestamp(record.created_at) ||
    record.schema_version !== 1 ||
    (record.state === "active"
      ? typeof record.started_at !== "string" || !isCanonicalTimestamp(record.started_at)
      : record.started_at !== null)
  ) {
    throw new DispatchListError("invalid-response");
  }

  return {
    aircraftId: record.aircraft_id,
    arrivalIcao: record.arrival_icao,
    createdAt: record.created_at,
    departureIcao: record.departure_icao,
    id: record.id,
    schemaVersion: 1,
    startedAt: record.state === "active" ? (record.started_at as string) : null,
    state: record.state,
  };
}

function parseDispatchList(value: unknown): CompanyDispatch[] {
  if (!Array.isArray(value) || value.length > DISPATCH_LIMIT) {
    throw new DispatchListError("invalid-response");
  }
  const dispatches = value.map(parseDispatch);
  if (
    new Set(dispatches.map((item) => item.id)).size !== dispatches.length ||
    new Set(dispatches.map((item) => item.aircraftId)).size !== dispatches.length
  ) {
    throw new DispatchListError("invalid-response");
  }
  return dispatches;
}

export async function loadDispatchList(
  input: LoadDispatchListInput,
  fetchImplementation: Fetch = fetch,
): Promise<CompanyDispatch[]> {
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
    throw new DispatchListError("unavailable");
  }

  if (response.status === 401 || response.status === 403) {
    throw new DispatchListError("authentication-required");
  }
  if (!response.ok) {
    throw new DispatchListError("unavailable");
  }
  return parseDispatchList(await readBoundedJson(response));
}
