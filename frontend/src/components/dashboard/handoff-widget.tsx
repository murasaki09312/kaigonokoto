import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { format, parseISO } from "date-fns";
import { AlertTriangle, Clock3, ExternalLink, MessageSquareText, RefreshCw } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { getDashboardHandoffs } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import type { DashboardHandoffItem } from "@/types/dashboard-handoff";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";

function formatHandoffTimestamp(value: string): string {
  return format(parseISO(value), "M/d HH:mm");
}

export function HandoffWidget() {
  const navigate = useNavigate();
  const { permissions } = useAuth();
  const [selectedHandoff, setSelectedHandoff] = useState<DashboardHandoffItem | null>(null);
  const canReadTodayBoard = permissions.includes("today_board:read");

  const handoffQuery = useQuery({
    queryKey: ["dashboard", "handoffs"],
    queryFn: getDashboardHandoffs,
    enabled: canReadTodayBoard,
  });

  const newThresholdHours = handoffQuery.data?.meta.new_threshold_hours ?? 6;
  const handoffs = handoffQuery.data?.handoffs ?? [];
  const hasItems = handoffs.length > 0;

  const selectedMeta = useMemo(() => {
    if (!selectedHandoff) return null;

    return {
      timestamp: formatHandoffTimestamp(selectedHandoff.created_at),
      recordedBy: selectedHandoff.recorded_by_user_name ?? "記録者不明",
    };
  }, [selectedHandoff]);

  if (!canReadTodayBoard) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader>
          <CardTitle className="text-base">今日の特記事項・申し送り</CardTitle>
          <CardDescription>申し送りの共有には today_board:read 権限が必要です。</CardDescription>
        </CardHeader>
      </Card>
    );
  }

  return (
    <>
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <div>
              <CardTitle className="text-base">今日の特記事項・申し送り</CardTitle>
              <CardDescription>直近24時間の申し送りを新着順で表示しています。</CardDescription>
            </div>
            <Badge variant="secondary" className="rounded-lg">
              New判定 {newThresholdHours} 時間以内
            </Badge>
          </div>
        </CardHeader>

        <CardContent className="space-y-3">
          {handoffQuery.isPending && (
            <div className="space-y-2">
              {Array.from({ length: 4 }).map((_, index) => (
                <Skeleton key={index} className="h-20 w-full" />
              ))}
            </div>
          )}

          {!handoffQuery.isPending && handoffQuery.isError && (
            <div className="rounded-xl border border-dashed p-6 text-center">
              <p className="font-medium">申し送りの取得に失敗しました</p>
              <p className="mt-1 text-sm text-muted-foreground">ネットワーク状態を確認して再試行してください。</p>
              <Button
                variant="outline"
                size="sm"
                className="mt-3 rounded-lg"
                onClick={() => handoffQuery.refetch()}
              >
                <RefreshCw className="mr-1 size-4" />
                再読み込み
              </Button>
            </div>
          )}

          {!handoffQuery.isPending && !handoffQuery.isError && !hasItems && (
            <div className="rounded-xl border border-dashed p-6 text-center">
              <p className="font-medium">申し送りはまだありません</p>
              <p className="mt-1 text-sm text-muted-foreground">記録画面で申し送りを入力するとここに表示されます。</p>
            </div>
          )}

          {!handoffQuery.isPending && !handoffQuery.isError && hasItems && handoffs.map((handoff) => (
            <button
              key={handoff.care_record_id}
              type="button"
              onClick={() => setSelectedHandoff(handoff)}
              className="w-full rounded-xl border border-border/70 p-3 text-left transition-colors hover:bg-muted/60"
            >
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="flex min-w-0 items-center gap-2">
                  <p className="text-sm font-semibold">{handoff.client_name}</p>
                  {handoff.is_new && (
                    <Badge className="rounded-full bg-red-500 px-2 py-0 text-[10px] font-semibold text-white hover:bg-red-500">
                      New
                    </Badge>
                  )}
                </div>
                <p className="flex items-center gap-1 text-xs text-muted-foreground">
                  <Clock3 className="size-3.5" />
                  {formatHandoffTimestamp(handoff.created_at)}
                </p>
              </div>

              <p className="mt-1 text-xs text-muted-foreground">記録者: {handoff.recorded_by_user_name ?? "記録者不明"}</p>
              <p className="mt-2 line-clamp-2 text-sm text-foreground">{handoff.handoff_note}</p>
            </button>
          ))}

          {!handoffQuery.isPending && !handoffQuery.isError && hasItems && (
            <div className="pt-1">
              <Button
                variant="outline"
                size="sm"
                className="rounded-lg"
                onClick={() => navigate("/app/records")}
              >
                <MessageSquareText className="mr-1 size-4" />
                記録画面で確認する
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      <Dialog open={selectedHandoff !== null} onOpenChange={(open) => !open && setSelectedHandoff(null)}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              {selectedHandoff?.client_name}
              {selectedHandoff?.is_new && (
                <Badge className="rounded-full bg-red-500 px-2 py-0 text-[10px] font-semibold text-white hover:bg-red-500">
                  New
                </Badge>
              )}
            </DialogTitle>
            <DialogDescription>
              {selectedMeta ? `${selectedMeta.recordedBy} / ${selectedMeta.timestamp}` : ""}
            </DialogDescription>
          </DialogHeader>

          {selectedHandoff ? (
            <div className="rounded-lg border border-border/70 bg-muted/20 p-3 text-sm leading-relaxed">
              {selectedHandoff.handoff_note}
            </div>
          ) : (
            <div className="rounded-lg border border-dashed p-3 text-sm text-muted-foreground">
              <AlertTriangle className="mr-1 inline size-4" />
              申し送りを読み込めませんでした
            </div>
          )}

          <DialogFooter>
            <Button variant="outline" className="rounded-lg" onClick={() => setSelectedHandoff(null)}>
              閉じる
            </Button>
            <Button
              className="rounded-lg"
              onClick={() => {
                setSelectedHandoff(null);
                navigate("/app/records");
              }}
            >
              <ExternalLink className="mr-1 size-4" />
              記録画面へ
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
