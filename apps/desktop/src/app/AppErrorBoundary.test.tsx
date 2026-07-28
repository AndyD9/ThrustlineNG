import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { AppErrorBoundary } from "@/app/AppErrorBoundary";

function BrokenView(): never {
  throw new Error("détail interne qui ne doit pas être rendu");
}

describe("AppErrorBoundary", () => {
  it("affiche un message sûr et déclenche l’abstraction de rechargement", async () => {
    const reloadPage = vi.fn();
    const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => undefined);
    const user = userEvent.setup();

    render(
      <AppErrorBoundary reloadPage={reloadPage}>
        <BrokenView />
      </AppErrorBoundary>,
    );

    expect(screen.getByRole("alert")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: /interface n’a pas pu/i })).toBeInTheDocument();
    expect(screen.queryByText(/détail interne/)).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Recharger" }));
    expect(reloadPage).toHaveBeenCalledOnce();
    consoleSpy.mockRestore();
  });
});
