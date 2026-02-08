import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";

export function NotFoundPage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-muted/40 px-4 text-center">
      <p className="text-4xl font-semibold tracking-tight">404</p>
      <p className="text-muted-foreground">ページが見つかりません。</p>
      <Button asChild className="rounded-xl">
        <Link to="/app">ダッシュボードへ戻る</Link>
      </Button>
    </div>
  );
}
