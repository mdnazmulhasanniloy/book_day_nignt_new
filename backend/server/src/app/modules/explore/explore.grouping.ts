/**
 * Day buckets for GET /explore?group=day (T-035, CR-09).
 * Buckets are computed from the LOCAL calendar date and weekday of the event start in an IANA time
 * zone (Intl), never with fixed hour offsets, so daylight-saving changes do not shift them.
 */

export const DAY_BUCKETS = ['Today', 'Tomorrow', 'This Weekend', 'Upcoming'] as const;
export type DayBucket = (typeof DAY_BUCKETS)[number];

/** Local weekend starts on Friday at this hour (inclusive). Ends at the end of Sunday. */
const WEEKEND_START_HOUR = 18;

const formatters = new Map<string, Intl.DateTimeFormat>();
const formatterFor = (timeZone: string): Intl.DateTimeFormat => {
  let f = formatters.get(timeZone);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hourCycle: 'h23',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
    });
    formatters.set(timeZone, f);
  }
  return f;
};

const MS_PER_DAY = 86_400_000;

/** Local calendar parts of an instant in a zone. `dayNumber` counts days since 1970-01-01 (local date). */
const localParts = ({ date, timeZone }: { date: Date; timeZone: string }) => {
  const parts = formatterFor(timeZone).formatToParts(date);
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value);
  const year = get('year');
  const month = get('month');
  const day = get('day');
  const hour = get('hour');
  const dayNumber = Math.round(Date.UTC(year, month - 1, day) / MS_PER_DAY);
  // 1970-01-01 was a Thursday; 0 = Sunday.
  const weekday = (((dayNumber + 4) % 7) + 7) % 7;
  return { year, month, day, hour, dayNumber, weekday };
};

const pad = (n: number, w = 2) => String(n).padStart(w, '0');

/** Local calendar date (YYYY-MM-DD) of an instant in a zone. */
export const localDateString = ({ date, timeZone }: { date: Date; timeZone: string }): string => {
  const p = localParts({ date, timeZone });
  return `${pad(p.year, 4)}-${pad(p.month)}-${pad(p.day)}`;
};

/**
 * Bucket of an event by the local day of its START, in `timeZone`.
 * Today = same local date as `now` (an event that started on an earlier local day and is still
 * running is also Today); Tomorrow = next local date; This Weekend = from Friday 18:00 to the end
 * of Sunday of the local Monday to Sunday week that contains `now`; everything else is Upcoming.
 * Today and Tomorrow win over This Weekend.
 */
export const classifyEventDay = ({
  startAt,
  now,
  timeZone,
}: {
  startAt: Date;
  now: Date;
  timeZone: string;
}): DayBucket => {
  const start = localParts({ date: startAt, timeZone });
  const today = localParts({ date: now, timeZone });
  if (start.dayNumber <= today.dayNumber) return 'Today';
  if (start.dayNumber === today.dayNumber + 1) return 'Tomorrow';

  const weekStart = today.dayNumber - ((today.weekday + 6) % 7); // Monday of the local week
  const inThisWeek = start.dayNumber >= weekStart && start.dayNumber < weekStart + 7;
  const inWeekend =
    start.weekday === 6 ||
    start.weekday === 0 ||
    (start.weekday === 5 && start.hour >= WEEKEND_START_HOUR);
  return inThisWeek && inWeekend ? 'This Weekend' : 'Upcoming';
};

export interface IDayGroup<T> {
  label: DayBucket;
  date: string;
  items: T[];
}

/**
 * Groups items (already in chronological order) into the four buckets, in fixed bucket order.
 * Empty buckets are omitted. `date` is the local date of the first item of the bucket.
 */
export const groupItemsByDay = <T extends { startAt: Date; timeZone: string }>({
  items,
  now,
}: {
  items: T[];
  now: Date;
}): IDayGroup<T>[] => {
  const byBucket = new Map<DayBucket, IDayGroup<T>>();
  for (const item of items) {
    const label = classifyEventDay({ startAt: item.startAt, now, timeZone: item.timeZone });
    let group = byBucket.get(label);
    if (!group) {
      group = { label, date: localDateString({ date: item.startAt, timeZone: item.timeZone }), items: [] };
      byBucket.set(label, group);
    }
    group.items.push(item);
  }
  return DAY_BUCKETS.flatMap((b) => {
    const g = byBucket.get(b);
    return g ? [g] : [];
  });
};
