export type DashboardHandoffItem = {
  care_record_id: number;
  reservation_id: number;
  client_id: number;
  client_name: string;
  recorded_by_user_id: number | null;
  recorded_by_user_name: string | null;
  handoff_note: string;
  created_at: string;
  is_new: boolean;
};

export type DashboardHandoffMeta = {
  total: number;
  window_hours: number;
  new_threshold_hours: number;
};

export type DashboardHandoffResponse = {
  handoffs: DashboardHandoffItem[];
  meta: DashboardHandoffMeta;
};
