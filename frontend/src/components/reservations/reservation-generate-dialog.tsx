import { useCallback, useMemo, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { generateReservations, type ApiError } from "@/lib/api";
import type { Client } from "@/types/client";
import type { ReservationGeneratePayload } from "@/types/reservation";
import { WEEKDAY_OPTIONS } from "@/components/reservations/reservation-constants";
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
  canManage: boolean;
  canOverrideCapacity: boolean;
  clients: Client[];
  onSubmitted: () => Promise<void> | void;
};

type FormValues = {
  clientId: string;
  startOn: string;
  endOn: string;
  weekdays: number[];
  startTime: string;
  endTime: string;
  notes: string;
  force: boolean;
};

function initialFormValues(): FormValues {
  return {
    clientId: "",
    startOn: "",
    endOn: "",
    weekdays: [1],
    startTime: "",
    endTime: "",
    notes: "",
    force: false,
  };
}

function toPayload(values: FormValues): ReservationGeneratePayload {
  return {
    client_id: Number(values.clientId),
    start_on: values.startOn,
    end_on: values.endOn,
    weekdays: values.weekdays,
    start_time: values.startTime.trim() ? values.startTime : null,
    end_time: values.endTime.trim() ? values.endTime : null,
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

  return "繰り返し予約の生成に失敗しました";
}

export function ReservationGenerateDialog({
  canManage,
  canOverrideCapacity,
  clients,
  onSubmitted,
}: Props) {
  const [open, setOpen] = useState(false);
  const initial = useMemo(() => initialFormValues(), []);
  const [values, setValues] = useState<FormValues>(initial);

  const closeDialog = useCallback(() => {
    setOpen(false);
    setValues(initial);
  }, [initial]);

  const mutation = useMutation({
    mutationFn: generateReservations,
    onSuccess: async (result) => {
      toast.success(`${result.total}件の予約を生成しました`);
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
    if (!values.startOn || !values.endOn) {
      toast.error("開始日と終了日を入力してください");
      return;
    }
    if (values.weekdays.length === 0) {
      toast.error("曜日を1つ以上選択してください");
      return;
    }

    await mutation.mutateAsync(toPayload(values));
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(nextOpen) => {
        setOpen(nextOpen);
        if (!nextOpen) setValues(initial);
      }}
    >
      <DialogTrigger asChild>
        <Button className="rounded-xl" variant="outline" disabled={!canManage} type="button">
          繰り返し生成
        </Button>
      </DialogTrigger>

      <DialogContent className="max-h-[90vh] overflow-y-auto rounded-2xl sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>週次繰り返し予約の生成</DialogTitle>
          <DialogDescription>曜日と期間を指定してまとめて予約を作成します。</DialogDescription>
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
              <label className="text-sm font-medium">開始日 *</label>
              <Input
                type="date"
                value={values.startOn}
                onChange={(event) => setValues((prev) => ({ ...prev, startOn: event.target.value }))}
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">終了日 *</label>
              <Input
                type="date"
                value={values.endOn}
                onChange={(event) => setValues((prev) => ({ ...prev, endOn: event.target.value }))}
              />
            </div>
          </div>

          <div className="space-y-2">
            <p className="text-sm font-medium">曜日 *</p>
            <div className="flex flex-wrap gap-3 rounded-xl border border-border/70 p-3">
              {WEEKDAY_OPTIONS.map((weekday) => (
                <label key={weekday.value} className="inline-flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={values.weekdays.includes(weekday.value)}
                    onChange={(event) => {
                      setValues((prev) => {
                        const weekdays = event.target.checked
                          ? [...prev.weekdays, weekday.value]
                          : prev.weekdays.filter((value) => value !== weekday.value);

                        return { ...prev, weekdays: weekdays.sort((a, b) => a - b) };
                      });
                    }}
                  />
                  {weekday.label}
                </label>
              ))}
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
            {mutation.isPending ? "生成中..." : "生成"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
