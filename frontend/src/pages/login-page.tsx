import { useState } from "react";
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useLocation, useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { useAuth } from "@/providers/auth-provider";
import { resolvePostLoginPath } from "@/lib/post-login-path";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

const schema = z.object({
  tenant_slug: z.string().min(1, "tenant_slug は必須です"),
  email: z.string().email("メールアドレス形式で入力してください"),
  password: z.string().min(1, "password は必須です"),
});

type FormValues = z.infer<typeof schema>;
type LoginLocationState = {
  from?: string;
};

export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { login } = useAuth();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      tenant_slug: "demo-dayservice",
      email: "admin@example.com",
      password: "Password123!",
    },
  });

  const onSubmit = async (values: FormValues) => {
    setIsSubmitting(true);
    try {
      const auth = await login(values);
      toast.success("ログインしました");
      navigate(
        resolvePostLoginPath({
          requestedPath: (location.state as LoginLocationState | null)?.from,
          permissions: auth.permissions,
        }),
        { replace: true },
      );
    } catch (error) {
      const message =
        typeof error === "object" && error !== null && "message" in error
          ? String(error.message)
          : "ログインに失敗しました";
      toast.error(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-[radial-gradient(circle_at_top,_hsl(var(--muted))_0%,_transparent_50%),linear-gradient(180deg,hsl(var(--background)),hsl(var(--muted))/35)] px-4 py-10">
      <Card className="w-full max-w-md rounded-2xl border-border/70 bg-card/90 shadow-xl shadow-black/5 backdrop-blur-sm transition-shadow duration-300">
        <CardHeader className="space-y-2 text-center">
          <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">kaigonokoto</p>
          <CardTitle className="text-2xl tracking-tight">Welcome back</CardTitle>
          <CardDescription>デイサービス運営を、軽く。</CardDescription>
        </CardHeader>
        <CardContent>
          <form className="space-y-4" onSubmit={form.handleSubmit(onSubmit)}>
            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="tenant_slug">
                Tenant Slug
              </label>
              <Input id="tenant_slug" {...form.register("tenant_slug")} placeholder="demo-dayservice" />
              {form.formState.errors.tenant_slug && (
                <p className="text-xs text-destructive">{form.formState.errors.tenant_slug.message}</p>
              )}
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="email">
                Email
              </label>
              <Input id="email" type="email" {...form.register("email")} placeholder="admin@example.com" />
              {form.formState.errors.email && (
                <p className="text-xs text-destructive">{form.formState.errors.email.message}</p>
              )}
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="password">
                Password
              </label>
              <Input id="password" type="password" {...form.register("password")} placeholder="********" />
              {form.formState.errors.password && (
                <p className="text-xs text-destructive">{form.formState.errors.password.message}</p>
              )}
            </div>

            <Button type="submit" className="w-full rounded-xl" disabled={isSubmitting}>
              {isSubmitting ? "Signing in..." : "ログイン"}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
