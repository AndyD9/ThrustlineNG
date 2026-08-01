const MAX_BODY_BYTES = 4_096;
const MAX_OPENING_AMOUNT_MINOR = 1_000_000_000_000_000;
const UPSTREAM_TIMEOUT_MILLISECONDS = 5_000;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export interface CompanyOnboardingEnvironment {
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  COMPANY_OPENING_BALANCE_MINOR?: string;
  COMPANY_OPENING_CURRENCY?: string;
}

interface CompanyOnboardingRequest {
  companyName: string;
  idempotencyKey: string;
}

interface AuthenticatedUser {
  id: string;
  is_anonymous: boolean;
}

interface CompanyOnboardingResponse {
  companyId: string;
  openingEntryId: string;
  schemaVersion: 1;
  state: "active";
}

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

class HttpError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(
    status: number,
    code: string,
    message: string,
  ) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function jsonResponse(status: number, body: unknown, extraHeaders?: HeadersInit): Response {
  const headers = new Headers(extraHeaders);
  headers.set("cache-control", "no-store");
  headers.set("content-type", "application/json; charset=utf-8");
  return new Response(JSON.stringify(body), {
    status,
    headers,
  });
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

function parseRequestBody(rawBody: string): CompanyOnboardingRequest {
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
  if (keys.length !== 2 || keys[0] !== "companyName" || keys[1] !== "idempotencyKey") {
    throw new HttpError(400, "invalid_request", "Request body contains unsupported fields.");
  }

  if (typeof record.companyName !== "string") {
    throw new HttpError(400, "invalid_company_name", "Company name is invalid.");
  }
  const normalizedName = record.companyName.trim().normalize("NFC");
  const nameLength = Array.from(normalizedName).length;
  if (record.companyName !== normalizedName || nameLength < 2 || nameLength > 80) {
    throw new HttpError(
      400,
      "invalid_company_name",
      "Company name must be normalized, trimmed, and contain between 2 and 80 characters.",
    );
  }

  if (typeof record.idempotencyKey !== "string" || !UUID_PATTERN.test(record.idempotencyKey)) {
    throw new HttpError(400, "invalid_idempotency_key", "Idempotency key must be a canonical UUID.");
  }

  return {
    companyName: normalizedName,
    idempotencyKey: record.idempotencyKey,
  };
}

function requireBearerToken(request: Request): string {
  const authorization = request.headers.get("authorization");
  const match = authorization?.match(/^Bearer ([^\s]+)$/);
  const token = match?.[1];
  if (token === undefined) {
    throw new HttpError(401, "authentication_required", "A valid session is required.");
  }
  return token;
}

function readRuntimeConfiguration(environment: CompanyOnboardingEnvironment): {
  anonKey: string;
  currencyCode: string;
  openingAmountMinor: number;
  serviceRoleKey: string;
  supabaseUrl: string;
} {
  const supabaseUrl = environment.SUPABASE_URL?.replace(/\/$/, "");
  const anonKey = environment.SUPABASE_ANON_KEY;
  const serviceRoleKey = environment.SUPABASE_SERVICE_ROLE_KEY;
  const currencyCode = environment.COMPANY_OPENING_CURRENCY;
  const rawAmount = environment.COMPANY_OPENING_BALANCE_MINOR;
  const openingAmountMinor = rawAmount === undefined ? Number.NaN : Number(rawAmount);

  if (
    supabaseUrl === undefined ||
    !/^https?:\/\//.test(supabaseUrl) ||
    anonKey === undefined ||
    anonKey.length === 0 ||
    serviceRoleKey === undefined ||
    serviceRoleKey.length === 0 ||
    currencyCode === undefined ||
    !/^[A-Z]{3}$/.test(currencyCode) ||
    !Number.isSafeInteger(openingAmountMinor) ||
    openingAmountMinor === 0 ||
    Math.abs(openingAmountMinor) > MAX_OPENING_AMOUNT_MINOR
  ) {
    throw new HttpError(503, "configuration_unavailable", "Company onboarding is not configured.");
  }

  return { anonKey, currencyCode, openingAmountMinor, serviceRoleKey, supabaseUrl };
}

async function authenticateUser(
  fetchImplementation: Fetch,
  supabaseUrl: string,
  anonKey: string,
  bearerToken: string,
): Promise<AuthenticatedUser> {
  let response: Response;
  try {
    response = await fetchImplementation(`${supabaseUrl}/auth/v1/user`, {
      method: "GET",
      headers: {
        apikey: anonKey,
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

function isCompanyOnboardingResponse(value: unknown): value is CompanyOnboardingResponse {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const response = value as Partial<CompanyOnboardingResponse>;
  return (
    response.schemaVersion === 1 &&
    response.state === "active" &&
    UUID_PATTERN.test(response.companyId ?? "") &&
    UUID_PATTERN.test(response.openingEntryId ?? "")
  );
}

async function createCompany(
  fetchImplementation: Fetch,
  configuration: ReturnType<typeof readRuntimeConfiguration>,
  user: AuthenticatedUser,
  request: CompanyOnboardingRequest,
): Promise<CompanyOnboardingResponse> {
  let response: Response;
  try {
    response = await fetchImplementation(
      `${configuration.supabaseUrl}/rest/v1/rpc/create_company_with_opening_balance`,
      {
        method: "POST",
        headers: {
          apikey: configuration.serviceRoleKey,
          authorization: `Bearer ${configuration.serviceRoleKey}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          company_name: request.companyName,
          currency_code: configuration.currencyCode,
          idempotency_key: request.idempotencyKey,
          opening_amount_minor: configuration.openingAmountMinor,
          owner_id: user.id,
        }),
        signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MILLISECONDS),
      },
    );
  } catch {
    throw new HttpError(503, "onboarding_unavailable", "Company onboarding is unavailable.");
  }

  if (!response.ok) {
    throw new HttpError(409, "onboarding_rejected", "Company could not be created.");
  }

  let value: unknown;
  try {
    value = await response.json();
  } catch {
    throw new HttpError(502, "invalid_backend_response", "Company onboarding returned an invalid response.");
  }
  if (!isCompanyOnboardingResponse(value)) {
    throw new HttpError(502, "invalid_backend_response", "Company onboarding returned an invalid response.");
  }
  return {
    companyId: value.companyId,
    openingEntryId: value.openingEntryId,
    schemaVersion: 1,
    state: "active",
  };
}

export function createCompanyOnboardingHandler(
  environment: CompanyOnboardingEnvironment,
  fetchImplementation: Fetch = fetch,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return jsonResponse(405, { error: { code: "method_not_allowed", message: "Use POST." } }, { allow: "POST" });
    }

    try {
      const bearerToken = requireBearerToken(request);
      const rawBody = await readBoundedBody(request);
      const onboardingRequest = parseRequestBody(rawBody);
      const configuration = readRuntimeConfiguration(environment);
      const user = await authenticateUser(
        fetchImplementation,
        configuration.supabaseUrl,
        configuration.anonKey,
        bearerToken,
      );
      const result = await createCompany(fetchImplementation, configuration, user, onboardingRequest);
      return jsonResponse(200, result);
    } catch (error) {
      if (error instanceof HttpError) {
        return jsonResponse(error.status, { error: { code: error.code, message: error.message } });
      }
      return jsonResponse(500, { error: { code: "internal_error", message: "Company onboarding failed." } });
    }
  };
}
