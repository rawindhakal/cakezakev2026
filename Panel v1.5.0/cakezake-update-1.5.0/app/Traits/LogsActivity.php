<?php

namespace App\Traits;

use App\Services\ActivityLogger;

/**
 * Records create / update / delete on a model into the audit trail.
 *
 * Built on Laravel's own Eloquent model events — no package, no observers to
 * register. Add the trait to a model and its changes are logged:
 *
 *     class Product extends Model { use LogsActivity; }
 *
 * A model can opt out of specific events:
 *
 *     protected static array $activityEvents = ['created', 'deleted'];
 *
 * @mixin \Illuminate\Database\Eloquent\Model
 *     The trait is only ever used inside an Eloquent model; without this the
 *     analyser cannot resolve Model::registerModelEvent() and flags it undefined.
 */
trait LogsActivity
{
    public static function bootLogsActivity(): void
    {
        foreach (static::activityEvents() as $event) {
            static::registerModelEvent(self::eloquentEventFor($event), function ($model) use ($event) {
                if (!$model->shouldLogActivity()) {
                    return;
                }
                ActivityLogger::logModel($event, $model);
            });
        }
    }

    /** Eloquent hook that corresponds to each audit event. */
    private static function eloquentEventFor(string $event): string
    {
        // `updated`/`created` fire after the write, so the model holds final state;
        // `deleting` is used so the row's attributes are still available to log.
        return match ($event) {
            'deleted' => 'deleting',
            default => $event,
        };
    }

    /** Events this model records; override per model to narrow. */
    protected static function activityEvents(): array
    {
        // property_exists, not ??: reading an undefined static property is a fatal.
        return property_exists(static::class, 'activityEvents')
            ? static::$activityEvents
            : ['created', 'updated', 'deleted'];
    }

    /**
     * Escape hatch for models that should skip logging in certain states —
     * e.g. high-churn background writes. Override per model.
     */
    public function shouldLogActivity(): bool
    {
        return true;
    }
}
