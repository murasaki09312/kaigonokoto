export type User = {
  id: number;
  tenant_id: number;
  name: string | null;
  email: string;
  created_at: string;
  updated_at: string;
};

export type MeResponse = {
  user: User;
  permissions: string[];
};

export type LoginPayload = {
  tenant_slug: string;
  email: string;
  password: string;
};

export type LoginResponse = {
  token: string;
  user: User;
};
