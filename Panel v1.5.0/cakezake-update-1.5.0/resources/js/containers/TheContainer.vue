<template>
    <div id="app">
        <div id="sidebar" class="active">
            <div class="sidebar-wrapper active">
                <div class="sidebar-header">
                    <div class="d-flex justify-content-center align-items-center" style="position: relative;">
                        <div class="logo">
                            <router-link to="/" style="display: flex; align-items: center; justify-content: center;">
                                <img class="container-logo" v-if="$appLogo != ''" :src="$storageUrl + $appLogo" alt='Logo'
                                    srcset="" />
                                <img class="container-logo" v-else :src="$baseUrl + '/images/logo.png'" alt='Logo'
                                    srcset="" />
                            </router-link>
                        </div>
                    </div>
                </div>
                <div class="sidebar-menu">
                    <ul class="menu">

                        <li class="sidebar-item sidebar-search">
                            <!-- Typing still filters the menu; the button (or ⌘K / Ctrl K)
                                 opens the palette that searches settings and forms too. -->
                            <div class="sidebar-search-box">
                                <b-form-input v-model="search" type="search" :placeholder="__('search')"></b-form-input>
                                <button type="button" class="sidebar-search-kbd" :title="__('search_everything')"
                                    @click="openGlobalSearch">{{ searchShortcutLabel }}</button>
                            </div>
                        </li>

                        <template v-for="group in sidebarGroups" :key="group.title">
                        <li class="sidebar-title" v-if="groupHasVisibleItems(group) && groupMatchesSearch(group)">{{ group.title }}</li>

                        <template v-for="item in group.items">
                            <li class="sidebar-item"
                                :class="{ 'active': isActive(item.url, item.exact) || subIsActive(item), 'has-sub': isHasSub(item) }"
                                v-if="isItemVisible(item) && itemMatchesSearch(item)">

                                <template v-if="isHasSub(item)">
                                    <a class="sidebar-link">
                                        <component :is="item.icon" />
                                        <span>{{ item.name }}</span>
                                    </a>
                                    <ul class="submenu" :class="{ 'active': subIsActive(item) || isSearching }">
                                        <template v-for="sub in item.submenu" :key="sub.key">
                                            <li class="submenu-item" :class="{ 'active': isActive(sub.url, sub.exact, item.submenu) }"
                                                v-if="(sub.role ? $role('Super Admin') : sub.permission && $can(sub.permission)) && submenuMatchesSearch(item, sub)">
                                                <router-link :to="sub.url" @click="closeSideBarMenu()">
                                                    {{ sub.name }}
                                                </router-link>
                                            </li>
                                        </template>
                                    </ul>
                                </template>

                                <template v-else>
                                    <router-link class="sidebar-link" :to="item.url" @click="closeSideBarMenu()">
                                        <component :is="item.icon" />
                                        <span>{{ item.name }}</span>
                                        <span v-if="item.url === '/chat' && unreadChat > 0"
                                            class="badge bg-danger rounded-pill ms-2">{{ unreadChat }}</span>
                                    </router-link>
                                </template>
                            </li>
                        </template>
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
            <the-footer></the-footer>
        </div>

        <!-- Setup guide: floats above the page, bottom-left. Gone for good once
             every step passes; collapsible so it never blocks the UI. -->
        <div v-if="setup.show" class="sg-pop" :class="{ 'is-collapsed': setupCollapsed }">
            <button v-if="setupCollapsed" type="button" class="sg-pop-fab"
                :title="__('setup_guide')" @click="setSetupCollapsed(false)">
                <span class="sg-pop-ring" :style="{ '--pct': setup.percent }">
                    <span>{{ setup.percent }}%</span>
                </span>
            </button>

            <template v-else>
                <div class="sg-pop-head">
                    <span class="sg-pop-ring" :style="{ '--pct': setup.percent }">
                        <span>{{ setup.percent }}%</span>
                    </span>
                    <span class="sg-pop-text">
                        <span class="sg-pop-title">{{ __('setup_guide') }}</span>
                        <span class="sg-pop-sub">
                            {{ setup.completed }}/{{ setup.total }} {{ __('steps_completed') }}
                        </span>
                    </span>
                    <button type="button" class="sg-pop-close" :title="__('close')"
                        @click="setSetupCollapsed(true)">
                        <X :size="15" />
                    </button>
                </div>

                <div class="sg-pop-bar"><span :style="{ width: setup.percent + '%' }"></span></div>

                <router-link to="/setup_guide" class="sg-pop-cta">
                    {{ __('setup_guide') }}
                    <ArrowRight :size="14" />
                </router-link>
            </template>
        </div>

        <!-- Demo-mode "Buy Now": floating, bottom-right, opens the purchase page in
             a new tab. Collapsible to a small pill so it never blocks exploring. -->
        <div v-if="isDemoMode" class="demo-buy" :class="{ 'is-min': demoBuyMin }">
            <a :href="demoBuyUrl" target="_blank" rel="noopener noreferrer" class="demo-buy-main"
                v-b-tooltip.hover.left="demoBuyMin ? __('buy_now') : ''">
                <span class="demo-buy-shine"></span>
                <ShoppingBag :size="18" class="demo-buy-ic" />
                <span class="demo-buy-body">
                    <span class="demo-buy-title">{{ __('buy_now') }}</span>
                    <span class="demo-buy-sub">{{ __('demo_buy_hint') }}</span>
                </span>
            </a>
            <button type="button" class="demo-buy-toggle" @click="toggleDemoBuy"
                :title="demoBuyMin ? __('expand') : __('minimize')">
                <component :is="demoBuyMin ? 'ChevronLeft' : 'ChevronRight'" :size="14" />
            </button>
        </div>

        <!-- Global search palette: menus, settings pages and the create forms. -->
        <GlobalSearch ref="globalSearch" :menu="sidebarGroups" />
    </div>
