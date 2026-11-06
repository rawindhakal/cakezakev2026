<template>
    <div id="app">
        <div id="sidebar" class="active">
            <div class="sidebar-wrapper active">
                <div class="sidebar-header">
                    <div class="d-flex justify-content-center align-items-center" style="position: relative;">
                        <div class="logo">
                            <router-link to="/" style="display: flex; align-items: center; justify-content: center;">
                                <img class="container-logo" v-if="$appLogo != ''" :src="$storageUrl + $appLogo"
                                    alt='Logo' srcset="" />
                                <img class="container-logo" v-else :src="$baseUrl + '/images/logo.png'" alt='Logo'
                                    srcset="" />
                            </router-link>
                        </div>
                    </div>
                </div>
                <div class="sidebar-menu">
                    <ul class="menu">

                        <template v-for="item in sidebarItems">

                            <li class="sidebar-item"
                                :class="{ 'active': isActive(item.url) || subIsActive(item), 'has-sub': isHasSub(item) }"
                                v-if="item.permission">

                                <template v-if="isHasSub(item)">
                                    <a class="sidebar-link">
                                        <component :is="item.icon" />
                                        <span>{{ item.name }}</span>
                                    </a>
                                    <ul class="submenu" :class="{ 'active': subIsActive(item) }">
                                        <template v-for="sub in item.submenu" :key="sub.key">
                                            <li class="submenu-item" :class="{ 'active': isActive(sub.url) }">
                                                <router-link :to="sub.url">
                                                    {{ sub.name }}
                                                </router-link>
                                            </li>
                                        </template>
                                    </ul>
                                </template>
                                <template v-else>
                                    <router-link class="sidebar-link" :to="item.url">
                                        <component :is="item.icon" />
                                        <span>{{ item.name }}</span>
                                        <span v-if="item.url === '/delivery_boy/chat' && unreadChat > 0"
                                            class="badge bg-danger rounded-pill ms-2">{{ unreadChat }}</span>
                                    </router-link>
                                </template>
                            </li>
                        </template>

                    </ul>
                </div>
            </div>
        </div>

        <div id="main">
            <vertical-header></vertical-header>
            <div class="main-content">
                <router-view></router-view>
            </div>
        </div>

        <!-- Full-page maintenance screen: blocks the entire delivery-boy panel. -->
        <div v-if="maintenanceModal" class="db-maintenance-screen">
            <div class="db-maintenance-inner">
                <component :is="icons.wrench" :size="88" class="db-maintenance-icon" />
                <h2 class="mt-3 mb-2 fw-bold">{{ __('under_maintenance') }}</h2>
                <p class="db-maintenance-msg">{{ maintenanceRemark || __('app_under_maintenance_message') }}</p>
                <button class="btn btn-outline-light mt-3" @click="checkMaintenance">
                    <component :is="icons.refresh" :size="16" /> {{ __('refresh') }}
                </button>
            </div>
        </div>

        <!-- Blocked Status Modal -->
        <b-modal v-model="deliveryBoyBlockedModal" id="delivery-boy-blocked-modal" title="Account Blocked" :no-close-on-backdrop="true"
            :no-close-on-esc="true" :hide-header-close="true" centered @ok="handleBlockedLogout">
            <div class="text-center">
                <component :is="icons.ban" :size="48" class="text-danger" />
                <h5 class="mt-3">You are blocked by admin</h5>
                <h6>Reason: {{ remark }}</h6>
                <p class="text-muted">Your account has been blocked by admin. Please contact admin to unblock your
                    account.</p>
            </div>
            <template #footer="{ ok }">
                <b-button variant="primary" @click="ok()">
                    OK
                </b-button>
            </template>
        </b-modal>
    </div>
</template>

<script>
import { markRaw } from 'vue'
import TheSidebar from './TheSidebar.vue'

import TheFooter from './TheFooter.vue'
import VerticalHeader from './VerticalHeader.vue'
import Auth from '../Auth.js';
import axios from "axios";
import { initEcho, getEcho } from '../echo.js';
import RiderLocationTracker from '../mixins/RiderLocationTracker.js';
import {
    LayoutDashboard, ShoppingCart, MessagesSquare, RotateCcw, CreditCard,
    ArrowLeftRight, Banknote, Wallet, Ban, Wrench, RefreshCw,
} from 'lucide-vue-next';

const SIDEBAR_OVERLAY_BREAKPOINT = 1200;

