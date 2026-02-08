export type ClientStatus = "active" | "inactive";
export type ClientGender = "unknown" | "male" | "female" | "other";

export type Client = {
  id: number;
  tenant_id: number;
  name: string;
  kana: string | null;
  birth_date: string | null;
  gender: ClientGender;
  phone: string | null;
  address: string | null;
  emergency_contact_name: string | null;
  emergency_contact_phone: string | null;
  notes: string | null;
  status: ClientStatus;
  created_at: string;
  updated_at: string;
};

export type ClientPayload = {
  name: string;
  kana?: string;
  birth_date?: string;
  gender?: ClientGender;
  phone?: string;
  address?: string;
  emergency_contact_name?: string;
  emergency_contact_phone?: string;
  notes?: string;
  status?: ClientStatus;
};
