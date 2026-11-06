// Common interface shared by map provider components
export interface MapMarker {
  latitude: number;
  longitude: number;
  title?: string;
  iconUrl?: string;
  /** Degrees clockwise from north; rotates the icon to face its heading. */
  rotation?: number;
}

export interface MapLineStyleOptions {
  color?: string;
  weight?: number;
  opacity?: number;
}

export interface MapPolygonStyleOptions extends MapLineStyleOptions {
  fillOpacity?: number;
}

export interface MapLatLng {
  lat: number;
  lng: number;
}

export interface MapComponentProps {
  latitude: number;
  longitude: number;
  zoom?: number;
  markers?: MapMarker[];
  showCenterMarker?: boolean;
  height?: string | number;
  className?: string;
  draggableMarker?: boolean;
  onMarkerDragEnd?: (coords: MapLatLng) => void;
  onMapClick?: (coords: MapLatLng) => void;
  onReady?: () => void;
  polyline?: MapMarker[];
  polylineOptions?: MapLineStyleOptions;
  polygon?: MapLatLng[];
  polygonOptions?: MapPolygonStyleOptions;
  fitToMarkers?: boolean;
}

// Map providers enum and list
export type MapProvider = "google" | "osm";

export const MAP_PROVIDERS = Object.freeze({
  GOOGLE: "google",
  OSM: "osm",
} as const);

export const SUPPORTED_PROVIDERS = Object.freeze([
  MAP_PROVIDERS.GOOGLE,
  MAP_PROVIDERS.OSM,
]);

// Default map provider fallback
export const DEFAULT_MAP_PROVIDER: MapProvider = MAP_PROVIDERS.GOOGLE;

export const isSupportedProvider = (provider: unknown): provider is MapProvider =>
  typeof provider === "string" &&
  (SUPPORTED_PROVIDERS as readonly string[]).includes(provider.toLowerCase());
