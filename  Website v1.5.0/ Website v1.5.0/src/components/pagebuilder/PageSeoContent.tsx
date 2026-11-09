import React from "react";

type Faq = { q: string; a: string };
type Props = { h1?: string; intro?: string; faqs?: Faq[] };

// Crawlable page copy under the sections: intro paragraphs and FAQs.
// Plain server-rendered HTML (details/summary) so it indexes without JS.
export default function PageSeoContent({ h1, intro, faqs }: Props) {
  const paragraphs = String(intro || "")
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter(Boolean);
  const list = (faqs || []).filter((f) => f?.q && f?.a);
  if (!paragraphs.length && !list.length) return null;

  return (
    <section className="container mx-auto px-4 py-8 max-w-4xl" aria-label="About this collection">
      {paragraphs.length > 0 && (
        <div className="mb-8">
          {h1 && <h2 className="text-xl md:text-2xl font-bold mb-3 textColor">{h1}</h2>}
          {paragraphs.map((p, i) => (
            <p key={i} className="mb-3 leading-relaxed text-sm md:text-base opacity-80 textColor">
              {p}
            </p>
          ))}
        </div>
      )}
      {list.length > 0 && (
        <div>
          <h2 className="text-xl md:text-2xl font-bold mb-3 textColor">Frequently asked questions</h2>
          <div className="divide-y rounded-xl border">
            {list.map((f, i) => (
              <details key={i} className="group p-4">
                <summary className="cursor-pointer font-semibold list-none flex justify-between gap-3 textColor">
                  <span>{f.q}</span>
                  <span className="transition group-open:rotate-45 text-xl leading-none">+</span>
                </summary>
                <p className="mt-2 text-sm md:text-base opacity-80 leading-relaxed textColor">{f.a}</p>
              </details>
            ))}
          </div>
        </div>
      )}
    </section>
  );
}
