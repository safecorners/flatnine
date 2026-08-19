"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/", label: "전체 현황" },
  { href: "/sessions", label: "세션 목록" },
];

export default function TopNav() {
  const pathname = usePathname();

  function isActive(href: string) {
    if (href === "/") return pathname === "/";
    // /sessions 목록과 /session/[id] 상세 모두 세션 탭으로 취급
    return pathname.startsWith("/session");
  }

  return (
    <header className="topnav">
      <div className="topnav-inner">
        <Link href="/" className="brand">
          RoadSense
        </Link>
        <nav className="topnav-links">
          {LINKS.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={isActive(l.href) ? "topnav-link active" : "topnav-link"}
            >
              {l.label}
            </Link>
          ))}
        </nav>
      </div>
    </header>
  );
}
