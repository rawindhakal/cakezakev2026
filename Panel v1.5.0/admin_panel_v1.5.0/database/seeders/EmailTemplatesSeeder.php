<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Seeds email_templates and email_template_translations (default language).
 * Templates use {{placeholder}} syntax; placeholders column lists keys for reference.
 * Source of the flows: CommonHelper::sendMailOrderStatus, sendReturnRequestMail,
 * sendMailAdminStatus, CustomerAuthController (verification code),
 * AdminAuthController (password reset).
 */
class EmailTemplatesSeeder extends Seeder
{
    /** One EMAIL template row per order/return status × audience. */
    public static function statusEmailTemplates(): array
    {
        $rows = [];
        foreach (NotificationTemplatesSeeder::ORDER_STATUSES as $slug) {
            // The order-items table is only rendered for received + delivered mails.
            $withItems = in_array($slug, ['received', 'delivered'], true);
            $customerMsg = $withItems
                ? "Hi {{customer_name}},\n\nYour order #{{order_id}} is now {{status_name}}.\n\n{{order_items_html}}\n\nThank you for shopping with {{app_name}}."
                : "Hi {{customer_name}},\n\nYour order #{{order_id}} is now {{status_name}}.\n\nThank you for shopping with {{app_name}}.";
            $customerPh = ['customer_name', 'order_id', 'status_name', 'currency', 'final_total', 'app_name', 'branch_name', 'branch_address'];
            if ($withItems) {
                $customerPh[] = 'order_items_html';
            }
            $rows[] = [
                'type'        => "order_status_{$slug}_customer",
                'title'       => 'Your order #{{order_id}} has been {{status_name}}',
                'message'     => $customerMsg,
                'placeholders' => json_encode($customerPh),
            ];
            $rows[] = [
                'type'        => "order_status_{$slug}_delivery_boy",
                'title'       => 'Order #{{order_id}} is now {{status_name}}',
                'message'     => "Hi {{delivery_boy_name}},\n\nOrder #{{order_id}} is now {{status_name}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['delivery_boy_name', 'order_id', 'status_name', 'app_name']),
            ];
            $rows[] = [
                'type'        => "order_status_{$slug}_admin",
                'title'       => 'Order #{{order_id}} is now {{status_name}}',
                'message'     => "Hi {{admin_name}},\n\nOrder #{{order_id}} is now {{status_name}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['admin_name', 'order_id', 'status_name', 'product_name', 'app_name']),
            ];
        }
        foreach (NotificationTemplatesSeeder::RETURN_STATUSES as $slug) {
            $rows[] = [
                'type'        => "return_status_{$slug}_customer",
                'title'       => 'Return Request #{{return_request_id}} - {{status_name}}',
                'message'     => "Hi {{customer_name}},\n\nYour return request #{{return_request_id}} for order #{{order_id}} is now {{status_name}}.\n\nFor any help contact us at {{support_email}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'return_request_id', 'order_id', 'status_name', 'support_email', 'app_name']),
            ];
            if (in_array($slug, NotificationTemplatesSeeder::RETURN_DB_STATUSES, true)) {
                $rows[] = [
                    'type'        => "return_status_{$slug}_delivery_boy",
                    'title'       => 'Return request is now {{status_name}}',
                    'message'     => "Hi {{delivery_boy_name}},\n\nReturn request for order #{{order_id}} is now {{status_name}}.\n\n{{app_name}}",
                    'placeholders' => json_encode(['delivery_boy_name', 'return_request_id', 'order_id', 'status_name', 'app_name']),
                ];
            }
            if ($slug === 'return_requested') {
                $rows[] = [
                    'type'        => "return_status_{$slug}_admin",
                    'title'       => 'New return request for order #{{order_id}}',
                    'message'     => "A new return request #{{return_request_id}} has been raised for order #{{order_id}}.\n\n{{app_name}}",
                    'placeholders' => json_encode(['return_request_id', 'order_id', 'app_name']),
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

        $templates = [
            [
                'type'        => 'order_item_status_customer',
                'title'       => 'Order item ({{product_name}}) in order #{{order_id}} has been {{status_name}}',
                'message'     => "Hi {{customer_name}},\n\nThe item {{product_name}} (qty {{quantity}}) in your order #{{order_id}} has been {{status_name}}.\n\nThank you for shopping with {{app_name}}.",
                'placeholders' => json_encode(['customer_name', 'order_id', 'order_item_id', 'product_name', 'product_names', 'items_count', 'quantity', 'status_name', 'app_name']),
            ],
            [
                'type'        => 'order_item_delivery_estimate_customer',
                'title'       => 'Updated delivery date for your order #{{order_id}}',
                'message'     => "Hi {{customer_name}},\n\nThe delivery date for {{product_name}} (qty {{quantity}}) in your order #{{order_id}} has changed from {{previous_delivery_date}} to {{estimated_delivery_date}}.\n\nWe are sorry for the delay and are working to get it to you as soon as possible.\n\n{{app_name}}",
                'placeholders' => json_encode(['app_name', 'customer_name', 'order_id', 'order_item_id', 'product_name', 'quantity', 'estimated_delivery_date', 'previous_delivery_date', 'currency', 'final_total']),
            ],
            [
                'type'        => 'order_item_cancelled_customer',
                'title'       => 'Order item ({{product_name}}) in order #{{order_id}} has been cancelled',
                'message'     => "Hi {{customer_name}},\n\nWe are sorry to inform you that the item {{product_name}} in your order #{{order_id}} has been cancelled.\nIf you paid online, the amount will be refunded to you.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'order_id', 'order_item_id', 'product_name', 'product_names', 'items_count', 'status_name', 'app_name']),
            ],
            [
                'type'        => 'assign_order_delivery_boy',
                'title'       => 'You have just been assigned new order #{{order_id}}',
                'message'     => "Hi {{delivery_boy_name}},\n\nOrder #{{order_id}} has been assigned to you for delivery.\nView the order: {{redirect_url}}\n\n{{app_name}}",
                'placeholders' => json_encode(['delivery_boy_name', 'order_id', 'redirect_url', 'app_name']),
            ],
            [
                'type'        => 'assign_order_customer',
                'title'       => 'Your order #{{order_id}} is on its way',
                'message'     => "Hi {{customer_name}},\n\n{{delivery_boy_name}} has been assigned to deliver your order #{{order_id}}. You can track it in the app.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'order_id', 'delivery_boy_name', 'app_name']),
            ],
            [
                'type'        => 'order_item_returned_customer',
                'title'       => 'Order item ({{product_name}}) in order #{{order_id}} has been returned',
                'message'     => "Hi {{customer_name}},\n\nThe item {{product_name}} in your order #{{order_id}} has been returned.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'order_id', 'product_name', 'app_name']),
            ],
            // --- Wallet (customer) ---
            [
                'type'        => 'wallet_recharged_customer',
                'title'       => 'Wallet recharged with {{currency}}{{amount}}',
                'message'     => "Hi {{customer_name}},\n\nYour wallet has been recharged with {{currency}}{{amount}}. Available balance: {{currency}}{{balance}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'amount', 'balance', 'currency', 'app_name']),
            ],
            [
                'type'        => 'wallet_cashback_customer',
                'title'       => 'Cashback of {{currency}}{{amount}} credited',
                'message'     => "Hi {{customer_name}},\n\nYou earned {{currency}}{{amount}} cashback. Available balance: {{currency}}{{balance}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'amount', 'balance', 'currency', 'app_name']),
            ],
            [
                'type'        => 'wallet_referral_bonus_customer',
                'title'       => 'Referral bonus of {{currency}}{{amount}} credited',
                'message'     => "Hi {{customer_name}},\n\nYou earned a referral bonus of {{currency}}{{amount}}. Available balance: {{currency}}{{balance}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'amount', 'balance', 'currency', 'app_name']),
            ],
            [
                'type'        => 'wallet_admin_credit_customer',
                'title'       => '{{currency}}{{amount}} credited to your wallet',
                'message'     => "Hi {{customer_name}},\n\n{{currency}}{{amount}} has been credited to your wallet. Available balance: {{currency}}{{balance}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'amount', 'balance', 'currency', 'app_name']),
            ],
            [
                'type'        => 'wallet_recharge_failed_customer',
                'title'       => 'Wallet recharge failed',
                'message'     => "Hi {{customer_name}},\n\nYour wallet recharge of {{currency}}{{amount}} could not be completed. No amount was deducted. Please try again.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'amount', 'currency', 'app_name']),
            ],
            [
                'type'        => 'wallet_refund_cancelled_customer',
                'title'       => 'Refund of {{currency}}{{amount}} credited',
                'message'     => "Hi {{customer_name}},\n\n{{currency}}{{amount}} for the cancelled item in order #{{order_id}} has been refunded to your wallet. Available balance: {{currency}}{{balance}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'amount', 'balance', 'currency', 'order_id', 'app_name']),
            ],
            [
                'type'        => 'wallet_refund_returned_customer',
                'title'       => 'Refund of {{currency}}{{amount}} credited',
                'message'     => "Hi {{customer_name}},\n\n{{currency}}{{amount}} for the returned item in order #{{order_id}} has been refunded to your wallet. Available balance: {{currency}}{{balance}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'amount', 'balance', 'currency', 'order_id', 'app_name']),
            ],
            // --- Wallet (delivery boy) ---
            [
                'type'        => 'wallet_credited_delivery_boy',
                'title'       => '{{currency}}{{amount}} credited to your wallet',
                'message'     => "Hi {{delivery_boy_name}},\n\n{{currency}}{{amount}} has been credited to your wallet.\n\n{{app_name}}",
                'placeholders' => json_encode(['delivery_boy_name', 'amount', 'currency', 'app_name']),
            ],
            [
                'type'        => 'wallet_debited_delivery_boy',
                'title'       => '{{currency}}{{amount}} debited from your wallet',
                'message'     => "Hi {{delivery_boy_name}},\n\n{{currency}}{{amount}} has been debited from your wallet.\n\n{{app_name}}",
                'placeholders' => json_encode(['delivery_boy_name', 'amount', 'currency', 'app_name']),
            ],
            // --- Withdrawal ---
            [
                'type'        => 'withdrawal_request_admin',
                'title'       => 'New withdrawal request of {{currency}}{{amount}}',
                'message'     => "{{delivery_boy_name}} has requested a withdrawal of {{currency}}{{amount}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['delivery_boy_name', 'amount', 'currency', 'app_name']),
            ],
            [
                'type'        => 'withdrawal_status_delivery_boy',
                'title'       => 'Withdrawal request {{status_name}}',
                'message'     => "Hi {{delivery_boy_name}},\n\nYour withdrawal request of {{currency}}{{amount}} has been {{status_name}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['delivery_boy_name', 'amount', 'currency', 'status_name', 'app_name']),
            ],
            // --- Back in stock ---
            [
                'type'        => 'back_in_stock_customer',
                'title'       => '{{product_name}} is back in stock',
                'message'     => "Hi {{customer_name}},\n\nGood news — {{product_name}} ({{variant_name}}) you asked us about is back in stock at {{currency}}{{price}}.\n\nOrder now before it sells out again.\n\n{{app_name}}",
                'placeholders' => json_encode(['app_name', 'customer_name', 'product_name', 'variant_name', 'price', 'currency']),
            ],

            // --- App version update ---
            [
                'type'        => 'app_version_update_customer',
                'title'       => '{{app_name}} {{version}} is now available',
                'message'     => "Hi {{customer_name}},\n\nA new {{platform}} version of {{app_name}} ({{version}}) is now available.\n\nUpdate here: {{store_url}}\n\n{{app_name}}",
                'placeholders' => json_encode(['app_name', 'customer_name', 'version', 'platform', 'store_url']),
            ],
            [
                'type'        => 'app_version_update_delivery_boy',
                'title'       => '{{app_name}} {{version}} is now available',
                'message'     => "Hi {{delivery_boy_name}},\n\nA new {{platform}} version of {{app_name}} ({{version}}) is now available. Please update to keep taking orders.\n\nUpdate here: {{store_url}}\n\n{{app_name}}",
                'placeholders' => json_encode(['app_name', 'delivery_boy_name', 'version', 'platform', 'store_url']),
            ],

            // --- Cart reminders ---
            [
                'type'        => 'cart_reminder_first_customer',
                'title'       => 'Your cart with {{product_name}} is waiting for you!',
                'message'     => "Your cart with {{product_name}} is waiting. Complete your purchase today!\n\n{{app_name}}",
                'placeholders' => json_encode(['product_name', 'app_name']),
            ],
            [
                'type'        => 'cart_reminder_interval_customer',
                'title'       => 'Still thinking it over?',
                'message'     => "You still have {{product_name}} in your cart. Complete your order now and don't miss out!\n\n{{app_name}}",
                'placeholders' => json_encode(['product_name', 'app_name']),
            ],
            // --- Account ---
            [
                'type'        => 'account_status_customer',
                'title'       => 'Your account is {{status_name}}',
                'message'     => "Hi {{customer_name}},\n\nYour {{app_name}} account is now {{status_name}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'status_name', 'app_name']),
            ],
            [
                'type'        => 'account_status_delivery_boy',
                'title'       => 'Your account is {{status_name}}',
                'message'     => "Hi {{delivery_boy_name}},\n\nYour {{app_name}} delivery partner account is now {{status_name}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['delivery_boy_name', 'status_name', 'app_name']),
            ],
            [
                'type'        => 'welcome_customer',
                'title'       => 'Welcome to {{app_name}}!',
                'message'     => "Hi {{customer_name}},\n\nWelcome to {{app_name}}! We're glad to have you on board. Start exploring and enjoy shopping with us.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'app_name']),
            ],
            [
                'type'        => 'password_changed_customer',
                'title'       => 'Your password was changed',
                'message'     => "Hi {{customer_name}},\n\nThis confirms that your {{app_name}} account password was just changed. If this wasn't you, please contact support immediately.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'app_name']),
            ],
            [
                'type'        => 'payment_failed_customer',
                'title'       => 'Payment failed for order #{{order_id}}',
                'message'     => "Hi {{customer_name}},\n\nYour payment of {{currency}}{{amount}} for order #{{order_id}} could not be completed, so the order was cancelled. Please try placing the order again.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'order_id', 'amount', 'currency', 'app_name']),
            ],
            [
                'type'        => 'salary_paid_delivery_boy',
                'title'       => 'Salary of {{currency}}{{amount}} paid',
                'message'     => "Hi {{delivery_boy_name}},\n\nA salary payment of {{currency}}{{amount}} was recorded on {{paid_on}}.\n{{note}}\n\n{{app_name}}",
                'placeholders' => json_encode(['delivery_boy_name', 'amount', 'currency', 'paid_on', 'note', 'app_name']),
            ],
            // --- Promotions ---
            [
                'type'        => 'promo_code_customer',
                'title'       => 'New offer — use code {{promo_code}}',
                'message'     => "Hi {{customer_name}},\n\n{{message}}\nUse code {{promo_code}} to get {{discount}} off. Hurry, valid till {{expiry_date}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'promo_code', 'discount', 'message', 'expiry_date', 'app_name']),
            ],
            [
                'type'        => 'new_blog_customer',
                'title'       => '{{blog_title}}',
                'message'     => "Hi {{customer_name}},\n\nWe just published a new post: {{blog_title}}. Read it now on {{app_name}}.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'blog_title', 'blog_url', 'app_name']),
            ],
            [
                'type'        => 'verify_email_customer',
                'title'       => '{{app_name}} - Your verification code',
                'message'     => "Hi {{customer_name}},\n\nYour verification code is: {{code}}\n\nIf you did not request this, please ignore this email.\n\n{{app_name}}",
                'placeholders' => json_encode(['customer_name', 'code', 'app_name']),
            ],
            [
                'type'        => 'two_factor_code_admin',
                'title'       => '{{app_name}} - Your login code',
                'message'     => "Hi {{username}},\n\nYour login verification code is: {{code}}\n\nIt expires in {{expiry_minutes}} minutes and can be used once.\n\nIf you did not try to sign in, change your password — someone else knows it.\n\n{{app_name}}",
                'placeholders' => json_encode(['username', 'code', 'expiry_minutes', 'app_name']),
            ],
            [
                'type'        => 'forgot_password_admin',
                'title'       => '{{app_name}} - Reset your password',
                'message'     => "Hi,\n\nWe received a request to reset your password. Click the link below to set a new password:\n{{reset_link}}\n\nIf you did not request this, please ignore this email.\n\n{{app_name}}",
                'placeholders' => json_encode(['reset_link', 'app_name']),
            ],
        ];

        $templates = array_merge(self::statusEmailTemplates(), $templates);

        foreach ($templates as $t) {
            DB::table('email_templates')->updateOrInsert(
                ['type' => $t['type']],
                [
                    'title'        => $t['title'],
                    'message'      => $t['message'],
                    'placeholders' => $t['placeholders'],
                    'created_at'   => now(),
                    'updated_at'   => now(),
                ]
            );

            $templateId = DB::table('email_templates')->where('type', $t['type'])->value('id');
            if ($templateId && $defaultLangId) {
                DB::table('email_template_translations')->updateOrInsert(
                    ['email_template_id' => $templateId, 'language_id' => $defaultLangId],
                    [
                        'title'      => $t['title'],
                        'message'    => $t['message'],
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]
                );
            }
        }
    }
}
