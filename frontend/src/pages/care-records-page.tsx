import { useEffect, useMemo, useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { addDays, format, parseISO, subDays } from "date-fns";
import { ja } from "date-fns/locale";
import {
  AlertTriangle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Edit3,
  Search,
  Send,
} from "lucide-react";
import { toast } from "sonner";
import { getTodayBoard, type ApiError, upsertCareRecord } from "@/lib/api";
import { useAuth } from "@/providers/auth-provider";
import {
  type CareRecordPayload,
  type LineNotificationStatus,
  type TodayBoardItem,
} from "@/types/today-board";
import { formatReservationTime, statusLabel } from "@/components/reservations/reservation-constants";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { useSearchParams } from "react-router-dom";

type CareRecordFormValues = {
  body_temperature: string;
  systolic_bp: string;
  diastolic_bp: string;
  pulse: string;
  spo2: string;
  care_note: string;
  handoff_note: string;
  send_line_notification: boolean;
};

type CareRecordTab = "all" | "unrecorded";

type LineStatusUi = {
  label: string;
  className: string;
  icon: typeof Clock3;
};

const LINE_STATUS_UI: Record<LineNotificationStatus, LineStatusUi> = {
  unsent: {
    label: "未送信",
    className: "border-zinc-300 bg-zinc-50 text-zinc-600",
    icon: Clock3,
  },
  queued: {
    label: "送信待ち",
    className: "border-sky-200 bg-sky-100 text-sky-700",
    icon: Send,
  },
  sent: {
    label: "送信済",
    className: "border-emerald-200 bg-emerald-100 text-emerald-700",
    icon: CheckCircle2,
  },
  failed: {
    label: "送信エラー",
    className: "border-rose-200 bg-rose-100 text-rose-700",
    icon: AlertTriangle,
  },
  skipped: {
    label: "送信スキップ",
    className: "border-amber-200 bg-amber-100 text-amber-700",
    icon: AlertTriangle,
  },
};

function formatDateKey(date: Date): string {
  return format(date, "yyyy-MM-dd");
}

function toOptionalString(value: string): string | null {
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function parseOptionalNumber(value: string): number | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
}

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

function formValuesFromItem(item: TodayBoardItem): CareRecordFormValues {
  return {
    body_temperature:
      item.care_record?.body_temperature === null || item.care_record?.body_temperature === undefined
        ? ""
        : String(item.care_record.body_temperature),
    systolic_bp:
      item.care_record?.systolic_bp === null || item.care_record?.systolic_bp === undefined
        ? ""
        : String(item.care_record.systolic_bp),
    diastolic_bp:
      item.care_record?.diastolic_bp === null || item.care_record?.diastolic_bp === undefined
        ? ""
        : String(item.care_record.diastolic_bp),
    pulse:
      item.care_record?.pulse === null || item.care_record?.pulse === undefined
        ? ""
        : String(item.care_record.pulse),
    spo2:
      item.care_record?.spo2 === null || item.care_record?.spo2 === undefined
        ? ""
        : String(item.care_record.spo2),
    care_note: item.care_record?.care_note ?? "",
    handoff_note: item.care_record?.handoff_note ?? "",
    send_line_notification: false,
  };
}

function lineStatusForItem(item: TodayBoardItem): LineNotificationStatus {
  return item.line_notification?.status ?? "unsent";
}

function parseCareRecordTab(value: string | null): CareRecordTab {
  return value === "unrecorded" ? "unrecorded" : "all";
}

function LineStatusBadge({ status }: { status: LineNotificationStatus }) {
  const ui = LINE_STATUS_UI[status];
  const Icon = ui.icon;

  return (
    <Badge
      variant="outline"
      className={cn("inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium", ui.className)}
    >
      <Icon className="size-3.5" />
      <span>{ui.label}</span>
    </Badge>
  );
}

export function CareRecordsPage() {
  const { permissions } = useAuth();
  const canReadRecords = permissions.includes("today_board:read");
  const canManageCareRecord = permissions.includes("care_records:manage");
  const [searchParams, setSearchParams] = useSearchParams();
  const tabParam = searchParams.get("tab");

  const [targetDate, setTargetDate] = useState(formatDateKey(new Date()));
  const [search, setSearch] = useState("");
  const [activeTab, setActiveTab] = useState<CareRecordTab>(() => parseCareRecordTab(tabParam));
  const [selectedItem, setSelectedItem] = useState<TodayBoardItem | null>(null);
  const [formValues, setFormValues] = useState<CareRecordFormValues | null>(null);

  const boardQuery = useQuery({
    queryKey: ["care-records", targetDate],
    queryFn: () => getTodayBoard({ date: targetDate }),
    enabled: canReadRecords,
  });

  const saveMutation = useMutation({
    mutationFn: ({
      reservationId,
      payload,
    }: {
      reservationId: number;
      payload: CareRecordPayload;
    }) => upsertCareRecord(reservationId, payload),
    onSuccess: async (_careRecord, variables) => {
      const didQueueLine = variables.payload.send_line_notification === true;
      if (didQueueLine) {
        toast.success("記録を保存し、LINE通知を送信キューに追加しました");
      } else {
        toast.success("記録を保存しました");
      }
      closeDialog();
      await boardQuery.refetch();
    },
    onError: (error) => {
      toast.error(formatApiError(error, "記録の保存に失敗しました"));
    },
  });

  const filteredItems = useMemo(() => {
    let items = boardQuery.data?.items ?? [];
    if (activeTab === "unrecorded") {
      items = items.filter((item) => item.care_record === null);
    }

    const keyword = search.trim().toLowerCase();

    if (!keyword) return items;

    return items.filter((item) => {
      const name = (item.reservation.client_name ?? "").toLowerCase();
      const note = (item.care_record?.handoff_note ?? "").toLowerCase();
      return name.includes(keyword) || note.includes(keyword);
    });
  }, [activeTab, boardQuery.data?.items, search]);

  const boardDateLabel = useMemo(() => {
    return format(parseISO(targetDate), "yyyy/MM/dd (E)", { locale: ja });
  }, [targetDate]);

  const summary = useMemo(() => {
    const items = boardQuery.data?.items ?? [];
    const recordedCount = items.filter((item) => item.care_record !== null).length;
    const sentCount = items.filter((item) => lineStatusForItem(item) === "sent").length;

    return {
      total: items.length,
      recordedCount,
      pendingCount: items.length - recordedCount,
      sentCount,
    };
  }, [boardQuery.data?.items]);

  const moveDay = (direction: "prev" | "next") => {
    const current = parseISO(targetDate);
    const next = direction === "prev" ? subDays(current, 1) : addDays(current, 1);
    setTargetDate(formatDateKey(next));
  };

  useEffect(() => {
    setActiveTab(parseCareRecordTab(tabParam));
  }, [tabParam]);

  const updateTab = (nextTab: CareRecordTab) => {
    setActiveTab(nextTab);
    setSearchParams((previous) => {
      const next = new URLSearchParams(previous);
      if (nextTab === "all") {
        next.delete("tab");
      } else {
        next.set("tab", nextTab);
      }
      return next;
    }, { replace: true });
  };

  const openDialog = (item: TodayBoardItem) => {
    setSelectedItem(item);
    setFormValues(formValuesFromItem(item));
  };

  const closeDialog = () => {
    setSelectedItem(null);
    setFormValues(null);
  };

  const saveRecord = async () => {
    if (!selectedItem || !formValues) return;

    if (formValues.send_line_notification && !toOptionalString(formValues.handoff_note)) {
      toast.error("LINE通知を送信する場合は、申し送りを入力してください。");
      return;
    }

    const payload: CareRecordPayload = {
      body_temperature: parseOptionalNumber(formValues.body_temperature),
      systolic_bp: parseOptionalNumber(formValues.systolic_bp),
      diastolic_bp: parseOptionalNumber(formValues.diastolic_bp),
      pulse: parseOptionalNumber(formValues.pulse),
      spo2: parseOptionalNumber(formValues.spo2),
      care_note: toOptionalString(formValues.care_note),
      handoff_note: toOptionalString(formValues.handoff_note),
      send_line_notification:
        formValues.send_line_notification && selectedItem.line_notification_available,
    };

    await saveMutation.mutateAsync({
      reservationId: selectedItem.reservation.id,
      payload,
    });
  };

  if (!canReadRecords) {
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
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader className="space-y-4">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <CardTitle className="text-base">記録</CardTitle>
              <CardDescription>ケア記録の入力と家族向けLINE通知を行います。</CardDescription>
            </div>
            <div className="flex items-center gap-2">
              <Button variant="outline" size="icon" className="rounded-xl" onClick={() => moveDay("prev")}>
                <ChevronLeft className="size-4" />
              </Button>
              <Badge variant="secondary" className="rounded-lg px-3 py-1">
                {boardDateLabel}
              </Badge>
              <Button variant="outline" size="icon" className="rounded-xl" onClick={() => moveDay("next")}>
                <ChevronRight className="size-4" />
              </Button>
            </div>
          </div>

          <div className="relative w-full max-w-sm">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              className="rounded-xl pl-9"
              placeholder="利用者名・申し送りで検索"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
          </div>

          <Tabs value={activeTab} onValueChange={(value) => updateTab(value as CareRecordTab)}>
            <TabsList className="rounded-xl">
              <TabsTrigger value="all">すべて</TabsTrigger>
              <TabsTrigger value="unrecorded">未入力のみ</TabsTrigger>
            </TabsList>
          </Tabs>
        </CardHeader>
      </Card>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Card className="rounded-2xl border-border/70">
          <CardHeader className="pb-2">
            <CardDescription>対象予定数</CardDescription>
            <CardTitle className="text-2xl">{summary.total}</CardTitle>
          </CardHeader>
        </Card>
        <Card className="rounded-2xl border-border/70">
          <CardHeader className="pb-2">
            <CardDescription>記録入力済 / 未入力</CardDescription>
            <CardTitle className="text-2xl">
              {summary.recordedCount} / {summary.pendingCount}
            </CardTitle>
          </CardHeader>
        </Card>
        <Card className="rounded-2xl border-border/70">
          <CardHeader className="pb-2">
            <CardDescription>LINE送信済</CardDescription>
            <CardTitle className="text-2xl">{summary.sentCount}</CardTitle>
          </CardHeader>
        </Card>
        <Card className="rounded-2xl border-border/70">
          <CardHeader className="pb-2">
            <CardDescription>編集権限</CardDescription>
            <CardTitle className="text-lg">{canManageCareRecord ? "編集可" : "閲覧のみ"}</CardTitle>
          </CardHeader>
        </Card>
      </div>

      {boardQuery.isPending && (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, index) => (
            <Skeleton key={index} className="h-24 w-full rounded-2xl" />
          ))}
        </div>
      )}

      {boardQuery.isError && !boardQuery.isPending && (
        <Card className="rounded-2xl border-destructive/30">
          <CardContent className="space-y-3 p-8 text-center">
            <p className="font-medium">記録一覧の取得に失敗しました</p>
            <Button variant="outline" className="rounded-xl" onClick={() => boardQuery.refetch()}>
              リトライ
            </Button>
          </CardContent>
        </Card>
      )}

      {!boardQuery.isPending && !boardQuery.isError && filteredItems.length === 0 && (
        <Card className="rounded-2xl border-dashed">
          <CardContent className="p-10 text-center">
            <p className="font-medium">対象データがありません</p>
            <p className="mt-1 text-sm text-muted-foreground">
              この日の予約がないか、検索条件に一致する利用者がいません。
            </p>
          </CardContent>
        </Card>
      )}

      {!boardQuery.isPending && !boardQuery.isError && filteredItems.length > 0 && (
        <div className="space-y-3">
          {filteredItems.map((item) => {
            const lineStatus = lineStatusForItem(item);
            const handoffPreview = item.care_record?.handoff_note?.trim();

            return (
              <Card key={item.reservation.id} className="rounded-2xl border-border/70">
                <CardContent className="flex flex-col gap-3 p-4 md:flex-row md:items-center md:justify-between">
                  <div className="min-w-0 space-y-1">
                    <p className="truncate text-sm font-semibold">
                      {item.reservation.client_name ?? "利用者未設定"}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {item.reservation.service_date} /{" "}
                      {formatReservationTime(item.reservation.start_time, item.reservation.end_time)} / 予約:
                      {statusLabel(item.reservation.status)}
                    </p>
                    <p className="line-clamp-2 text-xs text-muted-foreground">
                      申し送り: {handoffPreview && handoffPreview.length > 0 ? handoffPreview : "未入力"}
                    </p>
                  </div>

                  <div className="flex flex-wrap items-center gap-2">
                    <LineStatusBadge status={lineStatus} />
                    {item.line_notification_available ? (
                      <Badge variant="outline" className="rounded-full text-xs">
                        LINE連携 {item.line_enabled_family_count} 名
                      </Badge>
                    ) : (
                      <Badge variant="outline" className="rounded-full text-xs text-muted-foreground">
                        LINE未連携
                      </Badge>
                    )}
                    <Button
                      type="button"
                      size="sm"
                      className="rounded-lg"
                      disabled={!canManageCareRecord}
                      onClick={() => openDialog(item)}
                    >
                      <Edit3 className="mr-1 size-4" />
                      記録を編集
                    </Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      <Dialog open={selectedItem !== null} onOpenChange={(open) => (!open ? closeDialog() : null)}>
        <DialogContent className="max-h-[90vh] overflow-y-auto rounded-2xl sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle>記録の作成・編集</DialogTitle>
            <DialogDescription>
              {selectedItem?.reservation.client_name ?? "利用者"} /{" "}
              {selectedItem
                ? formatReservationTime(
                    selectedItem.reservation.start_time,
                    selectedItem.reservation.end_time,
                  )
                : "-"}
            </DialogDescription>
          </DialogHeader>

          {selectedItem && formValues && (
            <div className="space-y-4">
              <div className="grid gap-3 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">体温</label>
                  <Input
                    type="number"
                    step="0.1"
                    className="rounded-xl"
                    value={formValues.body_temperature}
                    onChange={(event) =>
                      setFormValues((prev) =>
                        prev ? { ...prev, body_temperature: event.target.value } : prev,
                      )
                    }
                    disabled={!canManageCareRecord || saveMutation.isPending}
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">SPO2</label>
                  <Input
                    type="number"
                    className="rounded-xl"
                    value={formValues.spo2}
                    onChange={(event) =>
                      setFormValues((prev) => (prev ? { ...prev, spo2: event.target.value } : prev))
                    }
                    disabled={!canManageCareRecord || saveMutation.isPending}
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">収縮期血圧</label>
                  <Input
                    type="number"
                    className="rounded-xl"
                    value={formValues.systolic_bp}
                    onChange={(event) =>
                      setFormValues((prev) =>
                        prev ? { ...prev, systolic_bp: event.target.value } : prev,
                      )
                    }
                    disabled={!canManageCareRecord || saveMutation.isPending}
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">拡張期血圧</label>
                  <Input
                    type="number"
                    className="rounded-xl"
                    value={formValues.diastolic_bp}
                    onChange={(event) =>
                      setFormValues((prev) =>
                        prev ? { ...prev, diastolic_bp: event.target.value } : prev,
                      )
                    }
                    disabled={!canManageCareRecord || saveMutation.isPending}
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">脈拍</label>
                  <Input
                    type="number"
                    className="rounded-xl"
                    value={formValues.pulse}
                    onChange={(event) =>
                      setFormValues((prev) => (prev ? { ...prev, pulse: event.target.value } : prev))
                    }
                    disabled={!canManageCareRecord || saveMutation.isPending}
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-muted-foreground">ケアメモ</label>
                <Textarea
                  rows={4}
                  className="rounded-xl"
                  value={formValues.care_note}
                  onChange={(event) =>
                    setFormValues((prev) => (prev ? { ...prev, care_note: event.target.value } : prev))
                  }
                  disabled={!canManageCareRecord || saveMutation.isPending}
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-muted-foreground">申し送り</label>
                <Textarea
                  rows={6}
                  className="rounded-xl"
                  value={formValues.handoff_note}
                  onChange={(event) =>
                    setFormValues((prev) => (prev ? { ...prev, handoff_note: event.target.value } : prev))
                  }
                  disabled={!canManageCareRecord || saveMutation.isPending}
                />
              </div>

              <div className="rounded-xl border border-border/70 p-3">
                <label className="flex items-start gap-3">
                  <input
                    type="checkbox"
                    className="mt-1 size-4 rounded border-border accent-primary"
                    checked={formValues.send_line_notification}
                    onChange={(event) =>
                      setFormValues((prev) =>
                        prev ? { ...prev, send_line_notification: event.target.checked } : prev,
                      )
                    }
                    disabled={
                      !canManageCareRecord ||
                      saveMutation.isPending ||
                      !selectedItem.line_notification_available
                    }
                  />
                  <span className="space-y-1">
                    <span className="block text-sm font-medium">家族へLINEで通知する</span>
                    {selectedItem.line_notification_available ? (
                      <span className="block text-xs text-muted-foreground">
                        連携済み家族 {selectedItem.line_enabled_family_count} 名へ送信対象として登録します。
                      </span>
                    ) : (
                      <span className="block text-xs text-muted-foreground">
                        LINE未連携（連携済み家族がいないため送信できません）
                      </span>
                    )}
                  </span>
                </label>
              </div>

              {selectedItem.line_notification?.status === "failed" && (
                <p className="text-xs text-rose-600">
                  前回送信エラー: {selectedItem.line_notification.last_error_message ?? "エラー詳細なし"}
                </p>
              )}
            </div>
          )}

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              className="rounded-xl"
              onClick={closeDialog}
              disabled={saveMutation.isPending}
            >
              キャンセル
            </Button>
            <Button
              type="button"
              className="rounded-xl"
              onClick={saveRecord}
              disabled={!canManageCareRecord || saveMutation.isPending}
            >
              保存
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
