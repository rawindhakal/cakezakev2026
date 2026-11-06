<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Seeds notification_templates and notification_template_translations (default language).
 * Templates use {{placeholder}} syntax. placeholders column lists keys for reference.
 * Translation table is used when sending FCM; seeding with default lang avoids empty content on first run.
 * Source: CommonHelper::sendNotificationOrderStatus, sendNotificationOrderAssignDeliveryBoy,
 * sendReturnRequestNotification;
 * CommonHelper::SendCartNotification. (Panel push templates removed; OrderNotification is database-only.)
 */
class NotificationTemplatesSeeder extends Seeder
{
    /** Order statuses id => slug (matches config/notifications.php). */
    public const ORDER_STATUSES = [
        'payment_pending', 'received', 'processed', 'shipped', 'out_for_delivery',
        'delivered', 'cancelled', 'returned', 'preparing', 'ready_for_pickup', 'picked_up',
    ];

    /** Return statuses slug list. */
    public const RETURN_STATUSES = [
        'return_requested', 'accepted', 'rejected', 'delivery_boy_assigned',
        'out_for_pickup', 'received_from_customer', 'return_to_branch', 'refund_completed',
    ];

    /** Return statuses the delivery boy is involved in. */
    public const RETURN_DB_STATUSES = ['delivery_boy_assigned', 'out_for_pickup', 'received_from_customer', 'return_to_branch'];

    /** Build one PUSH template row per order/return status × audience. */
    public static function statusPushTemplates(): array
    {
        $rows = [];
        foreach (self::ORDER_STATUSES as $slug) {
            // "Ready for pickup" is read by a rider on a delivery order and by the customer on a
            // self-pickup order, so its default names the branch — right either way.
            $rows[] = [
                'type' => "order_status_{$slug}_customer",
                'title' => 'Your order #{{order_id}} has been {{status_name}}',
                'message' => $slug === 'ready_for_pickup'
                    ? 'Your order #{{order_id}} is {{status_name}} at {{branch_name}}, {{branch_address}}.'
                    : 'Your order #{{order_id}} is now {{status_name}}. Thank you for shopping with {{app_name}}.',
                'placeholders' => json_encode(['order_id', 'status_name', 'app_name', 'currency', 'final_total', 'branch_name', 'branch_address']),
            ];
            $rows[] = [
                'type' => "order_status_{$slug}_delivery_boy",
                'title' => 'Order #{{order_id}} is now {{status_name}}',
                'message' => 'Order #{{order_id}} status has been updated to {{status_name}}.',
                'placeholders' => json_encode(['order_id', 'status_name', 'delivery_boy_name']),
            ];
            $rows[] = [
                'type' => "order_status_{$slug}_admin",
                'title' => 'Order #{{order_id}} is now {{status_name}}',
                'message' => 'Order #{{order_id}} status has been updated to {{status_name}}.',
                'placeholders' => json_encode(['order_id', 'status_name']),
            ];
        }
        foreach (self::RETURN_STATUSES as $slug) {
            $rows[] = [
                'type' => "return_status_{$slug}_customer",
                'title' => 'Your return request has been {{status_name}}',
                'message' => 'Your return request for order #{{order_id}} is now {{status_name}}. Thank you for using {{app_name}}.',
                'placeholders' => json_encode(['return_request_id', 'order_id', 'status_name', 'app_name']),
            ];
            if (in_array($slug, self::RETURN_DB_STATUSES, true)) {
                $rows[] = [
                    'type' => "return_status_{$slug}_delivery_boy",
                    'title' => 'Return request is now {{status_name}}',
                    'message' => 'A return request for order #{{order_id}} is now {{status_name}}.',
                    'placeholders' => json_encode(['return_request_id', 'order_id', 'status_name']),
                ];
            }
            if ($slug === 'return_requested') {
                $rows[] = [
                    'type' => "return_status_{$slug}_admin",
                    'title' => 'New return request for order #{{order_id}}',
                    'message' => 'A new return request has been raised for order #{{order_id}}.',
                    'placeholders' => json_encode(['return_request_id', 'order_id']),
                ];
            }
        }
        return $rows;
    }

