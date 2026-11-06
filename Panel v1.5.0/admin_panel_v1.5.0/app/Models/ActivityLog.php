<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/**
 * One audit-trail entry. Written by App\Services\ActivityLogger; never edited
 * afterwards — an audit row that can be changed is not an audit row.
 */
class ActivityLog extends Model
{
    protected $table = 'activity_logs';

    protected $guarded = [];

    protected $casts = [
        'properties' => 'array',
        'subject_id' => 'integer',
        'causer_id' => 'integer',
    ];

    public function subject(): MorphTo
    {
        return $this->morphTo();
    }

    public function causer(): MorphTo
    {
        return $this->morphTo();
    }

    /** Model class short name, e.g. App\Models\Product => Product. */
    public function getSubjectNameAttribute(): string
    {
        return $this->subject_type ? class_basename($this->subject_type) : '';
    }
}
