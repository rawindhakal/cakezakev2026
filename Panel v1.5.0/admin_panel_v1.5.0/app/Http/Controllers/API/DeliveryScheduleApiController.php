<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Services\DeliverySchedulingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/** Admin: delivery time slots, closed dates and scheduling rules. */
class DeliveryScheduleApiController extends Controller
{
    // ── Slots ──────────────────────────────────────────────────────────────
    public function slots()
    {
        $rows = DB::table('delivery_slots')->orderBy('sort_order')->orderBy('start_time')->get()->map(function ($r) {
            $r->start_time = substr($r->start_time, 0, 5);
            $r->end_time = substr($r->end_time, 0, 5);
            $r->upcoming_orders = DB::table('orders')->where('delivery_slot_id', $r->id)
                ->where('delivery_date', '>=', app(DeliverySchedulingService::class)->now()->toDateString())
                ->whereNotIn('active_status', DeliverySchedulingService::RELEASED_STATUSES)->count();
            return $r;
        });
        return CommonHelper::responseWithData($rows, $rows->count());
    }

    public function saveSlot(Request $request)
    {
        $v = Validator::make($request->all(), [
            'label' => 'nullable|string|max:191',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after:start_time',
            'capacity' => 'nullable|integer|min:0',
            'extra_charge' => 'nullable|numeric|min:0',
            'sort_order' => 'nullable|integer|min:0',
            'status' => 'nullable|boolean',
        ]);
        if ($v->fails()) return CommonHelper::responseError($v->errors()->first());
        $fmt = fn ($t) => \Carbon\Carbon::createFromFormat('H:i', $t)->format('h:i A');
        $id = $request->input('id') ? (int) $request->input('id') : null;
        $data = [
            'label' => trim((string) $request->input('label')) ?: $fmt($request->start_time) . ' - ' . $fmt($request->end_time),
            'start_time' => $request->start_time, 'end_time' => $request->end_time,
            'capacity' => $request->filled('capacity') ? (int) $request->capacity : null,
            'extra_charge' => (float) $request->input('extra_charge', 0),
            'sort_order' => (int) $request->input('sort_order', 0),
            'status' => $request->has('status') ? (int) $request->boolean('status') : 1,
            'updated_at' => now(),
        ];
        if ($id) { DB::table('delivery_slots')->where('id', $id)->update($data); }
        else { $data['created_at'] = now(); $id = DB::table('delivery_slots')->insertGetId($data); }
        return CommonHelper::responseWithData(DB::table('delivery_slots')->find($id));
    }

    public function deleteSlot(Request $request)
    {
        $id = (int) $request->input('id');
        $inUse = DB::table('orders')->where('delivery_slot_id', $id)->exists();
        if ($inUse) {
            // Keep history intact: deactivate instead of deleting.
            DB::table('delivery_slots')->where('id', $id)->update(['status' => 0, 'updated_at' => now()]);
            return CommonHelper::responseSuccess('Slot has orders, so it was deactivated instead of deleted.');
        }
        DB::table('delivery_slots')->where('id', $id)->delete();
        DB::table('delivery_blackout_dates')->where('slot_id', $id)->delete();
        return CommonHelper::responseSuccess('Deleted');
    }

    // ── Closed dates ───────────────────────────────────────────────────────
    public function blackouts()
    {
        $rows = DB::table('delivery_blackout_dates as b')->leftJoin('delivery_slots as s', 's.id', '=', 'b.slot_id')
            ->orderBy('b.date')->get(['b.id', 'b.date', 'b.slot_id', 'b.reason', 's.label as slot_label']);
        return CommonHelper::responseWithData($rows, $rows->count());
    }

    public function saveBlackout(Request $request)
    {
        $v = Validator::make($request->all(), [
            'date' => 'required|date_format:Y-m-d', 'date_to' => 'nullable|date_format:Y-m-d|after_or_equal:date',
            'slot_id' => 'nullable|integer', 'reason' => 'nullable|string|max:191',
        ]);
        if ($v->fails()) return CommonHelper::responseError($v->errors()->first());
        $from = \Carbon\Carbon::parse($request->date); $to = \Carbon\Carbon::parse($request->input('date_to', $request->date));
        if ($from->diffInDays($to) > 120) return CommonHelper::responseError('Range too long (max 120 days).');
        $slot = $request->filled('slot_id') ? (int) $request->slot_id : null;
        for ($d = $from->copy(); $d->lte($to); $d->addDay()) {
            DB::table('delivery_blackout_dates')->updateOrInsert(['date' => $d->toDateString(), 'slot_id' => $slot],
                ['reason' => $request->input('reason'), 'created_at' => now(), 'updated_at' => now()]);
        }
        return CommonHelper::responseSuccess('Saved');
    }

    public function deleteBlackout(Request $request)
    {
        DB::table('delivery_blackout_dates')->where('id', (int) $request->input('id'))->delete();
        return CommonHelper::responseSuccess('Deleted');
    }

    // ── Rules ──────────────────────────────────────────────────────────────
    public function settings()
    {
        return CommonHelper::responseWithData(app(DeliverySchedulingService::class)->settings());
    }

    public function saveSettings(Request $request)
    {
        $v = Validator::make($request->all(), [
            'required' => 'nullable|boolean', 'max_advance_days' => 'required|integer|min:1|max:365', 'min_lead_minutes' => 'required|integer|min:0|max:1440',
        ]);
        if ($v->fails()) return CommonHelper::responseError($v->errors()->first());
        foreach (['scheduling_required' => $request->boolean('required') ? '1' : '0', 'scheduling_max_advance_days' => (string) (int) $request->max_advance_days,
                  'scheduling_min_lead_minutes' => (string) (int) $request->min_lead_minutes] as $k => $val) {
            DB::table('settings')->updateOrInsert(['variable' => $k], ['value' => $val]);
        }
        return CommonHelper::responseWithData(app(DeliverySchedulingService::class)->settings());
    }
}