export default {
    name: 'TheContainerDeliveryBoy',
    mixins: [RiderLocationTracker],
    components: {
        TheSidebar,

        TheFooter,
        VerticalHeader
    },
    created() {
        this.checkPermissions();
        this.checkDeliveryBoyStatus();
        this.fetchUnreadChat();
        this.checkMaintenance();
        this.subscribeMaintenance();
        this._onUnread = () => this.fetchUnreadChat();
        window.addEventListener('chat:refresh-unread', this._onUnread);
    },
    watch: {
        '$route'() {
            this.checkPermissions();
            this.fetchUnreadChat();
            this.closeSideBarMenu();
        }
    },
    mounted() {
        //lang
        if (window.localStorage.getItem('lang')) {
            this.lang = window.localStorage.getItem('lang');
        }

        // Start periodic status check every 30 seconds
        this.statusCheckInterval = setInterval(() => {
            this.checkDeliveryBoyStatus();
        }, 30000);

        function slideToggle(t, e, o) { 0 === t.clientHeight ? j(t, e, o, !0) : j(t, e, o) } function slideUp(t, e, o) { j(t, e, o) } function slideDown(t, e, o) { j(t, e, o, !0) } function j(t, e, o, i) { void 0 === e && (e = 400), void 0 === i && (i = !1), t.style.overflow = "hidden", i && (t.style.display = "block"); var p, l = window.getComputedStyle(t), n = parseFloat(l.getPropertyValue("height")), a = parseFloat(l.getPropertyValue("padding-top")), s = parseFloat(l.getPropertyValue("padding-bottom")), r = parseFloat(l.getPropertyValue("margin-top")), d = parseFloat(l.getPropertyValue("margin-bottom")), g = n / e, y = a / e, m = s / e, u = r / e, h = d / e; window.requestAnimationFrame(function l(x) { void 0 === p && (p = x); var f = x - p; i ? (t.style.height = g * f + "px", t.style.paddingTop = y * f + "px", t.style.paddingBottom = m * f + "px", t.style.marginTop = u * f + "px", t.style.marginBottom = h * f + "px") : (t.style.height = n - g * f + "px", t.style.paddingTop = a - y * f + "px", t.style.paddingBottom = s - m * f + "px", t.style.marginTop = r - u * f + "px", t.style.marginBottom = d - h * f + "px"), f >= e ? (t.style.height = "", t.style.paddingTop = "", t.style.paddingBottom = "", t.style.marginTop = "", t.style.marginBottom = "", t.style.overflow = "", i || (t.style.display = "none"), "function" == typeof o && o()) : window.requestAnimationFrame(l) }) }
        let sidebarItems = document.querySelectorAll('.sidebar-item.has-sub');
        for (var i = 0; i < sidebarItems.length; i++) {
            let sidebarItem = sidebarItems[i];
            sidebarItems[i].querySelector('.sidebar-link').addEventListener('click', function (e) {
                e.preventDefault();

                let submenu = sidebarItem.querySelector('.submenu');
                if (submenu?.classList?.contains('active')) submenu.style.display = "block"
                if (submenu.style.display == "none") submenu?.classList?.add('active')
                else submenu?.classList?.remove('active')
                slideToggle(submenu, 300)
            })
        }

        if (window.innerWidth < SIDEBAR_OVERLAY_BREAKPOINT) {
            document.getElementById('sidebar')?.classList?.remove('active');
        }
        // Backdrop + body scroll lock while the sidebar overlays the content
        // (< 1024px). Click outside to close.
        const updateSidebarBackdrop = () => {
            const sidebar = document.getElementById('sidebar');
            const backdrop = document.querySelector('.sidebar-backdrop');
            const isSmallScreen = window.innerWidth < SIDEBAR_OVERLAY_BREAKPOINT;
            const isActive = sidebar?.classList?.contains('active');
            const isOverlaying = isSmallScreen && isActive;
            if (backdrop) backdrop.remove();
            if (isOverlaying) {
                const b = document.createElement('div');
                b.className = 'sidebar-backdrop';
                b.addEventListener('click', () => {
                    sidebar?.classList?.remove('active');
                    updateSidebarBackdrop();
                });
                document.body.appendChild(b);
            }
            document.body.classList.toggle('sidebar-open', isOverlaying);
        };

        let wasSmallScreen = window.innerWidth < SIDEBAR_OVERLAY_BREAKPOINT;
        window.addEventListener('resize', (event) => {
            const isSmall = window.innerWidth < SIDEBAR_OVERLAY_BREAKPOINT;
            if (isSmall === wasSmallScreen) return;
            wasSmallScreen = isSmall;

            const sidebar = document.getElementById('sidebar');
            if (isSmall) {
                sidebar?.classList?.remove('active');
            } else {
                sidebar?.classList?.add('active');
            }
            updateSidebarBackdrop();
        });
        // The header burger is the only sidebar toggle — the in-sidebar close (X)
        // buttons are gone; on small screens the backdrop also closes it.
        document.querySelector('.burger-btn')?.addEventListener('click', () => {
            document.getElementById('sidebar')?.classList?.toggle('active');
            updateSidebarBackdrop();
        });
        // Perfect Scrollbar Init
        if (typeof PerfectScrollbar.default == 'function') {
            const container = document.querySelector(".sidebar-wrapper");
            const ps = new PerfectScrollbar.default(container, {
                wheelPropagation: false
            });
        }
        document.querySelector('.sidebar-item.active')?.scrollIntoView(false)


    },
    beforeUnmount() {
        // Clear the status check interval when component is destroyed
        if (this.statusCheckInterval) {
            clearInterval(this.statusCheckInterval);
        }
        if (this._onUnread) window.removeEventListener('chat:refresh-unread', this._onUnread);
        const echo = getEcho();
        if (echo && this.deliveryBoyId) { try { echo.leave('chat.delivery_boy.' + this.deliveryBoyId); } catch (e) {} }
        if (echo) { try { echo.leave('maintenance'); } catch (e) {} }
        // Don't leave the scroll lock behind on logout / layout swap.
        document.body.classList.remove('sidebar-open');
        document.querySelector('.sidebar-backdrop')?.remove();
    },
    data: function () {
        return {
            icons: { ban: markRaw(Ban), wrench: markRaw(Wrench), refresh: markRaw(RefreshCw) },
            lang: 'en',
            statusCheckInterval: null,
            unreadChat: 0,
            deliveryBoyId: null,
            remark: '',
            deliveryBoyBlockedModal: false,
            maintenanceModal: false,
            maintenanceRemark: '',
            sidebarItems: [
                {
                    name: __('dashboard'),
                    icon: markRaw(LayoutDashboard),
                    url: '/delivery_boy',
                    permission: 'manage_dashboard'
                },
                {
                    name: __('orders'),
                    icon: markRaw(ShoppingCart),
                    url: '/delivery_boy/orders',
                    permission: 'order_list'
                },
                {
                    name: __('chat'),
                    icon: markRaw(MessagesSquare),
                    url: '/delivery_boy/chat',
                    permission: 'order_list'
                },
                {
                    name: __('return_requests'),
                    icon: markRaw(RotateCcw),
                    url: '/delivery_boy/return_requests',
                    permission: 'return_request_list',
                },
                {
                    name: __('withdrawal_requests'),
                    icon: markRaw(CreditCard),
                    url: '/delivery_boy/withdrawal_requests',
                    // Was gated on a report permission (product_sales_reports) that no longer
                    // exists; delivery boys are not permission-checked, so use their base one.
                    permission: 'order_list',
                },
                {
                    name: __('settlement_history'),
                    icon: markRaw(ArrowLeftRight),
                    url: '/delivery_boy/settlement_history',
                    permission: 'order_list'
                },
                {
                    name: __('cash_collection'),
                    icon: markRaw(Banknote),
                    url: '/delivery_boy/cash_collection',
                    permission: 'order_list'
                },
                {
                    name: __('salary_transactions'),
                    icon: markRaw(Wallet),
                    url: '/delivery_boy/salary_transactions',
                    permission: 'order_list'
                },
            ]
        }
    },
    methods: {
        // On small screens the sidebar overlays the page and locks body scroll,
        // so it has to close once navigation happens.
        closeSideBarMenu() {
            if (window.innerWidth < SIDEBAR_OVERLAY_BREAKPOINT) {
                document.getElementById('sidebar')?.classList?.remove('active');
                document.querySelector('.sidebar-backdrop')?.remove();
                document.body.classList.remove('sidebar-open');
            }
        },
        subIsActive(item) {
            const paths = Array.isArray(item.submenu) ? item.submenu : [];
            return paths.some(path => {
                return this.$route.path.indexOf(path.url) === 0;
            });
        },
        isActive(url) {
            if (this.$route.path == url) {
                return true;
            }
            return false;
        },
        isHasSub(item) {
            if (item.hasOwnProperty("submenu")) {
                if (item.submenu.length > 0) {
                    return true;
                }
            }
            return false;
        },
        changeLanguage(event) {
            this.lang = event.target.value;
            window.localStorage.setItem('lang', this.lang);
            this.isLoading = true
            let data = {
                language: this.lang
            }
            axios.post(this.$apiUrl + '/change_language', data)
                .then((response) => {
                    this.isLoading = false;
                    window.location.reload();
                });
        },
        checkPermissions() {
            // Delivery boys have token-only auth; skip permission checks
        },
        fetchUnreadChat() {
            axios.get(this.$deliveryBoyApiUrl + '/chat/unread_count')
                .then((res) => {
                    const d = (res.data && res.data.data) || {};
                    this.unreadChat = d.count || 0;
                    if (d.delivery_boy_id && !this.deliveryBoyId) {
                        this.deliveryBoyId = d.delivery_boy_id;
                        this.subscribeChatInbox();
                    }
                })
                .catch(() => {});
        },
        subscribeChatInbox() {
            initEcho();
            const echo = getEcho();
            if (!echo || !this.deliveryBoyId) return;
            try {
                echo.private('chat.delivery_boy.' + this.deliveryBoyId).listen('.message.sent', () => {
                    this.fetchUnreadChat();
                    window.dispatchEvent(new Event('chat:incoming'));
                });
            } catch (e) { /* best-effort */ }
        },
        // Show the maintenance overlay if the delivery-boy app is under maintenance.
        checkMaintenance() {
            axios.get(this.$deliveryBoyApiUrl + '/settings').then(res => {
                const d = res.data.data || {};
                if (Number(d.app_mode_delivery_boy) === 1) {
                    this.maintenanceModal = true;
                    this.maintenanceRemark = d.app_mode_delivery_boy_remark || '';
                }
            }).catch(() => { });
        },
        // Live maintenance toggle via the public `maintenance` channel.
        subscribeMaintenance() {
            initEcho();
            const echo = getEcho();
            if (!echo) return;
            try {
                echo.channel('maintenance').listen('.maintenance.toggled', (e) => {
                    if (!e || e.surface !== 'delivery_boy') return;
                    this.maintenanceModal = Number(e.mode) === 1;
                    const rk = e.remark || {};
                    const code = (window.appLocale || 'en');
                    this.maintenanceRemark = rk[code] || rk.en || Object.values(rk)[0] || '';
                });
            } catch (err) { /* best-effort */ }
        },
        checkDeliveryBoyStatus() {
            // Check if delivery boy is blocked
            axios.get(this.$deliveryBoyApiUrl + '/get_delivery_boy_status')
                .then((response) => {
                    if (response.data.status === 1) {
                        const deliveryBoyStatus = response.data.data.status;
                        // Status 4 means blocked
                        if (deliveryBoyStatus === 4) {
                            this.remark = response.data.data.remark || 'No reason provided';
                            this.deliveryBoyBlockedModal = true;
                            // Clear the interval to stop further checks
                            if (this.statusCheckInterval) {
                                clearInterval(this.statusCheckInterval);
                            }
                        }
                    }
                })
                .catch((error) => {
                    // Silently fail - don't show errors for background checks
                    console.error('Status check error:', error);
                });
        },
        handleBlockedLogout() {
            // Logout the delivery boy
            Auth.logout();
            // Redirect to login page
            this.$router.push({ path: '/delivery_boy/login' });
        }

    }
}
</script>

<style scoped>
/* lucide menu icons — theme styles .sidebar-link svg (built for feather).
   fill:none guards against the active-state rule `.sidebar-link svg { fill:#fff }`. */
.sidebar-link svg.lucide { width: 20px; height: 20px; stroke-width: 1.8px; flex-shrink: 0; fill: none !important; }

.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.3s;
}

.fade-enter,
.fade-leave-to {
    opacity: 0;
}

/* Full-page maintenance screen — sits above everything and blocks all interaction. */
.db-maintenance-screen {
    position: fixed;
    inset: 0;
    z-index: 20000;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
    text-align: center;
    color: #fff;
    background: linear-gradient(135deg, #1f2937, #111827);
}
.db-maintenance-inner {
    max-width: 520px;
}
.db-maintenance-icon {
    color: var(--bs-primary);
    display: block;
    margin: 0 auto;
}
.db-maintenance-msg {
    font-size: 1.05rem;
    opacity: 0.85;
    margin: 0;
    white-space: pre-line;
}
</style>
