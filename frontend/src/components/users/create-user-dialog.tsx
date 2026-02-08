import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { createUser } from "@/lib/api";
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
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

const schema = z.object({
  name: z.string().optional(),
  email: z.string().email("メールアドレス形式で入力してください"),
  password: z.string().min(8, "8文字以上で入力してください"),
});

type FormValues = z.infer<typeof schema>;

export function CreateUserDialog({ canManage }: { canManage: boolean }) {
  const [open, setOpen] = useState(false);
  const queryClient = useQueryClient();

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { name: "", email: "", password: "" },
  });

  const mutation = useMutation({
    mutationFn: createUser,
    onSuccess: async () => {
      toast.success("ユーザーを作成しました");
      setOpen(false);
      form.reset();
      await queryClient.invalidateQueries({ queryKey: ["users"] });
    },
    onError: (error) => {
      const message =
        typeof error === "object" && error !== null && "message" in error
          ? String(error.message)
          : "ユーザー作成に失敗しました";
      toast.error(message);
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    await mutation.mutateAsync(values);
  });

  if (!canManage) {
    return (
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <span>
              <Button className="rounded-xl" disabled>
                新規ユーザー
              </Button>
            </span>
          </TooltipTrigger>
          <TooltipContent>users:manage 権限が必要です</TooltipContent>
        </Tooltip>
      </TooltipProvider>
    );
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="rounded-xl">新規ユーザー</Button>
      </DialogTrigger>

      <DialogContent className="rounded-2xl">
        <DialogHeader>
          <DialogTitle>新規ユーザーを作成</DialogTitle>
          <DialogDescription>現在のテナント配下でユーザーを作成します。</DialogDescription>
        </DialogHeader>

        <form className="space-y-4" onSubmit={onSubmit}>
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="user_name">
              Name
            </label>
            <Input id="user_name" {...form.register("name")} placeholder="山田 花子" />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="user_email">
              Email
            </label>
            <Input id="user_email" type="email" {...form.register("email")} placeholder="user@example.com" />
            {form.formState.errors.email && (
              <p className="text-xs text-destructive">{form.formState.errors.email.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="user_password">
              Password
            </label>
            <Input id="user_password" type="password" {...form.register("password")} placeholder="Password123!" />
            {form.formState.errors.password && (
              <p className="text-xs text-destructive">{form.formState.errors.password.message}</p>
            )}
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" className="rounded-xl" onClick={() => setOpen(false)}>
              キャンセル
            </Button>
            <Button type="submit" className="rounded-xl" disabled={mutation.isPending}>
              {mutation.isPending ? "作成中..." : "作成"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
