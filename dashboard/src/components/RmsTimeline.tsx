"use client";

import {
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import type { DetectionConfig, WindowFeature } from "../lib/types";

interface Props {
  features: WindowFeature[];
  config?: DetectionConfig;
}

// 라이트/다크 양쪽에서 성립하는 중간 톤 (SVG 속성이라 CSS 토큰 대신 고정값)
const RMS_COLOR = "#5c7cfa";
const PEAK_COLOR = "#8b95a5";
const WARN_COLOR = "#e8930c";
const DANGER_COLOR = "#e03131";

export default function RmsTimeline({ features, config }: Props) {
  const data = features.map((f) => ({
    t: f.chunk_index,
    rms: Number(f.rms.toFixed(3)),
    peak: Number(f.peak.toFixed(3)),
  }));

  return (
    <ResponsiveContainer width="100%" height={280}>
      <LineChart data={data} margin={{ top: 8, right: 16, bottom: 8, left: 0 }}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis
          dataKey="t"
          label={{ value: "경과 (초)", position: "insideBottomRight", dy: 8 }}
          tick={{ fontSize: 12 }}
        />
        <YAxis
          label={{ value: "m/s²", angle: -90, position: "insideLeft" }}
          tick={{ fontSize: 12 }}
        />
        <Tooltip
          formatter={(v, name) => [
            `${v} m/s²`,
            name === "rms" ? "RMS" : "피크",
          ]}
          labelFormatter={(t) => `${t}초`}
          contentStyle={{
            background: "var(--surface)",
            border: "1px solid var(--border)",
            borderRadius: 10,
            color: "var(--text)",
            fontSize: "0.85rem",
          }}
          labelStyle={{ color: "var(--text-secondary)" }}
        />
        <Legend />
        <Line
          type="monotone"
          dataKey="peak"
          name="피크"
          stroke={PEAK_COLOR}
          dot={false}
          strokeWidth={1}
        />
        <Line
          type="monotone"
          dataKey="rms"
          name="RMS"
          stroke={RMS_COLOR}
          dot={false}
          strokeWidth={2.5}
        />
        {config && (
          <ReferenceLine
            y={config.warn_rms}
            stroke={WARN_COLOR}
            strokeDasharray="6 4"
            label={{ value: "주의", fill: WARN_COLOR, fontSize: 12 }}
          />
        )}
        {config && (
          <ReferenceLine
            y={config.danger_rms}
            stroke={DANGER_COLOR}
            strokeDasharray="6 4"
            label={{ value: "위험", fill: DANGER_COLOR, fontSize: 12 }}
          />
        )}
      </LineChart>
    </ResponsiveContainer>
  );
}
