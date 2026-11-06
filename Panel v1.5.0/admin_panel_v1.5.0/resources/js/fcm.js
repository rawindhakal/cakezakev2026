import { initializeApp } from 'firebase/app';
import { getMessaging, getToken, onMessage, isSupported } from 'firebase/messaging';
import toastr from 'toastr';
import { registerPanelServiceWorker } from './pwa.js';

async function initFcm() {
    const cfg = window.firebaseConfig;
    if (!cfg || !cfg.apiKey || !cfg.projectId || !cfg.messagingSenderId || !cfg.appId) return;
    if (!('Notification' in window)) return;
    if (!(await isSupported())) return;

    const base = window.baseUrl || '';
    const app = initializeApp(cfg);
    const messaging = getMessaging(app);

    try {
        const permission = await Notification.requestPermission();
        if (permission === 'granted') {

            const swReg = await registerPanelServiceWorker(cfg);
            const token = await getToken(messaging, {
                vapidKey: window.firebaseVapidKey || undefined,
                serviceWorkerRegistration: swReg,
            });
            window.panelFcmToken = token || '';
        }
    } catch (error) {
        console.error('FCM registration failed:', error);
    }

    onMessage(messaging, async (payload) => {
        const d = payload.data || {};
        if (d.type === 'new_order') {
            new Audio(base + '/assets/order_sound.mp3').play();
            toastr.options = {
                onclick: () => { window.location.href = base + '/orders?order_id=' + d.id; },
                showDuration: '60000',
                hideDuration: '20000',
                timeOut: '60000',
                extendedTimeOut: '10000',
                closeButton: true,
            };
            toastr.info(d.message, d.title);
        }

        // Don't raise a browser notification on a backgrounded tab.
        if (document.hidden) return;

        // For chat pushes, if this admin is already viewing that conversation, skip the
        // notification (the open thread's realtime handler already shows the message).
        if (d.type === 'chat' && String(d.id) === String(window.activeChatConversationId || '')) return;

        const notifOptions = {
            body: d.body,
            icon: d.icon,
            // The service worker's notificationclick handler reads this.
            data: { click_action: d.click_action || (base + '/orders?order_id=' + d.id) },
        };
        // Show the attachment preview when the message carries an image URL.
        if (d.image) notifOptions.image = d.image;

        const reg = await registerPanelServiceWorker();
        if (reg) {
            reg.showNotification(d.title, notifOptions);
            return;
        }
        try {
            const browserNotif = new Notification(d.title, notifOptions);
            browserNotif.onclick = () => {
                window.focus();
                window.location.href = notifOptions.data.click_action;
            };
        } catch (e) { /* no notification support at all */ }
    });
}

initFcm();
