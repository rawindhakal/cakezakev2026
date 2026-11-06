"use client";

// FontAwesome for API-driven social icons. media="print" + onLoad swap keeps
// it non-render-blocking; client component because onLoad needs a function.
export default function FontAwesomeLoader() {
  return (
    <>
      <link
        rel="stylesheet"
        href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css"
        media="print"
        onLoad={(e) => {
          const link = e.currentTarget;
          link.media = "all";
          link.onload = null;
        }}
      />
      <noscript>
        <link
          rel="stylesheet"
          href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css"
          media="all"
        />
      </noscript>
    </>
  );
}
