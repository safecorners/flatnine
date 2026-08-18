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

interface Props {
  track?: TrackPoint[];
  hazards?: HazardCluster[];
  height?: number;
}

/** 데이터 범위에 맞춰 지도를 이동 */
function FitBounds({ points }: { points: { lat: number; lng: number }[] }) {
  const map = useMap();
  useEffect(() => {
    if (points.length === 0) return;
    const lats = points.map((p) => p.lat);
    const lngs = points.map((p) => p.lng);
    map.fitBounds(
      [
        [Math.min(...lats), Math.min(...lngs)],
        [Math.max(...lats), Math.max(...lngs)],
      ],
      { padding: [40, 40], maxZoom: 18 }
    );
  }, [map, points]);
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

export default function SessionMap({ track = [], hazards = [], height = 480 }: Props) {
  const allPoints = [
    ...track.map((p) => ({ lat: p.lat, lng: p.lng })),
    ...hazards.map((h) => ({ lat: h.lat, lng: h.lng })),
  ];

  return (
    <MapContainer
      center={DEFAULT_CENTER}
      zoom={15}
      style={{ height, width: "100%", borderRadius: 12 }}
      scrollWheelZoom
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <FitBounds points={allPoints} />

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
