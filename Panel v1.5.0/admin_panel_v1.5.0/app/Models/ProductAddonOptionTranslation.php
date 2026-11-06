<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductAddonOptionTranslation extends Model
{
    use HasFactory;

    protected $table = 'product_addon_option_translations';

    protected $fillable = [
        'addon_option_id',
        'language_id',
        'name',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function addonOption()
    {
        return $this->belongsTo(ProductAddonOption::class, 'addon_option_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
