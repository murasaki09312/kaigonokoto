import { useCallback, useEffect, useMemo, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { createReservation, updateReservation, type ApiError } from "@/lib/api";
import type { Client } from "@/types/client";
import type { Reservation, ReservationPayload, ReservationStatus } from "@/types/reservation";
import { RESERVATION_STATUS_OPTIONS } from "@/components/reservations/reservation-constants";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";

type Props = {
  mode: "create" | "edit";
  canManage: boolean;
  canOverrideCapacity: boolean;
  clients: Client[];
  reservation?: Reservation;
  triggerLabel?: string;
  onSubmitted: () => Promise<void> | void;
};

type FormValues = {
  clientId: string;
  serviceDate: string;
  startTime: string;
  endTime: string;
  status: ReservationStatus;
  notes: string;
  force: boolean;
};

function initialFormValues(reservation?: Reservation): FormValues {
  return {
    clientId: reservation?.client_id ? String(reservation.client_id) : "",
    serviceDate: reservation?.service_date ?? "",
    startTime: reservation?.start_time ?? "",
    endTime: reservation?.end_time ?? "",
    status: reservation?.status ?? "scheduled",
    notes: reservation?.notes ?? "",
    force: false,
  };
}

function toPayload(values: FormValues): ReservationPayload {
  return {
    client_id: Number(values.clientId),
    service_date: values.serviceDate,
    start_time: values.startTime.trim() ? values.startTime : null,
    end_time: values.endTime.trim() ? values.endTime : null,
    status: values.status,
    notes: values.notes.trim() ? values.notes.trim() : null,
    force: values.force,
  };
}

function errorMessage(error: unknown): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    const apiError = error as ApiError;
    if (apiError.code === "capacity_exceeded" && apiError.conflicts?.length) {
      return `定員超過: ${apiError.conflicts.join(", ")}`;
    }
    return String(apiError.message);
  }

  return "予約の保存に失敗しました";
}

export function ReservationFormDialog({
  mode,
  canManage,
  canOverrideCapacity,
  clients,
  reservation,
  triggerLabel,
  onSubmitted,
}: Props) {
  const [open, setOpen] = useState(false);
  const defaults = useMemo(() => initialFormValues(reservation), [reservation]);
  const [values, setValues] = useState<FormValues>(defaults);

  useEffect(() => {
    setValues(defaults);
  }, [defaults]);

  const closeDialog = useCallback(() => {
    setOpen(false);
    setValues(defaults);
  }, [defaults]);

  const mutation = useMutation({
    mutationFn: async (payload: ReservationPayload) => {
      if (mode === "edit" && reservation) {
        return updateReservation(reservation.id, payload);
      }
      return createReservation(payload);
    },
    onSuccess: async () => {
      toast.success(mode === "create" ? "予約を作成しました" : "予約を更新しました");
      await onSubmitted();
      closeDialog();
    },
    onError: (error) => {
      toast.error(errorMessage(error));
    },
  });

  const submit = async () => {
    if (!values.clientId) {
      toast.error("利用者を選択してください");
      return;
    }
    if (!values.serviceDate) {
      toast.error("利用日を入力してください");
      return;
    }

    await mutation.mutateAsync(toPayload(values));
  };

  const title = mode === "create" ? "単発予約の作成" : "予約の編集";

  return (
    <Dialog
      open={open}
      onOpenChange={(nextOpen) => {
        setOpen(nextOpen);
        if (!nextOpen) setValues(defaults);
      }}
    >
      <DialogTrigger asChild>
        <Button
          className="rounded-xl"
          variant={mode === "create" ? "default" : "outline"}
          disabled={!canManage}
          type="button"
        >
          {triggerLabel ?? (mode === "create" ? "新規予約" : "編集")}
        </Button>
      </DialogTrigger>

      <DialogContent className="rounded-2xl sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>定員超過時は権限がある場合のみ上書きできます。</DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium">利用者 *</label>
            <Select
              value={values.clientId}
              onValueChange={(clientId) => setValues((prev) => ({ ...prev, clientId }))}
            >
              <SelectTrigger className="rounded-xl">
                <SelectValue placeholder="利用者を選択" />
              </SelectTrigger>
              <SelectContent>
                {clients.map((client) => (
                  <SelectItem key={client.id} value={String(client.id)}>
                    {client.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <label className="text-sm font-medium">利用日 *</label>
              <Input
                type="date"
                value={values.serviceDate}
                onChange={(event) => setValues((prev) => ({ ...prev, serviceDate: event.target.value }))}
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">状態</label>
              <Select
                value={values.status}
                onValueChange={(status) => setValues((prev) => ({ ...prev, status: status as ReservationStatus }))}
              >
                <SelectTrigger className="rounded-xl">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {RESERVATION_STATUS_OPTIONS.map((statusOption) => (
                    <SelectItem key={statusOption.value} value={statusOption.value}>
                      {statusOption.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <label className="text-sm font-medium">開始時刻</label>
              <Input
                type="time"
                value={values.startTime}
                onChange={(event) => setValues((prev) => ({ ...prev, startTime: event.target.value }))}
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">終了時刻</label>
              <Input
                type="time"
                value={values.endTime}
                onChange={(event) => setValues((prev) => ({ ...prev, endTime: event.target.value }))}
              />
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">メモ</label>
            <Textarea
              rows={3}
              value={values.notes}
              onChange={(event) => setValues((prev) => ({ ...prev, notes: event.target.value }))}
            />
          </div>

          {canOverrideCapacity && (
            <label className="inline-flex items-center gap-2 text-sm font-medium">
              <input
                type="checkbox"
                checked={values.force}
                onChange={(event) => setValues((prev) => ({ ...prev, force: event.target.checked }))}
              />
              定員超過を許可する（force）
            </label>
          )}
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" className="rounded-xl" onClick={closeDialog}>
            キャンセル
          </Button>
          <Button type="button" className="rounded-xl" onClick={submit} disabled={mutation.isPending}>
            {mutation.isPending ? "保存中..." : "保存"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
