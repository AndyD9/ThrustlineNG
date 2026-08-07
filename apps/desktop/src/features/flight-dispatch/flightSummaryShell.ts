import type { InvokeFlightSummary } from "@/features/flight-dispatch/flightSummary";

type ShellInvoke = (command: string) => Promise<unknown>;

interface ShellInternals {
  invoke?: unknown;
}

function resolveShellInvoke(): ShellInvoke | null {
  const internals = (globalThis as { __TAURI_INTERNALS__?: ShellInternals }).__TAURI_INTERNALS__;
  const invoke = internals?.invoke;
  return typeof invoke === "function" ? (invoke as ShellInvoke) : null;
}

export const invokeFlightSummaryThroughShell: InvokeFlightSummary = (command) => {
  const invoke = resolveShellInvoke();
  if (invoke === null) {
    return Promise.reject(new Error("shell-unavailable"));
  }
  return invoke(command);
};
