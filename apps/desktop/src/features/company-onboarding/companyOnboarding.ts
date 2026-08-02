const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const RESPONSE_LIMIT_BYTES = 16_384;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;

export type CompanyOnboardingFailure =
  | "authentication-required"
  | "invalid-response"
  | "rejected"
  | "unavailable";

export interface CompanyOnboardingResult {
  companyId: string;
  openingEntryId: string;
  schemaVersion: 1;
  state: "active";
}

export interface OnboardCompanyInput {
  accessToken: string;
  anonKey: string;
  companyName: string;
  idempotencyKey: string;
  signal?: AbortSignal;
  supabaseUrl: string;
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class CompanyOnboardingError extends Error {
  readonly failure: CompanyOnboardingFailure;

  constructor(failure: CompanyOnboardingFailure) {
    super(failure);
    this.name = "CompanyOnboardingError";
    this.failure = failure;
  }
}

export function normalizeCompanyName(value: string): string {
  const normalized = value.trim().normalize("NFC");
  const length = Array.from(normalized).length;
  if (length < 2 || length > 80) {
    throw new CompanyOnboardingError("rejected");
  }
  return normalized;
}

function requireNormalizedCompanyName(value: string): void {
  if (normalizeCompanyName(value) !== value) {
    throw new CompanyOnboardingError("rejected");
  }
}

function requireCanonicalUuid(value: string): void {
  if (!UUID_PATTERN.test(value)) {
    throw new CompanyOnboardingError("rejected");
  }
}

function requireHeaderValue(value: string): void {
  if (value.length === 0 || /[\r\n\s]/.test(value)) {
    throw new CompanyOnboardingError("authentication-required");
  }
}

function createEndpoint(rawBaseUrl: string): URL {
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    throw new CompanyOnboardingError("unavailable");
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
    throw new CompanyOnboardingError("unavailable");
  }

  return new URL("/functions/v1/company-onboarding", baseUrl);
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const length = Number(declaredLength);
    if (!Number.isSafeInteger(length) || length < 0 || length > RESPONSE_LIMIT_BYTES) {
      throw new CompanyOnboardingError("invalid-response");
    }
  }

  if (response.body === null) {
    throw new CompanyOnboardingError("invalid-response");
  }
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let length = 0;
  let body = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        body += decoder.decode();
        break;
      }
      length += value.byteLength;
      if (length > RESPONSE_LIMIT_BYTES) {
        await reader.cancel();
        throw new CompanyOnboardingError("invalid-response");
      }
      body += decoder.decode(value, { stream: true });
    }
  } finally {
    reader.releaseLock();
  }

  try {
    return JSON.parse(body);
  } catch {
    throw new CompanyOnboardingError("invalid-response");
  }
}

function parseResult(value: unknown): CompanyOnboardingResult {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new CompanyOnboardingError("invalid-response");
  }
  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).sort().join(",") !==
      "companyId,openingEntryId,schemaVersion,state" ||
    record.schemaVersion !== 1 ||
    record.state !== "active" ||
    typeof record.companyId !== "string" ||
    !UUID_PATTERN.test(record.companyId) ||
    typeof record.openingEntryId !== "string" ||
    !UUID_PATTERN.test(record.openingEntryId)
  ) {
    throw new CompanyOnboardingError("invalid-response");
  }
  return {
    companyId: record.companyId,
    openingEntryId: record.openingEntryId,
    schemaVersion: 1,
    state: "active",
  };
}

function classifyStatus(status: number): CompanyOnboardingError {
  if (status === 401 || status === 403) {
    return new CompanyOnboardingError("authentication-required");
  }
  if (status === 400 || status === 409 || status === 422) {
    return new CompanyOnboardingError("rejected");
  }
  return new CompanyOnboardingError("unavailable");
}

export async function onboardCompany(
  input: OnboardCompanyInput,
  fetchImplementation: Fetch = fetch,
): Promise<CompanyOnboardingResult> {
  requireNormalizedCompanyName(input.companyName);
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
        companyName: input.companyName,
        idempotencyKey: input.idempotencyKey,
      }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
      signal,
    });
  } catch {
    throw new CompanyOnboardingError("unavailable");
  }

  if (!response.ok) {
    throw classifyStatus(response.status);
  }
  return parseResult(await readBoundedJson(response));
}
