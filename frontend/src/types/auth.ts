export type UserRole = {
  id: number;
  name: string;
  label: string;
};

export type User = {
  id: number;
  tenant_id: number;
  name: string | null;
  email: string;
  role_names?: string[];
  roles?: UserRole[];
  created_at: string;
  updated_at: string;
};

export type MeResponse = {
  user: User;
  permissions: string[];
  roles?: string[];
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
