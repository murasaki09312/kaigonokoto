import { Navigate, Route, Routes } from "react-router-dom";
import { Toaster } from "@/components/ui/sonner";
import { AppShell } from "@/components/layout/app-shell";
import { ProtectedRoute, PublicOnlyRoute } from "@/components/common/route-guards";
import { LoginPage } from "@/pages/login-page";
import { DashboardPage } from "@/pages/dashboard-page";
import { UsersPage } from "@/pages/users-page";
import { ClientsPage } from "@/pages/clients-page";
import { ClientDetailPage } from "@/pages/client-detail-page";
import { ReservationsPage } from "@/pages/reservations-page";
import { TodayBoardPage } from "@/pages/today-board-page";
import { ShuttleBoardPage } from "@/pages/shuttle-board-page";
import { InvoicesPage } from "@/pages/invoices-page";
import { NotFoundPage } from "@/pages/not-found-page";

function App() {
  return (
    <>
      <Routes>
        <Route element={<PublicOnlyRoute />}>
          <Route path="/login" element={<LoginPage />} />
        </Route>

        <Route element={<ProtectedRoute />}>
          <Route path="/app" element={<AppShell />}>
            <Route index element={<DashboardPage />} />
            <Route path="today-board" element={<TodayBoardPage />} />
            <Route path="clients" element={<ClientsPage />} />
            <Route path="clients/:id" element={<ClientDetailPage />} />
            <Route path="reservations" element={<ReservationsPage />} />
            <Route path="shuttle" element={<ShuttleBoardPage />} />
            <Route path="invoices" element={<InvoicesPage />} />
            <Route path="users" element={<UsersPage />} />
          </Route>
        </Route>

        <Route path="/" element={<Navigate to="/app" replace />} />
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
      <Toaster richColors closeButton position="top-right" />
    </>
  );
}

export default App;
