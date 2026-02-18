import { describe, expect, it } from "vitest";
import { buildContractPayload } from "./contract-form-payload";

describe("buildContractPayload", () => {
  it("maps blank optional fields to null", () => {
    expect(
      buildContractPayload({
        start_on: "2026-03-01",
        end_on: "",
        weekdays: [1, 3],
        services: { meal: true },
        service_note: "",
        shuttle_required: false,
        shuttle_note: "   ",
      }),
    ).toEqual({
      start_on: "2026-03-01",
      end_on: null,
      weekdays: [1, 3],
      services: { meal: true },
      service_note: null,
      shuttle_required: false,
      shuttle_note: null,
    });
  });

  it("preserves filled optional fields", () => {
    expect(
      buildContractPayload({
        start_on: "2026-03-01",
        end_on: "2026-03-31",
        weekdays: [1, 3],
        services: { meal: true },
        service_note: "変更メモ",
        shuttle_required: true,
        shuttle_note: "朝のみ",
      }),
    ).toEqual({
      start_on: "2026-03-01",
      end_on: "2026-03-31",
      weekdays: [1, 3],
      services: { meal: true },
      service_note: "変更メモ",
      shuttle_required: true,
      shuttle_note: "朝のみ",
    });
  });
});
