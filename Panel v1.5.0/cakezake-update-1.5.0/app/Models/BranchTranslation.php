<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BranchTranslation extends Model
{
    use HasFactory;

    protected $table = 'branch_translations';

    protected $fillable = [
        'branch_id',
        'language_id',
        'name',
        'provider',
        'address',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    public function branch()
    {
        return $this->belongsTo(Branch::class, 'branch_id');
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
