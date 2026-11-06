"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  GoogleMap,
  MarkerF,
  OverlayViewF,
  OverlayView,
  Polygon,
  Polyline,
  useJsApiLoader,
} from "@react-google-maps/api";
import { useSelector } from "react-redux";
import { MAP_CONFIG } from "../../utils/mapConfig";
import { darkThemeStyles } from "../../utils/mapColor";
import MapLoader from "./MapLoader";
import MapError from "./MapError";
import type { MapComponentProps, MapLatLng } from "./types";

/**
 * Google Maps implementation of the common map interface.
 * Reuses the existing MAP_CONFIG / @react-google-maps/api setup.
 */
export default function GoogleMapComponent({
  latitude,
  longitude,
  zoom = 13,
  markers,
  showCenterMarker = true,
  height = "360px",
  className = "",
  draggableMarker = false,
  onMarkerDragEnd,
  onMapClick,
  onReady,
  polyline,
  polylineOptions,
  polygon,
  polygonOptions,
  fitToMarkers = false,
}: MapComponentProps) {
  const theme = useSelector((state: any) => state.Theme.theme);
  const mapRef = useRef<google.maps.Map | null>(null);
  // Once the user pans/zooms, stop re-fitting the viewport on data updates.
  const userMovedRef = useRef(false);
  const programmaticRef = useRef(false);
  const [userMoved, setUserMoved] = useState(false);

  // MAP_CONFIG (src/utils/mapConfig.ts, outside this migration batch) types
  // googleMapsApiKey as `string | undefined` and libraries as plain `string[]`,
  // looser than what useJsApiLoader's (unexported) options type expects. No
  // behavior change — same runtime object passed through as before this file
  // was typed.
  const { isLoaded, loadError } = useJsApiLoader(MAP_CONFIG as Parameters<typeof useJsApiLoader>[0]);

  const center = useMemo(
    () => ({ lat: Number(latitude), lng: Number(longitude) }),
    [latitude, longitude]
  );

  const containerStyle = useMemo(
    () => ({
      width: "100%",
      height: typeof height === "number" ? `${height}px` : height,
    }),
    [height]
  );

  const options = useMemo(
    () => ({
      disableDefaultUI: false,
      // Map type ("layers") control defaults to the top-left corner, where
      // callers commonly place their own overlay badges (e.g. LiveTrackingModal's
      // "Rider is on the way" pill) — not useful for a small embedded tracker.
      mapTypeControl: false,
      clickableIcons: false,
      styles: theme === "dark" ? darkThemeStyles : undefined,
    }),
    [theme]
  );

  const resolvedMarkers = useMemo(() => {
    if (Array.isArray(markers) && markers.length > 0) return markers;
    if (showCenterMarker)
      return [{ latitude: center.lat, longitude: center.lng }];
    return [];
  }, [markers, showCenterMarker, center.lat, center.lng]);

  // Dragged pin positions, kept until the parent passes new coords — otherwise any
  // re-render before the parent updates snaps the pin back to its old spot.
  const markersKey = resolvedMarkers.map((m) => `${m.latitude},${m.longitude}`).join("|");
  const [dragged, setDragged] = useState<{ key: string; pos: Record<number, MapLatLng> }>({ key: markersKey, pos: {} });
  if (dragged.key !== markersKey) setDragged({ key: markersKey, pos: {} });
  const draggedPos = dragged.key === markersKey ? dragged.pos : {};
  const rememberDrag = (index: number, pos: MapLatLng) =>
    setDragged((prev) => ({ key: prev.key, pos: { ...prev.pos, [index]: pos } }));

  // Ground pulse where the pin lands; id restarts the animation on each drop.
  const [dropPulse, setDropPulse] = useState<{ id: number; pos: MapLatLng } | null>(null);
  const pulseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const showDropPulse = (pos: MapLatLng) => {
    setDropPulse((prev) => ({ id: (prev?.id ?? 0) + 1, pos }));
    if (pulseTimerRef.current) clearTimeout(pulseTimerRef.current);
    pulseTimerRef.current = setTimeout(() => setDropPulse(null), 1300);
  };
  useEffect(() => () => {
    if (pulseTimerRef.current) clearTimeout(pulseTimerRef.current);
  }, []);

  const polylinePath = useMemo(
    () =>
      Array.isArray(polyline)
        ? polyline.map((p) => ({
            lat: Number(p.latitude),
            lng: Number(p.longitude),
          }))
        : [],
    [polyline]
  );

  const gPolylineOptions = useMemo(
    () => ({
      strokeColor: polylineOptions?.color ?? "#16a34a",
      strokeOpacity: polylineOptions?.opacity ?? 0.9,
      strokeWeight: polylineOptions?.weight ?? 6,
    }),
    [polylineOptions]
  );

  const polygonPath = useMemo(
    () =>
      Array.isArray(polygon)
        ? polygon
            .map((p) => ({ lat: Number(p.lat), lng: Number(p.lng) }))
            .filter((p) => !Number.isNaN(p.lat) && !Number.isNaN(p.lng))
        : [],
    [polygon]
  );

  const gPolygonOptions = useMemo(
    () => ({
      strokeColor: polygonOptions?.color ?? "#2563eb",
      strokeOpacity: polygonOptions?.opacity ?? 0.9,
      strokeWeight: polygonOptions?.weight ?? 2,
      fillColor: polygonOptions?.color ?? "#2563eb",
      fillOpacity: polygonOptions?.fillOpacity ?? 0.12,
      clickable: false,
    }),
    [polygonOptions]
  );

  // Auto-fit the viewport to every marker + polyline point.
  const fitBounds = useCallback(
    (map: google.maps.Map | null) => {
      if (!fitToMarkers || !map || !window.google?.maps) return;
      const pts = [
        ...resolvedMarkers.map((m) => ({
          lat: Number(m.latitude),
          lng: Number(m.longitude),
        })),
        ...polylinePath,
        ...polygonPath,
      ].filter((p) => !Number.isNaN(p.lat) && !Number.isNaN(p.lng));
      if (pts.length === 0) return;
      const bounds = new window.google.maps.LatLngBounds();
      pts.forEach((p) => bounds.extend(p));
      programmaticRef.current = true;
      map.fitBounds(bounds);
    },
    [fitToMarkers, resolvedMarkers, polylinePath, polygonPath]
  );

  const handleLoad = useCallback(
    (map: google.maps.Map) => {
      mapRef.current = map;
      fitBounds(map);
      onReady?.();
    },
    [onReady, fitBounds]
  );

  // Fit once per point-set shape. A live feed sends new coordinates every poll;
  // refitting on each one re-zoomed the map under the user. Afterwards the map
  // only pans, so a moving marker stays visible at the same zoom.
  const fittedForRef = useRef(0);
  useEffect(() => {
    const map = mapRef.current;
    if (!map || userMovedRef.current || !fitToMarkers) return;
    const count = resolvedMarkers.length + polylinePath.length + polygonPath.length;
    if (count === 0) return;
    if (fittedForRef.current !== count) {
      fittedForRef.current = count;
      fitBounds(map);
      return;
    }
    const first = resolvedMarkers[0];
    if (!first || !window.google?.maps) return;
    const pt = { lat: Number(first.latitude), lng: Number(first.longitude) };
    if (Number.isNaN(pt.lat) || Number.isNaN(pt.lng)) return;
    if (!map.getBounds()?.contains(pt)) {
      programmaticRef.current = true;
      map.panTo(pt);
    }
  }, [fitBounds, fitToMarkers, resolvedMarkers, polylinePath, polygonPath]);

  const markUserMoved = useCallback(() => {
    userMovedRef.current = true;
    setUserMoved(true);
  }, []);

  const handleDragStart = markUserMoved;

  // fitBounds also fires zoom_changed, so only user-driven zooms count.
  const handleZoomChanged = useCallback(() => {
    if (!programmaticRef.current) markUserMoved();
  }, [markUserMoved]);

  const handleIdle = useCallback(() => {
    programmaticRef.current = false;
  }, []);

  // Proper cleanup on unmount: drop the map ref so GC can reclaim it.
  const handleUnmount = useCallback(() => {
    mapRef.current = null;
    userMovedRef.current = false;
    setUserMoved(false);
  }, []);

  const handleMapClick = useCallback(
    (e: google.maps.MapMouseEvent) => {
      if (!onMapClick || !e?.latLng) return;
      onMapClick({ lat: e.latLng.lat(), lng: e.latLng.lng() });
    },
    [onMapClick]
  );

  const handleDragEnd = useCallback(
    (e: google.maps.MapMouseEvent) => {
      if (!onMarkerDragEnd || !e?.latLng) return;
      onMarkerDragEnd({ lat: e.latLng.lat(), lng: e.latLng.lng() });
    },
    [onMarkerDragEnd]
  );

  if (loadError) {
    // Log for debugging, show friendly fallback instead of crashing the page.
    console.error("[MapWrapper] Google Maps failed to load:", loadError);
    return <MapError height={height} className={className} />;
  }

  if (!isLoaded) {
    return <MapLoader height={height} className={className} />;
  }

  return (
    <div className={className} style={{ width: "100%" }}>
      <GoogleMap
        mapContainerStyle={containerStyle}
        center={userMoved ? undefined : center}
        zoom={userMoved ? undefined : zoom}
        options={options}
        onLoad={handleLoad}
        onUnmount={handleUnmount}
        onClick={handleMapClick}
        onDragStart={handleDragStart}
        onZoomChanged={handleZoomChanged}
        onIdle={handleIdle}
      >
        {polygonPath.length >= 3 && (
          <Polygon paths={polygonPath} options={gPolygonOptions} />
        )}
        {polylinePath.length >= 2 && (
          <Polyline path={polylinePath} options={gPolylineOptions} />
        )}
        {resolvedMarkers.map((m, i) => (
          <MarkerF
            key={`${m.latitude}-${m.longitude}-${i}`}
            position={draggedPos[i] ?? { lat: Number(m.latitude), lng: Number(m.longitude) }}
            title={m.title}
            // A bare URL string renders the image at its native pixel size —
            // scaledSize caps it so a large source image doesn't dwarf the map.
            icon={
              m.iconUrl
                ? {
                    url: m.iconUrl,
                    scaledSize: new window.google.maps.Size(36, 36),
                  }
                : undefined
            }
            draggable={draggableMarker}
            onDragEnd={
              draggableMarker
                ? (e) => {
                    if (e?.latLng) {
                      const pos = { lat: e.latLng.lat(), lng: e.latLng.lng() };
                      rememberDrag(i, pos);
                      showDropPulse(pos);
                    }
                    handleDragEnd(e);
                  }
                : undefined
            }
          />
        ))}
        {dropPulse && (
          <OverlayViewF
            key={dropPulse.id}
            position={dropPulse.pos}
            mapPaneName={OverlayView.OVERLAY_LAYER}
            getPixelPositionOffset={() => ({ x: -22, y: -22 })}
          >
            <div className="pinDropPulse" style={{ width: 44, height: 44 }} />
          </OverlayViewF>
        )}
      </GoogleMap>
    </div>
  );
}
