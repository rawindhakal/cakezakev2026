<?php

namespace App\Helpers;

use App\Models\Order;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Razorpay\Api\Api;
use Midtrans\Config;
use Midtrans\Snap;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;
use GuzzleHttp\Client;

class TransactionHelper
{
    public static function createOrderonRazorpay($type, $order_id, $wallet_amount, array $gateways = [], $currencyCode = 'INR')
    {
        $transaction_id = "";

        try {
            if ($type == 'order') {
                $order = Order::with('items')->findOrFail($order_id);
                $order_amount = $order->final_total;
                $order_details['receipt'] = strval($order->id);
            } else {
                $order_amount = $wallet_amount;
                $order_details['receipt'] = 'wallet_recharge';
            }

            $api = new Api($gateways['razorpay_key'] ?? '', $gateways['razorpay_secret_key'] ?? '');

            $currency_code = $currencyCode ?: 'INR';
            $order_details = [
                'amount' => $order_amount * 100,
                'currency' => $currency_code,
                'payment_capture' => 1,
                'receipt' => $order_details['receipt'],
            ];

            $rpay_order = $api->order->create($order_details);

            $transaction_id = $rpay_order->id;
        } catch (\Exception $e) {
            Log::error("Exception: " . $e->getMessage());
            Log::error($e->getTraceAsString());
        }

        return $transaction_id;
    }

    public static function createOrderOnStripe($amount, $type = 'order', $order_id = 0, array $gateways = [], $countryId = null)
    {
        $response = "";
        try {
            $user = auth()->user();

            $stripe_secret_key = $gateways['stripe_secret_key'] ?? '';
            $stripe_currency_code = $gateways['stripe_currency_code'] ?? '';
            $app_name = Setting::get_value('app_name');

            $stripe = new \Stripe\StripeClient($stripe_secret_key);
            Log::info("Stripe Initialized", [$stripe]);

            $stripeAmount = (float)$amount * 100;

            $metadata = [
                'type' => $type,
                'user_id' => $user->id,
                'country_id' => $countryId,
            ];

            if ($type == 'order' && $order_id > 0) {
                $metadata['order_id'] = $order_id;
            } elseif ($type == 'wallet') {
                $metadata['order_id'] = 'wallet-refill-user-' . $user->id . '-' . time() . '-' . random_int(100000, 999999)
                    . CommonHelper::rechargeCountrySuffix($countryId);
            }

            $paymentIntentData = [
                'description' => $app_name,
                'amount' => $stripeAmount,
                'currency' => $stripe_currency_code,
                'automatic_payment_methods' => ['enabled' => true],
                'metadata' => $metadata,
            ];

            $stripeData = $stripe->paymentIntents->create($paymentIntentData);
            $response = $stripeData;
        } catch (\Exception $e) {
            Log::error("Stripe Payment Error: " . $e->getMessage());
            Log::error($e->getTraceAsString());
        } finally {
            return $response;
        }
    }

    public static function verifyRazorpayPayment($paymentId, array $gateways = []): bool
    {
        try {
            if (empty($paymentId)) {
                return false;
            }
            $api = new Api($gateways['razorpay_key'] ?? '', $gateways['razorpay_secret_key'] ?? '');
            $payment = $api->payment->fetch($paymentId);
            return in_array($payment->status ?? '', ['captured', 'authorized'], true);
        } catch (\Exception $e) {
            Log::error("Razorpay payment fetch error: " . $e->getMessage());
            return false;
        }
    }

