import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { login as loginRequest, logout as logoutRequest, me, setToken, getToken } from "@/lib/api";
import type { ApiError } from "@/lib/api";
import type { LoginPayload, MeResponse, User } from "@/types/auth";

type AuthContextValue = {
  token: string | null;
  user: User | null;
  permissions: string[];
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (payload: LoginPayload) => Promise<MeResponse>;
  logout: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

function isApiError(error: unknown): error is ApiError {
  return typeof error === "object" && error !== null && "code" in error && "message" in error;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  const [token, setTokenState] = useState<string | null>(() => getToken());

  const persistToken = useCallback((nextToken: string | null) => {
    setToken(nextToken);
    setTokenState(nextToken);
  }, []);

  const meQuery = useQuery({
    queryKey: ["auth", "me", token],
    queryFn: me,
    enabled: Boolean(token),
    retry: false,
  });

  useEffect(() => {
    if (!token) return;
    if (isApiError(meQuery.error) && meQuery.error.status === 401) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- invalid token must be cleared immediately.
      persistToken(null);
      queryClient.removeQueries({ queryKey: ["auth"] });
    }
  }, [token, meQuery.error, queryClient, persistToken]);

  const login = useCallback(
    async (payload: LoginPayload) => {
      const response = await loginRequest(payload);
      persistToken(response.token);
      return queryClient.fetchQuery({
        queryKey: ["auth", "me", response.token],
        queryFn: me,
      });
    },
    [persistToken, queryClient],
  );

  const logout = useCallback(async () => {
    await logoutRequest();
    persistToken(null);
    queryClient.clear();
  }, [persistToken, queryClient]);

  const value = useMemo<AuthContextValue>(() => {
    const meData = meQuery.data;
    return {
      token,
      user: meData?.user ?? null,
      permissions: meData?.permissions ?? [],
      isLoading: Boolean(token) && meQuery.isPending,
      isAuthenticated: Boolean(token) && Boolean(meData?.user),
      login,
      logout,
    };
  }, [token, meQuery.data, meQuery.isPending, login, logout]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return context;
}
