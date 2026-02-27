export type DashboardVariant = "admin" | "staff" | "driver";

type ResolveDashboardVariantParams = {
  roles: string[];
  permissions: string[];
};

function hasRole(roles: string[], role: string): boolean {
  return roles.some((item) => item.toLowerCase() === role);
}

export function resolveDashboardVariant(params: ResolveDashboardVariantParams): DashboardVariant {
  if (hasRole(params.roles, "admin")) return "admin";
  if (hasRole(params.roles, "driver")) return "driver";
  if (hasRole(params.roles, "staff")) return "staff";

  if (params.permissions.includes("users:manage")) return "admin";
  if (params.permissions.includes("shuttles:operate") && !params.permissions.includes("today_board:read")) {
    return "driver";
  }
  return "staff";
}
