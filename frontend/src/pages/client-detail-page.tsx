import { useMemo } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { getClient } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { ClientFormDialog } from "@/components/clients/client-form-dialog";
import { DeleteClientDialog } from "@/components/clients/delete-client-dialog";

export function ClientDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { permissions } = useAuth();
  const canRead = permissions.includes("clients:read");
  const canManage = permissions.includes("clients:manage");

  const numericId = useMemo(() => Number(id), [id]);

  const clientQuery = useQuery({
    queryKey: ["client", numericId],
    queryFn: () => getClient(numericId),
    enabled: canRead && Number.isInteger(numericId) && numericId > 0,
  });

  if (!canRead) {
    return (
      <Card className="rounded-2xl">
        <CardContent className="p-8 text-center">
          <p className="font-medium">権限がありません</p>
          <p className="text-sm text-muted-foreground">clients:read 権限が必要です。</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <Button variant="ghost" className="rounded-xl" onClick={() => navigate("/app/clients")}>
        <ArrowLeft className="mr-2 size-4" /> 一覧に戻る
      </Button>

      {clientQuery.isPending && (
        <Card className="rounded-2xl">
          <CardContent className="space-y-3 p-6">
            <Skeleton className="h-6 w-40" />
            <Skeleton className="h-4 w-80" />
            <Skeleton className="h-32 w-full" />
          </CardContent>
        </Card>
      )}

      {clientQuery.isError && !clientQuery.isPending && (
        <Card className="rounded-2xl">
          <CardContent className="space-y-3 p-8 text-center">
            <p className="font-medium">利用者の取得に失敗しました</p>
            <Button variant="outline" className="rounded-xl" onClick={() => clientQuery.refetch()}>
              リトライ
            </Button>
          </CardContent>
        </Card>
      )}

      {clientQuery.data && (
        <Card className="rounded-2xl border-border/70 shadow-sm">
          <CardHeader className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <CardTitle className="text-xl">{clientQuery.data.name}</CardTitle>
              <CardDescription>{clientQuery.data.kana || "かな未設定"}</CardDescription>
            </div>
            <div className="flex items-center gap-2">
              <Badge variant="secondary" className="rounded-lg">
                {clientQuery.data.status}
              </Badge>
              <ClientFormDialog canManage={canManage} mode="edit" client={clientQuery.data} triggerLabel="編集" />
              <DeleteClientDialog
                id={clientQuery.data.id}
                canManage={canManage}
                onDeleted={() => navigate("/app/clients", { replace: true })}
              />
            </div>
          </CardHeader>
          <CardContent>
            <dl className="grid gap-4 md:grid-cols-2">
              <div>
                <dt className="text-sm text-muted-foreground">電話</dt>
                <dd className="font-medium">{clientQuery.data.phone || "-"}</dd>
              </div>
              <div>
                <dt className="text-sm text-muted-foreground">性別</dt>
                <dd className="font-medium">{clientQuery.data.gender}</dd>
              </div>
              <div>
                <dt className="text-sm text-muted-foreground">住所</dt>
                <dd className="font-medium">{clientQuery.data.address || "-"}</dd>
              </div>
              <div>
                <dt className="text-sm text-muted-foreground">緊急連絡先</dt>
                <dd className="font-medium">
                  {clientQuery.data.emergency_contact_name || "-"}
                  {clientQuery.data.emergency_contact_phone ? ` / ${clientQuery.data.emergency_contact_phone}` : ""}
                </dd>
              </div>
              <div className="md:col-span-2">
                <dt className="text-sm text-muted-foreground">備考</dt>
                <dd className="whitespace-pre-wrap font-medium">{clientQuery.data.notes || "-"}</dd>
              </div>
            </dl>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
