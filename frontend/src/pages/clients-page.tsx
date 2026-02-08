import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Search } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { listClients } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ClientFormDialog } from "@/components/clients/client-form-dialog";
import {
  ClientsEmpty,
  ClientsTable,
  ClientsTableError,
  ClientsTableSkeleton,
} from "@/components/clients/clients-table";

export function ClientsPage() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<"all" | "active" | "inactive">("all");
  const { permissions } = useAuth();
  const canRead = permissions.includes("clients:read");
  const canManage = permissions.includes("clients:manage");
  const navigate = useNavigate();

  const clientsQuery = useQuery({
    queryKey: ["clients", search, status],
    queryFn: () => listClients({ q: search, status }),
    enabled: canRead,
  });

  if (!canRead) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardContent className="p-10 text-center">
          <p className="font-medium">権限がありません</p>
          <p className="mt-1 text-sm text-muted-foreground">clients:read 権限を持つユーザーでログインしてください。</p>
        </CardContent>
      </Card>
    );
  }

  const clients = clientsQuery.data?.clients ?? [];

  return (
    <div className="space-y-4">
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <CardTitle className="text-base">利用者</CardTitle>
            <CardDescription>利用者一覧の検索・管理</CardDescription>
          </div>

          <div className="grid w-full gap-2 sm:grid-cols-[1fr_180px_auto] lg:w-auto">
            <div className="relative min-w-[260px]">
              <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                className="rounded-xl pl-9"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="名前・かな・電話で検索"
              />
            </div>

            <Select value={status} onValueChange={(value) => setStatus(value as typeof status)}>
              <SelectTrigger className="rounded-xl">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">all</SelectItem>
                <SelectItem value="active">active</SelectItem>
                <SelectItem value="inactive">inactive</SelectItem>
              </SelectContent>
            </Select>

            <ClientFormDialog canManage={canManage} mode="create" />
          </div>
        </CardHeader>
        <CardContent>
          {clientsQuery.isPending && <ClientsTableSkeleton />}

          {clientsQuery.isError && !clientsQuery.isPending && (
            <ClientsTableError onRetry={() => clientsQuery.refetch()} />
          )}

          {!clientsQuery.isPending && !clientsQuery.isError && clients.length === 0 && (
            <ClientsEmpty canManage={canManage} />
          )}

          {!clientsQuery.isPending && !clientsQuery.isError && clients.length > 0 && (
            <ClientsTable clients={clients} onSelect={(client) => navigate(`/app/clients/${client.id}`)} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
