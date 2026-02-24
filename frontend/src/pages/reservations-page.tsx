import { useMemo, useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import {
  addDays,
  eachDayOfInterval,
  endOfWeek,
  format,
  isSameDay,
  parseISO,
  startOfWeek,
  subDays,
} from "date-fns";
import { ja } from "date-fns/locale";
import { ChevronLeft, ChevronRight, Pencil, Search, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { deleteReservation, listClients, listReservations } from "@/lib/api";
import { ReservationFormDialog } from "@/components/reservations/reservation-form-dialog";
import { ReservationGenerateDialog } from "@/components/reservations/reservation-generate-dialog";
import { formatReservationTime, statusLabel } from "@/components/reservations/reservation-constants";
import type { Reservation } from "@/types/reservation";
import { useAuth } from "@/providers/auth-provider";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";

type ViewMode = "day" | "week";

function formatDateKey(date: Date): string {
  return format(date, "yyyy-MM-dd");
}

function statusBadgeClass(status: Reservation["status"]): string {
  if (status === "cancelled") return "bg-zinc-200 text-zinc-700";
  if (status === "completed") return "bg-emerald-100 text-emerald-700";
  return "bg-sky-100 text-sky-700";
}

export function ReservationsPage() {
  const { permissions } = useAuth();
  const canReadReservations = permissions.includes("reservations:read");
  const canManageReservations = permissions.includes("reservations:manage");
  const canOverrideCapacity =
    permissions.includes("reservations:override_capacity") || permissions.includes("tenants:manage");

  const [viewMode, setViewMode] = useState<ViewMode>("week");
  const [cursorDate, setCursorDate] = useState<Date>(new Date());
  const [search, setSearch] = useState("");

  const from = useMemo(() => {
    if (viewMode === "day") return formatDateKey(cursorDate);
    return formatDateKey(startOfWeek(cursorDate, { weekStartsOn: 1 }));
  }, [viewMode, cursorDate]);

  const to = useMemo(() => {
    if (viewMode === "day") return formatDateKey(cursorDate);
    return formatDateKey(endOfWeek(cursorDate, { weekStartsOn: 1 }));
  }, [viewMode, cursorDate]);

  const rangeDates = useMemo(() => {
    const fromDate = parseISO(from);
    const toDate = parseISO(to);
    return eachDayOfInterval({ start: fromDate, end: toDate });
  }, [from, to]);

  const reservationsQuery = useQuery({
    queryKey: ["reservations", from, to],
    queryFn: () => listReservations({ from, to }),
    enabled: canReadReservations,
  });

  const clientsQuery = useQuery({
    queryKey: ["reservation-form-clients"],
    queryFn: async () => {
      const result = await listClients({ status: "all" });
      return result.clients;
    },
    enabled: canManageReservations,
  });

  const deleteMutation = useMutation({
    mutationFn: deleteReservation,
    onSuccess: async () => {
      toast.success("予約を削除しました");
      await reservationsQuery.refetch();
    },
    onError: (error) => {
      const message =
        typeof error === "object" && error !== null && "message" in error
          ? String(error.message)
          : "予約の削除に失敗しました";
      toast.error(message);
    },
  });

  const reservations = useMemo(() => {
    const allReservations = reservationsQuery.data?.reservations ?? [];
    const normalizedSearch = search.trim().toLowerCase();
    if (!normalizedSearch) return allReservations;

    return allReservations.filter((reservation) =>
      (reservation.client_name ?? "").toLowerCase().includes(normalizedSearch),
    );
  }, [reservationsQuery.data?.reservations, search]);

  const reservationsByDate = useMemo(() => {
    return reservations.reduce<Record<string, Reservation[]>>((acc, reservation) => {
      const key = reservation.service_date;
      acc[key] ||= [];
      acc[key].push(reservation);
      return acc;
    }, {});
  }, [reservations]);

  const moveCursor = (direction: "prev" | "next") => {
    const delta = direction === "prev" ? -1 : 1;
    const days = viewMode === "day" ? 1 : 7;
    setCursorDate((current) => (delta > 0 ? addDays(current, days) : subDays(current, days)));
  };

  const refreshReservations = async () => {
    await reservationsQuery.refetch();
  };

  if (!canReadReservations) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardContent className="p-10 text-center">
          <p className="font-medium">権限がありません</p>
          <p className="mt-1 text-sm text-muted-foreground">
            reservations:read 権限を持つユーザーでログインしてください。
          </p>
        </CardContent>
      </Card>
    );
  }

  const periodLabel =
    viewMode === "day"
      ? format(parseISO(from), "yyyy/MM/dd (E)", { locale: ja })
      : `${format(parseISO(from), "yyyy/MM/dd", { locale: ja })} - ${format(parseISO(to), "yyyy/MM/dd", { locale: ja })}`;

  return (
    <div className="space-y-4">
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader className="space-y-4">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <CardTitle className="text-base">予約</CardTitle>
              <CardDescription>日/週の予約確認と定員管理</CardDescription>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <ReservationFormDialog
                mode="create"
                canManage={canManageReservations}
                canOverrideCapacity={canOverrideCapacity}
                clients={clientsQuery.data ?? []}
                onSubmitted={refreshReservations}
              />
              <ReservationGenerateDialog
                canManage={canManageReservations}
                canOverrideCapacity={canOverrideCapacity}
                onSubmitted={refreshReservations}
              />
            </div>
          </div>

          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            <div className="flex flex-wrap items-center gap-2">
              <Tabs value={viewMode} onValueChange={(value) => setViewMode(value as ViewMode)}>
                <TabsList className="rounded-xl">
                  <TabsTrigger value="day">日表示</TabsTrigger>
                  <TabsTrigger value="week">週表示</TabsTrigger>
                </TabsList>
              </Tabs>

              <Button variant="outline" size="icon" className="rounded-xl" onClick={() => moveCursor("prev")}>
                <ChevronLeft className="size-4" />
              </Button>
              <Button variant="outline" size="icon" className="rounded-xl" onClick={() => moveCursor("next")}>
                <ChevronRight className="size-4" />
              </Button>
              <Badge variant="secondary" className="rounded-lg">
                {periodLabel}
              </Badge>
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
        </CardHeader>

        <CardContent>
          {reservationsQuery.isPending && (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, index) => (
                <Skeleton key={index} className="h-12 w-full rounded-xl" />
              ))}
            </div>
          )}

          {reservationsQuery.isError && !reservationsQuery.isPending && (
            <Card className="rounded-2xl border-destructive/30">
              <CardContent className="space-y-3 p-8 text-center">
                <p className="font-medium">予約の取得に失敗しました</p>
                <Button variant="outline" className="rounded-xl" onClick={() => reservationsQuery.refetch()}>
                  リトライ
                </Button>
              </CardContent>
            </Card>
          )}

          {!reservationsQuery.isPending && !reservationsQuery.isError && reservations.length === 0 && (
            <Card className="rounded-2xl border-dashed">
              <CardContent className="p-10 text-center">
                <p className="font-medium">該当する予約がありません</p>
                <p className="mt-1 text-sm text-muted-foreground">検索条件や表示期間を変更してください。</p>
              </CardContent>
            </Card>
          )}

          {!reservationsQuery.isPending && !reservationsQuery.isError && reservations.length > 0 && viewMode === "day" && (
            <div className="overflow-hidden rounded-2xl border border-border/70">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>利用日</TableHead>
                    <TableHead>時刻</TableHead>
                    <TableHead>利用者</TableHead>
                    <TableHead>状態</TableHead>
                    <TableHead>メモ</TableHead>
                    <TableHead className="text-right">操作</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {reservations.map((reservation) => (
                    <TableRow key={reservation.id}>
                      <TableCell className="font-medium">{reservation.service_date}</TableCell>
                      <TableCell>{formatReservationTime(reservation.start_time, reservation.end_time)}</TableCell>
                      <TableCell>{reservation.client_name || "-"}</TableCell>
                      <TableCell>
                        <Badge variant="secondary" className={cn("rounded-lg", statusBadgeClass(reservation.status))}>
                          {statusLabel(reservation.status)}
                        </Badge>
                      </TableCell>
                      <TableCell className="max-w-[240px] truncate">{reservation.notes || "-"}</TableCell>
                      <TableCell className="space-x-2 text-right">
                        <ReservationFormDialog
                          mode="edit"
                          canManage={canManageReservations}
                          canOverrideCapacity={canOverrideCapacity}
                          clients={clientsQuery.data ?? []}
                          reservation={reservation}
                          triggerLabel="編集"
                          onSubmitted={refreshReservations}
                        />
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          className="rounded-xl"
                          disabled={!canManageReservations || deleteMutation.isPending}
                          onClick={async () => {
                            if (!window.confirm("この予約を削除しますか？")) return;
                            await deleteMutation.mutateAsync(reservation.id);
                          }}
                        >
                          <Trash2 className="size-4" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}

          {!reservationsQuery.isPending && !reservationsQuery.isError && reservations.length > 0 && viewMode === "week" && (
            <div className="-mx-1 overflow-x-auto pb-1">
              <div className="grid min-w-[1120px] grid-cols-7 gap-3 px-1">
                {rangeDates.map((date) => {
                  const dateKey = formatDateKey(date);
                  const dayReservations = reservationsByDate[dateKey] ?? [];
                  const capacity = reservationsQuery.data?.capacityByDate[dateKey];

                  return (
                    <Card key={dateKey} className="min-w-0 rounded-2xl border-border/70">
                      <CardHeader className="space-y-2 pb-3">
                        <div className="flex items-center justify-between gap-2">
                          <CardTitle className="truncate text-sm font-semibold">
                            {format(date, "M/d (E)", { locale: ja })}
                          </CardTitle>
                          {isSameDay(date, new Date()) && (
                            <Badge variant="secondary" className="shrink-0 rounded-lg">
                              今日
                            </Badge>
                          )}
                        </div>
                        <Badge
                          variant="outline"
                          className={cn(
                            "w-fit rounded-lg",
                            capacity?.exceeded
                              ? "border-destructive/40 text-destructive"
                              : capacity && capacity.remaining <= 0
                                ? "border-amber-500/40 text-amber-700"
                                : "text-muted-foreground",
                          )}
                        >
                          {capacity ? `${capacity.scheduled} / ${capacity.capacity}` : "- / -"}
                        </Badge>
                      </CardHeader>
                      <CardContent className="space-y-2">
                        {dayReservations.length === 0 && (
                          <p className="text-xs text-muted-foreground">予約なし</p>
                        )}

                        {dayReservations.map((reservation) => (
                          <div key={reservation.id} className="min-w-0 rounded-xl border border-border/70 p-2">
                            <p className="truncate text-xs font-medium">{reservation.client_name || "利用者未設定"}</p>
                            <p className="truncate text-xs text-muted-foreground">
                              {formatReservationTime(reservation.start_time, reservation.end_time)}
                            </p>
                            <div className="mt-1 space-y-1.5">
                              <Badge variant="secondary" className={cn("inline-flex max-w-full rounded-lg", statusBadgeClass(reservation.status))}>
                                {statusLabel(reservation.status)}
                              </Badge>
                              <div className="flex items-center justify-end gap-1">
                                <ReservationFormDialog
                                  mode="edit"
                                  canManage={canManageReservations}
                                  canOverrideCapacity={canOverrideCapacity}
                                  clients={clientsQuery.data ?? []}
                                  reservation={reservation}
                                  triggerSize="icon"
                                  triggerClassName="size-7 rounded-lg p-0"
                                  triggerIcon={<Pencil className="size-3.5" />}
                                  triggerAriaLabel="予約を編集"
                                  onSubmitted={refreshReservations}
                                />
                                <Button
                                  type="button"
                                  variant="ghost"
                                  size="icon"
                                  className="size-7 shrink-0 rounded-lg"
                                  disabled={!canManageReservations || deleteMutation.isPending}
                                  onClick={async () => {
                                    if (!window.confirm("この予約を削除しますか？")) return;
                                    await deleteMutation.mutateAsync(reservation.id);
                                  }}
                                >
                                  <Trash2 className="size-3.5" />
                                </Button>
                              </div>
                            </div>
                          </div>
                        ))}
                      </CardContent>
                    </Card>
                  );
                })}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
