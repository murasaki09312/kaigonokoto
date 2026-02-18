export type ReservationStatus = "scheduled" | "cancelled" | "completed";

export type Reservation = {
  id: number;
  tenant_id: number;
  client_id: number;
  client_name: string | null;
  service_date: string;
  start_time: string | null;
  end_time: string | null;
  status: ReservationStatus;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export type CapacityByDate = Record<
  string,
  {
    scheduled: number;
    capacity: number;
    remaining: number;
    exceeded: boolean;
  }
>;

export type ReservationPayload = {
  client_id: number;
  service_date: string;
  start_time?: string | null;
  end_time?: string | null;
  status?: ReservationStatus;
  notes?: string | null;
  force?: boolean;
};

export type ReservationGeneratePayload = {
  client_id: number;
  start_on: string;
  end_on: string;
  weekdays: number[];
  start_time?: string | null;
  end_time?: string | null;
  status?: ReservationStatus;
  notes?: string | null;
  force?: boolean;
};
