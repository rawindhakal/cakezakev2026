"use client";
import Link from "next/link";
import useZoneHref from "@/hooks/useZoneHref";
import useGiftingMeta from "./useGiftingMeta";

const Chip = ({ href, children }: { href: string; children: React.ReactNode }) => (
  <Link
    href={href}
    className="shrink-0 rounded-full cardBorder px-4 py-2 text-sm font-medium textColor hover:primaryColor hover:primaryColorBorder transition whitespace-nowrap"
  >
    {children}
  </Link>
);

const Row = ({ title, children }: { title: string; children: React.ReactNode }) => (
  <div className="mb-5">
    <h2 className="mb-3 text-xl md:text-2xl font-heading textColor">{title}</h2>
    <div className="flex gap-2 overflow-x-auto pb-2 [scrollbar-width:none]">{children}</div>
  </div>
);

// "Shop by occasion / who it's for / how fast" strip for the home page.
export default function GiftShop() {
  const zoneHref = useZoneHref();
  const { occasions, relationships, delivery_types } = useGiftingMeta();
  if (!occasions.length && !relationships.length) return null;

  const to = (q: string) => zoneHref(`/products?${q}`);
  return (
    <section className="container mx-auto px-4 py-6" aria-label="Gift finder">
      {occasions.length > 0 && (
        <Row title="Shop by occasion">
          {occasions.map((o) => (
            <Chip key={o.slug} href={to(`occasion=${o.slug}&title=${encodeURIComponent(o.name)}`)}>
              {o.name}
            </Chip>
          ))}
        </Row>
      )}
      {relationships.length > 0 && (
        <Row title="Gifts for">
          {relationships.map((r) => (
            <Chip key={r.slug} href={to(`relationship=${r.slug}&title=${encodeURIComponent("Gifts for " + r.name)}`)}>
              {r.name}
            </Chip>
          ))}
        </Row>
      )}
      {delivery_types.length > 0 && (
        <Row title="Delivery">
          {delivery_types.map((d) => (
            <Chip key={d.slug} href={to(`delivery=${d.slug}&title=${encodeURIComponent(d.name)}`)}>
              {d.name}
            </Chip>
          ))}
        </Row>
      )}
    </section>
  );
}
