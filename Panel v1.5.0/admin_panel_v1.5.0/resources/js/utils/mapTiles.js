/**
 * The OpenStreetMap basemap tile URL.
 *
 * OSM's own tiles are free and need no key, so every map in the panel points here.
 * Attribution is required by the OSM tile usage policy — Leaflet renders it from the
 * layer options below.
 */
export const OSM_TILE_URL = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

export const OSM_TILE_OPTIONS = {
    subdomains: ['a', 'b', 'c'],
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
};

/** The tile URL. Kept as a function so call sites need no change. */
export function osmTileUrl() {
    return OSM_TILE_URL;
}
