"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import SessionList from "../../components/SessionList";
import { formatDateTime } from "../../lib/geo";
import { supabase } from "../../lib/supabase";
import { MODE_LABELS, type Session } from "../../lib/types";

interface SessionsData {
  sessions: Session[];
  chunkCounts: Map<string, number>;
}

async function loadSessions(): Promise<SessionsData> {
  const [sessionsRes, featuresRes] = await Promise.all([
    supabase
      .from("sessions")
      .select("*")
      .order("started_at", { ascending: false }),
    supabase.from("window_features").select("session_id"),
  ]);

  const sessions = (sessionsRes.data ?? []) as Session[];
  const chunkCounts = new Map<string, number>();
  for (const row of featuresRes.data ?? []) {
    const id = (row as { session_id: string }).session_id;
    chunkCounts.set(id, (chunkCounts.get(id) ?? 0) + 1);
  }
  return { sessions, chunkCounts };
}

export default function SessionsPage() {
  const [data, setData] = useState<SessionsData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<string | null>(null);

  useEffect(() => {
    loadSessions().then(setData).catch((e) => setError(String(e)));
  }, []);

  async function deleteSession(s: Session) {
    const label = `${formatDateTime(s.started_at)} · ${
      MODE_LABELS[s.mode] ?? s.mode
    }`;
    if (
      !window.confirm(
        `${label} 세션과 측정 데이터가 영구 삭제됩니다. 계속할까요?`
      )
    ) {
      return;
    }
    setDeleting(s.id);
    try {
      const { error: deleteError, count } = await supabase
        .from("sessions")
        .delete({ count: "exact" })
        .eq("id", s.id);
      if (deleteError) throw deleteError;
      if (!count) throw new Error("삭제된 행이 없습니다");
      setData(await loadSessions());
    } catch (e) {
      window.alert(`삭제 실패: ${e instanceof Error ? e.message : e}`);
    } finally {
      setDeleting(null);
    }
  }

  return (
    <main className="page">
      <Link href="/">← 전체 현황</Link>
      <header className="page-header">
        <h1>세션 목록</h1>
        <p className="tagline">측정 세션 관리 — 삭제는 이 페이지에서만 가능합니다</p>
      </header>

      {error && <p className="notice error">데이터 로드 실패: {error}</p>}

      <section className="card">
        {data ? (
          <SessionList
            sessions={data.sessions}
            chunkCounts={data.chunkCounts}
            onDelete={deleteSession}
            deletingId={deleting}
          />
        ) : (
          !error && <p className="notice">로딩 중…</p>
        )}
      </section>
    </main>
  );
}
