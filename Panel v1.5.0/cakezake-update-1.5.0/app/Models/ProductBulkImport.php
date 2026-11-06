<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProductBulkImport extends Model
{
    protected $guarded = [];

    protected $casts = [
        'branch_ids' => 'array',
        'errors' => 'array',
        'total_rows' => 'integer',
        'processed_rows' => 'integer',
        'success_count' => 'integer',
    ];
}
