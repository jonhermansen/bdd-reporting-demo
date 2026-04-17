import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { App } from "./App";

beforeEach(() => {
  // @ts-expect-error — minimal fetch stub
  global.fetch = vi.fn(async (url: string, init?: RequestInit) => {
    if (init?.method === "POST") {
      return { json: async () => ({ id: 99, name: "widget" }) } as Response;
    }
    return { json: async () => [{ id: 1, name: "alpha" }] } as Response;
  });
});

describe("App", () => {
  it("TC001 renders the items heading", async () => {
    render(<App />);
    expect(screen.getByRole("heading")).toHaveTextContent("Items");
  });

  it("TC002 fetches and shows items", async () => {
    render(<App />);
    await waitFor(() =>
      expect(screen.getByText("alpha")).toBeInTheDocument(),
    );
  });

  it("TC003 adds an item via POST", async () => {
    render(<App />);
    fireEvent.change(screen.getByTestId("new-item"), {
      target: { value: "widget" },
    });
    fireEvent.click(screen.getByTestId("add"));
    await waitFor(() =>
      expect(screen.getByText("widget")).toBeInTheDocument(),
    );
  });

  it.skip("TC004 — skipped intentionally", () => {
    expect(true).toBe(false);
  });

  it("TC005 slow test (demonstrates slowest-report)", async () => {
    await new Promise((r) => setTimeout(r, 300));
    expect(true).toBe(true);
  });
});
