import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RoadSense — 보행 약자 노면 위험 지도",
  description:
    "스마트폰 가속도·자이로 센서로 측정한 노면 상태를 지도로 시각화하는 대시보드",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