    public function run(): void
    {
        // Default language for translation rows (same as used when language_id is null at send time)
        $defaultLangId = 1;
        if (Schema::hasTable('languages')) {
            $defaultLangId = (int) (DB::table('languages')->where('system_type', 4)->where('is_default', 1)->value('id') ?? 1);
        }

        // Per-status push templates (one row per order/return status × audience).
        $statusTemplates = self::statusPushTemplates();

        $templates = [
            // --- Order assigned to delivery boy (CommonHelper::sendNotificationOrderAssignDeliveryBoy) ---
            [
                'type'        => 'assign_order_delivery_boy',
                'title'       => 'Order #{{order_id}} has been assigned to you for delivery.',
                'message'     => '',
                'placeholders' => json_encode(['order_id']),
            ],
            // --- Order assigned – notify customer (same flow; template for app user) ---
            [
                'type'        => 'assign_order_customer',
                'title'       => 'Your order #{{order_id}} has been assigned to {{delivery_boy_name}} for delivery.',
                'message'     => 'A delivery partner has been assigned to your order. You can track the order in the app.',
                'placeholders' => json_encode(['order_id', 'delivery_boy_name']),
            ],
            // --- Order item returned (customer) ---
            [
                'type'        => 'order_item_returned_customer',
                'title'       => '{{product_name}} has been returned',
                'message'     => '{{product_name}} in your order #{{order_id}} has been returned. - {{app_name}}',
                'placeholders' => json_encode(['order_id', 'product_name', 'app_name']),
            ],
            // --- Chat message (ChatService::notify) — per audience ---
            [
                'type'        => 'chat_message_customer',
                'title'       => '{{sender_name}}',
                'message'     => '{{message}}',
                'placeholders' => json_encode(['sender_name', 'message']),
            ],
            [
                'type'        => 'chat_message_delivery_boy',
                'title'       => '{{sender_name}}',
                'message'     => '{{message}}',
                'placeholders' => json_encode(['sender_name', 'message']),
            ],
            [
                'type'        => 'chat_message_admin',
                'title'       => '{{sender_name}}',
                'message'     => '{{message}}',
                'placeholders' => json_encode(['sender_name', 'message']),
            ],
            // --- Back in stock (SendBackInStockNotification job) ---
            [
                'type'        => 'back_in_stock_customer',
                'title'       => '{{product_name}} is back in stock!',
                'message'     => '{{product_name}} ({{variant_name}}) is available again at {{currency}}{{price}}. Grab it before it sells out.',
                'placeholders' => json_encode(['app_name', 'customer_name', 'product_name', 'variant_name', 'price', 'currency']),
            ],

            // --- App version update (SendAppVersionUpdateNotification job) ---
            [
                'type'        => 'app_version_update_customer',
                'title'       => 'Update {{app_name}} to {{version}}',
                'message'     => 'A new {{platform}} version of {{app_name}} ({{version}}) is available. Update now for the latest features and fixes.',
                'placeholders' => json_encode(['app_name', 'customer_name', 'version', 'platform', 'store_url']),
            ],
            [
                'type'        => 'app_version_update_delivery_boy',
                'title'       => 'Update {{app_name}} to {{version}}',
                'message'     => 'A new {{platform}} version of {{app_name}} ({{version}}) is available. Update now to keep taking orders.',
                'placeholders' => json_encode(['app_name', 'delivery_boy_name', 'version', 'platform', 'store_url']),
            ],

            // --- Cart reminder (CommonHelper::SendCartNotification) ---
            [
                'type'        => 'cart_reminder_first_customer',
                'title'       => 'Hi, your cart with {{product_name}} is waiting for you!',
                'message'     => 'Don\'t forget to complete your purchase and place your order today!',
                'placeholders' => json_encode(['product_name']),
            ],
            [
                'type'        => 'cart_reminder_interval_customer',
                'title'       => 'Title for product {{product_name}}',
                'message'     => 'You still have {{product_name}} in your cart. Complete your order now and don\'t miss out!',
                'placeholders' => json_encode(['product_name']),
            ],

            // --- Account ---
            [
                'type'        => 'account_status_customer',
                'title'       => 'Your account is {{status_name}}',
                'message'     => 'Your {{app_name}} account is now {{status_name}}.',
                'placeholders' => json_encode(['customer_name', 'status_name', 'app_name']),
            ],
            [
                'type'        => 'account_status_delivery_boy',
                'title'       => 'Your account is {{status_name}}',
                'message'     => 'Your {{app_name}} delivery partner account is now {{status_name}}.',
                'placeholders' => json_encode(['delivery_boy_name', 'status_name', 'app_name']),
            ],
            [
                'type'        => 'welcome_customer',
                'title'       => 'Welcome to {{app_name}}!',
                'message'     => 'Hi {{customer_name}}, welcome to {{app_name}}! Start exploring and enjoy shopping with us.',
                'placeholders' => json_encode(['customer_name', 'app_name']),
            ],
            [
                'type'        => 'password_changed_customer',
                'title'       => 'Password changed',
                'message'     => 'Your {{app_name}} account password was just changed. If this wasn\'t you, contact support immediately.',
                'placeholders' => json_encode(['customer_name', 'app_name']),
            ],
            [
                'type'        => 'payment_failed_customer',
                'title'       => 'Payment failed for order #{{order_id}}',
                'message'     => 'Your payment of {{currency}}{{amount}} for order #{{order_id}} failed and the order was cancelled. Please try again.',
                'placeholders' => json_encode(['customer_name', 'order_id', 'amount', 'currency', 'app_name']),
            ],
            [
                'type'        => 'salary_paid_delivery_boy',
                'title'       => 'Salary paid',
                'message'     => 'A salary payment of {{currency}}{{amount}} was recorded on {{paid_on}}.',
                'placeholders' => json_encode(['delivery_boy_name', 'amount', 'currency', 'paid_on', 'note', 'app_name']),
            ],
            // --- Promotions ---
            [
                'type'        => 'promo_code_customer',
                'title'       => 'New offer — use code {{promo_code}}',
                'message'     => '{{message}} Use code {{promo_code}} to get {{discount}} off. Valid till {{expiry_date}}.',
                'placeholders' => json_encode(['customer_name', 'promo_code', 'discount', 'message', 'expiry_date', 'app_name']),
            ],
            [
                'type'        => 'new_blog_customer',
                'title'       => '{{blog_title}}',
                'message'     => 'We just published a new post: {{blog_title}}. Read it now on {{app_name}}.',
                'placeholders' => json_encode(['customer_name', 'blog_title', 'blog_url', 'app_name']),
            ],

            // --- Ecommerce item-wise status (CommonHelper::sendNotificationOrderStatus) ---
            // Ecommerce tracks status per ITEM, so the customer needs to know WHICH item
            // moved — the order-level template above can't say that.
            [
                'type'        => 'order_item_status_customer',
                'title'       => '{{product_name}} is now {{status_name}}',
                'message'     => '{{product_name}} (x{{quantity}}) in your order #{{order_id}} has been {{status_name}}. Thank you for shopping with {{app_name}}.',
                'placeholders' => json_encode(['order_id', 'order_item_id', 'product_name', 'product_names', 'items_count', 'quantity', 'status_name', 'currency', 'final_total', 'app_name']),
            ],
            // --- Delivery date revised (ecommerce) ---
            [
                'type'        => 'order_item_delivery_estimate_customer',
                'title'       => 'New delivery date for {{product_name}}',
                'message'     => '{{product_name}} in order #{{order_id}} is now expected by {{estimated_delivery_date}}. Sorry for the delay.',
                'placeholders' => json_encode(['app_name', 'customer_name', 'order_id', 'order_item_id', 'product_name', 'quantity', 'estimated_delivery_date', 'previous_delivery_date', 'currency', 'final_total']),
            ],
            // --- Item cancellation ---
            [
                'type'        => 'order_item_cancelled_customer',
                'title'       => '{{product_name}} has been cancelled',
                'message'     => '{{product_name}} (x{{quantity}}) in your order #{{order_id}} has been cancelled. Any amount paid for this item is refunded to your {{app_name}} wallet.',
                'placeholders' => json_encode(['order_id', 'order_item_id', 'product_name', 'product_names', 'items_count', 'quantity', 'app_name', 'currency', 'final_total']),
            ],

            // --- Customer wallet (CommonHelper::sendWalletNotification) ---
            // One template per event so the wording/translation can differ; all of them
            // carry {{amount}}, {{currency}} and the resulting {{balance}}.
            [
                'type'        => 'wallet_recharged_customer',
                'title'       => 'Wallet recharged with {{currency}}{{amount}}',
                'message'     => 'Your {{app_name}} wallet has been recharged with {{currency}}{{amount}}. Available balance: {{currency}}{{balance}}.',
                'placeholders' => json_encode(['amount', 'balance', 'currency', 'txn_id', 'app_name']),
            ],
            [
                'type'        => 'wallet_refund_cancelled_customer',
                'title'       => 'Refund of {{currency}}{{amount}} credited',
                'message'     => '{{currency}}{{amount}} for the cancelled item {{product_name}} in order #{{order_id}} has been refunded to your wallet. Available balance: {{currency}}{{balance}}.',
                'placeholders' => json_encode(['amount', 'balance', 'currency', 'order_id', 'product_name', 'app_name']),
            ],
            [
                'type'        => 'wallet_refund_returned_customer',
                'title'       => 'Refund of {{currency}}{{amount}} credited',
                'message'     => '{{currency}}{{amount}} for the returned item {{product_name}} in order #{{order_id}} has been refunded to your wallet. Available balance: {{currency}}{{balance}}.',
                'placeholders' => json_encode(['amount', 'balance', 'currency', 'order_id', 'product_name', 'return_request_id', 'app_name']),
            ],
            [
                'type'        => 'wallet_cashback_customer',
                'title'       => 'Cashback of {{currency}}{{amount}} credited',
                'message'     => 'You earned {{currency}}{{amount}} cashback on order #{{order_id}}. Available balance: {{currency}}{{balance}}.',
                'placeholders' => json_encode(['amount', 'balance', 'currency', 'order_id', 'app_name']),
            ],
            [
                'type'        => 'wallet_referral_bonus_customer',
                'title'       => 'Referral bonus of {{currency}}{{amount}} credited',
                'message'     => 'You earned a referral bonus of {{currency}}{{amount}}. Available balance: {{currency}}{{balance}}.',
                'placeholders' => json_encode(['amount', 'balance', 'currency', 'app_name']),
            ],
            // Admin can only CREDIT a customer wallet — there is no admin debit, so no
            // corresponding debit template.
            [
                'type'        => 'wallet_admin_credit_customer',
                'title'       => '{{currency}}{{amount}} credited to your wallet',
                'message'     => '{{currency}}{{amount}} has been credited to your wallet. {{message}} Available balance: {{currency}}{{balance}}.',
                'placeholders' => json_encode(['amount', 'balance', 'currency', 'message', 'app_name']),
            ],
            [
                'type'        => 'wallet_recharge_failed_customer',
                'title'       => 'Wallet recharge failed',
                'message'     => 'Your wallet recharge of {{currency}}{{amount}} could not be completed. Please try again.',
                'placeholders' => json_encode(['customer_name', 'amount', 'currency', 'app_name']),
            ],

            // --- Delivery boy wallet (CommonHelper::addDeliveryBoySettlement) ---
            // One template covers every credit reason (order bonus, item bonus, return
            // commission) — {{reason}} carries the detail, mirroring the settlement ledger.
            [
                'type'        => 'wallet_credited_delivery_boy',
                'title'       => '{{currency}}{{amount}} credited to your wallet',
                'message'     => '{{currency}}{{amount}} has been credited for {{reason}}. Available balance: {{currency}}{{balance}}.',
                'placeholders' => json_encode(['amount', 'balance', 'currency', 'reason']),
            ],
            [
                'type'        => 'wallet_debited_delivery_boy',
                'title'       => '{{currency}}{{amount}} debited from your wallet',
                'message'     => '{{currency}}{{amount}} has been debited for {{reason}}. Available balance: {{currency}}{{balance}}.',
                'placeholders' => json_encode(['amount', 'balance', 'currency', 'reason']),
            ],

            // --- Withdrawal requests ---
            [
                'type'        => 'withdrawal_request_admin',
                'title'       => 'New withdrawal request of {{currency}}{{amount}}',
                'message'     => '{{delivery_boy_name}} has requested a withdrawal of {{currency}}{{amount}}.',
                'placeholders' => json_encode(['withdrawal_request_id', 'amount', 'currency', 'delivery_boy_name', 'app_name']),
            ],
            [
                'type'        => 'withdrawal_status_delivery_boy',
                'title'       => 'Withdrawal request {{status_name}}',
                'message'     => 'Your withdrawal request of {{currency}}{{amount}} has been {{status_name}}. {{remark}}',
                'placeholders' => json_encode(['withdrawal_request_id', 'amount', 'currency', 'status_name', 'remark']),
            ],
        ];

        $templates = array_merge($statusTemplates, $templates);

        $now = now();
        foreach ($templates as $row) {
            $row['created_at'] = $now;
            $row['updated_at'] = $now;
            DB::table('notification_templates')->updateOrInsert(
                ['type' => $row['type']],
                $row
            );
            // Seed translation for default language so getNotificationTemplateContent finds content immediately
            $template = DB::table('notification_templates')->where('type', $row['type'])->first();
            if ($template && Schema::hasTable('notification_template_translations')) {
                DB::table('notification_template_translations')->updateOrInsert(
                    [
                        'notification_template_id' => $template->id,
                        'language_id'             => $defaultLangId,
                    ],
                    [
                        'title'      => $row['title'],
                        'message'    => $row['message'] ?? '',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
            }
        }
    }
}
