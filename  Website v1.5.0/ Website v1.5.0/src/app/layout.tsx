import type { Metadata, Viewport } from "next";
import { DM_Sans, Instrument_Serif, Caveat, Playfair_Display } from "next/font/google";
import "@/styles/globals.css";
import Providers from "./Providers";
import FontAwesomeLoader from "./FontAwesomeLoader";

// Variable font, max weight 700 — font-extrabold/black clamp to it.
const instrumentSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-family",
  display: "swap",
});

// Brand display serif (headings).
const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: ["400"],
  variable: "--font-heading",
  display: "swap",
});

// Handwriting font for decorative taglines (Spin & Win).
const caveat = Caveat({
  subsets: ["latin"],
  variable: "--font-script",
  display: "swap",
});

// Display serif for the Spin & Win poster lockup only.
const playfair = Playfair_Display({
  subsets: ["latin"],
  weight: ["900"],
  style: ["italic"],
  variable: "--font-poster",
  display: "swap",
});

export const metadata: Metadata = {
  // Base for relative OG URLs (else inferred from request host).
  metadataBase: process.env.NEXT_PUBLIC_BASE_URL
    ? new URL(process.env.NEXT_PUBLIC_BASE_URL)
    : undefined,
  applicationName: process.env.NEXT_PUBLIC_WEB_NAME,
  appleWebApp: {
    title: process.env.NEXT_PUBLIC_WEB_NAME,
    statusBarStyle: "default",
  },
  icons: {
    icon: "/favicon.webp",
    apple: "/icons/apple-touch-icon.png",
  },
};

// No maximum-scale/user-scalable=no — blocking zoom fails WCAG 1.4.4.
export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#000000",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    /* Font vars on <html> so portals (dialogs, toasts) inherit them. */
    <html
      lang="en"
      suppressHydrationWarning
      className={`${instrumentSans.variable} ${instrumentSerif.variable} ${caveat.variable} ${playfair.variable}`}
    >
      <head>
        <link rel="preconnect" href="https://cdnjs.cloudflare.com" crossOrigin="" />
        <FontAwesomeLoader />
      </head>
      <body className="antialiased !pointer-events-auto">
        <main>
          <Providers>{children}</Providers>
        </main>
      </body>
    </html>
  );
}
