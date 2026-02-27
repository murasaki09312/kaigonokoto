import type { User } from "@/types/auth";

export type RoleOption = {
  id: number;
  name: string;
  label: string;
};

export type AdminManagedUser = User & {
  roles: RoleOption[];
  role_names: string[];
  is_self: boolean;
};

export type AdminUsersListResult = {
  users: AdminManagedUser[];
  roleOptions: RoleOption[];
  meta: {
    current_user_id: number;
    can_manage_roles: boolean;
  };
};
