import Auth from '../Auth.js';
import { createRouter, createWebHistory } from "vue-router";
import axios from "axios";
const Install = () => import("../views/Install.vue");

// Auth
const Login = () => import("../views/Login.vue");
const ForgotPassword = () => import("../views/ForgotPassword.vue");
const ResetPassword = () => import("../views/ResetPassword.vue");

// Containers
const TheContainer = () => import("../containers/TheContainer.vue");
const TheContainerDeliveryBoy = () => import("../containers/TheContainerDeliveryBoy.vue");
const AccountSettings = () => import('../views/AccountSettings.vue');

// Views
const Dashboard = () => import("../views/Dashboard.vue");
const Orders = () => import("../views/Orders/Orders.vue");
const Chat = () => import("../views/Chat/Chat.vue");

// Notification Panel
const NotificationPanel = () => import("../views/NotificationPanel.vue");

// Categories
const ManageCategories = () => import("../views/Category/ManageCategories.vue");
const CategoryEdit = () => import("../views/Category/Edit.vue");
const CategoriesOrder = () => import("../views/Category/CategoriesOrder.vue");

// Products
const Products = () => import("../views/Product/Products.vue");
const EditProduct = () => import("../views/Product/EditProduct.vue");
const ProductAddons = () => import("../views/Product/Addons/ProductAddons.vue");
const CloneProduct = () => import("../views/Product/EditProduct.vue");
const ViewProduct = () => import("../views/Product/ViewProduct.vue");
const TaxCategories = () => import("../views/Product/TaxCategories/TaxCategories.vue");
const TaxRules = () => import("../views/Product/TaxRules/TaxRules.vue");
const Media = () => import("../views/Product/Media.vue");
const ProductRatings = () => import("../views/Product/ProductRatings.vue");
const ProductBulk = () => import("../views/Product/ProductBulk.vue");
const Brands = () => import("../views/Product/Brands/Brands.vue");
const Attributes = () => import("../views/Category/Attributes/Attributes.vue");
const ManageStock = () => import("../views/Product/ManageStock.vue");

// Branches
const Branches = () => import("../views/Branch/Branches.vue");
const EditBranch = () => import("../views/Branch/EditBranch.vue");

//Home Slider Images
const HomeBuilder = () => import("../views/HomeBuilder/HomeBuilder.vue");
const HomeBuilderEditor = () => import("../views/HomeBuilder/HomeBuilderEditor.vue");
const PageBuilder = () => import("../views/PageBuilder/PageBuilder.vue");
const PageBuilderEditor = () => import("../views/PageBuilder/PageBuilderEditor.vue");

//Promo Code
const PromoCode = () => import("../views/PromoCode/PromoCode.vue");
const SpinWheel = () => import("../views/SpinWheel/SpinWheel.vue");
const SpinWheelForm = () => import("../views/SpinWheel/SpinWheelForm.vue");
const SpinHistory = () => import("../views/SpinWheel/SpinHistory.vue");
const PromoCodeForm = () => import("../views/PromoCode/PromoCodeForm.vue");

//Setting - Branch Settings
const GeneralSettings = () => import("../views/Setting/GeneralSettings.vue");
const Settings = () => import("../views/Setting/Settings.vue");
const AppSettings = () => import("../views/Setting/AppSettings.vue");
const MaintenanceSettings = () => import("../views/Setting/Maintenance.vue");
const LoginSettings = () => import("../views/Setting/LoginSettings.vue");
const CartSettings = () => import("../views/Setting/CartSettings.vue");
const InvoiceSettings = () => import("../views/Setting/InvoiceSettings.vue");
const DeeplinkSettings = () => import("../views/Setting/DeeplinkSettings.vue");
const SmtpSettings = () => import("../views/Setting/SmtpSettings.vue");
const ChatSettings = () => import("../views/Setting/ChatSettings.vue");
const ApiCredentials = () => import("../views/Setting/ApiCredentials.vue");
const TaxSettings = () => import("../views/Setting/TaxSettings.vue");

//Setting - Payment Methods

//Setting - Contact Us
const ContactUs = () => import("../views/Setting/ContactUs.vue");

//Setting - Contact Us
const AboutUs = () => import("../views/Setting/AboutUs.vue");

// Policies moved to the Country form (country-scoped).

const FirebaseSettings = () => import("../views/Setting/FirebaseSettings.vue");
const NotificationTemplates = () => import("../views/Setting/NotificationTemplates/NotificationTemplates.vue");
const NotificationSettings = () => import("../views/Setting/NotificationSettings.vue");
const SettingsEmailTemplates = () => import("../views/Setting/EmailTemplates/EmailTemplates.vue");
const SmsSettings = () => import("../views/Setting/SmsSettings.vue");
const SmsTemplates = () => import("../views/Setting/SmsTemplates/SmsTemplates.vue");
const SeoSettings = () => import("../views/Setting/SeoSettings/SeoSettings.vue");

//Notifications - Send Notifications
const Notifications = () => import("../views/Notifications/Notifications.vue");
const Emails = () => import("../views/Emails/Emails.vue");
// Featured Section to show products
const PopupOffer = () => import("../views/Offers/PopupOffer.vue");

// DeliveryBoys
const DeliveryBoys = () => import("../views/DeliveryBoys/DeliveryBoys.vue");
const ViewDeliveryBoy = () => import("../views/DeliveryBoys/ViewDeliveryBoy.vue");
const EditDeliveryBoy = () => import("../views/DeliveryBoys/EditDeliveryBoy.vue");
const RegisteredDeliveryBoys = () => import("../views/DeliveryBoys/RegisteredDeliveryBoys.vue");

// Settlement History
const DeliveryBoySettlementHistory = () => import("../views/DeliveryBoys/SettlementHistory/SettlementHistory.vue");
const SalaryTransactions = () => import("../views/DeliveryBoys/SalaryTransactions/SalaryTransactions.vue");

// Cash Collection
const CashCollection = () => import("../views/DeliveryBoys/CashCollection/CashCollection.vue");

// Front End Header
const WebsiteSettings = () => import("../views/Setting/WebsiteSettings.vue");
// Blogs
const BlogCategories = () => import("../views/Blogs/BlogCategories.vue");
const Blogs = () => import("../views/Blogs/Blogs.vue");

