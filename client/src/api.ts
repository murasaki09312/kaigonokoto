export type LoginResponse = {
  token: string;
  user: User;
};

export type User = {
  id: number;
  tenant_id: number;
  name: string | null;
  email: string;
  created_at: string;
  updated_at: string;
};

export type CreateUserPayload = {
  name?: string;
  email: string;
  password: string;
};

type ApiErrorPayload = {
  error: {
    code: string;
    message: string;
  };
};

const API_BASE_URL = "http://localhost:3000";
const TOKEN_STORAGE_KEY = "kaigonokoto.jwt";
let inMemoryToken: string | null = null;

function storage(): Storage | null {
  try {
    return typeof localStorage === "undefined" ? null : localStorage;
  } catch {
    return null;
  }
}

function getToken(): string | null {
  if (inMemoryToken) return inMemoryToken;
  const value = storage()?.getItem(TOKEN_STORAGE_KEY) ?? null;
  inMemoryToken = value;
  return value;
}

export function setToken(token: string | null): void {
  inMemoryToken = token;

  if (!storage()) return;
  if (token) {
    storage()!.setItem(TOKEN_STORAGE_KEY, token);
  } else {
    storage()!.removeItem(TOKEN_STORAGE_KEY);
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers ?? {});
  headers.set("Accept", "application/json");
  headers.set("Content-Type", "application/json");

  const token = getToken();
  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  const response = await fetch(`${API_BASE_URL}${path}`, { ...init, headers });
  const body = (await response.json().catch(() => ({}))) as T | ApiErrorPayload;

  if (!response.ok) {
    const error = (body as ApiErrorPayload).error;
    throw new Error(error ? `${error.code}: ${error.message}` : response.statusText);
  }

  return body as T;
}

export async function login(tenantSlug: string, email: string, password: string): Promise<LoginResponse> {
  const result = await request<LoginResponse>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ tenant_slug: tenantSlug, email, password }),
  });

  setToken(result.token);
  return result;
}

export async function me(): Promise<{ user: User }> {
  return request<{ user: User }>("/auth/me", { method: "GET" });
}

export async function listUsers(): Promise<{ users: User[] }> {
  return request<{ users: User[] }>("/users", { method: "GET" });
}

export async function createUser(payload: CreateUserPayload): Promise<{ user: User }> {
  return request<{ user: User }>("/users", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}
