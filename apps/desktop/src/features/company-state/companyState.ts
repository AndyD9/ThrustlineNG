const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const RESPONSE_LIMIT_BYTES = 8_192;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;
const COMPANY_LIMIT = 2;
const HEADER_LIMIT_BYTES = 8_192;

export type CompanyPresenceFailure =
  | "authentication-required"
  | "invalid-response"
  | "unavailable";

export interface LoadCompanyPresenceInput {
  accessToken: string;
  anonKey: string;
  signal?: AbortSignal;
  supabaseUrl: string;
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class CompanyPresenceError extends Error {
  readonly failure: CompanyPresenceFailure;

  constructor(failure: CompanyPresenceFailure) {
    super(failure);
    this.name = "CompanyPresenceError";
    this.failure = failure;
  }
}

function requireHeaderValue(value: string): void {
  if (
    value.length === 0 ||
    new TextEncoder().encode(value).byteLength > HEADER_LIMIT_BYTES ||
    /[\r\n\s]/.test(value)
  ) {
    throw new CompanyPresenceError("authentication-required");
  }
}

function createEndpoint(rawBaseUrl: string): URL {
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    throw new CompanyPresenceError("unavailable");
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
    throw new CompanyPresenceError("unavailable");
  }

  const endpoint = new URL("/rest/v1/companies", baseUrl);
  endpoint.searchParams.set("select", "id");
  endpoint.searchParams.set("limit", String(COMPANY_LIMIT));
  return endpoint;
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const length = Number(declaredLength);
    if (!Number.isSafeInteger(length) || length < 0 || length > RESPONSE_LIMIT_BYTES) {
      throw new CompanyPresenceError("invalid-response");
    }
  }
  if (response.body === null) {
    throw new CompanyPresenceError("invalid-response");
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
        throw new CompanyPresenceError("invalid-response");
      }
      body += decoder.decode(value, { stream: true });
    }
  } finally {
    reader.releaseLock();
  }

  try {
    return JSON.parse(body);
  } catch {
    throw new CompanyPresenceError("invalid-response");
  }
}

function parseCompanyPresence(value: unknown): boolean {
  if (!Array.isArray(value) || value.length > 1) {
    throw new CompanyPresenceError("invalid-response");
  }
  for (const company of value) {
    if (
      company === null ||
      typeof company !== "object" ||
      Array.isArray(company) ||
      Object.keys(company).join(",") !== "id" ||
      typeof (company as Record<string, unknown>).id !== "string" ||
      !UUID_PATTERN.test((company as Record<string, unknown>).id as string)
    ) {
      throw new CompanyPresenceError("invalid-response");
    }
  }
  return value.length === 1;
}

export async function loadCompanyPresence(
  input: LoadCompanyPresenceInput,
  fetchImplementation: Fetch = fetch,
): Promise<boolean> {
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
    throw new CompanyPresenceError("unavailable");
  }

  if (response.status === 401 || response.status === 403) {
    throw new CompanyPresenceError("authentication-required");
  }
  if (!response.ok) {
    throw new CompanyPresenceError("unavailable");
  }
  return parseCompanyPresence(await readBoundedJson(response));
}
