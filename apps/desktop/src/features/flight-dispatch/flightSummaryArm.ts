const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export type FlightSummaryArmFailure = "invalid-response" | "rejected" | "unavailable";

export interface ArmedFlightSummary {
  contractVersion: "1";
  dispatchId: string;
}

export const FLIGHT_SUMMARY_ARM_COMMAND = "flight_summary_arm";

export type InvokeFlightSummaryArm = (
  command: typeof FLIGHT_SUMMARY_ARM_COMMAND,
  args: { dispatchId: string },
) => Promise<unknown>;

export class FlightSummaryArmError extends Error {
  readonly failure: FlightSummaryArmFailure;

  constructor(failure: FlightSummaryArmFailure) {
    super(failure);
    this.name = "FlightSummaryArmError";
    this.failure = failure;
  }
}

function isArmedFlightSummary(
  value: unknown,
  requestedDispatchId: string,
): value is ArmedFlightSummary {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const record = value as Record<string, unknown>;
  return (
    Object.keys(record).sort().join(",") === "contractVersion,dispatchId" &&
    record.contractVersion === "1" &&
    record.dispatchId === requestedDispatchId
  );
}

function classifyRejection(reason: unknown): FlightSummaryArmError {
  if (reason === "invalid-response" || reason === "rejected") {
    return new FlightSummaryArmError(reason);
  }
  return new FlightSummaryArmError("unavailable");
}

// Arme la mesure du bridge pour un dispatch : à appeler au départ du vol,
// jamais à la clôture. Le refus d'un réarmement en pleine mesure remonte en
// « rejected » sans détail.
export async function armFlightSummary(
  dispatchId: string,
  invokeImplementation: InvokeFlightSummaryArm,
): Promise<ArmedFlightSummary> {
  if (!UUID_PATTERN.test(dispatchId)) {
    throw new FlightSummaryArmError("rejected");
  }

  let value: unknown;
  try {
    value = await invokeImplementation(FLIGHT_SUMMARY_ARM_COMMAND, { dispatchId });
  } catch (reason) {
    throw classifyRejection(reason);
  }

  if (!isArmedFlightSummary(value, dispatchId)) {
    throw new FlightSummaryArmError("invalid-response");
  }
  return value;
}
