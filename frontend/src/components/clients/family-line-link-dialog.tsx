import { useMemo, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Copy, QrCode } from "lucide-react";
import { QRCodeSVG } from "qrcode.react";
import { toast } from "sonner";
import { issueFamilyLineInvitation, type ApiError } from "@/lib/api";
import type { FamilyMember } from "@/types/client";
import { Badge } from "@/components/ui/badge";
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

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

export function FamilyLineLinkDialog({
  clientId,
  familyMember,
  canManage,
  onIssued,
}: {
  clientId: number;
  familyMember: FamilyMember;
  canManage: boolean;
  onIssued?: () => Promise<void> | void;
}) {
  const [open, setOpen] = useState(false);
  const [invitationToken, setInvitationToken] = useState<string | null>(null);

  const lineBotIdRaw = String(import.meta.env.VITE_LINE_BOT_ID ?? "").trim();
  const lineBotId = lineBotIdRaw.replace(/^@/, "");

  const invitationMutation = useMutation({
    mutationFn: () => issueFamilyLineInvitation(clientId, familyMember.id),
    onSuccess: async (response) => {
      setInvitationToken(response.line_invitation_token);
      if (typeof onIssued === "function") await onIssued();
    },
    onError: (error) => {
      toast.error(formatApiError(error, "LINE連携コードの発行に失敗しました"));
    },
  });

  const lineMessageUrl = useMemo(() => {
    if (!invitationToken || !lineBotId) return null;
    const message = `連携コード:${invitationToken}`;
    return `https://line.me/R/oaMessage/${lineBotId}/?${encodeURIComponent(message)}`;
  }, [invitationToken, lineBotId]);

  const handleOpenChange = (nextOpen: boolean) => {
    setOpen(nextOpen);
    if (!nextOpen) return;
    if (!canManage) return;
    if (familyMember.line_linked) return;

    invitationMutation.mutate();
  };

  const handleCopy = async () => {
    if (!lineMessageUrl) return;

    try {
      await navigator.clipboard.writeText(lineMessageUrl);
      toast.success("LINE連携URLをコピーしました");
    } catch {
      toast.error("URLのコピーに失敗しました");
    }
  };

  const disabled = !canManage || familyMember.line_linked;

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="rounded-lg"
          disabled={disabled}
        >
          <QrCode className="mr-1 size-4" />
          LINE連携QR
        </Button>
      </DialogTrigger>
      <DialogContent className="rounded-2xl sm:max-w-md">
        <DialogHeader>
          <DialogTitle>LINE連携QRコード</DialogTitle>
          <DialogDescription>
            {familyMember.name} さんがQRを読み取り、LINEで「連携コード」を送信すると連携されます。
          </DialogDescription>
        </DialogHeader>

        {familyMember.line_linked ? (
          <div className="space-y-2 rounded-xl border border-border/70 p-4">
            <Badge variant="secondary" className="rounded-full">連携済み</Badge>
            <p className="text-sm text-muted-foreground">すでにLINE連携が完了しています。</p>
          </div>
        ) : invitationMutation.isPending ? (
          <div className="rounded-xl border border-border/70 p-4 text-sm text-muted-foreground">
            連携コードを発行しています...
          </div>
        ) : !lineBotId ? (
          <div className="rounded-xl border border-border/70 p-4 text-sm text-muted-foreground">
            `VITE_LINE_BOT_ID` が未設定です。環境変数を設定してください。
          </div>
        ) : lineMessageUrl ? (
          <div className="space-y-4">
            <div className="flex justify-center rounded-xl border border-border/70 bg-background p-3">
              <QRCodeSVG value={lineMessageUrl} size={220} />
            </div>
            <p className="break-all text-xs text-muted-foreground">{lineMessageUrl}</p>
          </div>
        ) : (
          <div className="rounded-xl border border-border/70 p-4 text-sm text-muted-foreground">
            連携コードを取得できませんでした。再度お試しください。
          </div>
        )}

        <DialogFooter>
          <Button type="button" variant="outline" className="rounded-xl" onClick={() => setOpen(false)}>
            閉じる
          </Button>
          <Button
            type="button"
            className="rounded-xl"
            onClick={handleCopy}
            disabled={!lineMessageUrl}
          >
            <Copy className="mr-1 size-4" />
            URLコピー
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
