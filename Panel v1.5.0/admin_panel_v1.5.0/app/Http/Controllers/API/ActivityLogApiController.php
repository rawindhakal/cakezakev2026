<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Read-only view over the audit trail. Entries are written by Laravel's model
 * and auth events (see App\Services\ActivityLogger) and are never edited here —
 * only listed, filtered and pruned.
 */
class ActivityLogApiController extends Controller
{
    public function index(Request $request)
    {
        $limit = (int) $request->input('limit', 15);
        $limit = $limit > 0 ? min($limit, 200) : 15;
        $offset = max(0, (int) $request->input('offset', 0));

        $query = ActivityLog::query()->orderByDesc('id');

        if ($request->filled('log_name')) {
            $query->where('log_name', $request->input('log_name'));
        }
        if ($request->filled('event')) {
            $query->where('event', $request->input('event'));
        }
        if ($request->filled('subject_type')) {
            // The UI sends short names ("Product"); rows store the FQCN.
            $query->where('subject_type', 'App\\Models\\' . $request->input('subject_type'));
        }
        if ($request->filled('causer_id')) {
            $query->where('causer_id', (int) $request->input('causer_id'));
        }
        if ($request->filled('start_date')) {
            $query->where('created_at', '>=', Carbon::parse($request->input('start_date'))->startOfDay());
        }
        if ($request->filled('end_date')) {
            $query->where('created_at', '<=', Carbon::parse($request->input('end_date'))->endOfDay());
        }
        if ($request->filled('search')) {
            $term = '%' . trim((string) $request->input('search')) . '%';
            $query->where(function ($q) use ($term) {
                $q->where('description', 'like', $term)
                    ->orWhere('subject_label', 'like', $term)
                    ->orWhere('causer_name', 'like', $term)
                    ->orWhere('ip_address', 'like', $term);
            });
        }

        $total = (clone $query)->count();
        $rows = $query->offset($offset)->limit($limit)->get();

        return CommonHelper::responseWithData($rows->map(fn (ActivityLog $l) => $this->shape($l))->values(), $total);
    }

    /** Filter options, derived from what has actually been logged. */
    public function filters()
    {
        return CommonHelper::responseWithData([
            'log_names' => ActivityLog::distinct()->orderBy('log_name')->pluck('log_name')->filter()->values(),
            'events' => ActivityLog::distinct()->orderBy('event')->pluck('event')->filter()->values(),
            'subject_types' => ActivityLog::distinct()->whereNotNull('subject_type')
                ->pluck('subject_type')->map(fn ($t) => class_basename($t))->unique()->sort()->values(),
            'causers' => ActivityLog::whereNotNull('causer_id')
                ->select('causer_id', 'causer_name')->distinct()->orderBy('causer_name')->get()
                ->map(fn ($c) => ['id' => (int) $c->causer_id, 'name' => $c->causer_name ?: ('#' . $c->causer_id)])
                ->unique('id')->values(),
        ]);
    }

    /** Prune old entries so the trail cannot grow without bound. */
    public function clear(Request $request)
    {
        $days = (int) $request->input('older_than_days', 0);

        $query = ActivityLog::query();
        if ($days > 0) {
            $query->where('created_at', '<', Carbon::now()->subDays($days));
        }
        $deleted = $query->delete();

        return CommonHelper::responseSuccessWithData('activity_logs_cleared', ['deleted' => $deleted]);
    }

    private function shape(ActivityLog $log): array
    {
        return [
            'id' => (int) $log->id,
            'log_name' => $log->log_name,
            'event' => $log->event,
            'description' => $log->description,
            'subject_type' => $log->subject_name,
            'subject_id' => $log->subject_id,
            'subject_label' => $log->subject_label,
            'causer_name' => $log->causer_name,
            'causer_role' => $log->causer_role,
            'causer_id' => $log->causer_id,
            'properties' => $log->properties,
            // Old/new pairs, ready to render as a diff table.
            'changes' => $this->changes($log),
            'ip_address' => $log->ip_address,
            'method' => $log->method,
            'url' => $log->url,
            'created_at' => $log->getRawOriginal('created_at'),
        ];
    }

    /** Flatten properties into [{field, old, new}] for the detail view. */
    private function changes(ActivityLog $log): array
    {
        $props = $log->properties ?? [];
        $new = $props['attributes'] ?? [];
        $old = $props['old'] ?? [];
        if (!is_array($new)) {
            return [];
        }

        $out = [];
        foreach ($new as $field => $value) {
            $out[] = [
                'field' => $field,
                'old' => $old[$field] ?? null,
                'new' => $value,
            ];
        }

        return $out;
    }
}
