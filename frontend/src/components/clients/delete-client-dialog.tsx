import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { deleteClient } from "@/lib/api";
import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";

export function DeleteClientDialog({
  id,
  canManage,
  onDeleted,
}: {
  id: number;
  canManage: boolean;
  onDeleted?: () => void;
}) {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: () => deleteClient(id),
    onSuccess: async () => {
      toast.success("利用者を削除しました");
      await queryClient.invalidateQueries({ queryKey: ["clients"] });
      await queryClient.removeQueries({ queryKey: ["client", id] });
      onDeleted?.();
    },
    onError: (error) => {
      const message =
        typeof error === "object" && error !== null && "message" in error
          ? String(error.message)
          : "削除に失敗しました";
      toast.error(message);
    },
  });

  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button variant="destructive" className="rounded-xl" disabled={!canManage}>
          削除
        </Button>
      </AlertDialogTrigger>
      <AlertDialogContent className="rounded-2xl">
        <AlertDialogHeader>
          <AlertDialogTitle>利用者を削除しますか？</AlertDialogTitle>
          <AlertDialogDescription>
            この操作は取り消せません。必要ならステータスを inactive に変更して運用してください。
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel className="rounded-xl">キャンセル</AlertDialogCancel>
          <AlertDialogAction className="rounded-xl" onClick={() => mutation.mutate()}>
            削除する
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
