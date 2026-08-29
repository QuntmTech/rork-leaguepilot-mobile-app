import type { Metadata } from "next";
import "./globals.css";
import "./v2.css";

export const metadata: Metadata = {
  title: "LEAGUEPILOT AI Mobile Preview",
  description:
    "Interactive UX/UI prototype for the LEAGUEPILOT AI mobile command center.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
