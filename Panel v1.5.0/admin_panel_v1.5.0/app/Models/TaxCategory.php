<?php

namespace App\Models;

use App\Traits\LogsActivity;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TaxCategory extends Model
{
    use HasFactory, LogsActivity;

    protected $table = 'tax_categories';
    protected $guarded = [];

    protected $casts = ['status' => 'integer'];

    public function rules()
    {
        return $this->hasMany(TaxRule::class, 'tax_category_id');
    }
}
