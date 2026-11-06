<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\DeliveryBoy;
use App\Models\DeliveryBoySettlement;
use Illuminate\Http\Request;

class DeliveryBoySettlementsApiController extends Controller
{

    public function index(Request $request){
        // Header-selected country scopes both the boys and the ledger.
        $countryId = (int) $request->input('country_id', 0);

        $deliveryBoys = DeliveryBoy::withAllTranslations()
            ->when($countryId, fn ($q) => $q->where('country_id', $countryId))
            ->orderBy('id', 'DESC')
            ->get();

        $settlements = DeliveryBoySettlement::settlementHistory(null, $countryId);

        // Attach per-language name translations for the panel.
        $boyIds = $settlements->pluck('delivery_boy_id')->unique()->filter();
        $translated = DeliveryBoy::withAllTranslations()->whereIn('id', $boyIds)->get()->keyBy('id');
        $contacts = CommonHelper::deliveryBoyContactMap($boyIds->all());
        $settlements = $settlements->map(function ($row) use ($translated, $contacts) {
            $boy = $translated[$row['delivery_boy_id']] ?? null;
            $row['translations'] = ($boy && $boy->relationLoaded('translations'))
                ? $boy->getRelation('translations')->toArray()
                : [];
            $c = $contacts[$row['delivery_boy_id']] ?? null;
            $row['profile_url'] = $c['profile_url'] ?? '';
            $row['email']       = $c['email'] ?? '';
            return $row;
        });

        $data = [
            'deliveryBoys' => $deliveryBoys,
            'settlements' => $settlements,
        ];
        return CommonHelper::responseWithData($data);
    }
}
