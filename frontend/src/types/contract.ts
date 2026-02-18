export type ContractServices = Record<string, boolean>;

export type Contract = {
  id: number;
  tenant_id: number;
  client_id: number;
  start_on: string;
  end_on: string | null;
  weekdays: number[];
  services: ContractServices;
  service_note: string | null;
  shuttle_required: boolean;
  shuttle_note: string | null;
  created_at: string;
  updated_at: string;
};

export type ContractPayload = {
  start_on: string;
  end_on: string | null;
  weekdays: number[];
  services: ContractServices;
  service_note: string | null;
  shuttle_required: boolean;
  shuttle_note: string | null;
};
