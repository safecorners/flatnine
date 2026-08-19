"use client";

import dynamic from "next/dynamic";
import { use, useEffect, useState } from "react";

import RmsTimeline from "../../../components/RmsTimeline";
import SeverityLegend from "../../../components/SeverityLegend";
import StatTiles from "../../../components/StatTiles";
import type { TrackPoint } from "../../../components/SessionMap";
import {
  clusterHazards,
  formatDateTime,
  formatDuration,
  severityOf,
  trackDistanceMeters,
} from "../../../lib/geo";
import { supabase } from "../../../lib/supabase";
import {
  MODE_LABELS,
  type DetectionConfig,
  type HazardWindow,
  type Session,
  type WindowFeature,
} from "../../../lib/types";

const SessionMap = dynamic(() => import("../../../components/SessionMap"), {
  ssr: false,
  loading: () => <div className="map-placeholder">지도 로딩 중…</div>,
});

interface DetailData {
  session: Session;
  features: WindowFeature[];
  hazards: HazardWindow[];
  config?: DetectionConfig;
}

async function loadDetail(id: string): Promise<DetailData> {
  const sessionRes = await supabase
    .from("sessions")
    .select("*")
    .eq("id", id)
    .single();
  if (sessionRes.error) throw sessionRes.error;
  const session = sessionRes.data as Session;

  const [featuresRes, hazardsRes, configRes] = await Promise.all([
    supabase
      .from("window_features")
      .select("*")
      .eq("session_id", id)
      .order("chunk_index", { ascending: true }),
    supabase.from("hazard_windows").select("*").eq("session_id", id),
    supabase
      .from("detection_config")
      .select("*")
      .eq("mode", session.mode)
      .single(),
  ]);

  return {
    session,
    features: (featuresRes.data ?? []) as WindowFeature[],
    hazards: (hazardsRes.data ?? []) as HazardWindow[],
    config: (configRes.data ?? undefined) as DetectionConfig | undefined,
  };
}

export default function SessionDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const [data, setData] = useState<DetailData | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadDetail(id).then(setData).catch((e) => setError(String(e)));
  }, [id]);

  if (error) {
    return (
      <main className="page">
        <p className="notice error">세션을 불러오지 못했습니다: {error}</p>
      </main>
    );
  }
  if (!data) {
    return (
      <main className="page">
        <p className="notice">로딩 중…</p>
      </main>
    );
  }

  const { session, features, hazards, config } = data;

  const track: TrackPoint[] = features
    .filter((f) => f.lat != null && f.lng != null)
    .map((f) => ({
      lat: f.lat!,
      lng: f.lng!,
      severity: severityOf(f, config),
      chunkIndex: f.chunk_index,
    }));

  const clusters = clusterHazards(hazards);
  const distance = trackDistanceMeters(features);
  const maxRms = features.length
    ? Math.max(...features.map((f) => f.rms))
    : 0;

  return (
    <main className="page">
      <header className="page-header">
        <h1>
          {formatDateTime(session.started_at)} ·{" "}
          {MODE_LABELS[session.mode] ?? session.mode}
        </h1>
        <p className="tagline">
          {session.device_model ?? "기기 미상"} ·{" "}
          {session.sample_rate_hz
            ? `실효 ${Math.round(session.sample_rate_hz)}Hz`
            : "샘플레이트 미상"}
        </p>
      </header>

      <StatTiles
        stats={[
          {
            label: "측정 시간",
            value: formatDuration(session.started_at, session.ended_at),
          },
          { label: "이동 거리", value: `${Math.round(distance)}m` },
          { label: "위험 지점", value: `${clusters.length}` },
          { label: "최대 RMS", value: `${maxRms.toFixed(2)} m/s²` },
        ]}
      />

      <section className="card">
        <div className="card-header">
          <h2>이동 경로</h2>
          <SeverityLegend />
        </div>
        {track.length === 0 ? (
          <p className="notice">GPS 좌표가 없는 세션입니다 (실내 측정 등).</p>
        ) : (
          <SessionMap track={track} hazards={clusters} height={440} />
        )}
      </section>

      <section className="card">
        <h2>진동 타임라인 (1초 윈도우 RMS)</h2>
        <RmsTimeline features={features} config={config} />
      </section>
    </main>
  );
}
