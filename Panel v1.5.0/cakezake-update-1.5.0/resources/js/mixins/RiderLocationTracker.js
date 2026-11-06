/**
 * Reports the rider's position while a delivery is in progress.
 *
 * The customer's map and the admin's order drawer both read a position the rider is
 * expected to have sent. The mobile app sends it; the rider web panel never did, so
 * those maps sat on whatever the app last wrote, or on nothing at all. This fills that
 * gap for riders working from the panel.
 *
 * It posts to `manage_live_tracking` without an `order_id`. The token already says who
 * the rider is, so the server moves every delivery they are out on and replies with how
 * many it moved — a browser has no way of knowing that itself, and asking first would
 * double the traffic. A reply of zero means nothing is in flight, which is the signal to
 * let go of the device's location until there is something to report again.
 *
 * Three things stop it:
 *
 *   * **Nothing out for delivery.** `tracked: 0` releases the geolocation watch; a slow
 *     heartbeat keeps checking so a newly dispatched order starts it again.
 *   * **The panel closes.** Everything is torn down on unmount, so a closed tab or a
 *     logout ends it.
 *   * **The tab is hidden.** A rider in a background tab is not working from the panel,
 *     and browsers throttle background timers anyway, so the positions would arrive
 *     late and unevenly.
 *
 * Position comes from a single `watchPosition`, not a fresh fix per tick: the browser
 * hands one over as the rider moves and the timer only decides how often it is sent on.
 * Refusing the permission stops the whole thing rather than asking again every ten
 * seconds.
 */

/** How often a position is sent while a delivery is in progress, in ms. */
const PUSH_EVERY = 10000;

/** How often to check again once there is nothing to report, in ms. */
const IDLE_EVERY = 60000;

export default {
    mounted() {
        this.startLocationReporting();
    },

    beforeUnmount() {
        this.stopLocationReporting();
    },

    methods: {
        startLocationReporting() {
            if (!navigator.geolocation) {
                return; // Nothing to report with.
            }

            this._trackDenied = false;
            this._trackPosition = null;

            this.beginWatching();

            this._onTrackVisibility = () => {
                if (document.hidden) {
                    this.pauseLocationReporting();
                } else {
                    this.beginWatching();
                }
            };
            document.addEventListener('visibilitychange', this._onTrackVisibility);
        },

        beginWatching() {
            if (this._trackDenied || document.hidden) return;

            if (this._trackWatchId == null) {
                this._trackWatchId = navigator.geolocation.watchPosition(
                    (pos) => { this._trackPosition = pos; },
                    (err) => {
                        /* Permission refused is final: asking again on a timer would
                           pester the rider and never succeed. A timeout or an
                           unavailable fix is temporary, so those are left to recover. */
                        if (err && err.code === err.PERMISSION_DENIED) {
                            this._trackDenied = true;
                            this.stopLocationReporting();
                        }
                    },
                    { enableHighAccuracy: true, maximumAge: PUSH_EVERY, timeout: 30000 }
                );
            }

            this.scheduleNextPush(0);
        },

        /** Re-armed after each reply, so the rate follows whether anything is in flight. */
        scheduleNextPush(delay) {
            if (this._trackPushTimer) {
                clearTimeout(this._trackPushTimer);
            }
            this._trackPushTimer = setTimeout(() => this.pushLocation(), delay);
        },

        pushLocation() {
            if (this._trackDenied) return;

            if (document.hidden) {
                this.pauseLocationReporting();
                return;
            }

            // No fix yet: come back shortly rather than giving up on the whole thing.
            if (!this._trackPosition) {
                this.scheduleNextPush(PUSH_EVERY);
                return;
            }

            const { latitude, longitude } = this._trackPosition.coords;
            if (latitude == null || longitude == null) {
                this.scheduleNextPush(PUSH_EVERY);
                return;
            }

            axios.post(this.$deliveryBoyApiUrl + '/manage_live_tracking', { latitude, longitude })
                .then((res) => {
                    const tracked = Number(res?.data?.data?.tracked || 0);

                    if (tracked > 0) {
                        this.scheduleNextPush(PUSH_EVERY);
                        return;
                    }

                    /* Nothing in flight. Release the device's location and fall back to
                       a slow heartbeat, so a newly dispatched order picks this up again
                       without the browser tracking a rider who is not delivering. */
                    this.releaseWatch();
                    this.scheduleNextPush(IDLE_EVERY);
                })
                .catch(() => {
                    // One missed position is not worth surfacing; try again next tick.
                    this.scheduleNextPush(PUSH_EVERY);
                });
        },

        releaseWatch() {
            if (this._trackWatchId != null) {
                navigator.geolocation.clearWatch(this._trackWatchId);
                this._trackWatchId = null;
                this._trackPosition = null;
            }
        },

        /** Hidden tab: drop the watch and the timer, but keep the listener that revives them. */
        pauseLocationReporting() {
            this.releaseWatch();
            if (this._trackPushTimer) {
                clearTimeout(this._trackPushTimer);
                this._trackPushTimer = null;
            }
        },

        stopLocationReporting() {
            this.pauseLocationReporting();
            if (this._onTrackVisibility) {
                document.removeEventListener('visibilitychange', this._onTrackVisibility);
                this._onTrackVisibility = null;
            }
        },
    },
};
