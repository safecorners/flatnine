"use client";

import { useEffect, useState } from "react";

import SessionList from "../../components/SessionList";
import StatTiles from "../../components/StatTiles";
import { clusterHazards } from "../../lib/geo";
import { supabase } from "../../lib/supabase";
import type { HazardWindow, Session } from "../../lib/types";

interface SessionsData {
  sessions: Session[];
  chunkCounts: Map<string, number>;
  hazards: HazardWindow[];
  totalSeconds: number;
}

async function loadSessions(): Promise<SessionsData> {
  const [sessionsRes, featuresRes, hazardsRes] = await Promise.all([
    supabase
      .from("sessions")
      .select("*")
      .order("started_at", { ascending: false }),
    supabase.from("window_features").select("session_id"),
    supabase.from("hazard_windows").select("*"),
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

  return { sessions, chunkCounts, hazards, totalSeconds };
}

export default function SessionsPage() {
  const [data, setData] = useState<SessionsData | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadSessions().then(setData).catch((e) => setError(String(e)));
  }, []);

  const clusters = data ? clusterHazards(data.hazards) : [];
  const dangerCount = clusters.filter((c) => c.severity === "danger").length;

  return (
    <main className="page">
      <header className="page-header">
        <h1>세션 목록</h1>
        <p className="tagline">업로드된 측정 세션 현황</p>
      </header>

      {error && <p className="notice error">데이터 로드 실패: {error}</p>}

      <StatTiles
        stats={[
          {
            label: "측정 세션",
            value: data ? `${data.sessions.length}` : "…",
          },
          {
            label: "총 측정 시간",
            value: data ? `${Math.round(data.totalSeconds / 60)}분` : "…",
          },
          {
            label: "위험 지점",
            value: data ? `${clusters.length}` : "…",
            sub: data
              ? `위험 ${dangerCount} · 주의 ${clusters.length - dangerCount}`
              : undefined,
          },
        ]}
      />

      <section className="card">
        {data ? (
          <SessionList
            sessions={data.sessions}
            chunkCounts={data.chunkCounts}
          />
        ) : (
          !error && <p className="notice">로딩 중…</p>
        )}
      </section>
    </main>
  );
}
