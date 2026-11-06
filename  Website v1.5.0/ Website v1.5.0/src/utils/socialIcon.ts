/** Helper functions for social media icon rendering and image type resolution. */

// Image file extension regex pattern.
const IMAGE_EXT = /\.(png|jpe?g|webp|gif|svg|avif)$/i;

// Check if social entry icon is an image file.
export const isImageIcon = (social: any): boolean => {
  const icon = String(social?.icon || "").trim();
  if (!icon) return false;
  return IMAGE_EXT.test(icon);
};

/** Return social media image icon URL or empty string for font glyphs. */
export const socialIconUrl = (social: any): string =>
  isImageIcon(social) ? String(social?.icon_url || "").trim() : "";

