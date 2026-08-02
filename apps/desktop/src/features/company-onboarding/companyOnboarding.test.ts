import { describe, expect, it, vi } from "vitest";

import {
  CompanyOnboardingError,
  normalizeCompanyName,
  onboardCompany,
  type OnboardCompanyInput,
} from "@/features/company-onboarding/companyOnboarding";

const companyId = "91000000-0000-4000-8000-000000000001";
const openingEntryId = "91000000-0000-4000-8000-000000000002";
const idempotencyKey = "91000000-0000-4000-8000-000000000003";

const input: OnboardCompanyInput = {
  accessToken: "private-user-token",
  anonKey: "public-anon-key",
  companyName: "Synthetic Airways",
  idempotencyKey,
  supabaseUrl: "http://127.0.0.1:54321",
};

const success = {
  companyId,
  openingEntryId,
  schemaVersion: 1 as const,
  state: "active" as const,
};

async function expectFailure(
  promise: Promise<unknown>,
  failure: CompanyOnboardingError["failure"],
) {
  await expect(promise).rejects.toMatchObject({ name: "CompanyOnboardingError", failure });
}

describe("onboardCompany", () => {
  it("envoie uniquement le nom et l'idempotence puis valide la réponse allowlistée", async () => {
    const fetchImplementation = vi.fn<
      (input: string | URL | Request, init?: RequestInit) => Promise<Response>
    >(async () => Response.json(success));

    await expect(onboardCompany(input, fetchImplementation)).resolves.toEqual(success);

    const [url, init] = fetchImplementation.mock.calls[0]!;
    expect(url.toString()).toBe(
      "http://127.0.0.1:54321/functions/v1/company-onboarding",
    );
    expect(init).toMatchObject({
      method: "POST",
      headers: {
        accept: "application/json",
        apikey: "public-anon-key",
        authorization: "Bearer private-user-token",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        companyName: "Synthetic Airways",
        idempotencyKey,
      }),
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    expect(init?.signal).toBeInstanceOf(AbortSignal);
    expect(init?.body).not.toContain("owner");
    expect(init?.body).not.toContain("amount");
    expect(init?.body).not.toContain("currency");
  });

  it("normalise le nom avant la construction d'une intention", () => {
    expect(normalizeCompanyName("  Compagnie Ae\u0301rienne  ")).toBe("Compagnie Aérienne");
    expect(() => normalizeCompanyName(" A ")).toThrowError(
      new CompanyOnboardingError("rejected"),
    );
  });

  it.each([
    ["nom non normalisé", { companyName: " Synthetic Airways " }, "rejected"],
    [
      "UUID non canonique",
      { idempotencyKey: "ABCDEF00-0000-4000-8000-000000000003" },
      "rejected",
    ],
    ["bearer invalide", { accessToken: "bad token" }, "authentication-required"],
    ["origine distante HTTP", { supabaseUrl: "http://example.com" }, "unavailable"],
  ] as const)("refuse %s avant réseau", async (_label, override, failure) => {
    const fetchImplementation = vi.fn();

    await expectFailure(
      onboardCompany({ ...input, ...override }, fetchImplementation),
      failure,
    );
    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it.each([
    [401, "authentication-required"],
    [403, "authentication-required"],
    [400, "rejected"],
    [409, "rejected"],
    [503, "unavailable"],
  ] as const)("redige HTTP %s en %s", async (status, failure) => {
    await expectFailure(
      onboardCompany(
        input,
        async () => new Response("sensitive backend detail", { status }),
      ),
      failure,
    );
  });

  it.each([
    ["champ supplémentaire", { ...success, ownerId: companyId }],
    ["identifiant invalide", { ...success, companyId: "invalid" }],
    ["schéma inconnu", { ...success, schemaVersion: 2 }],
  ])("refuse une réponse invalide : %s", async (_label, body) => {
    await expectFailure(
      onboardCompany(input, async () => Response.json(body)),
      "invalid-response",
    );
  });

  it("interrompt la lecture d'une réponse surdimensionnée", async () => {
    await expectFailure(
      onboardCompany(input, async () => new Response(`"${"x".repeat(16_385)}"`)),
      "invalid-response",
    );
  });

  it("redige une panne réseau", async () => {
    await expectFailure(
      onboardCompany(input, async () => Promise.reject(new Error("private-user-token"))),
      "unavailable",
    );
  });
});
