import { useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { Activity, CheckCircle2, Clock3, Users2 } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { getShuttleBoard, getTodayBoard } from "@/lib/api";
import { useCurrentTime } from "@/hooks/useCurrentTime";
import {
  getKpiCardAlertClassName,
  resolveDashboardCardAlertLevels,
  resolveShuttleCardMode,
  sortDashboardKpiCards,
  type DashboardKpiCardId,
} from "@/lib/kpi-alerts";
import { useAuth } from "@/providers/auth-provider";
import { HandoffWidget } from "@/components/dashboard/handoff-widget";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

type Snapshot = {
  scheduled: number | null;
  pendingAttendance: number | null;
  shuttlePickupPending: number | null;
  shuttleDropoffPending: number | null;
  recordPending: number | null;
  errors: {
    todayBoard: boolean;
    shuttleBoard: boolean;
  };
};

type DashboardCard = {
  id: DashboardKpiCardId;
  title: string;
  value: number | null;
  icon: typeof Users2;
  hint: string;
  sourceError: boolean;
  to?: string;
  requiredPermission?: string;
  dataPermission?: string;
};

type SnapshotQueryOptions = {
  date: string;
  canReadTodayBoard: boolean;
  canReadShuttleBoard: boolean;
};

async function fetchSnapshot(options: SnapshotQueryOptions): Promise<Snapshot> {
  const snapshot: Snapshot = {
    scheduled: null,
    pendingAttendance: null,
    shuttlePickupPending: null,
    shuttleDropoffPending: null,
    recordPending: null,
    errors: {
      todayBoard: false,
      shuttleBoard: false,
    },
  };

  const [todayBoardResult, shuttleBoardResult] = await Promise.allSettled([
    options.canReadTodayBoard ? getTodayBoard({ date: options.date }) : Promise.resolve(null),
    options.canReadShuttleBoard ? getShuttleBoard({ date: options.date }) : Promise.resolve(null),
  ]);

  if (todayBoardResult.status === "fulfilled" && todayBoardResult.value) {
    snapshot.scheduled = todayBoardResult.value.meta.total;
    snapshot.pendingAttendance = todayBoardResult.value.meta.attendance_counts.pending ?? 0;
    snapshot.recordPending = todayBoardResult.value.meta.care_record_pending ?? 0;
  } else if (options.canReadTodayBoard) {
    snapshot.errors.todayBoard = true;
  }

  if (shuttleBoardResult.status === "fulfilled" && shuttleBoardResult.value) {
    snapshot.shuttlePickupPending = shuttleBoardResult.value.meta.pickup_counts.pending ?? 0;
    snapshot.shuttleDropoffPending = shuttleBoardResult.value.meta.dropoff_counts.pending ?? 0;
  } else if (options.canReadShuttleBoard) {
    snapshot.errors.shuttleBoard = true;
  }

  return snapshot;
}

export function AdminDashboard() {
  const navigate = useNavigate();
  const currentTime = useCurrentTime();
  const { permissions } = useAuth();
  const targetDate = format(currentTime, "yyyy-MM-dd");
  const canReadTodayBoard = permissions.includes("today_board:read");
  const canReadShuttleBoard = permissions.includes("shuttles:read");
  const shuttleMode = resolveShuttleCardMode(currentTime);

  const snapshotQuery = useQuery({
    queryKey: ["dashboard", "snapshot", targetDate, canReadTodayBoard, canReadShuttleBoard],
    queryFn: () =>
      fetchSnapshot({
        date: targetDate,
        canReadTodayBoard,
        canReadShuttleBoard,
      }),
  });
  const shuttlePendingValue = shuttleMode === "pickup"
    ? snapshotQuery.data?.shuttlePickupPending ?? null
    : snapshotQuery.data?.shuttleDropoffPending ?? null;
  const alertLevels = resolveDashboardCardAlertLevels({
    now: currentTime,
    shuttleMode,
    pendingAttendance: snapshotQuery.data?.pendingAttendance ?? 0,
    pendingShuttle: shuttlePendingValue ?? 0,
    pendingRecord: snapshotQuery.data?.recordPending ?? 0,
  });

  const cards: DashboardCard[] = sortDashboardKpiCards(
    [
      {
        id: "scheduled",
        title: "今日の予定人数",
        value: snapshotQuery.data?.scheduled ?? null,
        icon: Users2,
        hint: "本日入所予定",
        sourceError: snapshotQuery.data?.errors.todayBoard ?? false,
        dataPermission: "today_board:read",
      },
      {
        id: "attendance-pending",
        title: "未出欠",
        value: snapshotQuery.data?.pendingAttendance ?? null,
        icon: Clock3,
        hint: "入力待ち",
        sourceError: snapshotQuery.data?.errors.todayBoard ?? false,
        to: "/app/today-board?filter=attendance_pending",
        requiredPermission: "today_board:read",
        dataPermission: "today_board:read",
      },
      {
        id: "shuttle-pending",
        title: shuttleMode === "pickup" ? "送迎未完了（迎え）" : "送迎未完了（送り）",
        value: shuttlePendingValue,
        icon: Activity,
        hint: shuttleMode === "pickup" ? "乗車チェック待ち" : "降車チェック待ち",
        sourceError: snapshotQuery.data?.errors.shuttleBoard ?? false,
        to: `/app/shuttle?direction=${shuttleMode}&status=pending`,
        requiredPermission: "shuttles:read",
        dataPermission: "shuttles:read",
      },
      {
        id: "record-pending",
        title: "記録未完了",
        value: snapshotQuery.data?.recordPending ?? null,
        icon: CheckCircle2,
        hint: "ケア記録待ち",
        sourceError: snapshotQuery.data?.errors.todayBoard ?? false,
        to: "/app/records?tab=unrecorded",
        requiredPermission: "today_board:read",
        dataPermission: "today_board:read",
      },
    ],
    currentTime,
  );

  return (
    <div className="space-y-6">
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {cards.map((card) => {
          const Icon = card.icon;
          const isActionable = Boolean(card.to);
          const canNavigate = isActionable
            && (!card.requiredPermission || permissions.includes(card.requiredPermission));
          const destination = canNavigate && card.to ? card.to : null;
          const canViewData = !card.dataPermission || permissions.includes(card.dataPermission);
          const hasValue = card.value !== null;
          const alertLevel = alertLevels[card.id];
          const valueText = hasValue ? String(card.value) : "--";
          const hintText = snapshotQuery.isPending
            ? card.hint
            : hasValue
              ? card.hint
              : canViewData && card.sourceError
                ? "取得失敗"
                : "権限が必要";
          const activateCard = () => {
            if (destination) navigate(destination);
          };

          return (
            <Card
              key={card.id}
              data-testid={`kpi-card-${card.id}`}
              role={isActionable ? "button" : undefined}
              tabIndex={isActionable ? 0 : undefined}
              aria-disabled={isActionable ? !canNavigate : undefined}
              onClick={isActionable ? activateCard : undefined}
              onKeyDown={isActionable
                ? (event) => {
                    if (event.key === "Enter" || event.key === " ") {
                      event.preventDefault();
                      activateCard();
                    }
                  }
                : undefined}
              className={cn(
                "rounded-2xl border-border/70 shadow-sm",
                hasValue && getKpiCardAlertClassName(alertLevel),
                isActionable && "transition-all duration-200",
                canNavigate && "cursor-pointer hover:-translate-y-1 hover:shadow-md",
                isActionable && !canNavigate && "cursor-not-allowed opacity-60",
              )}
            >
              <CardHeader className="flex flex-row items-start justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">{card.title}</CardTitle>
                <Icon className="size-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                {snapshotQuery.isPending ? (
                  <Skeleton className="h-8 w-16" />
                ) : (
                  <div data-testid={`kpi-value-${card.id}`} className="text-3xl font-semibold tracking-tight">
                    {valueText}
                  </div>
                )}
                <p
                  data-testid={`kpi-hint-${card.id}`}
                  className={cn(
                    "mt-1 text-xs",
                    snapshotQuery.isPending || hasValue ? "text-muted-foreground" : "text-amber-700",
                  )}
                >
                  {hintText}
                </p>
              </CardContent>
            </Card>
          );
        })}
      </section>

      <section className="grid grid-cols-1 gap-4 lg:grid-cols-[2fr_1fr]">
        <HandoffWidget />

        <Card className="rounded-2xl border-border/70 shadow-sm">
          <CardHeader>
            <CardTitle className="text-base">運用メモ</CardTitle>
            <CardDescription>現場オペレーションの目安</CardDescription>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>・出欠は 11:00 までに確定</p>
            <p>・送迎未完了はボードで再確認</p>
            <p>・記録未完了は終業前に解消</p>
            <p>・申し送りは New バッジを優先確認</p>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
