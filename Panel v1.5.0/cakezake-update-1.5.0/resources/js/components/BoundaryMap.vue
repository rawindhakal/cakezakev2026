<template>
    <div>
        <div class="d-flex gap-2 mb-2" v-if="mapProvider === 'google'">
            <button type="button" class="btn btn-sm btn-outline-primary" @click="startDrawArea">
                <i class="fa fa-draw-polygon me-1"></i>
                {{ (value && value.length) ? __('redraw_area') : __('draw_area') }}
            </button>
            <button type="button" class="btn btn-sm btn-outline-success" v-if="drawing"
                :disabled="pointCount < minPoints" @click="finishGoogleDraw">
                <i class="fa fa-check me-1"></i>{{ __('finish') }}
                <span class="badge bg-light text-dark ms-1">{{ pointCount }}</span>
            </button>
            <button type="button" class="btn btn-sm btn-outline-danger" :disabled="!value || !value.length" @click="clearArea">
                <i class="fa fa-trash me-1"></i>{{ __('clear') }}
            </button>
        </div>

        <div class="d-flex flex-wrap gap-2 mb-2" v-if="mapProvider !== 'google' && osmDrawing">
            <button type="button" class="btn btn-sm btn-outline-secondary" :disabled="osmPoints < 1"
                @click="undoLastPoint">
                <i class="fa fa-undo me-1"></i>{{ __('undo_last_point') }}
                <span class="badge bg-light text-dark ms-1">{{ osmPoints }}</span>
            </button>
            <button type="button" class="btn btn-sm btn-outline-success" :disabled="osmPoints < minPoints"
                @click="finishOsmDraw">
                <i class="fa fa-check me-1"></i>{{ __('finish_boundary') }}
            </button>
            <button type="button" class="btn btn-sm btn-outline-danger" @click="cancelOsmDraw">
                <i class="fa fa-times me-1"></i>{{ __('cancel') }}
            </button>
        </div>
        <!-- Address search sits with the map it moves, so each channel tab searches
             into its own catchment. -->
        <div class="position-relative mb-2" v-if="searchable">
            <div class="input-group input-group-sm">
                <span class="input-group-text"><i class="fa fa-search"></i></span>
                <input type="text" class="form-control" v-model="addressQuery"
                    @input="onAddressInput" autocomplete="off"
                    :placeholder="__('search_for_a_place_to_centre_the_map')">
                <span class="input-group-text" v-if="placeLoading">
                    <b-spinner small></b-spinner>
                </span>
            </div>
            <ul class="list-group bm-suggestions" v-if="placeSuggestions.length">
                <li class="list-group-item list-group-item-action" v-for="sug in placeSuggestions"
                    :key="sug.placeId" @mousedown.prevent="selectPlace(sug)">
                    {{ sug.text }}
                </li>
            </ul>
        </div>
        <div ref="mapContainer" class="boundary-map"></div>
        <!-- Explains the grey shapes: areas another zone already covers on this channel. -->
        <div class="bm-legend" v-if="reservedAreas && reservedAreas.length">
            <span class="bm-legend-swatch"></span>
            <span>{{ __('grey_areas_already_covered_on_this_channel') }} ({{ reservedAreas.length }})</span>
        </div>
        <small class="text-primary d-block mt-1" v-if="mapProvider !== 'google'">
            <i class="fa fa-info-circle me-1"></i>{{ __('osm_draw_polygon_hint') }}
        </small>
        <small class="text-danger d-block mt-1" v-if="drawError">
            <i class="fa fa-exclamation-circle me-1"></i>{{ drawError }}
        </small>
        <small class="text-primary d-block mt-1" v-else-if="mapProvider === 'google' && drawing">
            {{ __('draw_polygon_hint') }}
            <span v-if="pointCount">— {{ pointCount }} {{ __('points') }}</span>
        </small>
        <small class="text-muted d-block mt-1" v-if="!value || !value.length">
            {{ __('no_polygon_drawn_yet') }}
        </small>
        <small class="text-success d-block mt-1" v-else>
            {{ __('polygon_drawn') }} ({{ value.length }} {{ __('points') }})
        </small>
    </div>
</template>

<script>
import axios from 'axios';
import { markRaw } from 'vue';
import L from 'leaflet';
import { osmTileUrl, OSM_TILE_OPTIONS } from '../utils/mapTiles.js';
import 'leaflet/dist/leaflet.css';
import 'leaflet-draw';
import 'leaflet-draw/dist/leaflet.draw.css';
import { loadGoogleMaps } from '../utils/googleMaps.js';

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
    iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
    shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

/* How close to a placed point a click has to land to count as that point, in pixels.
   The vertex icons are 8px, and nobody clicks a boundary corner to the pixel. */
const VERTEX_SNAP_PX = 14;

