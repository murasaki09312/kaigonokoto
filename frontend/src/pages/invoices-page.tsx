import { useMemo, useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { ja } from "date-fns/locale";
import { FileSpreadsheet, Loader2 } from "lucide-react";
import { Link } from "react-router-dom";
import { toast } from "sonner";
import { generateInvoices, listInvoices, type ApiError } from "@/lib/api";
import type { Invoice } from "@/types/invoice";
import { useAuth } from "@/providers/auth-provider";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { cn } from "@/lib/utils";

function currentMonthKey(): string {
  return format(new Date(), "yyyy-MM");
}

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

function invoiceStatusLabel(status: Invoice["status"]): string {
  if (status === "fixed") return "確定";
  return "下書き";
}

function invoiceStatusClass(status: Invoice["status"]): string {
  if (status === "fixed") return "bg-emerald-100 text-emerald-700";
  return "bg-zinc-100 text-zinc-700";
}

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency: "JPY",
    maximumFractionDigits: 0,
  }).format(value);
}

function formatGeneratedAt(value: string | null): string {
  if (!value) return "-";

  return new Date(value).toLocaleString("ja-JP", {
    dateStyle: "short",
    timeStyle: "short",
  });
}

export function InvoicesPage() {
  const { permissions } = useAuth();
  const canReadInvoices = permissions.includes("invoices:read");
  const canManageInvoices = permissions.includes("invoices:manage");

  const [month, setMonth] = useState(currentMonthKey());

  const invoicesQuery = useQuery({
    queryKey: ["invoices", month],
    queryFn: () => listInvoices({ month }),
    enabled: canReadInvoices,
  });

  const generateMutation = useMutation({
    mutationFn: (mode: "replace" | "skip") => generateInvoices({ month, mode }),
    onSuccess: async (result) => {
      const messages: string[] = [];
      messages.push(`${result.generated}件を生成`);
      if (result.replaced > 0) messages.push(`${result.replaced}件を再生成`);
      if (result.skippedExisting > 0) messages.push(`${result.skippedExisting}件を既存のためスキップ`);
      if (result.skippedFixed > 0) messages.push(`${result.skippedFixed}件を確定済みのためスキップ`);
      toast.success(messages.join(" / "));
      await invoicesQuery.refetch();
    },
    onError: (error) => {
      toast.error(formatApiError(error, "請求データの生成に失敗しました"));
    },
  });

  const invoices = invoicesQuery.data?.invoices ?? [];
  const monthLabel = useMemo(() => {
    const [year, monthValue] = month.split("-").map((value) => Number(value));
    if (!year || !monthValue) return month;
    return format(new Date(year, monthValue - 1, 1), "yyyy年M月", { locale: ja });
  }, [month]);

  if (!canReadInvoices) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardContent className="p-10 text-center">
          <p className="font-medium">権限がありません</p>
          <p className="mt-1 text-sm text-muted-foreground">
            invoices:read 権限を持つユーザーでログインしてください。
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader className="space-y-4">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <CardTitle className="text-base">請求</CardTitle>
              <CardDescription>月次の利用実績（出席）から請求データを自動生成します。</CardDescription>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <Input
                type="month"
                value={month}
                onChange={(event) => setMonth(event.target.value)}
                className="w-44 rounded-xl"
              />
              <Button
                type="button"
                className="rounded-xl"
                disabled={!canManageInvoices || generateMutation.isPending}
                onClick={() => generateMutation.mutate("replace")}
              >
                {generateMutation.isPending ? <Loader2 className="mr-2 size-4 animate-spin" /> : <FileSpreadsheet className="mr-2 size-4" />}
                一括生成
              </Button>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
            <Badge variant="secondary" className="rounded-lg">
              対象月: {monthLabel}
            </Badge>
            <Badge variant="outline" className="rounded-lg">
              件数: {invoicesQuery.data?.total ?? 0}
            </Badge>
            <Badge variant="outline" className="rounded-lg">
              合計: {formatCurrency(invoicesQuery.data?.totalAmount ?? 0)}
            </Badge>
          </div>
        </CardHeader>

        <CardContent>
          {invoicesQuery.isPending && (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, index) => (
                <Skeleton key={index} className="h-12 w-full rounded-xl" />
              ))}
            </div>
          )}

          {invoicesQuery.isError && !invoicesQuery.isPending && (
            <Card className="rounded-2xl border-destructive/30">
              <CardContent className="space-y-3 p-8 text-center">
                <p className="font-medium">請求データの取得に失敗しました</p>
                <Button variant="outline" className="rounded-xl" onClick={() => invoicesQuery.refetch()}>
                  リトライ
                </Button>
              </CardContent>
            </Card>
          )}

          {!invoicesQuery.isPending && !invoicesQuery.isError && invoices.length === 0 && (
            <Card className="rounded-2xl border-dashed">
              <CardContent className="p-10 text-center">
                <p className="font-medium">この月の請求データはありません</p>
                <p className="mt-1 text-sm text-muted-foreground">
                  {canManageInvoices ? "一括生成を実行して作成してください。" : "管理権限を持つユーザーに生成を依頼してください。"}
                </p>
              </CardContent>
            </Card>
          )}

          {!invoicesQuery.isPending && !invoicesQuery.isError && invoices.length > 0 && (
            <div className="overflow-hidden rounded-2xl border border-border/70">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>利用者</TableHead>
                    <TableHead>対象月</TableHead>
                    <TableHead>明細数</TableHead>
                    <TableHead>ステータス</TableHead>
                    <TableHead>合計金額</TableHead>
                    <TableHead>生成日時</TableHead>
                    <TableHead className="text-right">操作</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {invoices.map((invoice) => (
                    <TableRow key={invoice.id}>
                      <TableCell className="font-medium">{invoice.client_name || "-"}</TableCell>
                      <TableCell>{invoice.billing_month}</TableCell>
                      <TableCell>{invoice.line_count ?? 0}</TableCell>
                      <TableCell>
                        <Badge variant="secondary" className={cn("rounded-lg", invoiceStatusClass(invoice.status))}>
                          {invoiceStatusLabel(invoice.status)}
                        </Badge>
                      </TableCell>
                      <TableCell>{formatCurrency(invoice.total_amount)}</TableCell>
                      <TableCell>{formatGeneratedAt(invoice.generated_at)}</TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-2">
                          <Button asChild variant="outline" size="sm" className="rounded-lg">
                            <Link to={`/app/invoices/${invoice.id}`}>請求書</Link>
                          </Button>
                          <Button asChild variant="outline" size="sm" className="rounded-lg">
                            <Link to={`/app/invoices/${invoice.id}/receipt`}>レセプト</Link>
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