// Social Media
const SocialMedia = () => import("../views/Setting/SocialMedia/SocialMedia.vue");

//Customers
const Customers = () => import("../views/Customers/Customers.vue");
const ViewCustomer = () => import("../views/Customers/ViewCustomer.vue");

//Customers Wallet Transactions
const WalletTransactions = () => import("../views/Customers/WalletTransactions/WalletTransactions.vue");
// Transactions
const Transactions = () => import("../views/Customers/Transactions.vue");
// Wishlists
const Wishlists = () => import("../views/Customers/Wishlists.vue");
const StockAlerts = () => import("../views/Customers/StockAlerts.vue");
const Carts = () => import("../views/Customers/Carts.vue");
// Product Requests

// Withdrawal Requests
const WithdrawalRequests = () => import("../views/WithdrawalRequests/WithdrawalRequests.vue");

// Return Requests
const ReturnRequests = () => import("../views/ReturnRequests/ReturnRequests.vue");

// Sales Reports

// Product Sales Reports
const ReportPage = () => import("../views/Reports/ReportPage.vue");

// Commission Reports
// System Users
const SystemUsers = () => import("../views/SystemUsers/SystemUsers.vue");
const Role = () => import("../views/Role/Role.vue");
const BranchUsers = () => import("../views/BranchPanel/BranchUsers.vue");
const BranchRoles = () => import("../views/BranchPanel/BranchRoles.vue");


// Errors
const PageNotFound = () => import("../views/errors/404.vue");
const Unauthorized = () => import("../views/errors/403.vue");
const ServerError = () => import("../views/errors/500.vue");

const SystemUpdater = () => import("../views/Setting/SystemUpdater.vue");
const Plugins = () => import("../views/Plugins/Plugins.vue");
const Shipments = () => import("../views/Orders/Shipments.vue");
const PluginSettings = () => import("../views/Plugins/PluginSettings.vue");
const SetupGuide = () => import("../views/SetupGuide.vue")
const CronJobs = () => import("../views/Setting/CronJobs.vue");
const ActivityLogs = () => import("../views/Setting/ActivityLogs.vue");

// Location
const Zones = () => import("../views/Zone/Zones.vue");
const EditZone = () => import("../views/Zone/EditZone.vue");
const DeliveryCities = () => import("../views/Zone/DeliveryCities.vue");
const DeliveryAreas = () => import("../views/Zone/DeliveryAreas.vue");

//Faqs
const Faqs = () => import("../views/Faqs/Faqs.vue");

// Languages
const Languages = () => import("../views/Setting/Languages/Languages.vue")

// Countries
const Countries = () => import("../views/Countries/Countries.vue")
const Regions = () => import("../views/Countries/Regions.vue")
const CountryForm = () => import("../views/Countries/CountryForm.vue")

/***********************************************************/
/*Delivery Boy*/
const DeliveryBoyRegister = () => import("../views/DeliveryBoy/DeliveryBoyRegister.vue");
const DeliveryBoyLogin = () => import("../views/DeliveryBoy/DeliveryBoyLogin.vue");
const BranchLogin = () => import("../views/Branch/BranchLogin.vue");

const DeliveryBoyDashboard = () => import("../views/DeliveryBoy/Dashboard.vue");

const DeliveryBoyOrders = () => import("../views/DeliveryBoy/Orders.vue");
const DeliveryBoyChat = () => import("../views/DeliveryBoy/Chat.vue");
const DeliveryBoyReturnRequests = () => import("../views/ReturnRequests/ReturnRequests.vue");
const DeliveryBoyWithdrawalRequests = () => import("../views/DeliveryBoy/WithdrawalRequests/WithdrawalRequests.vue");
const DeliveryBoySettlementHistoryPanel = () => import("../views/DeliveryBoy/SettlementHistory.vue");
const DeliveryBoyCashCollection = () => import("../views/DeliveryBoy/CashCollection.vue");
const DeliveryBoySalaryTransactions = () => import("../views/DeliveryBoy/SalaryTransactions.vue");

const DeliverySettings = () => import('../views/AccountSettings.vue');
const DeliveryProfile = () => import("../views/DeliveryBoys/EditDeliveryBoy.vue");

const DeliveryBoyViewProduct = () => import("../views/Product/ViewProduct.vue");


let router = createRouter({
    history: createWebHistory(),
    scrollBehavior: () => ({ top: 0 }),
    routes: configRoutes(),
});

var roleSuperAdmin = "Super Admin";
var roleDeliveryBoy = "Delivery Boy";
var roleName = "Super Admin";
var appName = window.appName;

function currentPermissions() {
    let p = window.UserPermissions;
    if (typeof p === 'string') {
        try { p = JSON.parse(p); } catch (e) { p = []; }
    }
    return Array.isArray(p) ? p : [];
}
function hasPermission(name) {
    return !name || currentPermissions().indexOf(name) !== -1;
}

const LANDING_ROUTES = [
    ['manage_dashboard', '/dashboard'],
    ['order_list', '/orders'],
    ['self_pickup_order_list', '/orders/pickup'],
    ['product_list', '/products'],
    ['stock_management', '/manage_stock'],
    ['return_request_list', '/return_requests'],
    ['promo_code_list', '/promo_code'],
    ['spin_wheel_list', '/spin_wheel'],
    ['home_builder_list', '/home_builder'],
    ['customer_list', '/customers'],
    ['transaction_list', '/transactions'],
    ['manage_customer_wallet', '/wallet_transactions'],
    ['delivery_boy_list', '/delivery_boys'],
    ['cash_collection_list', '/cash_collection'],
    ['chat', '/chat'],
    ['notification_list', '/notifications'],
    ['manage_emails', '/emails'],
    ['report_sales', '/reports/sales'],
    ['category_list', '/manage_categories'],
    ['brand_list', '/brands'],
    ['tax_list', '/tax_categories'],
    ['attribute_list', '/attributes'],
    ['branch_user_manage', '/branch_users'],
    ['branch_role_manage', '/branch_roles'],
];
function firstAllowedRoute() {
    for (const [perm, path] of LANDING_ROUTES) {
        if (hasPermission(perm)) return path;
    }
    return '/unauthorized';
}

