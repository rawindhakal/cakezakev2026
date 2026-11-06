import React from "react";
import BreadCrumb from "../breadcrumb/BreadCrumb";
import { useSelector } from "react-redux";

const AboutUs = () => {
  const setting = useSelector((state: any) => state?.Setting?.setting);
  return (
    <section>
      <div>
        <div>
          <BreadCrumb />
        </div>
        {setting?.about_us !== "" && (
          // No container/padding/flex wrapper here on purpose: this HTML is
          // authored as a self-contained, full-bleed page-builder layout —
          // each top-level <div style="background-color:...; padding:..."> IS
          // its own full-width section (the hero, the dark "core
          // differentiator" band, etc). Wrapping it in `container` + `p-4` +
          // `flex items-center` confined those sections inside a padded,
          // centered, flex-squeezed box, which is why the live page showed a
          // narrower/centered version of what the admin's own full-width
          // preview renders.
          <div
            className="infoContent "
            // Rendered raw, no sanitizeHtml: about_us is admin/CMS-authored
            // page-builder markup, not end-user input, and sanitizing it was
            // stripping styles/tags the admin's own layout depended on. Must
            // stay a trusted-content-only field — never point this at
            // anything a customer can submit.
            dangerouslySetInnerHTML={{ __html: setting?.about_us }}
          />
        )}
      </div>
    </section>
  );
};

export default AboutUs;
