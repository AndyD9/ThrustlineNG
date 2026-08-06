import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import {
  type FlightSummaryCommand,
  FlightSummaryControl,
} from "@/features/flight-dispatch/FlightSummaryControl";
import type { FlightSummary } from "@/features/flight-dispatch/flightSummary";

const completedSummary: FlightSummary = {
  blockMinutes: 42,
  contractVersion: "1",
  state: "completed",
};

const summaryOf = (state: FlightSummary["state"]): FlightSummary => ({
  blockMinutes: null,
  contractVersion: "1",
  state,
});

describe("FlightSummaryControl", () => {
  it("ne lit rien au rendu et nomme le vol dans l’action", () => {
    const command = vi.fn<FlightSummaryCommand>(async () => completedSummary);
    render(<FlightSummaryControl command={command} flightLabel="LFPO → EGLL" />);

    expect(command).not.toHaveBeenCalled();
    expect(
      screen.getByRole("button", { name: "Afficher le temps de bloc · LFPO → EGLL" }),
    ).toBeEnabled();
  });

  it("affiche le temps de bloc d’un replay terminé, sans le recalculer", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightSummaryCommand>(async () => completedSummary);
    render(<FlightSummaryControl command={command} flightLabel="LFPO → EGLL" />);

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));

    expect(await screen.findByText("Temps de bloc mesuré : 42 min.")).toBeInTheDocument();
    expect(command).toHaveBeenCalledExactlyOnceWith();
    expect(
      screen.getByRole("button", { name: "Actualiser la mesure · LFPO → EGLL" }),
    ).toBeEnabled();
  });

  it("rend explicite un replay encore en cours", async () => {
    const user = userEvent.setup();
    render(
      <FlightSummaryControl command={async () => summaryOf("running")} flightLabel="A → B" />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));
    expect(await screen.findByText("Replay en cours : la mesure se poursuit.")).toBeInTheDocument();
  });

  it("rend explicite une trace incomplète, sans temps inventé", async () => {
    const user = userEvent.setup();
    render(
      <FlightSummaryControl command={async () => summaryOf("incomplete")} flightLabel="A → B" />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));
    expect(
      await screen.findByText("Trace incomplète : aucun temps de bloc mesuré."),
    ).toBeInTheDocument();
    expect(screen.queryByText(/min\./)).not.toBeInTheDocument();
  });

  it("rend explicite l’absence de replay mesuré", async () => {
    const user = userEvent.setup();
    render(
      <FlightSummaryControl command={async () => summaryOf("idle")} flightLabel="A → B" />,
    );

    await user.click(screen.getByRole("button", { name: /Afficher le temps de bloc/ }));
    expect(await screen.findByText("Aucun replay mesuré pour l’instant.")).toBeInTheDocument();
  });

  it("rend l’indisponibilité en alerte puis permet un retry", async () => {
    const user = userEvent.setup();
    const command = vi.fn<FlightSummaryCommand>()
      .mockRejectedValueOnce(new Error("unavailable"))
      .mockResolvedValueOnce(completedSummary);
    render(<FlightSummaryControl command={command} flightLabel="A → B" />);

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
    render(<FlightSummaryControl command={command} flightLabel="A → B" />);

    const button = screen.getByRole("button", { name: /Afficher le temps de bloc/ });
    await user.click(button);
    expect(await screen.findByText("Lecture du résumé de vol.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Lecture…/ })).toBeDisabled();

    resolve(completedSummary);
    expect(await screen.findByText("Temps de bloc mesuré : 42 min.")).toBeInTheDocument();
    expect(command).toHaveBeenCalledOnce();
  });
});
