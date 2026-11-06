import { markRaw } from 'vue';
import {
    Store as BranchIcon, LogIn, ShoppingCart, Smartphone, Link2, Mail, MessagesSquare,
    KeyRound, Globe, Share2, Search, FileText, Phone, Languages,
    Bell, BellRing, MessageSquareText, RefreshCw, Clock, ScrollText, Wrench,
    Percent, ReceiptText, Puzzle,
} from 'lucide-vue-next';

/**
 * The Settings hub, in one place.
 *
 * The hub page renders it as cards and the global search indexes it, so a card
 * added here shows up in both. Labels go through __(), so this must be called at
 * render time rather than evaluated on import.
 */
export function settingsGroups() {
    return [
                {
                    title: __('general'),
                    items: [
                        {
                            title: __('general_settings'), desc: __('store_identity_address_and_branding'),
                            icon: markRaw(BranchIcon), tone: 'primary', permission: 'manage_general_settings',
                            to: '/settings/general',
                            keywords: 'logo favicon app name business address branch address map link support email support number copyright theme colour color currency order prefix invoice prefix rating cart items',
                        },
                        {
                            title: __('login_setting'), desc: __('how_customers_sign_in_and_register'),
                            icon: markRaw(LogIn), tone: 'violet', permission: 'manage_login_settings',
                            to: '/settings/login',
                            keywords: 'phone login google apple email otp firebase password policy minimum length uppercase special',
                        },
                        {
                            title: __('cart_setting'), desc: __('cart_rules_and_reminder_notifications'),
                            icon: markRaw(ShoppingCart), tone: 'amber', permission: 'manage_cart_settings',
                            to: '/settings/cart',
                            keywords: 'abandoned cart reminder notification delay interval stop time',
                        },
                        {
                            // Lives at /languages, not /settings/languages — the route
                            // predates the hub and is linked to from elsewhere.
                            title: __('languages'), desc: __('panel_and_app_languages'),
                            icon: markRaw(Languages), tone: 'violet', permission: 'language_list',
                            to: '/languages',
                            keywords: 'language translation locale rtl json panel app website labels',
                        },
                        {
                            title: __('tax_settings'), desc: __('tax_settings_hint'),
                            icon: markRaw(Percent), tone: 'primary', permission: 'tax_list',
                            to: '/settings/tax',
                            keywords: 'tax category gst vat rule rate region inclusive exclusive hsn',
                        },
                        {
                            title: __('invoice_settings'), desc: __('invoice_settings_hint'),
                            icon: markRaw(ReceiptText), tone: 'amber', permission: 'manage_invoice_settings',
                            to: '/settings/invoice',
                            keywords: 'invoice receipt paper size a4 a5 letter thermal 80mm 58mm roll custom font bold colour logo signature header note footer note thank you tax summary delivery receipt products prices print pdf',
                        },
                    ],
                },
                {
                    title: __('communication'),
                    items: [
                        {
                            title: __('notification_settings'), desc: __('notification_settings_desc'),
                            icon: markRaw(BellRing), tone: 'primary', permission: 'manage_notification_templates',
                            to: '/settings/notification_settings',
                            keywords: 'notification channel toggle push mail sms customer delivery boy admin events',
                        },
                        {
                            title: __('smtp_mail_setting'), desc: __('outgoing_mail_server_credentials'),
                            icon: markRaw(Mail), tone: 'primary', permission: 'manage_smtp_settings',
                            to: '/settings/smtp',
                            keywords: 'smtp mail server host port encryption username password from mail test mail',
                        },
                        {
                            title: __('chat_setting'), desc: __('realtime_chat_broadcast_driver'),
                            icon: markRaw(MessagesSquare), tone: 'green', permission: 'manage_chat_settings',
                            to: '/settings/chat',
                            keywords: 'chat pusher reverb realtime broadcast driver app key cluster',
                        },
                        {
                            title: __('firebase_settings'), desc: __('push_notification_credentials'),
                            icon: markRaw(Bell), tone: 'amber', permission: 'manage_firebase_settings',
                            to: '/settings/firebase',
                            keywords: 'firebase push fcm service account json project id web api key vapid',
                        },
                        {
                            title: __('notification_templates'), desc: __('push_notification_message_templates'),
                            icon: markRaw(MessageSquareText), tone: 'violet', permission: 'manage_notification_templates',
                            to: '/settings/notification_templates',
                            keywords: 'push template title message placeholders order status wallet',
                        },
                        {
                            title: __('sms_settings'), desc: __('sms_gateway_credentials'),
                            icon: markRaw(Phone), tone: 'cyan', permission: 'manage_sms_settings',
                            to: '/settings/sms',
                            keywords: 'sms gateway twilio msg91 otp sender id credentials',
                        },
                        {
                            title: __('sms_templates'), desc: __('sms_message_templates'),
                            icon: markRaw(MessageSquareText), tone: 'slate', permission: 'manage_sms_templates',
                            to: '/settings/sms_templates',
                            keywords: 'sms template message placeholders otp order status',
                        },
                        {
                            title: __('email_templates'), desc: __('email_message_templates'),
                            icon: markRaw(Mail), tone: 'teal', permission: 'manage_email_templates',
                            to: '/settings/email_templates',
                            keywords: 'email template subject body html placeholders order invoice welcome',
                        },
                    ],
                },
                {
                    // Website and the mobile apps are one "customer-facing channels" group.
                    title: __('website_and_apps'),
                    items: [
                        {
                            title: __('website_settings'), desc: __('storefront_appearance_and_behaviour'),
                            icon: markRaw(Globe), tone: 'primary', permission: 'manage_website_settings',
                            to: '/settings/website',
                            keywords: 'website storefront banner theme homepage web appearance',
                        },
                        {
                            title: __('app_setting'), desc: __('customer_and_delivery_app_options'),
                            icon: markRaw(Smartphone), tone: 'violet', permission: 'manage_app_settings',
                            to: '/settings/app',
                            keywords: 'app version force update customer app delivery boy app android ios theme colour',
                        },
                        {
                            title: __('deeplink_setting'), desc: __('app_store_urls_and_deeplink_schema'),
                            icon: markRaw(Link2), tone: 'slate', permission: 'manage_deeplink_settings',
                            to: '/settings/deeplink',
                            keywords: 'deeplink playstore appstore url schema share link',
                        },
                        {
                            title: __('social_media'), desc: __('social_profile_links'),
                            icon: markRaw(Share2), tone: 'cyan', permission: 'manage_social_media',
                            to: '/settings/social_media',
                            keywords: 'facebook instagram twitter youtube linkedin social links',
                        },
                        {
                            title: __('seo_settings'), desc: __('page_titles_meta_and_keywords'),
                            icon: markRaw(Search), tone: 'green', permission: 'manage_seo_settings',
                            to: '/settings/seo',
                            keywords: 'seo meta title description keywords og image sitemap',
                        },
                        {
                            title: __('about_us'), desc: __('about_us_page_content'),
                            icon: markRaw(FileText), tone: 'violet', permission: 'manage_about_us',
                            to: '/settings/about_us',
                            keywords: 'about us page content editor',
                        },
                        {
                            title: __('contact_us'), desc: __('contact_page_content'),
                            icon: markRaw(FileText), tone: 'amber', permission: 'manage_contact_us',
                            to: '/settings/contact_us',
                            keywords: 'contact us page content address phone email',
                        },
                        {
                            title: __('maintenance_mode'), desc: __('maintenance_mode_desc'),
                            icon: markRaw(Wrench), tone: 'amber', permission: 'manage_app_settings',
                            to: '/settings/maintenance',
                            keywords: 'maintenance mode downtime message app website',
                        },
                    ],
                },
                {
                    title: __('advanced'),
                    items: [
                        {
                            title: __('third_party_api_credentials'), desc: __('maps_payments_and_other_api_keys'),
                            icon: markRaw(KeyRound), tone: 'slate', permission: 'manage_api_credentials',
                            to: '/settings/api',
                            keywords: 'google maps api key places geocoding gemini payment gateway keys osm',
                        },
                        {
                            title: __('activity_logs'), desc: __('audit_trail_of_changes_and_logins'),
                            icon: markRaw(ScrollText), tone: 'slate', permission: 'manage_activity_logs',
                            to: '/settings/activity_logs',
                            keywords: 'activity log audit trail history who changed login',
                        },
                        {
                            title: __('cron_jobs'), desc: __('scheduled_tasks_and_queue_setup'),
                            icon: markRaw(Clock), tone: 'amber', permission: 'manage_cron_jobs',
                            to: '/settings/cron_jobs',
                            keywords: 'cron job schedule queue worker command url',
                        },
                        {
                            title: __('plugins'), desc: __('plugins_hint'),
                            icon: markRaw(Puzzle), tone: 'violet', permission: 'manage_plugins',
                            to: '/plugins',
                            keywords: 'plugin plugin extension install zip purchase code licence license shiprocket payu shipping payment gateway sms enable disable uninstall',
                        },
                        {
                            title: __('system_updater'), desc: __('install_the_latest_version'),
                            icon: markRaw(RefreshCw), tone: 'primary', permission: 'manage_system_updater',
                            to: '/settings/system_updater',
                            keywords: 'update version upgrade purchase code zip patch',
                        },
                    ],
                },
    ];
}
