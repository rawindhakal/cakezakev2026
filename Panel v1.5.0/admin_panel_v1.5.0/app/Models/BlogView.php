<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BlogView extends Model
{
    use HasFactory;

    protected $table = 'blog_views';

    public $timestamps = false;

    protected $primaryKey = ['blog_id', 'ip_address'];

    public $incrementing = false;

    protected $fillable = [
        'blog_id',
        'ip_address'
    ];
    public function blog()
    {
        return $this->belongsTo(Blog::class);
    }
}