let polygonDrawingPatched = false;
function patchPolygonDrawing() {
    if (polygonDrawingPatched || !L.Draw || !L.Draw.Polygon) {
        return;
    }
    polygonDrawingPatched = true;

    const t = (key) => (typeof window.__ === 'function' ? window.__(key) : key);

    const baseAddHooks = L.Draw.Polygon.prototype.addHooks;
    const baseRemoveHooks = L.Draw.Polygon.prototype.removeHooks;

    const defaultPrecision = { km: 2, ha: 2, m: 0, mi: 2, ac: 2, yd: 0, ft: 0, nm: 2 };
    L.GeometryUtil.readableArea = function (area, isMetric, precision) {
        const digits = L.Util.extend({}, defaultPrecision, precision);
        const round = (value, places) => L.GeometryUtil.formattedNumber(value, places);

        if (!isMetric) {
            const yards = area / 0.836127;          // square yards in a square metre
            if (yards >= 3097600) { return round(yards / 3097600, digits.mi) + ' mi²'; }
            if (yards >= 4840) { return round(yards / 4840, digits.ac) + ' acres'; }

            return round(yards, digits.yd) + ' yd²';
        }

        const kind = typeof isMetric;
        let units = ['ha', 'm'];
        if (kind === 'string') {
            units = [isMetric];
        } else if (kind !== 'boolean') {
            units = isMetric;
        }

        if (area >= 1000000 && units.indexOf('km') !== -1) { return round(area * 0.000001, digits.km) + ' km²'; }
        if (area >= 10000 && units.indexOf('ha') !== -1) { return round(area * 0.0001, digits.ha) + ' ha'; }

        return round(area, digits.m) + ' m²';
    };

    L.Draw.Polygon.include({
        addHooks() {
            baseAddHooks.call(this);
            if (typeof this.options.onDrawHandler === 'function') {
                this.options.onDrawHandler(this);
            }
        },

        removeHooks() {
            baseRemoveHooks.call(this);
            if (typeof this.options.onDrawHandler === 'function') {
                this.options.onDrawHandler(null);
            }
        },

        _updateFinishHandler() {
            const markers = this._markers;

            if (markers.length === 1) {
                markers[0].on('click', this._finishShape, this);
                this._markFirstVertex();

                return;
            }

            markers[markers.length - 1].on('click', this._refuseJoin, this);
        },

        _refuseJoin() {
            this._refuse('boundary_must_close_on_the_first_point');
        },

        _getTooltipText() {
            const count = this._markers.length;
            let text;

            if (count === 0) {
                text = t('draw_boundary_start');
            } else if (count < 3) {
                text = t('draw_boundary_continue');
            } else {
                text = t('draw_boundary_close');
            }

            return { text, subtext: count ? this._getMeasurementString() : null };
        },

        addVertex(latlng) {
            const markers = this._markers || [];
            const hit = this._vertexNear(latlng);

            // Near the start: that is the close, and the only one.
            if (hit === 0) {
                this._finishShape();
                return;
            }

            if (hit > 0) {
                this._refuse('boundary_must_close_on_the_first_point');
                return;
            }

            /* Let the original decide about self-intersection — it owns that geometry.
               It refuses by leaving the marker count where it was. */
            const before = markers.length;
            L.Draw.Polyline.prototype.addVertex.call(this, latlng);

            if (this._markers.length === before) {
                this._refuse('boundary_edges_cannot_cross');
            } else {
                this._reportError('');
            }
        },

        _finishShape() {
            // Three corners is the least that encloses anything.
            if (this._markers.length < 3) {
                this._refuse('polygon_needs_at_least_three_points');
                return;
            }

            this._reportError('');
            L.Draw.Polyline.prototype._finishShape.call(this);
        },

        /** Index of the placed point this click lands on, or -1. */
        _vertexNear(latlng) {
            if (!this._map || !this._markers || !this._markers.length) {
                return -1;
            }

            const point = this._map.latLngToLayerPoint(latlng);

            for (let i = 0; i < this._markers.length; i += 1) {
                const at = this._map.latLngToLayerPoint(this._markers[i].getLatLng());
                if (point.distanceTo(at) <= VERTEX_SNAP_PX) {
                    return i;
                }
            }

            return -1;
        },

        /** Turn the shape red, say why on the map and say why under it. */
        _refuse(key) {
            const message = t(key);
            this.options.drawError.message = message;
            this._showErrorTooltip();
            this._reportError(message);
        },

        _reportError(message) {
            if (typeof this.options.onDrawError === 'function') {
                this.options.onDrawError(message);
            }
        },

        /* The closing point has to be findable, so it does not look like the others. */
        _markFirstVertex() {
            const icon = this._markers[0] && this._markers[0]._icon;
            if (icon) {
                L.DomUtil.addClass(icon, 'bm-first-vertex');
            }
        },
    });
}
patchPolygonDrawing();

