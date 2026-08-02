const LOCAL_SUPABASE_URL = "http://127.0.0.1:54321";
const MAX_PUBLIC_KEY_LENGTH = 4_096;

export interface DesktopConnectionConfig {
  anonKey: string;
  supabaseUrl: typeof LOCAL_SUPABASE_URL;
  target: "local";
}

export interface DesktopConnectionEnvironment {
  VITE_THRUSTLINE_SUPABASE_ANON_KEY?: string;
  VITE_THRUSTLINE_SUPABASE_URL?: string;
}

export class DesktopConnectionConfigError extends Error {
  constructor() {
    super("desktop-connection-unavailable");
    this.name = "DesktopConnectionConfigError";
  }
}

function requirePublicHeaderValue(value: string | undefined): string {
  if (
    value === undefined ||
    value.length === 0 ||
    value.length > MAX_PUBLIC_KEY_LENGTH ||
    /[\r\n\s]/.test(value)
  ) {
    throw new DesktopConnectionConfigError();
  }
  return value;
}

export function readDesktopConnectionConfig(
  environment: DesktopConnectionEnvironment,
): DesktopConnectionConfig {
  if (environment.VITE_THRUSTLINE_SUPABASE_URL !== LOCAL_SUPABASE_URL) {
    throw new DesktopConnectionConfigError();
  }

  return {
    anonKey: requirePublicHeaderValue(environment.VITE_THRUSTLINE_SUPABASE_ANON_KEY),
    supabaseUrl: LOCAL_SUPABASE_URL,
    target: "local",
  };
}

export function readBundledDesktopConnectionConfig(): DesktopConnectionConfig {
  return readDesktopConnectionConfig(import.meta.env);
}
