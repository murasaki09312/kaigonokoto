import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Search } from "lucide-react";
import { listUsers } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { CreateUserDialog } from "@/components/users/create-user-dialog";
import {
  UsersTable,
  UsersTableEmpty,
  UsersTableError,
  UsersTableSkeleton,
} from "@/components/users/users-table";

export function UsersPage() {
  const [search, setSearch] = useState("");
  const { permissions } = useAuth();
  const canManageUsers = permissions.includes("users:manage");

  const usersQuery = useQuery({
    queryKey: ["users"],
    queryFn: listUsers,
  });

  const filteredUsers = useMemo(() => {
    const normalized = search.trim().toLowerCase();
    if (!normalized) return usersQuery.data ?? [];

    return (usersQuery.data ?? []).filter((user) => {
      return (
        user.email.toLowerCase().includes(normalized) ||
        (user.name ?? "").toLowerCase().includes(normalized)
      );
    });
  }, [usersQuery.data, search]);

  return (
    <div className="space-y-4">
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <CardTitle className="text-base">Users</CardTitle>
            <CardDescription>現在のテナント配下ユーザー一覧</CardDescription>
          </div>

          <div className="flex w-full items-center gap-2 lg:w-auto">
            <div className="relative w-full lg:w-72">
              <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                className="rounded-xl pl-9"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="名前・メールで検索"
              />
            </div>
            <CreateUserDialog canManage={canManageUsers} />
          </div>
        </CardHeader>
        <CardContent>
          {usersQuery.isPending && <UsersTableSkeleton />}

          {usersQuery.isError && !usersQuery.isPending && (
            <UsersTableError onRetry={() => usersQuery.refetch()} />
          )}

          {!usersQuery.isPending && !usersQuery.isError && filteredUsers.length === 0 && (
            <UsersTableEmpty query={search} />
          )}

          {!usersQuery.isPending && !usersQuery.isError && filteredUsers.length > 0 && (
            <UsersTable users={filteredUsers} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
