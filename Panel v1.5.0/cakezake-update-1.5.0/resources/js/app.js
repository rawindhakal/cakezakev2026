import Auth from "./Auth.js";
import './bootstrap.js';
import { createApp } from 'vue';
import router from './router/index.js'
import { createBootstrap } from 'bootstrap-vue-next';
import 'bootstrap/dist/css/bootstrap.css';
import 'bootstrap-vue-next/dist/bootstrap-vue-next.css';

import Swal from 'sweetalert2/dist/sweetalert2.js';
import AppSelect from './components/AppSelect.vue';

import Permissions from './mixins/Permissions.vue';

import VueToast, { useToast } from 'vue-toast-notification';
import 'vue-toast-notification/dist/theme-sugar.css';
import 'vue-multiselect/dist/vue-multiselect.min.css';
import { VueClipboard as Clipboard } from '@soerenmartius/vue3-clipboard';
import VueGoogleMaps from '@fawmi/vue-google-maps';

import VueApexCharts from 'vue3-apexcharts';

import VueFormWizard from 'vue3-form-wizard';
import 'vue3-form-wizard/dist/style.css';

import Vue3EasyDataTable from 'vue3-easy-data-table';
import 'vue3-easy-data-table/dist/style.css';

import MazerDatatable from './components/MazerDatatable.vue';
import FileUpload from './components/FileUpload.vue';
import SeoSection from './components/SeoSection.vue';
import EntityCardSkeleton from './components/EntityCardSkeleton.vue';

import CryptoJS from "crypto-js";

import mitt from 'mitt';

const secretKey = "ewgrrtoecaemr";

function decryptMapApiKey(encryptedKey) {
    try {
        const bytes = CryptoJS.AES.decrypt(encryptedKey, secretKey);
        return bytes.toString(CryptoJS.enc.Utf8);
    } catch (error) {
        console.error("Decryption failed:", error);
        return null;
    }
}

let decryptedKey = decryptMapApiKey(window.MapApiKey);
let decryptedMapKey = decryptMapApiKey(window.GoogleMapApiKey);

window.Swal = Swal;
import toastr from 'toastr';
import dayjs from './utils/dayjs';
window.dayjs = dayjs;
window.toastr = toastr;

// Firebase Cloud Messaging (web push) — self-invokes; no-ops if config not injected.
import './fcm.js';
import { registerPanelServiceWorker, initInstallPrompt } from './pwa.js';

registerPanelServiceWorker(window.firebaseConfig || null);
initInstallPrompt();

const app = createApp({});

app.use(router);
app.use(createBootstrap());
app.use(VueToast);
app.use(Clipboard);
app.use(VueFormWizard);
app.use(VueApexCharts);

app.use(VueGoogleMaps, {
    load: {
        key: window.GoogleMapApiKey || window.MapApiKey || decryptedMapKey || decryptedKey,
        libraries: 'places,drawing',
    },
});

app.component('apexchart', VueApexCharts);
app.component('AppSelect', AppSelect);
app.component('EasyDataTable', Vue3EasyDataTable);
app.component('MazerDatatable', MazerDatatable);
app.component('FileUpload', FileUpload);
app.component('SeoSection', SeoSection);
app.component('EntityCardSkeleton', EntityCardSkeleton);

import InfiniteLoading from 'v3-infinite-loading';
app.component('InfiniteLoading', InfiniteLoading);

app.mixin(Permissions);

const emitter = mitt();
app.config.globalProperties.$eventBus = emitter;

app.config.globalProperties.$googleMapsKey = window.GoogleMapApiKey || window.MapApiKey || decryptedMapKey || decryptedKey;
app.config.globalProperties.$appName = window.appName;
app.config.globalProperties.$appLogo = window.appLogo;
app.config.globalProperties.$panelLoginBackgroundImg = window.panelLoginBackgroundImg;
app.config.globalProperties.$currency = window.currency;
app.config.globalProperties.$supportEmail = window.supportEmail;
app.config.globalProperties.$supportNumber = window.supportNumber;
app.config.globalProperties.$isDemo = window.isDemo;
app.config.globalProperties.$currentVersion = window.currentVersion;
app.config.globalProperties.$deliveryBoyBonusSettings = window.deliveryBoyBonusSettings;

