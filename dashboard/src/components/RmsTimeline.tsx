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

export default function RmsTimeline({ features, config }: Props) {
  const data = features.map((f) => ({
    t: f.chunk_index,
    rms: Number(f.rms.toFixed(3)),
    peak: Number(f.peak.toFixed(3)),
  }));

  return (
    <ResponsiveContainer width="100%" height={280}>
      <LineChart data={data} margin={{ top: 8, right: 16, bottom: 8, left: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
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
        />
        <Legend />
        <Line
          type="monotone"
          dataKey="peak"
          name="피크"
          stroke="#c4b5fd"
          dot={false}
          strokeWidth={1}
        />
        <Line
          type="monotone"
          dataKey="rms"
          name="RMS"
          stroke="#0d9488"
          dot={false}
          strokeWidth={2}
        />
        {config && (
          <ReferenceLine
            y={config.warn_rms}
            stroke="#f59e0b"
            strokeDasharray="6 4"
            label={{ value: "주의", fill: "#f59e0b", fontSize: 12 }}
          />
        )}
        {config && (
          <ReferenceLine
            y={config.danger_rms}
            stroke="#dc2626"
            strokeDasharray="6 4"
            label={{ value: "위험", fill: "#dc2626", fontSize: 12 }}
          />
        )}
      </LineChart>
    </ResponsiveContainer>
  );
}
