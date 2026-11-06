<?php

namespace App\Models;

use App\Traits\LogsActivity;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * WHAT a jurisdiction charges for a tax category.
 *
 * A rule is scoped to a country, optionally narrowed to one region, and optionally
 * to one tax category (NULL category = "everything not otherwise covered"). It holds
 * no rate of its own — the rate is the sum of its components, which is what lets
 * India express CGST 9 + SGST 9 and IGST 18 as two rules over the same 18%.
 *
 * A rate change is made by editing the rule; past orders keep the rate they were
 * charged because `order_item_taxes` froze it at order time.
 *
 * `place_of_supply`:
 *   any   — jurisdiction makes no intra/inter distinction (most countries)
 *   intra — branch region == buyer region
 *   inter — branch region != buyer region
 */
class TaxRule extends Model
{
    use HasFactory, LogsActivity;

    protected $table = 'tax_rules';
    protected $guarded = [];

    protected $casts = [
        'country_id'         => 'integer',
        'region_id'          => 'integer',
        'tax_category_id'    => 'integer',
        'status'             => 'integer',
    ];

    public function components()
    {
        return $this->hasMany(TaxRuleComponent::class, 'tax_rule_id')->orderBy('sort_order');
    }

    public function country()
    {
        return $this->belongsTo(Country::class, 'country_id');
    }

    public function region()
    {
        return $this->belongsTo(Region::class, 'region_id');
    }

    public function taxCategory()
    {
        return $this->belongsTo(TaxCategory::class, 'tax_category_id');
    }

    /** Combined rate of every component. This is the figure the cart quotes. */
    public function totalRate(): float
    {
        return round((float) $this->components->sum('rate'), 3);
    }
}
