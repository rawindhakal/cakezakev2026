<?php

namespace App\Models;

use App\Helpers\CommonHelper;
use App\Helpers\CustomerProductShaper;
use App\Traits\HasTranslations;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use App\Traits\LogsActivity;

class Branch extends Model
{
    use HasFactory, HasTranslations, SoftDeletes, LogsActivity;

    protected $table = 'branches';
    protected $guarded = [];

    protected $casts = [
        'operating_hours' => 'array',
        'zone_id'         => 'integer',
        'status'          => 'integer',
    ];

    protected $translatable = [
        'name',
        'provider',
        'address',
    ];

    protected $translationModel = 'BranchTranslation';
    protected $translationForeignKey = 'branch_id';

    protected $hidden = ['deleted_at'];

    public static $statusActive = 1;
    public static $statusInactive = 0;

    // What the branch offers the customer.
    public const MODE_DELIVERY = 'delivery';
    public const MODE_PICKUP = 'pickup';
    public const MODE_BOTH = 'both';

    /** Can a customer collect from this branch themselves (on $channel, when given)? */
    public function offersPickup(?string $channel = null): bool
    {
        $modes = $this->service_modes ?? self::MODE_DELIVERY;
        if (!in_array($modes, [self::MODE_PICKUP, self::MODE_BOTH], true)) {
            return false;
        }
        if ($channel === null) {
            return true;
        }
        $channels = $this->pickup_channels ?? 'both';

        return $channels === 'both' || $channels === $channel;
    }

    /** Does this branch deliver to the customer's door? */
    public function offersDelivery(): bool
    {
        return in_array($this->service_modes ?? self::MODE_DELIVERY, [self::MODE_DELIVERY, self::MODE_BOTH], true);
    }

    /**
     * What a customer needs to know to collect here — the one shape reused by the cart,
     * the zone endpoint and the order lists.
     */
    public function pickupInfo(): array
    {
        $minutes = (int) ($this->preparation_time ?? 0);

        return [
            'branch_id'            => (int) $this->id,
            'branch_name'          => (string) $this->name,
            'address'             => (string) ($this->formatted_address ?: $this->address),
            'latitude'            => $this->latitude !== null ? (float) $this->latitude : null,
            'longitude'           => $this->longitude !== null ? (float) $this->longitude : null,
            /* Postal parts, for couriers and printed labels. Only the pincode lives on
               the branch; city/state belong to its zone and the country to the zone's
               country, so they are read through rather than duplicated. */
            'pincode'             => (string) ($this->pincode ?? ''),
            'city'                => (string) ($this->zone->city ?? ''),
            'state'               => (string) ($this->zone->state ?? ''),
            'country_code'        => (string) ($this->zone->country->code ?? ''),
            // Carriers' address forms take the country by name, not by code.
            'country_name'        => (string) ($this->zone->country->name ?? ''),
            'contact_number'      => (string) ($this->contact_number ?? ''),
            'email'               => (string) ($this->email ?? ''),
            'preparation_minutes' => $minutes,
            'preparation_time'    => $minutes > 0 ? CustomerProductShaper::formatDeliveryTime($minutes) : '',
            'operating_hours'     => $this->operating_hours ?: (object) [],
            'is_open_now'         => CommonHelper::isBranchOpenNow($this),
        ];
    }

    public function translations()
    {
        return $this->hasMany(BranchTranslation::class, 'branch_id');
    }

    /** All branch-panel login users (admins) belonging to this branch. */
    public function admins()
    {
        return $this->hasMany(Admin::class, 'branch_id');
    }

    /** The primary login admin created with the branch. */
    public function owner()
    {
        return $this->belongsTo(Admin::class, 'owner_admin_id');
    }

    /**
     * A branch has exactly ONE zone. The zone's own sales_channel decides which
     * channel(s) the branch serves — a branch fulfilling both points at a 'both' zone.
     */
    public function zone()
    {
        return $this->belongsTo(Zone::class, 'zone_id');
    }

    /**
     * Constrain a branch query to those serving $channel, via their zone.
     * Replaces the old zoneColumn()/zoneCoalesceSql() pair.
     */
    public function scopeServingChannel($query, ?string $channel)
    {
        if ($channel === null || !in_array($channel, Zone::REAL_CHANNELS, true)) {
            return $query;
        }
        return $query->whereHas('zone', fn ($q) => $q->serving($channel));
    }
}
