export type FacilityScale = "normal" | "large_1" | "large_2";

export type FacilityScaleOption = {
  value: FacilityScale;
  label: string;
};

export type FacilitySetting = {
  tenant_id: number;
  city_name: string | null;
  facility_scale: FacilityScale | null;
  city_options: string[];
  facility_scale_options: FacilityScaleOption[];
};
