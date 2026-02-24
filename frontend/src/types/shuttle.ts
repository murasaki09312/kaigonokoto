import type { Reservation } from "@/types/reservation";

export type ShuttleDirection = "pickup" | "dropoff";
export type ShuttleLegStatus = "pending" | "boarded" | "alighted" | "cancelled";

export type ShuttleLeg = {
  id: number | null;
  tenant_id: number | null;
  shuttle_operation_id: number | null;
  direction: ShuttleDirection;
  status: ShuttleLegStatus;
  planned_at: string | null;
  actual_at: string | null;
  handled_by_user_id: number | null;
  handled_by_user_name: string | null;
  note: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type ShuttleOperation = {
  id: number | null;
  tenant_id: number;
  reservation_id: number;
  client_id: number;
  service_date: string;
  requires_pickup: boolean;
  requires_dropoff: boolean;
  pickup_leg: ShuttleLeg;
  dropoff_leg: ShuttleLeg;
  created_at: string | null;
  updated_at: string | null;
};

export type ShuttleBoardItem = {
  reservation: Reservation;
  shuttle_operation: ShuttleOperation;
};

export type ShuttleBoardMeta = {
  date: string;
  total: number;
  pickup_counts: Record<ShuttleLegStatus, number>;
  dropoff_counts: Record<ShuttleLegStatus, number>;
};

export type ShuttleBoardResponse = {
  items: ShuttleBoardItem[];
  meta: ShuttleBoardMeta;
};

export type ShuttleLegPayload = {
  status?: ShuttleLegStatus | null;
  planned_at?: string | null;
  actual_at?: string | null;
  note?: string | null;
};
