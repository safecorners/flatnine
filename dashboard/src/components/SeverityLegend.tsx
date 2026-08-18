import { SEVERITY_COLORS } from "../lib/geo";

const ITEMS = [
  { key: "ok", label: "정상" },
  { key: "warn", label: "주의" },
  { key: "danger", label: "위험" },
] as const;

export default function SeverityLegend() {
  return (
    <div className="legend">
      {ITEMS.map((item) => (
        <span key={item.key} className="legend-item">
          <span
            className="legend-dot"
            style={{ background: SEVERITY_COLORS[item.key] }}
          />
          {item.label}
        </span>
      ))}
    </div>
  );
}
