import axios, { AxiosError } from "axios";
import type { LoginPayload, LoginResponse, MeResponse, User } from "@/types/auth";
import type { Client, ClientPayload, ClientStatus } from "@/types/client";
import type { Contract, ContractPayload } from "@/types/contract";

export type ApiError = {
  code: string;
  message: string;
  status?: number;
};

type ErrorPayload = {
  error?: {
    code?: string;
    message?: string;
  };
  exception?: string;
};

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000";
const TOKEN_KEY = "kaigonokoto.jwt";

const client = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
});

client.interceptors.request.use((config) => {
  const token = getToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null): void {
  if (!token) {
    localStorage.removeItem(TOKEN_KEY);
    return;
  }

  localStorage.setItem(TOKEN_KEY, token);
}

function normalizeError(error: unknown): ApiError {
  if (axios.isAxiosError(error)) {
    const axiosError = error as AxiosError<ErrorPayload>;
    const status = axiosError.response?.status;
    const responseData = axiosError.response?.data;
    const responsePayload =
      typeof responseData === "object" && responseData !== null
        ? (responseData as ErrorPayload)
        : undefined;
    const code = responsePayload?.error?.code ?? "request_failed";

    let message = responsePayload?.error?.message ?? axiosError.message;
    const exception = typeof responseData === "string" ? responseData : responsePayload?.exception ?? "";
    const hasDatabaseConnectionError =
      exception.includes("ConnectionNotEstablished") || exception.includes("PG::ConnectionBad");

    if (code === "database_unavailable" || status === 503 || (status === 500 && hasDatabaseConnectionError)) {
      message = "データベースに接続できません。PostgreSQL を起動して再試行してください。";
    }

    return {
      code,
      message,
      status,
    };
  }

  return {
    code: "unexpected_error",
    message: error instanceof Error ? error.message : "Unexpected error",
  };
}

export async function login(payload: LoginPayload): Promise<LoginResponse> {
  try {
    const { data } = await client.post<LoginResponse>("/auth/login", payload);
    return data;
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function me(): Promise<MeResponse> {
  try {
    const { data } = await client.get<MeResponse>("/auth/me");
    return data;
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function logout(): Promise<void> {
  try {
    await client.post("/auth/logout");
  } catch {
    // Server side token invalidation is not used in MVP.
  }
}

export async function listUsers(): Promise<User[]> {
  try {
    const { data } = await client.get<{ users: User[] }>("/users");
    return data.users;
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function createUser(payload: {
  name?: string;
  email: string;
  password: string;
}): Promise<User> {
  try {
    const { data } = await client.post<{ user: User }>("/users", payload);
    return data.user;
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function listClients(params?: {
  q?: string;
  status?: ClientStatus | "all";
}): Promise<{ clients: Client[]; total: number }> {
  try {
    const searchParams = new URLSearchParams();

    if (params?.q) searchParams.set("q", params.q);
    if (params?.status && params.status !== "all") searchParams.set("status", params.status);

    const query = searchParams.toString();
    const path = query.length > 0 ? `/clients?${query}` : "/clients";
    const { data } = await client.get<{ clients: Client[]; meta: { total: number } }>(path);

    return {
      clients: data.clients,
      total: data.meta.total,
    };
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function getClient(id: number | string): Promise<Client> {
  try {
    const { data } = await client.get<{ client: Client }>(`/clients/${id}`);
    return data.client;
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function createClient(payload: ClientPayload): Promise<Client> {
  try {
    const { data } = await client.post<{ client: Client }>("/clients", payload);
    return data.client;
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function updateClient(id: number | string, payload: ClientPayload): Promise<Client> {
  try {
    const { data } = await client.patch<{ client: Client }>(`/clients/${id}`, payload);
    return data.client;
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function deleteClient(id: number | string): Promise<void> {
  try {
    await client.delete(`/clients/${id}`);
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function listContracts(
  clientId: number | string,
  params?: { as_of?: string },
): Promise<{ contracts: Contract[]; total: number; currentContractId: number | null }> {
  try {
    const searchParams = new URLSearchParams();
    if (params?.as_of) searchParams.set("as_of", params.as_of);

    const query = searchParams.toString();
    const path = query.length > 0 ? `/clients/${clientId}/contracts?${query}` : `/clients/${clientId}/contracts`;

    const { data } = await client.get<{
      contracts: Contract[];
      meta: { total: number; current_contract_id?: number | null };
    }>(path);

    return {
      contracts: data.contracts,
      total: data.meta.total,
      currentContractId: data.meta.current_contract_id ?? null,
    };
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function getContract(clientId: number | string, id: number | string): Promise<Contract> {
  try {
    const { data } = await client.get<{ contract: Contract }>(`/clients/${clientId}/contracts/${id}`);
    return data.contract;
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function createContract(clientId: number | string, payload: ContractPayload): Promise<Contract> {
  try {
    const { data } = await client.post<{ contract: Contract }>(`/clients/${clientId}/contracts`, payload);
    return data.contract;
  } catch (error) {
    throw normalizeError(error);
  }
}

export async function updateContract(
  clientId: number | string,
  id: number | string,
  payload: ContractPayload,
): Promise<Contract> {
  try {
    const { data } = await client.patch<{ contract: Contract }>(`/clients/${clientId}/contracts/${id}`, payload);
    return data.contract;
  } catch (error) {
    throw normalizeError(error);
  }
}
