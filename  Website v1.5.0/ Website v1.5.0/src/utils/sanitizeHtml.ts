import sanitize from "sanitize-html";

// Configure allowed HTML tags, attributes, and image URI schemes for HTML sanitization.
const ALLOWED_TAGS = [...sanitize.defaults.allowedTags, "img"];
const ALLOWED_ATTRIBUTES = {
  ...sanitize.defaults.allowedAttributes,
  "*": ["class", "style"],
  // Allow inline base64 images in img tags.
  img: [...(sanitize.defaults.allowedAttributes.img ?? []), "class", "style"],
};
const ALLOWED_SCHEMES_BY_TAG = { img: [...sanitize.defaults.allowedSchemes, "data"] };

/** Sanitize API/CMS-provided HTML string for safe dangerouslySetInnerHTML injection. */
export const sanitizeHtml = (dirty: string | null | undefined): { __html: string } => ({
  __html: sanitize(dirty ?? "", {
    allowedTags: ALLOWED_TAGS,
    allowedAttributes: ALLOWED_ATTRIBUTES,
    allowedSchemesByTag: ALLOWED_SCHEMES_BY_TAG,
    parseStyleAttributes: false,
  }),
});

export default sanitizeHtml;

