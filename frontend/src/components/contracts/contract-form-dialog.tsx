import { useCallback, useEffect, useMemo, useState } from "react";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { createContract, updateContract } from "@/lib/api";
import type { Contract, ContractPayload, ContractServices } from "@/types/contract";
import { SERVICE_OPTIONS, WEEKDAY_OPTIONS } from "@/components/contracts/contract-constants";
import { buildContractPayload } from "@/components/contracts/contract-form-payload";
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

const schema = z
  .object({
    start_on: z.string().min(1, "開始日は必須です"),
    end_on: z.string().optional(),
    weekdays: z.array(z.number().int().min(0).max(6)).min(1, "利用曜日を1つ以上選択してください"),
    services: z.record(z.string(), z.boolean()),
    service_note: z.string().optional(),
    shuttle_required: z.boolean(),
    shuttle_note: z.string().optional(),
  })
  .refine((values) => !values.end_on || values.end_on >= values.start_on, {
    path: ["end_on"],
    message: "終了日は開始日以降にしてください",
  });

type FormValues = z.infer<typeof schema>;

type Props = {
  clientId: number;
  canManage: boolean;
  mode: "create" | "edit";
  contract?: Contract;
  triggerLabel?: string;
};

function defaultServices(services?: ContractServices): ContractServices {
  return SERVICE_OPTIONS.reduce<ContractServices>((acc, option) => {
    acc[option.key] = Boolean(services?.[option.key]);
    return acc;
  }, {});
}

function toDefaultValues(contract?: Contract): FormValues {
  return {
    start_on: contract?.start_on ?? "",
    end_on: contract?.end_on ?? "",
    weekdays: contract?.weekdays ?? [],
    services: defaultServices(contract?.services),
    service_note: contract?.service_note ?? "",
    shuttle_required: contract?.shuttle_required ?? false,
    shuttle_note: contract?.shuttle_note ?? "",
  };
}

function toPayload(values: FormValues): ContractPayload {
  return buildContractPayload(values);
}

export function ContractFormDialog({
  clientId,
  canManage,
  mode,
  contract,
  triggerLabel,
}: Props) {
  const [open, setOpen] = useState(false);
  const queryClient = useQueryClient();
  const initialValues = useMemo(() => toDefaultValues(contract), [contract]);

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });

  useEffect(() => {
    form.reset(initialValues);
  }, [form, initialValues]);

  const closeDialog = useCallback(() => {
    setOpen(false);
    form.reset(initialValues);
  }, [form, initialValues]);

  const handleOpenChange = useCallback(
    (nextOpen: boolean) => {
      setOpen(nextOpen);
      if (!nextOpen) {
        form.reset(initialValues);
      }
    },
    [form, initialValues],
  );

  const mutation = useMutation({
    mutationFn: async (values: FormValues) => {
      const payload = toPayload(values);
      if (mode === "edit" && contract) {
        return updateContract(clientId, contract.id, payload);
      }

      return createContract(clientId, payload);
    },
    onSuccess: async () => {
      toast.success(mode === "create" ? "契約を作成しました" : "契約を更新しました");
      closeDialog();
      await queryClient.invalidateQueries({ queryKey: ["contracts", clientId] });
    },
    onError: (error) => {
      const message =
        typeof error === "object" && error !== null && "message" in error
          ? String(error.message)
          : "契約の保存に失敗しました";
      toast.error(message);
    },
  });

  const selectedWeekdays = form.watch("weekdays");
  const services = form.watch("services");
  const shuttleRequired = form.watch("shuttle_required");

  const onSubmit = form.handleSubmit(async (values) => {
    await mutation.mutateAsync(values);
  });

  const title = mode === "create" ? "契約/利用プランの新規作成" : "契約/利用プランの編集";

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button
          className="rounded-xl"
          variant={mode === "create" ? "default" : "outline"}
          disabled={!canManage}
          type="button"
        >
          {triggerLabel ?? (mode === "create" ? "新規契約" : "編集")}
        </Button>
      </DialogTrigger>

      <DialogContent className="max-h-[90vh] overflow-y-auto rounded-2xl sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>改定履歴として保存されます。開始日は必須です。</DialogDescription>
        </DialogHeader>

        <form className="space-y-5" onSubmit={onSubmit}>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="contract_start_on">
                開始日 *
              </label>
              <Input id="contract_start_on" type="date" {...form.register("start_on")} />
              {form.formState.errors.start_on && (
                <p className="text-xs text-destructive">{form.formState.errors.start_on.message}</p>
              )}
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="contract_end_on">
                終了日
              </label>
              <Input id="contract_end_on" type="date" {...form.register("end_on")} />
              {form.formState.errors.end_on && (
                <p className="text-xs text-destructive">{form.formState.errors.end_on.message}</p>
              )}
            </div>
          </div>

          <div className="space-y-2">
            <p className="text-sm font-medium">利用曜日 *</p>
            <div className="flex flex-wrap gap-3 rounded-xl border border-border/70 p-3">
              {WEEKDAY_OPTIONS.map((option) => (
                <label key={option.value} className="inline-flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={selectedWeekdays.includes(option.value)}
                    onChange={(event) => {
                      const nextWeekdays = event.target.checked
                        ? [...selectedWeekdays, option.value]
                        : selectedWeekdays.filter((value) => value !== option.value);
                      form.setValue("weekdays", nextWeekdays.sort((a, b) => a - b), { shouldValidate: true });
                    }}
                  />
                  {option.label}
                </label>
              ))}
            </div>
            {form.formState.errors.weekdays && (
              <p className="text-xs text-destructive">{form.formState.errors.weekdays.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <p className="text-sm font-medium">サービス内容</p>
            <div className="grid gap-2 rounded-xl border border-border/70 p-3 sm:grid-cols-2">
              {SERVICE_OPTIONS.map((option) => (
                <label key={option.key} className="inline-flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={Boolean(services[option.key])}
                    onChange={(event) => {
                      form.setValue(
                        "services",
                        {
                          ...services,
                          [option.key]: event.target.checked,
                        },
                        { shouldDirty: true },
                      );
                    }}
                  />
                  {option.label}
                </label>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="contract_service_note">
              サービスメモ
            </label>
            <Textarea id="contract_service_note" rows={3} {...form.register("service_note")} />
          </div>

          <div className="space-y-2">
            <label className="inline-flex items-center gap-2 text-sm font-medium">
              <input
                type="checkbox"
                checked={shuttleRequired}
                onChange={(event) => form.setValue("shuttle_required", event.target.checked)}
              />
              送迎あり
            </label>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="contract_shuttle_note">
              送迎メモ
            </label>
            <Textarea id="contract_shuttle_note" rows={2} {...form.register("shuttle_note")} />
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" className="rounded-xl" onClick={closeDialog}>
              キャンセル
            </Button>
            <Button type="submit" className="rounded-xl" disabled={mutation.isPending}>
              {mutation.isPending ? "保存中..." : "保存"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
