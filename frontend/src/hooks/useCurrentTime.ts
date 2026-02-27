import { useEffect, useState } from "react";

type UseCurrentTimeOptions = {
  intervalMs?: number;
  nowProvider?: () => Date;
  alignToMinute?: boolean;
};

const DEFAULT_INTERVAL_MS = 60_000;
const defaultNowProvider = () => new Date();

export function useCurrentTime(options?: UseCurrentTimeOptions): Date {
  const intervalMs = options?.intervalMs ?? DEFAULT_INTERVAL_MS;
  const nowProvider = options?.nowProvider ?? defaultNowProvider;
  const alignToMinute = options?.alignToMinute ?? true;
  const [currentTime, setCurrentTime] = useState<Date>(() => nowProvider());

  useEffect(() => {
    let intervalId: ReturnType<typeof setInterval> | null = null;
    let timeoutId: ReturnType<typeof setTimeout> | null = null;

    const updateCurrentTime = () => {
      setCurrentTime(nowProvider());
    };

    if (alignToMinute && intervalMs === DEFAULT_INTERVAL_MS) {
      const now = nowProvider();
      const millisecondsUntilNextMinute = (60 - now.getSeconds()) * 1000 - now.getMilliseconds();

      timeoutId = setTimeout(() => {
        updateCurrentTime();
        intervalId = setInterval(updateCurrentTime, intervalMs);
      }, millisecondsUntilNextMinute);
    } else {
      intervalId = setInterval(updateCurrentTime, intervalMs);
    }

    return () => {
      if (timeoutId !== null) clearTimeout(timeoutId);
      if (intervalId !== null) clearInterval(intervalId);
    };
  }, [alignToMinute, intervalMs, nowProvider]);

  return currentTime;
}
