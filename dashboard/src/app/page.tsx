"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { useEffect, useState } from "react";

import SeverityLegend from "../components/SeverityLegend";
import StatTiles from "../components/StatTiles";
import {
  clusterHazards,
  formatDateTime,
  formatDuration,
  type HazardCluster,
} from "../lib/geo";
import { supabase, supabaseConfigured } from "../lib/supabase";
import { MODE_LABELS, type HazardWindow, type Session } from "../lib/types";

const SessionMap = dynamic(() => import("../components/SessionMap"), {
  ssr: false,
  loading: () => <div className="map-placeholder">지도 로딩 중…</div>,
});

interface HomeData {
  sessions: Session[];
  hazards: HazardWindow[];
  chunkCounts: Map<string, number>;
  totalSeconds: number;
}

async function loadHome(): Promise<HomeData> {
  const [sessionsRes, hazardsRes, featuresRes] = await Promise.all([
    supabase
      .from("sessions")
      .select("*")
      .order("started_at", { ascending: false }),
    supabase.from("hazard_windows").select("*"),
    supabase.from("window_features").select("session_id"),
  ]);

  const sessions = (sessionsRes.data ?? []) as Session[];
  const hazards = (hazardsRes.data ?? []) as HazardWindow[];

  const chunkCounts = new Map<string, number>();
  for (const row of featuresRes.data ?? []) {
    const id = (row as { session_id: string }).session_id;
    chunkCounts.set(id, (chunkCounts.get(id) ?? 0) + 1);
  }

  const totalSeconds = sessions.reduce(
    (acc, s) =>
      acc +
      Math.max(0, (+new Date(s.ended_at) - +new Date(s.started_at)) / 1000),
    0
  );

  return { sessions, hazards, chunkCounts, totalSeconds };
}

export default function HomePage() {
  const [data, setData] = useState<HomeData | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!supabaseConfigured) return;
    loadHome().then(setData).catch((e) => setError(String(e)));
  }, []);

  if (!supabaseConfigured) {
    return (
      <main className="page">
        <h1>RoadSense 대시보드</h1>
        <p className="notice">
          Supabase 환경변수(NEXT_PUBLIC_SUPABASE_URL /
          NEXT_PUBLIC_SUPABASE_ANON_KEY)가 설정되지 않았습니다.
        </p>
      </main>
    );
  }

  const clusters: HazardCluster[] = data ? clusterHazards(data.hazards) : [];
  const dangerCount = clusters.filter((c) => c.severity === "danger").length;

  return (
    <main className="page">
      <header className="page-header">
        <h1>RoadSense</h1>
        <p className="tagline">
          스마트폰 IMU로 감지한 보행 약자 노면 위험 지도
        </p>
      </header>

      {error && <p className="notice error">데이터 로드 실패: {error}</p>}

      <StatTiles
        stats={[
          { label: "측정 세션", value: `${data?.sessions.length ?? "—"}` },
          {
            label: "총 측정 시간",
            value: data ? `${Math.round(data.totalSeconds / 60)}분` : "—",
          },
          {
            label: "위험 지점",
            value: `${clusters.length || "—"}`,
            sub: data ? `위험 ${dangerCount} · 주의 ${clusters.length - dangerCount}` : undefined,
          },
        ]}
      />

      <section className="card">
        <div className="card-header">
          <h2>전체 위험 지도</h2>
          <SeverityLegend />
        </div>
        <SessionMap hazards={clusters} height={440} />
      </section>

      <section className="card">
        <h2>세션 목록</h2>
        {data && data.sessions.length === 0 && (
          <p className="notice">아직 업로드된 세션이 없습니다.</p>
        )}
        <ul className="session-list">
          {data?.sessions.map((s) => {
            const uploaded = data.chunkCounts.get(s.id) ?? 0;
            const complete = uploaded >= s.chunk_count;
            return (
              <li key={s.id}>
                <Link href={`/session/${s.id}`} className="session-row">
                  <span className="session-title">
                    {formatDateTime(s.started_at)} ·{" "}
                    {MODE_LABELS[s.mode] ?? s.mode}
                  </span>
                  <span className="session-meta">
                    {formatDuration(s.started_at, s.ended_at)}
                    {s.sample_rate_hz
                      ? ` · ${Math.round(s.sample_rate_hz)}Hz`
                      : ""}
                    {" · "}
                    {complete ? (
                      <span className="ok-text">완료</span>
                    ) : (
                      <span className="warn-text">
                        업로드 {uploaded}/{s.chunk_count}
                      </span>
                    )}
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>
      </section>
    </main>
  );
}
