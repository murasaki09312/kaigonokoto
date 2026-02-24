import type { Reservation } from "@/types/reservation";

export type AttendanceStatus = "pending" | "present" | "absent" | "cancelled";

export type Attendance = {
  id: number;
  tenant_id: number;
  reservation_id: number;
  status: AttendanceStatus;
  absence_reason: string | null;
  contacted_at: string | null;
  note: string | null;
  created_at: string;
  updated_at: string;
};

export type CareRecord = {
  id: number;
  tenant_id: number;
  reservation_id: number;
  recorded_by_user_id: number | null;
  body_temperature: string | number | null;
  systolic_bp: number | null;
  diastolic_bp: number | null;
  pulse: number | null;
  spo2: number | null;
  care_note: string | null;
  handoff_note: string | null;
  created_at: string;
  updated_at: string;
};

export type TodayBoardItem = {
  reservation: Reservation;
  attendance: Attendance | null;
  care_record: CareRecord | null;
};

export type TodayBoardMeta = {
  date: string;
  total: number;
  attendance_counts: Record<AttendanceStatus, number>;
  care_record_completed: number;
  care_record_pending: number;
};

export type TodayBoardResponse = {
  items: TodayBoardItem[];
  meta: TodayBoardMeta;
};

export type AttendancePayload = {
  status: AttendanceStatus;
  absence_reason?: string | null;
  contacted_at?: string | null;
  note?: string | null;
};

export type CareRecordPayload = {
  body_temperature?: number | null;
  systolic_bp?: number | null;
  diastolic_bp?: number | null;
  pulse?: number | null;
  spo2?: number | null;
  care_note?: string | null;
  handoff_note?: string | null;
};
