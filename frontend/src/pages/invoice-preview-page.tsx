import { Link, useNavigate, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, Printer } from "lucide-react";
import { getInvoice, type ApiError } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Separator } from "@/components/ui/separator";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency: "JPY",
    maximumFractionDigits: 0,
  }).format(value);
}

function formatDate(value: string): string {
  return new Date(value).toLocaleDateString("ja-JP", {
    dateStyle: "medium",
  });
}

function formatQuantity(value: number): string {
  if (Number.isInteger(value)) return String(value);
  return value.toFixed(2);
}

function formatCopaymentRate(rate: number): string {
  return `${Math.round(rate * 10)}割`;
}

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

export function InvoicePreviewPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { permissions } = useAuth();
  const canReadInvoices = permissions.includes("invoices:read");

  const invoiceQuery = useQuery({
    queryKey: ["invoice", id],
    queryFn: () => {
      if (!id) throw new Error("invalid invoice id");
      return getInvoice(id);
    },
    enabled: canReadInvoices && Boolean(id),
  });

  const invoice = invoiceQuery.data?.invoice;
  const invoiceLines = invoiceQuery.data?.invoiceLines ?? [];

  const monthLabel = (() => {
    if (!invoice?.billing_month) return "-";
    const [year, month] = invoice.billing_month.split("-").map(Number);
    if (!year || !month) return invoice.billing_month;

    return `${year}年${month}月`;
  })();

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

  if (invoiceQuery.isPending) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader>
          <CardTitle>請求書プレビュー</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <Skeleton className="h-10 w-56 rounded-xl" />
          <Skeleton className="h-10 w-full rounded-xl" />
          <Skeleton className="h-64 w-full rounded-xl" />
        </CardContent>
      </Card>
    );
  }

  if (invoiceQuery.isError || !invoice) {
    return (
      <Card className="rounded-2xl border-destructive/30 shadow-sm">
        <CardContent className="space-y-3 p-8 text-center">
          <p className="font-medium">請求書データの取得に失敗しました</p>
          <p className="text-sm text-muted-foreground">
            {formatApiError(invoiceQuery.error, "時間をおいて再度お試しください")}
          </p>
          <div className="flex justify-center gap-2">
            <Button variant="outline" className="rounded-xl" onClick={() => invoiceQuery.refetch()}>
              リトライ
            </Button>
            <Button variant="ghost" className="rounded-xl" onClick={() => navigate("/app/invoices")}>戻る</Button>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4 print:space-y-0">
      <div className="flex flex-wrap items-center justify-between gap-2 print:hidden">
        <Button asChild variant="outline" className="rounded-xl">
          <Link to="/app/invoices">
            <ArrowLeft className="mr-2 size-4" />
            一覧へ戻る
          </Link>
        </Button>
        <Button className="rounded-xl" onClick={() => window.print()}>
          <Printer className="mr-2 size-4" />
          請求書を出力（印刷）
        </Button>
      </div>

      <Card className="rounded-2xl border-border/70 shadow-sm print:rounded-none print:border-0 print:shadow-none">
        <CardHeader className="space-y-2 print:px-0 print:pt-0">
          <CardTitle className="text-xl">請求書プレビュー</CardTitle>
          <CardDescription>
            請求ID: {invoice.id}
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-6 print:px-0 print:pb-0">
          <section className="grid gap-4 rounded-xl border border-border/70 bg-muted/30 p-4 print:border print:bg-transparent">
            <div className="grid gap-1">
              <p className="text-sm text-muted-foreground">宛名</p>
              <p className="text-lg font-semibold">{invoice.client_name || "-"} 様</p>
            </div>
            <div className="grid gap-1 sm:grid-cols-2">
              <div>
                <p className="text-sm text-muted-foreground">請求年月</p>
                <p className="font-medium">{monthLabel}</p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground">請求日</p>
                <p className="font-medium">{formatDate(invoice.updated_at)}</p>
              </div>
            </div>
          </section>

          <section className="rounded-xl border border-border/70 p-4 print:border">
            <p className="text-sm text-muted-foreground">請求金額（利用者負担額）</p>
            <p className="mt-2 text-4xl font-bold tracking-tight">{formatCurrency(invoice.copayment_amount)}</p>
            <p className="mt-1 text-xs text-muted-foreground">
              負担割合: {formatCopaymentRate(invoice.copayment_rate)}
            </p>
          </section>

          <section className="rounded-xl border border-border/70 p-4 print:border">
            <h3 className="text-sm font-semibold">内訳</h3>
            <div className="mt-3 space-y-2 text-sm">
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">総費用（保険内）</span>
                <span className="font-medium">{formatCurrency(invoice.subtotal_amount)}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">保険請求分</span>
                <span className="font-medium">{formatCurrency(invoice.insurance_claim_amount)}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">自己負担分（保険内）</span>
                <span className="font-medium">{formatCurrency(invoice.insured_copayment_amount)}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">自己負担分（超過）</span>
                <span className="font-medium">{formatCurrency(invoice.excess_copayment_amount)}</span>
              </div>
              <Separator className="my-2" />
              <div className="flex items-center justify-between text-base font-semibold">
                <span>最終請求額</span>
                <span>{formatCurrency(invoice.copayment_amount)}</span>
              </div>
            </div>
          </section>

          <section className="rounded-xl border border-border/70 p-4 print:border">
            <h3 className="mb-3 text-sm font-semibold">明細</h3>
            <div className="overflow-hidden rounded-xl border border-border/70">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>日付</TableHead>
                    <TableHead>項目</TableHead>
                    <TableHead className="text-right">単位数</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {invoiceLines.map((line) => (
                    <TableRow key={line.id}>
                      <TableCell>{line.service_date}</TableCell>
                      <TableCell>{line.item_name}</TableCell>
                      <TableCell className="text-right">{formatQuantity(line.units)} 単位</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </section>
        </CardContent>
      </Card>
    </div>
  );
}
