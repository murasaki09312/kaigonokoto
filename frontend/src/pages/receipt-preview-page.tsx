import { Link, useNavigate, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, Download, Printer } from "lucide-react";
import { toast } from "sonner";
import { downloadInvoiceReceiptCsv, getInvoiceReceipt, type ApiError } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

function formatUnits(value: number): string {
  return new Intl.NumberFormat("ja-JP", {
    maximumFractionDigits: 0,
  }).format(value);
}

export function ReceiptPreviewPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { permissions } = useAuth();
  const canReadInvoices = permissions.includes("invoices:read");

  const receiptQuery = useQuery({
    queryKey: ["invoice-receipt", id],
    queryFn: () => {
      if (!id) throw new Error("invalid invoice id");
      return getInvoiceReceipt(id);
    },
    enabled: canReadInvoices && Boolean(id),
  });

  const invoice = receiptQuery.data?.invoice;
  const receiptItems = receiptQuery.data?.receiptItems ?? [];
  const totalUnits = receiptQuery.data?.totalUnits ?? 0;

  const handleDownloadCsv = async () => {
    if (!id) return;

    try {
      const { blob, filename } = await downloadInvoiceReceiptCsv(id);
      const url = window.URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = filename;
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      window.URL.revokeObjectURL(url);
      toast.success("伝送CSVをダウンロードしました");
    } catch (error) {
      toast.error(formatApiError(error, "伝送CSVのダウンロードに失敗しました"));
    }
  };

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

  if (receiptQuery.isPending) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader>
          <CardTitle>国保連レセプトプレビュー</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <Skeleton className="h-10 w-56 rounded-xl" />
          <Skeleton className="h-10 w-full rounded-xl" />
          <Skeleton className="h-64 w-full rounded-xl" />
        </CardContent>
      </Card>
    );
  }

  if (receiptQuery.isError || !invoice) {
    return (
      <Card className="rounded-2xl border-destructive/30 shadow-sm">
        <CardContent className="space-y-3 p-8 text-center">
          <p className="font-medium">レセプトデータの取得に失敗しました</p>
          <p className="text-sm text-muted-foreground">
            {formatApiError(receiptQuery.error, "時間をおいて再度お試しください")}
          </p>
          <div className="flex justify-center gap-2">
            <Button variant="outline" className="rounded-xl" onClick={() => receiptQuery.refetch()}>
              リトライ
            </Button>
            <Button variant="ghost" className="rounded-xl" onClick={() => navigate(`/app/invoices/${id}`)}>
              請求書へ戻る
            </Button>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4 print:space-y-0">
      <div className="flex flex-wrap items-center justify-between gap-2 print:hidden">
        <div className="flex flex-wrap items-center gap-2">
          <Button asChild variant="outline" className="rounded-xl">
            <Link to={`/app/invoices/${invoice.id}`}>
              <ArrowLeft className="mr-2 size-4" />
              請求書へ戻る
            </Link>
          </Button>
          <Button variant="outline" className="rounded-xl" onClick={handleDownloadCsv}>
            <Download className="mr-2 size-4" />
            伝送CSVダウンロード
          </Button>
        </div>
        <Button className="rounded-xl" onClick={() => window.print()}>
          <Printer className="mr-2 size-4" />
          レセプトを出力（印刷）
        </Button>
      </div>

      <Card className="rounded-2xl border-border/70 shadow-sm print:rounded-none print:border-0 print:shadow-none">
        <CardHeader className="space-y-2 print:px-0 print:pt-0">
          <CardTitle className="text-xl">国保連レセプトプレビュー</CardTitle>
          <CardDescription>
            請求ID: {invoice.id} / 利用者: {invoice.client_name || "-"}
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-6 print:px-0 print:pb-0">
          <section className="rounded-xl border border-border/70 p-4 print:border">
            <div className="overflow-hidden rounded-xl border border-border/70">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>サービスコード</TableHead>
                    <TableHead>サービス内容</TableHead>
                    <TableHead className="text-right">単位数</TableHead>
                    <TableHead className="text-right">回数</TableHead>
                    <TableHead className="text-right">サービス単位数</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {receiptItems.map((item) => (
                    <TableRow key={item.service_code}>
                      <TableCell className="font-mono">{item.service_code}</TableCell>
                      <TableCell>{item.name || "-"}</TableCell>
                      <TableCell className="text-right">{formatUnits(item.unit_score)}</TableCell>
                      <TableCell className="text-right">{item.count}</TableCell>
                      <TableCell className="text-right">{formatUnits(item.total_units)}</TableCell>
                    </TableRow>
                  ))}
                  {receiptItems.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={5} className="py-10 text-center text-sm text-muted-foreground">
                        レセプト明細がありません
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </div>
          </section>

          <section className="rounded-xl border border-border/70 p-4 print:border">
            <p className="text-sm text-muted-foreground">合計単位数（月間総単位数）</p>
            <p className="mt-2 text-4xl font-bold tracking-tight">{formatUnits(totalUnits)} 単位</p>
          </section>
        </CardContent>
      </Card>
    </div>
  );
}
