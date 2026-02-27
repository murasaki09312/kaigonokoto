// @vitest-environment jsdom
import { act, renderHook } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useCurrentTime } from "./useCurrentTime";

describe("useCurrentTime", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("updates on the provided interval and stops after unmount", () => {
    vi.useFakeTimers();

    let now = new Date("2026-02-27T10:00:00.000Z");
    const { result, unmount } = renderHook(() =>
      useCurrentTime({
        intervalMs: 1_000,
        alignToMinute: false,
        nowProvider: () => now,
      }),
    );

    expect(result.current.toISOString()).toBe("2026-02-27T10:00:00.000Z");

    act(() => {
      now = new Date("2026-02-27T10:00:01.000Z");
      vi.advanceTimersByTime(1_000);
    });
    expect(result.current.toISOString()).toBe("2026-02-27T10:00:01.000Z");

    unmount();

    act(() => {
      now = new Date("2026-02-27T10:00:02.000Z");
      vi.advanceTimersByTime(2_000);
    });
    expect(result.current.toISOString()).toBe("2026-02-27T10:00:01.000Z");
  });

  it("aligns updates to the next minute when default interval is used", () => {
    vi.useFakeTimers();

    let now = new Date("2026-02-27T10:00:30.250Z");
    const { result } = renderHook(() =>
      useCurrentTime({
        nowProvider: () => now,
      }),
    );

    expect(result.current.toISOString()).toBe("2026-02-27T10:00:30.250Z");

    act(() => {
      now = new Date("2026-02-27T10:00:59.999Z");
      vi.advanceTimersByTime(29_749);
    });
    expect(result.current.toISOString()).toBe("2026-02-27T10:00:30.250Z");

    act(() => {
      now = new Date("2026-02-27T10:01:00.000Z");
      vi.advanceTimersByTime(1);
    });
    expect(result.current.toISOString()).toBe("2026-02-27T10:01:00.000Z");

    act(() => {
      now = new Date("2026-02-27T10:02:00.000Z");
      vi.advanceTimersByTime(60_000);
    });
    expect(result.current.toISOString()).toBe("2026-02-27T10:02:00.000Z");
  });
});
