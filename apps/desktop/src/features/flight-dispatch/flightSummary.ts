const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export type FlightSummaryFailure = "invalid-response" | "unavailable";

export type FlightSummaryState = "completed" | "idle" | "incomplete" | "running";

export interface FlightSummary {
  attachedDispatchId: string | null;
  blockMinutes: number | null;
  contractVersion: "1";
  state: FlightSummaryState;
}

export const FLIGHT_SUMMARY_COMMAND = "flight_summary";

export type InvokeFlightSummary = (command: typeof FLIGHT_SUMMARY_COMMAND) => Promise<unknown>;

export class FlightSummaryError extends Error {
  readonly failure: FlightSummaryFailure;

  constructor(failure: FlightSummaryFailure) {
    super(failure);
    this.name = "FlightSummaryError";
    this.failure = failure;
  }
}

const STATES: readonly string[] = ["completed", "idle", "incomplete", "running"];

function isFlightSummary(value: unknown): value is FlightSummary {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }

  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).sort().join(",") !==
    "attachedDispatchId,blockMinutes,contractVersion,state"
  ) {
    return false;
  }
  if (record.contractVersion !== "1" || !STATES.includes(record.state as string)) {
    return false;
  }
  if (
    record.attachedDispatchId !== null &&
    (typeof record.attachedDispatchId !== "string" ||
      !UUID_PATTERN.test(record.attachedDispatchId))
  ) {
    return false;
  }
  if (record.state === "completed") {
    return (
      typeof record.blockMinutes === "number" &&
      Number.isInteger(record.blockMinutes) &&
      record.blockMinutes >= 1
    );
  }
  return record.blockMinutes === null;
}

function classifyRejection(reason: unknown): FlightSummaryError {
  return new FlightSummaryError(reason === "invalid-response" ? "invalid-response" : "unavailable");
}

export async function readFlightSummary(
  invokeImplementation: InvokeFlightSummary,
): Promise<FlightSummary> {
  let value: unknown;
  try {
    value = await invokeImplementation(FLIGHT_SUMMARY_COMMAND);
  } catch (reason) {
    throw classifyRejection(reason);
  }

  if (!isFlightSummary(value)) {
    throw new FlightSummaryError("invalid-response");
  }
  return value;
}
