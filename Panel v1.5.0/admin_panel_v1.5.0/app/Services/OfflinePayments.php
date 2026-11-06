<?php

namespace App\Services;

use App\Models\Setting;
use Illuminate\Support\Facades\DB;

/**
 * The only payment methods CakeZake accepts. COD and pay-at-counter are settled in
 * person; eSewa, bank transfer and QR are paid up front by the customer, who uploads
 * proof, and staff verify it by hand in the admin panel.
 */
class OfflinePayments
{
    public const COD = 'COD';
    public const COUNTER = 'PayAtCounter';
    public const ESEWA = 'Esewa';
    public const BANK = 'BankTransfer';
    public const QR = 'QrPayment';

    /** Methods whose payment must be verified by staff. */
    public const MANUAL = [self::ESEWA, self::BANK, self::QR];
    public const ALL = [self::COD, self::COUNTER, self::ESEWA, self::BANK, self::QR];

    private const KEY = 'offline_payments';

    public static function defaults(): array
    {
        return [
            'cod' => ['enabled' => 1],
            'counter' => ['enabled' => 1, 'instructions' => ''],
            'esewa' => ['enabled' => 0, 'esewa_id' => '', 'account_name' => '', 'qr_image' => '', 'instructions' => ''],
            'bank' => ['enabled' => 0, 'bank_name' => '', 'account_name' => '', 'account_number' => '', 'branch' => '', 'instructions' => ''],
            'qr' => ['enabled' => 0, 'qr_image' => '', 'instructions' => ''],
        ];
    }

    /** Flat keys inside countries.payment_gateways that hold the offline settings. */
    private const FIELDS = [
        'cod' => ['enabled' => 'cod_payment_method'],
        'counter' => ['enabled' => 'counter_payment_method', 'instructions' => 'counter_instructions'],
        'esewa' => ['enabled' => 'esewa_payment_method', 'esewa_id' => 'esewa_id', 'account_name' => 'esewa_account_name',
            'qr_image' => 'esewa_qr_image', 'instructions' => 'esewa_instructions'],
        'bank' => ['enabled' => 'bank_payment_method', 'bank_name' => 'bank_name', 'account_name' => 'bank_account_name',
            'account_number' => 'bank_account_number', 'branch' => 'bank_branch', 'instructions' => 'bank_instructions'],
        'qr' => ['enabled' => 'qr_payment_method', 'qr_image' => 'qr_image', 'instructions' => 'qr_instructions'],
    ];

    /** Offline payment settings of one country (they live in countries.payment_gateways). */
    public static function forCountry($country): array
    {
        $gw = is_array($country?->payment_gateways ?? null) ? $country->payment_gateways : [];
        $out = self::defaults();
        foreach (self::FIELDS as $section => $map) {
            foreach ($map as $field => $key) {
                if (!array_key_exists($key, $gw)) continue;
                $out[$section][$field] = $field === 'enabled' ? ((int) $gw[$key] ? 1 : 0) : (string) $gw[$key];
            }
        }
        return $out;
    }

    public static function url(?string $path): string
    {
        return $path ? asset('storage/' . ltrim($path, '/')) : '';
    }

    /** Client-safe view: what the checkout needs to show payment instructions. */
    public static function publicConfig($country): array
    {
        $c = self::forCountry($country);
        $c['esewa']['qr_image'] = self::url($c['esewa']['qr_image']);
        $c['qr']['qr_image'] = self::url($c['qr']['qr_image']);
        return $c;
    }

    public static function enabled(string $method, $country = null): bool
    {
        $c = self::forCountry($country);
        $map = [self::COD => 'cod', self::COUNTER => 'counter', self::ESEWA => 'esewa', self::BANK => 'bank', self::QR => 'qr'];
        return isset($map[$method]) && (int) ($c[$map[$method]]['enabled'] ?? 0) === 1;
    }

    public static function isManual(?string $method): bool
    {
        return in_array($method, self::MANUAL, true);
    }
}
