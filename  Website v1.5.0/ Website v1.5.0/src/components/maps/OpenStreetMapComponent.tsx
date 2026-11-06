"use client";

import { useEffect, useMemo, useRef, useState, MutableRefObject } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  Polygon,
  Polyline,
  useMap,
  useMapEvents,
} from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import MapLoader from "./MapLoader";
import type { MapComponentProps, MapLatLng } from "./types";

// Unique sequence counter for Leaflet container keys
let mapInstanceSeq = 0;

// Default Leaflet marker icon configuration using CDN assets
const DEFAULT_ICON = new L.Icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl:
    "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

// Draggable pin has no baked shadow — a pulse marks the ground spot on drop instead.
const DRAG_ICON = new L.Icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl:
    "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
});

// Sync Leaflet view on center/zoom prop changes, until the user takes over
function RecenterController({
  center,
  zoom,
  userMovedRef,
}: {
  center: L.LatLngExpression;
  zoom: number;
  userMovedRef: MutableRefObject<boolean>;
}) {
  const map = useMap();
  useEffect(() => {
    if (userMovedRef.current) return;
    map.setView(center, zoom);
  }, [map, center, zoom, userMovedRef]);
  return null;
}

// Flag manual pan/zoom so data refreshes stop snapping the viewport back
function UserMoveController({
  userMovedRef,
}: {
  userMovedRef: MutableRefObject<boolean>;
}) {
  const map = useMap();
  useEffect(() => {
    const mark = (e: L.LeafletEvent & { hard?: boolean }) => {
      // Programmatic setView/fitBounds pass no originating DOM event.
      if ((e as any).originalEvent || map.getContainer().matches(":hover")) {
        userMovedRef.current = true;
      }
    };
    map.on("dragstart", mark);
    map.on("zoomstart", mark);
    return () => {
      map.off("dragstart", mark);
      map.off("zoomstart", mark);
    };
  }, [map, userMovedRef]);
  return null;
}

// Forward map click events to callback
function ClickController({ onMapClick }: { onMapClick?: (coords: MapLatLng) => void }) {
  useMapEvents({
    click(e) {
      onMapClick?.({ lat: e.latlng.lat, lng: e.latlng.lng });
    },
  });
  return null;
}

// Recompute map container bounds after mounting
function ResizeController() {
  const map = useMap();
  useEffect(() => {
    const fix = () => map.invalidateSize();
    const timers = [0, 150, 400, 800].map((ms) => setTimeout(fix, ms));
    window.addEventListener("resize", fix);
    return () => {
      timers.forEach(clearTimeout);
      window.removeEventListener("resize", fix);
    };
  }, [map]);
  return null;
}

// Capture Leaflet map instance and trigger onReady callback
function MapReadyController({
  mapRef,
  onReady,
}: {
  mapRef: MutableRefObject<L.Map | null>;
  onReady?: () => void;
}) {
  const map = useMap();
  useEffect(() => {
    mapRef.current = map;
    onReady?.();
  }, [map, mapRef, onReady]);
  return null;
}

// Fit map view bounds to points
function FitBoundsController({
  points,
  userMovedRef,
}: {
  points: [number, number][];
  userMovedRef: MutableRefObject<boolean>;
}) {
  const map = useMap();
  // Fit once per point-set shape. A live feed hands us new coordinates every
  // poll; refitting each time re-zoomed the map under the user.
  const fittedForRef = useRef<number>(0);
  useEffect(() => {
    if (userMovedRef.current) return;
    if (!points || points.length === 0) return;
    const alreadyFitted = fittedForRef.current === points.length;
    if (alreadyFitted) {
      // Keep the moving point (first marker, e.g. the rider) in view without
      // touching the zoom level.
      map.panInside(points[0], { padding: [40, 40] });
      return;
    }
    fittedForRef.current = points.length;
    if (points.length === 1) {
      map.setView(points[0], map.getZoom());
      return;
    }
    map.fitBounds(points, { padding: [40, 40] });
  }, [map, points, userMovedRef]);
  return null;
}

