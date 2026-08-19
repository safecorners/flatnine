"use client";

import dynamic from "next/dynamic";
import { useEffect, useMemo, useRef, useState } from "react";

import HeatLegend from "../components/HeatLegend";
import LocationSearch from "../components/LocationSearch";
import SeverityLegend from "../components/SeverityLegend";
import type { MapFocus } from "../components/SessionMap";
import type { HeatPoint } from "../components/HeatLayer";
import { clusterHazards, heatIntensity, type HazardCluster } from "../lib/geo";
import { supabase, supabaseConfigured } from "../lib/supabase";
import type { DetectionConfig, HazardWindow } from "../lib/types";

const SessionMap = dynamic(() => import("../components/SessionMap"), {
  ssr: false,
  loading: () => <div className="map-placeholder">지도 로딩 중…</div>,
});

interface HomeData {
  hazards: HazardWindow[];
  configs: Map<string, DetectionConfig>;
}

async function loadHome(): Promise<HomeData> {
  const [hazardsRes, configRes] = await Promise.all([
    supabase.from("hazard_windows").select("*"),
    supabase.from("detection_config").select("*"),
  ]);
  if (hazardsRes.error) throw hazardsRes.error;

  const configs = new Map<string, DetectionConfig>();
  for (const c of (configRes.data ?? []) as DetectionConfig[]) {
    configs.set(c.mode, c);
  }
  return { hazards: (hazardsRes.data ?? []) as HazardWindow[], configs };
}

export default function HomePage() {
  const [data, setData] = useState<HomeData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [focus, setFocus] = useState<MapFocus | null>(null);
  const [viewer, setViewer] = useState<{ lat: number; lng: number } | null>(
    null
  );
  const [hazardDisplay, setHazardDisplay] = useState<"circles" | "heatmap">(
    "circles"
  );
  const searchedRef = useRef(false);

  useEffect(() => {
    if (!supabaseConfigured) return;
    loadHome().then(setData).catch((e) => setError(String(e)));
  }, []);

  // 기본 지도 중심 = 뷰어의 현재 위치 (권한 거부·실패 시 위험 지점 범위로 폴백)
  useEffect(() => {
    if (!("geolocation" in navigator)) return;
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const p = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        setViewer(p);
        // 사용자가 이미 검색으로 이동했다면 덮어쓰지 않는다
        if (!searchedRef.current) {
          setFocus({ ...p, zoom: 15 });
        }
      },
      () => {},
      { timeout: 8000, maximumAge: 60000 }
    );
  }, []);

  function handleSearchSelect(lat: number, lng: number, label: string) {
    searchedRef.current = true;
    setFocus({ lat, lng, zoom: 16, label });
  }

  // 히트맵은 클러스터가 아닌 원본 윈도우 단위로 밀도를 표현한다
  const heatPoints: HeatPoint[] = useMemo(() => {
    if (!data) return [];
    return data.hazards
      .filter((h) => h.lat != null && h.lng != null)
      .map((h) => ({
        lat: h.lat!,
        lng: h.lng!,
        intensity: heatIntensity(h, data.configs),
      }));
  }, [data]);

  if (!supabaseConfigured) {
    return (
      <main className="page">
        <header className="page-header">
          <h1>보행 약자 노면 위험 지도</h1>
        </header>
        <p className="notice">
          Supabase 환경변수(NEXT_PUBLIC_SUPABASE_URL /
          NEXT_PUBLIC_SUPABASE_ANON_KEY)가 설정되지 않았습니다.
        </p>
      </main>
    );
  }

  const clusters: HazardCluster[] = data ? clusterHazards(data.hazards) : [];

  return (
    <main className="page">
      <header className="page-header">
        <h1>보행 약자 노면 위험 지도</h1>
        <p className="tagline">
          스마트폰 가속도·자이로 센서로 수집한 노면 상태를 지도에서 확인합니다
        </p>
      </header>

      <LocationSearch onSelect={handleSearchSelect} />

      {error && <p className="notice error">데이터 로드 실패: {error}</p>}

      <section className="card">
        <div className="card-header">
          <h2>전체 위험 지도</h2>
          <div className="map-controls">
            {hazardDisplay === "circles" ? <SeverityLegend /> : <HeatLegend />}
            <div className="map-toggle" role="group" aria-label="표시 방식">
              <button
                type="button"
                className={hazardDisplay === "circles" ? "active" : ""}
                onClick={() => setHazardDisplay("circles")}
              >
                원
              </button>
              <button
                type="button"
                className={hazardDisplay === "heatmap" ? "active" : ""}
                onClick={() => setHazardDisplay("heatmap")}
              >
                히트맵
              </button>
            </div>
          </div>
        </div>
        <SessionMap
          hazards={clusters}
          height={520}
          focus={focus}
          viewer={viewer}
          hazardDisplay={hazardDisplay}
          heatPoints={heatPoints}
        />
      </section>
    </main>
  );
}
