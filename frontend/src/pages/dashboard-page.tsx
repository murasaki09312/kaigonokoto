import { useQuery } from "@tanstack/react-query";
import { Activity, CheckCircle2, Clock3, Users2 } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";

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

async function fetchSnapshot(): Promise<Snapshot> {
  await new Promise((resolve) => setTimeout(resolve, 600));
  return {
    scheduled: 24,
    pendingAttendance: 3,
    shuttlePending: 2,
    recordPending: 5,
  };
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
  const snapshotQuery = useQuery({ queryKey: ["dashboard", "snapshot"], queryFn: fetchSnapshot });
  const recentQuery = useQuery({ queryKey: ["dashboard", "recent"], queryFn: fetchRecentUpdates });

  const cards = [
    {
      title: "今日の予定人数",
      value: snapshotQuery.data?.scheduled,
      icon: Users2,
      hint: "本日入所予定",
    },
    {
      title: "未出欠",
      value: snapshotQuery.data?.pendingAttendance,
      icon: Clock3,
      hint: "入力待ち",
    },
    {
      title: "送迎未完了",
      value: snapshotQuery.data?.shuttlePending,
      icon: Activity,
      hint: "乗降チェック待ち",
    },
    {
      title: "記録未完了",
      value: snapshotQuery.data?.recordPending,
      icon: CheckCircle2,
      hint: "ケア記録待ち",
    },
  ];

  return (
    <div className="space-y-6">
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {cards.map((card) => {
          const Icon = card.icon;
          return (
            <Card key={card.title} className="rounded-2xl border-border/70 shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:shadow-md">
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
