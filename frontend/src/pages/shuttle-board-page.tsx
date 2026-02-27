import { useEffect, useMemo, useState, type ComponentType } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { addDays, format, parseISO, subDays } from "date-fns";
import { ja } from "date-fns/locale";
import { Ban, Check, CheckCircle2, ChevronLeft, ChevronRight, CircleDashed, CircleSlash2, Search } from "lucide-react";
import { toast } from "sonner";
import { useSearchParams } from "react-router-dom";
import { getShuttleBoard, type ApiError, upsertShuttleLeg } from "@/lib/api";
import type { ShuttleBoardItem, ShuttleDirection, ShuttleLegStatus } from "@/types/shuttle";
import { useAuth } from "@/providers/auth-provider";
import { formatReservationTime, statusLabel } from "@/components/reservations/reservation-constants";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";

type StatusUi = {
  label: string;
  className: string;
  icon: ComponentType<{ className?: string }>;
};

type ShuttleStatusFilter = ShuttleLegStatus | "all";

type ShuttleStatusFilterOption = {
  value: ShuttleStatusFilter;
  label: string;
};

const STATUS_FILTER_OPTIONS: ShuttleStatusFilterOption[] = [
  { value: "all", label: "すべて" },
  { value: "pending", label: "未実施" },
  { value: "boarded", label: "乗車済み" },
  { value: "alighted", label: "降車済み" },
  { value: "cancelled", label: "キャンセル" },
];

const STATUS_UI: Record<ShuttleLegStatus, StatusUi> = {
  pending: {
    label: "未実施",
    className: "border-zinc-300 bg-zinc-50 text-zinc-600",
    icon: CircleDashed,
  },
  boarded: {
    label: "乗車済み",
    className: "border-sky-200 bg-sky-100 text-sky-700",
    icon: CheckCircle2,
  },
  alighted: {
    label: "降車済み",
    className: "border-emerald-200 bg-emerald-100 text-emerald-700",
    icon: CheckCircle2,
  },
  cancelled: {
    label: "キャンセル",
    className: "border-border bg-muted text-muted-foreground",
    icon: CircleSlash2,
  },
};

function formatDateKey(date: Date): string {
  return format(date, "yyyy-MM-dd");
}

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

function parseDirection(value: string | null): ShuttleDirection {
  return value === "dropoff" ? "dropoff" : "pickup";
}

function parseStatusFilter(value: string | null): ShuttleStatusFilter {
  if (value === "pending") return "pending";
  if (value === "boarded") return "boarded";
  if (value === "alighted") return "alighted";
  if (value === "cancelled") return "cancelled";
  return "all";
}

function getLeg(item: ShuttleBoardItem, direction: ShuttleDirection) {
  return direction === "pickup" ? item.shuttle_operation.pickup_leg : item.shuttle_operation.dropoff_leg;
}

function formatActualTime(value: string | null): string {
  if (!value) return "-";
  return format(parseISO(value), "HH:mm");
}

