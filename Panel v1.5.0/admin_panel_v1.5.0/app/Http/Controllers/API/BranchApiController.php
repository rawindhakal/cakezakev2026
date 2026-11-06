<?php

namespace App\Http\Controllers\API;

use App\Plugins\Registries\ShippingProviderRegistry;
use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Admin;
use App\Models\OrderItem;
use App\Models\Permission;
use App\Models\PermissionCategory;
use App\Models\Region;
use App\Models\Role;
use App\Models\Branch;
use App\Models\Zone;
use App\Services\LanguageService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Spatie\Permission\Models\Role as SpatieRole;
use Illuminate\Validation\Rule;
use Laravel\Passport\Token;
use Laravel\Passport\RefreshToken;

class BranchApiController extends Controller
{
    protected $languageService;

    public function __construct(LanguageService $languageService)
    {
        $this->languageService = $languageService;
    }

    public function getBranches(Request $request)
    {
        $query = Branch::with(['translations', 'zone:id,name,city,state,sales_channel,country_id,region_id'])->orderBy('id', 'desc');

        if ($request->filled('search')) {
            $term = $request->input('search');
            $query->where(function ($q) use ($term) {
                $q->where('name', 'like', "%{$term}%")
                    ->orWhere('provider', 'like', "%{$term}%")
                    ->orWhereHas('zone', fn ($z) => $z->where('name', 'like', "%{$term}%")
                        ->orWhere('city', 'like', "%{$term}%")
                        ->orWhere('state', 'like', "%{$term}%"));
            });
        }

        if ($request->filled('service_modes')) {
            $query->where('service_modes', $request->input('service_modes'));
        }
        if ($request->filled('fulfillment_type')) {
            $query->where('fulfillment_type', $request->input('fulfillment_type'));
        }

        if ($request->filled('status')) {
            $query->where('status', (int) $request->input('status'));
        }

        // Global header country/zone filter. Branch reaches country via its zone
        // (quick or ecommerce), so match on either zone FK.
        if ($request->filled('country_id')) {
            $countryId = (int) $request->input('country_id');
            $zoneIds = Zone::where('country_id', $countryId)->pluck('id')->all();
            $query->whereIn('zone_id', $zoneIds);
        }
        if ($request->filled('zone_id')) {
            $zoneId = (int) $request->input('zone_id');
            $query->where('zone_id', $zoneId);
        }

        $total = $query->count();

        if ($request->filled('limit')) {
            $branches = $query->skip((int) $request->input('offset', 0))
                ->take((int) $request->input('limit'))
                ->get();
        } else {
            $branches = $query->get();
        }

        $regionIds = $branches->map(fn ($s) => optional($s->zone)->region_id)->filter()->unique();
        $regions = Region::whereIn('id', $regionIds)->get(['id', 'name', 'code', 'tax_code'])->keyBy('id');

        foreach ($branches as $branch) {
            $regionId = optional($branch->zone)->region_id;
            $branch->region_id = $regionId ? (int) $regionId : null;
            $branch->region_name = $regionId ? ($regions[$regionId]->name ?? null) : null;
        }

        return CommonHelper::responseWithData([
            'total'  => $total,
            'branches' => $branches,
        ]);
    }

