<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationTemplateTranslation extends Model
{
    protected $table = 'notification_template_translations';

    protected $fillable = ['notification_template_id', 'language_id', 'title', 'message'];

    public function notificationTemplate(): BelongsTo
    {
        return $this->belongsTo(NotificationTemplate::class, 'notification_template_id');
    }

    public function language(): BelongsTo
    {
        return $this->belongsTo(Language::class, 'language_id');
    }
}
