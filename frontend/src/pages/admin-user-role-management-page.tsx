import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Search } from "lucide-react";
import { toast } from "sonner";
import { listAdminUsers, updateAdminUserRoles, type ApiError } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

export function AdminUserRoleManagementPage() {
  const { permissions, user } = useAuth();
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [updatingUserId, setUpdatingUserId] = useState<number | null>(null);

  const canManageUsers = permissions.includes("users:manage");

  const adminUsersQuery = useQuery({
    queryKey: ["admin-users"],
    queryFn: listAdminUsers,
    enabled: canManageUsers,
  });

  const updateRoleMutation = useMutation({
    mutationFn: ({ userId, roleName }: { userId: number; roleName: string }) => {
      return updateAdminUserRoles(userId, { role_names: [roleName] });
    },
    onMutate: ({ userId }) => {
      setUpdatingUserId(userId);
    },
    onSuccess: async (_, variables) => {
      toast.success("ロールを更新しました");
      await queryClient.invalidateQueries({ queryKey: ["admin-users"] });
      setUpdatingUserId((current) => (current === variables.userId ? null : current));
    },
    onError: (error, variables) => {
      toast.error(formatApiError(error, "ロール更新に失敗しました"));
      setUpdatingUserId((current) => (current === variables.userId ? null : current));
    },
  });

  const filteredUsers = useMemo(() => {
    const users = adminUsersQuery.data?.users ?? [];
    const normalized = search.trim().toLowerCase();
    if (!normalized) return users;

    return users.filter((targetUser) => {
      return (
        targetUser.email.toLowerCase().includes(normalized) ||
        (targetUser.name ?? "").toLowerCase().includes(normalized)
      );
    });
  }, [adminUsersQuery.data?.users, search]);

  if (!canManageUsers) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardContent className="p-10 text-center">
          <p className="font-medium">権限がありません</p>
          <p className="mt-1 text-sm text-muted-foreground">
            users:manage 権限を持つ管理者ユーザーでログインしてください。
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader className="space-y-4">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <CardTitle className="text-base">スタッフ管理</CardTitle>
              <CardDescription>同一テナント内ユーザーのロールを変更できます。</CardDescription>
            </div>
            <div className="relative w-full lg:w-80">
              <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                className="rounded-xl pl-9"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="名前・メールで検索"
              />
            </div>
          </div>

          {user && (
            <div className="text-xs text-muted-foreground">
              ログイン中: <span className="font-medium">{user.name || user.email}</span>
            </div>
          )}
        </CardHeader>

        <CardContent>
          {adminUsersQuery.isPending && (
            <div className="space-y-2">
              {Array.from({ length: 6 }).map((_, index) => (
                <Skeleton key={index} className="h-12 w-full rounded-xl" />
              ))}
            </div>
          )}

          {adminUsersQuery.isError && !adminUsersQuery.isPending && (
            <Card className="rounded-2xl border-destructive/30">
              <CardContent className="p-8 text-center">
                <p className="font-medium">スタッフ一覧の取得に失敗しました</p>
                <p className="mt-1 text-sm text-muted-foreground">時間をおいて再試行してください。</p>
              </CardContent>
            </Card>
          )}

          {!adminUsersQuery.isPending && !adminUsersQuery.isError && filteredUsers.length === 0 && (
            <Card className="rounded-2xl border-dashed">
              <CardContent className="p-10 text-center">
                <p className="font-medium">対象ユーザーが見つかりません</p>
              </CardContent>
            </Card>
          )}

          {!adminUsersQuery.isPending && !adminUsersQuery.isError && filteredUsers.length > 0 && (
            <div className="overflow-hidden rounded-2xl border border-border/70 bg-card shadow-sm">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>名前</TableHead>
                    <TableHead>Email</TableHead>
                    <TableHead>現在ロール</TableHead>
                    <TableHead>変更</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredUsers.map((targetUser) => {
                    const currentRole = targetUser.role_names[0] ?? "";
                    const isSelf = targetUser.is_self;
                    const disabled = isSelf || updatingUserId === targetUser.id;

                    return (
                      <TableRow key={targetUser.id} className="transition-colors hover:bg-muted/40">
                        <TableCell className="font-medium">{targetUser.name || "-"}</TableCell>
                        <TableCell>{targetUser.email}</TableCell>
                        <TableCell>
                          <div className="flex flex-wrap gap-1">
                            {targetUser.role_names.map((roleName) => (
                              <Badge key={`${targetUser.id}-${roleName}`} variant="secondary" className="rounded-lg">
                                {roleName}
                              </Badge>
                            ))}
                          </div>
                        </TableCell>
                        <TableCell>
                          <TooltipProvider>
                            <Tooltip>
                              <TooltipTrigger asChild>
                                <div>
                                  <Select
                                    value={currentRole || undefined}
                                    onValueChange={(nextRole) => {
                                      void updateRoleMutation.mutateAsync({ userId: targetUser.id, roleName: nextRole });
                                    }}
                                    disabled={disabled}
                                  >
                                    <SelectTrigger className="w-56 rounded-xl">
                                      <SelectValue placeholder="ロールを選択" />
                                    </SelectTrigger>
                                    <SelectContent>
                                      {(adminUsersQuery.data?.roleOptions ?? []).map((roleOption) => (
                                        <SelectItem key={roleOption.name} value={roleOption.name}>
                                          {roleOption.label}
                                        </SelectItem>
                                      ))}
                                    </SelectContent>
                                  </Select>
                                </div>
                              </TooltipTrigger>
                              {isSelf && (
                                <TooltipContent>
                                  自分自身のAdminロールは外せないため変更できません。
                                </TooltipContent>
                              )}
                            </Tooltip>
                          </TooltipProvider>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
