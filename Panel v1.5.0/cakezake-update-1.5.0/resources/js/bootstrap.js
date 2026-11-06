import _ from 'lodash';
window._ = _;

/**
 * We'll load the axios HTTP library which allows us to easily issue requests
 * to our Laravel back-end. This library automatically handles sending the
 * CSRF token as a header based on the value of the "XSRF" token cookie.
 */

import axios from 'axios';
window.axios = axios;

window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';

/**
 * Microsoft Clarity custom events.
 */
import { trackRequest } from './utils/clarity.js';

window.axios.interceptors.response.use(
    (response) => {
        try {
            trackRequest(response?.config?.url, response?.data);
        } catch (e) {
            // Analytics must never interfere with the request pipeline.
        }
        return response;
    },
    (error) => Promise.reject(error)
);

function redirectToLoginAfterAuthLoss() {
    let user = null;
    try {
        user = JSON.parse(window.localStorage.getItem('user') || 'null');
    } catch (e) {
        // Corrupt user blob — fall back to the admin login below.
    }

    // Pick the right login page BEFORE wiping storage.
    let target = '/login';
    if (user) {
        if (Number(user.role_id) === 3) {
            target = '/delivery_boy/login';
        } else if (user.branch_id || user.is_branch_owner || (user.branch && user.branch.id)) {
            target = '/branch/login';
        }
    }
    // Never loop when we're already sitting on that login page.
    if (window.location.pathname.replace(/\/+$/, '') === target) return;

    // Preserve the language selection across the storage wipe (mirrors Auth.logout()).
    const lang = window.localStorage.getItem('lang');
    const language = window.localStorage.getItem('language');
    window.localStorage.clear();
    if (lang !== null) window.localStorage.setItem('lang', lang);
    if (language !== null) window.localStorage.setItem('language', language);
    delete window.axios.defaults.headers.common['Authorization'];

    window.location.replace(target);
}

window.axios.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error?.response?.status === 401 && window.localStorage.getItem('token')) {
            redirectToLoginAfterAuthLoss();
            return new Promise(() => {});
        }
        return Promise.reject(error);
    }
);
