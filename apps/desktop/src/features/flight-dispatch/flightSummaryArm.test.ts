import { describe, expect, it, vi } from "vitest";

import {
  FLIGHT_SUMMARY_ARM_COMMAND,
  FlightSummaryArmError,
  armFlightSummary,
  type InvokeFlightSummaryArm,
} from "./flightSummaryArm";

const dispatchId = "94abcdef-0000-4000-8000-000000000004";

async function failureOf(run: Promise<unknown>): Promise<FlightSummaryArmError> {
  try {
    await run;
  } catch (reason) {
    expect(reason).toBeInstanceOf(FlightSummaryArmError);
    return reason as FlightSummaryArmError;
  }
  throw new Error("expected a FlightSummaryArmError");
}

describe("armFlightSummary", () => {
  it("invoque la commande d'armement avec le seul dispatch demandé", async () => {
    const invoke = vi.fn<InvokeFlightSummaryArm>(async () => ({
      contractVersion: "1",
      dispatchId,
    }));

    const armed = await armFlightSummary(dispatchId, invoke);

    expect(armed).toEqual({ contractVersion: "1", dispatchId });
    expect(invoke).toHaveBeenCalledOnce();
    expect(invoke).toHaveBeenCalledWith(FLIGHT_SUMMARY_ARM_COMMAND, { dispatchId });
  });

  it.each([
    ["vide", ""],
    ["hors UUID", "not-a-uuid"],
    ["majuscules", dispatchId.toUpperCase()],
    ["espaces", ` ${dispatchId} `],
  ])("refuse localement un dispatch %s avant tout appel", async (_label, candidate) => {
    const invoke = vi.fn<InvokeFlightSummaryArm>();

    const failure = await failureOf(armFlightSummary(candidate, invoke));

    expect(failure.failure).toBe("rejected");
    expect(invoke).not.toHaveBeenCalled();
  });

  it.each([
    ["clé inconnue", { contractVersion: "1", dispatchId, generation: 2 }],
    ["clé manquante", { contractVersion: "1" }],
    ["version étrangère", { contractVersion: "2", dispatchId }],
    ["dispatch divergent", { contractVersion: "1", dispatchId: dispatchId.replace("4", "5") }],
    ["tableau", []],
    ["null", null],
  ])("rejette un accusé forgé : %s", async (_label, payload) => {
    const failure = await failureOf(armFlightSummary(dispatchId, async () => payload));
    expect(failure.failure).toBe("invalid-response");
  });

  it("relaie les catégories rejected et invalid-response du shell", async () => {
    for (const category of ["rejected", "invalid-response"] as const) {
      const failure = await failureOf(
        armFlightSummary(dispatchId, () => Promise.reject(category)),
      );
      expect(failure.failure).toBe(category);
    }
  });

  it("classe tout autre rejet comme indisponible sans le relayer", async () => {
    const failure = await failureOf(
      armFlightSummary(dispatchId, () => Promise.reject(new Error("ECONNREFUSED 127.0.0.1:52345"))),
    );
    expect(failure.failure).toBe("unavailable");
    expect(failure.message).toBe("unavailable");
    expect(failure.message).not.toContain("127.0.0.1");
  });
});
