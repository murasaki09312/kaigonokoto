const OPERATIONS_PATH = "/app/clients";
const FALLBACK_PATHS = [OPERATIONS_PATH, "/app/reservations", "/app/users", "/app"] as const;

type RouteAccessRule = {
  pattern: RegExp;
  requiredPermissions: string[];
};

const ROUTE_ACCESS_RULES: RouteAccessRule[] = [
  { pattern: /^\/app\/today-board(?:\/|$)/, requiredPermissions: ["today_board:read"] },
  { pattern: /^\/app\/clients(?:\/|$)/, requiredPermissions: ["clients:read"] },
  { pattern: /^\/app\/reservations(?:\/|$)/, requiredPermissions: ["reservations:read"] },
  { pattern: /^\/app\/users(?:\/|$)/, requiredPermissions: ["users:read"] },
  { pattern: /^\/app\/?$/, requiredPermissions: [] },
];

function extractPathname(path: string): string {
  return path.split(/[?#]/, 1)[0] || "/";
}

function normalizeRequestedPath(path: string | null | undefined): string | null {
  if (!path) return null;
  if (!path.startsWith("/")) return null;
  if (path.startsWith("//")) return null;

  const pathname = extractPathname(path);
  if (pathname === "/login") return null;

  return path;
}

export function canAccessPath(path: string, permissions: string[]): boolean {
  const pathname = extractPathname(path);
  const rule = ROUTE_ACCESS_RULES.find((routeRule) => routeRule.pattern.test(pathname));
  if (!rule) return false;

  return rule.requiredPermissions.every((permission) => permissions.includes(permission));
}

export function resolvePostLoginPath({
  requestedPath,
  permissions,
}: {
  requestedPath?: string | null;
  permissions: string[];
}): string {
  const normalizedRequestedPath = normalizeRequestedPath(requestedPath);

  if (normalizedRequestedPath && canAccessPath(normalizedRequestedPath, permissions)) {
    return normalizedRequestedPath;
  }

  const fallbackPath = FALLBACK_PATHS.find((path) => canAccessPath(path, permissions));
  return fallbackPath ?? "/app";
}

export { OPERATIONS_PATH };
