<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * One head inside a rule: CGST 9%, SGST 9%, IGST 18%, VAT 5%, "County Tax" 1.5%.
 * Components are ADDITIVE and all apply to the same taxable base — never compounded.
 */
class TaxRuleComponent extends Model
{
    use HasFactory;

    protected $table = 'tax_rule_components';
    public $timestamps = false;
    protected $guarded = [];

    protected $casts = [
        'tax_rule_id' => 'integer',
        'rate'        => 'float',
        'sort_order'  => 'integer',
    ];

    public function rule()
    {
        return $this->belongsTo(TaxRule::class, 'tax_rule_id');
    }
}