router.beforeEach((to, from, next) => {
    //if (to.matched.some(record => record.meta.requiresAuth) ) {
    if (isInstalled) {
        if (to.name == 'install') {
            router.push('/404').catch(() => { });
        }
        var title = to.meta && to.meta.title ? to.meta.title : 'Dashboard';
        window.document.title = title + ' - ' + appName;

        var nonloginRoute = ['install', 'login', 'delivery_boy_register', 'forgot_password', 'reset_password', 'delivery_boy_login', 'branch_login'];
        if (!nonloginRoute.includes(to.name)) {
            if (Auth.check()) {
                roleName = (Auth.user.role && Auth.user.role.name) || '';
                if (Auth.user.role_id === 3 && Auth.user.delivery_boy_status === 0) {

                    if (to.path.startsWith('/delivery_boy')) {
                        next();
                        return;
                    }
                    router.push('/delivery_boy').catch(() => { });
                    return;
                } else if (Auth.user.role_id === 3 && Auth.user.delivery_boy_status === 1 && to.name == "Dashboard") {
                    //Delivery boy
                    router.push('/delivery_boy/dashboard');
                    return;
                } else {
                    const isBranchUser = Auth.user.branch_id != null;
                    if (isBranchUser) {
                        if (!to.path.startsWith('/branch')) {
                            router.push('/branch' + (to.path === '/' ? '/dashboard' : to.path)).catch(() => { });
                            return;
                        }
                    } else if (to.path === '/branch' || to.path.startsWith('/branch/')) {
                        router.push(to.path.replace(/^\/branch/, '') || '/dashboard').catch(() => { });
                        return;
                    }

                    //Check Role Wise Access
                    if (to.meta.role && !to.meta.role.includes(roleName)) {
                        if (roleName == roleDeliveryBoy) {
                            router.push('/delivery_boy').catch(() => { });
                            return;
                        } else {
                            router.push('/dashboard').catch(() => { });
                            return;
                        }
                    }

                    if (to.name === 'Dashboard' && !hasPermission('manage_dashboard')) {
                        const dest = firstAllowedRoute();
                        if (dest && dest !== to.path) {
                            router.push(dest).catch(() => { });
                            return;
                        }
                    }

                    if (to.meta.permission && !hasPermission(to.meta.permission)) {
                        const dest = firstAllowedRoute();
                        if (dest && dest !== to.path) {
                            router.push(dest).catch(() => { });
                            return;
                        }
                    }

                    next();
                    return;
                }

            } else {
                router.push('/login').catch(() => { });
            }
        } else {
            next();
        }

    } else {
        next();
    }

});
export default router;

