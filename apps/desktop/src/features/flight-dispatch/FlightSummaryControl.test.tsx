import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import {
  type FlightSummaryCommand,
  FlightSummaryControl,
} from "@/features/flight-dispatch/FlightSummaryControl";
import type { FlightSummary } from "@/features/flight-dispatch/flightSummary";

const dispatchId = "94abcdef-0000-4000-8000-000000000004";
const otherDispatchId = "94abcdef-0000-4000-8000-000000000005";

const completedSummary: FlightSummary = {
  attachedDispatchId: dispatchId,
  blockMinutes: 42,
  contractVersion: "1",
  state: "completed",
};

const summaryOf = (state: FlightSummary["state"]): FlightSummary => ({
  attachedDispatchId: dispatchId,
  blockMinutes: null,
  contractVersion: "1",
  state,
});

describe("FlightSummaryControl", () => {
  it("ne lit rien au rendu et nomme le vol dans l’action", () => {
    const command = vi.fn<FlightSummaryCommand>(async () => completedSummary);
    render(
      <FlightSummaryControl
        command={command}
        dispatchId={dispatchId}
        flightLabel="LFPO → EGLL"
      />,
    );

    expect(command).not.toHaveBeenCalled();
    expect(
      screen.getByRole("button", { name: "Afficher le temps de bloc · LFPO → EGLL" }),
    ).toBeEnabled();
  });

  it("affiche le temps de bloc du vol rattaché, sans le recalculer", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightSummaryCommand>(async () => completedSummary);
    render(
      <FlightSummaryControl
        command={command}
        dispatchId={dispatchId}
        flightLabel="LFPO → EGLL"
      />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));

    expect(await screen.findByText("Temps de bloc mesuré : 42 min.")).toBeInTheDocument();
    expect(command).toHaveBeenCalledExactlyOnceWith();
    expect(
      screen.getByRole("button", { name: "Actualiser la mesure · LFPO → EGLL" }),
    ).toBeEnabled();
  });

  it("n’attribue jamais la mesure d’un autre vol à cette ligne", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightSummaryCommand>(async () => ({
      ...completedSummary,
      attachedDispatchId: otherDispatchId,
    }));
    render(
      <FlightSummaryControl
        command={command}
        dispatchId={dispatchId}
        flightLabel="A → B"
      />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));

    expect(await screen.findByText("Aucune mesure rattachée à ce vol.")).toBeInTheDocument();
    expect(screen.queryByText(/min\./)).not.toBeInTheDocument();
  });

  it("échoue fermé sur une mesure sans rattachement", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightSummaryCommand>(async () => ({
      ...completedSummary,
      attachedDispatchId: null,
    }));
    render(
      <FlightSummaryControl
        command={command}
        dispatchId={dispatchId}
        flightLabel="A → B"
      />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));

    expect(await screen.findByText("Aucune mesure rattachée à ce vol.")).toBeInTheDocument();
    expect(screen.queryByText(/min\./)).not.toBeInTheDocument();
  });

  it("rend explicite un replay encore en cours", async () => {
    const user = userEvent.setup();
    render(
      <FlightSummaryControl
        command={async () => summaryOf("running")}
        dispatchId={dispatchId}
        flightLabel="A → B"
      />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));
    expect(await screen.findByText("Replay en cours : la mesure se poursuit.")).toBeInTheDocument();
  });

  it("rend explicite une trace incomplète, sans temps inventé", async () => {
    const user = userEvent.setup();
    render(
      <FlightSummaryControl
        command={async () => summaryOf("incomplete")}
        dispatchId={dispatchId}
        flightLabel="A → B"
      />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));
    expect(
      await screen.findByText("Trace incomplète : aucun temps de bloc mesuré."),
    ).toBeInTheDocument();
    expect(screen.queryByText(/min\./)).not.toBeInTheDocument();
  });

  it("rend explicite une mesure armée sans replay mesuré", async () => {
    const user = userEvent.setup();
    render(
      <FlightSummaryControl
        command={async () => summaryOf("idle")}
        dispatchId={dispatchId}
        flightLabel="A → B"
      />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));
    expect(
      await screen.findByText("Mesure armée : aucun replay mesuré pour l’instant."),
    ).toBeInTheDocument();
  });

  it("rend l’indisponibilité en alerte puis permet un retry", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightSummaryCommand>()
      .mockRejectedValueOnce(new Error("unavailable"))
      .mockResolvedValueOnce(completedSummary);
    render(
      <FlightSummaryControl command={command} dispatchId={dispatchId} flightLabel="A → B" />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");

    await user.click(screen.getByRole("button", { name: "Réessayer · A → B" }));
    expect(await screen.findByText("Temps de bloc mesuré : 42 min.")).toBeInTheDocument();
    expect(command).toHaveBeenCalledTimes(2);
  });

  it("bloque les lectures concurrentes pendant une mesure", async () => {
    const user = userEvent.setup();
    let resolve!: (summary: FlightSummary) => void;
    const pending = new Promise<FlightSummary>((promiseResolve) => {
      resolve = promiseResolve;
    });
    const command = vi.fn<FlightSummaryCommand>(async () => pending);
    render(
      <FlightSummaryControl command={command} dispatchId={dispatchId} flightLabel="A → B" />,
    );

    const button = screen.getByRole("button", { name: /Afficher le temps de bloc/ });
    await user.click(button);
    expect(await screen.findByText("Lecture du résumé de vol.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Lecture…/ })).toBeDisabled();

    resolve(completedSummary);
    expect(await screen.findByText("Temps de bloc mesuré : 42 min.")).toBeInTheDocument();
    expect(command).toHaveBeenCalledOnce();
  });
});
