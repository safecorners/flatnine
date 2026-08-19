import type {
  DetectionConfig,
  HazardWindow,
  Severity,
  WindowFeature,
} from "./types";

export const SEVERITY_COLORS: Record<Severity, string> = {
  ok: "#16a34a",
  warn: "#f59e0b",
  danger: "#dc2626",
};

export function severityOf(
  f: Pick<WindowFeature, "rms" | "peak">,
  cfg: DetectionConfig | undefined
): Severity {
  if (!cfg) return "ok";
  if (f.rms >= cfg.danger_rms || f.peak >= cfg.impact_peak) return "danger";
  if (f.rms >= cfg.warn_rms) return "warn";
  return "ok";
}

export function haversineMeters(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number }
): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

/** 좌표가 있는 연속 지점들의 트랙 길이 (m) */
export function trackDistanceMeters(
  points: { lat: number | null; lng: number | null }[]
): number {
  let total = 0;
  let prev: { lat: number; lng: number } | null = null;
  for (const p of points) {
    if (p.lat == null || p.lng == null) continue;
    const cur = { lat: p.lat, lng: p.lng };
    if (prev) {
      const d = haversineMeters(prev, cur);
      if (d < 100) total += d; // GPS 점프(>100m/s)는 거리에서 제외
    }
    prev = cur;
  }
  return total;
}

export interface HazardCluster {
  lat: number;
  lng: number;
  severity: "warn" | "danger";
  maxRms: number;
  maxPeak: number;
  windowCount: number;
  sessionId: string;
  startChunk: number;
}

/** 같은 세션의 인접 chunk_index 위험 윈도우를 하나의 지점으로 병합 */
export function clusterHazards(hazards: HazardWindow[]): HazardCluster[] {
  const sorted = [...hazards]
    .filter((h) => h.lat != null && h.lng != null)
    .sort((a, b) =>
      a.session_id === b.session_id
        ? a.chunk_index - b.chunk_index
        : a.session_id.localeCompare(b.session_id)
    );

  const clusters: HazardCluster[] = [];
  let group: HazardWindow[] = [];

  const flush = () => {
    if (group.length === 0) return;
    const mid = group[Math.floor(group.length / 2)];
    clusters.push({
      lat: mid.lat!,
      lng: mid.lng!,
      severity: group.some((g) => g.severity === "danger") ? "danger" : "warn",
      maxRms: Math.max(...group.map((g) => g.rms)),
      maxPeak: Math.max(...group.map((g) => g.peak)),
      windowCount: group.length,
      sessionId: group[0].session_id,
      startChunk: group[0].chunk_index,
    });
    group = [];
  };

  for (const h of sorted) {
    const last = group[group.length - 1];
    if (
      last &&
      (h.session_id !== last.session_id ||
        h.chunk_index - last.chunk_index > 2)
    ) {
      flush();
    }
    group.push(h);
  }
  flush();
  return clusters;
}

/** 히트맵 강도: 해당 mode의 danger 임계값 대비 RMS 비율 (0.3~1로 클램프) */
export function heatIntensity(
  h: Pick<HazardWindow, "rms" | "mode">,
  configs: Map<string, DetectionConfig>
): number {
  const danger = configs.get(h.mode)?.danger_rms;
  if (!danger || danger <= 0) return 0.6;
  return Math.min(1, Math.max(0.3, h.rms / danger));
}

export function formatDuration(startIso: string, endIso: string): string {
  const secs = Math.max(
    0,
    Math.round((+new Date(endIso) - +new Date(startIso)) / 1000)
  );
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}분 ${s.toString().padStart(2, "0")}초`;
}

export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  return `${d.getMonth() + 1}/${d.getDate()} ${d
    .getHours()
    .toString()
    .padStart(2, "0")}:${d.getMinutes().toString().padStart(2, "0")}`;
}
