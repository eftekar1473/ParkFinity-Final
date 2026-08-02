// Shared pricing engine (server-authoritative).
// Strategy chain: base(durationType) * peak * weekend * demand.
// Same math the client previews, but the server is the source of truth.

export type DurationType = 'Hourly' | 'Daily' | 'Weekly' | 'Monthly' | 'Yearly';

export interface ListingRates {
  hourly_rate: number | null;
  daily_rate: number | null;
  weekly_rate: number | null;
  monthly_rate: number | null;
  yearly_rate: number | null;
}

export interface PlatformSettings {
  commission_rate: number;   // 0.10
  peak_multiplier: number;   // 1.50
  weekend_multiplier: number; // 1.20
}

export interface PriceBreakdown {
  baseRate: number;
  units: number;
  subtotal: number;      // base * units
  peakMult: number;
  weekendMult: number;
  demandMult: number;
  total: number;         // subtotal * peak * weekend * demand (rounded 2dp)
  commission: number;    // total * commission_rate
  ownerEarnings: number; // total - commission
}

// Base rate for a duration type; fall back to a coarser tier when a rate is null.
export function baseRate(rates: ListingRates, type: DurationType): number {
  const h = rates.hourly_rate ?? 0;
  const d = rates.daily_rate ?? h * 12;
  const w = rates.weekly_rate ?? d * 7;
  const m = rates.monthly_rate ?? w * 4;
  switch (type) {
    case 'Hourly': return h;
    case 'Daily': return d;
    case 'Weekly': return w;
    case 'Monthly': return m;
    case 'Yearly': return rates.yearly_rate ?? m * 12;
    default: return h;
  }
}

// Peak: demand-driven when we have 7-day density for this hour bucket, else fixed hours.
// demandCount = bookings started in same hour-of-day over last 7 days (listing_hour_demand RPC).
export function peakMultiplier(startHour: number, demandCount: number, cfgPeak: number): number {
  if (demandCount >= 3) return Math.min(cfgPeak, 1.0 + demandCount * 0.1); // busy hour -> up to cfgPeak
  const fixedPeak = (startHour >= 8 && startHour <= 10) || (startHour >= 17 && startHour <= 20);
  return fixedPeak ? cfgPeak : 1.0;
}

// Weekend: Fri(5)/Sat(6) in BD. getUTCDay(): Sun=0..Sat=6.
export function weekendMultiplier(day: number, cfgWeekend: number): number {
  return (day === 5 || day === 6) ? cfgWeekend : 1.0;
}

// Occupancy surge: low free ratio -> small bounded surge.
export function demandMultiplier(available: number, capacity: number): number {
  if (capacity <= 0) return 1.0;
  const ratio = available / capacity; // free fraction
  if (ratio <= 0.15) return 1.25;
  if (ratio <= 0.35) return 1.15;
  if (ratio <= 0.60) return 1.05;
  return 1.0;
}

export function computePrice(params: {
  rates: ListingRates;
  durationType: DurationType;
  units: number;
  start: Date;
  demandCount: number;
  available: number;
  capacity: number;
  settings: PlatformSettings;
}): PriceBreakdown {
  const { rates, durationType, units, start, demandCount, available, capacity, settings } = params;
  const rate = baseRate(rates, durationType);
  const subtotal = rate * units;
  const peakMult = peakMultiplier(start.getUTCHours(), demandCount, settings.peak_multiplier);
  const weekendMult = weekendMultiplier(start.getUTCDay(), settings.weekend_multiplier);
  const demandMult = demandMultiplier(available, capacity);
  const raw = subtotal * peakMult * weekendMult * demandMult;
  const total = Math.round(raw * 100) / 100;
  const commission = Math.round(total * settings.commission_rate * 100) / 100;
  const ownerEarnings = Math.round((total - commission) * 100) / 100;
  return { baseRate: rate, units, subtotal, peakMult, weekendMult, demandMult, total, commission, ownerEarnings };
}
