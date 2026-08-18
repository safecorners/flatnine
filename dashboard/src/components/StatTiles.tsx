interface Stat {
  label: string;
  value: string;
  sub?: string;
}

export default function StatTiles({ stats }: { stats: Stat[] }) {
  return (
    <div className="stat-grid">
      {stats.map((s) => (
        <div key={s.label} className="stat-tile">
          <div className="stat-value">{s.value}</div>
          <div className="stat-label">{s.label}</div>
          {s.sub && <div className="stat-sub">{s.sub}</div>}
        </div>
      ))}
    </div>
  );
}
