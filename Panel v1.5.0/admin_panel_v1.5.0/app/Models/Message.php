<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    public const SENDER_ADMIN = 'admin';
    public const SENDER_CUSTOMER = 'customer';
    public const SENDER_DELIVERY_BOY = 'delivery_boy';

    protected $fillable = [
        'conversation_id',
        'sender_type',
        'sender_id',
        'message',
        'attachment',
        'read_at',
    ];

    protected $casts = [
        'conversation_id' => 'integer',
        'sender_id'       => 'integer',
        'read_at'         => 'datetime',
    ];

    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }
}
