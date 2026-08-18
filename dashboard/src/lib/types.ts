export type Mode = "walk" | "wheelchair" | "stroller";
export type Severity = "ok" | "warn" | "danger";

export interface Session {
  id: string;
  created_at: string;
  started_at: string;
  ended_at: string;
  mode: Mode;
  device_model: string | null;
  platform: string | null;
  sample_rate_hz: number | null;
  chunk_count: number;
}

export interface WindowFeature {
  session_id: string;
  chunk_index: number;
  ts: string;
  lat: number | null;
  lng: number | null;
  n: number;
  rms: number;
  peak: number;
}

export interface HazardWindow {
  session_id: string;
  chunk_index: number;
  ts: string;
  lat: number | null;
  lng: number | null;
  rms: number;
  peak: number;
  mode: Mode;
  severity: "warn" | "danger";
}

export interface DetectionConfig {
  mode: Mode;
  warn_rms: number;
  danger_rms: number;
  impact_peak: number;
}

export const MODE_LABELS: Record<Mode, string> = {
  wheelchair: "휠체어",
  stroller: "유모차",
  walk: "보행",
};
