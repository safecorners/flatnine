"use client";

import { useEffect } from "react";
import {
  CircleMarker,
  MapContainer,
  Polyline,
  Popup,
  TileLayer,
  useMap,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";

import { SEVERITY_COLORS, type HazardCluster } from "../lib/geo";
import type { Severity } from "../lib/types";

export interface TrackPoint {
  lat: number;
  lng: number;
  severity: Severity;
  chunkIndex: number;
}

export interface MapFocus {
  lat: number;
  lng: number;
  zoom?: number;
  label?: string;
}

interface Props {
  track?: TrackPoint[];
  hazards?: HazardCluster[];
  height?: number;
  /** 검색 결과·현재 위치 등 지도가 이동해야 할 지점. 설정되면 자동 맞춤은 꺼진다. */
  focus?: MapFocus | null;
  /** 뷰어(브라우저)의 현재 위치 마커 */
  viewer?: { lat: number; lng: number } | null;
}

/** 데이터 범위에 맞춰 지도를 이동 (enabled=false면 동작 안 함) */
function FitBounds({
  points,
  enabled,
}: {
  points: { lat: number; lng: number }[];
  enabled: boolean;
}) {
  const map = useMap();
  // 배열 identity가 렌더마다 바뀌어도 실제 범위가 같으면 재실행하지 않도록 키로 비교
  const boundsKey =
    points.length === 0
      ? ""
      : [
          Math.min(...points.map((p) => p.lat)),
          Math.min(...points.map((p) => p.lng)),
          Math.max(...points.map((p) => p.lat)),
          Math.max(...points.map((p) => p.lng)),
        ].join(",");
  useEffect(() => {
    if (!enabled || boundsKey === "") return;
    const [minLat, minLng, maxLat, maxLng] = boundsKey.split(",").map(Number);
    map.fitBounds(
      [
        [minLat, minLng],
        [maxLat, maxLng],
      ],
      { padding: [40, 40], maxZoom: 18 }
    );
  }, [map, boundsKey, enabled]);
  return null;
}

/** focus가 바뀔 때마다 해당 지점으로 부드럽게 이동 */
function FlyTo({ focus }: { focus?: MapFocus | null }) {
  const map = useMap();
  useEffect(() => {
    if (!focus) return;
    map.flyTo([focus.lat, focus.lng], focus.zoom ?? 16, { duration: 0.8 });
  }, [map, focus]);
  return null;
}

/** 연속 동일 심각도 구간을 하나의 Polyline으로 묶는다 */
function trackSegments(track: TrackPoint[]) {
  const segments: { color: string; positions: [number, number][] }[] = [];
  let curSeverity: Severity | null = null;
  let curPositions: [number, number][] = [];

  const flush = () => {
    if (curSeverity !== null && curPositions.length > 1) {
      segments.push({
        color: SEVERITY_COLORS[curSeverity],
        positions: curPositions,
      });
    }
  };

  for (const p of track) {
    const pos: [number, number] = [p.lat, p.lng];
    if (curSeverity === p.severity) {
      curPositions.push(pos);
    } else {
      flush();
      // 구간 연속성을 위해 이전 마지막 점을 새 구간의 시작점으로
      const prevLast = curPositions[curPositions.length - 1];
      curPositions = prevLast ? [prevLast, pos] : [pos];
      curSeverity = p.severity;
    }
  }
  flush();
  return segments;
}

// 기본 중심: 인하대학교 (데이터 없을 때)
const DEFAULT_CENTER: [number, number] = [37.4504, 126.6538];

export default function SessionMap({
  track = [],
  hazards = [],
  height = 480,
  focus = null,
  viewer = null,
}: Props) {
  const allPoints = [
    ...track.map((p) => ({ lat: p.lat, lng: p.lng })),
    ...hazards.map((h) => ({ lat: h.lat, lng: h.lng })),
  ];

  return (
    <MapContainer
      center={DEFAULT_CENTER}
      zoom={15}
      className="map-canvas"
      style={{ height, width: "100%" }}
      scrollWheelZoom
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <FitBounds points={allPoints} enabled={focus == null} />
      <FlyTo focus={focus} />

      {viewer && (
        <CircleMarker
          center={[viewer.lat, viewer.lng]}
          radius={8}
          pathOptions={{
            color: "#ffffff",
            weight: 2,
            fillColor: "#2563eb",
            fillOpacity: 0.9,
          }}
        >
          <Popup>내 위치</Popup>
        </CircleMarker>
      )}

      {focus?.label && (
        <CircleMarker
          center={[focus.lat, focus.lng]}
          radius={9}
          pathOptions={{
            color: "#0d9488",
            fillColor: "#0d9488",
            fillOpacity: 0.35,
          }}
        >
          <Popup>{focus.label}</Popup>
        </CircleMarker>
      )}

      {trackSegments(track).map((seg, i) => (
        <Polyline
          key={i}
          positions={seg.positions}
          pathOptions={{ color: seg.color, weight: 5, opacity: 0.85 }}
        />
      ))}

      {hazards.map((h, i) => (
        <CircleMarker
          key={i}
          center={[h.lat, h.lng]}
          radius={h.severity === "danger" ? 10 : 7}
          pathOptions={{
            color: SEVERITY_COLORS[h.severity],
            fillColor: SEVERITY_COLORS[h.severity],
            fillOpacity: 0.7,
          }}
        >
          <Popup>
            <b>{h.severity === "danger" ? "위험" : "주의"}</b> ·{" "}
            {h.windowCount}초 구간
            <br />
            최대 RMS {h.maxRms.toFixed(2)} m/s²
            <br />
            최대 피크 {h.maxPeak.toFixed(2)} m/s²
          </Popup>
        </CircleMarker>
      ))}
    </MapContainer>
  );
}
