<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Country;
use App\Models\DeliveryBoySalary;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class DeliveryBoySalaryApiController extends Controller
{
  
    public function getList(Request $request)
    {
        $limit     = (int) $request->input('limit', 10);
        $offset    = (int) $request->input('offset', 0);
        $search    = trim((string) $request->input('search', ''));
        $countryId = (int) $request->input('country_id', 0);
        $deliveryBoyId = (int) $request->input('delivery_boy_id', 0);
        $startDate = trim((string) $request->input('start_date', ''));
        $endDate   = trim((string) $request->input('end_date', ''));

        $query = DeliveryBoySalary::query()
            ->from('delivery_boy_salaries as ds')
            ->leftJoin('delivery_boys as db', 'db.id', '=', 'ds.delivery_boy_id')
            ->when($countryId, fn ($q) => $q->where('db.country_id', $countryId))
            ->when($deliveryBoyId, fn ($q) => $q->where('ds.delivery_boy_id', $deliveryBoyId))
            ->when($startDate !== '', fn ($q) => $q->whereDate('ds.paid_on', '>=', $startDate))
            ->when($endDate !== '', fn ($q) => $q->whereDate('ds.paid_on', '<=', $endDate))
            ->when($search !== '', function ($q) use ($search) {
                $like = '%' . $search . '%';
                $q->where(function ($w) use ($like) {
                    $w->where('db.name', 'like', $like)
                        ->orWhere('db.mobile', 'like', $like)
                        ->orWhere('ds.note', 'like', $like)
                        ->orWhere('ds.amount', 'like', $like);
                });
            })
            ->select(
                'ds.*',
                'db.name as delivery_boy_name',
                'db.mobile as delivery_boy_mobile',
                'db.country_code as delivery_boy_country_code'
            );


        $total = (clone $query)->count();

        $rows = $query->orderByDesc('ds.id')
            ->offset($offset)->limit($limit > 0 ? $limit : 10)
            ->get();

        // Header country's currency for the amount column.
        $country = $countryId ? Country::find($countryId) : null;
        $currency = $country->currency ?? null;

        // Rider photo + email for the identity block beside the name.
        $contacts = CommonHelper::deliveryBoyContactMap($rows->pluck('delivery_boy_id')->all());

        $data = $rows->map(function ($r) use ($currency, $contacts) {
            $c = $contacts[$r->delivery_boy_id] ?? null;
            return [
                'id'              => (int) $r->id,
                'delivery_boy_id' => (int) $r->delivery_boy_id,
                'name'            => $r->delivery_boy_name,
                'mobile'          => $r->delivery_boy_mobile,
                'country_code'    => $r->delivery_boy_country_code,
                'profile_url'     => $c['profile_url'] ?? '',
                'email'           => $c['email'] ?? '',
                'amount'          => (float) $r->amount,
                'currency'        => $currency,
                'paid_on'         => $r->getRawOriginal('paid_on'),
                'note'            => $r->note,
                'created_at'      => $r->getRawOriginal('created_at'),
            ];
        });

        return CommonHelper::responseWithData($data, $total);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'delivery_boy_id' => 'required|integer|exists:delivery_boys,id',
            'amount'          => 'required|numeric|min:0',
            'paid_on'         => 'required|date',
            'note'            => 'nullable|string|max:1000',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $salary = new DeliveryBoySalary();
        $salary->delivery_boy_id = (int) $request->delivery_boy_id;
        $salary->amount          = (float) $request->amount;
        $salary->paid_on         = $request->paid_on;
        $salary->note            = $request->note;
        $salary->created_by      = auth()->id();
        $salary->save();

        // Tell the delivery boy their salary was paid.
        CommonHelper::sendSalaryPaidNotification($salary->delivery_boy_id, $salary);

        return CommonHelper::responseSuccess('salary_transaction_added_successfully');
    }

    public function update(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'id'              => 'required|integer|exists:delivery_boy_salaries,id',
            'delivery_boy_id' => 'required|integer|exists:delivery_boys,id',
            'amount'          => 'required|numeric|min:0',
            'paid_on'         => 'required|date',
            'note'            => 'nullable|string|max:1000',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $salary = DeliveryBoySalary::find($request->id);
        if (!$salary) {
            return CommonHelper::responseError('salary_transaction_not_found');
        }

        $salary->delivery_boy_id = (int) $request->delivery_boy_id;
        $salary->amount          = (float) $request->amount;
        $salary->paid_on         = $request->paid_on;
        $salary->note            = $request->note;
        $salary->save();

        return CommonHelper::responseSuccess('salary_transaction_updated_successfully');
    }

    public function delete(Request $request)
    {
        $salary = DeliveryBoySalary::find($request->id);
        if (!$salary) {
            return CommonHelper::responseError('salary_transaction_not_found');
        }
        $salary->delete();
        return CommonHelper::responseSuccess('salary_transaction_deleted_successfully');
    }
}
