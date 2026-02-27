import { formatDistanceToNow } from "date-fns";
import { ja } from "date-fns/locale";
import type { User } from "@/types/auth";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

export function UsersTableSkeleton() {
  return (
    <div className="space-y-2">
      {Array.from({ length: 6 }).map((_, index) => (
        <Skeleton key={index} className="h-12 w-full rounded-xl" />
      ))}
    </div>
  );
}

export function UsersTableError({ onRetry }: { onRetry: () => void }) {
  return (
    <Card className="rounded-2xl border-destructive/30">
      <CardContent className="flex flex-col items-center gap-3 p-8 text-center">
        <p className="font-medium">ユーザー一覧の取得に失敗しました</p>
        <p className="text-sm text-muted-foreground">ネットワーク状態か認証状態を確認してください。</p>
        <Button variant="outline" className="rounded-xl" onClick={onRetry}>
          リトライ
        </Button>
      </CardContent>
    </Card>
  );
}

export function UsersTableEmpty({ query }: { query: string }) {
  return (
    <Card className="rounded-2xl border-dashed">
      <CardContent className="p-10 text-center">
        <p className="font-medium">ユーザーが見つかりません</p>
        <p className="mt-1 text-sm text-muted-foreground">
          {query ? `「${query}」に一致するユーザーがありません。` : "まだユーザーが登録されていません。"}
        </p>
      </CardContent>
    </Card>
  );
}

export function UsersTable({ users }: { users: User[] }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-border/70 bg-card shadow-sm">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Email</TableHead>
            <TableHead>スタッフ権限</TableHead>
            <TableHead className="text-right">Updated</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {users.map((user) => (
            <TableRow key={user.id} className="transition-colors hover:bg-muted/40">
              <TableCell className="font-medium">{user.name || "-"}</TableCell>
              <TableCell>{user.email}</TableCell>
              <TableCell>{user.roles?.map((role) => role.label).join(" / ") || "—"}</TableCell>
              <TableCell className="text-right text-muted-foreground">
                {formatDistanceToNow(new Date(user.updated_at), { addSuffix: true, locale: ja })}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
