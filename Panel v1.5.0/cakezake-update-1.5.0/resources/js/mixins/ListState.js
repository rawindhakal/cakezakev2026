/**
 * Remembers where you were in a list.
 *
 * Open a record from page 3, press Back, and the list used to reload at page 1 — the
 * component is destroyed on navigation, so `currentPage` reset to its default. This
 * keeps the paging (and any filters a page opts in) in sessionStorage, keyed by route,
 * and puts them back when the list mounts again.
 *
 * Usage in a list component:
 *
 *     mixins: [ListState],
 *     listState: ['currentPage', 'perPage', 'search'],   // defaults to currentPage + perPage
 *
 * Only a return from one of the list's own pages restores — /products/edit/12 back to
 * /products, however you got there (browser Back, a Cancel button, or a save that routes
 * home). Reloading the list, or opening it from the menu, starts clean at page 1: a
 * reload reads as "start over".
 *
 * State lives for the browser tab only: a fresh tab starts at page 1, which is what
 * someone opening the panel expects.
 */
const PREFIX = 'list-state:';

/**
 * Where the last navigation came from.
 *
 * A popstate listener is not reliable here: Vue Router registers its own listener first
 * and can resolve the route — creating this component — before ours ever runs. The
 * router's own afterEach always fires before the incoming component is created, so it
 * is the dependable signal.
 */
let previousPath = null;
let routerHooked = false;

function hookRouter(router) {
    if (routerHooked || !router) return;
    routerHooked = true;
    router.afterEach((to, from) => {
        // START_LOCATION has no name and path '/', which is exactly what a fresh load
        // looks like — and a fresh load must not restore.
        previousPath = from && from.name ? from.path : null;
    });
}

/**
 * Restore only when returning from one of this list's own pages — /products/edit/12
 * back to /products. A reload has no previous route, and arriving from the menu comes
 * from somewhere else entirely, so both start clean.
 */
function cameFromDetailOf(listPath) {
    return !!previousPath && previousPath !== listPath && previousPath.startsWith(listPath + '/');
}

export default {
    data() {
        return {
            // True while the saved state is being applied, so a page can tell a restore
            // from a real filter change (a filter change must go back to page 1).
            listStateRestoring: false,
        };
    },
    created() {
        hookRouter(this.$router);

        const keys = this.$options.listState || ['currentPage', 'perPage'];
        this._listStateKeys = keys;
        this._listPath = this.$route ? this.$route.path : window.location.pathname;
        this._listStateKey = PREFIX + this._listPath;

        let saved = null;
        try {
            saved = JSON.parse(window.sessionStorage.getItem(this._listStateKey) || 'null');
        } catch (e) { /* corrupt entry — start fresh */ }

        if (saved && cameFromDetailOf(this._listPath)) {
            this.listStateRestoring = true;
            keys.forEach((k) => {
                if (saved[k] !== undefined && this[k] !== undefined) this[k] = saved[k];
            });
            // Left standing until a page consumes it. A timer would be wrong: the first
            // filter pass often runs from an async callback (country lookup), long after
            // any tick would have cleared the flag — and that pass would reset the page.
        }

        // Persist on change. Deep is unnecessary — these are scalars.
        keys.forEach((k) => {
            this.$watch(k, () => this.saveListState());
        });
    },
    methods: {
        /**
         * True once, on the first filter pass after a restore, so a page can skip its
         * "reset to page 1". Every later call — a real filter change — returns false.
         */
        consumeListRestore() {
            if (!this.listStateRestoring) return false;
            this.listStateRestoring = false;

            return true;
        },
        saveListState() {
            if (!this._listStateKeys) return;
            const state = {};
            this._listStateKeys.forEach((k) => { state[k] = this[k]; });
            try {
                window.sessionStorage.setItem(this._listStateKey, JSON.stringify(state));
            } catch (e) { /* private mode / quota — paging just won't be remembered */ }
        },
        /** Forget this list's position — call it when the underlying set changes shape. */
        clearListState() {
            try {
                window.sessionStorage.removeItem(this._listStateKey);
            } catch (e) { /* nothing to clear */ }
        },
    },
};