app.config.globalProperties.$websiteUrl = window.websiteUrl;
app.config.globalProperties.$copyrightDetails = window.copyrightDetails;

// Convert #rrggbb -> "r, g, b" for Bootstrap RGB triplet vars
function _hexToRgb(hex) {
    const m = String(hex || '').match(/^#?([0-9a-fA-F]{6})$/);
    if (!m) return null;
    const v = parseInt(m[1], 16);
    return ((v >> 16) & 255) + ', ' + ((v >> 8) & 255) + ', ' + (v & 255);
}

// Override --bs-primary on :root via inline style (beats any stylesheet) so all
// Bootstrap utilities (text-primary, btn-primary, bg-primary, etc.) follow.
window.applyAdminThemeColor = function (color) {
    if (!/^#[0-9a-fA-F]{6}$/.test(color || '')) return;
    const rgb = _hexToRgb(color);
    const root = document.documentElement;
    root.style.setProperty('--bs-primary', color, 'important');
    root.style.setProperty('--bs-primary-rgb', rgb, 'important');
    root.style.setProperty('--bs-link-color', color, 'important');
    root.style.setProperty('--bs-link-color-rgb', rgb, 'important');
    if (document.body) {
        document.body.style.setProperty('--bs-primary', color, 'important');
        document.body.style.setProperty('--bs-primary-rgb', rgb, 'important');
    }
    window.adminThemeColor = color;
};

window.applyAdminThemeColor(window.adminThemeColor || '#FE3C5E');

app.config.globalProperties.$adminThemeColor = window.adminThemeColor;
app.config.globalProperties.$baseUrl = window.baseUrl;
app.config.globalProperties.$apiUrl = window.baseUrl + '/api';
app.config.globalProperties.$deliveryBoyApiUrl = window.baseUrl + '/delivery_boy';
app.config.globalProperties.$storageUrl = window.baseUrl + '/storage/';

app.config.globalProperties.$roleSuperAdmin = "Super Admin";
app.config.globalProperties.$roleDeliveryBoy = "Delivery Boy";
app.config.globalProperties.$roleNameBranch = "Branch";

app.config.globalProperties.$mobileWidth = 991;
app.config.globalProperties.$currentWidth = window.innerWidth;
app.config.globalProperties.$currentHeight = window.innerHeight;

app.config.globalProperties.$setWindowSize = function () {
    if (typeof (window.innerWidth) == 'number') {
        app.config.globalProperties.$currentWidth = window.innerWidth;
        app.config.globalProperties.$currentHeight = window.innerHeight;
    } else {
        if (document.documentElement && (document.documentElement.clientWidth || document.documentElement.clientHeight)) {
            app.config.globalProperties.$currentWidth = document.documentElement.clientWidth;
            app.config.globalProperties.$currentHeight = document.documentElement.clientHeight;
        } else {
            if (document.body && (document.body.clientWidth || document.body.clientHeight)) {
                app.config.globalProperties.$currentWidth = document.body.clientWidth;
                app.config.globalProperties.$currentHeight = document.body.clientHeight;
            }
        }
    }
}
app.config.globalProperties.$setWindowSize();
window.addEventListener('resize', app.config.globalProperties.$setWindowSize);
window.addEventListener('DOMContentLoaded', app.config.globalProperties.$setWindowSize);

app.config.globalProperties.$swal = window.Swal;
app.config.globalProperties.$logo = '';

var lang = localStorage.getItem("language");
lang = JSON.parse(lang);
app.config.globalProperties.$perPage = 10;
app.config.globalProperties.$pageOptions = [10, 20, 30, 50, 100];

window.trans = window.__ = function (string, replacements) {
    var lang = localStorage.getItem("language");
    lang = JSON.parse(lang);
    window.i18n = lang;
    var out = _.get(lang, string) || string;
    if (replacements && typeof replacements === 'object') {
        Object.keys(replacements).forEach(function (k) {
            out = out.replace(new RegExp('\\{' + k + '\\}', 'g'), replacements[k]);
        });
    }
    return out;
};

app.config.globalProperties.trans = window.trans;
app.config.globalProperties.__ = window.__;

// TinyMCE dialogs (image upload, link, etc.) render at <body> level in `.tox-tinymce-aux`.
// Bootstrap modals trap focus and would steal it back, leaving the dialog inputs
document.addEventListener('focusin', function (e) {
    if (e.target && typeof e.target.closest === 'function' &&
        e.target.closest('.tox-tinymce-aux, .tox-dialog, .tox-tinymce') !== null) {
        e.stopImmediatePropagation();
    }
}, true);

document.addEventListener('invalid', function (e) {
    if (e.target.validity && e.target.validity.valueMissing && e.target.hasAttribute('required')) {
        var lang = null;
        try {
            var stored = window.localStorage.getItem('language');
            if (stored) lang = JSON.parse(stored);
        } catch (err) { }
        var msg = (lang && lang.please_fill_out_this_field) ? lang.please_fill_out_this_field : 'Please fill out this field.';
        e.target.setCustomValidity(msg);
    }
}, true);
document.addEventListener('input', function (e) {
    if (e.target.hasAttribute('required')) {
        e.target.setCustomValidity('');
    }
});
document.addEventListener('change', function (e) {
    if (e.target.hasAttribute('required') && e.target.validity.valid) {
        e.target.setCustomValidity('');
    }
});

// PHP date() tokens → dayjs tokens (only the ones our country formats use).
const PHP_TO_DAYJS = {
    d: 'DD', j: 'D', m: 'MM', n: 'M', M: 'MMM', F: 'MMMM',
    Y: 'YYYY', y: 'YY', H: 'HH', G: 'H', h: 'hh', g: 'h',
    i: 'mm', s: 'ss', A: 'A', a: 'a', D: 'ddd', l: 'dddd',
};
function phpFormatToDayjs(format) {
    return String(format || '').replace(/[a-zA-Z]/g, (ch) => PHP_TO_DAYJS[ch] || ch);
}
function countryDateFormat() {
    return phpFormatToDayjs(window.localStorage.getItem('country_date_format') || 'd-m-Y');
}
function countryTimeFormat() {
    return phpFormatToDayjs(window.localStorage.getItem('country_time_format') || 'h:i A');
}
// APIs emit UTC (ISO 8601 or "YYYY-MM-DD HH:mm:ss"); render in the browser's
// local timezone using the header-selected country's date/time formats.
function parseUtc(value) {
    if (!value) return null;
    const d = dayjs.utc(value);
    return d.isValid() ? d.local() : null;
}

app.config.globalProperties.$filters = {
    formatDate(value) {
        // Date-only values (dob etc.) carry no time — format as-is, no tz shift.
        if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
            const d = dayjs(value);
            return d.isValid() ? d.format(countryDateFormat()) : '';
        }
        const d = parseUtc(value);
        return d ? d.format(countryDateFormat()) : '';
    },
    formatTime(value) {
        const d = parseUtc(value);
        return d ? d.format(countryTimeFormat()) : '';
    },
    formatDateTime(value) {
        const d = parseUtc(value);
        return d ? d.format(countryDateFormat() + ' ' + countryTimeFormat()) : '';
    },
    emailMask(value) {
        if (app.config.globalProperties.$isDemo != 1) return value;
        if (!value) return '';

        const at = String(value).lastIndexOf('@');
        if (at < 1) return '*'.repeat(Math.max(3, String(value).length));

        const username = String(value).slice(0, at);
        const domain = String(value).slice(at + 1);
        const lead = username.length > 4 ? 2 : 1;
        const tail = username.length > 6 ? 2 : 0;
        const hidden = Math.max(2, username.length - lead - tail);

        return `${username.slice(0, lead)}${'*'.repeat(hidden)}${tail ? username.slice(-tail) : ''}@${domain}`;
    },
    mobileMask(value) {
        if (app.config.globalProperties.$isDemo != 1) return value;
        if (!value) return '';

        const digits = String(value);
        const lead = digits.length > 5 ? 2 : 1;
        const tail = digits.length > 7 ? 3 : (digits.length > 4 ? 2 : 0);
        const hidden = Math.max(2, digits.length - lead - tail);

        return `${digits.slice(0, lead)}${'*'.repeat(hidden)}${tail ? digits.slice(-tail) : ''}`;
    }
};

app.config.globalProperties.updateLogo = function (logo) {
    app.config.globalProperties.$logo = logo;
    window.localStorage.setItem('logo', logo);
};

app.config.globalProperties.isImage = function (url) {
    return /\.(jpg|jpeg|png|webp|avif|gif|svg)$/.test(url);
};

app.config.globalProperties.$dragoverFile = function (event) {
    event.preventDefault();
    if (!event.currentTarget.classList.contains('bg-green-300')) {
        event.currentTarget.classList.remove('bg-gray-100');
        event.currentTarget.classList.add('bg-green-300');
    }
};
app.config.globalProperties.$dragleaveFile = function (event) {
    event.currentTarget.classList.add('bg-gray-100');
    event.currentTarget.classList.remove('bg-green-300');
};

app.config.globalProperties.formattedName = function (name) {
    var newName = name.replace(/_/g, ' ');
    newName = newName.toLowerCase().replace(/(?<= )[^\s]|^./g, a => a.toUpperCase())
    return newName;
};

app.config.globalProperties.showMessage = function (variant, message) {
    const toast = useToast();
    toast.open({
        type: variant,
        message: message,
    });
};

app.config.globalProperties.showSuccess = function (message) {
    Swal.fire({
        title: __('success'),
        text: message,
        icon: 'success',
        confirmButtonText: __('ok'),
    });
};

app.config.globalProperties.showError = function (error_message) {
    Swal.fire({
        title: __('error'),
        text: error_message,
        icon: 'error',
        confirmButtonText: __('ok'),
    });
};

app.config.globalProperties.showWarning = function (error_message) {
    Swal.fire({
        title: __('warning'),
        text: error_message,
        icon: 'warning',
        confirmButtonText: __('ok'),
    });
};

(function () {
    const logoUrl = window.appLogo
        ? (window.baseUrl + '/storage/' + window.appLogo)
        : '';
    // Web Settings' "Broken Image" goes first: a 404 should look like a missing file,
    // not like the brand logo. Empty when unset, so the chain falls back to what it
    // always used. favicon/broken are already full urls from the blade layout.
    const chain = [window.appBrokenImage, window.appFavicon, logoUrl, window.baseUrl + '/images/logo.png']
        .filter(Boolean)
        .filter(function (url, i, arr) { return arr.indexOf(url) === i; }); // dedupe

    document.addEventListener('error', function (e) {
        const el = e.target;
        if (!el || el.tagName !== 'IMG') return;
        if (el.hasAttribute('onerror')) return;        // element handles its own error
        if (el.hasAttribute('data-no-fallback')) return;

        // Pick the next candidate in the chain we haven't tried yet and that
        // isn't the src that just failed.
        let step = parseInt(el.dataset.imgFbStep || '0', 10);
        while (step < chain.length && chain[step] === el.src) step++;
        if (step >= chain.length) return;              // chain exhausted — give up
        el.dataset.imgFbStep = String(step + 1);
        el.src = chain[step];
    }, true);
})();

app.mount('#app');
