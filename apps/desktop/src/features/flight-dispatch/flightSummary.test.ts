import { describe, expect, it } from "vitest";

import {
  FLIGHT_SUMMARY_COMMAND,
  FlightSummaryError,
  readFlightSummary,
} from "./flightSummary";

const attachedDispatchId = "94abcdef-0000-4000-8000-000000000004";

const resolvedWith = (value: unknown) => () => Promise.resolve(value);

async function failureOf(run: Promise<unknown>): Promise<FlightSummaryError> {
  try {
    await run;
  } catch (reason) {
    expect(reason).toBeInstanceOf(FlightSummaryError);
    return reason as FlightSummaryError;
  }
  throw new Error("expected a FlightSummaryError");
}

describe("readFlightSummary", () => {
  it("invoque exactement la commande du contrat", async () => {
    const commands: string[] = [];
    await readFlightSummary((command) => {
      commands.push(command);
      return Promise.resolve({
        attachedDispatchId: null,
        blockMinutes: null,
        contractVersion: "1",
        state: "idle",
      });
    });
    expect(commands).toEqual([FLIGHT_SUMMARY_COMMAND]);
  });

  it("accepte un vol terminé avec son temps de bloc et son rattachement", async () => {
    const summary = await readFlightSummary(
      resolvedWith({
        attachedDispatchId,
        blockMinutes: 42,
        contractVersion: "1",
        state: "completed",
      }),
    );
    expect(summary).toEqual({
      attachedDispatchId,
      blockMinutes: 42,
      contractVersion: "1",
      state: "completed",
    });
  });

  it("accepte une mesure non rattachée", async () => {
    const summary = await readFlightSummary(
      resolvedWith({
        attachedDispatchId: null,
        blockMinutes: 42,
        contractVersion: "1",
        state: "completed",
      }),
    );
    expect(summary.attachedDispatchId).toBeNull();
  });

  it.each(["idle", "running", "incomplete"])(
    "accepte l'état %s sans temps de bloc",
    async (state) => {
      const summary = await readFlightSummary(
        resolvedWith({
          attachedDispatchId: null,
          blockMinutes: null,
          contractVersion: "1",
          state,
        }),
      );
      expect(summary.state).toBe(state);
      expect(summary.blockMinutes).toBeNull();
    },
  );

  it.each([
    [
      "clé inconnue",
      {
        attachedDispatchId: null,
        blockMinutes: null,
        contractVersion: "1",
        state: "idle",
        token: "x",
      },
    ],
    ["clé manquante", { attachedDispatchId: null, contractVersion: "1", state: "idle" }],
    [
      "rattachement manquant (forme F0004)",
      { blockMinutes: null, contractVersion: "1", state: "idle" },
    ],
    [
      "rattachement hors UUID canonique",
      {
        attachedDispatchId: "not-a-uuid",
        blockMinutes: null,
        contractVersion: "1",
        state: "idle",
      },
    ],
    [
      "rattachement en majuscules",
      {
        attachedDispatchId: attachedDispatchId.toUpperCase(),
        blockMinutes: null,
        contractVersion: "1",
        state: "idle",
      },
    ],
    [
      "version étrangère",
      { attachedDispatchId: null, blockMinutes: null, contractVersion: "2", state: "idle" },
    ],
    [
      "état inconnu",
      { attachedDispatchId: null, blockMinutes: null, contractVersion: "1", state: "landed" },
    ],
    [
      "terminé sans temps",
      { attachedDispatchId: null, blockMinutes: null, contractVersion: "1", state: "completed" },
    ],
    [
      "temps hors vol terminé",
      { attachedDispatchId: null, blockMinutes: 5, contractVersion: "1", state: "running" },
    ],
    [
      "temps nul",
      { attachedDispatchId: null, blockMinutes: 0, contractVersion: "1", state: "completed" },
    ],
    [
      "temps non entier",
      { attachedDispatchId: null, blockMinutes: 1.5, contractVersion: "1", state: "completed" },
    ],
    [
      "temps en chaîne",
      { attachedDispatchId: null, blockMinutes: "1", contractVersion: "1", state: "completed" },
    ],
    ["tableau", []],
    ["null", null],
    ["chaîne", "idle"],
  ])("rejette un résumé forgé : %s", async (_label, payload) => {
    const failure = await failureOf(readFlightSummary(resolvedWith(payload)));
    expect(failure.failure).toBe("invalid-response");
  });

  it("relaie la catégorie invalid-response du shell", async () => {
    const failure = await failureOf(readFlightSummary(() => Promise.reject("invalid-response")));
    expect(failure.failure).toBe("invalid-response");
  });

  it("classe tout autre rejet comme indisponible sans le relayer", async () => {
    const failure = await failureOf(
      readFlightSummary(() => Promise.reject(new Error("ECONNREFUSED 127.0.0.1:52345"))),
    );
    expect(failure.failure).toBe("unavailable");
    expect(failure.message).toBe("unavailable");
    expect(failure.message).not.toContain("127.0.0.1");
  });

  it("ne laisse traverser que les quatre clés du contrat", async () => {
    const summary = await readFlightSummary(
      resolvedWith({
        attachedDispatchId,
        blockMinutes: 7,
        contractVersion: "1",
        state: "completed",
      }),
    );
    expect(Object.keys(summary).sort()).toEqual([
      "attachedDispatchId",
      "blockMinutes",
      "contractVersion",
      "state",
    ]);
  });
});
