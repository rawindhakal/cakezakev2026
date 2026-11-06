<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Canonical SMS templates (customer-facing), mirroring NotificationTemplatesSeeder:
 * idempotent updateOrInsert, {{placeholder}} syntax, seeds a default-language
 * translation row. Covers OTP + every OrderStatusList + ReturnStatusList status.
 * MSG91 DLT (Flow) template ids are set per language on the translation rows.
 */
class SmsTemplatesSeeder extends Seeder
{
    public function run(): void
    {
        $defaultLangId = DB::table('languages')
            ->where('system_type', 4)
            ->where('is_default', 1)
            ->value('id');

        $templates = [
            // ---- OTP ----
            'otp_customer' => [
                'message' => 'Your {{app_name}} OTP is {{otp}}. Do not share it with anyone.',
                'ph'      => ['app_name', 'otp'],
            ],

            // ---- Order statuses (customer) ----
            'order_status_payment_pending_customer' => [
                'message' => 'Hi {{customer_name}}, your order #{{order_id}} is placed and payment is pending.',
                'ph'      => ['customer_name', 'order_id', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_received_customer' => [
                'message' => 'Hi {{customer_name}}, your order #{{order_id}} has been received. Total: {{currency}}{{final_total}}.',
                'ph'      => ['customer_name', 'order_id', 'currency', 'final_total', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_processed_customer' => [
                'message' => 'Your order #{{order_id}} is being processed.',
                'ph'      => ['order_id', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_shipped_customer' => [
                'message' => 'Your order #{{order_id}} has been shipped.',
                'ph'      => ['order_id', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_out_for_delivery_customer' => [
                'message' => 'Your order #{{order_id}} is out for delivery.',
                'ph'      => ['order_id', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_delivered_customer' => [
                'message' => 'Your order #{{order_id}} has been delivered. Thank you for shopping with {{app_name}}!',
                'ph'      => ['order_id', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_cancelled_customer' => [
                'message' => 'Your order #{{order_id}} has been cancelled.',
                'ph'      => ['order_id', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_returned_customer' => [
                'message' => 'Your order #{{order_id}} has been returned.',
                'ph'      => ['order_id', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_preparing_customer' => [
                'message' => 'Your order #{{order_id}} is being prepared.',
                'ph'      => ['order_id', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_ready_for_pickup_customer' => [
                'message' => 'Your order #{{order_id}} is ready for pickup at {{branch_name}}, {{branch_address}}.',
                'ph'      => ['order_id', 'app_name', 'branch_name', 'branch_address'],
            ],
            'order_status_picked_up_customer' => [
                'message' => 'Your order #{{order_id}} has been picked up.',
                'ph'      => ['order_id', 'app_name', 'branch_name', 'branch_address'],
            ],

            // ---- Return-request statuses (customer) ----
            'return_status_return_requested_customer' => [
                'message' => 'Your return request #{{return_request_id}} for order #{{order_id}} has been submitted.',
                'ph'      => ['return_request_id', 'order_id', 'app_name'],
            ],
            'return_status_accepted_customer' => [
                'message' => 'Your return request #{{return_request_id}} has been accepted.',
                'ph'      => ['return_request_id', 'order_id', 'app_name'],
            ],
            'return_status_rejected_customer' => [
                'message' => 'Your return request #{{return_request_id}} has been rejected.',
                'ph'      => ['return_request_id', 'order_id', 'app_name'],
            ],
            'return_status_delivery_boy_assigned_customer' => [
                'message' => 'A delivery agent has been assigned for your return #{{return_request_id}}.',
                'ph'      => ['return_request_id', 'order_id', 'app_name'],
            ],
            'return_status_out_for_pickup_customer' => [
                'message' => 'Your return #{{return_request_id}} is out for pickup.',
                'ph'      => ['return_request_id', 'order_id', 'app_name'],
            ],
            'return_status_received_from_customer_customer' => [
                'message' => 'Your return #{{return_request_id}} has been picked up.',
                'ph'      => ['return_request_id', 'order_id', 'app_name'],
            ],
            'return_status_return_to_branch_customer' => [
                'message' => 'Your return #{{return_request_id}} has reached the branch.',
                'ph'      => ['return_request_id', 'order_id', 'app_name'],
            ],
            'return_status_refund_completed_customer' => [
                'message' => 'Refund for your return #{{return_request_id}} is completed.',
                'ph'      => ['return_request_id', 'order_id', 'app_name'],
            ],

            // --- Ecommerce item-wise status ---
            // Ecommerce tracks status per ITEM; the order-level templates above cannot say
            // WHICH item moved, so these carry the product name.
            'order_item_status_customer' => [
                'message' => '{{product_name}} in order #{{order_id}} is now {{status_name}}. - {{app_name}}',
                'ph'      => ['order_id', 'product_name', 'product_names', 'items_count', 'status_name', 'app_name'],
            ],
            'order_item_delivery_estimate_customer' => [
                'message' => '{{product_name}} in order #{{order_id}} is now expected by {{estimated_delivery_date}}. - {{app_name}}',
                'ph'      => ['app_name', 'customer_name', 'order_id', 'order_item_id', 'product_name', 'quantity', 'estimated_delivery_date', 'previous_delivery_date', 'currency', 'final_total'],
            ],
            'order_item_cancelled_customer' => [
                'message' => '{{product_name}} in order #{{order_id}} has been cancelled. - {{app_name}}',
                'ph'      => ['order_id', 'product_name', 'product_names', 'items_count', 'app_name'],
            ],
            'order_item_returned_customer' => [
                'message' => '{{product_name}} in order #{{order_id}} has been returned. - {{app_name}}',
                'ph'      => ['order_id', 'product_name', 'app_name'],
            ],

            // --- Wallet (customer only — there is no admin/delivery-boy SMS) ---
            'wallet_recharged_customer' => [
                'message' => '{{currency}}{{amount}} added to your wallet. Balance: {{currency}}{{balance}}. - {{app_name}}',
                'ph'      => ['amount', 'balance', 'currency', 'app_name'],
            ],
            'wallet_refund_cancelled_customer' => [
                'message' => 'Refund of {{currency}}{{amount}} for cancelled item in order #{{order_id}} credited to your wallet. Balance: {{currency}}{{balance}}. - {{app_name}}',
                'ph'      => ['amount', 'balance', 'currency', 'order_id', 'product_name', 'app_name'],
            ],
            'wallet_refund_returned_customer' => [
                'message' => 'Refund of {{currency}}{{amount}} for returned item in order #{{order_id}} credited to your wallet. Balance: {{currency}}{{balance}}. - {{app_name}}',
                'ph'      => ['amount', 'balance', 'currency', 'order_id', 'product_name', 'app_name'],
            ],
            'wallet_cashback_customer' => [
                'message' => 'You earned {{currency}}{{amount}} cashback on order #{{order_id}}. Balance: {{currency}}{{balance}}. - {{app_name}}',
                'ph'      => ['amount', 'balance', 'currency', 'order_id', 'app_name'],
            ],
            'wallet_referral_bonus_customer' => [
                'message' => 'You earned a referral bonus of {{currency}}{{amount}}. Balance: {{currency}}{{balance}}. - {{app_name}}',
                'ph'      => ['amount', 'balance', 'currency', 'app_name'],
            ],
            // Admin can only CREDIT a customer wallet — no admin debit, so no debit template.
            'wallet_admin_credit_customer' => [
                'message' => '{{currency}}{{amount}} credited to your wallet. Balance: {{currency}}{{balance}}. - {{app_name}}',
                'ph'      => ['amount', 'balance', 'currency', 'message', 'app_name'],
            ],
            'back_in_stock_customer' => [
                'message' => '{{product_name}} ({{variant_name}}) is back in stock at {{currency}}{{price}}. Order now! - {{app_name}}',
                'ph'      => ['app_name', 'customer_name', 'product_name', 'variant_name', 'price', 'currency'],
            ],
            'wallet_recharge_failed_customer' => [
                'message' => 'Your wallet recharge of {{currency}}{{amount}} could not be completed. Please try again. - {{app_name}}',
                'ph'      => ['customer_name', 'amount', 'currency', 'app_name'],
            ],

            // --- App version update ---
            'app_version_update_customer' => [
                'message' => '{{app_name}} {{version}} is now available on {{platform}}. Update now: {{store_url}}',
                'ph'      => ['app_name', 'customer_name', 'version', 'platform', 'store_url'],
            ],
            'app_version_update_delivery_boy' => [
                'message' => '{{app_name}} {{version}} is now available on {{platform}}. Please update: {{store_url}}',
                'ph'      => ['app_name', 'delivery_boy_name', 'version', 'platform', 'store_url'],
            ],

            // --- Account ---
            'account_status_customer' => [
                'message' => 'Your {{app_name}} account is now {{status_name}}.',
                'ph'      => ['customer_name', 'status_name', 'app_name'],
            ],
            'account_status_delivery_boy' => [
                'message' => 'Your {{app_name}} delivery partner account is now {{status_name}}.',
                'ph'      => ['delivery_boy_name', 'status_name', 'app_name'],
            ],
            'payment_failed_customer' => [
                'message' => 'Payment of {{currency}}{{amount}} for order #{{order_id}} failed and the order was cancelled. - {{app_name}}',
                'ph'      => ['customer_name', 'order_id', 'amount', 'currency', 'app_name'],
            ],
            'salary_paid_delivery_boy' => [
                'message' => 'Salary of {{currency}}{{amount}} was paid on {{paid_on}}. - {{app_name}}',
                'ph'      => ['delivery_boy_name', 'amount', 'currency', 'paid_on', 'note', 'app_name'],
            ],
            // --- Promotions ---
            'promo_code_customer' => [
                'message' => 'Use code {{promo_code}} to get {{discount}} off. Valid till {{expiry_date}}. - {{app_name}}',
                'ph'      => ['customer_name', 'promo_code', 'discount', 'message', 'expiry_date', 'app_name'],
            ],
        ];

        // Delivery-boy + admin per-status SMS (customer rows are defined above).
        foreach (NotificationTemplatesSeeder::ORDER_STATUSES as $slug) {
            $templates["order_status_{$slug}_delivery_boy"] = [
                'message' => 'Order #{{order_id}} is now {{status_name}}. - {{app_name}}',
                'ph'      => ['order_id', 'status_name', 'delivery_boy_name', 'app_name'],
            ];
            $templates["order_status_{$slug}_admin"] = [
                'message' => 'Order #{{order_id}} is now {{status_name}}. - {{app_name}}',
                'ph'      => ['order_id', 'status_name', 'app_name'],
            ];
        }
        foreach (NotificationTemplatesSeeder::RETURN_STATUSES as $slug) {
            if (in_array($slug, NotificationTemplatesSeeder::RETURN_DB_STATUSES, true)) {
                $templates["return_status_{$slug}_delivery_boy"] = [
                    'message' => 'Return #{{return_request_id}} for order #{{order_id}} is now {{status_name}}. - {{app_name}}',
                    'ph'      => ['return_request_id', 'order_id', 'status_name', 'app_name'],
                ];
            }
        }

        foreach ($templates as $type => $tpl) {
            DB::table('sms_templates')->updateOrInsert(
                ['type' => $type],
                [
                    'message'      => $tpl['message'],
                    'placeholders' => json_encode($tpl['ph']),
                    'updated_at'   => now(),
                    'created_at'   => now(),
                ]
            );

            if ($defaultLangId) {
                $templateId = DB::table('sms_templates')->where('type', $type)->value('id');
                DB::table('sms_template_translations')->updateOrInsert(
                    ['sms_template_id' => $templateId, 'language_id' => $defaultLangId],
                    [
                        'message'    => $tpl['message'],
                        'updated_at' => now(),
                        'created_at' => now(),
                    ]
                );
            }
        }
    }
}