export function ShuttleBoardPage() {
  const { permissions } = useAuth();
  const canReadBoard = permissions.includes("shuttles:read");
  const [searchParams, setSearchParams] = useSearchParams();
  const directionParam = searchParams.get("direction");
  const statusParam = searchParams.get("status");

  const [targetDate, setTargetDate] = useState(formatDateKey(new Date()));
  const [search, setSearch] = useState("");
  const [activeDirection, setActiveDirection] = useState<ShuttleDirection>(() => parseDirection(directionParam));
  const [statusFilter, setStatusFilter] = useState<ShuttleStatusFilter>(() => parseStatusFilter(statusParam));

  const boardQuery = useQuery({
    queryKey: ["shuttle-board", targetDate],
    queryFn: () => getShuttleBoard({ date: targetDate }),
    enabled: canReadBoard,
  });

  const updateLegMutation = useMutation({
    mutationFn: ({
      reservationId,
      direction,
      payload,
    }: {
      reservationId: number;
      direction: ShuttleDirection;
      payload: { status: ShuttleLegStatus; actual_at: string | null };
    }) => upsertShuttleLeg(reservationId, direction, payload),
    onSuccess: async (_, variables) => {
      const completedStatus = variables.direction === "pickup" ? "乗車済み" : "降車済み";
      const toastMessage = variables.payload.status === "cancelled"
        ? "送迎ステータスをキャンセルに更新しました"
        : variables.payload.status === "pending"
          ? "送迎ステータスを未実施に更新しました"
          : `送迎ステータスを${completedStatus}に更新しました`;

      toast.success(toastMessage);
      await boardQuery.refetch();
    },
    onError: (error) => {
      const message =
        typeof error === "object" &&
        error !== null &&
        "code" in error &&
        (error as ApiError).code === "forbidden"
          ? "送迎ステータスを更新する権限がありません。"
          : formatApiError(error, "送迎ステータスの更新に失敗しました");
      toast.error(message);
    },
  });

  const filteredItems = useMemo(() => {
    let items = boardQuery.data?.items ?? [];
    if (statusFilter !== "all") {
      items = items.filter((item) => getLeg(item, activeDirection).status === statusFilter);
    }

    const normalizedSearch = search.trim().toLowerCase();
    if (!normalizedSearch) return items;

    return items.filter((item) =>
      (item.reservation.client_name ?? "").toLowerCase().includes(normalizedSearch),
    );
  }, [activeDirection, boardQuery.data?.items, search, statusFilter]);

  const boardDateLabel = useMemo(() => format(parseISO(targetDate), "yyyy/MM/dd (E)", { locale: ja }), [targetDate]);
  const statusCounts = activeDirection === "pickup"
    ? boardQuery.data?.meta.pickup_counts
    : boardQuery.data?.meta.dropoff_counts;
  const canOperateBoard = boardQuery.data?.meta.capabilities?.can_update_leg
    ?? (permissions.includes("shuttles:operate") || permissions.includes("shuttles:manage"));
  const canManageSchedule = boardQuery.data?.meta.capabilities?.can_manage_schedule
    ?? permissions.includes("shuttles:manage");

  const moveDay = (direction: "prev" | "next") => {
    const current = parseISO(targetDate);
    const next = direction === "prev" ? subDays(current, 1) : addDays(current, 1);
    setTargetDate(formatDateKey(next));
  };

  useEffect(() => {
    setActiveDirection(parseDirection(directionParam));
  }, [directionParam]);

  useEffect(() => {
    setStatusFilter(parseStatusFilter(statusParam));
  }, [statusParam]);

  const updateDirection = (nextDirection: ShuttleDirection) => {
    setActiveDirection(nextDirection);
    setSearchParams((previous) => {
      const next = new URLSearchParams(previous);
      next.set("direction", nextDirection);
      return next;
    }, { replace: true });
  };

  const updateStatusFilter = (nextStatus: ShuttleStatusFilter) => {
    setStatusFilter(nextStatus);
    setSearchParams((previous) => {
      const next = new URLSearchParams(previous);
      if (nextStatus === "all") {
        next.delete("status");
      } else {
        next.set("status", nextStatus);
      }
      return next;
    }, { replace: true });
  };

  const updateStatus = async (item: ShuttleBoardItem, status: ShuttleLegStatus) => {
    const completedStatus = activeDirection === "pickup" ? "boarded" : "alighted";
    const actualAt = status === completedStatus ? new Date().toISOString() : null;

    await updateLegMutation.mutateAsync({
      reservationId: item.reservation.id,
      direction: activeDirection,
      payload: { status, actual_at: actualAt },
    });
  };

  const statusMeta = STATUS_UI;
  const completeActionStatus = activeDirection === "pickup" ? "boarded" : "alighted";
  const completeActionLabel = activeDirection === "pickup" ? "乗車済みにする" : "降車済みにする";

  if (!canReadBoard) {
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
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <CardTitle className="text-base">送迎ボード</CardTitle>
              <CardDescription>当日の迎え・送り状況を確認し、乗降チェックを記録します。</CardDescription>
            </div>

            <div className="flex items-center gap-2">
              <Button variant="outline" size="icon" className="rounded-xl" onClick={() => moveDay("prev")}>
                <ChevronLeft className="size-4" />
              </Button>
              <Badge variant="secondary" className="rounded-lg">
                {boardDateLabel}
              </Badge>
              <Button variant="outline" size="icon" className="rounded-xl" onClick={() => moveDay("next")}>
                <ChevronRight className="size-4" />
              </Button>
            </div>
          </div>

          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            <Tabs value={activeDirection} onValueChange={(value) => updateDirection(value as ShuttleDirection)}>
              <TabsList className="rounded-xl">
                <TabsTrigger value="pickup">迎え</TabsTrigger>
                <TabsTrigger value="dropoff">送り</TabsTrigger>
              </TabsList>
            </Tabs>

            <div className="flex w-full flex-col gap-2 lg:w-auto lg:flex-row lg:items-center">
              <div className="flex flex-wrap gap-1.5">
                {STATUS_FILTER_OPTIONS.map((option) => (
                  <Button
                    key={option.value}
                    type="button"
                    size="sm"
                    variant={statusFilter === option.value ? "secondary" : "outline"}
                    className="rounded-lg"
                    aria-label={`状態: ${option.label}`}
                    onClick={() => updateStatusFilter(option.value)}
                  >
                    {option.label}
                  </Button>
                ))}
              </div>

              <div className="relative w-full max-w-sm">
                <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  className="rounded-xl pl-9"
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="利用者名で検索"
                />
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {(["pending", "boarded", "alighted", "cancelled"] as ShuttleLegStatus[]).map((status) => {
              const meta = statusMeta[status];
              const Icon = meta.icon;
              const count = statusCounts?.[status] ?? 0;

              return (
                <div key={status} className="rounded-xl border border-border/70 bg-background px-3 py-2">
                  <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                    <Icon className="size-3.5" />
                    <span>{meta.label}</span>
                  </div>
                  <p className="mt-1 text-base font-semibold">{count}件</p>
                </div>
              );
            })}
          </div>

          <div className="flex flex-wrap gap-2 text-xs text-muted-foreground">
            <Badge variant={canOperateBoard ? "secondary" : "outline"} className="rounded-lg">
              乗降更新: {canOperateBoard ? "可" : "不可"}
            </Badge>
            <Badge variant={canManageSchedule ? "secondary" : "outline"} className="rounded-lg">
              計画管理: {canManageSchedule ? "可" : "不可"}
            </Badge>
          </div>
        </CardHeader>

        <CardContent>
          {boardQuery.isPending && (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, index) => (
                <Skeleton key={index} className="h-24 w-full rounded-xl" />
              ))}
            </div>
          )}

          {boardQuery.isError && !boardQuery.isPending && (
            <Card className="rounded-2xl border-destructive/30">
              <CardContent className="space-y-3 p-8 text-center">
                <p className="font-medium">送迎データの取得に失敗しました</p>
                <Button variant="outline" className="rounded-xl" onClick={() => boardQuery.refetch()}>
                  リトライ
                </Button>
              </CardContent>
            </Card>
          )}

          {!boardQuery.isPending && !boardQuery.isError && filteredItems.length === 0 && (
            <Card className="rounded-2xl border-dashed">
              <CardContent className="p-10 text-center">
                <p className="font-medium">対象の送迎利用者がいません</p>
                <p className="mt-1 text-sm text-muted-foreground">この日の予約、または検索条件を確認してください。</p>
              </CardContent>
            </Card>
          )}

          {!boardQuery.isPending && !boardQuery.isError && filteredItems.length > 0 && (
            <div className="space-y-3">
              {filteredItems.map((item) => {
                const leg = getLeg(item, activeDirection);
                const meta = statusMeta[leg.status];
                const Icon = meta.icon;

                return (
                  <Card key={item.reservation.id} className="rounded-2xl border-border/70">
                    <CardContent className="space-y-3 p-4">
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="truncate text-sm font-semibold">
                            {item.reservation.client_name || "利用者未設定"}
                          </p>
                          <p className="text-xs text-muted-foreground">
                            予約時間: {formatReservationTime(item.reservation.start_time, item.reservation.end_time)}
                          </p>
                          <p className="text-xs text-muted-foreground">
                            予約状態: {statusLabel(item.reservation.status)}
                          </p>
                        </div>

                        <Badge
                          variant="outline"
                          className={cn(
                            "inline-flex min-h-8 items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold",
                            meta.className,
                          )}
                        >
                          <Icon className="size-3.5" />
                          <span>{meta.label}</span>
                        </Badge>
                      </div>

                      <div className="grid gap-2 text-xs text-muted-foreground sm:grid-cols-3">
                        <p>実績時刻: {formatActualTime(leg.actual_at)}</p>
                        <p className="truncate">対応者: {leg.handled_by_user_name || "-"}</p>
                        <p className="truncate">メモ: {leg.note || "-"}</p>
                      </div>

                      {canOperateBoard ? (
                        <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
                          <Button
                            type="button"
                            className="h-11 rounded-xl"
                            disabled={updateLegMutation.isPending}
                            onClick={() => updateStatus(item, completeActionStatus)}
                          >
                            <Check className="mr-1 size-4" />
                            {completeActionLabel}
                          </Button>
                          <Button
                            type="button"
                            variant="outline"
                            className="h-11 rounded-xl"
                            disabled={updateLegMutation.isPending}
                            onClick={() => updateStatus(item, "pending")}
                          >
                            <CircleDashed className="mr-1 size-4" />
                            未実施に戻す
                          </Button>
                          <Button
                            type="button"
                            variant="outline"
                            className="h-11 rounded-xl border-destructive/40 text-destructive hover:bg-destructive/10"
                            disabled={updateLegMutation.isPending}
                            onClick={() => updateStatus(item, "cancelled")}
                          >
                            <Ban className="mr-1 size-4" />
                            キャンセル
                          </Button>
                        </div>
                      ) : (
                        <p className="text-xs text-muted-foreground">
                          shuttles:operate または shuttles:manage 権限がないため更新できません。
                        </p>
                      )}
                    </CardContent>
                  </Card>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
