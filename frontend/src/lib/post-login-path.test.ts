import { describe, expect, it } from "vitest";
import { canAccessPath, resolvePostLoginPath } from "./post-login-path";

describe("canAccessPath", () => {
  it("allows today board path with today_board:read", () => {
    expect(canAccessPath("/app/today-board", ["today_board:read"])).toBe(true);
  });

  it("allows operations path with clients:read", () => {
    expect(canAccessPath("/app/clients", ["clients:read"])).toBe(true);
  });

  it("allows shuttle path with shuttles:read", () => {
    expect(canAccessPath("/app/shuttle", ["shuttles:read"])).toBe(true);
  });

  it("allows invoices path with invoices:read", () => {
    expect(canAccessPath("/app/invoices", ["invoices:read"])).toBe(true);
  });

  it("rejects operations path without clients:read", () => {
    expect(canAccessPath("/app/clients", ["users:read"])).toBe(false);
  });

  it("allows dashboard for any authenticated user", () => {
    expect(canAccessPath("/app", [])).toBe(true);
  });

  it("rejects unknown app paths", () => {
    expect(canAccessPath("/app/unknown", ["clients:read", "users:read"])).toBe(false);
  });
});

describe("resolvePostLoginPath", () => {
  it("prioritizes requested path when accessible", () => {
    expect(
      resolvePostLoginPath({
        requestedPath: "/app/users?tab=all",
        permissions: ["users:read"],
      }),
    ).toBe("/app/users?tab=all");
  });

  it("returns requested today board path when permitted", () => {
    expect(
      resolvePostLoginPath({
        requestedPath: "/app/today-board",
        permissions: ["today_board:read"],
      }),
    ).toBe("/app/today-board");
  });

  it("falls back to operations path when no requested path", () => {
    expect(resolvePostLoginPath({ permissions: ["clients:read"] })).toBe("/app/clients");
  });

  it("falls back to reservations when clients page is not allowed", () => {
    expect(resolvePostLoginPath({ permissions: ["reservations:read"] })).toBe("/app/reservations");
  });

  it("falls back to first accessible default path when operations is not allowed", () => {
    expect(resolvePostLoginPath({ permissions: ["users:read"] })).toBe("/app/users");
  });

  it("falls back to shuttle board when only shuttles:read is available", () => {
    expect(resolvePostLoginPath({ permissions: ["shuttles:read"] })).toBe("/app/shuttle");
  });

  it("falls back to invoices when only invoices:read is available", () => {
    expect(resolvePostLoginPath({ permissions: ["invoices:read"] })).toBe("/app/invoices");
  });

  it("falls back to dashboard when no scoped pages are allowed", () => {
    expect(resolvePostLoginPath({ permissions: [] })).toBe("/app");
  });

  it("ignores unsafe or login requested paths", () => {
    expect(
      resolvePostLoginPath({
        requestedPath: "https://evil.example.com/phishing",
        permissions: ["clients:read"],
      }),
    ).toBe("/app/clients");

    expect(
      resolvePostLoginPath({
        requestedPath: "/login",
        permissions: ["clients:read"],
      }),
    ).toBe("/app/clients");
  });

  it("ignores requested path without permission", () => {
    expect(
      resolvePostLoginPath({
        requestedPath: "/app/clients/1",
        permissions: ["users:read"],
      }),
    ).toBe("/app/users");
  });

  it("falls back when requested app path is unknown", () => {
    expect(
      resolvePostLoginPath({
        requestedPath: "/app/unknown",
        permissions: ["clients:read"],
      }),
    ).toBe("/app/clients");
  });
});
