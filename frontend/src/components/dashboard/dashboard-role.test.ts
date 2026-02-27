import { describe, expect, it } from "vitest";
import { resolveDashboardVariant } from "./dashboard-role";

describe("resolveDashboardVariant", () => {
  it("prioritizes explicit admin role", () => {
    const variant = resolveDashboardVariant({
      roles: ["staff", "admin"],
      permissions: [],
    });

    expect(variant).toBe("admin");
  });

  it("resolves driver and staff from explicit roles", () => {
    expect(
      resolveDashboardVariant({
        roles: ["driver"],
        permissions: [],
      }),
    ).toBe("driver");

    expect(
      resolveDashboardVariant({
        roles: ["staff"],
        permissions: [],
      }),
    ).toBe("staff");
  });

  it("falls back to permissions when roles are unavailable", () => {
    expect(
      resolveDashboardVariant({
        roles: [],
        permissions: ["users:manage"],
      }),
    ).toBe("admin");

    expect(
      resolveDashboardVariant({
        roles: [],
        permissions: ["shuttles:operate", "shuttles:read"],
      }),
    ).toBe("driver");
  });
});
