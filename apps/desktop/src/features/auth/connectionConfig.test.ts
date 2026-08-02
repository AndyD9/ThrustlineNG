import { describe, expect, it } from "vitest";

import {
  DesktopConnectionConfigError,
  readDesktopConnectionConfig,
} from "@/features/auth/connectionConfig";

const environment = {
  VITE_THRUSTLINE_SUPABASE_ANON_KEY: "public-local-anon-key",
  VITE_THRUSTLINE_SUPABASE_URL: "http://127.0.0.1:54321",
};

describe("readDesktopConnectionConfig", () => {
  it("accepte uniquement la cible Supabase locale publique identifiée", () => {
    expect(readDesktopConnectionConfig(environment)).toEqual({
      anonKey: "public-local-anon-key",
      supabaseUrl: "http://127.0.0.1:54321",
      target: "local",
    });
  });

  it.each([
    ["configuration absente", {}],
    ["origine locale divergente", { ...environment, VITE_THRUSTLINE_SUPABASE_URL: "http://localhost:54321" }],
    ["cible distante", { ...environment, VITE_THRUSTLINE_SUPABASE_URL: "https://example.supabase.co" }],
    ["clé absente", { VITE_THRUSTLINE_SUPABASE_URL: environment.VITE_THRUSTLINE_SUPABASE_URL }],
    ["clé avec espace", { ...environment, VITE_THRUSTLINE_SUPABASE_ANON_KEY: "public key" }],
  ])("refuse %s sans exposer la valeur", (_name, candidate) => {
    expect(() => readDesktopConnectionConfig(candidate)).toThrowError(
      new DesktopConnectionConfigError(),
    );
  });
});