</template>
<script>
import { markRaw } from 'vue'
import GlobalSearch from '../components/GlobalSearch.vue'
import TheSidebar from './TheSidebar.vue'
import TheFooter from './TheFooter.vue'
import VerticalHeader from './VerticalHeader.vue'
import Auth from '../Auth.js';
import axios from "axios";
import { initEcho, getEcho } from '../echo.js';
import {
    LayoutDashboard, ShoppingCart, MessagesSquare, LayoutGrid, Package, Boxes, Store as BranchIcon,
    LayoutTemplate, Gift, TicketPercent, Disc3, PackageCheck, RotateCcw, CreditCard, Bike, Bell, Mail,
    Settings, PenLine, Globe, Map, Users, ChartColumn, UserCog,
    ShieldCheck, CircleHelp, X, ArrowRight, ShoppingBag, ChevronUp, ChevronDown,
    ChevronLeft, ChevronRight, Tags,
} from 'lucide-vue-next';

const SIDEBAR_OVERLAY_BREAKPOINT = 1200;

export default {
    name: 'TheContainer',
    components: {
        GlobalSearch,
        TheSidebar,
        TheFooter,
        VerticalHeader,
        X,
        ArrowRight,
        ShoppingBag,
        ChevronUp,
        ChevronDown,
        ChevronLeft,
        ChevronRight,
    },
    created() {
        this.closeSideBarMenu();
        this.checkPermissions();
        this.fetchUnreadChat();
        this.subscribeChatInbox();
        // Refresh when the chat page reads/opens a thread (same-page, no route change).
        this._onUnread = () => this.fetchUnreadChat();
        window.addEventListener('chat:refresh-unread', this._onUnread);

        this.fetchSetupGuide();
        this._onSetup = () => this.fetchSetupGuide();
        window.addEventListener('setup-guide:refresh', this._onSetup);

        this._setupInterceptor = axios.interceptors.response.use(
            (response) => {
                const method = (response?.config?.method || '').toLowerCase();
                if (['post', 'put', 'patch', 'delete'].includes(method)) {
                    this.scheduleSetupRefresh();
                }
                return response;
            },
            (error) => Promise.reject(error)
        );
    },
    beforeUnmount() {
        if (this._onUnread) window.removeEventListener('chat:refresh-unread', this._onUnread);
        if (this._onSetup) window.removeEventListener('setup-guide:refresh', this._onSetup);
        if (this._setupInterceptor !== undefined) axios.interceptors.response.eject(this._setupInterceptor);
        clearTimeout(this._setupTimer);
        const echo = getEcho();
        if (echo) { try { echo.leave('chat.admins'); } catch (e) {} }
        // Don't leave the scroll lock behind on logout / layout swap.
        document.body.classList.remove('sidebar-open');
        document.querySelector('.sidebar-backdrop')?.remove();
    },
    watch: {
        '$route'() {
            this.checkPermissions();
            this.fetchUnreadChat();
            this.scheduleSetupRefresh();
        }
    },
    mounted() {
        if (window.localStorage.getItem('lang')) {
            this.lang = window.localStorage.getItem('lang');
            console.log(this.lang);
        }

        function slideToggle(t, e, o) { 0 === t.clientHeight ? j(t, e, o, !0) : j(t, e, o) } function slideUp(t, e, o) { j(t, e, o) } function slideDown(t, e, o) { j(t, e, o, !0) } function j(t, e, o, i) { void 0 === e && (e = 400), void 0 === i && (i = !1), t.style.overflow = "hidden", i && (t.style.display = "block"); var p, l = window.getComputedStyle(t), n = parseFloat(l.getPropertyValue("height")), a = parseFloat(l.getPropertyValue("padding-top")), s = parseFloat(l.getPropertyValue("padding-bottom")), r = parseFloat(l.getPropertyValue("margin-top")), d = parseFloat(l.getPropertyValue("margin-bottom")), g = n / e, y = a / e, m = s / e, u = r / e, h = d / e; window.requestAnimationFrame(function l(x) { void 0 === p && (p = x); var f = x - p; i ? (t.style.height = g * f + "px", t.style.paddingTop = y * f + "px", t.style.paddingBottom = m * f + "px", t.style.marginTop = u * f + "px", t.style.marginBottom = h * f + "px") : (t.style.height = n - g * f + "px", t.style.paddingTop = a - y * f + "px", t.style.paddingBottom = s - m * f + "px", t.style.marginTop = r - u * f + "px", t.style.marginBottom = d - h * f + "px"), f >= e ? (t.style.height = "", t.style.paddingTop = "", t.style.paddingBottom = "", t.style.marginTop = "", t.style.marginBottom = "", t.style.overflow = "", i || (t.style.display = "none"), "function" == typeof o && o()) : window.requestAnimationFrame(l) }) }
        let sidebarItems = document.querySelectorAll('.sidebar-item.has-sub');
        // Mark initially open submenus with 'open' class for toggle icon
        sidebarItems.forEach(function (item) {
            const submenu = item.querySelector('.submenu');
            if (submenu && submenu.classList.contains('active')) {
                item.classList.add('open');
            }
        });
        for (var i = 0; i < sidebarItems.length; i++) {
            let sidebarItem = sidebarItems[i];
            sidebarItems[i].querySelector('.sidebar-link').addEventListener('click', function (e) {
                e.preventDefault();

                let submenu = sidebarItem.querySelector('.submenu');
                const isCurrentlyOpen = submenu?.classList?.contains('active');

                // Accordion: close all other open submenus
                sidebarItems.forEach(function (otherItem) {
                    if (otherItem !== sidebarItem) {
                        const otherSubmenu = otherItem.querySelector('.submenu');
                        if (otherSubmenu && otherSubmenu.classList.contains('active')) {
                            otherSubmenu.classList.remove('active');
                            // Use the same animation instead of setting display: none instantly
                            slideUp(otherSubmenu, 300);
                            otherItem.classList.remove('open');
                        }
                    }
                });

                // Toggle current submenu
                if (isCurrentlyOpen) {
                    submenu?.classList?.remove('active');
                    sidebarItem.classList.remove('open');
                    slideUp(submenu, 300);
                } else {
                    submenu?.classList?.add('active');
                    sidebarItem.classList.add('open');
                    slideDown(submenu, 300);
                }
            })
        }

        if (window.innerWidth < SIDEBAR_OVERLAY_BREAKPOINT) {
            document.getElementById('sidebar')?.classList?.remove('active');
        }
        // Backdrop + body scroll lock while the sidebar overlays the content
        // (< 1024px). Above that the sidebar pushes content instead of covering
        // it, so the page must stay scrollable.
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

        // Scroll into active sidebar
        if (document.querySelector('.sidebar-item.active')) {
            document.querySelector('.sidebar-item.active').scrollIntoView(false)
        }


    },
    data: function () {
        return {
            lang: 'en',
            search: '',
            unreadChat: 0,
            chatBadgeTimer: null,
            isLoading: false,
            suspecious: null,

            // Setup guide progress; `show` stays false until we know there is
            // something outstanding, so the widget never flashes in and out.
            setup: { show: false, percent: 0, completed: 0, total: 0 },
            // Collapsing is a per-browser preference, not a dismissal: the popup
            // still returns as a small badge until every step is done.
            setupCollapsed: window.localStorage.getItem('setup_guide_collapsed') === '1',

            // Demo-mode "Buy Now". Change this URL to the actual purchase page.
            demoBuyUrl: 'https://www.cakezake.com/products/cakezake-hyperlocal-quick-commerce-ecommerce-platform',
            demoBuyMin: window.localStorage.getItem('demo_buy_min') === '1',

            sidebarGroups: [
                {
                    title: __('main'),
                    items: [
                        {
                            name: __('dashboard'),
                            icon: markRaw(LayoutDashboard),
                            url: '/dashboard',
                            permission: 'manage_dashboard'
                        },
                        {
                            name: __('orders'),
                            icon: markRaw(ShoppingCart),
                            url: '/orders',
                            permission: 'order_list',
                            exact: true,
                        },
                        {
                            // The dispatch desk: every parcel across orders, courier or not.
                            name: __('shipments'),
                            icon: markRaw(PackageCheck),
                            url: '/shipments',
                            permission: 'order_list',
                        },
                        {
                            name: __('self_pickup'),
                            icon: markRaw(PackageCheck),
                            url: '/orders/pickup',
                            permission: 'self_pickup_order_list'
                        },
                        {
                            name: __('return_requests'),
                            icon: markRaw(RotateCcw),
                            url: '/return_requests',
                            permission: 'return_request_list',
                        },
                        {
                            name: __('chat'),
                            icon: markRaw(MessagesSquare),
                            url: '/chat',
                            permission: 'chat'
                        },
                        {
                            name: __('home_builder'),
                            icon: markRaw(LayoutTemplate),
                            permission: null,
                            submenu: [
                                {
                                    name: __('home_builder'),
                                    url: '/home_builder',
                                    permission: 'home_builder_list',
                                },
                                {
                                    name: __('page_builder'),
                                    url: '/page_builder',
                                    permission: 'page_builder_list',
                                },
                            ]
                        },
                    ],
                },
                {
                    title: __('catalog'),
                    items: [
                        {
                            name: __('categories'),
                            icon: markRaw(LayoutGrid),
                            permission: null,
                            submenu: [
                                {
                                    name: __('categories'),
                                    url: '/manage_categories',
                                    permission: 'category_list',
                                },
                                {
                                    name: __('attributes'),
                                    url: '/attributes',
                                    permission: 'attribute_list',
                                },
                                {
                                    name: __('categories_order'),
                                    url: '/categories_order',
                                    permission: 'manage_categories_order',
                                },
                            ]
                        },
                        {
                            name: __('products'),
                            icon: markRaw(Package),
                            permission: null,
                            submenu: [
                                {
                                    name: __('add_product'),
                                    url: '/products/create',
                                    permission: 'product_create',
                                },
                                {
                                    name: __('manage_products'),
                                    url: '/products',
                                    permission: 'product_list',
                                },
                                {
                                    name: __('product_ratings'),
                                    url: '/product_ratings',
                                    permission: 'product_ratings',
                                },
                                {
                                    name: __('media'),
                                    url: '/media',
                                    permission: 'manage_media',
                                },
                                {
                                    name: __('bulk_upload'),
                                    url: '/bulk_upload',
                                    permission: 'manage_product_bulk_upload',
                                },
                                {
                                    name: __('bulk_update'),
                                    url: '/bulk_update',
                                    permission: 'manage_product_bulk_upload',
                                },
                            ]
                        },
                        {
                            name: __('brands'),
                            icon: markRaw(Tags),
                            url: '/brands',
                            permission: 'brand_list',
                        },
                        {
                            name: __('stock_management'),
                            icon: markRaw(Boxes),
                            url: '/manage_stock',
                            permission: 'stock_management',
                        },
                    ],
                },
                {
                    /* Country > zone > branch, widest scope first. */
                    title: __('locations'),
                    items: [
                        {
                            name: __('countries'),
                            icon: markRaw(Globe),
                            url: '/countries',
                            permission: 'country_list',
                        },
                        {
                            name: __('zones'),
                            icon: markRaw(Map),
                            permission: null,
                            submenu: [
                                {
                                    name: __('add_zone'),
                                    url: '/zones/create',
                                    permission: 'zone_create',
                                },
                                {
                                    name: __('manage_zones'),
                                    url: '/zones',
                                    permission: 'zone_list',
                                },
                                {
                                    name: __('delivery_cities'),
                                    url: '/delivery_cities',
                                    permission: 'delivery_city_list',
                                },
                                {
                                    name: __('delivery_areas'),
                                    url: '/delivery_areas',
                                    permission: 'delivery_area_list',
                                }
                            ]
                        },
                        {
                            name: __('branches'),
                            icon: markRaw(BranchIcon),
                            permission: null,
                            submenu: [
                                {
                                    name: __('add_branch'),
                                    url: '/branches/create',
                                    permission: 'branch_create',
                                },
                                {
                                    name: __('manage_branches'),
                                    url: '/branches',
                                    permission: 'branch_list',
                                },
                            ],
                        },
                    ],
                },
                {
                    title: __('delivery'),
                    items: [
                        {
                            name: __('delivery_boys'),
                            icon: markRaw(Bike),
                            permission: null,
                            submenu: [
                                {
                                    name: __('add_delivery_boy'),
                                    url: '/delivery_boys/create',
                                    permission: 'delivery_boy_create',
                                },
                                {
                                    name: __('manage_delivery_boys'),
                                    url: '/delivery_boys',
                                    permission: 'delivery_boy_list',
                                },
                                {
                                    name: __('dlivery_boy_requests'),
                                    url: '/registered_delivery_boys',
                                    permission: 'delivery_boy_list',
                                },
                                {
                                    name: __('settlement_history'),
                                    url: '/settlement_history',
                                    permission: 'delivery_boy_wallet_transactions_list',
                                },
                                {
                                    name: __('cash_collection'),
                                    url: '/cash_collection',
                                    permission: 'cash_collection_list',
                                },
                                {
                                    name: __('salary_transactions'),
                                    url: '/salary_transactions',
                                    permission: 'delivery_boy_salary_list',
                                },
                                {
                                    name: __('withdrawal_requests'),
                                    url: '/withdrawal_requests',
                                    permission: 'withdrawal_request_list',
                                },
                            ]
                        },
                    ],
                },
                {
                    title: __('customers'),
                    items: [
                        {
                            name: __('customers'),
                            icon: markRaw(Users),
                            permission: null,
                            submenu: [
                                {
                                    name: __('customers'),
                                    url: '/users',
                                    permission: 'customer_list',
                                },
                                {
                                    name: __('wishlists'),
                                    url: '/wishlists',
                                    permission: 'manage_wishlists',
                                },
                                {
                                    name: __('stock_alerts'),
                                    url: '/stock_alerts',
                                    permission: 'manage_stock_alerts',
                                },
                                {
                                    name: __('carts'),
                                    url: '/carts',
                                    permission: 'manage_carts',
                                },
                                {
                                    name: __('wallet_transactions'),
                                    url: '/wallet_transactions',
                                    permission: 'manage_customer_wallet',
                                },
                                {
                                    name: __('transactions'),
                                    url: '/transactions',
                                    permission: 'transaction_list',
                                },
                            ]
                        },
                    ],
                },
                {
                    title: __('marketing'),
                    items: [
                        {
                            name: __('manage_popup_offer'),
                            icon: markRaw(Gift),
                            url: '/popup',
                            permission: 'popup_offer_update',
                        },
                        {
                            name: __('promo_code'),
                            icon: markRaw(TicketPercent),
                            permission: 'promo_code_list',
                            submenu: [
                                {
                                    name: __('add_promo_code'),
                                    url: '/promo_code/create',
                                    permission: 'promo_code_create',
                                },
                                {
                                    name: __('manage_promo_code'),
                                    url: '/promo_code',
                                    permission: 'promo_code_list',
                                }
                            ]
                        },
                        {
                            name: __('spin_wheel'),
                            icon: markRaw(Disc3),
                            permission: 'spin_wheel_list',
                            submenu: [
                                {
                                    name: __('manage_spin_wheel'),
                                    url: '/spin_wheel',
                                    permission: 'spin_wheel_list',
                                },
                                {
                                    name: __('spin_history'),
                                    url: '/spin_wheel/history',
                                    permission: 'spin_wheel_list',
                                }
                            ]
                        },
                        {
                            name: __('blogs'),
                            icon: markRaw(PenLine),
                            permission: null,
                            submenu: [
                                {
                                    name: __('blog_categories'),
                                    url: '/blog_categories',
                                    permission: 'blog_category_list',
                                },
                                {
                                    name: __('blogs'),
                                    url: '/blogs',
                                    permission: 'blog_list',
                                }
                            ]
                        },
                        {
                            name: __('notifications'),
                            icon: markRaw(Bell),
                            url: '/notifications',
                            permission: 'notification_list',
                        },
                        {
                            // Single destination — a submenu of one just adds a click.
                            name: __('email'),
                            icon: markRaw(Mail),
                            url: '/emails',
                            permission: 'manage_emails',
                        },
                    ],
                },
                {
                    title: __('reports'),
                    items: [
                        {
                            name: __('reports'),
                            icon: markRaw(ChartColumn),
                            permission: null,
                            submenu: [
                                { name: __('sales_report'), url: '/reports/sales', permission: 'report_sales' },
                                { name: __('orders_report'), url: '/reports/orders', permission: 'report_orders' },
                                { name: __('product_performance'), url: '/reports/products', permission: 'report_products' },
                                { name: __('customer_report'), url: '/reports/customers', permission: 'report_customers' },
                                { name: __('inventory_report'), url: '/reports/inventory', permission: 'report_inventory' },
                                { name: __('returns_refunds'), url: '/reports/returns', permission: 'report_returns' },
                                { name: __('delivery_boy_report'), url: '/reports/delivery', permission: 'report_delivery' },
                                { name: __('payment_report'), url: '/reports/payment', permission: 'report_payment' },
                                { name: __('category_report'), url: '/reports/category', permission: 'report_category' },
                                { name: __('promo_report'), url: '/reports/promo', permission: 'report_promo' },
                                { name: __('tax_report'), url: '/reports/tax', permission: 'report_tax' },
                                { name: __('order_wise_tax_report'), url: '/reports/tax_orders', permission: 'report_tax_orders' },
                            ]
                        },
                    ],
                },
                {
                    title: __('administration'),
                    items: [
                        {
                            name: __('settings'),
                            icon: markRaw(Settings),
                            url: '/settings',
                            permission: null,
                            anyPermission: [
                                'manage_general_settings', 'manage_login_settings', 'manage_cart_settings',
                                'manage_website_settings', 'manage_app_settings', 'manage_deeplink_settings',
                                'manage_social_media', 'manage_seo_settings',
                                'manage_about_us', 'manage_contact_us',
                                'manage_smtp_settings', 'manage_chat_settings',
                                'manage_firebase_settings', 'manage_notification_templates',
                                'manage_sms_settings', 'manage_sms_templates',
                                'manage_api_credentials', 'manage_system_updater',
                                'manage_activity_logs', 'manage_cron_jobs',
                                'manage_plugins', 'language_list',
                            ],
                        },
                        {
                            name: __('system_users'),
                            icon: markRaw(UserCog),
                            url: '/system_users',
                            role: true
                        },
                        {
                            name: __('role'),
                            icon: markRaw(ShieldCheck),
                            url: '/role',
                            role: true
                        },
                        {
                            name: __('faqs'),
                            icon: markRaw(CircleHelp),
                            url: '/faqs',
                            permission: 'faq_list',
                        },
                    ],
                },
                {
                    title: __('branch_panel'),
                    items: [
                        {
                            name: __('branch_users'),
                            icon: markRaw(UserCog),
                            url: '/branch_users',
                            permission: 'branch_user_manage',
                            branchOnly: true,
                        },
                        {
                            name: __('branch_roles'),
                            icon: markRaw(ShieldCheck),
                            url: '/branch_roles',
                            permission: 'branch_role_manage',
                            branchOnly: true,
                        },
                    ],
                },
            ],
        }
    },
    computed: {
        sidebarItems() {
            return this.sidebarGroups.flatMap(group => group.items);
        },
        searchQuery() {
            return (this.search || '').trim().toLowerCase();
        },
        isSearching() {
            return this.searchQuery.length > 0;
        },
        searchShortcutLabel() {
            return (navigator.platform || '').toLowerCase().includes('mac') ? '⌘K' : 'Ctrl K';
        },
        // Demo mode flag comes through as the string "1".
        isDemoMode() {
            return String(this.$isDemo) === '1';
        },
    },
    methods: {

        openGlobalSearch() {
            if (this.$refs.globalSearch) this.$refs.globalSearch.show();
        },

        toggleDemoBuy() {
            this.demoBuyMin = !this.demoBuyMin;
            window.localStorage.setItem('demo_buy_min', this.demoBuyMin ? '1' : '0');
        },

        matchText(text) {
            const q = this.searchQuery;
            if (!q) return true;
            return String(text || '').toLowerCase().includes(q);
        },
        itemMatchesSearch(item) {
            if (!this.searchQuery) return true;
            if (this.matchText(item.name)) return true;
            if (this.isHasSub(item)) {
                return item.submenu.some(sub => this.matchText(sub.name));
            }
            return false;
        },
        // A submenu child shows if the query is empty, the child matches, or its
        // parent matches (so selecting a whole section by name keeps its children).
        submenuMatchesSearch(item, sub) {
            if (!this.searchQuery) return true;
            return this.matchText(sub.name) || this.matchText(item.name);
        },
        groupMatchesSearch(group) {
            if (!this.searchQuery) return true;
            return group.items.some(item => this.itemMatchesSearch(item));
        },
        subIsActive(item) {
            const paths = Array.isArray(item.submenu) ? item.submenu : [];
            return paths.some(path => {
                return this.$route.path.indexOf(path.url) === 0;
            });
        },
        isActive(url, exact = false, siblings = []) {
            if (!url) return false;
            let path = this.$route.path;
            if (path === '/branch' || path.startsWith('/branch/')) {
                path = path.slice('/branch'.length) || '/dashboard';
            }
            if (path === url) {
                return true;
            }

            if (exact || url === '/' || !path.startsWith(url + '/')) {
                return false;
            }
            // A child path lights up the LONGEST matching entry among its siblings only:
            const closer = (siblings || []).some(sib => sib && sib.url && sib.url !== url
                && sib.url.length > url.length
                && (path === sib.url || path.startsWith(sib.url + '/')));
            return !closer;
        },
        isHasSub(item) {
            if (item.hasOwnProperty("submenu")) {
                if (item.submenu.length > 0) {
                    return true;
                }
            }
            return false;
        },
        isItemVisible(item) {
            if (item.branchOnly) return this.$isBranchUser() && (!item.permission || this.$can(item.permission));
            if (item.role === true) return this.$role('Super Admin');
            if (item.permission && this.$can(item.permission)) return true;
            if (item.anyPermission && this.hasAnyPermission(item.anyPermission)) return true;
            if (item.permission === null && this.isHasSub(item) && this.hasAnySubmenuPermission(item)) return true;
            return false;
        },
        groupHasVisibleItems(group) {
            return group.items.some(item => this.isItemVisible(item));
        },
        // Link-style items that aggregate several areas (e.g. the Settings hub) are
        // visible when the user holds ANY of the listed permissions.
        hasAnyPermission(list) {
            if (!Array.isArray(list) || !list.length) return false;
            return list.some(p => this.$can(p));
        },
        hasAnySubmenuPermission(item) {
            if (!item.submenu || item.submenu.length === 0) {
                return false;
            }
            return item.submenu.some(submenu => {
                if (submenu.role) {
                    return this.$role('Super Admin') && (item.name === 'Role' || item.name === 'System Users');
                }
                return submenu.permission && this.$can(submenu.permission);
            });
        },
        checkPermissions() {
            var current_path = this.$route.path;
            var permission = '';

            this.sidebarItems.forEach(menu => {
                //Only Main Categories
                if (menu.submenu && menu.submenu.length > 0) {
                    menu.submenu.forEach(submenu => {
                        if (submenu.url === current_path) {
                            permission = submenu.permission;
                        }
                    });
                } else {
                    if (menu.url === current_path) {
                        permission = menu.permission;
                    }
                }
            });

            if (Auth.check() && UserPermissions.length === 0) {
                //this.$router.push({path:'/login'});
                if (window.localStorage.getItem('loginCheck') == 1) {
                    Auth.logout();
                }
                window.localStorage.setItem('loginCheck', 1);
                window.location.reload();
            }
            else if (Auth.check() && permission && !this.$can(permission)) {
                this.$router.push({ path: '/unauthorized' });
            }
        },

        setSetupCollapsed(value) {
            this.setupCollapsed = value;
            window.localStorage.setItem('setup_guide_collapsed', value ? '1' : '0');
        },
        scheduleSetupRefresh() {
            if (!this.setup.show) return;
            clearTimeout(this._setupTimer);
            this._setupTimer = setTimeout(() => this.fetchSetupGuide(), 700);
        },
        fetchSetupGuide() {
            if (this.$isBranchUser && this.$isBranchUser()) {
                this.setup.show = false;
                return;
            }
            axios.get(this.$apiUrl + '/setup_guide')
                .then(res => {
                    const d = res.data?.data || {};
                    this.setup = {
                        show: !d.is_complete,
                        percent: d.percent || 0,
                        completed: d.completed || 0,
                        total: d.total || 0,
                    };
                    // The guide page renders from this instead of fetching again,
                    // so both stay in step off a single request.
                    window.dispatchEvent(new CustomEvent('setup-guide:updated', { detail: d }));
                })
                // Never let a failed check block the panel — just leave it hidden.
                .catch(() => { this.setup.show = false; });
        },
        fetchUnreadChat() {
            if (!this.$can || !this.$can('chat')) return;
            axios.get(this.$apiUrl + '/chat/unread_count')
                .then((res) => { this.unreadChat = (res.data && res.data.data && res.data.data.count) || 0; })
                .catch(() => {});
        },
        subscribeChatInbox() {
            if (!this.$can || !this.$can('chat')) return;
            initEcho();
            const echo = getEcho();
            if (!echo) return;
            try {
                echo.private('chat.admins').listen('.message.sent', () => {
                    this.fetchUnreadChat();
                    window.dispatchEvent(new Event('chat:incoming'));
                });
            } catch (e) { /* best-effort */ }
        },
        closeSideBarMenu() {
            var w = window.innerWidth;
            if (w < 1024) {
                document.getElementById('sidebar')?.classList?.remove('active');
                const backdrop = document.querySelector('.sidebar-backdrop');
                if (backdrop) backdrop.remove();
                // Navigating away with the lock still on would leave the page unscrollable.
                document.body.classList.remove('sidebar-open');
            }
        },
    }
}
</script>

<style scoped>
/* lucide menu icons — theme already colors .sidebar-link svg (built for feather icons).
   fill:none guards against the active-state theme rule `.sidebar-link svg { fill:#fff }`,
   which would solid-fill outline icons. */
.sidebar-link svg.lucide { width: 20px; height: 20px; stroke-width: 1.8px; flex-shrink: 0; fill: none !important; }

.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.3s;
}

.fade-enter,
.fade-leave-to {
    opacity: 0;
}
</style>
