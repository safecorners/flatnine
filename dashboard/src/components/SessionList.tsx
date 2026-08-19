"use client";

import Link from "next/link";

import { formatDateTime, formatDuration } from "../lib/geo";
import { MODE_LABELS, type Session } from "../lib/types";

interface Props {
  sessions: Session[];
  chunkCounts: Map<string, number>;
  /** 전달되면 각 행에 삭제 버튼이 표시된다 (세션 목록 관리 페이지 전용) */
  onDelete?: (session: Session) => void;
  deletingId?: string | null;
}

export default function SessionList({
  sessions,
  chunkCounts,
  onDelete,
  deletingId,
}: Props) {
  if (sessions.length === 0) {
    return <p className="notice">아직 업로드된 세션이 없습니다.</p>;
  }

  return (
    <ul className="session-list">
      {sessions.map((s) => {
        const uploaded = chunkCounts.get(s.id) ?? 0;
        const complete = uploaded >= s.chunk_count;
        return (
          <li key={s.id} className="session-item">
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
            {onDelete && (
              <button
                type="button"
                className="delete-button"
                title="세션 삭제"
                aria-label="세션 삭제"
                disabled={deletingId === s.id}
                onClick={() => onDelete(s)}
              >
                {deletingId === s.id ? "…" : "🗑"}
              </button>
            )}
          </li>
        );
      })}
    </ul>
  );
}
