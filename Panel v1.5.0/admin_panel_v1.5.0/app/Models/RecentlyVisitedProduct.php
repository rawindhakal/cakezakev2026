<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RecentlyVisitedProduct extends Model
{
    use HasFactory;

    // Table name
    protected $table = 'recently_visited_products';

    // Fillable fields
    protected $fillable = [
        'user_id',
        'product_id',
        'visited_at'
    ];

    // Cast visited_at as datetime
    protected $casts = [
        'visited_at' => 'datetime',
    ];

    // Relationship with User model
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Relationship with Product model
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
