import { useMemo, useState, type ComponentType } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import {
  CalendarCheck2,
  Car,
  ClipboardCheck,
  ClipboardList,
  Home,
  Menu,
  Search,
  Settings,
  Users,
  Wallet,
} from "lucide-react";
import { useAuth } from "@/providers/auth-provider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { Badge } from "@/components/ui/badge";
import { ThemeToggle } from "@/components/common/theme-toggle";
import { cn } from "@/lib/utils";

type NavItem = {
  label: string;
  to?: string;
  icon: ComponentType<{ className?: string }>;
  disabled?: boolean;
};

const coreNav: NavItem[] = [
  { label: "ダッシュボード", to: "/app", icon: Home },
  { label: "当日ボード", to: "/app/today-board", icon: ClipboardList },
  { label: "利用者", to: "/app/clients", icon: Users },
  { label: "予約", to: "/app/reservations", icon: CalendarCheck2 },
  { label: "送迎", to: "/app/shuttle", icon: Car },
  { label: "記録", to: "/app/records", icon: ClipboardCheck },
  { label: "請求", to: "/app/invoices", icon: Wallet },
  { label: "ユーザー一覧", to: "/app/users", icon: Users },
];

const pageTitleMap: Record<string, string> = {
  "/app": "ダッシュボード",
  "/app/today-board": "当日ボード",
  "/app/clients": "利用者",
  "/app/reservations": "予約",
  "/app/shuttle": "送迎",
  "/app/records": "記録",
  "/app/invoices": "請求",
  "/app/users": "ユーザー一覧",
  "/app/settings/users": "スタッフ管理",
  "/app/settings/facility": "事業所設定",
};

function SidebarItems({
  onNavigate,
  showFacilitySettings,
  showStaffManagement,
}: {
  onNavigate?: () => void;
  showFacilitySettings: boolean;
  showStaffManagement: boolean;
}) {
  const items = useMemo(() => {
    const baseItems = [ ...coreNav ];
    if (showStaffManagement) {
      baseItems.push({ label: "スタッフ管理", to: "/app/settings/users", icon: Settings });
    }
    if (showFacilitySettings) {
      baseItems.push({ label: "事業所設定", to: "/app/settings/facility", icon: Settings });
    }
    return baseItems;
  }, [showStaffManagement, showFacilitySettings]);

  return (
    <nav className="space-y-1 px-2">
      {items.map((item) => {
        const Icon = item.icon;

        if (item.disabled || !item.to) {
          return (
            <button
              key={item.label}
              type="button"
              disabled
              className="flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm text-muted-foreground opacity-70"
            >
              <Icon className="size-4" />
              <span>{item.label}</span>
            </button>
          );
        }

        return (
          <NavLink
            key={item.label}
            to={item.to}
            onClick={onNavigate}
            className={({ isActive }) =>
              cn(
                "flex items-center gap-2 rounded-xl px-3 py-2 text-sm transition-colors",
                isActive
                  ? "bg-primary/10 text-foreground"
                  : "text-muted-foreground hover:bg-muted hover:text-foreground",
              )
            }
          >
            <Icon className="size-4" />
            <span>{item.label}</span>
          </NavLink>
        );
      })}
    </nav>
  );
}

export function AppShell() {
  const [isOpen, setIsOpen] = useState(false);
  const { pathname } = useLocation();
  const { user, permissions, logout } = useAuth();
  const navigate = useNavigate();

  const pageTitle = pathname.startsWith("/app/clients/")
    ? "利用者詳細"
    : pathname.startsWith("/app/invoices/")
      ? "請求書プレビュー"
    : (pageTitleMap[pathname] ?? "kaigonokoto");

  return (
    <div className="min-h-screen bg-gradient-to-b from-muted/60 to-background print:bg-white">
      <div className="mx-auto grid min-h-screen w-full max-w-[1600px] lg:grid-cols-[250px_1fr]">
        <aside className="hidden border-r border-border/80 bg-background/70 px-3 py-4 backdrop-blur-sm print:hidden lg:block">
          <div className="mb-6 flex items-center justify-between px-2">
            <div>
              <p className="text-sm font-semibold tracking-tight">kaigonokoto</p>
              <p className="text-xs text-muted-foreground">Operations Console</p>
            </div>
            <Badge variant="secondary" className="rounded-lg">MVP</Badge>
          </div>
          <SidebarItems
            showFacilitySettings={permissions.includes("tenants:manage")}
            showStaffManagement={permissions.includes("users:manage")}
          />
        </aside>

        <div className="flex min-h-screen flex-col">
          <header className="sticky top-0 z-20 border-b border-border/80 bg-background/80 px-4 py-3 backdrop-blur supports-[backdrop-filter]:bg-background/60 print:hidden lg:px-8">
            <div className="flex items-center gap-3">
              <Sheet open={isOpen} onOpenChange={setIsOpen}>
                <SheetTrigger asChild>
                  <Button variant="outline" size="icon" className="rounded-xl lg:hidden">
                    <Menu className="size-4" />
                  </Button>
                </SheetTrigger>
                <SheetContent side="left" className="w-72 p-0">
                  <div className="border-b px-4 py-4">
                    <p className="font-semibold">kaigonokoto</p>
                    <p className="text-xs text-muted-foreground">Operations Console</p>
                  </div>
                  <div className="py-4">
                    <SidebarItems
                      showFacilitySettings={permissions.includes("tenants:manage")}
                      showStaffManagement={permissions.includes("users:manage")}
                      onNavigate={() => setIsOpen(false)}
                    />
                  </div>
                </SheetContent>
              </Sheet>

              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold tracking-tight lg:text-base">{pageTitle}</p>
                <p className="text-xs text-muted-foreground">デイサービス運営を、軽く。</p>
              </div>

              <div className="hidden w-full max-w-sm items-center lg:flex">
                <Search className="relative left-8 z-10 size-4 text-muted-foreground" />
                <Input className="pl-10" placeholder="検索（ダミー）" />
              </div>

              <ThemeToggle />

              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline" className="rounded-xl">
                    {user?.name || user?.email || "User"}
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-56 rounded-xl">
                  <DropdownMenuLabel>
                    <p className="text-sm font-medium">{user?.name || "No Name"}</p>
                    <p className="text-xs text-muted-foreground">{user?.email}</p>
                  </DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem
                    onClick={async () => {
                      await logout();
                      navigate("/login", { replace: true });
                    }}
                  >
                    ログアウト
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </header>

          <main className="flex-1 px-4 py-6 print:p-0 lg:px-8 lg:py-8">
            <div className="mx-auto w-full max-w-7xl print:max-w-none">
              <Outlet />
            </div>
          </main>

          <footer className="px-4 pb-4 print:hidden lg:px-8">
            <Separator />
            <p className="pt-3 text-xs text-muted-foreground">kaigonokoto · API mode MVP</p>
          </footer>
        </div>
      </div>
    </div>
  );
}
