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

    public static function config(): array
    {
        $raw = DB::table('settings')->where('variable', self::KEY)->value('value');
        $saved = $raw ? (json_decode($raw, true) ?: []) : [];
        $out = self::defaults();
        foreach ($out as $k => $v) {
            $out[$k] = array_merge($v, is_array($saved[$k] ?? null) ? $saved[$k] : []);
        }
        return $out;
    }

    public static function save(array $cfg): void
    {
        $json = json_encode($cfg);
        if (DB::table('settings')->where('variable', self::KEY)->exists()) {
            DB::table('settings')->where('variable', self::KEY)->update(['value' => $json]);
        } else {
            DB::table('settings')->insert(['variable' => self::KEY, 'value' => $json]);
        }
    }

    public static function url(?string $path): string
    {
        return $path ? asset('storage/' . ltrim($path, '/')) : '';
    }

    /** Client-safe view: what the checkout needs to show payment instructions. */
    public static function publicConfig(): array
    {
        $c = self::config();
        $c['esewa']['qr_image'] = self::url($c['esewa']['qr_image']);
        $c['qr']['qr_image'] = self::url($c['qr']['qr_image']);
        return $c;
    }

    public static function enabled(string $method): bool
    {
        $c = self::config();
        $map = [self::COD => 'cod', self::COUNTER => 'counter', self::ESEWA => 'esewa', self::BANK => 'bank', self::QR => 'qr'];
        return isset($map[$method]) && (int) ($c[$map[$method]]['enabled'] ?? 0) === 1;
    }

    public static function isManual(?string $method): bool
    {
        return in_array($method, self::MANUAL, true);
    }
}