function configRoutes() {
    var roleSuperAdmin = "Super Admin";
    var roleAdmin = "Admin";
    var roleDeliveryBoy = "Delivery Boy";
    var roleName = "Super Admin";

    var adminSuperadminRoles = [roleSuperAdmin, roleAdmin];
    var deliveryBoyRoles = [roleDeliveryBoy];

    async function fetchData() {
        try {
            const response = await axios.get(window.baseUrl + '/api/role');
            const data = response.data.data.map(role => role.name);
            const roles = data;
            return roles; // Return adminRoles if needed
        } catch (error) {
            // Handle error
            console.error('Error fetching roles:', error);
        }
    }
    let adminRoles;
    fetchData();
    fetchData().then(result => {
        const otherroles = result.filter(role => role !== 'Delivery Boy');
        const adminRoles = otherroles;

    });
    return [
        {
            path: "/install",
            name: "install",
            component: Install,
            meta: {
                title: 'Install'
            },
        },
        {
            path: "/",
            alias: "/branch",
            redirect: "/dashboard",
            name: "Home",
            component: TheContainer,
            meta: {
                requiresAuth: true,
                role: adminRoles,
                title: 'Admin Dashboard'
            },
            children: [
                { path: "/unauthorized", component: Unauthorized, meta: { title: 'Unauthorized' } },
                {
                    path: "dashboard",
                    name: "Dashboard",
                    component: Dashboard,
                    meta: {
                        requiresAuth: true,
                        role: adminRoles,
                        permission: 'manage_dashboard',
                        title: 'Admin Dashboard'
                    },
                },
                {
                    path: "orders",
                    name: "Orders",
                    component: Orders,
                    props: { fixedDeliveryType: 'delivery' },
                    meta: {
                        permission: 'order_list',
                        role: adminRoles,
                        title: 'Orders'
                    },
                },
                {
                    // Same list, pinned to self-pickup orders.
                    path: "orders/pickup",
                    name: "PickupOrders",
                    component: Orders,
                    props: { fixedDeliveryType: 'pickup' },
                    meta: {
                        permission: 'self_pickup_order_list',
                        role: adminRoles,
                        title: 'Self Pickup Orders'
                    },
                },
                {
                    path: "chat",
                    name: "Chat",
                    component: Chat,
                    meta: {
                        permission: 'chat',
                        role: adminRoles,
                        title: 'Chat'
                    },
                },
                {
                    path: "notification_panel",
                    name: "NotificationPanel",
                    component: NotificationPanel,
                    meta: {
                        role: adminRoles,
                        title: 'Notification'
                    },
                },
                {
                    path: "manage_categories/create",
                    name: "manage_categories_create",
                    component: CategoryEdit,
                    meta: {
                        permission: 'category_create',
                        role: adminRoles,
                        title: 'Add Category'
                    },
                },
                {
                    path: "manage_categories/edit/:id",
                    name: "manage_categories_edit",
                    component: CategoryEdit,
                    meta: {
                        permission: 'category_update',
                        role: adminRoles,
                        title: 'Edit Category'
                    },
                },
                {
                    path: "manage_categories",
                    name: "manage_categories",
                    component: ManageCategories,
                    meta: {
                        permission: 'category_list',
                        role: adminRoles,
                        title: 'Categories'

                    },
                },
                {
                    path: "categories_order",
                    name: "categories_order",
                    component: CategoriesOrder,
                    meta: {
                        permission: 'manage_categories_order',
                        role: adminRoles,
                        title: 'Categories Order'

                    },
                },
                {
                    path: "products",
                    name: "ManageProducts",
                    component: Products,
                    meta: {
                        permission: 'product_list',
                        role: adminRoles,
                        title: 'Manage Products'

                    },
                },
                {
                    path: "products/create",
                    name: "Add Product",
                    component: EditProduct,
                    meta: {
                        permission: 'product_create',
                        role: adminRoles,
                        title: 'Add Product'

                    },
                },
                {
                    path: "products/edit/:id",
                    name: "EditProduct",
                    component: EditProduct,
                    props: true,
                    meta: {
                        permission: 'product_update',
                        role: adminRoles,
                        title: 'Edit Product'

                    },
                },
                {
                    // A food product's addon setup: its own page, with its own save, so a
                    // menu can be edited without re-saving the whole product.
                    path: "products/:id/addons",
                    name: "ProductAddons",
                    component: ProductAddons,
                    props: true,
                    meta: {
                        permission: 'product_update',
                        role: adminRoles,
                        title: 'Product Addons'
                    },
                },
                {
                    path: "products/view/:id",
                    name: "ViewProduct",
                    component: ViewProduct,
                    props: true,
                    meta: {
                        permission: 'product_list',
                        role: adminRoles,
                        title: 'Product View'

                    },
                },
                {
                    path: "product_ratings/view/:id",
                    name: "ProductRatings",
                    component: ProductRatings,
                    props: true,
                    meta: {
                        permission: 'product_ratings',
                        role: adminRoles,
                        title: 'Product View'

                    },
                },
                {
                    path: "products/clone/:id/:clone",
                    name: "CloneProduct",
                    component: CloneProduct,
                    props: true,
                    meta: {
                        permission: 'product_create',
                        role: adminRoles,
                        title: 'Clone Product'

                    },
                },
                {
                    path: "bulk_upload",
                    name: "BulkUpload",
                    component: ProductBulk,
                    props: { mode: 'upload' },
                    meta: {
                        permission: 'manage_product_bulk_upload',
                        role: adminRoles,
                        title: 'Bulk Upload'
                    },
                },
                {
                    path: "bulk_update",
                    name: "BulkUpdate",
                    component: ProductBulk,
                    props: { mode: 'update' },
                    meta: {
                        permission: 'manage_product_bulk_upload',
                        role: adminRoles,
                        title: 'Bulk Update'
                    },
                },
                {
                    path: "tax_categories",
                    name: "TaxCategories",
                    component: TaxCategories,
                    meta: { permission: 'tax_list', role: adminRoles, title: 'Tax Categories' },
                },
                {
                    path: "tax_rules",
                    name: "TaxRules",
                    component: TaxRules,
                    meta: { permission: 'tax_list', role: adminRoles, title: 'Tax Rules' },
                },
                {
                    path: "brands",
                    name: "Brands",
                    component: Brands,
                    meta: {
                        permission: 'brand_list',
                        role: adminRoles,
                        title: 'Brands'

                    },
                },
                {
                    path: "attributes",
                    name: "Attributes",
                    component: Attributes,
                    meta: {
                        permission: 'attribute_list',
                        role: adminRoles,
                        title: 'Attributes'
                    },
                },
                {
                    path: "manage_stock",
                    name: "Stock Management",
                    component: ManageStock,
                    meta: {
                        permission: 'stock_management',
                        role: adminRoles,
                        title: 'Stock Management'

                    },
                },
                {
                    path: "branches",
                    name: "Branches",
                    component: Branches,
                    meta: {
                        permission: 'branch_list',
                        role: adminRoles,
                        title: 'Branches'
                    },
                },
                {
                    path: "branches/create",
                    name: "CreateBranch",
                    component: EditBranch,
                    meta: {
                        permission: 'branch_create',
                        role: adminRoles,
                        title: 'Create Branch'
                    },
                },
                {
                    path: "branches/edit/:id",
                    name: "EditBranch",
                    component: EditBranch,
                    props: true,
                    meta: {
                        permission: 'branch_update',
                        role: adminRoles,
                        title: 'Edit Branch'
                    },
                },
                {
                    path: "home_builder",
                    name: "HomeBuilder",
                    component: HomeBuilder,
                    meta: {
                        permission: 'home_builder_list',
                        role: adminRoles,
                        title: 'Home Builder'
                    },
                },
                {
                    path: "home_builder/create",
                    name: "HomeBuilderCreate",
                    component: HomeBuilderEditor,
                    meta: {
                        permission: 'home_builder_create',
                        role: adminRoles,
                        title: 'New Home Layout'
                    },
                },
                {
                    path: "home_builder/edit/:id",
                    name: "HomeBuilderEdit",
                    component: HomeBuilderEditor,
                    meta: {
                        permission: 'home_builder_update',
                        role: adminRoles,
                        title: 'Edit Home Layout'
                    },
                },
                {
                    path: "page_builder",
                    name: "PageBuilder",
                    component: PageBuilder,
                    meta: {
                        permission: 'page_builder_list',
                        role: adminRoles,
                        title: 'Page Builder'
                    },
                },
                {
                    path: "page_builder/edit/:id",
                    name: "PageBuilderEdit",
                    component: PageBuilderEditor,
                    meta: {
                        permission: 'page_builder_update',
                        role: adminRoles,
                        title: 'Edit Page'
                    },
                },
                {
                    path: "promo_code/create",
                    name: "promo_code_create",
                    component: PromoCodeForm,
                    meta: {
                        permission: 'promo_code_create',
                        role: adminRoles,
                        title: 'Create Coupon'
                    },
                },
                {
                    path: "promo_code/edit/:id",
                    name: "promo_code_edit",
                    component: PromoCodeForm,
                    meta: {
                        permission: 'promo_code_update',
                        role: adminRoles,
                        title: 'Edit Coupon'
                    },
                },
                {
                    path: "promo_code",
                    name: "promo_code",
                    component: PromoCode,
                    meta: {
                        permission: 'promo_code_list',
                        role: adminRoles,
                        title: 'Promo Code'
                    },
                },
                {
                    path: "spin_wheel/create",
                    name: "spin_wheel_create",
                    component: SpinWheelForm,
                    meta: {
                        permission: 'spin_wheel_create',
                        role: adminRoles,
                        title: 'Create Spin Wheel Campaign'
                    },
                },
                {
                    path: "spin_wheel/edit/:id",
                    name: "spin_wheel_edit",
                    component: SpinWheelForm,
                    meta: {
                        permission: 'spin_wheel_update',
                        role: adminRoles,
                        title: 'Edit Spin Wheel Campaign'
                    },
                },
                {
                    path: "spin_wheel/history",
                    name: "spin_wheel_history",
                    component: SpinHistory,
                    meta: {
                        permission: 'spin_wheel_list',
                        role: adminRoles,
                        title: 'Spin History'
                    },
                },
                {
                    path: "spin_wheel",
                    name: "spin_wheel",
                    component: SpinWheel,
                    meta: {
                        permission: 'spin_wheel_list',
                        role: adminRoles,
                        title: 'Spin Wheel'
                    },
                },
                {
                    path: "settings",
                    name: "Settings",
                    component: Settings,
                    meta: {
                        permission: 'order_list',
                        role: adminRoles,
                        title: 'Settings'
                    },
                },
                {
                    path: "settings/general",
                    name: "GeneralSettings",
                    component: GeneralSettings,
                    meta: {
                        permission: 'manage_general_settings',
                        role: adminRoles,
                        title: 'General Settings',
                    },
                },
                {
                    path: "settings/app",
                    name: "AppSettings",
                    component: AppSettings,
                    meta: {
                        permission: 'manage_app_settings',
                        role: adminRoles,
                        title: 'App Settings',
                    },
                },
                {
                    path: "settings/maintenance",
                    name: "MaintenanceSettings",
                    component: MaintenanceSettings,
                    meta: {
                        permission: 'manage_general_settings',
                        role: adminRoles,
                        title: 'Maintenance Mode',
                    },
                },
                {
                    path: "settings/login",
                    name: "LoginSettings",
                    component: LoginSettings,
                    meta: {
                        permission: 'manage_login_settings',
                        role: adminRoles,
                        title: 'Login Settings',
                    },
                },
                {
                    path: "settings/invoice",
                    name: "InvoiceSettings",
                    component: InvoiceSettings,
                    meta: {
                        permission: 'manage_invoice_settings',
                        role: adminRoles,
                        title: 'Invoice Settings',
                    },
                },
                {
                    path: "settings/cart",
                    name: "CartSettings",
                    component: CartSettings,
                    meta: {
                        permission: 'manage_cart_settings',
                        role: adminRoles,
                        title: 'Cart Settings',
                    },
                },
                {
                    path: "settings/deeplink",
                    name: "DeeplinkSettings",
                    component: DeeplinkSettings,
                    meta: {
                        permission: 'manage_deeplink_settings',
                        role: adminRoles,
                        title: 'Deeplink Settings',
                    },
                },
                {
                    path: "settings/smtp",
                    name: "SmtpSettings",
                    component: SmtpSettings,
                    meta: {
                        permission: 'manage_smtp_settings',
                        role: adminRoles,
                        title: 'SMTP Mail Settings',
                    },
                },
                {
                    path: "settings/chat",
                    name: "ChatSettings",
                    component: ChatSettings,
                    meta: {
                        permission: 'manage_chat_settings',
                        role: adminRoles,
                        title: 'Chat Settings',
                    },
                },
                {
                    path: "settings/tax",
                    name: "TaxSettings",
                    component: TaxSettings,
                    meta: { permission: 'tax_list', role: adminRoles, title: 'Tax Settings' },
                },
                {
                    path: "settings/api",
                    name: "ApiCredentials",
                    component: ApiCredentials,
                    meta: {
                        permission: 'manage_api_credentials',
                        role: adminRoles,
                        title: 'API Credentials',
                    },
                },
                {
                    path: "settings/contact_us",
                    name: "Contact Us",
                    component: ContactUs,
                    meta: {
                        permission: 'manage_contact_us',
                        role: adminRoles,
                        title: 'Contact Us'

                    },
                },
                {
                    path: "settings/about_us",
                    name: "About Us",
                    component: AboutUs,
                    meta: {
                        permission: 'manage_about_us',
                        role: adminRoles,
                        title: 'About Us'

                    },
                },
                {
                    path: "settings/firebase",
                    name: "FirebaseSettings",
                    component: FirebaseSettings,
                    meta: {
                        permission: 'manage_firebase_settings',
                        role: adminRoles,
                        title: 'Firebase Settings'
                    },
                },
                {
                    path: "settings/notification_templates",
                    name: "NotificationTemplates",
                    component: NotificationTemplates,
                    meta: {
                        permission: 'manage_notification_templates',
                        role: adminRoles,
                        title: 'Notification Templates'
                    },
                },
                {
                    path: "settings/notification_settings",
                    name: "NotificationSettings",
                    component: NotificationSettings,
                    meta: {
                        permission: 'manage_notification_templates',
                        role: adminRoles,
                        title: 'Notification Settings'
                    },
                },
                {
                    path: "settings/email_templates",
                    name: "SettingsEmailTemplates",
                    component: SettingsEmailTemplates,
                    meta: {
                        permission: 'manage_email_templates',
                        role: adminRoles,
                        title: 'Email Templates'
                    },
                },
                {
                    path: "settings/sms",
                    name: "SmsSettings",
                    component: SmsSettings,
                    meta: {
                        permission: 'manage_sms_settings',
                        role: adminRoles,
                        title: 'SMS Settings'
                    },
                },
                {
                    path: "settings/sms_templates",
                    name: "SmsTemplates",
                    component: SmsTemplates,
                    meta: {
                        permission: 'manage_sms_templates',
                        role: adminRoles,
                        title: 'Sms Templates'
                    },
                },

                {
                    path: "settings/seo",
                    name: "SeoSettings",
                    component: SeoSettings,
                    meta: {
                        permission: 'manage_seo_settings',
                        role: adminRoles,
                        title: 'SEO Settings'
                    },
                },

                {
                    path: "notifications",
                    name: "SendNotifications",
                    component: Notifications,
                    meta: {
                        permission: 'notification_list',
                        role: adminRoles,
                        title: 'Manage Notifications'

                    },
                },
                {
                    path: "emails/:create",
                    name: "SendEmails_create",
                    component: Emails,
                    meta: {
                        permission: 'manage_emails',
                        role: adminRoles,
                        title: 'Send Email'

                    },
                },
                {
                    path: "emails",
                    name: "SendEmails",
                    component: Emails,
                    meta: {
                        permission: 'manage_emails',
                        role: adminRoles,
                        title: 'Manage Emails'

                    },
                },
                {
                    path: "popup",
                    name: "PopupOffer",
                    component: PopupOffer,
                    meta: {
                        permission: 'popup_offer_update',
                        role: adminRoles,
                        title: 'Popup Offer'
                    },
                },
                {
                    path: "delivery_boys/create",
                    name: "CreateDeliveryBoy",
                    component: EditDeliveryBoy,
                    meta: {
                        permission: 'delivery_boy_create',
                        role: adminRoles,
                        title: 'Create Delivery Boy'

                    },
                },
                {
                    path: "delivery_boys/view/:id",
                    name: "ViewDeliveryBoy",
                    component: ViewDeliveryBoy,
                    props: true,
                    meta: {
                        permission: 'delivery_boy_list',
                        role: adminRoles,
                        title: 'Delivery Boy View'

                    },
                },
                {
                    path: "delivery_boys/edit/:id",
                    name: "EditDeliveryBoy",
                    component: EditDeliveryBoy,
                    props: true,
                    meta: {
                        permission: 'delivery_boy_update',
                        role: adminRoles,
                        title: 'Edit Delivery Boy'

                    },
                },
                {
                    path: "registered_delivery_boys",
                    name: "RegisteredDeliveryBoys",
                    component: RegisteredDeliveryBoys,
                    meta: {
                        permission: 'delivery_boy_list',
                        role: adminRoles,
                        title: 'Delivery Boys'

                    },
                },
                {
                    path: "delivery_boys",
                    name: "DeliveryBoys",
                    component: DeliveryBoys,
                    meta: {
                        permission: 'delivery_boy_list',
                        role: adminRoles,
                        title: 'Delivery Boys'

                    },
                },
                {
                    path: "settlement_history",
                    name: "Settlement History",
                    component: DeliveryBoySettlementHistory,
                    meta: {
                        permission: 'delivery_boy_wallet_transactions_list',
                        role: adminRoles,
                        title: 'Settlement History'

                    },
                },
                {
                    path: "salary_transactions",
                    name: "SalaryTransactions",
                    component: SalaryTransactions,
                    meta: {
                        permission: 'delivery_boy_salary_list',
                        role: adminRoles,
                        title: 'Salary Transactions'
                    },
                },
                {
                    path: "cash_collection",
                    name: "Delivery boy cash",
                    component: CashCollection,
                    meta: {
                        permission: 'cash_collection_list',
                        role: adminRoles,
                        title: 'Delivery boy cash'

                    },
                },
                {
                    path: "settings/website",
                    name: "WebsiteSettings",
                    component: WebsiteSettings,
                    meta: {
                        permission: 'manage_website_settings',
                        role: adminRoles,
                        title: 'Website Settings'

                    },
                },
                {
                    path: "blog_categories",
                    name: "Blog Categories",
                    component: BlogCategories,
                    meta: {
                        permission: 'blog_category_list',
                        role: adminRoles,
                        title: 'Blog Categories'
                    },
                },
                {
                    path: "blogs",
                    name: "Blogs",
                    component: Blogs,
                    meta: {
                        permission: 'blog_list',
                        role: adminRoles,
                        title: 'Blogs'
                    },
                },
                {
                    path: "settings/social_media",
                    name: "SocialMedia",
                    component: SocialMedia,
                    meta: {
                        permission: 'manage_social_media',
                        role: adminRoles,
                        title: 'Social Media'

                    },
                },
                {
                    path: "users",
                    name: "Customers",
                    component: Customers,
                    meta: {
                        permission: 'customer_list',
                        role: adminRoles,
                        title: 'Customers'

                    },
                },
                {
                    path: "users/view/:id",
                    name: "ViewCustomer",
                    component: ViewCustomer,
                    meta: {
                        permission: 'customer_list',
                        role: adminRoles,
                        title: 'Customer View'
                    },
                },
                {
                    path: "wishlists",
                    name: "Wishlists",
                    component: Wishlists,
                    meta: {
                        permission: 'manage_wishlists',
                        role: adminRoles,
                        title: 'Wishlists'

                    },
                },
                {
                    path: "stock_alerts",
                    name: "StockAlerts",
                    component: StockAlerts,
                    meta: {
                        permission: 'manage_stock_alerts',
                        role: adminRoles,
                        title: 'Stock Alerts'
                    },
                },
                {
                    path: "carts",
                    name: "Carts",
                    component: Carts,
                    meta: {
                        permission: 'manage_carts',
                        role: adminRoles,
                        title: 'Carts'
                    },
                },
                {
                    path: "transactions",
                    name: "Transactions",
                    component: Transactions,
                    meta: {
                        permission: 'transaction_list',
                        role: adminRoles,
                        title: 'Transactions'

                    },
                },
                {
                    path: "wallet_transactions",
                    name: "Manage Customer Wallet",
                    component: WalletTransactions,
                    meta: {
                        permission: 'manage_customer_wallet',
                        role: adminRoles,
                        title: 'Manage Customer Wallet'

                    },
                },
                {
                    path: "withdrawal_requests",
                    name: "Withdrawal Requests",
                    component: WithdrawalRequests,
                    meta: {
                        permission: 'withdrawal_request_list',
                        role: adminRoles,
                        title: 'Withdrawal Requests'

                    },
                },
                {
                    path: "return_requests",
                    name: "Return Requests",
                    component: ReturnRequests,
                    meta: {
                        permission: 'return_request_list',
                        role: adminRoles,
                        title: 'Return Requests'

                    },
                },
                {
                    path: "reports/sales",
                    name: "ReportSales",
                    component: ReportPage,
                    props: { type: "sales" },
                    meta: {
                        permission: 'report_sales',
                        role: adminRoles,
                        title: 'Sales Report'
                    },
                },
                {
                    path: "reports/orders",
                    name: "ReportOrders",
                    component: ReportPage,
                    props: { type: "orders" },
                    meta: {
                        permission: 'report_orders',
                        role: adminRoles,
                        title: 'Orders Report'
                    },
                },
                {
                    path: "reports/products",
                    name: "ReportProducts",
                    component: ReportPage,
                    props: { type: "products" },
                    meta: {
                        permission: 'report_products',
                        role: adminRoles,
                        title: 'Products Report'
                    },
                },
                {
                    path: "reports/customers",
                    name: "ReportCustomers",
                    component: ReportPage,
                    props: { type: "customers" },
                    meta: {
                        permission: 'report_customers',
                        role: adminRoles,
                        title: 'Customers Report'
                    },
                },
                {
                    path: "reports/inventory",
                    name: "ReportInventory",
                    component: ReportPage,
                    props: { type: "inventory" },
                    meta: {
                        permission: 'report_inventory',
                        role: adminRoles,
                        title: 'Inventory Report'
                    },
                },
                {
                    path: "reports/returns",
                    name: "ReportReturns",
                    component: ReportPage,
                    props: { type: "returns" },
                    meta: {
                        permission: 'report_returns',
                        role: adminRoles,
                        title: 'Returns Report'
                    },
                },
                {
                    path: "reports/delivery",
                    name: "ReportDelivery",
                    component: ReportPage,
                    props: { type: "delivery" },
                    meta: {
                        permission: 'report_delivery',
                        role: adminRoles,
                        title: 'Delivery Report'
                    },
                },
                {
                    path: "reports/payment",
                    name: "ReportPayment",
                    component: ReportPage,
                    props: { type: "payment" },
                    meta: {
                        permission: 'report_payment',
                        role: adminRoles,
                        title: 'Payment Report'
                    },
                },
                {
                    path: "reports/category",
                    name: "ReportCategory",
                    component: ReportPage,
                    props: { type: "category" },
                    meta: {
                        permission: 'report_category',
                        role: adminRoles,
                        title: 'Category Report'
                    },
                },
                {
                    path: "reports/promo",
                    name: "ReportPromo",
                    component: ReportPage,
                    props: { type: "promo" },
                    meta: {
                        permission: 'report_promo',
                        role: adminRoles,
                        title: 'Promo Report'
                    },
                },
                {
                    path: "reports/tax",
                    name: "ReportTax",
                    component: ReportPage,
                    props: { type: "tax" },
                    meta: {
                        permission: 'report_tax',
                        role: adminRoles,
                        title: 'Tax Report'
                    },
                },
                {
                    path: "reports/tax_orders",
                    name: "ReportTaxOrders",
                    component: ReportPage,
                    props: { type: "tax_orders" },
                    meta: {
                        permission: 'report_tax_orders',
                        role: adminRoles,
                        title: 'Order-wise Tax Report'
                    },
                },
                {
                    path: "system_users",
                    name: "System Users",
                    component: SystemUsers,
                    meta: {
                        permission: 'manage_general_settings',
                        role: adminRoles,
                        title: 'System Users'
                    },
                },
                {
                    path: "role",
                    name: "Role",
                    component: Role,
                    meta: {
                        permission: 'manage_general_settings',
                        role: adminRoles,
                        title: 'Role'
                    },
                },
                {
                    path: "branch_users",
                    name: "Branch Users",
                    component: BranchUsers,
                    meta: { permission: 'branch_user_manage', title: 'Branch Users' },
                },
                {
                    path: "branch_roles",
                    name: "Branch Roles",
                    component: BranchRoles,
                    meta: { permission: 'branch_role_manage', title: 'Branch Roles' },
                },
                {
                    path: "branch/profile",
                    name: "BranchProfile",
                    component: EditBranch,
                    meta: { title: 'My Profile', branchProfile: true },
                },
                {
                    path: "branch/account_settings",
                    name: "BranchAccountSettings",
                    component: AccountSettings,
                    meta: { title: 'Settings' },
                },
                {
                    path: "media",
                    name: "Media",
                    component: Media,
                    meta: {
                        permission: 'manage_media',
                        role: adminRoles,
                        title: 'Media'
                    },
                },
                {
                    path: "/account_settings",
                    name: "AccountSettings",
                    component: AccountSettings,
                    meta: {
                        title: 'Account Settings'
                    },
                },
                {
                    path: "product_ratings",
                    name: "Product Ratings",
                    component: ProductRatings,
                    meta: {
                        permission: 'product_ratings',
                        role: adminRoles,
                        title: 'Product Ratings'
                    },
                },
                {
                    path: "setup_guide",
                    name: "SetupGuide",
                    component: SetupGuide,
                    meta: {
                        role: adminRoles,
                        title: 'Setup Guide'
                    },
                },
                {
                    path: "shipments",
                    name: "Shipments",
                    component: Shipments,
                    meta: {
                        permission: 'order_list',
                        role: adminRoles,
                        title: 'Shipments'
                    },
                },
                {
                    path: "plugins",
                    name: "Plugins",
                    component: Plugins,
                    meta: {
                        permission: 'manage_plugins',
                        role: adminRoles,
                        title: 'Plugins'
                    },
                },
                {
                    path: "plugins/:slug",
                    name: "PluginSettings",
                    component: PluginSettings,
                    meta: {
                        permission: 'manage_plugins',
                        role: adminRoles,
                        title: 'Plugin Settings'
                    },
                },
                {
                    path: "settings/system_updater",
                    name: "SystemUpdater",
                    component: SystemUpdater,
                    meta: {
                        permission: 'manage_system_updater',
                        role: adminRoles,
                        title: 'System Updater'
                    },
                },
                {
                    path: "settings/activity_logs",
                    name: "ActivityLogs",
                    component: ActivityLogs,
                    meta: {
                        permission: 'manage_activity_logs',
                        role: adminRoles,
                        title: 'Activity Logs'
                    },
                },
                {
                    path: "settings/cron_jobs",
                    name: "CronJobs",
                    component: CronJobs,
                    meta: {
                        permission: 'manage_cron_jobs',
                        role: adminRoles,
                        title: 'Cron Jobs'
                    },
                },
                {
                    path: "zones",
                    name: "Zones",
                    component: Zones,
                    meta: {
                        permission: 'zone_list',
                        role: adminRoles,
                        title: 'Zones'
                    },
                },
                {
                    path: "zones/create",
                    name: "AddZone",
                    component: EditZone,
                    meta: {
                        permission: 'zone_create',
                        role: adminRoles,
                        title: 'Create Zone'
                    },
                },
                {
                    path: "zones/edit/:id",
                    name: "EditZone",
                    component: EditZone,
                    meta: {
                        permission: 'zone_update',
                        role: adminRoles,
                        title: 'Edit Zone'
                    },
                },
                {
                    path: "delivery_cities",
                    name: "DeliveryCities",
                    component: DeliveryCities,
                    meta: {
                        permission: 'delivery_city_list',
                        role: adminRoles,
                        title: 'Delivery Cities'
                    },
                },
                {
                    path: "delivery_areas",
                    name: "DeliveryAreas",
                    component: DeliveryAreas,
                    meta: {
                        permission: 'delivery_area_list',
                        role: adminRoles,
                        title: 'Delivery Areas'
                    },
                },
                {
                    path: "faqs",
                    name: "FAQs",
                    component: Faqs,
                    meta: {
                        permission: 'faq_list',
                        role: adminRoles,
                        title: 'FAQs'

                    },
                },
                {
                    path: "languages/:create",
                    name: "languages_create",
                    component: Languages,
                    meta: {
                        permission: 'language_create',
                        role: adminRoles,
                        title: 'Languages'

                    },
                },
                {
                    path: "languages",
                    name: "languages",
                    component: Languages,
                    meta: {
                        permission: 'language_list',
                        role: adminRoles,
                        title: 'Languages'
                    },
                },
                {
                    path: "countries/edit/:id",
                    name: "countries_edit",
                    component: CountryForm,
                    meta: { permission: 'country_update', role: adminRoles, title: 'Countries' },
                },
                {
                    path: "countries/:id/regions",
                    name: "countries_regions",
                    component: Regions,
                    meta: { permission: 'country_update', role: adminRoles, title: 'Regions' },
                },
                {
                    path: "countries",
                    name: "countries",
                    component: Countries,
                    meta: {
                        permission: 'country_list',
                        role: adminRoles,
                        title: 'Countries'
                    },
                },
            ],
        },
        {

            path: "/delivery_boy",
            // name: "delivery_boy",
            component: TheContainerDeliveryBoy,
            children: [
                {
                    path: "",
                    name: "DeliveryBoyDashboard",
                    component: DeliveryBoyDashboard,
                    meta: {
                        requiresAuth: true,
                        role: deliveryBoyRoles,
                        title: 'Dashboard'
                    },
                },
                {
                    path: "dashboard",
                    name: "deliveryBoy_dashboard",
                    component: DeliveryBoyDashboard,
                    meta: {
                        requiresAuth: true,
                        role: deliveryBoyRoles,
                        title: 'Dashboard'
                    },
                },

                {
                    path: "orders",
                    name: "DeliveryBoyOrders",
                    component: DeliveryBoyOrders,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'Orders'
                    },
                },
                {
                    path: "chat",
                    name: "DeliveryBoyChat",
                    component: DeliveryBoyChat,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'Chat'
                    },
                },
                {
                    path: "return_requests",
                    name: "DeliveryBoyReturnRequests",
                    component: DeliveryBoyReturnRequests,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'Return Requests'
                    },
                },
                {
                    path: "/delivery_boy/withdrawal_requests",
                    name: "DeliveryBoyWithdrawalRequests",
                    component: DeliveryBoyWithdrawalRequests,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'Withdrawal Requests'
                    },
                },
                {
                    path: "settlement_history",
                    name: "DeliveryBoySettlementHistory",
                    component: DeliveryBoySettlementHistoryPanel,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'Fund Transfers'
                    },
                },
                {
                    path: "cash_collection",
                    name: "DeliveryBoyCashCollection",
                    component: DeliveryBoyCashCollection,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'Delivery boy cash'
                    },
                },
                {
                    path: "salary_transactions",
                    name: "DeliveryBoySalaryTransactions",
                    component: DeliveryBoySalaryTransactions,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'Salary Transactions'
                    },
                },
                {
                    path: "account_settings",
                    name: "DeliverySettings",
                    component: DeliverySettings,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'Settings'
                    },
                },
                {
                    path: "profile",
                    name: "DeliveryProfile",
                    component: DeliveryProfile,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'My Profile'
                    },
                },
                {
                    path: "products/view/:id",
                    name: "DeliveryBoyViewProduct",
                    component: DeliveryBoyViewProduct,
                    props: true,
                    meta: {
                        permission: 'order_list',
                        role: deliveryBoyRoles,
                        title: 'Product View'
                    },
                },
                {
                    path: "notification_panel",
                    name: "DeliveryBoyNotificationPanel",
                    component: NotificationPanel,
                    meta: {
                        role: deliveryBoyRoles,
                        title: 'Notifications'
                    },
                },
            ],
        },

        {
            path: "/login",
            name: "login",
            component: Login,
            meta: {
                title: 'Login'
            },
        },
        {
            path: "/delivery_boy/login",
            name: "delivery_boy_login",
            component: DeliveryBoyLogin,
            meta: {
                title: 'Delivery Boy Login'
            },
        },
        {
            path: "/branch/login",
            name: "branch_login",
            component: BranchLogin,
            meta: {
                title: 'Branch Login'
            },
        },
        {
            path: "/delivery_boy/register",
            name: "delivery_boy_register",
            component: DeliveryBoyRegister,
            meta: {
                title: 'Delivery Boy Register'
            },
        },
        {
            path: "/forgot-password",
            name: "forgot_password",
            component: ForgotPassword,
            meta: {
                title: 'Forgot Password'
            },
        },
        {
            path: "/reset-password",
            name: "reset_password",
            component: ResetPassword,
            meta: {
                title: 'Reset Password'
            },
        },

        /*Other Pages*/

        { path: "/error_500", component: ServerError, meta: { title: 'Server Error' } },
        { path: "/:pathMatch(.*)*", name: "NotFound", component: PageNotFound, meta: { title: '404 Page Not Found' } }

    ];
}

