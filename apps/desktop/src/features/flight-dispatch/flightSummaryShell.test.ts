import { afterEach, describe, expect, it, vi } from "vitest";

import {
  FLIGHT_SUMMARY_COMMAND,
  FlightSummaryError,
  readFlightSummary,
} from "@/features/flight-dispatch/flightSummary";
import { invokeFlightSummaryThroughShell } from "@/features/flight-dispatch/flightSummaryShell";

type ShellGlobal = { __TAURI_INTERNALS__?: { invoke?: unknown } };

const shellGlobal = globalThis as ShellGlobal;

afterEach(() => {
  delete shellGlobal.__TAURI_INTERNALS__;
});

describe("invokeFlightSummaryThroughShell", () => {
  it("relaie exactement la commande au shell et rend sa réponse brute", async () => {
    const invoke = vi.fn(async (command: string) => ({ received: command }));
    shellGlobal.__TAURI_INTERNALS__ = { invoke };

    await expect(invokeFlightSummaryThroughShell(FLIGHT_SUMMARY_COMMAND)).resolves.toEqual({
      received: "flight_summary",
    });
    expect(invoke).toHaveBeenCalledExactlyOnceWith("flight_summary");
  });

  it("échoue hors du shell Tauri, classé indisponible par le lecteur", async () => {
    const failure = await readFlightSummary(invokeFlightSummaryThroughShell).then(
      () => {
        throw new Error("expected a FlightSummaryError");
      },
      (reason: unknown) => reason,
    );

    expect(failure).toBeInstanceOf(FlightSummaryError);
    expect((failure as FlightSummaryError).failure).toBe("unavailable");
  });

  it("échoue quand le shell n’expose pas de fonction invoke", async () => {
    shellGlobal.__TAURI_INTERNALS__ = { invoke: "not-a-function" };

    await expect(invokeFlightSummaryThroughShell(FLIGHT_SUMMARY_COMMAND)).rejects.toThrow(
      "shell-unavailable",
    );
  });
});
