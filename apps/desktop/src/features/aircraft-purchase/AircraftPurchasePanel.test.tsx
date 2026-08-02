import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { AircraftPurchasePanel } from "@/features/aircraft-purchase/AircraftPurchasePanel";
import {
  AircraftPurchaseError,
  type AircraftPurchaseResult,
  type PurchaseAircraftInput,
} from "@/features/aircraft-purchase/aircraftPurchase";

const offerId = "82000000-0000-4000-8000-000000000001";
const secondOfferId = "82000000-0000-4000-8000-000000000002";
const firstKey = "82000000-0000-4000-8000-000000000003";
const secondKey = "82000000-0000-4000-8000-000000000004";
const aircraftId = "82000000-0000-4000-8000-000000000005";
const ledgerEntryId = "82000000-0000-4000-8000-000000000006";

const result: AircraftPurchaseResult = {
  aircraftId,
  ledgerEntryId,
  offerId,
  schemaVersion: 1,
  state: "owned",
};

const baseProps = {
  anonKey: "public-anon-key",
  createIdempotencyKey: () => firstKey,
  offer: { id: offerId, label: "Cessna 172" },
  session: { accessToken: "private-user-token" },
  supabaseUrl: "https://example.supabase.co",
};

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((promiseResolve, promiseReject) => {
    resolve = promiseResolve;
    reject = promiseReject;
  });
  return { promise, reject, resolve };
}

describe("AircraftPurchasePanel", () => {
  it("passe de prêt à pending puis owned et bloque un double clic", async () => {
    const user = userEvent.setup();
    const pending = deferred<AircraftPurchaseResult>();
    const command = vi.fn((_input: PurchaseAircraftInput) => pending.promise);
    const { container } = render(<AircraftPurchasePanel {...baseProps} command={command} />);

    const button = screen.getByRole("button", { name: "Acheter cet avion" });
    await user.dblClick(button);

    expect(command).toHaveBeenCalledOnce();
    expect(button).toBeDisabled();
    expect(screen.getByText("Achat en cours. Ne fermez pas cette fenêtre.")).toBeInTheDocument();
    expect(container).not.toHaveTextContent("private-user-token");
    expect(container).not.toHaveTextContent("public-anon-key");

    pending.resolve(result);

    expect(await screen.findByText("Avion acquis. Il est maintenant dans votre flotte.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Avion acquis" })).toBeDisabled();
    expect(command.mock.calls[0]![0]).toMatchObject({
      accessToken: "private-user-token",
      anonKey: "public-anon-key",
      idempotencyKey: firstKey,
      offerId,
    });
  });

  it("réutilise la clé de la même intention après indisponibilité", async () => {
    const user = userEvent.setup();
    const command = vi
      .fn<(input: PurchaseAircraftInput) => Promise<AircraftPurchaseResult>>()
      .mockRejectedValueOnce(new AircraftPurchaseError("unavailable"))
      .mockResolvedValueOnce(result);
    render(<AircraftPurchasePanel {...baseProps} command={command} />);

    await user.click(screen.getByRole("button", { name: "Acheter cet avion" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("indisponible");
    await user.click(screen.getByRole("button", { name: "Réessayer" }));

    expect(await screen.findByText(/maintenant dans votre flotte/)).toBeInTheDocument();
    expect(command).toHaveBeenCalledTimes(2);
    expect(command.mock.calls[0]![0].idempotencyKey).toBe(firstKey);
    expect(command.mock.calls[1]![0].idempotencyKey).toBe(firstKey);
  });

  it("réinitialise l’intention quand l’offre change", async () => {
    const user = userEvent.setup();
    const command = vi.fn(async (commandInput: PurchaseAircraftInput) => ({
      ...result,
      aircraftId: commandInput.offerId === offerId ? aircraftId : secondKey,
      offerId: commandInput.offerId,
    }));
    const createIdempotencyKey = vi
      .fn<() => string>()
      .mockReturnValueOnce(firstKey)
      .mockReturnValueOnce(secondKey);
    const { rerender } = render(
      <AircraftPurchasePanel
        {...baseProps}
        command={command}
        createIdempotencyKey={createIdempotencyKey}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Acheter cet avion" }));
    expect(await screen.findByText(/maintenant dans votre flotte/)).toBeInTheDocument();
    rerender(
      <AircraftPurchasePanel
        {...baseProps}
        command={command}
        createIdempotencyKey={createIdempotencyKey}
        offer={{ id: secondOfferId, label: "Diamond DA40" }}
      />,
    );
    await user.click(await screen.findByRole("button", { name: "Acheter cet avion" }));

    expect(command.mock.calls[0]![0]).toMatchObject({ offerId, idempotencyKey: firstKey });
    expect(command.mock.calls[1]![0]).toMatchObject({
      offerId: secondOfferId,
      idempotencyKey: secondKey,
    });
  });

  it.each([
    ["authentication-required", "Votre session a expiré", "Réessayer après reconnexion"],
    ["rejected", "L’achat a été refusé", "Acheter cet avion"],
  ] as const)("présente un refus %s sans détail technique", async (failure, message, buttonName) => {
    const user = userEvent.setup();
    const command = vi.fn(async (_input: PurchaseAircraftInput): Promise<AircraftPurchaseResult> => {
      throw new AircraftPurchaseError(failure);
    });
    const { container } = render(<AircraftPurchasePanel {...baseProps} command={command} />);

    await user.click(screen.getByRole("button", { name: "Acheter cet avion" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(message);
    expect(screen.getByRole("button", { name: buttonName })).toBeInTheDocument();
    expect(container).not.toHaveTextContent(failure);
  });

  it("réutilise l’intention après reconnexion avec le nouveau bearer", async () => {
    const user = userEvent.setup();
    const command = vi
      .fn<(input: PurchaseAircraftInput) => Promise<AircraftPurchaseResult>>()
      .mockRejectedValueOnce(new AircraftPurchaseError("authentication-required"))
      .mockResolvedValueOnce(result);
    const { rerender } = render(<AircraftPurchasePanel {...baseProps} command={command} />);

    await user.click(screen.getByRole("button", { name: "Acheter cet avion" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("session a expiré");
    rerender(
      <AircraftPurchasePanel
        {...baseProps}
        command={command}
        session={{ accessToken: "refreshed-user-token" }}
      />,
    );
    await user.click(screen.getByRole("button", { name: "Réessayer après reconnexion" }));

    expect(await screen.findByText(/maintenant dans votre flotte/)).toBeInTheDocument();
    expect(command.mock.calls[0]![0].idempotencyKey).toBe(firstKey);
    expect(command.mock.calls[1]![0]).toMatchObject({
      accessToken: "refreshed-user-token",
      idempotencyKey: firstKey,
    });
  });

  it("annule la commande lors du démontage", async () => {
    let receivedSignal: AbortSignal | undefined;
    const command = vi.fn((commandInput: PurchaseAircraftInput) => {
      receivedSignal = commandInput.signal;
      return new Promise<AircraftPurchaseResult>(() => undefined);
    });
    const user = userEvent.setup();
    const { unmount } = render(<AircraftPurchasePanel {...baseProps} command={command} />);

    await user.click(screen.getByRole("button", { name: "Acheter cet avion" }));
    unmount();

    expect(receivedSignal?.aborted).toBe(true);
  });
});
