import { useEffect, useMemo, useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { addDays, format, parseISO, subDays } from "date-fns";
import { ja } from "date-fns/locale";
import {
  Check,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  CircleDashed,
  CircleSlash2,
  Save,
  Search,
  XCircle,
  type LucideIcon,
} from "lucide-react";
import { toast } from "sonner";
import { getTodayBoard, type ApiError, upsertAttendance, upsertCareRecord } from "@/lib/api";
import type {
  AttendancePayload,
  AttendanceStatus,
  CareRecordPayload,
  TodayBoardItem,
} from "@/types/today-board";
import { useAuth } from "@/providers/auth-provider";
import { formatReservationTime, statusLabel } from "@/components/reservations/reservation-constants";
import { Badge, type BadgeProps } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useSearchParams } from "react-router-dom";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";

type AttendanceDraft = {
  status: AttendanceStatus;
  absence_reason: string;
  contacted_at: string;
  note: string;
};

type CareRecordDraft = {
  body_temperature: string;
  systolic_bp: string;
  diastolic_bp: string;
  pulse: string;
  spo2: string;
  care_note: string;
  handoff_note: string;
};

type AttendanceStatusUiMeta = {
  label: string;
  icon: LucideIcon;
  variant: NonNullable<BadgeProps["variant"]>;
  badgeClassName: string;
};

type TodayBoardFilter = "all" | "attendance_pending" | "care_record_pending";

const ATTENDANCE_STATUS_UI: Record<AttendanceStatus, AttendanceStatusUiMeta> = {
  pending: {
    label: "予定",
    icon: CircleDashed,
    variant: "outline",
    badgeClassName: "border-zinc-300 bg-zinc-50 text-zinc-600",
  },
  present: {
    label: "出席",
    icon: CheckCircle2,
    variant: "secondary",
    badgeClassName: "border-emerald-200 bg-emerald-100 text-emerald-700",
  },
  absent: {
    label: "欠席",
    icon: XCircle,
    variant: "secondary",
    badgeClassName: "border-rose-200 bg-rose-100 text-rose-700",
  },
  cancelled: {
    label: "キャンセル",
    icon: CircleSlash2,
    variant: "secondary",
    badgeClassName: "border-border bg-muted text-muted-foreground",
  },
};

const ATTENDANCE_STATUS_OPTIONS: AttendanceStatus[] = [
  "pending",
  "present",
  "absent",
  "cancelled",
];

function AttendanceStatusBadge({ status }: { status: AttendanceStatus }) {
  const meta = ATTENDANCE_STATUS_UI[status];
  const Icon = meta.icon;

  return (
    <Badge
      variant={meta.variant}
      className={cn(
        "inline-flex min-h-8 items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold",
        meta.badgeClassName,
      )}
    >
      <Icon className="size-3.5" />
      <span>{meta.label}</span>
    </Badge>
  );
}

function formatDateKey(date: Date): string {
  return format(date, "yyyy-MM-dd");
}

function toOptionalString(value: string): string | null {
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function toDateTimeLocalValue(value: string | null | undefined): string {
  if (!value) return "";
  const date = new Date(value);
  const adjusted = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return adjusted.toISOString().slice(0, 16);
}

function parseOptionalNumber(value: string): number | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
}

function attendanceDraftFromItem(item: TodayBoardItem): AttendanceDraft {
  return {
    status: item.attendance?.status ?? "pending",
    absence_reason: item.attendance?.absence_reason ?? "",
    contacted_at: toDateTimeLocalValue(item.attendance?.contacted_at),
    note: item.attendance?.note ?? "",
  };
}

function careRecordDraftFromItem(item: TodayBoardItem): CareRecordDraft {
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
  };
}

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

function parseTodayBoardFilter(value: string | null): TodayBoardFilter {
  if (value === "attendance_pending") return "attendance_pending";
  if (value === "care_record_pending") return "care_record_pending";
  return "all";
}

