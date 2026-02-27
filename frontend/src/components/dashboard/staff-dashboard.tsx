import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { ClipboardCheck, Clock3, Megaphone, MessageSquareText } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { getTodayBoard } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

function toHandoffSummary(value: string): string {
  const normalized = value.trim().replace(/\s+/g, " ");
  return normalized.length > 64 ? `${normalized.slice(0, 64)}...` : normalized;
}

export function StaffDashboard() {
  const navigate = useNavigate();
  const { permissions } = useAuth();
  const targetDate = format(new Date(), "yyyy-MM-dd");
  const canReadTodayBoard = permissions.includes("today_board:read");

  const boardQuery = useQuery({
    queryKey: ["staff-dashboard", "today-board", targetDate],
    queryFn: () => getTodayBoard({ date: targetDate }),
    enabled: canReadTodayBoard,
  });

  const summary = useMemo(() => {
    const items = boardQuery.data?.items ?? [];
    const handoffItems = items
      .filter((item) => Boolean(item.care_record?.handoff_note?.trim()))
      .map((item) => ({
        reservationId: item.reservation.id,
        clientName: item.reservation.client_name ?? "名称未設定",
        note: toHandoffSummary(item.care_record?.handoff_note ?? ""),
      }));

    return {
      total: boardQuery.data?.meta.total ?? 0,
      attendancePending: boardQuery.data?.meta.attendance_counts.pending ?? 0,
      recordPending: boardQuery.data?.meta.care_record_pending ?? 0,
      handoffItems,
    };
  }, [boardQuery.data]);

  if (!canReadTodayBoard) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardContent className="p-10 text-center">
          <p className="font-medium">権限がありません</p>
          <p className="mt-1 text-sm text-muted-foreground">
            today_board:read 権限を持つユーザーでログインしてください。
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <section className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="rounded-2xl border-border/70 shadow-sm">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <ClipboardCheck className="size-4" />
              記録未完了
            </CardTitle>
          </CardHeader>
          <CardContent>
            {boardQuery.isPending ? (
              <Skeleton className="h-8 w-16" />
            ) : (
              <div className="text-3xl font-semibold tracking-tight">{summary.recordPending}</div>
            )}
            <p className="mt-1 text-xs text-muted-foreground">本日のケア記録待ち</p>
            <Button
              variant="outline"
              size="sm"
              className="mt-3 rounded-lg"
              onClick={() => navigate("/app/records?tab=unrecorded")}
            >
              未記録を開く
            </Button>
          </CardContent>
        </Card>

        <Card className="rounded-2xl border-border/70 shadow-sm">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <Clock3 className="size-4" />
              未出欠
            </CardTitle>
          </CardHeader>
          <CardContent>
            {boardQuery.isPending ? (
              <Skeleton className="h-8 w-16" />
            ) : (
              <div className="text-3xl font-semibold tracking-tight">{summary.attendancePending}</div>
            )}
            <p className="mt-1 text-xs text-muted-foreground">出欠入力待ち</p>
            <Button
              variant="outline"
              size="sm"
              className="mt-3 rounded-lg"
              onClick={() => navigate("/app/today-board?filter=attendance_pending")}
            >
              当日ボードを開く
            </Button>
          </CardContent>
        </Card>

        <Card className="rounded-2xl border-border/70 shadow-sm">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
              <Megaphone className="size-4" />
              申し送り
            </CardTitle>
          </CardHeader>
          <CardContent>
            {boardQuery.isPending ? (
              <Skeleton className="h-8 w-16" />
            ) : (
              <div className="text-3xl font-semibold tracking-tight">{summary.handoffItems.length}</div>
            )}
            <p className="mt-1 text-xs text-muted-foreground">本日の特記事項</p>
            <Badge variant="secondary" className="mt-3 rounded-lg">
              対象者 {summary.total} 名
            </Badge>
          </CardContent>
        </Card>
      </section>

      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base">
            <MessageSquareText className="size-4" />
            現場の特記事項（申し送り）
          </CardTitle>
          <CardDescription>連絡メモを優先度順に確認し、記録画面へすぐに遷移できます。</CardDescription>
        </CardHeader>

        <CardContent className="space-y-3">
          {boardQuery.isPending && (
            <div className="space-y-2">
              {Array.from({ length: 4 }).map((_, index) => (
                <Skeleton key={index} className="h-14 w-full" />
              ))}
            </div>
          )}

          {!boardQuery.isPending && summary.handoffItems.length === 0 && (
            <div className="rounded-xl border border-dashed p-8 text-center">
              <p className="font-medium">申し送りはありません</p>
              <p className="mt-1 text-sm text-muted-foreground">記録画面で入力するとここに表示されます。</p>
            </div>
          )}

          {summary.handoffItems.map((item) => (
            <button
              key={item.reservationId}
              type="button"
              className="w-full rounded-xl border border-border/70 p-3 text-left transition-colors hover:bg-muted/60"
              onClick={() => navigate("/app/records")}
            >
              <p className="text-sm font-semibold">{item.clientName}</p>
              <p className="mt-1 text-sm text-muted-foreground">{item.note}</p>
            </button>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}
