import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";

const REFRESH_MARGIN_SECONDS = 30;
const RESPONSE_LIMIT_BYTES = 16_384;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;
const TOKEN_LIMIT_BYTES = 8_192;

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export type SessionFailure = "authentication-required" | "invalid-response" | "unavailable";

export interface UserSessionTokens {
  accessToken: string;
  expiresAtEpochSeconds: number;
  refreshToken: string;
}

interface AuthTokenResponse {
  access_token: string;
  expires_in: number;
  refresh_token: string;
  token_type: string;
}

export class SessionError extends Error {
  readonly failure: SessionFailure;

  constructor(failure: SessionFailure) {
    super(failure);
    this.name = "SessionError";
    this.failure = failure;
  }
}

function requireToken(value: string): void {
  if (
    value.length === 0 ||
    new TextEncoder().encode(value).byteLength > TOKEN_LIMIT_BYTES ||
    /[\r\n\s]/.test(value)
  ) {
    throw new SessionError("authentication-required");
  }
}

function requireSession(session: UserSessionTokens): UserSessionTokens {
  requireToken(session.accessToken);
  requireToken(session.refreshToken);
  if (!Number.isSafeInteger(session.expiresAtEpochSeconds) || session.expiresAtEpochSeconds <= 0) {
    throw new SessionError("authentication-required");
  }
  return { ...session };
}

async function readJson(response: Response): Promise<unknown> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const byteLength = Number(declaredLength);
    if (!Number.isSafeInteger(byteLength) || byteLength < 0 || byteLength > RESPONSE_LIMIT_BYTES) {
      throw new SessionError("invalid-response");
    }
  }

  const body = await response.text();
  if (new TextEncoder().encode(body).byteLength > RESPONSE_LIMIT_BYTES) {
    throw new SessionError("invalid-response");
  }
  try {
    return JSON.parse(body);
  } catch {
    throw new SessionError("invalid-response");
  }
}

export function parseAuthSessionResponse(
  value: unknown,
  nowEpochSeconds: number,
): UserSessionTokens {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new SessionError("invalid-response");
  }
  const response = value as Partial<AuthTokenResponse>;
  const expiresIn = response.expires_in;
  if (
    typeof response.access_token !== "string" ||
    typeof response.refresh_token !== "string" ||
    response.token_type !== "bearer" ||
    !Number.isSafeInteger(expiresIn) ||
    (expiresIn ?? 0) <= REFRESH_MARGIN_SECONDS ||
    (expiresIn ?? 0) > 604_800
  ) {
    throw new SessionError("invalid-response");
  }
  try {
    requireToken(response.access_token);
    requireToken(response.refresh_token);
  } catch {
    throw new SessionError("invalid-response");
  }
  return {
    accessToken: response.access_token,
    expiresAtEpochSeconds: nowEpochSeconds + (expiresIn as number),
    refreshToken: response.refresh_token,
  };
}

export class DesktopSessionManager {
  readonly #config: DesktopConnectionConfig;
  readonly #fetch: Fetch;
  readonly #nowEpochSeconds: () => number;
  #refreshInFlight: { promise: Promise<string>; revision: number } | undefined;
  #revision = 0;
  #session: UserSessionTokens | undefined;

  constructor(
    config: DesktopConnectionConfig,
    fetchImplementation: Fetch = fetch,
    nowEpochSeconds: () => number = () => Math.floor(Date.now() / 1_000),
  ) {
    this.#config = config;
    this.#fetch = fetchImplementation;
    this.#nowEpochSeconds = nowEpochSeconds;
  }

  setSession(session: UserSessionTokens): void {
    this.#session = requireSession(session);
    this.#revision += 1;
  }

  clear(): void {
    this.#session = undefined;
    this.#revision += 1;
  }

  hasSession(): boolean {
    return this.#session !== undefined;
  }

  async getAccessToken(): Promise<string> {
    const session = this.#session;
    if (session === undefined) {
      throw new SessionError("authentication-required");
    }
    if (session.expiresAtEpochSeconds - this.#nowEpochSeconds() > REFRESH_MARGIN_SECONDS) {
      return session.accessToken;
    }
    const revision = this.#revision;
    if (this.#refreshInFlight?.revision === revision) {
      return this.#refreshInFlight.promise;
    }
    const promise = this.#refresh(revision).finally(() => {
      if (this.#refreshInFlight?.promise === promise) {
        this.#refreshInFlight = undefined;
      }
    });
    this.#refreshInFlight = { promise, revision };
    return promise;
  }

  async #refresh(revision: number): Promise<string> {
    const session = this.#session;
    if (session === undefined) {
      throw new SessionError("authentication-required");
    }

    let response: Response;
    try {
      response = await this.#fetch(
        new URL("/auth/v1/token?grant_type=refresh_token", this.#config.supabaseUrl),
        {
          method: "POST",
          headers: {
            accept: "application/json",
            apikey: this.#config.anonKey,
            "content-type": "application/json",
          },
          body: JSON.stringify({ refresh_token: session.refreshToken }),
          cache: "no-store",
          credentials: "omit",
          referrerPolicy: "no-referrer",
          signal: AbortSignal.timeout(REQUEST_TIMEOUT_MILLISECONDS),
        },
      );
    } catch {
      throw new SessionError("unavailable");
    }

    if (this.#revision !== revision) {
      throw new SessionError("authentication-required");
    }
    if (response.status === 400 || response.status === 401 || response.status === 403) {
      this.clear();
      throw new SessionError("authentication-required");
    }
    if (!response.ok) {
      throw new SessionError("unavailable");
    }

    const refreshed = parseAuthSessionResponse(await readJson(response), this.#nowEpochSeconds());
    if (this.#revision !== revision) {
      throw new SessionError("authentication-required");
    }
    this.#session = refreshed;
    return refreshed.accessToken;
  }
}
