import { useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { Activity, CheckCircle2, Clock3, Users2 } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { getShuttleBoard, getTodayBoard } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

type Snapshot = {
  scheduled: number;
  pendingAttendance: number;
  shuttlePending: number;
  recordPending: number;
};

type UpdateItem = {
  id: string;
  text: string;
  when: string;
};

type DashboardCard = {
  title: string;
  value: number;
  icon: typeof Users2;
  hint: string;
  to?: string;
  requiredPermission?: string;
};

type SnapshotQueryOptions = {
  date: string;
  canReadTodayBoard: boolean;
  canReadShuttleBoard: boolean;
};

async function fetchSnapshot(options: SnapshotQueryOptions): Promise<Snapshot> {
  const snapshot: Snapshot = {
    scheduled: 0,
    pendingAttendance: 0,
    shuttlePending: 0,
    recordPending: 0,
  };

  const [todayBoardResult, shuttleBoardResult] = await Promise.allSettled([
    options.canReadTodayBoard ? getTodayBoard({ date: options.date }) : Promise.resolve(null),
    options.canReadShuttleBoard ? getShuttleBoard({ date: options.date }) : Promise.resolve(null),
  ]);

  if (todayBoardResult.status === "fulfilled" && todayBoardResult.value) {
    snapshot.scheduled = todayBoardResult.value.meta.total;
    snapshot.pendingAttendance = todayBoardResult.value.meta.attendance_counts.pending ?? 0;
    snapshot.recordPending = todayBoardResult.value.meta.care_record_pending ?? 0;
  }

  if (shuttleBoardResult.status === "fulfilled" && shuttleBoardResult.value) {
    snapshot.shuttlePending = shuttleBoardResult.value.meta.pickup_counts.pending ?? 0;
  }

  return snapshot;
}

async function fetchRecentUpdates(): Promise<UpdateItem[]> {
  await new Promise((resolve) => setTimeout(resolve, 900));
  return [
    { id: "1", text: "山田 太郎さんの出欠が更新されました", when: "3分前" },
    { id: "2", text: "送迎チェックが2件完了しました", when: "12分前" },
    { id: "3", text: "新規ユーザーが作成されました", when: "24分前" },
  ];
}

export function DashboardPage() {
  const navigate = useNavigate();
  const { permissions } = useAuth();
  const targetDate = format(new Date(), "yyyy-MM-dd");
  const canReadTodayBoard = permissions.includes("today_board:read");
  const canReadShuttleBoard = permissions.includes("shuttles:read");

  const snapshotQuery = useQuery({
    queryKey: ["dashboard", "snapshot", targetDate, canReadTodayBoard, canReadShuttleBoard],
    queryFn: () =>
      fetchSnapshot({
        date: targetDate,
        canReadTodayBoard,
        canReadShuttleBoard,
      }),
  });
  const recentQuery = useQuery({ queryKey: ["dashboard", "recent"], queryFn: fetchRecentUpdates });

  const cards: DashboardCard[] = [
    {
      title: "今日の予定人数",
      value: snapshotQuery.data?.scheduled ?? 0,
      icon: Users2,
      hint: "本日入所予定",
    },
    {
      title: "未出欠",
      value: snapshotQuery.data?.pendingAttendance ?? 0,
      icon: Clock3,
      hint: "入力待ち",
      to: "/app/today-board?filter=attendance_pending",
      requiredPermission: "today_board:read",
    },
    {
      title: "送迎未完了",
      value: snapshotQuery.data?.shuttlePending ?? 0,
      icon: Activity,
      hint: "乗降チェック待ち",
      to: "/app/shuttle?direction=pickup&status=pending",
      requiredPermission: "shuttles:read",
    },
    {
      title: "記録未完了",
      value: snapshotQuery.data?.recordPending ?? 0,
      icon: CheckCircle2,
      hint: "ケア記録待ち",
      to: "/app/records?tab=unrecorded",
      requiredPermission: "today_board:read",
    },
  ];

  return (
    <div className="space-y-6">
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {cards.map((card) => {
          const Icon = card.icon;
          const isActionable = Boolean(card.to);
          const canNavigate = isActionable
            && (!card.requiredPermission || permissions.includes(card.requiredPermission));
          const destination = canNavigate && card.to ? card.to : null;

          return (
            <Card
              key={card.title}
              role={canNavigate ? "button" : undefined}
              tabIndex={canNavigate ? 0 : undefined}
              aria-disabled={isActionable && !canNavigate ? true : undefined}
              onClick={destination ? () => navigate(destination) : undefined}
              onKeyDown={destination
                ? (event) => {
                    if (event.key === "Enter" || event.key === " ") {
                      event.preventDefault();
                      navigate(destination);
                    }
                  }
                : undefined}
              className={cn(
                "rounded-2xl border-border/70 shadow-sm",
                isActionable && "transition-all duration-200",
                canNavigate && "cursor-pointer hover:-translate-y-1 hover:shadow-md",
                isActionable && !canNavigate && "opacity-60",
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
                  <div className="text-3xl font-semibold tracking-tight">{card.value ?? 0}</div>
                )}
                <p className="mt-1 text-xs text-muted-foreground">{card.hint}</p>
              </CardContent>
            </Card>
          );
        })}
      </section>

      <section className="grid grid-cols-1 gap-4 lg:grid-cols-[2fr_1fr]">
        <Card className="rounded-2xl border-border/70 shadow-sm">
          <CardHeader>
            <CardTitle className="text-base">最近の更新</CardTitle>
            <CardDescription>現場オペレーションの更新ログ（ダミー）</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {recentQuery.isPending && (
              <div className="space-y-3">
                {Array.from({ length: 4 }).map((_, index) => (
                  <Skeleton key={index} className="h-10 w-full" />
                ))}
              </div>
            )}

            {!recentQuery.isPending && (recentQuery.data?.length ?? 0) === 0 && (
              <div className="rounded-xl border border-dashed p-8 text-center">
                <p className="font-medium">更新はまだありません</p>
                <p className="mt-1 text-sm text-muted-foreground">本日の操作が始まるとここに表示されます。</p>
              </div>
            )}

            {(recentQuery.data ?? []).map((item) => (
              <div key={item.id} className="flex items-center justify-between rounded-xl border border-border/70 p-3">
                <p className="text-sm">{item.text}</p>
                <Badge variant="secondary" className="rounded-lg">
                  {item.when}
                </Badge>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card className="rounded-2xl border-border/70 shadow-sm">
          <CardHeader>
            <CardTitle className="text-base">運用メモ</CardTitle>
            <CardDescription>現場オペレーションの目安</CardDescription>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>・出欠は 11:00 までに確定</p>
            <p>・送迎未完了はボードで再確認</p>
            <p>・記録未完了は終業前に解消</p>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
