import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import {
  parseAuthSessionResponse,
  SessionError,
  type UserSessionTokens,
} from "@/features/auth/session";

const EMAIL_LIMIT_BYTES = 254;
const PASSWORD_LIMIT_BYTES = 1_024;
const RESPONSE_LIMIT_BYTES = 16_384;
const REQUEST_TIMEOUT_MILLISECONDS = 5_000;

type Fetch = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export type PasswordSignInFailure = "invalid-response" | "rejected" | "unavailable";

export interface PasswordSignInInput {
  config: DesktopConnectionConfig;
  email: string;
  password: string;
  signal?: AbortSignal;
}

export class PasswordSignInError extends Error {
  readonly failure: PasswordSignInFailure;

  constructor(failure: PasswordSignInFailure) {
    super(failure);
    this.name = "PasswordSignInError";
    this.failure = failure;
  }
}

function byteLength(value: string): number {
  return new TextEncoder().encode(value).byteLength;
}

function requireEmail(value: string): void {
  const atIndex = value.indexOf("@");
  if (
    value.length === 0 ||
    value !== value.trim() ||
    /\s/.test(value) ||
    atIndex <= 0 ||
    atIndex !== value.lastIndexOf("@") ||
    atIndex === value.length - 1 ||
    byteLength(value) > EMAIL_LIMIT_BYTES
  ) {
    throw new PasswordSignInError("rejected");
  }
}

function requirePassword(value: string): void {
  const length = byteLength(value);
  if (length === 0 || length > PASSWORD_LIMIT_BYTES) {
    throw new PasswordSignInError("rejected");
  }
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const length = Number(declaredLength);
    if (!Number.isSafeInteger(length) || length < 0 || length > RESPONSE_LIMIT_BYTES) {
      throw new PasswordSignInError("invalid-response");
    }
  }

  if (response.body === null) {
    throw new PasswordSignInError("invalid-response");
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
        throw new PasswordSignInError("invalid-response");
      }
      body += decoder.decode(value, { stream: true });
    }
  } finally {
    reader.releaseLock();
  }
  try {
    return JSON.parse(body);
  } catch {
    throw new PasswordSignInError("invalid-response");
  }
}

export async function signInWithPassword(
  input: PasswordSignInInput,
  fetchImplementation: Fetch = fetch,
  nowEpochSeconds: () => number = () => Math.floor(Date.now() / 1_000),
): Promise<UserSessionTokens> {
  requireEmail(input.email);
  requirePassword(input.password);

  const timeoutSignal = AbortSignal.timeout(REQUEST_TIMEOUT_MILLISECONDS);
  const signal = input.signal === undefined
    ? timeoutSignal
    : AbortSignal.any([input.signal, timeoutSignal]);

  let response: Response;
  try {
    response = await fetchImplementation(
      new URL("/auth/v1/token?grant_type=password", input.config.supabaseUrl),
      {
        method: "POST",
        headers: {
          accept: "application/json",
          apikey: input.config.anonKey,
          "content-type": "application/json",
        },
        body: JSON.stringify({ email: input.email, password: input.password }),
        cache: "no-store",
        credentials: "omit",
        referrerPolicy: "no-referrer",
        signal,
      },
    );
  } catch {
    throw new PasswordSignInError("unavailable");
  }

  if ([400, 401, 403, 422].includes(response.status)) {
    throw new PasswordSignInError("rejected");
  }
  if (!response.ok) {
    throw new PasswordSignInError("unavailable");
  }

  const value = await readBoundedJson(response);
  try {
    return parseAuthSessionResponse(value, nowEpochSeconds());
  } catch (error) {
    if (error instanceof SessionError) {
      throw new PasswordSignInError("invalid-response");
    }
    throw error;
  }
}