// OpenStreetMap view component using react-leaflet
// Pin lifts while dragged, settles on release and leaves a soft ring at the drop point.
const DROP_RING_ICON = new L.DivIcon({
  className: "pinDropPulse",
  iconSize: [44, 44],
  iconAnchor: [22, 22],
});

const liftPin = (e: any) => {
  const el = e.target?.getElement?.();
  el?.classList.remove("pinSettle");
  el?.classList.add("pinLifted");
};

const dropPin = (e: any) => {
  const marker = e.target;
  const el = marker?.getElement?.();
  if (el) {
    el.classList.add("pinSettle");
    el.classList.remove("pinLifted");
    setTimeout(() => el.classList.remove("pinSettle"), 350);
  }
  const map = marker?._map;
  if (!map) return;
  const ring = L.marker(marker.getLatLng(), { icon: DROP_RING_ICON, interactive: false, keyboard: false }).addTo(map);
  setTimeout(() => ring.remove(), 1300);
};

export default function OpenStreetMapComponent({
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
  const [mounted, setMounted] = useState(false);
  const mapRef = useRef<L.Map | null>(null);
  // Once the user pans/zooms, data refreshes must not re-fit the viewport.
  const userMovedRef = useRef(false);
  const [containerKey] = useState(() => ++mapInstanceSeq);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMounted(true);
    return () => {
      mapRef.current = null;
    };
  }, []);

  const center = useMemo(
    () => [Number(latitude), Number(longitude)] as [number, number],
    [latitude, longitude],
  );

  const containerStyle = useMemo(
    () => ({
      width: "100%",
      height: typeof height === "number" ? `${height}px` : height,
    }),
    [height],
  );

  const resolvedMarkers = useMemo(() => {
    // Leaflet throws on a NaN LatLng, so drop markers with unusable coords.
    const valid = Array.isArray(markers)
      ? markers.filter(
          (m) =>
            Number.isFinite(Number(m.latitude)) &&
            Number.isFinite(Number(m.longitude)),
        )
      : [];
    if (valid.length > 0) return valid;
    if (showCenterMarker && Number.isFinite(center[0]) && Number.isFinite(center[1]))
      return [{ latitude: center[0], longitude: center[1] }];
    return [];
  }, [markers, showCenterMarker, center]);

  // Dragged pin positions, kept until the parent passes new coords — otherwise any
  // re-render before the parent updates snaps the pin back to its old spot.
  const markersKey = resolvedMarkers.map((m) => `${m.latitude},${m.longitude}`).join("|");
  const [dragged, setDragged] = useState<{ key: string; pos: Record<number, MapLatLng> }>({ key: markersKey, pos: {} });
  if (dragged.key !== markersKey) setDragged({ key: markersKey, pos: {} });
  const draggedPos = dragged.key === markersKey ? dragged.pos : {};
  const rememberDrag = (index: number, pos: MapLatLng) =>
    setDragged((prev) => ({ key: prev.key, pos: { ...prev.pos, [index]: pos } }));

  const polylinePositions = useMemo(
    () =>
      Array.isArray(polyline)
        ? polyline
            .map((p) => [Number(p.latitude), Number(p.longitude)] as [number, number])
            .filter(([lat, lng]) => Number.isFinite(lat) && Number.isFinite(lng))
        : [],
    [polyline],
  );

  const polygonPositions = useMemo(
    () =>
      Array.isArray(polygon)
        ? polygon
            .map((p) => [Number(p.lat), Number(p.lng)] as [number, number])
            .filter(([lat, lng]) => Number.isFinite(lat) && Number.isFinite(lng))
        : [],
    [polygon],
  );

  const fitPoints = useMemo(() => {
    if (!fitToMarkers) return [];
    return [
      ...resolvedMarkers.map((m) => [Number(m.latitude), Number(m.longitude)] as [number, number]),
      ...polylinePositions,
      ...polygonPositions,
    ].filter(([lat, lng]) => Number.isFinite(lat) && Number.isFinite(lng));
  }, [fitToMarkers, resolvedMarkers, polylinePositions, polygonPositions]);

  const leafletPolylineOptions = useMemo(
    () => ({
      color: polylineOptions?.color ?? "#16a34a",
      weight: polylineOptions?.weight ?? 6,
      opacity: polylineOptions?.opacity ?? 0.9,
    }),
    [polylineOptions],
  );

  const leafletPolygonOptions = useMemo(
    () => ({
      color: polygonOptions?.color ?? "#2563eb",
      weight: polygonOptions?.weight ?? 2,
      opacity: polygonOptions?.opacity ?? 0.9,
      fillColor: polygonOptions?.color ?? "#2563eb",
      fillOpacity: polygonOptions?.fillOpacity ?? 0.12,
      interactive: false,
    }),
    [polygonOptions],
  );

  if (!mounted) {
    return <MapLoader height={height} className={className} />;
  }

  return (
    <div className={className} style={{ width: "100%" }}>
      {/* Leaflet map container */}
      <MapContainer
        key={`osm-map-${containerKey}`}
        {...({ center, zoom, scrollWheelZoom: true } as object)}
        style={containerStyle}
      >
        <MapReadyController mapRef={mapRef} onReady={onReady} />
        <UserMoveController userMovedRef={userMovedRef} />
        <TileLayer
          {...({
            attribution:
              '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
          } as object)}
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <ResizeController />
        {fitToMarkers && fitPoints.length > 0 ? (
          <FitBoundsController points={fitPoints} userMovedRef={userMovedRef} />
        ) : (
          <RecenterController
            center={center}
            zoom={zoom}
            userMovedRef={userMovedRef}
          />
        )}
        {onMapClick && <ClickController onMapClick={onMapClick} />}
        {polygonPositions.length >= 3 && (
          <Polygon
            positions={polygonPositions}
            pathOptions={leafletPolygonOptions}
          />
        )}
        {polylinePositions.length >= 2 && (
          <Polyline
            positions={polylinePositions}
            pathOptions={leafletPolylineOptions}
          />
        )}
        {resolvedMarkers.map((m, i) => {
          // L.Icon cannot rotate, so a rotated marker goes through divIcon.
          const rot = Number(m.rotation);
          const icon = !m.iconUrl
            ? draggableMarker
              ? DRAG_ICON
              : DEFAULT_ICON
            : !Number.isFinite(rot)
              ? new L.Icon({
                  iconUrl: m.iconUrl,
                  iconSize: [32, 32],
                  iconAnchor: [16, 32],
                  popupAnchor: [0, -32],
                })
              : new L.DivIcon({
                  className: "",
                  iconSize: [32, 32],
                  iconAnchor: [16, 16],
                  popupAnchor: [0, -16],
                  html: `<img src="${m.iconUrl}" alt="" style="width:32px;height:32px;display:block;transform:rotate(${rot}deg);transform-origin:50% 50%;" />`,
                });
          return (
            <Marker
              key={`marker-${i}`}
              position={
                draggedPos[i]
                  ? [draggedPos[i].lat, draggedPos[i].lng]
                  : [Number(m.latitude), Number(m.longitude)]
              }
              {...({ icon, draggable: draggableMarker } as object)}
              eventHandlers={
                draggableMarker
                  ? {
                      dragstart: liftPin,
                      dragend: (e: any) => {
                        dropPin(e);
                        const { lat, lng } = e.target.getLatLng();
                        rememberDrag(i, { lat, lng });
                        onMarkerDragEnd?.({ lat, lng });
                      },
                    }
                  : undefined
              }
            >
              {m.title ? <Popup>{m.title}</Popup> : null}
            </Marker>
          );
        })}
      </MapContainer>
    </div>
  );
}
