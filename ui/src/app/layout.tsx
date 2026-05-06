import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "XMOB Datalab — Pipeline Dashboard",
  description: "Pipeline observability for the XMOB Datalab initiative",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className="antialiased">{children}</body>
    </html>
  );
}