    public function save(Request $request)
    {
        $defaultLanguage = $this->languageService->getDefaultLanguage();
        $isDefaultLanguage = ($request->language_id == $defaultLanguage->id);

        if ($request->filled('id')) {
            $branch = Branch::find($request->id);
            if (!$branch) {
                return CommonHelper::responseError('Branch not found');
            }
        } else {
            if (!$isDefaultLanguage) {
                return CommonHelper::responseError('Please create branch in default language first');
            }

            $validator = Validator::make($request->all(), [
                'name'             => 'required',
                'fulfillment_type' => 'required|in:quick,ecommerce,both',
            ]);

            if ($validator->fails()) {
                return CommonHelper::responseError($validator->errors()->first());
            }

            $branch = new Branch();
        }

        if ($isDefaultLanguage) {
            $fulfillment = $request->input('fulfillment_type', $branch->fulfillment_type ?: 'quick');

            // A branch has exactly ONE zone; the zone declares which channel(s) it serves.
            $coordValidator = Validator::make($request->all(), [
                'latitude'       => 'required|numeric|between:-90,90',
                'longitude'      => 'required|numeric|between:-180,180',
                'zone_id'        => 'required|integer|exists:zones,id',
                'contact_number' => 'required|string',
            ], [
                'latitude.required'       => __('please_select_branch_location_on_map'),
                'longitude.required'      => __('please_select_branch_location_on_map'),
                'zone_id.required'        => __('please_select_a_zone'),
                'zone_id.exists'          => __('please_select_a_zone'),
                'contact_number.required' => __('contact_number') . ' ' . __('is_required'),
            ]);

            if ($coordValidator->fails()) {
                return CommonHelper::responseError($coordValidator->errors()->first());
            }

            // Branch login credential — email is the login id (must be unique across
            // all admins). Password is required on create, optional on update.
            $credValidator = Validator::make($request->all(), [
                'email'    => ['required', 'email', Rule::unique('admins', 'email')->ignore($branch->owner_admin_id)],
                'password' => $branch->exists ? 'nullable|string' : 'required|string',
            ], [
                'email.required' => __('please_enter_email') ?: 'Email is required',
                'email.unique'   => __('email_already_taken') ?: 'This email is already in use',
            ]);
            if ($credValidator->fails()) {
                return CommonHelper::responseError($credValidator->errors()->first());
            }
            // Enforce the configured password policy (same as system users).
            if ($request->filled('password')
                && ($pwErr = CommonHelper::validatePasswordPolicy($request->password)) !== null) {
                return CommonHelper::responseError($pwErr);
            }
            if ($request->filled('password') && $request->password !== $request->confirm_password) {
                return CommonHelper::responseError(__('password_and_confirm_password_must_match'));
            }

            $zoneId = (int) $request->input('zone_id');
            $zone   = Zone::find($zoneId);

            if (!$zone || !$this->zoneSupportsFulfillment($zone, $fulfillment)) {
                return CommonHelper::responseError(__('selected_zone_does_not_support_this_fulfillment_type'));
            }

            // One zone -> one branch.
            $taken = Branch::where('zone_id', $zoneId)
                ->when($branch->id, fn ($q) => $q->where('id', '!=', $branch->id))
                ->exists();
            if ($taken) {
                return CommonHelper::responseError(__('zone_already_assigned_to_another_branch'));
            }

            $branch->name              = $request->input('name');
            $branch->provider          = $request->input('provider');
            $branch->fulfillment_type  = $fulfillment;
            // Self pickup: what the branch offers, and where. A single-channel branch can
            // only offer pickup on its own channel whatever the form sent.
            $modes = (string) $request->input('service_modes', $branch->service_modes ?? 'delivery');
            $branch->service_modes = in_array($modes, ['delivery', 'pickup', 'both'], true) ? $modes : 'delivery';
            $pickupChannels = (string) $request->input('pickup_channels', $branch->pickup_channels ?? 'both');
            $branch->pickup_channels = $fulfillment === 'both'
                ? (in_array($pickupChannels, ['quick', 'ecommerce', 'both'], true) ? $pickupChannels : 'both')
                : $fulfillment;
            $branch->zone_id           = $zoneId;
            $branch->address           = $request->input('address');
            $branch->latitude          = $request->input('latitude');
            $branch->longitude         = $request->input('longitude');
            $branch->formatted_address = $request->input('formatted_address');
            $branch->place_id          = $request->input('place_id');
            $branch->contact_number  = $request->input('contact_number');
            $branch->email           = $request->input('email');
            /* A courier collects from a pincode, not from a map pin. Optional here —
               only a shipping integration insists on it. */
            $branch->pincode         = trim((string) $request->input('pincode', '')) ?: null;
            $branch->operating_hours = $this->parseJson($request->input('operating_hours'));
            $branch->preparation_time = max(0, (int) $request->input('preparation_time', 0));
            $branch->status = (int) $request->input('status', 1);
            // The branch's tax identity (GSTIN / VAT / TRN). Blank clears it.
            if ($request->has('tax_number')) {
                $number = strtoupper(trim((string) $request->input('tax_number')));
                $branch->tax_number = $number !== '' ? $number : null;
                $branch->tax_registration_type = $number !== ''
                    ? (strtoupper(trim((string) $request->input('tax_registration_type'))) ?: null)
                    : null;
            }
            $branch->save();

            // Every branch opens with the full catalogue (existing rows are left as they are).
            app(\App\Services\BranchCatalogSync::class)->syncBranch((int) $branch->id);

            if ((int) $branch->status === 0) {
                $this->revokeBranchLogins($branch->id);
            }

            $ownerRole = $this->syncOwnerRole($branch, $request);
            $this->syncBranchOwner($branch, $request->input('email'), $request->input('password'), $ownerRole);
        }

        $branch->saveTranslation((int) $request->language_id, [
            'name'     => $request->input('name'),
            'provider' => $request->input('provider'),
            'address'  => $request->input('address'),
        ]);

        return CommonHelper::responseWithData([
            'id'      => $branch->id,
            'message' => __('branch_saved_successfully'),
        ]);
    }

