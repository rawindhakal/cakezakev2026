<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

/**
 * The BUYER's tax registration number — what India calls a GSTIN, the EU a VAT number,
 * the UAE a TRN, Australia an ABN and the US an EIN.
 *
 * A business buyer has to be able to put that number on the order, or the invoice it
 * receives is not one it can claim input credit against. The number is always OPTIONAL:
 * most buyers are consumers and have none, so a required field would block the ordinary
 * checkout to serve the rare one.
 *
 * Everything country-specific — whether to ask at all, what to call it, what shape it has —
 * is a column on `countries`, because the scheme follows the BUYER's country, not the
 * branch's. DEFAULTS below is only the seed: an admin editing a country overrides it, and
 * a country that is not listed simply gets the generic wording.
 *
 * The branch side of the same idea already exists as `branches.tax_number` +
 * `branches.tax_registration_type`, snapshotted onto `order_items.branch_tax_number`.
 */
class BuyerTaxIdentity
{
    /**
     * Seed per ISO country code: [label key or literal label, validation regex|null].
     *
     * The regex is a FORMAT check, not proof of registration — only the issuing
     * government can tell you a number is real. It exists to catch the typo, so an
     * invoice is not issued against 14 digits of a 15-digit GSTIN.
     */
    public const DEFAULTS = [
        'IN' => ['GSTIN', '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'],
        'AE' => ['TRN', '^[0-9]{15}$'],
        'SA' => ['VAT Number', '^3[0-9]{14}$'],
        'GB' => ['VAT Number', '^(GB)?([0-9]{9}|[0-9]{12})$'],
        'AU' => ['ABN', '^[0-9]{11}$'],
        'NZ' => ['GST Number', '^[0-9]{8,9}$'],
        'CA' => ['GST/HST Number', '^[0-9]{9}(RT[0-9]{4})?$'],
        'US' => ['EIN', '^[0-9]{2}-?[0-9]{7}$'],
        'SG' => ['GST Registration Number', '^[0-9A-Z]{9,10}$'],
        'ZA' => ['VAT Number', '^4[0-9]{9}$'],
        'MY' => ['SST Number', null],
        'ID' => ['NPWP', '^[0-9]{15,16}$'],
        'PH' => ['TIN', '^[0-9]{9,12}$'],
        'BD' => ['BIN', '^[0-9]{9,13}$'],
        'PK' => ['NTN', '^[0-9]{7,13}$'],
        'LK' => ['VAT Number', null],
        'NP' => ['PAN', '^[0-9]{9}$'],
        'BR' => ['CNPJ', '^[0-9]{14}$'],
        'MX' => ['RFC', '^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$'],
        'JP' => ['Corporate Number', '^T?[0-9]{13}$'],
        'KR' => ['Business Registration Number', '^[0-9]{10}$'],
        'CN' => ['USCC', '^[0-9A-Z]{18}$'],
        'TR' => ['VKN', '^[0-9]{10}$'],
        'RU' => ['INN', '^[0-9]{10}([0-9]{2})?$'],
        'CH' => ['UID', '^(CHE)?[0-9]{9}$'],
        'NO' => ['MVA Number', '^[0-9]{9}(MVA)?$'],
    ];

    /**
     * EU member states, whose VAT number is country prefix + 2-13 alphanumerics.
     * One shared shape rather than 27 near-identical lines — the per-state length rules
     * belong to VIES, which is a lookup, not a regex.
     */
    public const EU_CODES = [
        'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR',
        'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK',
    ];

    public const EU_LABEL = 'VAT Number';
    public const EU_REGEX = '^[A-Z]{2}[0-9A-Z]{2,13}$';

    /** Wording for a country with no scheme of its own — still optional, still collected. */
    public const GENERIC_LABEL = 'Tax Number';

    /** @var array<string,array> */
    private static array $configCache = [];

    /** Seed values for one ISO code: [label, regex|null, enabledByDefault]. */
    public static function seedFor(?string $code): array
    {
        $code = strtoupper(trim((string) $code));

        if (isset(self::DEFAULTS[$code])) {
            return [self::DEFAULTS[$code][0], self::DEFAULTS[$code][1], 1];
        }
        if (in_array($code, self::EU_CODES, true)) {
            return [self::EU_LABEL, self::EU_REGEX, 1];
        }

        // No known scheme: give the country the generic wording but leave the field OFF,
        // so an upgrade never adds a box to a checkout nobody asked for.
        return [self::GENERIC_LABEL, null, 0];
    }

