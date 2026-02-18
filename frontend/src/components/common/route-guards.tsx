import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "@/providers/auth-provider";
import { PageLoading } from "@/components/common/page-loading";
import { resolvePostLoginPath } from "@/lib/post-login-path";

export function ProtectedRoute() {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return <PageLoading />;
  }

  if (!isAuthenticated) {
    const returnTo = `${location.pathname}${location.search}${location.hash}`;
    return <Navigate to="/login" replace state={{ from: returnTo }} />;
  }

  return <Outlet />;
}

export function PublicOnlyRoute() {
  const { isAuthenticated, isLoading, permissions } = useAuth();

  if (isLoading) {
    return <PageLoading />;
  }

  if (isAuthenticated) {
    return <Navigate to={resolvePostLoginPath({ permissions })} replace />;
  }

  return <Outlet />;
}
