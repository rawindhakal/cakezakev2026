<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

/** Admin CRUD for the gifting lookups: occasions, relationships, delivery types. */
class GiftingApiController extends Controller
{
    private const TYPES = [
        'occasions' => ['occasions', ['occasion_date']],
        'relationships' => ['relationships', []],
        'delivery_types' => ['gift_delivery_types', ['lead_minutes', 'extra_charge', 'time_window', 'description']],
    ];

    private function table(string $type): array
    {
        abort_unless(isset(self::TYPES[$type]), 404);
        return self::TYPES[$type];
    }

    public function list(Request $request, string $type)
    {
        [$table] = $this->table($type);
        $rows = DB::table($table)->orderBy('sort_order')->orderBy('name')->get();
        $counts = [];
        $col = $type === 'delivery_types' ? 'delivery_types' : $type;
        foreach ($rows as $r) {
            $counts[$r->id] = DB::table('products')->whereJsonContains($col, $r->slug)->count();
        }
        foreach ($rows as $r) {
            $r->products_count = $counts[$r->id];
        }
        return CommonHelper::responseWithData($rows, $rows->count());
    }

    public function save(Request $request, string $type)
    {
        return $this->store($request, $type, null);
    }

    public function update(Request $request, string $type)
    {
        return $this->store($request, $type, (int) $request->input('id'));
    }

    private function store(Request $request, string $type, ?int $id)
    {
        [$table, $extra] = $this->table($type);
        $v = Validator::make($request->all(), [
            'name' => 'required|string|max:191',
            'slug' => 'nullable|string|max:191',
            'sort_order' => 'nullable|integer|min:0',
            'status' => 'nullable|boolean',
            'lead_minutes' => 'nullable|integer|min:0',
            'extra_charge' => 'nullable|numeric|min:0',
            'image' => 'nullable|image|max:4096',
        ]);
        if ($v->fails()) {
            return CommonHelper::responseError($v->errors()->first());
        }
        $slug = Str::slug($request->input('slug') ?: $request->input('name'));
        $dup = DB::table($table)->where('slug', $slug)->when($id, fn ($q) => $q->where('id', '!=', $id))->exists();
        if ($dup) {
            return CommonHelper::responseError('Slug already exists.');
        }
        $data = [
            'name' => $request->input('name'), 'slug' => $slug,
            'sort_order' => (int) $request->input('sort_order', 0),
            'status' => $request->has('status') ? (int) $request->boolean('status') : 1,
            'updated_at' => now(),
        ];
        foreach ($extra as $f) {
            if ($request->has($f)) {
                $data[$f] = $request->input($f) === '' ? null : $request->input($f);
            }
        }
        if ($request->hasFile('image')) {
            $data['image'] = $request->file('image')->store($table, 'public');
        }
        if ($id) {
            DB::table($table)->where('id', $id)->update($data);
        } else {
            $data['created_at'] = now();
            $id = DB::table($table)->insertGetId($data);
        }
        return CommonHelper::responseWithData(DB::table($table)->find($id));
    }

    public function delete(Request $request, string $type)
    {
        [$table] = $this->table($type);
        DB::table($table)->where('id', (int) $request->input('id'))->delete();
        return CommonHelper::responseSuccess('Deleted');
    }
}