    /**
     * What the apps and the validator need for one country.
     * `enabled` false means the field is not shown and nothing is stored.
     */
    public static function config(?int $countryId): array
    {
        $key = (string) ($countryId ?? 0);
        if (isset(self::$configCache[$key])) {
            return self::$configCache[$key];
        }

        $off = ['enabled' => false, 'label' => self::GENERIC_LABEL, 'regex' => null, 'country_code' => null];
        if (!$countryId) {
            return self::$configCache[$key] = $off;
        }

        $row = DB::table('countries')->where('id', $countryId)
            ->first(['code', 'buyer_tax_enabled', 'buyer_tax_label', 'buyer_tax_regex']);
        if (!$row) {
            return self::$configCache[$key] = $off;
        }

        return self::$configCache[$key] = [
            'enabled'      => (int) ($row->buyer_tax_enabled ?? 0) === 1,
            'label'        => trim((string) ($row->buyer_tax_label ?? '')) ?: self::GENERIC_LABEL,
            'regex'        => trim((string) ($row->buyer_tax_regex ?? '')) ?: null,
            'country_code' => strtoupper(trim((string) ($row->code ?? ''))) ?: null,
        ];
    }

    /**
     * The country whose rules apply to an address.
     *
     * An address names its country three ways and any of them can be the only one
     * present: the region it picked (the most precise — a region belongs to exactly one
     * country), the zone it resolved to, and the plain country text the app sent.
     *
     * @param object|array|null $address
     */
    public static function countryIdForAddress($address): ?int
    {
        $get = function (string $key) use ($address) {
            if (is_array($address)) {
                return $address[$key] ?? null;
            }
            return is_object($address) ? ($address->$key ?? null) : null;
        };

        if ($regionId = (int) ($get('region_id') ?: 0)) {
            $countryId = DB::table('regions')->where('id', $regionId)->value('country_id');
            if ($countryId) {
                return (int) $countryId;
            }
        }

        if ($zoneId = (int) ($get('zone_id') ?: 0)) {
            $countryId = DB::table('zones')->where('id', $zoneId)->value('country_id');
            if ($countryId) {
                return (int) $countryId;
            }
        }

        $name = trim((string) ($get('country') ?: ''));
        if ($name !== '') {
            $countryId = DB::table('countries')
                ->whereRaw('LOWER(name) = ?', [mb_strtolower($name)])
                ->orWhereRaw('LOWER(code) = ?', [mb_strtolower($name)])
                ->value('id');
            if ($countryId) {
                return (int) $countryId;
            }
        }

        return null;
    }

    /** Uppercase and collapse spacing. Punctuation is kept — some schemes use it. */
    public static function normalize(?string $number): string
    {
        $number = preg_replace('/\s+/', '', (string) $number);
        return strtoupper(trim((string) $number));
    }

    /**
     * Validate a buyer-entered number against the country's rule.
     * Returns a ready-to-show message, or null when the number is acceptable.
     * An empty number is always acceptable — the field is optional.
     */
    public static function validate(?int $countryId, ?string $number): ?string
    {
        $number = self::normalize($number);
        if ($number === '') {
            return null;
        }

        $config = self::config($countryId);
        if (!$config['enabled']) {
            return __('tax_number_not_collected_for_this_country');
        }

        $label = $config['label'];

        // Hard storage limit, checked whatever the pattern says.
        if (mb_strlen($number) > 64) {
            return __('tax_number_too_long', ['label' => $label]);
        }

        if (!$config['regex']) {
            return null;
        }

        if (!preg_match('/' . str_replace('/', '\\/', $config['regex']) . '/', $number)) {
            return __('invalid_tax_number', ['label' => $label]);
        }

        // India publishes the GSTIN check digit, so a transposed pair can be caught here
        // rather than by the buyer's accountant three weeks later. Only alongside a
        // pattern, for the reason above.
        if ($config['country_code'] === 'IN' && !self::gstinChecksumValid($number)) {
            return __('invalid_tax_number', ['label' => $label]);
        }

        return null;
    }

    /**
     * GSTIN check digit: base-36 over the first 14 characters, alternating weights 1 and 2,
     * each product folded (quotient + remainder) before summing, and the 15th character is
     * whatever brings the total to a multiple of 36.
     */
    public static function gstinChecksumValid(string $gstin): bool
    {
        $alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        if (strlen($gstin) !== 15) {
            return false;
        }

        $sum = 0;
        for ($i = 0; $i < 14; $i++) {
            $value = strpos($alphabet, $gstin[$i]);
            if ($value === false) {
                return false;
            }
            $product = $value * (($i % 2 === 0) ? 1 : 2);
            $sum += intdiv($product, 36) + ($product % 36);
        }

        $expected = $alphabet[(36 - ($sum % 36)) % 36];

        return $gstin[14] === $expected;
    }
}
