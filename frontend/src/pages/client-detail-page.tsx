import { useMemo } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { formatDistanceToNow } from "date-fns";
import { ja } from "date-fns/locale";
import { ArrowLeft } from "lucide-react";
import { getClient, listContracts } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import { ContractFormDialog } from "@/components/contracts/contract-form-dialog";
import { formatServices, formatWeekdays } from "@/components/contracts/contract-constants";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { ClientFormDialog } from "@/components/clients/client-form-dialog";
import { DeleteClientDialog } from "@/components/clients/delete-client-dialog";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export function ClientDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { permissions } = useAuth();

  const canReadClient = permissions.includes("clients:read");
  const canManageClient = permissions.includes("clients:manage");
  const canReadContracts = permissions.includes("contracts:read");
  const canManageContracts = permissions.includes("contracts:manage");

  const numericId = useMemo(() => Number(id), [id]);
  const isValidClientId = Number.isInteger(numericId) && numericId > 0;

  const clientQuery = useQuery({
    queryKey: ["client", numericId],
    queryFn: () => getClient(numericId),
    enabled: canReadClient && isValidClientId,
  });

  const contractsQuery = useQuery({
    queryKey: ["contracts", numericId],
    queryFn: () => listContracts(numericId),
    enabled: canReadContracts && isValidClientId,
  });

  if (!canReadClient) {
    return (
      <Card className="rounded-2xl">
        <CardContent className="p-8 text-center">
          <p className="font-medium">権限がありません</p>
          <p className="text-sm text-muted-foreground">clients:read 権限が必要です。</p>
        </CardContent>
      </Card>
    );
  }

  const contracts = contractsQuery.data?.contracts ?? [];

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
              <ClientFormDialog canManage={canManageClient} mode="edit" client={clientQuery.data} triggerLabel="編集" />
              <DeleteClientDialog
                id={clientQuery.data.id}
                canManage={canManageClient}
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

      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <CardTitle className="text-lg">契約 / 利用プラン</CardTitle>
            <CardDescription>改定履歴を新しい順で表示します。</CardDescription>
          </div>
          {canReadContracts && isValidClientId && (
            <ContractFormDialog
              clientId={numericId}
              canManage={canManageContracts}
              mode="create"
              triggerLabel="新規契約"
            />
          )}
        </CardHeader>

        <CardContent>
          {!canReadContracts && (
            <div className="rounded-2xl border border-dashed p-8 text-center">
              <p className="font-medium">権限がありません</p>
              <p className="text-sm text-muted-foreground">contracts:read 権限が必要です。</p>
            </div>
          )}

          {canReadContracts && contractsQuery.isPending && (
            <div className="space-y-2">
              {Array.from({ length: 4 }).map((_, index) => (
                <Skeleton key={index} className="h-12 w-full rounded-xl" />
              ))}
            </div>
          )}

          {canReadContracts && contractsQuery.isError && !contractsQuery.isPending && (
            <div className="space-y-3 rounded-2xl border border-destructive/30 p-8 text-center">
              <p className="font-medium">契約履歴の取得に失敗しました</p>
              <Button variant="outline" className="rounded-xl" onClick={() => contractsQuery.refetch()}>
                リトライ
              </Button>
            </div>
          )}

          {canReadContracts && !contractsQuery.isPending && !contractsQuery.isError && contracts.length === 0 && (
            <div className="rounded-2xl border border-dashed p-8 text-center">
              <p className="font-medium">契約/利用プランはまだ登録されていません</p>
              <p className="text-sm text-muted-foreground">必要に応じて「新規契約」から登録してください。</p>
            </div>
          )}

          {canReadContracts && !contractsQuery.isPending && !contractsQuery.isError && contracts.length > 0 && (
            <div className="overflow-hidden rounded-2xl border border-border/70">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>開始日</TableHead>
                    <TableHead>終了日</TableHead>
                    <TableHead>利用曜日</TableHead>
                    <TableHead>サービス</TableHead>
                    <TableHead>送迎</TableHead>
                    <TableHead>更新</TableHead>
                    <TableHead className="text-right">操作</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {contracts.map((contract) => {
                    const isCurrent = contractsQuery.data?.currentContractId === contract.id;

                    return (
                      <TableRow key={contract.id} className={isCurrent ? "bg-primary/5" : undefined}>
                        <TableCell className="font-medium">{contract.start_on}</TableCell>
                        <TableCell>{contract.end_on || "継続中"}</TableCell>
                        <TableCell>{formatWeekdays(contract.weekdays)}</TableCell>
                        <TableCell>
                          <div className="space-y-1">
                            <p>{formatServices(contract.services)}</p>
                            {contract.service_note && (
                              <p className="text-xs text-muted-foreground">{contract.service_note}</p>
                            )}
                          </div>
                        </TableCell>
                        <TableCell>
                          <div className="space-y-1">
                            <p>{contract.shuttle_required ? "あり" : "なし"}</p>
                            {contract.shuttle_note && (
                              <p className="text-xs text-muted-foreground">{contract.shuttle_note}</p>
                            )}
                          </div>
                        </TableCell>
                        <TableCell className="text-muted-foreground">
                          {formatDistanceToNow(new Date(contract.updated_at), { addSuffix: true, locale: ja })}
                        </TableCell>
                        <TableCell className="text-right">
                          <ContractFormDialog
                            clientId={numericId}
                            canManage={canManageContracts}
                            mode="edit"
                            contract={contract}
                            triggerLabel="編集"
                          />
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