    /** Internal name of a branch's OWNER role (distinct from its sub-user roles). */
    private function ownerRoleName(int $branchId): string
    {
        return 'branch' . $branchId . ':__owner__';
    }

    /**
     * Create/sync the branch's per-branch OWNER role and its permission ceiling.
     * The admin picks permissions (default = full catalog on create); the two
     * management perms are always included. Revoking a permission cascade-prunes
     * it from the branch's sub-user roles so no sub-user ever exceeds the owner.
     */
    private function syncOwnerRole(Branch $branch, Request $request): SpatieRole
    {
        $role = SpatieRole::firstOrCreate(
            ['name' => $this->ownerRoleName($branch->id), 'guard_name' => 'web'],
            ['branch_id' => $branch->id]
        );
        if ((int) $role->branch_id !== (int) $branch->id) {
            $role->branch_id = $branch->id;
            $role->save();
        }

        // Only (re)apply permissions when the admin sent them, or on first create.
        $sentPerms = $request->has('permissions');
        if ($sentPerms || !$branch->owner_admin_id) {
            if ($sentPerms) {
                $ids = array_map('intval', (array) $request->input('permissions', []));
                $selected = Permission::whereIn('id', $ids)->pluck('name')->all();
                $names = array_values(array_intersect($selected, Role::branchPermissionCatalog()));
            } else {
                // Create default = full catalog.
                $names = Role::branchPermissionCatalog();
            }
            $ownerNames = array_values(array_unique(array_merge($names, Role::branchOwnerMgmtPerms())));
            $role->syncPermissions(Permission::whereIn('name', $ownerNames)->get());
            $this->pruneSubUserRoles($branch->id, $ownerNames);
        }

        return $role;
    }

    /** Clamp every branch sub-user role down to the owner's permission set. */
    private function pruneSubUserRoles(int $branchId, array $ownerNames): void
    {
        $subRoles = SpatieRole::where('branch_id', $branchId)
            ->where('name', '!=', $this->ownerRoleName($branchId))
            ->get();
        foreach ($subRoles as $r) {
            $keep = $r->permissions->pluck('name')->intersect($ownerNames)->values()->all();
            $r->syncPermissions(Permission::whereIn('name', $keep)->get());
        }
    }