    public static function createOrderonMidtrans($type, $order_id, $wallet_amount, array $gateways = [], $countryId = null)
    {
        $snapUrl = "";
        $snapToken = "";
        $currentDateTime = Carbon::now()->format('YmdHis');
        try {
            if ($type == 'order') {
                $order = Order::with('items')->findOrFail($order_id);

                $order_amount = $order->final_total;
                $order_details['receipt'] = 'order-' . $order_id . '-' . auth()->user()->id;
            } else {
                $order_amount = $wallet_amount;
                $order_details['receipt'] = 'wallet-' . $currentDateTime . '-' . auth()->user()->id
                    . CommonHelper::rechargeCountrySuffix($countryId);
            }

            Config::$serverKey = $gateways['midtrans_server_key'] ?? '';
            Config::$isProduction = (($gateways['midtrans_mode'] ?? '') == 'sandbox') ? false : true;

            $params = [
                'transaction_details' => [
                    'order_id' => $order_details['receipt'],
                    'gross_amount' => $order_amount * 1000,
                ],
            ];

            $snapResponse = Snap::createTransaction($params);

            $snapUrl = $snapResponse->redirect_url;
            $snapToken = $snapResponse->token;
        } catch (\Exception $e) {
            Log::error("Exception: " . $e->getMessage());
            Log::error($e->getTraceAsString());
        }

        return [
            'snapUrl' => $snapUrl,
            'snapToken' => $snapToken,
        ];
    }

    public static function createOrderonPhonepe($type, $order_id, $wallet_amount, array $gateways = [], $countryId = null)
    {
        try {
            $currentDateTime = Carbon::now()->format('YmdHis');
            $userId = auth()->id();

            if ($type === 'order') {
                $order = Order::with('items')->findOrFail($order_id);
                $order_amount = $order->final_total;
                $receipt = 'order-' . $order_id . '-' . $userId;
            } else {
                $order_amount = $wallet_amount;
                $receipt = 'wallet-' . $currentDateTime . '-' . $userId
                    . CommonHelper::rechargeCountrySuffix($countryId);
            }

            $mode          = $gateways['phonepay_mode'] ?? '';
            $clientId      = $gateways['phonepay_client_id'] ?? '';
            $clientVersion = $gateways['phonepay_client_version'] ?? '';
            $clientSecret  = $gateways['phonepay_client_secret'] ?? '';
            $websiteUrl    = Setting::get_value('website_url');

            if ($mode === 'production') {
                $tokenUrl = 'https://api.phonepe.com/apis/identity-manager/v1/oauth/token';
                $payUrl = 'https://api.phonepe.com/apis/pg/checkout/v2/pay';
            } else {
                $tokenUrl = 'https://api-preprod.phonepe.com/apis/pg-sandbox/v1/oauth/token';
                $payUrl = 'https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/pay';
            }

            $merchantTransactionId = substr('TXN' . time() . '-' . $receipt, 0, 40);
            $tokenCurl = curl_init();

            curl_setopt_array($tokenCurl, array(
                CURLOPT_URL => $tokenUrl,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_ENCODING => '',
                CURLOPT_MAXREDIRS => 10,
                CURLOPT_TIMEOUT => 0,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
                CURLOPT_CUSTOMREQUEST => 'POST',
                CURLOPT_POSTFIELDS => http_build_query([
                    'client_id' => $clientId,
                    'client_version' => $clientVersion,
                    'client_secret' => $clientSecret,
                    'grant_type' => 'client_credentials',
                ]),
                CURLOPT_HTTPHEADER => array(
                    'Content-Type: application/x-www-form-urlencoded'
                ),
            ));

            $response = curl_exec($tokenCurl);
            unset($tokenCurl);

            $tokenResponse = json_decode($response, true);
            $accessToken = $tokenResponse['access_token'] ?? null;

            if (!$accessToken) {
                return [
                    'error' => true,
                    'message' => 'Failed to retrieve token',
                ];
            }

            $paymentData = [
                'merchantOrderId' => $merchantTransactionId,
                'amount' => (int) round($order_amount * 100),
                "metaInfo" => [
                    "type" => $type,
                    "order_id" => $order_id,
                    "user_id" => $userId,
                    "country_id" => $countryId,
                ],
                'paymentFlow' => [
                    'type' => 'PG_CHECKOUT',
                    'message' => 'Payment message used for collect requests',
                    'merchantUrls' => [
                        'redirectUrl' => $websiteUrl . '/web-payment-status?payment_method=phonepe',
                    ],
                ],
            ];

            $payCUrl = curl_init();

            curl_setopt_array($payCUrl, array(
                CURLOPT_URL => $payUrl,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_ENCODING => '',
                CURLOPT_MAXREDIRS => 10,
                CURLOPT_TIMEOUT => 0,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
                CURLOPT_CUSTOMREQUEST => 'POST',
                CURLOPT_POSTFIELDS => json_encode($paymentData),
                CURLOPT_HTTPHEADER => array(
                    'Content-Type: application/json',
                    'Authorization: O-Bearer ' . $accessToken,
                ),
            ));
            $response = curl_exec($payCUrl);
            unset($payCUrl);
            $final_response = json_decode($response, true);
            $final_response['merchantOrderId'] = $merchantTransactionId;
            $final_response['token'] = $accessToken;
            return CommonHelper::responseWithData($final_response);
        } catch (\Exception $e) {
            Log::error('PhonePe Order Error: ' . $e->getMessage());
            return [
                'error' => true,
                'message' => $e->getMessage(),
            ];
        }
    }

