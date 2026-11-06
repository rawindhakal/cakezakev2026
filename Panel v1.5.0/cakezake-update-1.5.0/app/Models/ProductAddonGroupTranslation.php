<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductAddonGroupTranslation extends Model
{
    use HasFactory;

    protected $table = 'product_addon_group_translations';

    protected $fillable = [
        'addon_group_id',
        'language_id',
        'name',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function addonGroup()
    {
        return $this->belongsTo(ProductAddonGroup::class, 'addon_group_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
