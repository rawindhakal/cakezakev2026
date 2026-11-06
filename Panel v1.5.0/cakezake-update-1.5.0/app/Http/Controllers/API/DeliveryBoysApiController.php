<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Admin;
use App\Models\DeliveryBoy;
use App\Models\DeliveryBoyCashCollection;
use App\Models\DeliveryBoySalary;
use App\Models\DeliveryBoySettlement;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusList;
use App\Models\ReturnRequest;
use App\Models\ReturnStatusList;
use App\Models\Role;
use App\Models\WithdrawalRequest;
use App\Services\LanguageService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

class DeliveryBoysApiController extends Controller
{
    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }
    public function getDeliveryBoyBonusSettings()
    {
        $bonus = CommonHelper::getDeliveryBoyBonusSettings();
        if (empty($bonus)) {
            return CommonHelper::responseError("Default bonus not found.");
        }
        return CommonHelper::responseWithData($bonus);
    }

    public function getDeliveryBoy(Request $request)
    {
        $query = DeliveryBoy::withAllTranslations()
            ->with(['admin', 'country:id,currency', 'zone:id,name'])
            ->orderBy('id', 'DESC');

        if ($request->filled('filterStatus')) {
            $query->where('status', $request->filterStatus);
        }
        // Country filter (admin panel dropdown).
        if ($request->filled('country_id')) {
            $query->where('country_id', $request->country_id);
        }

        if ($request->filled('zone_id')) {
            $query->where('zone_id', $request->zone_id);
        }

        // Search across name / mobile / id and the linked admin's email.
        if ($request->filled('search')) {
            $search = trim((string) $request->search);
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('mobile', 'like', "%{$search}%")
                    ->orWhere('id', 'like', "%{$search}%")
                    ->orWhereHas('admin', function ($a) use ($search) {
                        $a->where('email', 'like', "%{$search}%");
                    });
            });
        }

        $deliveryBoys = $query->get();
        foreach ($deliveryBoys as $db) {
            $db->email = $db->admin ? $db->admin->email : '';
        }

        $deliveryBoysForResponse = $deliveryBoys->map(function (DeliveryBoy $db) {
            $row = $db->toArray();
            $rawCreated = $db->getAttributes()['created_at'] ?? null;
            if ($rawCreated !== null && $rawCreated !== '') {
                $row['created_at'] = $rawCreated;
            }
            $rawDob = $db->getAttributes()['dob'] ?? null;
            if ($rawDob !== null && $rawDob !== '') {
                $row['dob'] = $rawDob;
            }
            return $row;
        });

        return CommonHelper::responseWithData($deliveryBoysForResponse);
    }

    private function formatDeliveryBoyData(DeliveryBoy $deliveryBoy, ?string $accessToken = null): array
    {
        $data = $deliveryBoy->makeHidden(['admin', 'translations'])->toArray();
        $data['email'] = $deliveryBoy->admin?->email ?? '';
        if ($accessToken !== null) {
            $data['access_token'] = $accessToken;
        }
        return $data;
    }

    public function edit(Request $request, $id = null)
    {
        $query = DeliveryBoy::withAllTranslations()->with('admin');

        $deliveryBoy = $id !== null
            ? $query->find($id)
            : $query->where('admin_id', $request->user()?->id)->first();

        if (!$deliveryBoy) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }

        DeliveryBoy::setOptimizedResponse(false);

        $data = $this->formatDeliveryBoyData($deliveryBoy);

        $data['translations'] = $deliveryBoy->translations;

        return CommonHelper::responseWithData($data, false);
    }
    public function save(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();

        $translations = $request->translations;
        if (is_string($translations)) {
            $translations = json_decode($translations, true);
        }
        $translations = is_array($translations) ? $translations : null;
        if (!$request->filled('language_id')) {
            $request->merge(['language_id' => $defaultLanguage->id]);
        }

        $rules = [
            'language_id' => 'required|exists:languages,id',
            'name'        => 'required',
            'address'     => 'required',
        ];

        if ($request->language_id == $defaultLanguage->id) {
            $rules = array_merge($rules, [
                'dob' => 'required',
                'mobile' => 'required',
                'email' => 'email|required|unique:admins,email',
                'password' => 'required',
                'confirm_password' => 'required|same:password',
                'country_id' => 'required|exists:countries,id',
                'zone_id'    => 'required|exists:zones,id',
                'ifsc_code' => 'required',
                'bank_name' => 'required',
                'bank_account_number' => 'required',
                'account_name' => 'required',
                'profile' => 'required|image',
                'driving_license' => 'required|file',
                'national_identity_card' => 'required|file',
                'bonus_type' => 'required|in:0,1',
                'return_bonus_type' => 'required|in:0,1',
                'bonus_percentage' => $request->bonus_type == 1 ? 'required|numeric|min:0.1' : 'nullable',
                'return_bonus_percentage' => $request->return_bonus_type == 1 ? 'required|numeric|min:0.1' : 'nullable'
            ]);
        }

        $messages = [
            'zone_id.required'                => __('please_select_a_zone'),
            'zone_id.exists'                  => __('please_select_a_zone'),
            'profile.required'                => __('profile_image_is_required'),
            'profile.image'                   => __('profile_must_be_an_image'),
            'driving_license.required'        => __('driving_license_is_required'),
            'national_identity_card.required' => __('national_identity_card_is_required'),
        ];
        $validator = Validator::make($request->all(), $rules, $messages);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if ($request->language_id != $defaultLanguage->id) {
            return CommonHelper::responseError('default_language_required_first');
        }

        // Mobile length must match the selected country's configured bounds.
        if (($mobErr = CommonHelper::validateMobileForCountry($request->country_id, $request->mobile)) !== null) {
            return CommonHelper::responseError($mobErr);
        }

        if (($pwErr = CommonHelper::validatePasswordPolicy($request->password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }

        DB::beginTransaction();
        try {
            /** Admin */
            $admin = Admin::create([
                'username' => $request->name,
                'email'    => $request->email,
                'password' => bcrypt($request->password),
                'role_id'  => Role::$roleDeliveryBoy,
                'created_by' => 0,
            ]);

            /** DeliveryBoy main table */
            $deliveryBoy = DeliveryBoy::create([
                'admin_id' => $admin->id,
                'country_id' => $request->country_id,
                'zone_id'    => $request->zone_id,
                'name'     => $request->name,
                'address'  => $request->address,
                'other_payment_information' => $request->other_payment_information,
                'mobile'   => $request->mobile,
                'country_code' => $request->country_code,
                'dob'      => $request->dob,
                'bonus_type' => $request->bonus_type ?? 0,
                'bonus_percentage' => $request->bonus_percentage ?? 0,
                'bonus_min_amount' => $request->bonus_min_amount ?? 0,
                'bonus_max_amount' => $request->bonus_max_amount ?? 0,
                'return_bonus_type' => $request->return_bonus_type ?? 0,
                'return_bonus_percentage' => $request->return_bonus_percentage ?? 0,
                'return_bonus_min_amount' => $request->return_bonus_min_amount ?? 0,
                'return_bonus_max_amount' => $request->return_bonus_max_amount ?? 0,
                'ifsc_code' => $request->ifsc_code,
                'bank_name' => $request->bank_name,
                'bank_account_number' => $request->bank_account_number,
                'account_name' => $request->account_name,
                'status'   => DeliveryBoy::$statusActive,
            ]);


            /** Files */
            if ($request->hasFile('profile')) {
                $deliveryBoy->profile = CommonHelper::uploadFile($request, 'profile', 'delivery_boy/profile');
            }
            if ($request->hasFile('driving_license')) {
                $deliveryBoy->driving_license = CommonHelper::uploadFile($request, 'driving_license', 'delivery_boy/driving_license');
            }

            if ($request->hasFile('national_identity_card')) {
                $deliveryBoy->national_identity_card = CommonHelper::uploadFile($request, 'national_identity_card', 'delivery_boy/national_identity_card');
            }

            $deliveryBoy->save(); // save files

            /* Save Translation (all languages in one call when the map is sent) */
            if ($translations !== null) {
                foreach ($translations as $langId => $data) {
                    $deliveryBoy->saveTranslation((int) $langId, [
                        'name'    => $data['name'] ?? '',
                        'address' => $data['address'] ?? '',
                        'other_payment_information' => $data['other_payment_information'] ?? '',
                    ]);
                }
            } else {
                $deliveryBoy->saveTranslation($request->language_id, [
                    'name'  => $request->name ?? '',
                    'address' => $request->address ?? '',
                    'other_payment_information' => $request->other_payment_information ?? '',
                ]);
            }

            DB::commit();

            return CommonHelper::responseWithData([
                'id' => $deliveryBoy->id,
                'message' => __('delivery_boy_saved_successfully'),
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error("DeliveryBoy Save Error", [$e->getMessage()]);
            return CommonHelper::responseError('something_went_wrong');
        }
    }

    public function update(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();

        $translations = $request->translations;
        if (is_string($translations)) {
            $translations = json_decode($translations, true);
        }
        $translations = is_array($translations) ? $translations : null;

        if ($translations !== null) {
            if (empty($translations[$defaultLanguage->id]['name'])) {
                return CommonHelper::responseError('default_language_required_first');
            }
            $request->merge([
                'language_id' => $defaultLanguage->id,
                'name'        => $translations[$defaultLanguage->id]['name'],
                'address'     => $translations[$defaultLanguage->id]['address'] ?? '',
                'other_payment_information' => $translations[$defaultLanguage->id]['other_payment_information'] ?? '',
            ]);
        } elseif (!$request->filled('language_id')) {
            $request->merge(['language_id' => $defaultLanguage->id]);
        }

        $isDefaultLang   = $defaultLanguage && (int) $request->language_id === (int) $defaultLanguage->id;

        $rules = [
            'language_id' => 'required|exists:languages,id',
            'name'        => $isDefaultLang ? 'required' : 'nullable|string',
            'address'     => $isDefaultLang ? 'required' : 'nullable|string',
            'zone_id'     => $isDefaultLang ? 'required|exists:zones,id' : 'nullable|exists:zones,id',
        ];

        // If password is filled, confirm_password is required and must match
        if ($request->filled('password')) {
            $rules['password'] = 'required';
            $rules['confirm_password'] = 'required|same:password';
        }
        // A profile image is optional on update, but if sent it must be an image.
        if ($request->hasFile('profile')) {
            $rules['profile'] = 'image';
        }

        $messages = [
            'zone_id.required'         => __('please_select_a_zone'),
            'zone_id.exists'           => __('please_select_a_zone'),
            'profile.image'            => __('profile_must_be_an_image'),
            'confirm_password.same'    => __('password_and_confirm_password_must_match'),
        ];
        $validator = Validator::make($request->all(), $rules, $messages);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        // Admin panel posts the target id; self-service (no id) falls back to
        // the authenticated delivery boy's own record.
        $deliveryBoy = $request->filled('id')
            ? DeliveryBoy::find($request->id)
            : DeliveryBoy::where('admin_id', $request->user()?->id)->first();
        if (!$deliveryBoy) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }

        // Profile image is required — an existing image satisfies it; only enforce a
        // new upload when the record has none yet (default-language pass).
        if ($isDefaultLang && empty($deliveryBoy->profile) && !$request->hasFile('profile')) {
            return CommonHelper::responseError(__('profile_image_is_required'));
        }

        // For default language updates, validate email uniqueness in admins table (per admin record).
        if ($isDefaultLang && $request->filled('email')) {
            $emailValidator = Validator::make($request->all(), [
                'email' => [
                    'required',
                    'email',
                    Rule::unique('admins', 'email')->ignore($deliveryBoy->admin_id),
                ],
            ]);
            if ($emailValidator->fails()) {
                return CommonHelper::responseError($emailValidator->errors()->first());
            }
        }

        if ($isDefaultLang && $request->filled('mobile')) {
            $mobCountryId = $request->filled('country_id') ? $request->country_id : $deliveryBoy->country_id;
            if (($mobErr = CommonHelper::validateMobileForCountry($mobCountryId, $request->mobile)) !== null) {
                return CommonHelper::responseError($mobErr);
            }
        }

        /** Update main table only for default language */
        if ($request->language_id == $defaultLanguage->id) {
            $deliveryBoy->name = $request->name;
            $deliveryBoy->address = $request->address;
            $deliveryBoy->other_payment_information = $request->other_payment_information ?? '';
            $deliveryBoy->mobile = $request->mobile ?? $deliveryBoy->mobile;
            $deliveryBoy->country_code = $request->country_code ?? $deliveryBoy->country_code;
            $deliveryBoy->dob    = $request->dob ?? $deliveryBoy->dob;
            $deliveryBoy->zone_id = $request->filled('zone_id') ? (int) $request->zone_id : $deliveryBoy->zone_id;
            $deliveryBoy->status = $request->status ?? $deliveryBoy->status;
            $deliveryBoy->remark = $request->input('remark', '');

            // Bank details
            $deliveryBoy->ifsc_code = $request->ifsc_code ?? $deliveryBoy->ifsc_code;
            $deliveryBoy->bank_name = $request->bank_name ?? $deliveryBoy->bank_name;
            $deliveryBoy->bank_account_number = $request->bank_account_number ?? $deliveryBoy->bank_account_number;
            $deliveryBoy->account_name = $request->account_name ?? $deliveryBoy->account_name;

            // Bonus details
            $deliveryBoy->bonus_type = $request->bonus_type ?? $deliveryBoy->bonus_type ?? 0;
            $deliveryBoy->bonus_percentage = $request->bonus_percentage ?? $deliveryBoy->bonus_percentage ?? 0;
            $deliveryBoy->bonus_min_amount = $request->bonus_min_amount ?? $deliveryBoy->bonus_min_amount ?? 0;
            $deliveryBoy->bonus_max_amount = $request->bonus_max_amount ?? $deliveryBoy->bonus_max_amount ?? 0;

            // Return commission details
            $deliveryBoy->return_bonus_type = $request->return_bonus_type ?? $deliveryBoy->return_bonus_type ?? 0;
            $deliveryBoy->return_bonus_percentage = $request->return_bonus_percentage ?? $deliveryBoy->return_bonus_percentage ?? 0;
            $deliveryBoy->return_bonus_min_amount = $request->return_bonus_min_amount ?? $deliveryBoy->return_bonus_min_amount ?? 0;
            $deliveryBoy->return_bonus_max_amount = $request->return_bonus_max_amount ?? $deliveryBoy->return_bonus_max_amount ?? 0;

            /** Files */
            if ($request->hasFile('profile')) {
                $deliveryBoy->profile = CommonHelper::uploadFile($request, 'profile', 'delivery_boy/profile', $deliveryBoy->profile);
            }
            if ($request->hasFile('driving_license')) {
                $deliveryBoy->driving_license = CommonHelper::uploadFile($request, 'driving_license', 'delivery_boy/driving_license', $deliveryBoy->driving_license);
            }

            if ($request->hasFile('national_identity_card')) {
                $deliveryBoy->national_identity_card = CommonHelper::uploadFile($request, 'national_identity_card', 'delivery_boy/national_identity_card', $deliveryBoy->national_identity_card);
            }

            $deliveryBoy->save();

            // Update Admin password when password is provided
            if ($request->filled('password')) {
                if (($pwErr = CommonHelper::validatePasswordPolicy($request->password)) !== null) {
                    return CommonHelper::responseError($pwErr);
                }
                $admin = Admin::find($deliveryBoy->admin_id);
                if ($admin) {
                    $admin->password = bcrypt($request->password);
                    $admin->save();
                }
            }

            // Update Admin email when provided (after passing uniqueness validation above).
            if ($request->filled('email')) {
                $admin = Admin::find($deliveryBoy->admin_id);
                if ($admin) {
                    $admin->email = $request->email;
                    $admin->save();
                }
            }
        }

        /**  Save or Update Translation (all languages in one call when the map is sent) */
        if ($translations !== null) {
            foreach ($translations as $langId => $data) {
                $deliveryBoy->saveTranslation((int) $langId, [
                    'name'    => $data['name'] ?? '',
                    'address' => $data['address'] ?? '',
                    'other_payment_information' => $data['other_payment_information'] ?? '',
                ]);
            }
        } else {
            $deliveryBoy->saveTranslation($request->language_id, [
                'name'  => $request->name ?? '',
                'address' => $request->address ?? '',
                'other_payment_information' => $request->other_payment_information ?? '',
            ]);
        }

        /** Return latest delivery boy with current language translation */
        $deliveryBoy = DeliveryBoy::withTranslation()->with('admin')->find($deliveryBoy->id);

        $data = $this->formatDeliveryBoyData($deliveryBoy);
        $data['message'] = __('delivery_boy_updated_successfully');

        return CommonHelper::responseWithData($data, false);
    }

    public function updateStatus(Request $request)
    {
        $authUser = $request->user();
        $ownBoy = $authUser?->deliveryBoy;
        $isSelfService = $ownBoy && (int) $authUser->role_id === Role::$roleDeliveryBoy;

        if ($isSelfService) {
            $validator = Validator::make($request->all(), [
                'status' => 'required|integer|in:' . DeliveryBoy::$statusActive . ',' . DeliveryBoy::$statusDeactivated,
            ]);
            if ($validator->fails()) {
                return CommonHelper::responseError($validator->errors()->first());
            }
            if (!in_array((int) $ownBoy->status, [DeliveryBoy::$statusActive, DeliveryBoy::$statusDeactivated], true)) {
                return CommonHelper::responseError(__('you_dont_have_permission_to_update_to_this_status'));
            }
            $request->merge(['id' => $ownBoy->id]);
        }

        if (!isset($request->id)) {
            return CommonHelper::responseError(__('delivery_boy_not_found'));
        }

        $deliveryBoy = DeliveryBoy::find($request->id);
        if (!$deliveryBoy) {
            return CommonHelper::responseError(__('delivery_boy_not_found'));
        }

        $deliveryBoy->status = (int) $request->status;
        // A self-toggle never carries a remark; don't wipe the admin's existing one.
        if (!$isSelfService) {
            $deliveryBoy->remark = $request->remark ?? "";
        }
        $deliveryBoy->save();

        $status_name = match ((int) $deliveryBoy->status) {
            DeliveryBoy::$statusActive      => DeliveryBoy::$Active,
            DeliveryBoy::$statusDeactivated => DeliveryBoy::$Deactivated,
            default                         => DeliveryBoy::$Rejected,
        };

        // Only an admin-driven status change notifies the boy; a self-toggle shouldn't.
        if (!$isSelfService) {
            dispatch(function () use ($deliveryBoy) {
                try {
                    CommonHelper::sendDeliveryBoyStatusNotification($deliveryBoy);
                } catch (\Exception $e) {
                    Log::error("Approve delivery_boy status notification error", [$e->getMessage()]);
                }
            })->afterResponse();
        }

        return CommonHelper::responseSuccessWithData(
            __('delivery_boy_status_updated_successfully', ['status' => $status_name]),
            ['status' => (int) $deliveryBoy->status]
        );
    }

    public function delete(Request $request)
    {
        $deliveryBoy = DeliveryBoy::find($request->id);

        if ($deliveryBoy) {
            $finished = [OrderStatusList::$delivered, OrderStatusList::$cancelled, OrderStatusList::$returned];

            $hasActiveQuick = Order::where('delivery_boy_id', $deliveryBoy->id)
                ->where('channel', 'quick')
                ->whereNotIn('active_status', $finished)
                ->exists();

            $hasActiveEcom = OrderItem::where('delivery_boy_id', $deliveryBoy->id)
                ->whereNotIn('active_status', $finished)
                ->exists();

            if ($hasActiveQuick || $hasActiveEcom) {
                return CommonHelper::responseError('cannot_delete_delivery_boy_with_active_orders');
            }

            $deliveryBoy->delete();
        }

        return CommonHelper::responseSuccess('delivery_boy_deleted_successfully');
    }

    public function getDeliveryBoyDetail($id)
    {
        $boy = DeliveryBoy::withAllTranslations()->with('country')->find($id);
        if (!$boy) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }
        $admin = Admin::find($boy->admin_id);

        /* ---------- wallet (delivery_boy_settlements) ---------- */
        $credits = DeliveryBoySettlement::where('delivery_boy_id', $id)
            ->where('type', DeliveryBoySettlement::$typeCredit);
        $debits = DeliveryBoySettlement::where('delivery_boy_id', $id)
            ->where('type', DeliveryBoySettlement::$typeDebit);
        $salaryTotal = (float) DeliveryBoySalary::where('delivery_boy_id', $id)->sum('amount');
        $pendingWithdraw = (float) WithdrawalRequest::where('type', WithdrawalRequest::$typeDeliveryBoy)
            ->where('type_id', $id)->where('status', WithdrawalRequest::$statusPending)->sum('amount');
        $totalWithdrawn = (float) WithdrawalRequest::where('type', WithdrawalRequest::$typeDeliveryBoy)
            ->where('type_id', $id)->where('status', WithdrawalRequest::$statusApproved)->sum('amount');

        /* ---------- cash (delivery_boy_cash_collections) ---------- */
        $totalCollected = (float) DeliveryBoyCashCollection::where('delivery_boy_id', $id)
            ->where('type', DeliveryBoyCashCollection::$paymentTypeCod)->sum('amount');
        $totalDeposited = (float) DeliveryBoyCashCollection::where('delivery_boy_id', $id)
            ->where('type', DeliveryBoyCashCollection::$typeCashCollection)->sum('amount');

        /* ---------- orders: quick at order level, ecommerce at item level ---------- */
        $activeStatuses = [1, 2, 3, 4, 5, 9, 10, 11];
        $quick = Order::where('delivery_boy_id', $id)->where('channel', 'quick');
        $ecom = OrderItem::join('orders as o', 'order_items.order_id', '=', 'o.id')
            ->whereNull('o.deleted_at')->whereNull('order_items.deleted_at')
            ->where('o.channel', 'ecommerce')->where('order_items.delivery_boy_id', $id);

        $orderStats = [
            'quick' => [
                'active'    => (int) (clone $quick)->whereIn('active_status', $activeStatuses)->count(),
                'delivered' => (int) (clone $quick)->where('active_status', OrderStatusList::$delivered)->count(),
                'cancelled' => (int) (clone $quick)->whereIn('active_status', [OrderStatusList::$cancelled, OrderStatusList::$returned])->count(),
            ],
            'ecommerce' => [
                'active'    => (int) (clone $ecom)->whereIn('order_items.active_status', $activeStatuses)->count(),
                'delivered' => (int) (clone $ecom)->where('order_items.active_status', OrderStatusList::$delivered)->count(),
                'cancelled' => (int) (clone $ecom)->whereIn('order_items.active_status', [OrderStatusList::$cancelled, OrderStatusList::$returned])->count(),
            ],
        ];
        $orderStats['remaining_to_deliver'] = $orderStats['quick']['active'] + $orderStats['ecommerce']['active'];
        $orderStats['total_delivered'] = $orderStats['quick']['delivered'] + $orderStats['ecommerce']['delivered'];

        $bonusEarned = (float) (clone $credits)->sum('amount');

        /* ---------- returns ---------- */
        $returnsAssigned = ReturnRequest::where('delivery_boy_id', $id)->count();
        $returnsCompleted = ReturnRequest::where('delivery_boy_id', $id)
            ->whereIn('status', [ReturnStatusList::$rReturnToBranch, ReturnStatusList::$rRefundCompleted])->count();

        /* ---------- recent orders (both channels, latest 10) ---------- */
        $recentQuick = (clone $quick)->select('id', 'order_number', 'channel', 'final_total', 'currency', 'active_status', 'created_at')
            ->orderByDesc('id')->limit(10)->get();
        $recentEcom = (clone $ecom)->select('order_items.order_id as id', 'o.order_number', 'o.channel', 'order_items.final_total', 'o.currency', 'order_items.active_status', 'order_items.created_at')
            ->orderByDesc('order_items.id')->limit(10)->get();
        $recentOrders = $recentQuick->concat($recentEcom)->sortByDesc('created_at')->take(10)->values();

        $salaryLast = DeliveryBoySalary::where('delivery_boy_id', $id)->orderByDesc('paid_on')->first();

        $data = [
            'delivery_boy' => [
                'id'            => $boy->id,
                'name'          => $boy->name,
                'email'         => $admin->email ?? null,
                'mobile'        => $boy->mobile,
                'country_code'  => $boy->country_code,
                'address'       => $boy->address,
                'dob'           => $boy->dob,
                'status'        => (int) $boy->status,
                'remark'        => $boy->remark,
                'country'       => $boy->country ? ['id' => $boy->country->id, 'name' => $boy->country->name, 'currency' => $boy->country->currency, 'currency_code' => $boy->country->currency_code] : null,
                'bonus'         => ['type' => $boy->bonus_type, 'percentage' => $boy->bonus_percentage, 'min' => $boy->bonus_min_amount, 'max' => $boy->bonus_max_amount],
                'return_bonus'  => ['type' => $boy->return_bonus_type, 'percentage' => $boy->return_bonus_percentage, 'min' => $boy->return_bonus_min_amount, 'max' => $boy->return_bonus_max_amount],
                'bank'          => ['account_name' => $boy->account_name, 'account_number' => $boy->bank_account_number, 'bank_name' => $boy->bank_name, 'ifsc' => $boy->ifsc_code, 'other' => $boy->other_payment_information],
                'profile_url'               => $boy->profile_url,
                'driving_license_url'       => $boy->driving_license_url,
                'national_identity_card_url' => $boy->national_identity_card_url ?? null,
                'created_at'    => $boy->getAttributes()['created_at'] ?? null,
                'translations'  => $boy->relationLoaded('translations') ? $boy->getRelation('translations')->toArray() : [],
            ],
            'stats' => [
                'wallet' => [
                    'balance'             => (float) $boy->balance,
                    'total_earned'        => $bonusEarned + $salaryTotal,
                    'bonus_earned'        => $bonusEarned,
                    'total_debited'       => (float) (clone $debits)->sum('amount'),
                    'total_withdrawn'     => $totalWithdrawn,
                    'pending_withdrawals' => $pendingWithdraw,
                    'available'           => max(0, (float) $boy->balance - $pendingWithdraw),
                ],
                'cash' => [
                    'in_hand'         => (float) $boy->cash_received,
                    'total_collected' => $totalCollected,
                    'total_deposited' => $totalDeposited,
                ],
                'salary' => [
                    'total'        => $salaryTotal,
                    'last_paid_on' => $salaryLast->paid_on ?? null,
                    'last_amount'  => $salaryLast->amount ?? null,
                ],
                'orders'  => $orderStats,
                'returns' => ['assigned' => $returnsAssigned, 'completed' => $returnsCompleted],
            ],
            'settlement_history'  => DeliveryBoySettlement::settlementHistory($id),
            'cash_collections'    => DeliveryBoyCashCollection::where('delivery_boy_cash_collections.delivery_boy_id', $id)
                ->where('delivery_boy_cash_collections.type', DeliveryBoyCashCollection::$paymentTypeCod)
                ->leftJoin('orders', 'delivery_boy_cash_collections.order_id', '=', 'orders.id')
                ->select('delivery_boy_cash_collections.*', 'orders.order_number')
                ->orderByDesc('delivery_boy_cash_collections.id')->get()
                ->each(fn($t) => $t->message = CommonHelper::translateLedgerMessage($t->message)),
            'withdrawals'         => WithdrawalRequest::where('type', WithdrawalRequest::$typeDeliveryBoy)->where('type_id', $id)->orderByDesc('id')->get()
                ->each(fn($w) => $w->message = CommonHelper::translateLedgerMessage($w->message)),
            'salary_transactions' => DeliveryBoySalary::where('delivery_boy_id', $id)->orderByDesc('paid_on')->get(),
            'recent_orders'       => $recentOrders,
        ];
        return CommonHelper::responseWithData($data);
    }

    public function getStatus(Request $request)
    {
        $own = DB::table('delivery_boys')->where('admin_id', (int) (auth()->id() ?? 0))->value('id');
        if (!$own) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }

        $requested = $request->filled('id') ? (int) $request->input('id') : (int) $own;
        if ($requested !== (int) $own) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }

        $delivery_boy_id = $own;

        $deliveryBoy = DeliveryBoy::find($delivery_boy_id);

        if (!$deliveryBoy) {
            return CommonHelper::responseError('delivery_boy_not_found');
        }

        $data = ['status' => $deliveryBoy->status, 'remark' => $deliveryBoy->remark];
        return CommonHelper::responseWithData($data);
    }
}
