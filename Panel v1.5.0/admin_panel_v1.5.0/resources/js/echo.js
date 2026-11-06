// Laravel Echo bootstrap for the admin / delivery-boy panels.
//
// Two interchangeable drivers, picked in Settings -> Chat Setting and injected by
// the blade as window.broadcastConfig.driver:
//   reverb -> our own websocket server (php artisan reverb:start must be running)
//   pusher -> Pusher Channels cloud (nothing of ours to run; the client derives its
//             endpoint from the cluster, so no ws host/port is configured here)
//
// Realtime is best-effort: chat pages also poll, so chat still works if the driver
// is off, misconfigured, or the websocket server is down.
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.Pusher = Pusher;

let echoInstance = null;

export function initEcho() {
    if (echoInstance) return echoInstance;
    try {
        // driver === '' means realtime is off (or misconfigured server-side) — chat
        // then relies on its polling fallback.
        const { driver, config: c = {} } = window.broadcastConfig || {};
        if (driver !== 'reverb' && driver !== 'pusher') return null;
        if (!c.key) return null;

        // Both panels authenticate with the same Passport token, but each actor hits the
        // auth route under its own prefix (delivery boys are root-mounted at
        // /delivery_boy, admins under /api). Either would authorize a boy — the guard is
        // the same — but keeping them separate means the boy app and boy panel share one
        // endpoint.
        let isDeliveryBoy = false;
        try {
            const user = JSON.parse(localStorage.getItem('user') || 'null');
            isDeliveryBoy = Number(user?.role_id) === 3;
        } catch (e) { /* malformed user blob — fall back to the admin endpoint */ }

        const prefix = isDeliveryBoy ? '/delivery_boy' : '/api';
        const common = {
            authEndpoint: (window.baseUrl || '') + prefix + '/broadcasting/auth',
            auth: { headers: { Authorization: 'Bearer ' + localStorage.getItem('token') } },
        };

        if (driver === 'pusher') {
            if (!c.cluster) return null;

            echoInstance = new Echo({
                ...common,
                broadcaster: 'pusher',
                key: c.key,
                cluster: c.cluster,
                forceTLS: true,
            });
        } else {
            const port = Number(c.port || 8080);

            echoInstance = new Echo({
                ...common,
                broadcaster: 'reverb',
                key: c.key,
                wsHost: c.host || window.location.hostname,
                wsPort: port,
                wssPort: port,
                forceTLS: c.scheme === 'https',
                enabledTransports: ['ws', 'wss'],
            });
        }
    } catch (e) {
        echoInstance = null;
    }
    return echoInstance;
}

export function getEcho() {
    return echoInstance;
}
