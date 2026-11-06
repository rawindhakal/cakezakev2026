<?php

namespace App\Models;

use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class Zone extends Model
{
    use HasFactory, HasTranslations, LogsActivity;

    /** A zone serves one channel, or both from a single boundary. */
    public const CHANNEL_QUICK     = 'quick';
    public const CHANNEL_ECOMMERCE = 'ecommerce';
    public const CHANNEL_BOTH      = 'both';

    public const CHANNELS = [self::CHANNEL_QUICK, self::CHANNEL_ECOMMERCE, self::CHANNEL_BOTH];

    /** The two real channels — 'both' is a shorthand for serving each of these. */
    public const REAL_CHANNELS = [self::CHANNEL_QUICK, self::CHANNEL_ECOMMERCE];

    /** How an ecommerce parcel may leave this zone. */
    public const DELIVERY_COURIER         = 'courier';
    public const DELIVERY_BOY             = 'delivery_boy';
    public const DELIVERY_MANUAL_TRACKING = 'manual_tracking';

    public const DELIVERY_METHODS = [self::DELIVERY_COURIER, self::DELIVERY_BOY, self::DELIVERY_MANUAL_TRACKING];

    protected $table = 'zones';

    protected $guarded = [];

    protected $casts = [
        'polygon_boundary_quick'       => 'array',
        'polygon_boundary_ecommerce'   => 'array',
        'surge_slots'                  => 'array',
        'additional_charges_quick'     => 'array',
        'additional_charges_ecommerce' => 'array',
        'slab_pricing'                 => 'array',
        'city_pricing'                 => 'array',
        'area_pricing'                 => 'array',
        'ecommerce_delivery_methods'   => 'array',
        'status'                       => 'integer',
    ];

    protected $translatable = [
        'surge_labels',
        'additional_charge_names_quick',
        'additional_charge_names_ecommerce',
    ];

    protected $translationModel = 'ZoneTranslation';

    protected $translationForeignKey = 'zone_id';

    protected $hidden = ['created_at', 'updated_at'];

    public function translations()
    {
        return $this->hasMany(ZoneTranslation::class, 'zone_id');
    }

    public function country()
    {
        return $this->belongsTo(Country::class, 'country_id');
    }

    public function branches()
    {
        return $this->hasMany(Branch::class, 'zone_id');
    }

    public function servesChannel(?string $channel): bool
    {
        if ($channel === null || !in_array($channel, self::REAL_CHANNELS, true)) {
            return true;
        }
        return $this->sales_channel === $channel || $this->sales_channel === self::CHANNEL_BOTH;
    }

    /** The real channels this zone serves: ['quick'], ['ecommerce'], or both. */
    public function servedChannels(): array
    {
        return $this->sales_channel === self::CHANNEL_BOTH
            ? self::REAL_CHANNELS
            : [$this->sales_channel];
    }

    /**
     * The catchment for a channel. Falls back to the other channel's boundary when the
     * asked-for one hasn't been drawn, so a half-configured zone still resolves.
     */
    public function polygonFor(?string $channel): ?array
    {
        $quick = $this->polygon_boundary_quick;
        $ecom  = $this->polygon_boundary_ecommerce;

        $preferred = $channel === self::CHANNEL_ECOMMERCE ? $ecom : $quick;
        $other     = $channel === self::CHANNEL_ECOMMERCE ? $quick : $ecom;

        if (is_array($preferred) && !empty($preferred)) {
            return $preferred;
        }
        // Only fall back when no channel was specified — a channel-scoped lookup must
        // not match against the other channel's (differently sized) catchment.
        if ($channel === null && is_array($other) && !empty($other)) {
            return $other;
        }
        return null;
    }

    /** Flat additional charges for a channel (both channels support them). */
    /**
     * Does one additional-charge row apply to this delivery type?
     */
    public function chargeAppliesTo(array $row, string $deliveryType): bool
    {
        $appliesTo = $row['applies_to'] ?? 'delivery';

        return $appliesTo === 'both' || $appliesTo === $deliveryType;
    }

    public function additionalChargesFor(?string $channel): array
    {
        $field = $channel === self::CHANNEL_ECOMMERCE
            ? 'additional_charges_ecommerce'
            : 'additional_charges_quick';

        return is_array($this->$field) ? $this->$field : [];
    }

    /**
     * Constrain a query to zones serving $channel — 'both' zones always qualify.
     * Use this instead of where('sales_channel', $channel), which silently hides them.
     */
    public function scopeServing($query, ?string $channel)
    {
        if ($channel === null || !in_array($channel, self::REAL_CHANNELS, true)) {
            return $query;
        }
        return $query->whereIn('sales_channel', [$channel, self::CHANNEL_BOTH]);
    }

    public function region()
    {
        return $this->belongsTo(Region::class, 'region_id');
    }
    /**
     * The three ways an ecommerce parcel can leave: a courier from a shipping plugin, the
     * zone's own delivery boy, or another courier whose waybill is typed in by hand.
     */
    public function allowedDeliveryMethods(): array
    {
        $stored = $this->ecommerce_delivery_methods;
        $stored = is_array($stored) ? $stored : (array) json_decode((string) $stored, true);
        $allowed = array_values(array_intersect(self::DELIVERY_METHODS, $stored));

        // Nothing chosen means nothing was ever restricted: all three doors are open.
        return $allowed ?: self::DELIVERY_METHODS;
    }

    public function allowsDeliveryMethod(string $method): bool
    {
        return in_array($method, $this->allowedDeliveryMethods(), true);
    }

    /**
     * Is a courier the only door out of this zone?
     *
     * Asked of the zone's own choice rather than of the pricing strategy, because a zone
     * can price from a carrier's quote and still put its own rider on the parcel. Only
     * here does an unserviceable pincode have to become a refused order.
     */
    public function deliversByCourierOnly(): bool
    {
        return $this->allowedDeliveryMethods() === [self::DELIVERY_COURIER];
    }
}
