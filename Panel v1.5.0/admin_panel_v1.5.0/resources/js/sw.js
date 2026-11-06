/**
 * The panel's one service worker.
 *
 * It has two jobs that must live in the same file: Workbox precaching for the PWA, and
 * Firebase background messaging. A second worker registered at the same scope REPLACES
 * the first, so shipping a separate firebase-messaging-sw.js alongside this would
 * silently kill web push (or caching, depending which registered last).
 */
import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching';
import { registerRoute, NavigationRoute } from 'workbox-routing';
import { NetworkFirst, CacheFirst, StaleWhileRevalidate } from 'workbox-strategies';
import { ExpirationPlugin } from 'workbox-expiration';

// Hashed build assets, injected at build time.
precacheAndRoute(self.__WB_MANIFEST || []);
cleanupOutdatedCaches();

/**
 * The app shell is network-first: a deploy must be picked up on the next load, and a
 * stale shell paired with fresh assets is a broken panel. Falls back to cache offline.
 */
registerRoute(
    new NavigationRoute(
        new NetworkFirst({
            cacheName: 'panel-shell',
            networkTimeoutSeconds: 5,
            plugins: [new ExpirationPlugin({ maxEntries: 8 })],
        }),
        // Never intercept the API, downloads or auth callbacks — those must hit the server.
        { denylist: [/^\/api\//, /^\/storage\//, /^\/linkstorage/, /^\/migration/, /^\/logs/] },
    ),
);

registerRoute(
    ({ url }) => url.pathname.startsWith('/build/assets/'),
    new StaleWhileRevalidate({
        cacheName: 'panel-build',
        plugins: [
            new ExpirationPlugin({ maxEntries: 400, maxAgeSeconds: 60 * 60 * 24 * 30 }),
            {
                cacheWillUpdate: async ({ request, response }) => {
                    if (!response || response.status !== 200) {
                        return null;
                    }
                    const type = response.headers.get('content-type') || '';
                    const wantsScript = request.url.endsWith('.js');
                    const wantsStyle = request.url.endsWith('.css');
                    if ((wantsScript || wantsStyle) && type.includes('text/html')) {
                        return null; // server answered with the app shell, not the asset
                    }

                    return response;
                },
            },
        ],
    }),
);

/** Fonts and images change rarely and are safe to serve from cache. */
registerRoute(
    ({ request }) => ['font', 'image'].includes(request.destination),
    new CacheFirst({
        cacheName: 'panel-static',
        plugins: [new ExpirationPlugin({ maxEntries: 200, maxAgeSeconds: 60 * 60 * 24 * 30 })],
    }),
);

// API responses are deliberately NOT cached. An admin acting on a stale order total or
// stock count is worse than an offline error.

/* ------------------------------------------------------------------ *
 * Firebase background messaging (was public/firebase-messaging-sw.js)
 * ------------------------------------------------------------------ */
importScripts('https://www.gstatic.com/firebasejs/11.1.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.1.0/firebase-messaging-compat.js');

// The page passes the project config on the registration URL, so one worker file serves
// whatever Firebase project this install is configured with.
const params = new URLSearchParams(self.location.search);
if (params.get('apiKey') && params.get('projectId')) {
    firebase.initializeApp({
        apiKey: params.get('apiKey'),
        projectId: params.get('projectId'),
        messagingSenderId: params.get('messagingSenderId'),
        appId: params.get('appId'),
    });

    firebase.messaging().onBackgroundMessage(function (payload) {
        const notification = payload.data || {};
        const title = notification.title || '';
        const options = {
            body: notification.body || notification.message || '',
            icon: notification.icon,
            data: { click_action: notification.click_action || notification.id || '' },
        };
        return self.registration.showNotification(title, options);
    });
}

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    const target = (event.notification.data && event.notification.data.click_action) || '/';
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
            for (const client of list) {
                if ('focus' in client) return client.focus();
            }
            return clients.openWindow(target);
        }),
    );
});
