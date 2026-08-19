"use client";

import { useEffect } from "react";
import L from "leaflet";
import "leaflet.heat";
import { useMap } from "react-leaflet";

export interface HeatPoint {
  lat: number;
  lng: number;
  /** 0~1. mode별 danger 임계값 대비 RMS 비율 */
  intensity: number;
}

/** leaflet.heat 캔버스 레이어의 react-leaflet 래퍼 */
export default function HeatLayer({ points }: { points: HeatPoint[] }) {
  const map = useMap();

  useEffect(() => {
    const layer = L.heatLayer(
      points.map(
        (p) => [p.lat, p.lng, p.intensity] as L.HeatLatLngTuple
      ),
      {
        radius: 28,
        blur: 20,
        // 이 줌부터 원래 강도로 표시 (더 넓은 줌은 단계당 절반씩 감쇠 —
        // 값이 크면 광역 뷰에서 히트가 사라지므로 도시 스케일에 맞춤)
        maxZoom: 13,
        max: 1.0,
        // 심각도 색 계열(주황→빨강)과 정합
        gradient: { 0.3: "#f59f00", 0.6: "#e8590c", 1.0: "#e03131" },
      }
    );
    layer.addTo(map);
    return () => {
      map.removeLayer(layer);
    };
  }, [map, points]);

  return null;
}
