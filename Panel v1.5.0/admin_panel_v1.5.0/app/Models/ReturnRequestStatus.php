<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ReturnRequestStatus extends Model
{
    use HasFactory;

    protected $guarded = [];

    public function returnRequest()
    {
        return $this->belongsTo(ReturnRequest::class);
    }
}