    /**
     * Creates or updates the branch's PRIMARY login — an `admins` row on the branch's
     * OWNER role, linked to the branch. The email/password are the branch login.
     */
    private function syncBranchOwner(Branch $branch, ?string $email, ?string $password, SpatieRole $ownerRole): void
    {
        $admin = $branch->owner_admin_id ? Admin::find($branch->owner_admin_id) : null;
        if (!$admin) {
            $admin = Admin::where('branch_id', $branch->id)->where('is_branch_owner', 1)->first();
        }

        if ($admin) {
            $admin->username       = $branch->name;
            $admin->email          = $email;
            $admin->role_id        = $ownerRole->id;
            $admin->branch_id       = $branch->id;
            $admin->is_branch_owner = 1;
            if (!empty($password)) {
                $admin->password = Hash::make($password);
            }
            $admin->save();
        } else {
            $admin = Admin::create([
                'username'       => $branch->name,
                'email'          => $email,
                'password'       => Hash::make($password ?: Str::random(14)),
                'role_id'        => $ownerRole->id,
                'created_by'     => auth()->id() ?? 0,
                'branch_id'       => $branch->id,
                'is_branch_owner' => 1,
            ]);
        }
        $this->assignRolePivot($admin, $ownerRole);

        if ((int) $branch->owner_admin_id !== (int) $admin->id) {
            $branch->owner_admin_id = $admin->id;
            $branch->save();
        }
    }

    private function assignRolePivot(Admin $admin, SpatieRole $ownerRole): void
    {
        DB::table('model_has_roles')
            ->where('model_type', $admin->getMorphClass())
            ->where('model_id', $admin->id)
            ->delete();
        DB::table('model_has_roles')->insert([
            'role_id'    => $ownerRole->id,
            'model_type' => $admin->getMorphClass(),
            'model_id'   => $admin->id,
        ]);
        $admin->unsetRelation('roles');
        app(\Spatie\Permission\PermissionRegistrar::class)->forgetCachedPermissions();
    }

    /** Admin permission-picker catalog (categories with only branch-owner perms). */
    public function permissionCatalog()
    {
        $categories = PermissionCategory::with(['permissions' => fn ($q) => $q->whereIn('name', Role::branchPermissionCatalog())])
            ->get()
            ->filter(fn ($c) => $c->permissions->isNotEmpty())
            ->values();
        return CommonHelper::responseWithData(['categories' => $categories]);
    }

    /** Update ONLY a branch's owner permissions (used by the listing's permission icon). */
    public function savePermissions(Request $request)
    {
        $branch = Branch::find($request->input('id'));
        if (!$branch) {
            return CommonHelper::responseError('Branch not found');
        }
        $request->merge(['permissions' => (array) $request->input('permissions', [])]);
        $ownerRole = $this->syncOwnerRole($branch, $request);
        // Keep the owner admin on the (possibly re-created) owner role.
        if ($branch->owner_admin_id) {
            Admin::where('id', $branch->owner_admin_id)->update(['role_id' => $ownerRole->id]);
        }
        return CommonHelper::responseSuccess('permissions_updated_successfully');
    }

    /**
     * Can a courier collect from this branch?
     *
     * Core asks whichever shipping plugin is installed and relays its answer, so the
     * branch form can tell an admin "this pincode is not collected from" or "this branch
     * is not registered with the courier" while they are still editing the branch,
     * instead of at the first order. Answers honestly that it cannot check when no
     * shipping plugin is installed.
     */
    public function checkPickup(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'branch_id' => 'nullable|integer|exists:branches,id',
            'pincode'  => 'nullable|string|max:16',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $branch = $request->filled('branch_id') ? Branch::with('zone.country')->find((int) $request->branch_id) : null;

        $provider = app(ShippingProviderRegistry::class)->default(
            'ecommerce',
            (string) (optional(optional($branch)->zone)->country->code ?? '') ?: null
        );

        if (!$provider) {
            /* Answer in the same shape as a real check, so the form does not have to
               guess what is missing — an incomplete payload left `registered` undefined,
               and the Register button appeared for a branch no courier can serve. */
            return CommonHelper::responseWithData([
                'checked'      => true,
                'ok'           => false,
                'serviceable'  => false,
                'registered'   => false,
                'can_register' => false,
                'couriers'     => 0,
                'nickname'     => null,
                'message'      => $this->noProviderReason($branch),
            ]);
        }

        // An unsaved branch can still be checked: the typed pincode is enough to ask
        // whether couriers collect there, which is the half that decides the address.
        $info = $branch
            ? $branch->pickupInfo()
            : ['branch_id' => 0, 'branch_name' => '', 'pincode' => (string) $request->input('pincode', '')];

        if ($request->filled('pincode')) {
            $info['pincode'] = (string) $request->input('pincode');
        }

        $result = $provider->verifyPickup($info);

        return CommonHelper::responseWithData([
            'checked'     => true,
            'provider'    => $provider->key(),
            'provider_name' => $provider->label(),
            'ok'          => (bool) $result['ok'],
            'serviceable' => (bool) $result['serviceable'],
            'registered'  => (bool) $result['registered'],
            // Whether registering is a thing the admin can actually do from here.
            'can_register' => !$result['registered'],
            'nickname'    => $result['nickname'],
            'couriers'    => (int) $result['couriers'],
            'message'     => $result['message'] !== '' ? __($result['message']) : '',
        ]);
    }

