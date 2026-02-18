import { describe, expect, it } from "vitest";
import { canAccessPath, resolvePostLoginPath } from "./post-login-path";

describe("canAccessPath", () => {
  it("allows operations path with clients:read", () => {
    expect(canAccessPath("/app/clients", ["clients:read"])).toBe(true);
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

  it("falls back to operations path when no requested path", () => {
    expect(resolvePostLoginPath({ permissions: ["clients:read"] })).toBe("/app/clients");
  });

  it("falls back to first accessible default path when operations is not allowed", () => {
    expect(resolvePostLoginPath({ permissions: ["users:read"] })).toBe("/app/users");
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