    public static function createOrderonCashfree($type, $order_id, $wallet_amount, array $gateways = [], $currencyCode = 'INR', $countryId = null)
    {
        try {
            $currentDateTime = Carbon::now()->format('YmdHis');
            $uniqueString = uniqid();

            if ($type == 'order') {
                $order = Order::with('items')->findOrFail($order_id);
                $order_amount = $order->final_total;
                $order_details['receipt'] = 'order-' . $order_id . '-' . auth()->user()->id . '-' . $uniqueString;
            } else {
                $order_amount = $wallet_amount;
                $order_details['receipt'] = 'wallet-' . $currentDateTime . '-' . auth()->user()->id . '-' . $uniqueString
                    . CommonHelper::rechargeCountrySuffix($countryId);
            }
            $user = User::where('id', auth()->user()->id)->first();

            $cashfree_app_id = $gateways['cashfree_app_id'] ?? '';
            $cashfree_secret_key = $gateways['cashfree_secret_key'] ?? '';
            $cashfree_mode = $gateways['cashfree_mode'] ?? '';

            if (empty($cashfree_app_id) || empty($cashfree_secret_key)) {
                throw new \Exception('Cashfree credentials are not properly configured');
            }

            $url = $cashfree_mode === 'production' ? 'https://api.cashfree.com/pg/links' : 'https://sandbox.cashfree.com/pg/links';

            $client = new Client();

            $linkPurpose = $type === 'order' ? 'Order Payment' : 'Wallet Recharge';
            if (strlen($linkPurpose) > 100) {
                $linkPurpose = substr($linkPurpose, 0, 100);
            }

            $sanitizeValue = function ($value) {
                if (empty($value)) {
                    return '';
                }
                $sanitized = str_replace(['<', '>', '{', '}', '"'], '', (string)$value);
                if (strlen($sanitized) > 100) {
                    $sanitized = substr($sanitized, 0, 100);
                }
                return $sanitized;
            };

            $linkNotes = [];
            $linkNotes['type'] = $sanitizeValue($type);

            if (!empty($order_id)) {
                $linkNotes['order_id'] = $sanitizeValue($order_id);
            }

            if (!empty($currentDateTime)) {
                $linkNotes['time'] = $sanitizeValue($currentDateTime);
            }

            if (empty($linkNotes)) {
                $linkNotes['type'] = $sanitizeValue($type);
            }

            $rawPhone = preg_replace('/\D/', '', (string) ($user->mobile ?? ''));
            if (strlen($rawPhone) === 12 && str_starts_with($rawPhone, '91')) {
                $rawPhone = substr($rawPhone, 2);
            } elseif (strlen($rawPhone) === 11 && str_starts_with($rawPhone, '0')) {
                $rawPhone = substr($rawPhone, 1);
            }
            $customerPhone = (strlen($rawPhone) >= 8 && strlen($rawPhone) <= 15) ? $rawPhone : '9999999999';

            $body = [
                'customer_details' => [
                    'customer_email' => $user->email ?? '',
                    'customer_name' => $user->name ?? '',
                    'customer_phone' => $customerPhone,
                ],
                'link_amount' => floatval($order_amount),
                'link_currency' => $currencyCode ?: 'INR',
                'link_id' => $order_details['receipt'],
                'link_purpose' => $linkPurpose,
                'link_auto_reminders' => true,
                'link_notify' => [
                    'send_email' => true,
                    'send_sms' => false
                ],
                'link_meta' => [
                    'return_url' => route('cashfree.redirect', ['order' => $order_details['receipt']]),
                    'upi_intent' => false
                ],
                'link_notes' => $linkNotes,
                'link_expiry_time' => date('c', strtotime('+1 day'))
            ];

            $response = $client->post($url, [
                'headers' => [
                    'accept' => 'application/json',
                    'content-type' => 'application/json',
                    'x-api-version' => '2023-08-01',
                    'x-client-id' => trim($cashfree_app_id),
                    'x-client-secret' => trim($cashfree_secret_key),
                ],
                'json' => $body,
            ]);

            $responseBody = json_decode($response->getBody(), true);

            if (isset($responseBody['link_status']) && $responseBody['link_status'] === 'ACTIVE') {
                return [
                    'redirectUrl' => $responseBody['link_url'],
                ];
            } else {
                throw new \Exception('Cashfree API error: ' . json_encode($responseBody));
            }
        } catch (\GuzzleHttp\Exception\ClientException $e) {
            Log::error('Cashfree ClientException:', [
                'message' => $e->getMessage(),
                'response' => $e->getResponse() ? json_decode($e->getResponse()->getBody(), true) : null
            ]);
            return [
                'error' => true,
                'message' => 'Payment gateway error: ' . $e->getMessage()
            ];
        } catch (\Exception $e) {
            Log::error('Error in createOrderonCashfree:', [
                'message' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            return [
                'error' => true,
                'message' => $e->getMessage()
            ];
        }
    }

    public static function createOrderonPayTabs($type, $order_id, $wallet_amount, array $gateways = [], $currencyCode = 'INR', $countryId = null)
    {
        try {
            $currentDateTime = Carbon::now()->format('YmdHis');

            if ($type == 'order') {
                $order = Order::with('items')->findOrFail($order_id);
                $order_amount = $order->final_total;
                $order_details['receipt'] = 'order-' . $order_id . '-' . auth()->user()->id;
            } else {
                $order_amount = $wallet_amount;
                $order_details['receipt'] = 'wallet-' . $currentDateTime . '-' . auth()->user()->id;
                $order_details['receipt'] = 'wallet-' . $currentDateTime . '-' . auth()->user()->id
                    . CommonHelper::rechargeCountrySuffix($countryId);
            }

            $paytabs_profile_id = $gateways['paytabs_profile_id'] ?? '';
            $paytabs_secret_key = $gateways['paytabs_secret_key'] ?? '';
            $paytabs_mode = $gateways['paytabs_mode'] ?? '';
            $url = $paytabs_mode === 'production' ? 'https://www.paytabs.com/apiv2/create_pay_page' : 'https://secure-global.paytabs.com/payment/request';

            $response = Http::withHeaders([
                'authorization' => $paytabs_secret_key,
                'content-type' => 'application/json'
            ])->post($url, [
                'profile_id' => $paytabs_profile_id,
                'tran_type' => 'sale',
                'tran_class' => 'ecom',
                'cart_id' => $order_details['receipt'],
                'cart_description' => 'Paytabs',
                'cart_currency' => $currencyCode ?: 'INR',
                'cart_amount' => $order_amount,
                'callback' => route('paytabs.callback'),
                'return' =>  route('paytabs.redirect', ['order' => $order_details['receipt']]),
                'hide_shipping' => true,
                'hide_billing' => true
            ]);

            if ($response->successful()) {
                $data = $response->json();
                return [
                    'redirectUrl' => $data['redirect_url'],
                ];
            } else {
                $response->json();
            }
        } catch (\Exception $e) {
            Log::error('Error in createOrderonPayTabs: ' . $e->getMessage());
            return [
                'error' => true,
                'message' => $e->getMessage(),
            ];
        }
    }
}
