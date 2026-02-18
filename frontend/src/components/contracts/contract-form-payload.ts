import type { ContractPayload, ContractServices } from "@/types/contract";

export type ContractFormPayloadInput = {
  start_on: string;
  end_on?: string;
  weekdays: number[];
  services: ContractServices;
  service_note?: string;
  shuttle_required: boolean;
  shuttle_note?: string;
};

function normalizeNullableText(value?: string): string | null {
  const nextValue = value?.trim() ?? "";
  return nextValue.length > 0 ? nextValue : null;
}

export function buildContractPayload(values: ContractFormPayloadInput): ContractPayload {
  return {
    start_on: values.start_on,
    end_on: normalizeNullableText(values.end_on),
    weekdays: values.weekdays,
    services: values.services,
    service_note: normalizeNullableText(values.service_note),
    shuttle_required: values.shuttle_required,
    shuttle_note: normalizeNullableText(values.shuttle_note),
  };
}