export default {
    name: 'BoundaryMap',
    props: {
        // Array of { lat, lng } points.
        modelValue: { type: Array, default: () => [] },
        // Areas already claimed by other zones on this channel, drawn read-only in grey
        // so the admin can see what's taken before they draw. [{ id, name, points }]
        reservedAreas: { type: Array, default: () => [] },
        // Show an address search above the map that pans it to the picked place.
        searchable: { type: Boolean, default: false },
    },
    emits: ['update:modelValue', 'place-selected'],
    data() {
        return {
            mapProvider: 'osm',
            googleMapKey: '',
            map: null,
            drawnItems: null,
            gmap: null,
            gpolygon: null,
            drawing: false,
            drawError: '',
            minPoints: 3,
            osmDrawing: false,
            osmPoints: 0,
            livePointCount: 0,
            mapClickListener: null,
            mapDblClickListener: null,
            reservedLayer: null,   // Leaflet FeatureGroup
            gReserved: [],         // google.maps.Polygon[]
            reservedTip: null,     // Leaflet tooltip
            gReservedTip: null,    // google.maps.InfoWindow
            hoveredReservedId: null,
            addressQuery: '',
            placeSuggestions: [],
            placeLoading: false,
            placeTimer: null,
            placeSessionToken: null,
            placeAbort: null,
            lastPlaceQuery: '',
        };
    },
    computed: {
        value() {
            return this.modelValue || [];
        },
        // Vertices placed so far — the in-progress Google path, else the saved ring.
        pointCount() {
            return this.drawing ? this.livePointCount : this.value.length;
        },
    },
    watch: {
        // The parent loads these asynchronously and swaps them per channel tab.
        reservedAreas: {
            deep: true,
            handler() { this.renderReserved(); },
        },
    },
    async mounted() {
        await this.loadMapProvider();
        this.$nextTick(() => this.initMap());
    },
    beforeUnmount() {
        this.hideReservedTip();
        if (this.gReservedTip) { try { this.gReservedTip.close(); } catch (e) { /* noop */ } this.gReservedTip = null; }
        this.reservedTip = null;
        // Google polygons outlive the component unless detached explicitly.
        for (const p of this.gReserved) { try { p.setMap(null); } catch (e) { /* noop */ } }
        this.gReserved = [];
        if (this.mapClickListener) { this.mapClickListener.remove(); this.mapClickListener = null; }
        if (this.mapDblClickListener) { this.mapDblClickListener.remove(); this.mapDblClickListener = null; }
        if (this._polyDrawer) { try { this._polyDrawer.disable(); } catch (e) { /* noop */ } this._polyDrawer = null; }
        if (this._editHandler) { try { this._editHandler.disable(); } catch (e) { /* noop */ } this._editHandler = null; }
        if (this._onFsChange) {
            document.removeEventListener('fullscreenchange', this._onFsChange);
            this._onFsChange = null;
        }
        if (this.map) {
            this.map.remove();
            this.map = null;
        }
    },
    methods: {
        /**
         * Every polygon change funnels through here, so the ring is normalised once:
         * consecutive duplicate vertices dropped (a double-click to finish adds one),
         * and a trailing vertex equal to the first removed — the ring closes implicitly
         * (server walks i % count), so repeating the start point is redundant.
         * No upper limit on vertices.
         */
        normalizeRing(points) {
            const EPS = 1e-6; // ~0.1 m — same spot, not a deliberate vertex
            const same = (a, b) => Math.abs(a.lat - b.lat) < EPS && Math.abs(a.lng - b.lng) < EPS;

            const out = [];
            for (const p of (points || [])) {
                if (!p || p.lat == null || p.lng == null) continue;
                const pt = { lat: Number(p.lat), lng: Number(p.lng) };
                if (!Number.isFinite(pt.lat) || !Number.isFinite(pt.lng)) continue;
                if (out.length && same(out[out.length - 1], pt)) continue;
                out.push(pt);
            }
            while (out.length > 1 && same(out[0], out[out.length - 1])) out.pop();
            return out;
        },
        emit(points) {
            this.$emit('update:modelValue', this.normalizeRing(points));
        },
        async loadMapProvider() {
            try {
                const res = await axios.get(this.$apiUrl + '/store_settings');
                const rows = res.data?.data?.store_settings || [];
                const get = v => (rows.find(r => r.variable === v) || {}).value || '';
                this.mapProvider = get('map_provider') === 'google' ? 'google' : 'osm';
                this.googleMapKey = get('googleMapApiKey');
            } catch {
                this.mapProvider = 'osm';
            }
        },
        areaColor() {
            const v = getComputedStyle(document.documentElement).getPropertyValue('--bs-primary').trim();
            return v || '#435ebe';
        },
        initMap() {
            if (this.mapProvider === 'google') {
                this.initGoogleMap();
            } else {
                this.initLeafletMap();
            }
        },
        initLeafletMap() {
            if (!this.$refs.mapContainer || this.map) return;
            // Starts wide; an existing polygon fitBounds() over this, and the search
            // box pans it directly.
            this.map = markRaw(L.map(this.$refs.mapContainer).setView([22.0, 79.0], 5));

            L.tileLayer(osmTileUrl(), OSM_TILE_OPTIONS).addTo(this.map);

            // Leaflet has no built-in fullscreen (Google Maps does). Add one via the
            // browser Fullscreen API — no extra dependency.
            this.addFullscreenControl();

            // Reserved areas go on first so the editable polygon draws above them.
            this.reservedLayer = markRaw(new L.FeatureGroup());
            this.map.addLayer(this.reservedLayer);
            this.renderReserved();

            // The reserved shapes are non-interactive so clicks reach the drawing tool,
            // which also means they emit no mouse events. Hit-test them from the map's
            // own mousemove instead to get a hover label without stealing clicks.
            this.map.on('mousemove', e => this.onReservedHover(e.latlng.lat, e.latlng.lng, e.latlng));
            this.map.on('mouseout', () => this.hideReservedTip());

            this.drawnItems = markRaw(new L.FeatureGroup());
            this.map.addLayer(this.drawnItems);

            this.leafletDrawOptions = this.polygonDrawOptions();
            const drawControl = new L.Control.Draw({
                position: 'topright',
                draw: {
                    polygon: this.leafletDrawOptions,
                    polyline: false, rectangle: false, circle: false, marker: false, circlemarker: false,
                },
                edit: { featureGroup: this.drawnItems },
            });
            this.map.addControl(drawControl);

            this.map.on(L.Draw.Event.DRAWVERTEX, e => {
                this.osmPoints = e.layers ? e.layers.getLayers().length : this.osmPoints + 1;
            });
            this.map.on(L.Draw.Event.DRAWSTOP, () => {
                this.osmDrawing = false;
                this.osmPoints = 0;
            });

            this.map.on(L.Draw.Event.DRAWSTART, () => {
                this.osmDrawing = true;
                this.osmPoints = 0;
                this.drawError = '';
                if (this._editHandler) {
                    try { this._editHandler.disable(); } catch (e) { /* noop */ }
                    this._editHandler = null;
                }
            });

            this.map.on(L.Draw.Event.CREATED, e => {
                this.drawError = '';
                this.drawnItems.clearLayers();
                const layer = markRaw(e.layer);
                this.drawnItems.addLayer(layer);
                this.bindLiveEdit(layer);
                this.syncPolygonFromLayer(layer);
                // Freshly drawn — drop straight into edit mode so vertices are draggable.
                this.$nextTick(() => this.enableLeafletEdit());
            });
            this.map.on(L.Draw.Event.EDITED, e => {
                e.layers.eachLayer(layer => this.syncPolygonFromLayer(layer));
            });
            this.map.on(L.Draw.Event.EDITVERTEX, e => { if (e.poly) this.syncPolygonFromLayer(e.poly); });
            this.map.on(L.Draw.Event.EDITMOVE, e => { if (e.layer) this.syncPolygonFromLayer(e.layer); });
            this.map.on(L.Draw.Event.DELETED, () => this.emit([]));

            // Preselect the right tool: edit mode when a polygon already exists (edit
            // screen), draw mode when starting blank (create screen) — so the user doesn't
            // have to click the toolbar button first.
            if (this.value.length) {
                this.renderLeafletPolygon(this.value);
                this.$nextTick(() => this.enableLeafletEdit());
            } else {
                this.$nextTick(() => this.enableLeafletDraw());
            }
        },

        polygonDrawOptions() {
            const areaColor = this.areaColor();

            return {
                allowIntersection: false,
                showArea: true,
                shapeOptions: { color: areaColor, fillColor: areaColor, fillOpacity: 0.25 },
                drawError: {
                    // Bootstrap's danger, and long enough to read the reason.
                    color: '#dc3545',
                    timeout: 4000,
                },
                onDrawError: (message) => { this.drawError = message; },
                onDrawHandler: (handler) => { this._activeDrawer = handler; },
            };
        },

        /** Remove the corner just placed, so one bad click is not a restart. */
        undoLastPoint() {
            if (this._activeDrawer) {
                this._activeDrawer.deleteLastVertex();
                this.drawError = '';
            }
        },

        /* Closes the ring exactly as clicking the first point does — same rule, same
           checks — for anyone who would rather press a button than hit a 14px target. */
        finishOsmDraw() {
            if (this._activeDrawer) {
                this._activeDrawer._finishShape();
            }
        },

        cancelOsmDraw() {
            if (this._activeDrawer) {
                this._activeDrawer.disable();
            }
            this.drawError = '';
        },
        // Programmatically activate the "draw a polygon" handler (same as clicking the
        // toolbar's polygon button).
        enableLeafletDraw() {
            if (!this.map || this._polyDrawer) return;
            this._polyDrawer = markRaw(new L.Draw.Polygon(this.map, this.leafletDrawOptions));
            this._polyDrawer.enable();
        },
        // Programmatically activate the edit handler (same as the toolbar's edit button).
        enableLeafletEdit() {
            if (!this.map || !this.drawnItems || !this.drawnItems.getLayers().length) return;
            if (this._editHandler) { try { this._editHandler.disable(); } catch (e) { /* noop */ } }
            this._editHandler = markRaw(new L.EditToolbar.Edit(this.map, {
                featureGroup: this.drawnItems,
            }));
            this._editHandler.enable();
        },
        async initGoogleMap() {
            if (!this.$refs.mapContainer || this.gmap) return;
            try {
                // DrawingManager was removed in Maps JS API v3.65; polygons are
                // drawn manually via map click listeners, so no 'drawing' lib needed.
                await loadGoogleMaps(this.googleMapKey, []);
            } catch (e) {
                this.mapProvider = 'osm';
                this.initLeafletMap();
                return;
            }
            this.gmap = markRaw(new google.maps.Map(this.$refs.mapContainer, {
                center: { lat: 22.0, lng: 79.0 }, zoom: 5,
                streetViewControl: false, mapTypeControl: true, fullscreenControl: true,
                disableDoubleClickZoom: true,
            }));

            this.renderReserved();

            // Google polygons are clickable:false, so they emit no events either —
            // hit-test from the map's mousemove, same as the Leaflet path.
            this.gmap.addListener('mousemove', e => {
                if (e.latLng) this.onReservedHover(e.latLng.lat(), e.latLng.lng(), null);
            });
            this.gmap.addListener('mouseout', () => this.hideReservedTip());

            if (this.value.length > 0) {
                this.renderGooglePolygon(this.value);
            } else {
                this.enterGoogleDrawMode();
            }
        },
        // Custom Leaflet fullscreen control (native Fullscreen API — no plugin).
        addFullscreenControl() {
            const self = this;
            const Ctrl = L.Control.extend({
                options: { position: 'topleft' },
                onAdd() {
                    const btn = L.DomUtil.create('a', 'leaflet-bar leaflet-control boundary-map-fs-btn');
                    btn.href = '#';
                    btn.title = __('toggle_fullscreen');
                    btn.setAttribute('role', 'button');
                    btn.innerHTML = '<i class="fa fa-expand"></i>';
                    L.DomEvent.on(btn, 'click', (e) => {
                        L.DomEvent.stop(e);
                        self.toggleFullscreen();
                    });
                    return btn;
                },
            });
            this.map.addControl(new Ctrl());

            // Leaflet keeps rendering at the old size after a fullscreen resize —
            // recompute so tiles fill the screen (and shrink back on exit).
            this._onFsChange = () => {
                const el = this.$refs.mapContainer;
                const active = document.fullscreenElement === el;
                if (el) el.classList.toggle('is-fullscreen', active);
                const icon = el?.querySelector('.boundary-map-fs-btn i');
                if (icon) icon.className = active ? 'fa fa-compress' : 'fa fa-expand';
                setTimeout(() => this.map && this.map.invalidateSize(), 120);
            };
            document.addEventListener('fullscreenchange', this._onFsChange);
        },
        toggleFullscreen() {
            const el = this.$refs.mapContainer;
            if (!el) return;
            if (document.fullscreenElement === el) {
                document.exitFullscreen?.();
            } else {
                el.requestFullscreen?.();
            }
        },
        startDrawArea() {
            if (this.mapProvider !== 'google' || !this.gmap) return;
            this.enterGoogleDrawMode();
        },
        // Manual polygon drawing (replaces the removed DrawingManager).
        // Click adds vertices; double-click finishes the shape.
        enterGoogleDrawMode() {
            if (this.gpolygon) { this.gpolygon.setMap(null); this.gpolygon = null; }
            this.emit([]);
            this.drawing = true;
            this.drawError = '';
            this.livePointCount = 0;

            const areaColor = this.areaColor();
            // One empty ring so getPath() returns a usable MVCArray to push into.
            this.gpolygon = markRaw(new google.maps.Polygon({
                paths: [[]], editable: true, draggable: false,
                strokeColor: areaColor, fillColor: areaColor, fillOpacity: 0.25,
            }));
            this.gpolygon.setMap(this.gmap);
            this.bindGooglePolygon(this.gpolygon);
            this.gmap.setOptions({ draggableCursor: 'crosshair' });

            this.mapClickListener = this.gmap.addListener('click', e => {
                this.gpolygon.getPath().push(e.latLng);
                this.livePointCount = this.normalizeRing(this.googlePathPoints(this.gpolygon)).length;
                if (this.livePointCount >= this.minPoints) this.drawError = '';
                this.syncGooglePolygon(this.gpolygon);
            });
            this.mapDblClickListener = this.gmap.addListener('dblclick', () => this.finishGoogleDraw());
        },
        finishGoogleDraw() {
            if (!this.gpolygon) return;

            // Normalise first so the minimum is judged on real vertices, not on the
            // duplicate a finishing double-click leaves behind.
            const ring = this.normalizeRing(this.googlePathPoints(this.gpolygon));
            if (ring.length < this.minPoints) {
                this.drawError = __('polygon_needs_at_least_three_points');
                return; // stay in draw mode so they can keep clicking
            }
            this.drawError = '';

            this.drawing = false;
            if (this.mapClickListener) { this.mapClickListener.remove(); this.mapClickListener = null; }
            if (this.mapDblClickListener) { this.mapDblClickListener.remove(); this.mapDblClickListener = null; }
            if (this.gmap) this.gmap.setOptions({ draggableCursor: null });

            // Write the cleaned ring back so the on-map shape matches what we store.
            this.gpolygon.setPath(ring);
            this.gpolygon.setDraggable(true);
            this.emit(ring);
        },
        googlePathPoints(poly) {
            const path = poly.getPath();
            const pts = [];
            for (let i = 0; i < path.getLength(); i++) {
                const p = path.getAt(i);
                pts.push({ lat: p.lat(), lng: p.lng() });
            }
            return pts;
        },
        // --- address search ------------------------------------------------------
        makeSessionToken() {
            return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
                const r = Math.random() * 16 | 0;
                return (c === 'x' ? r : ((r & 0x3) | 0x8)).toString(16);
            });
        },
        onAddressInput() {
            const input = (this.addressQuery || '').trim();
            if (this.placeTimer) clearTimeout(this.placeTimer);
            if (input.length < 3) { this.placeSuggestions = []; return; }
            if (input === this.lastPlaceQuery) return;
            this.placeTimer = setTimeout(() => this.fetchPlaceSuggestions(input), 500);
        },
        fetchPlaceSuggestions(input) {
            this.lastPlaceQuery = input;
            this.placeLoading = true;
            if (!this.placeSessionToken) this.placeSessionToken = this.makeSessionToken();
            if (this.placeAbort) this.placeAbort.abort();
            this.placeAbort = new AbortController();

            axios.get(this.$baseUrl + '/customer/places_autocomplete', {
                params: { input, source: 'web', sessiontoken: this.placeSessionToken },
                signal: this.placeAbort.signal,
            }).then(res => {
                const list = res.data?.data?.suggestions || [];
                this.placeSuggestions = list.map(sg => ({
                    placeId: sg.placePrediction?.placeId || '',
                    text: sg.placePrediction?.text?.text || '',
                })).filter(sg => sg.placeId);
            }).catch(() => { /* aborted or failed */ })
                .finally(() => { this.placeLoading = false; });
        },
        selectPlace(sug) {
            this.placeLoading = true;
            this.placeSuggestions = [];
            this.addressQuery = sug.text;

            axios.get(this.$baseUrl + '/customer/places_details', {
                params: { place_id: sug.placeId, source: 'web', sessiontoken: this.placeSessionToken },
            }).then(res => {
                const d = res.data?.data;
                if (!d) return;
                const lat = d.location?.latitude;
                const lng = d.location?.longitude;

                // Pan in place — remounting the map would discard a polygon in progress.
                if (lat != null && lng != null) this.panTo(Number(lat), Number(lng));

                const comp = d.addressComponents || [];
                const get = type => (comp.find(c => (c.types || []).includes(type))?.longText) || '';
                this.$emit('place-selected', {
                    placeId: sug.placeId,
                    formattedAddress: d.formattedAddress || sug.text,
                    latitude: lat != null ? Number(lat) : null,
                    longitude: lng != null ? Number(lng) : null,
                    city: get('locality') || get('administrative_area_level_2'),
                    state: get('administrative_area_level_1'),
                    country: get('country'),
                });
            }).catch(() => { })
                .finally(() => {
                    this.placeLoading = false;
                    this.placeSessionToken = null; // end the billing session
                });
        },
        panTo(lat, lng) {
            if (this.mapProvider === 'google' && this.gmap) {
                this.gmap.setCenter({ lat, lng });
                this.gmap.setZoom(Math.max(this.gmap.getZoom() || 0, 13));
            } else if (this.map) {
                this.map.setView([lat, lng], Math.max(this.map.getZoom() || 0, 13));
            }
        },

        // --- reserved-area hover label -------------------------------------------
        // Ray casting: same test the server uses to place a customer in a zone.
        pointInPolygon(lat, lng, pts) {
            let inside = false;
            for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
                const yi = Number(pts[i].lat), xi = Number(pts[i].lng);
                const yj = Number(pts[j].lat), xj = Number(pts[j].lng);
                if (((yi > lat) !== (yj > lat)) && (lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi)) {
                    inside = !inside;
                }
            }
            return inside;
        },
        reservedAt(lat, lng) {
            for (const area of (this.reservedAreas || [])) {
                const pts = area.points || [];
                if (pts.length >= 3 && this.pointInPolygon(lat, lng, pts)) return area;
            }
            return null;
        },
        onReservedHover(lat, lng, latlng) {
            const hit = this.reservedAt(lat, lng);
            if (!hit) { this.hideReservedTip(); return; }

            if (this.mapProvider === 'google') {
                if (!this.gReservedTip) {
                    this.gReservedTip = markRaw(new google.maps.InfoWindow({ disableAutoPan: true }));
                }
                this.gReservedTip.setContent(this.escapeHtml(hit.name));
                this.gReservedTip.setPosition({ lat, lng });
                if (this.hoveredReservedId !== hit.id) this.gReservedTip.open(this.gmap);
            } else {
                if (!this.reservedTip) {
                    this.reservedTip = markRaw(L.tooltip({
                        direction: 'top', offset: [0, -4], className: 'bm-reserved-tip', opacity: 1,
                    }));
                }
                this.reservedTip.setLatLng(latlng).setContent(this.escapeHtml(hit.name));
                if (this.hoveredReservedId !== hit.id) this.reservedTip.addTo(this.map);
            }
            this.hoveredReservedId = hit.id;
            this.setHoverCursor(true);
        },
        hideReservedTip() {
            if (this.hoveredReservedId === null) return;
            this.hoveredReservedId = null;
            if (this.reservedTip && this.map) { try { this.map.closeTooltip(this.reservedTip); } catch (e) { /* noop */ } }
            if (this.gReservedTip) { try { this.gReservedTip.close(); } catch (e) { /* noop */ } }
            this.setHoverCursor(false);
        },
        // Only hint at hover when we're not mid-draw (the crosshair matters more then).
        setHoverCursor(on) {
            const el = this.$refs.mapContainer;
            if (!el || this.drawing) return;
            el.style.cursor = on ? 'help' : '';
        },
        escapeHtml(v) {
            return String(v ?? '').replace(/[&<>"']/g, c => (
                { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
            ));
        },

        // --- reserved (already-taken) areas -------------------------------------
        renderReserved() {
            return this.mapProvider === 'google' ? this.renderReservedGoogle() : this.renderReservedLeaflet();
        },
        renderReservedLeaflet() {
            if (!this.map || !this.reservedLayer) return;
            this.reservedLayer.clearLayers();
            for (const area of (this.reservedAreas || [])) {
                const pts = (area.points || [])
                    .filter(p => p && p.lat != null && p.lng != null)
                    .map(p => [Number(p.lat), Number(p.lng)]);
                if (pts.length < 3) continue;
                const poly = markRaw(L.polygon(pts, {
                    color: '#9aa0a6', fillColor: '#9aa0a6', fillOpacity: 0.18,
                    weight: 1, dashArray: '4 3',
                    // Non-interactive: these are context only. Clicking them used to draw
                    // a focus ring and swallow clicks meant for the map underneath.
                    interactive: false, className: 'bm-reserved',
                }));
                this.reservedLayer.addLayer(poly);
            }
        },
        renderReservedGoogle() {
            for (const p of this.gReserved) p.setMap(null);
            this.gReserved = [];
            if (!this.gmap) return;
            for (const area of (this.reservedAreas || [])) {
                const path = (area.points || [])
                    .filter(p => p && p.lat != null && p.lng != null)
                    .map(p => ({ lat: Number(p.lat), lng: Number(p.lng) }));
                if (path.length < 3) continue;
                const poly = markRaw(new google.maps.Polygon({
                    paths: path, clickable: false, editable: false, draggable: false,
                    strokeColor: '#9aa0a6', strokeWeight: 1, strokeOpacity: 0.9,
                    fillColor: '#9aa0a6', fillOpacity: 0.18, zIndex: 1,
                }));
                poly.setMap(this.gmap);
                this.gReserved.push(poly);
            }
        },
        clearArea() {
            if (this.mapProvider === 'google') {
                if (this.drawing) this.finishGoogleDraw();
                if (this.gpolygon) { this.gpolygon.setMap(null); this.gpolygon = null; }
            } else if (this.drawnItems) {
                this.drawnItems.clearLayers();
            }
            this.drawError = '';
            this.emit([]);
        },
        syncPolygonFromLayer(layer) {
            if (!layer || typeof layer.getLatLngs !== 'function') return;
            let latlngs = layer.getLatLngs();
            if (Array.isArray(latlngs) && Array.isArray(latlngs[0])) latlngs = latlngs[0];
            this.emit((latlngs || []).map(p => ({ lat: p.lat, lng: p.lng })));
        },
        bindLiveEdit(layer) {
            const handler = () => this.syncPolygonFromLayer(layer);
            layer.on('edit', handler);
            layer.on('editdrag', handler);
            layer.on('drag', handler);
        },
        syncGooglePolygon(poly) {
            const path = poly.getPath();
            const pts = [];
            for (let i = 0; i < path.getLength(); i++) {
                const p = path.getAt(i);
                pts.push({ lat: p.lat(), lng: p.lng() });
            }
            this.emit(pts);
        },
        bindGooglePolygon(poly) {
            const path = poly.getPath();
            const handler = () => this.syncGooglePolygon(poly);
            ['set_at', 'insert_at', 'remove_at'].forEach(ev => path.addListener(ev, handler));
        },
        renderLeafletPolygon(points) {
            if (!this.map || !this.drawnItems) return;
            this.drawnItems.clearLayers();
            const latlngs = points.map(p => [p.lat, p.lng]);
            const areaColor = this.areaColor();
            const polygon = markRaw(L.polygon(latlngs, { color: areaColor, fillColor: areaColor, fillOpacity: 0.25 }));
            this.drawnItems.addLayer(polygon);
            this.bindLiveEdit(polygon);
            this.map.fitBounds(polygon.getBounds(), { padding: [20, 20] });
        },
        renderGooglePolygon(points) {
            if (!this.gmap) return;
            if (this.gpolygon) this.gpolygon.setMap(null);
            const paths = points.map(p => ({ lat: Number(p.lat), lng: Number(p.lng) }));
            const areaColor = this.areaColor();
            this.gpolygon = markRaw(new google.maps.Polygon({
                paths, editable: true, draggable: true, strokeColor: areaColor, fillColor: areaColor, fillOpacity: 0.25,
            }));
            this.gpolygon.setMap(this.gmap);
            this.bindGooglePolygon(this.gpolygon);
            const bounds = new google.maps.LatLngBounds();
            paths.forEach(p => bounds.extend(p));
            this.gmap.fitBounds(bounds);
        },
    },
};
</script>

