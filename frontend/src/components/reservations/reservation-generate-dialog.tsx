import { useCallback, useMemo, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { endOfMonth, format, startOfMonth } from "date-fns";
import { toast } from "sonner";
import { generateReservations, type ApiError } from "@/lib/api";
import type { ReservationGeneratePayload } from "@/types/reservation";
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
import { Textarea } from "@/components/ui/textarea";

type Props = {
  canManage: boolean;
  canOverrideCapacity: boolean;
  onSubmitted: () => Promise<void> | void;
};

type FormValues = {
  startOn: string;
  endOn: string;
  startTime: string;
  endTime: string;
  notes: string;
  force: boolean;
};

function initialFormValues(): FormValues {
  const today = new Date();

  return {
    startOn: format(startOfMonth(today), "yyyy-MM-dd"),
    endOn: format(endOfMonth(today), "yyyy-MM-dd"),
    startTime: "",
    endTime: "",
    notes: "",
    force: false,
  };
}

function toPayload(values: FormValues): ReservationGeneratePayload {
  return {
    start_on: values.startOn,
    end_on: values.endOn,
    start_time: values.startTime.trim() ? values.startTime : null,
    end_time: values.endTime.trim() ? values.endTime : null,
    notes: values.notes.trim() ? values.notes.trim() : null,
    force: values.force,
  };
}

function errorMessage(error: unknown): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    const apiError = error as ApiError;
    return String(apiError.message);
  }

  return "予約の一括生成に失敗しました";
}

function compactDateList(dates: string[]): string {
  if (dates.length <= 3) return dates.join(", ");

  return `${dates.slice(0, 3).join(", ")} ほか${dates.length - 3}日`;
}

export function ReservationGenerateDialog({ canManage, canOverrideCapacity, onSubmitted }: Props) {
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
      const messages: string[] = [];

      if (result.total > 0) {
        messages.push(`${result.total}件の予約を生成しました`);
      } else {
        messages.push("生成対象の予約はありませんでした");
      }

      if (result.existingSkippedTotal > 0) {
        messages.push(`既存予約のため ${result.existingSkippedTotal}件をスキップ`);
      }

      if (result.capacitySkippedDates.length > 0) {
        messages.push(`定員超過日: ${compactDateList(result.capacitySkippedDates)}`);
        toast.warning(messages.join(" / "));
      } else if (result.total > 0) {
        toast.success(messages.join(" / "));
      } else {
        toast.info(messages.join(" / "));
      }

      await onSubmitted();
      closeDialog();
    },
    onError: (error) => {
      toast.error(errorMessage(error));
    },
  });

  const submit = async () => {
    if (!values.startOn || !values.endOn) {
      toast.error("開始日と終了日を入力してください");
      return;
    }

    if (values.endOn < values.startOn) {
      toast.error("終了日は開始日以降にしてください");
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
          一括生成
        </Button>
      </DialogTrigger>

      <DialogContent className="max-h-[90vh] overflow-y-auto rounded-2xl sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>契約情報から予約を一括生成</DialogTitle>
          <DialogDescription>
            指定期間に有効な契約の利用曜日をもとに、対象利用者の予約をまとめて作成します。
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
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
