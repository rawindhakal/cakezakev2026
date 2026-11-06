<?php

namespace App\Http\Controllers\API;

use App\Services\Shipping\HandlesReturnPickups;
use App\Plugins\Registries\ShippingProviderRegistry;
use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\ReturnRequest;
use App\Services\Shipping\CourierReturnStatusService;
use App\Services\Shipping\ReturnShipmentService;
use Illuminate\Http\Request;

/**
 * Having a courier collect a return.
 *
 * Mirrors `orders/shipping/*` and sits under `return_requests/` so EnsureBranchScope gates
 * it on the same permissions as the rest of the returns screen. With no plugin installed
 * every call answers "no provider" and the panel offers only a rider or manual tracking.
 */
class ReturnShippingApiController extends Controller
{
    public function __construct(private ReturnShipmentService $returns) {}

    /** Which carriers could collect a return at all. */
    public function providers(Request $request)
    {
        $registry = app(ShippingProviderRegistry::class);

        $providers = array_values(array_filter(
            array_map(function (array $provider) use ($registry) {
                $instance = $registry->provider($provider['key']);

                // Only a carrier that actually does reverse logistics is offered.
                return $instance instanceof HandlesReturnPickups ? $provider : null;
            }, $registry->describe())
        ));

        return CommonHelper::responseWithData(['providers' => $providers]);
    }

    /** What the panel needs before asking for reverse rates. */
    public function context(Request $request)
    {
        [$return, $error] = $this->target($request);
        if ($error) {
            return CommonHelper::responseError($error);
        }

        $result = $this->returns->context($return, $this->overrides($request));

        // A blocking reason is still useful data — the dialog shows what to fix.
        return CommonHelper::responseWithData($result['data'] ?? []);
    }

    public function quote(Request $request)
    {
        [$return, $error] = $this->target($request);
        if ($error) {
            return CommonHelper::responseError($error);
        }

        $result = $this->returns->quote($return, $request->input('provider'), $this->overrides($request));

        return $result['ok']
            ? CommonHelper::responseWithData($result['data'])
            : CommonHelper::responseError($result['message'] ?? 'could_not_fetch_courier_rates');
    }

    public function create(Request $request)
    {
        [$return, $error] = $this->target($request);
        if ($error) {
            return CommonHelper::responseError($error);
        }

        $result = $this->returns->createPickup(
            $return,
            $request->input('courier_id'),
            $request->input('provider'),
            $this->overrides($request)
        );

        return $result['ok']
            ? CommonHelper::responseSuccessWithData('return_pickup_booked', $result['data'])
            : CommonHelper::responseError($result['message'] ?? 'could_not_book_the_return_pickup');
    }

    public function cancel(Request $request)
    {
        [$return, $error] = $this->target($request);
        if ($error) {
            return CommonHelper::responseError($error);
        }

        $result = $this->returns->cancelPickup($return);

        return $result['ok']
            ? CommonHelper::responseSuccess($result['message'] ?? 'return_pickup_cancelled')
            : CommonHelper::responseError($result['message'] ?? 'could_not_cancel_the_return_pickup');
    }

    /**
     * Ask the carrier where the parcel is now.
     *
     * The webhook is the normal feed; this is the button for when somebody wants to know
     * before the next scan arrives.
     */
    public function track(Request $request)
    {
        [$return, $error] = $this->target($request);
        if ($error) {
            return CommonHelper::responseError($error);
        }
        if (empty($return->tracking_id)) {
            return CommonHelper::responseError('this_return_has_no_tracking_number');
        }

        $provider = app(ShippingProviderRegistry::class)->provider((string) $return->courier_provider);
        if (!$provider) {
            return CommonHelper::responseError('no_shipping_provider_is_available');
        }

        $update = $provider->track((string) $return->tracking_id);
        if (!$update) {
            return CommonHelper::responseError('the_courier_had_no_update_for_this_parcel');
        }

        $result = app(CourierReturnStatusService::class)->apply($update, [(int) $return->id]);

        return CommonHelper::responseSuccessWithData('tracking_refreshed', [
            'status'         => $update->status,
            'carrier_status' => $update->carrierStatus,
            'applied'        => $result['applied'],
            'return_status'  => (int) $return->fresh()->status,
        ]);
    }

    /* ---------------------------------------------------------------- helpers */

    /** @return array{0:?ReturnRequest, 1:?string} */
    private function target(Request $request): array
    {
        $id = (int) $request->input('return_request_id', $request->input('id', 0));
        if ($id <= 0) {
            return [null, 'return_request_not_found'];
        }

        $return = ReturnRequest::find($id);

        return $return ? [$return, null] : [null, 'return_request_not_found'];
    }

    /**
     * The parcel figures the admin corrected, bounded so a typo cannot be sent.
     *
     * Same rule as the forward dialog: anything outside 0–300 is ignored rather than
     * clamped, because a clamped 5000 is still a wrong parcel.
     */
    private function overrides(Request $request): array
    {
        $parcel = (array) $request->input('parcel', []);
        $overrides = [];

        foreach (['weight', 'length', 'breadth', 'height'] as $field) {
            if (!isset($parcel[$field]) || $parcel[$field] === '' || $parcel[$field] === null) {
                continue;
            }
            $value = (float) $parcel[$field];
            if ($value > 0 && $value <= 300) {
                $overrides[$field] = $value;
            }
        }

        return $overrides;
    }
}
