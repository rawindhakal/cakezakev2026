<template>
    <div class="vh-root">
    <header class="app-header">
        <nav class="navbar navbar-expand">
            <div class="container-fluid d-flex align-items-center flex-nowrap gap-2">
                <!-- Left: sidebar toggle + small-screen demo badge -->
                <div class="d-flex align-items-center gap-2 flex-shrink-0">
                    <a href="javascript:void(0)" class="burger-btn hdr-icon-btn"
                        :title="__('menu') || 'Toggle sidebar'" aria-label="Toggle sidebar">
                        <PanelLeft />
                    </a>
                    <span v-if="$isDemo == 1" class="hdr-demo-badge" :title="__('demo_mode')">
                        <span class="hdr-demo-dot"></span>{{ __('demo') }}
                    </span>
                </div>

                <!-- Right side — always visible, auto-wraps on small screens. -->
                <div class="navbar-collapse ms-auto" id="navbarSupportedContent">
                    <div class="d-flex flex-row align-items-center justify-content-end flex-wrap w-100 gap-2">
                        <ul class="navbar-nav list-unstyled d-flex flex-row flex-wrap align-items-center gap-1 mb-0">

                            <!-- Theme toggle -->
                            <li class="nav-item">
                                <button type="button" class="hdr-icon-btn" @click="toggleTheme"
                                    :title="userTheme === 'theme-dark' ? 'Switch to light' : 'Switch to dark'">
                                    <Sun v-if="userTheme === 'theme-dark'" />
                                    <Moon v-else />
                                </button>
                            </li>

                            <!-- Website link -->
                            <li v-if="$websiteUrl" class="nav-item">
                                <a class="hdr-icon-btn" :href="$websiteUrl" target="_blank"
                                    :title="__('website') || 'Website'">
                                    <Globe />
                                </a>
                            </li>

                            <!-- Notifications -->
                            <li class="nav-item dropdown">
                                <a class="hdr-icon-btn dropdown-toggle position-relative" href="#"
                                    data-bs-toggle="dropdown" aria-expanded="false" :title="__('notifications')">
                                    <Bell />
                                    <span v-if="notifications_unread_count > 0" class="hdr-dot">
                                        {{ notifications_unread_count > 9 ? '9+' : notifications_unread_count }}
                                    </span>
                                </a>
                                <ul class="dropdown-menu dropdown-menu-end notification-dropdown p-0">
                                    <!-- Header: title + unread count, and mark-all as a quiet icon action -->
                                    <li class="notif-head">
                                        <div class="d-flex align-items-center gap-2">
                                            <span class="notif-head-title">{{ __('notifications') }}</span>
                                            <span v-if="notifications_unread_count > 0" class="notif-count">
                                                {{ notifications_unread_count }}
                                            </span>
                                        </div>
                                    </li>

                                    <li class="notif-scroll">
                                        <button v-for="notification of notifications.slice(0, 5)" :key="notification.id"
                                            type="button" class="notif-item"
                                            :class="{ 'is-unread': !notification.read_at }"
                                            @click="openNotification(notification)">
                                            <span class="notif-icon">
                                                <component :is="notification.read_at ? 'Bell' : 'BellDot'" :size="15" />
                                            </span>
                                            <span class="notif-body">
                                                <span class="notif-text">{{ notification.data.text }}</span>
                                                <span class="notif-time">{{ changeDateTime(notification.created_at) }}</span>
                                            </span>
                                            <span v-if="!notification.read_at" class="notif-unread-dot"></span>
                                        </button>

                                        <div v-if="notifications.length === 0" class="notif-empty">
                                            <BellOff :size="26" />
                                            <span>{{ __('no_new_notification') }}</span>
                                        </div>
                                    </li>

                                    <li v-if="notifications.length > 0" class="notif-foot">
                                        <button type="button" class="notif-see-all" @click="goToNotificationPanel">
                                            {{ __('see_all_notifications') }}
                                        </button>
                                        <button v-if="notifications_unread_count > 0" type="button"
                                            class="notif-mark-all" @click.stop="confirmMarkAllAsRead">
                                            {{ __('read_all_notifications') }}
                                        </button>
                                    </li>
                                </ul>
                            </li>

                            <!-- Language selector -->
                            <li class="nav-item dropdown">
                                <a class="hdr-icon-btn dropdown-toggle" href="#" data-bs-toggle="dropdown"
                                    aria-expanded="false" :title="__('select_language') || 'Select Language'">
                                    <Languages />
                                </a>
                                <ul class="dropdown-menu dropdown-menu-end language-dropdown">
                                    <li>
                                        <h6 class="dropdown-header">{{ __('select_language') }}</h6>
                                    </li>
                                    <li v-if="languages.length === 0">
                                        <a class="dropdown-item active" href="#"
                                            @click.prevent="changeLanguage('en')">English</a>
                                    </li>
                                    <li v-for="language in languages" :key="language.code">
                                        <a class="dropdown-item d-flex align-items-center justify-content-between"
                                            :class="{ active: lang === language.code }" href="#"
                                            @click.prevent="changeLanguage(language.code)">
                                            <span>{{ language.name }}</span>
                                            <Check v-if="lang === language.code" :size="15" />
                                        </a>
                                    </li>
                                </ul>
                            </li>

                            <li class="nav-item d-none d-lg-flex align-items-center px-1">
                                <span class="hdr-divider"></span>
                            </li>
                        </ul>

                        <!-- User menu -->
                        <div class="dropdown">
                            <a href="#" class="user-chip text-decoration-none" data-bs-toggle="dropdown"
                                aria-expanded="false">
                                <img :src="profile_url" alt="profile">
                                <span class="d-none d-lg-flex flex-column text-start">
                                    <span class="user-chip-name">{{ user.username }}</span>
                                    <span class="user-chip-role">{{ roleLabel }}</span>
                                </span>
                                <ChevronDown class="hdr-caret d-none d-lg-block" />
                            </a>
                            <ul class="dropdown-menu dropdown-menu-end user-dropdown-menu">
                                <li>
                                    <h6 class="dropdown-header">{{ __('hello') }}, {{ user.username }}!</h6>
                                </li>
                                <li v-if="role == $roleDeliveryBoy">
                                    <router-link class="dropdown-item d-flex align-items-center gap-2"
                                        to="/delivery_boy/profile">
                                        <User />{{ __('my_profile') }}
                                    </router-link>
                                </li>
                                <li v-if="role != $roleDeliveryBoy && !($isBranchUser && $isBranchUser())">
                                    <router-link class="dropdown-item d-flex align-items-center gap-2" to="/account_settings">
                                        <Settings />{{ __('account_settings') }}
                                    </router-link>
                                </li>
                                <li v-if="role == $roleDeliveryBoy">
                                    <router-link class="dropdown-item d-flex align-items-center gap-2"
                                        to="/delivery_boy/account_settings">
                                        <Settings />{{ __('settings') }}
                                    </router-link>
                                </li>
                                <li v-if="$isBranchUser && $isBranchUser() && $isBranchOwner()">
                                    <router-link class="dropdown-item d-flex align-items-center gap-2"
                                        to="/branch/profile">
                                        <User />{{ __('my_profile') }}
                                    </router-link>
                                </li>
                                <li v-if="$isBranchUser && $isBranchUser()">
                                    <router-link class="dropdown-item d-flex align-items-center gap-2"
                                        to="/branch/account_settings">
                                        <Settings />{{ __('settings') }}
                                    </router-link>
                                </li>

                                <li v-if="canInstallApp">
                                    <a class="dropdown-item d-flex align-items-center gap-2"
                                        href="javascript:void(0)" @click="installApp()">
                                        <Download />{{ __('install_app') }}
                                    </a>
                                </li>

                                <li>
                                    <hr class="dropdown-divider">
                                </li>
                                <li>
                                    <a class="dropdown-item d-flex align-items-center gap-2 text-danger"
                                        href="javascript:void(0)" @click="logout()">
                                        <LogOut />{{ __('logout') }}
                                    </a>
                                </li>
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
        </nav>
    </header>

    <!-- Notifications open their record in place rather than navigating away. -->
    <OrderDetailSlider v-model="orderSliderShow" :order-id="activeOrderId" @updated="getNotifications" />
    <ReturnDetailSlider v-model="returnSliderShow" :record="activeReturn" @updated="getNotifications" />
    </div>
