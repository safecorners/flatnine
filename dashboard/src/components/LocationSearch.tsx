"use client";

import { useState, type FormEvent } from "react";

interface NominatimResult {
  place_id: number;
  display_name: string;
  lat: string;
  lon: string;
}

interface Props {
  onSelect: (lat: number, lng: number, label: string) => void;
}

/** OSM Nominatim 지오코딩 검색창 — API 키 불필요 (저용량 데모 사용) */
export default function LocationSearch({ onSelect }: Props) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<NominatimResult[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);

  async function search(e: FormEvent) {
    e.preventDefault();
    const q = query.trim();
    if (!q || busy) return;
    setBusy(true);
    setSearchError(null);
    try {
      const res = await fetch(
        "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5" +
          `&accept-language=ko&q=${encodeURIComponent(q)}`
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = (await res.json()) as NominatimResult[];
      setResults(data);
      if (data.length === 0) setSearchError("검색 결과가 없습니다");
    } catch {
      setResults(null);
      setSearchError("검색에 실패했습니다. 잠시 후 다시 시도해 주세요.");
    } finally {
      setBusy(false);
    }
  }

  function select(r: NominatimResult) {
    const label = r.display_name.split(",")[0].trim();
    onSelect(Number(r.lat), Number(r.lon), label);
    setResults(null);
    setQuery(label);
  }

  return (
    <div className="location-search">
      <form onSubmit={search} className="search-form">
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="장소·주소 검색 (예: 인하대학교)"
          aria-label="위치 검색"
        />
        <button type="submit" disabled={busy}>
          {busy ? "검색 중…" : "검색"}
        </button>
      </form>
      {searchError && <p className="search-error">{searchError}</p>}
      {results && results.length > 0 && (
        <ul className="search-results">
          {results.map((r) => (
            <li key={r.place_id}>
              <button type="button" onClick={() => select(r)}>
                {r.display_name}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