<style scoped>
/* Reserved areas are context, not targets — keep them visually recessive. */
:deep(.bm-reserved) {
    pointer-events: none;
}

/* Leaflet/SVG paths draw a focus ring when clicked — never wanted here. */
:deep(.leaflet-interactive:focus),
:deep(path.leaflet-interactive:focus),
:deep(.bm-reserved:focus) {
    outline: none;
}
/* The map container itself is focusable (tabindex) — the browser blue focus
   outline showed around the whole map while drawing. Suppress it. */
.boundary-map:focus,
:deep(.leaflet-container:focus),
:deep(.leaflet-container:focus-visible) {
    outline: none;
}

:deep(.bm-reserved-tip) {
    background: #5f6368;
    color: #fff;
    border: 0;
    font-size: .72rem;
    font-weight: 600;
    padding: 2px 7px;
    box-shadow: 0 2px 6px rgba(0, 0, 0, .2);
}

:deep(.bm-reserved-tip::before) {
    border-top-color: #5f6368;
}

.bm-suggestions {
    position: absolute;
    z-index: 1080;
    left: 0;
    right: 0;
    max-height: 220px;
    overflow-y: auto;
    box-shadow: 0 6px 18px rgba(0, 0, 0, .12);
}

.bm-suggestions .list-group-item {
    cursor: pointer;
    font-size: .82rem;
    padding: .4rem .6rem;
}
.bm-legend {
    display: flex;
    align-items: center;
    gap: .4rem;
    font-size: .75rem;
    color: var(--app-muted, #6c757d);
    margin-top: .4rem;
}
.bm-legend-swatch {
    width: 14px;
    height: 10px;
    border: 1px dashed #9aa0a6;
    background: rgba(154, 160, 166, .18);
    display: inline-block;
    border-radius: 2px;
}

.boundary-map {
    width: 100%;
    height: 360px;
    border-radius: 8px;
    border: 1px solid #e0e0e0;
    position: relative;
    z-index: 0;
}

/* Native fullscreen: the map element becomes the whole screen, so fill it. */
.boundary-map.is-fullscreen,
.boundary-map:fullscreen {
    width: 100%;
    height: 100%;
    border-radius: 0;
}
</style>

<!-- Unscoped: the fullscreen button is created by Leaflet via the DOM (not this
     component's template), so scoped styles never attach to it and Leaflet's default
     30px `.leaflet-bar a` sizing wins. A global rule is required to override it. -->
<style>
.leaflet-draw-tooltip,
.leaflet-draw-guides,
.leaflet-draw-guide-dash {
    pointer-events: none;
}

.leaflet-editing-icon.bm-first-vertex {
    border-radius: 50%;
    background: #fff;
    border: 3px solid var(--bs-primary, #435ebe);
    box-shadow: 0 0 0 3px rgba(var(--bs-primary-rgb, 67, 94, 190), .25);
    margin-left: -6px !important;
    margin-top: -6px !important;
    width: 14px !important;
    height: 14px !important;
    cursor: pointer;
}

.boundary-map-fs-btn {
    display: flex !important;
    align-items: center;
    justify-content: center;
    width: 34px !important;
    height: 34px !important;
    line-height: 34px !important;
    font-size: 16px !important;
    color: #333;
    background: #fff !important;
}
</style>