</template>

<script>
import Auth from '../Auth.js';
import axios from 'axios';
import dayjs from '../utils/dayjs';
import OrderDetailSlider from '../views/Orders/OrderDetailSlider.vue';
import ReturnDetailSlider from '../views/ReturnRequests/ReturnDetailSlider.vue';
import {
    PanelLeft, MoreHorizontal, X, ChevronDown, Sun, Moon, Globe,
    Bell, BellOff, BellDot, Languages, Check, CheckCheck, User, Settings, LogOut,
    Map, MapPin, Download,
} from 'lucide-vue-next';
import { canInstall, promptInstall } from '../pwa.js';

export default {
    name: 'VerticalHeader',
    components: {
        OrderDetailSlider,
        ReturnDetailSlider,
        PanelLeft, MoreHorizontal, X, ChevronDown, Sun, Moon, Globe,
        Bell, BellOff, BellDot, Languages, Check, CheckCheck, User, Settings, LogOut,
        Map, MapPin, Download,
    },
    data() {
        return {
            lang: window.localStorage.getItem('lang') || window.appLocale || 'en',
            user: Auth.user,
            role: Role,
            profile_url: this.$baseUrl + '/images/admin_logo.png',
            canInstallApp: canInstall(),
            notifications: [],
            notifications_unread_count: 0,

            orderSliderShow: false,
            activeOrderId: null,
            returnSliderShow: false,
            activeReturn: null,
            userTheme: 'theme-light',
            isToggle: false,
            remark: '',
            windowHeight: window.innerHeight,
            windowWidth: window.innerWidth,
            languages: [],
            timer: null,
        };
    },
    computed: {
        roleLabel() {
            if (this.$isBranchUser && this.$isBranchUser()) {
                if (this.$isBranchOwner && this.$isBranchOwner()) {
                    const display = String(this.role || '').replace(/^branch\d+:/, '');
                    return display === '__owner__' ? __('owner') : display;
                }
                return window.BranchName || __('branch');
            }
            return this.role || '';
        },
        // Delivery-boy endpoints are root-mounted under /delivery_boy (not /api), so
        // token-scoped calls (logout, update_fcm_token) must hit that prefix for a boy.
        authApiBase() {
            return this.role === this.$roleDeliveryBoy ? this.$deliveryBoyApiUrl : this.$apiUrl;
        },
    },
    created() {
        this.getNotifications();
    },
    mounted() {
        // beforeinstallprompt can fire before or after this component mounts.
        this._onInstallable = () => { this.canInstallApp = true; };
        this._onInstalled = () => { this.canInstallApp = false; };
        window.addEventListener('pwa:installable', this._onInstallable);
        window.addEventListener('pwa:installed', this._onInstalled);

        if (window.localStorage.getItem('lang_reload_pending') === 'true') {
            window.localStorage.removeItem('lang_reload_pending');
            setTimeout(() => {
                const url = window.location.href.split('?')[0].split('#')[0];
                window.location.href = url + '?_t=' + Date.now();
            }, 100);
            return;
        }

        this.$nextTick(() => {
            window.addEventListener('resize', this.onResize);
            window.addEventListener('DOMContentLoaded', this.onResize);
        });

        this.setTheme(this.getTheme());
        this.timer = setInterval(this.getNotifications, 40000);
        this.getLanguage();
    },
    beforeUnmount() {
        window.removeEventListener('resize', this.onResize);
        window.removeEventListener('DOMContentLoaded', this.onResize);
        if (this.timer) clearInterval(this.timer);
        window.removeEventListener('pwa:installable', this._onInstallable);
        window.removeEventListener('pwa:installed', this._onInstalled);
    },
    methods: {
        async installApp() {
            await promptInstall();
            this.canInstallApp = canInstall();
        },
        logout() {
            const role_id = Auth.user.role_id;
            const finish = () => {
                Auth.logout();
                setTimeout(() => {
                    if (role_id === 3) this.$router.push('/delivery_boy/login');
                    else this.$router.push('/login');
                    window.location.reload();
                }, 500);
            };
            const fcm = window.panelFcmToken || '';
            axios.post(this.authApiBase + '/logout', { fcm_token: fcm })
                .catch(() => { })
                .then(finish);
        },
        changeLanguage(code) {
            if (!code || code === this.lang) return;
            this.lang = code;
            window.localStorage.setItem('lang', this.lang);
            axios.post(this.$apiUrl + '/change_language', { language: this.lang })
                .then(() => {
                    // Keep this device's FCM token language in sync with the panel language.
                    const langId = (this.languages.find(l => l.code === code) || {}).id;
                    if (window.panelFcmToken && langId) {
                        const fd = new FormData();
                        fd.append('fcm_token', window.panelFcmToken);
                        fd.append('language_id', langId);
                        fd.append('platform', 'web');
                        axios.post(this.authApiBase + '/update_fcm_token', fd).catch(() => { });
                    }
                    this.applyRtlForLanguage(this.lang);
                    this.updateDefaultLanguage(this.lang);
                    window.localStorage.removeItem('language');
                    window.localStorage.setItem('lang_reload_pending', 'true');
                    const url = window.location.href.split('?')[0].split('#')[0];
                    window.location.href = url + '?_t=' + Date.now();
                });
        },
        updateDefaultLanguage(newDefaultLanguage) {
            this.languages.forEach(language => {
                language.is_default = language.code === newDefaultLanguage ? 1 : 0;
            });
        },
        getLanguage() {
            axios.get(this.$apiUrl + '/system_languages', { params: { system_type: 4 } })
                .then(response => {
                    this.languages = Array.isArray(response.data?.data) ? response.data.data : [];
                    this.applyRtlForLanguage(window.localStorage.getItem('lang') || this.lang);
                })
                .catch(error => console.error('Error fetching languages:', error));
        },
        applyRtlForLanguage(langCode) {
            const lang = this.languages.find(l => (l.code || '').toLowerCase() === (langCode || '').toLowerCase());
            const isRtl = lang && String(lang.type || '').toLowerCase() === 'rtl';
            document.body.classList.toggle('rtl', !!isRtl);
        },
        getNotifications() {
            axios.get(this.$apiUrl + '/get_top_notifications')
                .then(response => {
                    this.notifications = response.data.data.notifications;
                    this.notifications_unread_count = response.data.data.unread;
                });
        },
        markAsReadNotification(notification) {
            if (notification.read_at == null) {
                axios.get(this.$apiUrl + '/notification_read?id=' + notification.id)
                    .then(() => this.getNotifications());
            }
        },
        confirmMarkAllAsRead() {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: 'Do you want to mark all notifications as read?',
                icon: 'question',
                showCancelButton: true,
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {
                if (result.value) this.markAllAsRead();
            });
        },
        markAllAsRead() {
            axios.get(this.$apiUrl + '/notification_read')
                .then(response => {
                    this.getNotifications();
                    this.showMessage('success', response.data.message || 'All notifications marked as read');
                })
                .catch(() => this.showError('Failed to mark all notifications as read'));
        },
        goToNotificationPanel() {
            if (this.role === this.$roleDeliveryBoy) {
                this.$router.push('/delivery_boy/notification_panel');
            } else {
                this.$router.push('/notification_panel');
            }
        },
        changeDateTime(dateTime) {
            return dayjs(dateTime).fromNow();
        },
        setTheme(theme) {
            sessionStorage.setItem('user-theme', theme);
            this.userTheme = theme;
            document.body.classList.remove('theme-light', 'theme-dark');
            document.body.classList.add(theme);
            // Let theme-aware widgets (e.g. Apex charts) re-render on live toggle.
            window.dispatchEvent(new CustomEvent('theme:changed', { detail: theme }));
        },
        getMediaPreference() {
            return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'theme-dark' : 'theme-light';
        },
        getTheme() {
            const stored = sessionStorage.getItem('user-theme');
            this.userTheme = stored || 'theme-light';
            return this.userTheme;
        },
        toggleTheme(event) {
            const active = sessionStorage.getItem('user-theme');
            const next = (active === 'theme-light' || !active || active === 'undefined' || active === 'null')
                ? 'theme-dark' : 'theme-light';

            const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
            if (!document.startViewTransition || reduced) {
                this.setTheme(next);
                return;
            }

            const rect = event && event.currentTarget && event.currentTarget.getBoundingClientRect
                ? event.currentTarget.getBoundingClientRect()
                : null;
            const x = rect ? rect.left + rect.width / 2 : window.innerWidth;
            const y = rect ? rect.top + rect.height / 2 : 0;
            // Radius that still covers the furthest corner from the origin.
            const endRadius = Math.hypot(
                Math.max(x, window.innerWidth - x),
                Math.max(y, window.innerHeight - y),
            );

            const transition = document.startViewTransition(() => this.setTheme(next));
            transition.ready.then(() => {
                document.documentElement.animate(
                    { clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${endRadius}px at ${x}px ${y}px)`] },
                    { duration: 480, easing: 'ease-in-out', pseudoElement: '::view-transition-new(root)' },
                );
            }).catch(() => { /* transition skipped — theme is already applied */ });
        },
        onResize() {
            this.windowHeight = window.innerHeight;
            this.windowWidth = window.innerWidth;
        },
        /** Return-flow notifications carry the return request they belong to. */
        isReturn(notification) {
            return !!(notification.data && notification.data.return_request_id);
        },

        openNotification(notification) {
            this.markAsReadNotification(notification);

            if (this.isReturn(notification)) {
                this.openReturn(notification.data.return_request_id);
                return;
            }

            this.activeOrderId = notification.data.order_id;
            this.orderSliderShow = true;
        },

        // The slider wants the whole record and there is no fetch-one endpoint —
        // pull the list and pick the row out of it.
        openReturn(returnId) {
            axios.get(this.$apiUrl + '/return_requests')
                .then(res => {
                    const record = (res.data?.data || []).find(r => Number(r.id) === Number(returnId));
                    if (!record) {
                        this.showError(__('return_request_not_found'));
                        return;
                    }
                    this.activeReturn = record;
                    this.returnSliderShow = true;
                })
                .catch(() => this.showError(__('something_went_wrong')));
        },
    },
};
</script>

<style scoped>
/* Shell geometry (header height, .hdr-icon-btn, .user-chip, .hdr-divider,
   dropdown styling) lives in assets/css/custom/common.css so light and dark
   share one source of truth. Only header-local bits stay here. */

/* Compact country/zone pickers that read as one control with the icon buttons. */
.hdr-select {
    min-width: 132px;
    max-width: 170px;
    height: 34px;
    padding: 0 0.6rem;
    font-size: 0.8125rem !important;
    color: var(--app-ink);
    background-color: transparent;
    border: 1px solid var(--app-border);
    border-radius: 8px;
}
.hdr-select:hover,
.hdr-select:focus {
    border-color: var(--bs-primary);
    box-shadow: none;
}
.hdr-select::after {
    display: none;
}

/* Country flag. A bare height attribute is only a default that any stray CSS
   can override, so pin the box here and let the image letterbox inside it. */
.hdr-flag {
    width: 20px;
    height: 14px;
    object-fit: contain;
    flex-shrink: 0;
    margin-bottom: 0;
    border-radius: 2px;
}

/* Leading icon on the zone control and its menu rows. */
.hdr-select-icon {
    width: 15px;
    height: 15px;
    stroke-width: 1.8px;
    color: var(--app-muted);
    flex-shrink: 0;
}
.hdr-select:hover .hdr-select-icon,
.dropdown-item.active .hdr-select-icon {
    color: inherit;
}

.hdr-caret {
    width: 15px;
    height: 15px;
    stroke-width: 2px;
    color: var(--app-muted);
    flex-shrink: 0;
}

/* Unread count sitting on the bell. */
.hdr-dot {
    position: absolute;
    top: -2px;
    right: 0;
    min-width: 16px;
    height: 16px;
    padding: 0 4px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 999px;
    background-color: #ef4444;
    color: #fff;
    font-size: 0.625rem;
    font-weight: 600;
    line-height: 1;
}

/* Notification dropdown: fixed header + scrolling list + sticky footer. */
.notification-dropdown {
    width: 340px;
    min-width: 340px;
    max-width: 340px;
    overflow: hidden;
}
.notif-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
    padding: 0.7rem 0.85rem;
    border-bottom: 1px solid var(--app-border);
}
.notif-head-title {
    font-size: 0.85rem;
    font-weight: 700;
    color: var(--app-ink);
}
.notif-count {
    min-width: 20px;
    padding: 0 6px;
    height: 18px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 999px;
    background-color: rgba(var(--bs-primary-rgb), 0.12);
    color: var(--bs-primary);
    font-size: 0.68rem;
    font-weight: 700;
}
.notif-mark-all {
    padding: 0.25rem 0.4rem;
    border: none;
    border-radius: 6px;
    background: transparent;
    color: var(--app-muted);
    font-size: 0.78rem;
    font-weight: 500;
    white-space: nowrap;
    cursor: pointer;
}
.notif-mark-all:hover {
    background-color: var(--app-hover);
    color: var(--app-ink);
}

.notif-scroll {
    max-height: 320px;
    overflow-y: auto;
}
.notif-item {
    position: relative;
    display: flex;
    align-items: flex-start;
    gap: 0.6rem;
    width: 100%;
    padding: 0.7rem 1.4rem 0.7rem 0.85rem;
    border: none;
    border-bottom: 1px solid var(--app-border);
    background: transparent;
    text-align: start;
    cursor: pointer;
    transition: background-color 0.12s ease;
}
.notif-item:last-child { border-bottom: none; }
.notif-item:hover { background-color: var(--app-hover); }
/* Unread rows get a light tint; the bell (and its dot) carries the state. */
.notif-item.is-unread { background-color: rgba(var(--bs-primary-rgb), 0.05); }
/* Read rows: plain, muted bell so they recede. */
.notif-item:not(.is-unread) .notif-icon {
    background-color: var(--app-hover);
    color: var(--app-muted);
}
.notif-icon {
    flex-shrink: 0;
    width: 30px;
    height: 30px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 8px;
    background-color: rgba(var(--bs-primary-rgb), 0.1);
    color: var(--bs-primary);
}
.notif-body { min-width: 0; flex: 1; }
.notif-text {
    display: block;
    font-size: 0.8rem;
    line-height: 1.35;
    color: var(--app-ink);
    white-space: normal;
    word-break: break-word;
    overflow-wrap: anywhere;
}
.notif-item.is-unread .notif-text { font-weight: 600; }
.notif-time {
    display: block;
    margin-top: 2px;
    font-size: 0.7rem;
    color: var(--app-muted);
}
.notif-unread-dot {
    position: absolute;
    top: 0.85rem;
    inset-inline-end: 0.7rem;
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background-color: var(--bs-primary);
}

.notif-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.45rem;
    padding: 2rem 1rem;
    color: var(--app-muted);
    font-size: 0.8rem;
}
.notif-empty svg { opacity: 0.45; }

.notif-foot {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
    padding: 0.45rem 0.6rem;
    border-top: 1px solid var(--app-border);
}
.notif-see-all {
    padding: 0.25rem 0.4rem;
    border: none;
    border-radius: 6px;
    background: transparent;
    color: var(--bs-primary);
    font-size: 0.78rem;
    font-weight: 600;
    white-space: nowrap;
    cursor: pointer;
}
.notif-see-all:hover { background-color: var(--app-hover); }

.language-dropdown {
    min-width: 180px;
    max-height: 320px;
    overflow-y: auto;
}
.language-dropdown .dropdown-item {
    transition: background-color 0.15s ease;
    cursor: pointer;
}
.language-dropdown .dropdown-item:hover,
.language-dropdown .dropdown-item:focus {
    background-color: var(--app-hover);
    color: inherit;
}

.user-dropdown-menu {
    min-width: 210px;
    max-width: 250px;
}

/* Phone: 340px does not fit next to the bell, so Popper pushes the panel off the
   left edge and it gets clipped. Pin it to the viewport under the header instead. */
@media (max-width: 575.98px) {
    .notification-dropdown.dropdown-menu {
        position: fixed !important;
        inset: calc(var(--app-header-h, 64px) + 0.25rem) 0.6rem auto 0.6rem !important;
        transform: none !important;
        width: auto;
        min-width: 0;
        max-width: none;
    }
    .user-dropdown-menu.dropdown-menu {
        max-width: calc(100vw - 1.2rem);
    }
}
</style>
