import { formatDistanceToNow } from "date-fns";
import { ja } from "date-fns/locale";
import type { Client } from "@/types/client";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { cn } from "@/lib/utils";

export function ClientsTableSkeleton() {
  return (
    <div className="space-y-2">
      {Array.from({ length: 6 }).map((_, index) => (
        <Skeleton key={index} className="h-12 w-full rounded-xl" />
      ))}
    </div>
  );
}

export function ClientsTableError({ onRetry }: { onRetry: () => void }) {
  return (
    <Card className="rounded-2xl border-destructive/30">
      <CardContent className="flex flex-col items-center gap-3 p-8 text-center">
        <p className="font-medium">利用者一覧の取得に失敗しました</p>
        <p className="text-sm text-muted-foreground">認証状態か通信状態を確認してください。</p>
        <Button variant="outline" className="rounded-xl" onClick={onRetry}>
          リトライ
        </Button>
      </CardContent>
    </Card>
  );
}

export function ClientsEmpty({ canManage }: { canManage: boolean }) {
  return (
    <Card className="rounded-2xl border-dashed">
      <CardContent className="p-10 text-center">
        <p className="font-medium">利用者がいません</p>
        <p className="mt-1 text-sm text-muted-foreground">
          {canManage ? "右上の「新規利用者」から追加できます。" : "登録待ちです。"}
        </p>
      </CardContent>
    </Card>
  );
}

export function ClientsTable({
  clients,
  onSelect,
}: {
  clients: Client[];
  onSelect: (client: Client) => void;
}) {
  return (
    <div className="overflow-hidden rounded-2xl border border-border/70 bg-card shadow-sm">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>名前</TableHead>
            <TableHead>電話</TableHead>
            <TableHead>ステータス</TableHead>
            <TableHead className="text-right">更新</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {clients.map((client) => (
            <TableRow
              key={client.id}
              className="cursor-pointer transition-colors hover:bg-muted/40"
              onClick={() => onSelect(client)}
            >
              <TableCell className="font-medium">
                <div>
                  <p>{client.name}</p>
                  <p className="text-xs text-muted-foreground">{client.kana || "-"}</p>
                </div>
              </TableCell>
              <TableCell>{client.phone || "-"}</TableCell>
              <TableCell>
                <Badge
                  variant="secondary"
                  className={cn(
                    "rounded-lg",
                    client.status === "active" ? "bg-emerald-100 text-emerald-700" : "bg-zinc-200 text-zinc-700",
                  )}
                >
                  {client.status}
                </Badge>
              </TableCell>
              <TableCell className="text-right text-muted-foreground">
                {formatDistanceToNow(new Date(client.updated_at), { addSuffix: true, locale: ja })}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
