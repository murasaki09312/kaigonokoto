import { AdminDashboard } from "@/components/dashboard/admin-dashboard";
import { DriverDashboard } from "@/components/dashboard/driver-dashboard";
import { resolveDashboardVariant } from "@/components/dashboard/dashboard-role";
import { StaffDashboard } from "@/components/dashboard/staff-dashboard";
import { useAuth } from "@/providers/auth-provider";

export function DashboardPage() {
  const { roles, permissions } = useAuth();
  const variant = resolveDashboardVariant({ roles, permissions });

  switch (variant) {
    case "admin":
      return <AdminDashboard />;
    case "driver":
      return <DriverDashboard />;
    case "staff":
    default:
      return <StaffDashboard />;
  }
}
