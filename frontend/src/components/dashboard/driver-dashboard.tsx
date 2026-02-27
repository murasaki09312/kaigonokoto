import { useMemo, useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { Ban, CheckCircle2, CircleDashed, Route, Truck } from "lucide-react";
import { toast } from "sonner";
import { getShuttleBoard, type ApiError, upsertShuttleLeg } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import type { ShuttleBoardItem, ShuttleDirection, ShuttleLegStatus } from "@/types/shuttle";
import { formatReservationTime } from "@/components/reservations/reservation-constants";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";

type StatusUi = {
  label: string;
  className: string;
};

const STATUS_UI: Record<ShuttleLegStatus, StatusUi> = {
  pending: {
    label: "未実施",
    className: "border-zinc-300 bg-zinc-50 text-zinc-600",
  },
  boarded: {
    label: "乗車済み",
    className: "border-sky-200 bg-sky-100 text-sky-700",
  },
  alighted: {
    label: "降車済み",
    className: "border-emerald-200 bg-emerald-100 text-emerald-700",
  },
  cancelled: {
    label: "キャンセル",
    className: "border-border bg-muted text-muted-foreground",
  },
};

function getLeg(item: ShuttleBoardItem, direction: ShuttleDirection) {
  return direction === "pickup" ? item.shuttle_operation.pickup_leg : item.shuttle_operation.dropoff_leg;
}

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

function compareByPriority(left: ShuttleBoardItem, right: ShuttleBoardItem, direction: ShuttleDirection): number {
  const leftLeg = getLeg(left, direction);
  const rightLeg = getLeg(right, direction);
  const leftPending = leftLeg.status === "pending" ? 0 : 1;
  const rightPending = rightLeg.status === "pending" ? 0 : 1;
  if (leftPending !== rightPending) return leftPending - rightPending;
  return (left.reservation.client_name ?? "").localeCompare(right.reservation.client_name ?? "");
}

export function DriverDashboard() {
  const { user, permissions } = useAuth();
  const [activeDirection, setActiveDirection] = useState<ShuttleDirection>("pickup");
  const targetDate = format(new Date(), "yyyy-MM-dd");
  const canReadShuttleBoard = permissions.includes("shuttles:read");
  const canOperateShuttleBoard = permissions.includes("shuttles:operate") || permissions.includes("shuttles:manage");

  const boardQuery = useQuery({
    queryKey: ["driver-dashboard", "shuttle-board", targetDate],
    queryFn: () => getShuttleBoard({ date: targetDate }),
    enabled: canReadShuttleBoard,
  });

  const updateLegMutation = useMutation({
    mutationFn: ({
      reservationId,
      direction,
      status,
    }: {
      reservationId: number;
      direction: ShuttleDirection;
      status: ShuttleLegStatus;
    }) => {
      const completeStatus = direction === "pickup" ? "boarded" : "alighted";
      const actualAt = status === completeStatus ? new Date().toISOString() : null;
      return upsertShuttleLeg(reservationId, direction, { status, actual_at: actualAt });
    },
    onSuccess: async (_, variables) => {
      const completeLabel = variables.direction === "pickup" ? "乗車済み" : "降車済み";
      const actionMessage = variables.status === "cancelled"
        ? "キャンセルに更新しました"
        : variables.status === "pending"
          ? "未実施に戻しました"
          : `${completeLabel}に更新しました`;
      toast.success(`送迎ステータスを${actionMessage}`);
      await boardQuery.refetch();
    },
    onError: (error) => {
      toast.error(formatApiError(error, "送迎ステータスの更新に失敗しました"));
    },
  });

  const directionCounts = activeDirection === "pickup"
    ? boardQuery.data?.meta.pickup_counts
    : boardQuery.data?.meta.dropoff_counts;

  const assignedItems = useMemo(() => {
    const items = boardQuery.data?.items ?? [];
    const ownItems = items.filter((item) => {
      const leg = getLeg(item, activeDirection);
      return leg.handled_by_user_id === user?.id;
    });
    const source = ownItems.length > 0 ? ownItems : items;
    return [...source].sort((left, right) => compareByPriority(left, right, activeDirection));
  }, [activeDirection, boardQuery.data?.items, user?.id]);

  const completeActionStatus = activeDirection === "pickup" ? "boarded" : "alighted";
  const completeActionLabel = activeDirection === "pickup" ? "乗車済みにする" : "降車済みにする";

  if (!canReadShuttleBoard) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardContent className="p-10 text-center">
          <p className="font-medium">権限がありません</p>
          <p className="mt-1 text-sm text-muted-foreground">
            shuttles:read 権限を持つユーザーでログインしてください。
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader className="space-y-4">
          <div>
            <CardTitle className="flex items-center gap-2 text-base">
              <Truck className="size-4" />
              今日の送迎ルート
            </CardTitle>
            <CardDescription>担当送迎の進捗を確認し、その場で乗降ステータスを更新します。</CardDescription>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3">
            <Tabs value={activeDirection} onValueChange={(value) => setActiveDirection(value as ShuttleDirection)}>
              <TabsList className="rounded-xl">
                <TabsTrigger value="pickup">迎え</TabsTrigger>
                <TabsTrigger value="dropoff">送り</TabsTrigger>
              </TabsList>
            </Tabs>

            <div className="flex items-center gap-2">
              <Badge variant="secondary" className="rounded-lg">
                対象日 {targetDate}
              </Badge>
              <Badge variant="outline" className="rounded-lg">
                未実施 {directionCounts?.pending ?? 0} 件
              </Badge>
            </div>
          </div>
        </CardHeader>
      </Card>

      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base">
            <Route className="size-4" />
            乗降ステータスのクイック更新
          </CardTitle>
          <CardDescription>
            {assignedItems.some((item) => getLeg(item, activeDirection).handled_by_user_id === user?.id)
              ? "あなたの担当分を表示しています。"
              : "担当割り当てがないため、当日の全件を表示しています。"}
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-3">
          {boardQuery.isPending && (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, index) => (
                <Skeleton key={index} className="h-16 w-full" />
              ))}
            </div>
          )}

          {!boardQuery.isPending && assignedItems.length === 0 && (
            <div className="rounded-xl border border-dashed p-8 text-center">
              <p className="font-medium">対象データがありません</p>
              <p className="mt-1 text-sm text-muted-foreground">本日の送迎予定が登録されるとここに表示されます。</p>
            </div>
          )}

          {assignedItems.map((item) => {
            const leg = getLeg(item, activeDirection);
            const ui = STATUS_UI[leg.status];

            return (
              <div key={`${item.reservation.id}-${activeDirection}`} className="rounded-xl border border-border/70 p-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="text-sm font-semibold">{item.reservation.client_name ?? "名称未設定"}</p>
                    <p className="text-xs text-muted-foreground">
                      {formatReservationTime(item.reservation.start_time, item.reservation.end_time)}
                    </p>
                  </div>
                  <Badge variant="outline" className={cn("rounded-full", ui.className)}>
                    {ui.label}
                  </Badge>
                </div>

                <div className="mt-3 flex flex-wrap gap-2">
                  <Button
                    size="sm"
                    className="rounded-lg"
                    onClick={() =>
                      updateLegMutation.mutate({
                        reservationId: item.reservation.id,
                        direction: activeDirection,
                        status: completeActionStatus,
                      })}
                    disabled={!canOperateShuttleBoard || updateLegMutation.isPending}
                  >
                    <CheckCircle2 className="mr-1 size-4" />
                    {completeActionLabel}
                  </Button>

                  <Button
                    size="sm"
                    variant="outline"
                    className="rounded-lg"
                    onClick={() =>
                      updateLegMutation.mutate({
                        reservationId: item.reservation.id,
                        direction: activeDirection,
                        status: "pending",
                      })}
                    disabled={!canOperateShuttleBoard || updateLegMutation.isPending}
                  >
                    <CircleDashed className="mr-1 size-4" />
                    未実施に戻す
                  </Button>

                  <Button
                    size="sm"
                    variant="outline"
                    className="rounded-lg"
                    onClick={() =>
                      updateLegMutation.mutate({
                        reservationId: item.reservation.id,
                        direction: activeDirection,
                        status: "cancelled",
                      })}
                    disabled={!canOperateShuttleBoard || updateLegMutation.isPending}
                  >
                    <Ban className="mr-1 size-4" />
                    キャンセル
                  </Button>
                </div>
              </div>
            );
          })}
        </CardContent>
      </Card>
    </div>
  );
}
