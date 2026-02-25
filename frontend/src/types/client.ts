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
  line_notification_available: boolean;
  line_linked_family_count: number;
  line_enabled_family_count: number;
  created_at: string;
  updated_at: string;
};

export type FamilyMember = {
  id: number;
  tenant_id: number;
  client_id: number;
  name: string;
  relationship: string | null;
  primary_contact: boolean;
  active: boolean;
  line_enabled: boolean;
  line_linked: boolean;
  line_invitation_token_generated_at: string | null;
  created_at: string;
  updated_at: string;
};

export type FamilyLineInvitation = {
  family_member: FamilyMember;
  line_invitation_token: string;
  line_invitation_token_generated_at: string | null;
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
