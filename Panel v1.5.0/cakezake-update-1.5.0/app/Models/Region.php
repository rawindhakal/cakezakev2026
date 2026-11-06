<?php

namespace App\Models;

use App\Traits\HasTranslations;
use App\Traits\LogsActivity;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A country subdivision: state, province, emirate, territory.
 *
 * `code` is the ISO-3166-2 subdivision code ('IN-MH') and is what the import
 * datasets key on. `tax_code` is the jurisdiction's own code where one exists —
 * India's GST state code '27' — and is blank everywhere it doesn't. Nothing in
 * the engine branches on either; they are printed and matched, never switched on.
 */
class Region extends Model
{
    use HasFactory, HasTranslations, LogsActivity;

    protected $table = 'regions';
    protected $guarded = [];

    protected $casts = [
        'country_id' => 'integer',
        'status'     => 'integer',
    ];

    protected $translatable = ['name'];
    protected $translationModel = 'RegionTranslation';
    protected $translationForeignKey = 'region_id';

    protected $appends = ['translations'];

    public function translations()
    {
        return $this->hasMany(RegionTranslation::class, 'region_id');
    }

    public function country()
    {
        return $this->belongsTo(Country::class, 'country_id');
    }

    /** Parsed once per request; the file is a static seed list that never changes at runtime. */
    private static ?array $datasetCache = null;

    /**
     * The shipped subdivision list for a country code, or [] when none exists.
     *
     * Lives in one compact file (config/states.json) keyed by ISO alpha-2, rather than
     * 225 separate files: the same 5,060 subdivisions in a third of the space, and the
     * import screens only ever need one country's slice. Keys are short on disk
     * (n/c/t/y) and expanded here, so callers see normal field names.
     *
     * This file is only a SEED. Once a country is imported its regions live in the
     * `regions` table and are edited there; nothing reads this at request time.
     */
    public static function dataset(string $countryCode): array
    {
        if (self::$datasetCache === null) {
            $file = config_path('states.json');
            self::$datasetCache = is_file($file)
                ? (json_decode((string) file_get_contents($file), true) ?: [])
                : [];
        }

        $rows = self::$datasetCache[strtoupper(trim($countryCode))] ?? [];

        return array_map(fn ($row) => [
            'name'     => $row['n'] ?? '',
            'code'     => $row['c'] ?? '',
            'tax_code' => $row['t'] ?? null,
            'type'     => $row['y'] ?? 'state',
        ], $rows);
    }

    /**
     * Create regions for a country from the shipped dataset.
     *
     * $codes null = every subdivision the dataset carries (what a fresh country import
     * does, so the country is immediately usable); an array = only those codes.
     * Existing codes are skipped, so this is safe to run again.
     *
     * Returns how many rows were actually created.
     */
    public static function importFromDataset(int $countryId, string $countryCode, ?array $codes = null, ?int $languageId = null): int
    {
        $dataset = self::dataset($countryCode);
        if (empty($dataset)) {
            return 0;
        }
        if ($codes !== null) {
            $wanted = array_flip(array_map('strval', $codes));
            $dataset = array_filter($dataset, fn ($row) => isset($wanted[$row['code'] ?? '']));
        }
        if (empty($dataset)) {
            return 0;
        }

        $existing = self::where('country_id', $countryId)->pluck('code')->filter()->flip();
        $imported = 0;

        foreach ($dataset as $row) {
            $code = $row['code'] ?? null;
            if (!$code || isset($existing[$code])) {
                continue;
            }
            $region = new self();
            $region->country_id = $countryId;
            $region->name = $row['name'] ?? $code;
            $region->code = $code;
            $region->tax_code = $row['tax_code'] ?? null;
            $region->type = $row['type'] ?? 'state';
            $region->status = 1;
            $region->save();

            if ($languageId) {
                $region->saveTranslation($languageId, ['name' => $region->name]);
            }
            $imported++;
        }

        return $imported;
    }

    /** "27-Maharashtra" for India, "Dubai" where there is no tax code. */
    public function placeOfSupplyLabel(): string
    {
        return $this->tax_code ? $this->tax_code . '-' . $this->name : (string) $this->name;
    }
}
