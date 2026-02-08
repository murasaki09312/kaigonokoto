import { useEffect, useState } from "react";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { createClient, updateClient } from "@/lib/api";
import type { Client } from "@/types/client";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

const schema = z.object({
  name: z.string().min(1, "名前は必須です"),
  kana: z.string().optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  emergency_contact_name: z.string().optional(),
  emergency_contact_phone: z.string().optional(),
  notes: z.string().optional(),
  status: z.enum(["active", "inactive"]),
  gender: z.enum(["unknown", "male", "female", "other"]),
});

type FormValues = z.infer<typeof schema>;

const defaultValues: FormValues = {
  name: "",
  kana: "",
  phone: "",
  address: "",
  emergency_contact_name: "",
  emergency_contact_phone: "",
  notes: "",
  status: "active",
  gender: "unknown",
};

type Props = {
  canManage: boolean;
  mode: "create" | "edit";
  client?: Client;
  triggerLabel?: string;
  onFinished?: (client: Client) => void;
};

export function ClientFormDialog({
  canManage,
  mode,
  client,
  triggerLabel,
  onFinished,
}: Props) {
  const [open, setOpen] = useState(false);
  const queryClient = useQueryClient();

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues,
  });

  useEffect(() => {
    if (!client) {
      form.reset(defaultValues);
      return;
    }

    form.reset({
      name: client.name,
      kana: client.kana ?? "",
      phone: client.phone ?? "",
      address: client.address ?? "",
      emergency_contact_name: client.emergency_contact_name ?? "",
      emergency_contact_phone: client.emergency_contact_phone ?? "",
      notes: client.notes ?? "",
      status: client.status,
      gender: client.gender,
    });
  }, [client, form]);

  const mutation = useMutation({
    mutationFn: async (values: FormValues) => {
      if (mode === "edit" && client) {
        return updateClient(client.id, values);
      }
      return createClient(values);
    },
    onSuccess: async (saved) => {
      toast.success(mode === "create" ? "利用者を作成しました" : "利用者を更新しました");
      setOpen(false);
      await queryClient.invalidateQueries({ queryKey: ["clients"] });
      if (client) {
        await queryClient.invalidateQueries({ queryKey: ["client", client.id] });
      }
      onFinished?.(saved);
    },
    onError: (error) => {
      const message =
        typeof error === "object" && error !== null && "message" in error
          ? String(error.message)
          : "保存に失敗しました";
      toast.error(message);
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    await mutation.mutateAsync(values);
  });

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="rounded-xl" variant={mode === "create" ? "default" : "outline"} disabled={!canManage}>
          {triggerLabel ?? (mode === "create" ? "新規利用者" : "編集")}
        </Button>
      </DialogTrigger>

      <DialogContent className="max-h-[90vh] overflow-y-auto rounded-2xl">
        <DialogHeader>
          <DialogTitle>{mode === "create" ? "新規利用者" : "利用者編集"}</DialogTitle>
          <DialogDescription>利用者情報を入力してください。</DialogDescription>
        </DialogHeader>

        <form className="space-y-4" onSubmit={onSubmit}>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-medium" htmlFor="client_name">
                名前 *
              </label>
              <Input id="client_name" {...form.register("name")} />
              {form.formState.errors.name && (
                <p className="text-xs text-destructive">{form.formState.errors.name.message}</p>
              )}
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="client_kana">
                かな
              </label>
              <Input id="client_kana" {...form.register("kana")} />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="client_phone">
                電話
              </label>
              <Input id="client_phone" {...form.register("phone")} />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">ステータス</label>
              <Select value={form.watch("status")} onValueChange={(v) => form.setValue("status", v as FormValues["status"])}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">active</SelectItem>
                  <SelectItem value="inactive">inactive</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">性別</label>
              <Select value={form.watch("gender")} onValueChange={(v) => form.setValue("gender", v as FormValues["gender"])}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="unknown">unknown</SelectItem>
                  <SelectItem value="male">male</SelectItem>
                  <SelectItem value="female">female</SelectItem>
                  <SelectItem value="other">other</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-medium" htmlFor="client_address">
                住所
              </label>
              <Input id="client_address" {...form.register("address")} />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="client_emergency_name">
                緊急連絡先名
              </label>
              <Input id="client_emergency_name" {...form.register("emergency_contact_name")} />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="client_emergency_phone">
                緊急連絡先電話
              </label>
              <Input id="client_emergency_phone" {...form.register("emergency_contact_phone")} />
            </div>

            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-medium" htmlFor="client_notes">
                備考
              </label>
              <Textarea id="client_notes" rows={4} {...form.register("notes")} />
            </div>
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" className="rounded-xl" onClick={() => setOpen(false)}>
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