export function TodayBoardPage() {
  const { permissions } = useAuth();
  const canReadBoard = permissions.includes("today_board:read");
  const canManageAttendance = permissions.includes("attendances:manage");
  const canManageCareRecord = permissions.includes("care_records:manage");
  const [searchParams, setSearchParams] = useSearchParams();
  const filterParam = searchParams.get("filter");

  const [targetDate, setTargetDate] = useState(formatDateKey(new Date()));
  const [search, setSearch] = useState("");
  const [activeFilter, setActiveFilter] = useState<TodayBoardFilter>(() => parseTodayBoardFilter(filterParam));
  const [attendanceDrafts, setAttendanceDrafts] = useState<Record<number, AttendanceDraft>>({});
  const [careRecordDrafts, setCareRecordDrafts] = useState<Record<number, CareRecordDraft>>({});

  const boardQuery = useQuery({
    queryKey: ["today-board", targetDate],
    queryFn: () => getTodayBoard({ date: targetDate }),
    enabled: canReadBoard,
  });

  const attendanceMutation = useMutation({
    mutationFn: ({
      reservationId,
      payload,
    }: {
      reservationId: number;
      payload: AttendancePayload;
    }) => upsertAttendance(reservationId, payload),
    onSuccess: async (_attendance, variables) => {
      setAttendanceDrafts((prev) => {
        if (!(variables.reservationId in prev)) return prev;

        const next = { ...prev };
        delete next[variables.reservationId];
        return next;
      });
      toast.success("出欠を保存しました");
      await boardQuery.refetch();
    },
    onError: (error) => {
      toast.error(formatApiError(error, "出欠の保存に失敗しました"));
    },
  });

  const careRecordMutation = useMutation({
    mutationFn: ({
      reservationId,
      payload,
    }: {
      reservationId: number;
      payload: CareRecordPayload;
    }) => upsertCareRecord(reservationId, payload),
    onSuccess: async (_careRecord, variables) => {
      setCareRecordDrafts((prev) => {
        if (!(variables.reservationId in prev)) return prev;

        const next = { ...prev };
        delete next[variables.reservationId];
        return next;
      });
      toast.success("記録を保存しました");
      await boardQuery.refetch();
    },
    onError: (error) => {
      toast.error(formatApiError(error, "記録の保存に失敗しました"));
    },
  });

  const filteredItems = useMemo(() => {
    let items = boardQuery.data?.items ?? [];
    if (activeFilter === "attendance_pending") {
      items = items.filter((item) => (item.attendance?.status ?? "pending") === "pending");
    } else if (activeFilter === "care_record_pending") {
      items = items.filter((item) => item.care_record === null);
    }

    const normalizedSearch = search.trim().toLowerCase();
    if (!normalizedSearch) return items;

    return items.filter((item) =>
      (item.reservation.client_name ?? "").toLowerCase().includes(normalizedSearch),
    );
  }, [activeFilter, boardQuery.data?.items, search]);

  useEffect(() => {
    setActiveFilter(parseTodayBoardFilter(filterParam));
  }, [filterParam]);

  const boardDateLabel = useMemo(() => {
    return format(parseISO(targetDate), "yyyy/MM/dd (E)", { locale: ja });
  }, [targetDate]);

  const updateAttendanceDraft = (
    item: TodayBoardItem,
    updater: (draft: AttendanceDraft) => AttendanceDraft,
  ) => {
    setAttendanceDrafts((prev) => {
      const current = prev[item.reservation.id] ?? attendanceDraftFromItem(item);
      return {
        ...prev,
        [item.reservation.id]: updater(current),
      };
    });
  };

  const updateCareRecordDraft = (
    item: TodayBoardItem,
    updater: (draft: CareRecordDraft) => CareRecordDraft,
  ) => {
    setCareRecordDrafts((prev) => {
      const current = prev[item.reservation.id] ?? careRecordDraftFromItem(item);
      return {
        ...prev,
        [item.reservation.id]: updater(current),
      };
    });
  };

  const saveAttendance = async (item: TodayBoardItem) => {
    const draft = attendanceDrafts[item.reservation.id] ?? attendanceDraftFromItem(item);
    const payload: AttendancePayload = {
      status: draft.status,
      absence_reason: toOptionalString(draft.absence_reason),
      contacted_at: draft.contacted_at ? new Date(draft.contacted_at).toISOString() : null,
      note: toOptionalString(draft.note),
    };

    await attendanceMutation.mutateAsync({ reservationId: item.reservation.id, payload });
  };

  const saveCareRecord = async (item: TodayBoardItem) => {
    const draft = careRecordDrafts[item.reservation.id] ?? careRecordDraftFromItem(item);
    const payload: CareRecordPayload = {
      body_temperature: parseOptionalNumber(draft.body_temperature),
      systolic_bp: parseOptionalNumber(draft.systolic_bp),
      diastolic_bp: parseOptionalNumber(draft.diastolic_bp),
      pulse: parseOptionalNumber(draft.pulse),
      spo2: parseOptionalNumber(draft.spo2),
      care_note: toOptionalString(draft.care_note),
      handoff_note: toOptionalString(draft.handoff_note),
    };

    await careRecordMutation.mutateAsync({ reservationId: item.reservation.id, payload });
  };

  const moveDay = (direction: "prev" | "next") => {
    const current = parseISO(targetDate);
    const next = direction === "prev" ? subDays(current, 1) : addDays(current, 1);
    setTargetDate(formatDateKey(next));
  };

  const updateActiveFilter = (nextFilter: TodayBoardFilter) => {
    setActiveFilter(nextFilter);
    setSearchParams((previous) => {
      const next = new URLSearchParams(previous);
      if (nextFilter === "all") {
        next.delete("filter");
      } else {
        next.set("filter", nextFilter);
      }
      return next;
    }, { replace: true });
  };

  if (!canReadBoard) {
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
              <CardTitle className="text-base">当日ボード</CardTitle>
              <CardDescription>予定確認・出欠登録・ケア記録を1画面で管理します。</CardDescription>
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
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="利用者名で検索"
            />
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Button
              type="button"
              size="sm"
              variant={activeFilter === "all" ? "secondary" : "outline"}
              className="rounded-lg"
              onClick={() => updateActiveFilter("all")}
            >
              すべて
            </Button>
            <Button
              type="button"
              size="sm"
              variant={activeFilter === "attendance_pending" ? "secondary" : "outline"}
              className="rounded-lg"
              onClick={() => updateActiveFilter("attendance_pending")}
            >
              未出欠
            </Button>
            <Button
              type="button"
              size="sm"
              variant={activeFilter === "care_record_pending" ? "secondary" : "outline"}
              className="rounded-lg"
              onClick={() => updateActiveFilter("care_record_pending")}
            >
              記録未完了
            </Button>
          </div>
        </CardHeader>
      </Card>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Card className="rounded-2xl border-border/70">
          <CardHeader className="pb-2">
            <CardDescription>予定件数</CardDescription>
            <CardTitle className="text-2xl">{boardQuery.data?.meta.total ?? 0}</CardTitle>
          </CardHeader>
        </Card>
        <Card className="rounded-2xl border-border/70">
          <CardHeader className="pb-2">
            <CardDescription>出席 / 欠席</CardDescription>
            <CardTitle className="text-2xl">
              {(boardQuery.data?.meta.attendance_counts.present ?? 0)} /{" "}
              {(boardQuery.data?.meta.attendance_counts.absent ?? 0)}
            </CardTitle>
          </CardHeader>
        </Card>
        <Card className="rounded-2xl border-border/70">
          <CardHeader className="pb-2">
            <CardDescription>未処理出欠</CardDescription>
            <CardTitle className="text-2xl">{boardQuery.data?.meta.attendance_counts.pending ?? 0}</CardTitle>
          </CardHeader>
        </Card>
        <Card className="rounded-2xl border-border/70">
          <CardHeader className="pb-2">
            <CardDescription>記録完了 / 未完了</CardDescription>
            <CardTitle className="text-2xl">
              {boardQuery.data?.meta.care_record_completed ?? 0} / {boardQuery.data?.meta.care_record_pending ?? 0}
            </CardTitle>
          </CardHeader>
        </Card>
      </div>

      {boardQuery.isPending && (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, index) => (
            <Skeleton key={index} className="h-52 w-full rounded-2xl" />
          ))}
        </div>
      )}

      {boardQuery.isError && !boardQuery.isPending && (
        <Card className="rounded-2xl border-destructive/30">
          <CardContent className="space-y-3 p-8 text-center">
            <p className="font-medium">当日ボードの取得に失敗しました</p>
            <Button variant="outline" className="rounded-xl" onClick={() => boardQuery.refetch()}>
              リトライ
            </Button>
          </CardContent>
        </Card>
      )}

      {!boardQuery.isPending && !boardQuery.isError && filteredItems.length === 0 && (
        <Card className="rounded-2xl border-dashed">
          <CardContent className="p-10 text-center">
            <p className="font-medium">対象の予定がありません</p>
            <p className="mt-1 text-sm text-muted-foreground">
              この日の予約は未登録、または検索条件に一致する利用者がいません。
            </p>
          </CardContent>
        </Card>
      )}

      {!boardQuery.isPending && !boardQuery.isError && filteredItems.length > 0 && (
        <div className="space-y-3">
          {filteredItems.map((item) => {
            const attendanceDraft = attendanceDrafts[item.reservation.id] ?? attendanceDraftFromItem(item);
            const careRecordDraft = careRecordDrafts[item.reservation.id] ?? careRecordDraftFromItem(item);

            return (
              <Card key={item.reservation.id} className="rounded-2xl border-border/70">
                <CardHeader className="space-y-3 pb-3">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <CardTitle className="text-base">{item.reservation.client_name ?? "利用者未設定"}</CardTitle>
                      <CardDescription>
                        {item.reservation.service_date} /{" "}
                        {formatReservationTime(item.reservation.start_time, item.reservation.end_time)}
                      </CardDescription>
                    </div>
                    <Badge variant="secondary" className="rounded-lg">
                      予約状態: {statusLabel(item.reservation.status)}
                    </Badge>
                  </div>
                </CardHeader>
                <CardContent className="grid gap-4 xl:grid-cols-2">
                  <section className="space-y-3 rounded-xl border border-border/70 p-4">
                    <div className="flex items-center justify-between">
                      <p className="text-sm font-semibold">出欠</p>
                      <Button
                        type="button"
                        size="sm"
                        className="rounded-lg"
                        disabled={!canManageAttendance || attendanceMutation.isPending}
                        onClick={() => saveAttendance(item)}
                      >
                        <Save className="mr-1 size-4" />
                        保存
                      </Button>
                    </div>

                    <div className="space-y-2">
                      <label className="text-xs font-medium text-muted-foreground">ステータス</label>
                      {canManageAttendance ? (
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <button
                              type="button"
                              className="inline-flex min-h-10 items-center rounded-full transition hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                              aria-label="出欠ステータスを変更"
                            >
                              <AttendanceStatusBadge status={attendanceDraft.status} />
                            </button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="start" className="w-44 rounded-xl">
                            <DropdownMenuLabel className="text-xs text-muted-foreground">
                              出欠ステータス
                            </DropdownMenuLabel>
                            <DropdownMenuSeparator />
                            {ATTENDANCE_STATUS_OPTIONS.map((statusValue) => {
                              const meta = ATTENDANCE_STATUS_UI[statusValue];
                              const Icon = meta.icon;
                              return (
                                <DropdownMenuItem
                                  key={statusValue}
                                  className="cursor-pointer rounded-lg py-2"
                                  onSelect={() =>
                                    updateAttendanceDraft(item, (current) => ({
                                      ...current,
                                      status: statusValue,
                                    }))
                                  }
                                >
                                  <span className="inline-flex items-center gap-2">
                                    <Icon className="size-4 text-muted-foreground" />
                                    <span>{meta.label}</span>
                                  </span>
                                  {attendanceDraft.status === statusValue && (
                                    <Check className="ml-auto size-4 text-primary" />
                                  )}
                                </DropdownMenuItem>
                              );
                            })}
                          </DropdownMenuContent>
                        </DropdownMenu>
                      ) : (
                        <AttendanceStatusBadge status={attendanceDraft.status} />
                      )}
                    </div>

                    <div className="space-y-2">
                      <label className="text-xs font-medium text-muted-foreground">欠席理由</label>
                      <Input
                        className="rounded-xl"
                        value={attendanceDraft.absence_reason}
                        onChange={(event) =>
                          updateAttendanceDraft(item, (current) => ({
                            ...current,
                            absence_reason: event.target.value,
                          }))
                        }
                        disabled={!canManageAttendance}
                      />
                    </div>

                    <div className="space-y-2">
                      <label className="text-xs font-medium text-muted-foreground">連絡時刻</label>
                      <Input
                        type="datetime-local"
                        className="rounded-xl"
                        value={attendanceDraft.contacted_at}
                        onChange={(event) =>
                          updateAttendanceDraft(item, (current) => ({
                            ...current,
                            contacted_at: event.target.value,
                          }))
                        }
                        disabled={!canManageAttendance}
                      />
                    </div>

                    <div className="space-y-2">
                      <label className="text-xs font-medium text-muted-foreground">メモ</label>
                      <Textarea
                        rows={3}
                        className="rounded-xl"
                        value={attendanceDraft.note}
                        onChange={(event) =>
                          updateAttendanceDraft(item, (current) => ({
                            ...current,
                            note: event.target.value,
                          }))
                        }
                        disabled={!canManageAttendance}
                      />
                    </div>
                  </section>

                  <section className="space-y-3 rounded-xl border border-border/70 p-4">
                    <div className="flex items-center justify-between">
                      <p className="text-sm font-semibold">ケア記録</p>
                      <Button
                        type="button"
                        size="sm"
                        className="rounded-lg"
                        disabled={!canManageCareRecord || careRecordMutation.isPending}
                        onClick={() => saveCareRecord(item)}
                      >
                        <Save className="mr-1 size-4" />
                        保存
                      </Button>
                    </div>

                    <div className="grid gap-2 sm:grid-cols-2">
                      <div className="space-y-2">
                        <label className="text-xs font-medium text-muted-foreground">体温</label>
                        <Input
                          type="number"
                          step="0.1"
                          className="rounded-xl"
                          value={careRecordDraft.body_temperature}
                          onChange={(event) =>
                            updateCareRecordDraft(item, (current) => ({
                              ...current,
                              body_temperature: event.target.value,
                            }))
                          }
                          disabled={!canManageCareRecord}
                        />
                      </div>
                      <div className="space-y-2">
                        <label className="text-xs font-medium text-muted-foreground">SPO2</label>
                        <Input
                          type="number"
                          className="rounded-xl"
                          value={careRecordDraft.spo2}
                          onChange={(event) =>
                            updateCareRecordDraft(item, (current) => ({
                              ...current,
                              spo2: event.target.value,
                            }))
                          }
                          disabled={!canManageCareRecord}
                        />
                      </div>
                      <div className="space-y-2">
                        <label className="text-xs font-medium text-muted-foreground">収縮期血圧</label>
                        <Input
                          type="number"
                          className="rounded-xl"
                          value={careRecordDraft.systolic_bp}
                          onChange={(event) =>
                            updateCareRecordDraft(item, (current) => ({
                              ...current,
                              systolic_bp: event.target.value,
                            }))
                          }
                          disabled={!canManageCareRecord}
                        />
                      </div>
                      <div className="space-y-2">
                        <label className="text-xs font-medium text-muted-foreground">拡張期血圧</label>
                        <Input
                          type="number"
                          className="rounded-xl"
                          value={careRecordDraft.diastolic_bp}
                          onChange={(event) =>
                            updateCareRecordDraft(item, (current) => ({
                              ...current,
                              diastolic_bp: event.target.value,
                            }))
                          }
                          disabled={!canManageCareRecord}
                        />
                      </div>
                      <div className="space-y-2">
                        <label className="text-xs font-medium text-muted-foreground">脈拍</label>
                        <Input
                          type="number"
                          className="rounded-xl"
                          value={careRecordDraft.pulse}
                          onChange={(event) =>
                            updateCareRecordDraft(item, (current) => ({
                              ...current,
                              pulse: event.target.value,
                            }))
                          }
                          disabled={!canManageCareRecord}
                        />
                      </div>
                    </div>

                    <div className="space-y-2">
                      <label className="text-xs font-medium text-muted-foreground">ケアメモ</label>
                      <Textarea
                        rows={3}
                        className="rounded-xl"
                        value={careRecordDraft.care_note}
                        onChange={(event) =>
                          updateCareRecordDraft(item, (current) => ({
                            ...current,
                            care_note: event.target.value,
                          }))
                        }
                        disabled={!canManageCareRecord}
                      />
                    </div>

                    <div className="space-y-2">
                      <label className="text-xs font-medium text-muted-foreground">申し送り</label>
                      <Textarea
                        rows={3}
                        className="rounded-xl"
                        value={careRecordDraft.handoff_note}
                        onChange={(event) =>
                          updateCareRecordDraft(item, (current) => ({
                            ...current,
                            handoff_note: event.target.value,
                          }))
                        }
                        disabled={!canManageCareRecord}
                      />
                    </div>
                  </section>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