    /**
     * Why no courier answered for this branch.
     *
     * "Install a shipping plugin" is only true when none is installed. With one
     * installed that serves other countries, saying so sends an admin hunting for a
     * plugin they already have — the branch is simply outside where it collects.
     */
    private function noProviderReason(?Branch $branch): string
    {
        $registry = app(ShippingProviderRegistry::class);
        $configured = array_filter(
            $registry->keys(),
            fn (string $key) => (bool) $registry->provider($key)?->isConfigured()
        );

        if (!$configured) {
            return __('no_shipping_provider_is_available');
        }

        $country = (string) (optional(optional($branch)->zone)->country->name ?? '');

        return $country !== ''
            ? __('no_courier_collects_from_country', ['country' => $country])
            : __('no_courier_collects_from_this_branch');
    }

    /**
     * Register this branch as a collection point with the installed courier.
     *
     * The alternative is an admin typing the same address into two panels and keeping
     * the handles in step by hand, which is exactly where it goes wrong. The courier's
     * own validation message is passed straight back: a rejected address is a data
     * problem to fix, not something to smooth over.
     */
    public function registerPickup(Request $request)
    {
        if (shouldDemoMask()) {
            return CommonHelper::responseError('this_action_is_disabled_in_demo_mode');
        }

        $validator = Validator::make($request->all(), [
            'branch_id' => 'required|integer|exists:branches,id',
            // What the admin is looking at in the form, which may differ from the saved
            // row if they have just edited it.
            'pincode'        => 'nullable|string|max:16',
            'address'        => 'nullable|string|max:191',
            'city'           => 'nullable|string|max:100',
            'state'          => 'nullable|string|max:100',
            'branch_name'     => 'nullable|string|max:191',
            'contact_number' => 'nullable|string|max:20',
            'email'          => 'nullable|email|max:191',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $branch = Branch::with('zone.country')->find((int) $request->branch_id);
        if (!$branch) {
            return CommonHelper::responseError('branch_not_found');
        }

        $provider = app(ShippingProviderRegistry::class)->default(
            'ecommerce',
            (string) (optional($branch->zone)->country->code ?? '') ?: null
        );
        if (!$provider) {
            return CommonHelper::responseError($this->noProviderReason($branch));
        }
        
        $typed = array_filter([
            'pincode'        => trim((string) $request->input('pincode', '')),
            'address'        => trim((string) $request->input('address', '')),
            'city'           => trim((string) $request->input('city', '')),
            'state'          => trim((string) $request->input('state', '')),
            'branch_name'     => trim((string) $request->input('branch_name', '')),
            'contact_number' => trim((string) $request->input('contact_number', '')),
            'email'          => trim((string) $request->input('email', '')),
        ], fn ($value) => $value !== '');

        $result = $provider->registerPickup($typed + $branch->pickupInfo());

        if (empty($result['ok'])) {
            return CommonHelper::responseError(__($result['message']));
        }

        return CommonHelper::responseSuccessWithData(__($result['message']), [
            'nickname' => $result['nickname'],
            'verified' => (bool) $result['verified'],
            'provider' => $provider->key(),
        ]);
    }

    public function edit($id)
    {
        $branch = Branch::with(['translations', 'zone:id,name'])->find($id);
        if (!$branch) {
            return CommonHelper::responseError('Branch not found');
        }
        $ownerRole = SpatieRole::where('name', $this->ownerRoleName($branch->id))->first();
        $data = $branch->toArray();
        // Current owner permission ids (excluding the always-on mgmt perms) for the picker.
        $data['owner_permission_ids'] = $ownerRole
            ? $ownerRole->permissions()->whereIn('name', Role::branchPermissionCatalog())->pluck('permissions.id')->all()
            : [];
        return CommonHelper::responseWithData($data);
    }

    /** Branch owner viewing its OWN branch (Account → Profile). Resolves the branch server-side. */
    public function myProfile()
    {
        $user = auth()->user();
        if (!$user || !$user->isBranchUser() || !$user->branch_id || !$user->is_branch_owner) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        return $this->edit((int) $user->branch_id);
    }

    /** Branch owner saving its OWN branch profile — never lets it change permissions or password here. */
    public function saveMyProfile(Request $request)
    {
        $user = auth()->user();
        if (!$user || !$user->isBranchUser() || !$user->branch_id || !$user->is_branch_owner) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        $request->merge(['id' => (int) $user->branch_id]);
        // Ceiling + credentials are admin-only / Settings-only; strip them from a self edit.
        $request->request->remove('permissions');
        $request->request->remove('password');
        $request->request->remove('confirm_password');
        return $this->save($request);
    }

    public function delete(Request $request)
    {
        if (!$request->filled('id')) {
            return CommonHelper::responseError('Branch id required');
        }
        $branch = Branch::find($request->id);
        if (!$branch) {
            return CommonHelper::responseSuccess('branch_already_deleted');
        }
        // Block delete when the branch has order items (order history must survive).
        if (OrderItem::where('branch_id', $branch->id)->exists()) {
            return CommonHelper::responseError('branch_in_use_deactivate_instead');
        }
        // Release the branch's zones so they can be assigned to another branch
        // (unique index would otherwise keep them locked to the trashed row).
        $branch->zone_id = null;
        $branch->save();
        Admin::where('branch_id', $branch->id)->update(['status' => 0]);
        // Kill any active panel session for the removed branch.
        $this->revokeBranchLogins($branch->id);
        $branch->delete();
        return CommonHelper::responseSuccess('branch_deleted_successfully');
    }

    private function revokeBranchLogins(int $branchId): void
    {
        $adminIds = Admin::where('branch_id', $branchId)->pluck('id');
        if ($adminIds->isEmpty()) {
            return;
        }
        $tokenIds = Token::whereIn('user_id', $adminIds)
            ->where('revoked', false)
            ->pluck('id');
        if ($tokenIds->isEmpty()) {
            return;
        }
        Token::whereIn('id', $tokenIds)->update(['revoked' => true]);
        RefreshToken::whereIn('access_token_id', $tokenIds)->update(['revoked' => true]);
    }

    /**
     * Can this zone back a branch with the given fulfillment type?
     * Strict: the zone's channel must equal the branch's fulfillment type.
     */
    protected function zoneSupportsFulfillment(Zone $zone, string $fulfillment): bool
    {
        return $zone->sales_channel === $fulfillment;
    }

    public function getZonesForType(Request $request)
    {
        $type = $request->input('fulfillment_type');

        $query = Zone::query()->where('status', 1)->orderBy('name');

        // The zone's channel must equal the branch's fulfillment type — quick branches get
        // quick zones, ecommerce gets ecommerce, and a 'both' zone is reserved for a
        // 'both' branch. No cross-matching.
        if (in_array($type, Zone::CHANNELS, true)) {
            $query->where('sales_channel', $type);
        }

        if ($request->filled('country_id')) {
            $query->where('country_id', (int) $request->input('country_id'));
        }
        if ($request->filled('zone_id')) {
            $ownZoneId = (int) Branch::where('id', (int) $request->input('branch_id', 0))->value('zone_id');
            $query->where(function ($q) use ($request, $ownZoneId) {
                $q->where('id', (int) $request->input('zone_id'));
                if ($ownZoneId) {
                    $q->orWhere('id', $ownZoneId);
                }
            });
        }

        // One zone -> one branch: hide zones already owned by another branch
        // (the editing branch's own zones stay selectable via branch_id).
        $editingBranchId = (int) $request->input('branch_id', 0);
        $takenZoneIds = Branch::query()
            ->when($editingBranchId, fn ($q) => $q->where('id', '!=', $editingBranchId))
            ->pluck('zone_id')
            ->filter()
            ->all();
        if (!empty($takenZoneIds)) {
            $query->whereNotIn('id', $takenZoneIds);
        }

        $zones = $query->with('region:id,name')->get(['id', 'name', 'sales_channel', 'country_id', 'region_id'])
            ->map(function (Zone $z) {
                return [
                    'id'            => $z->id,
                    'name'          => $z->getRawOriginal('name') ?: ('Zone #' . $z->id),
                    'sales_channel' => $z->sales_channel,
                    'country_id'    => $z->country_id ? (int) $z->country_id : null,
                    'region_id'     => $z->region_id ? (int) $z->region_id : null,
                    'region_name'   => optional($z->region)->name,
                ];
            })->values();

        return CommonHelper::responseWithData([
            'zones' => $zones,
        ]);
    }

    public function getBranchesForChannel(Request $request)
    {
        $channel = $request->input('sales_channel', 'both');

        $query = Branch::query()->where('status', 1)->orderBy('name');

        if ($channel === 'quick') {
            $query->whereIn('fulfillment_type', ['quick', 'both']);
        } elseif ($channel === 'ecommerce') {
            $query->whereIn('fulfillment_type', ['ecommerce', 'both']);
        }
        // 'both' (product sells everywhere) -> every active branch

        // Global header country/zone filter. Branch reaches country via its zone FKs.
        if ($request->filled('country_id') || $request->filled('zone_id')) {
            $zoneIds = $request->filled('zone_id')
                ? [(int) $request->input('zone_id')]
                : Zone::where('country_id', (int) $request->input('country_id'))->pluck('id')->all();
            $query->where(function ($q) use ($zoneIds) {
                $q->whereIn('zone_id', $zoneIds);
            });
        }

        // Optional name search (variant step branch picker).
        if ($request->filled('search')) {
            $term = $request->input('search');
            $query->where('name', 'like', "%{$term}%");
        }

        $branches = $query->with('zone:id,name,city')->get(['id', 'name', 'fulfillment_type', 'zone_id']);

        // Resolve each branch's country (via its channel zone) so the product form can
        // show the branch's currency symbol next to price fields and auto-fill the
        // purchase price across branches of the SAME country. Branch → zone → country.
        $zoneIds = $branches->pluck('zone_id')
            ->filter()->unique()->values()->all();
        $zoneCountry = empty($zoneIds)
            ? collect()
            : Zone::whereIn('id', $zoneIds)->with('country')->get()->keyBy('id');

        $mapped = $branches->map(function (Branch $s) use ($channel, $zoneCountry) {
            $zoneId = $channel === 'ecommerce'
                ? $s->zone_id
                : $s->zone_id;
            $country = $zoneId && isset($zoneCountry[$zoneId]) ? $zoneCountry[$zoneId]->country : null;
            return [
                'id'                => $s->id,
                'name'              => $s->getRawOriginal('name') ?: ('Branch #' . $s->id),
                'fulfillment_type'  => $s->fulfillment_type,
                'city'              => $s->zone?->city,
                'zone_id'           => $s->zone_id,
                // zone for the requested channel (quick fallback for 'both' callers)
                'zone_id'           => $zoneId,
                // Country + currency for per-branch pricing UI (symbol + same-country autofill).
                'country_id'        => $country?->id,
                'currency'          => $country?->currency,
                'currency_code'     => $country?->currency_code,
            ];
        })->values();

        return CommonHelper::responseWithData(['branches' => $mapped]);
    }

    protected function parseJson($input)
    {
        if (is_null($input) || $input === '') {
            return null;
        }
        if (is_array($input)) {
            return $input;
        }
        $decoded = json_decode($input, true);
        return json_last_error() === JSON_ERROR_NONE ? $decoded : null;
    }

}
