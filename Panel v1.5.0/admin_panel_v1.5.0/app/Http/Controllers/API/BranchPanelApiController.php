<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Admin;
use App\Models\Permission;
use App\Models\PermissionCategory;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Spatie\Permission\Models\Role;

/**
 * Branch-panel self-management: a branch owner creates sub-users and branch-scoped
 * roles. Everything is scoped to the authenticated user's branch_id; roles are
 * branch-owned (roles.branch_id) and can only grant the branch permission set.
 */
class BranchPanelApiController extends Controller
{
    /** The current branch id, or null when the user isn't a branch user. */
    private function branchId(): ?int
    {
        $user = auth()->user();
        if (!$user || !$user->isBranchUser()) {
            return null;
        }
        return $user->branch_id ? (int) $user->branch_id : null;
    }

    private function can(string $permission): bool
    {
        return in_array($permission, auth()->user()->allPermissions ?? [], true);
    }

    /** Internal name of the branch's OWNER role (never assignable to a sub-user). */
    private function ownerRoleName(int $branchId): string
    {
        return 'branch' . $branchId . ':__owner__';
    }

    /** The branch OWNER's permission set — the ceiling for delegating to sub-users. */
    private function ownerPermissionNames(int $branchId): array
    {
        $ownerRole = Role::where('name', $this->ownerRoleName($branchId))->first();
        return $ownerRole ? $ownerRole->permissions->pluck('name')->all() : [];
    }

    /** Roles a branch user may assign to a sub-user: its own sub-user roles (not the owner role). */
    private function branchRoleIds(int $branchId): array
    {
        return Role::where('branch_id', $branchId)
            ->where('name', '!=', $this->ownerRoleName($branchId))
            ->pluck('id')->map(fn ($i) => (int) $i)->all();
    }

    /* =============================== USERS =============================== */

    public function users()
    {
        $branchId = $this->branchId();
        if (!$branchId) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }

        $records = Admin::with('role')->where('branch_id', $branchId)->orderBy('id', 'DESC')->get();
        $roles = Role::where('branch_id', $branchId)
            ->where('name', '!=', $this->ownerRoleName($branchId))
            ->get()->map(fn ($r) => ['id' => $r->id, 'name' => $this->displayName($r->name)]);

        return CommonHelper::responseWithData(['records' => $records, 'roles' => $roles]);
    }

    public function saveUser(Request $request)
    {
        $branchId = $this->branchId();
        if (!$branchId || !$this->can('branch_user_manage')) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }

        $validator = Validator::make($request->all(), [
            'username'         => 'required',
            'email'            => 'required|email|unique:admins,email',
            'role_id'          => 'required|integer',
            'password'         => 'required|same:confirm_password',
            'confirm_password' => 'required',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        if (!in_array((int) $request->role_id, $this->branchRoleIds($branchId), true)) {
            return CommonHelper::responseError('invalid_role_selected');
        }
        if (($pwErr = CommonHelper::validatePasswordPolicy($request->password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }
        if ($request->password !== $request->confirm_password) {
            return CommonHelper::responseError(__('password_and_confirm_password_must_match'));
        }

        $admin = new Admin();
        $admin->username       = $request->username;
        $admin->email          = $request->email;
        $admin->password       = bcrypt($request->password);
        $admin->created_by     = auth()->id();
        $admin->role_id        = (int) $request->role_id;
        $admin->branch_id       = $branchId;
        $admin->is_branch_owner = 0;
        $admin->save();

        return CommonHelper::responseSuccess(__('system_user_saved_successfully'));
    }

    public function updateUser(Request $request)
    {
        $branchId = $this->branchId();
        if (!$branchId || !$this->can('branch_user_manage')) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }

        $admin = Admin::where('id', $request->id)->where('branch_id', $branchId)->first();
        if (!$admin) {
            return CommonHelper::responseError('system_user_not_found');
        }
        if ($admin->is_branch_owner) {
            return CommonHelper::responseError('the_branch_owner_login_is_managed_from_the_branch_form');
        }

        $rules = [
            'username' => 'required',
            'email'    => 'required|email|unique:admins,email,' . $admin->id,
            'role_id'  => 'required|integer',
        ];
        if ($request->filled('password')) {
            $rules['password'] = 'same:confirm_password';
        }
        $validator = Validator::make($request->all(), $rules);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        if (!in_array((int) $request->role_id, $this->branchRoleIds($branchId), true)) {
            return CommonHelper::responseError('invalid_role_selected');
        }
        if ($request->filled('password') && ($pwErr = CommonHelper::validatePasswordPolicy($request->password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }
        if ($request->filled('password') && $request->password !== $request->confirm_password) {
            return CommonHelper::responseError(__('password_and_confirm_password_must_match'));
        }

        $admin->username = $request->username;
        $admin->email    = $request->email;
        $admin->role_id  = (int) $request->role_id;
        if ($request->filled('password')) {
            $admin->password = bcrypt($request->password);
        }
        $admin->save();

        return CommonHelper::responseSuccess(__('system_user_updated_successfully'));
    }

    public function deleteUser(Request $request)
    {
        $branchId = $this->branchId();
        if (!$branchId || !$this->can('branch_user_manage')) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        $admin = Admin::where('id', $request->id)->where('branch_id', $branchId)->first();
        if (!$admin) {
            return CommonHelper::responseSuccess(__('system_user_deleted_successfully'));
        }
        if ($admin->is_branch_owner) {
            return CommonHelper::responseError('the_branch_owner_login_cannot_be_deleted');
        }
        $admin->delete();
        return CommonHelper::responseSuccess(__('system_user_deleted_successfully'));
    }

    /* =============================== ROLES =============================== */

    public function roles()
    {
        $branchId = $this->branchId();
        if (!$branchId) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        $roles = Role::where('branch_id', $branchId)
            ->where('name', '!=', $this->ownerRoleName($branchId))
            ->get()->map(fn ($r) => ['id' => $r->id, 'name' => $this->displayName($r->name)]);
        return CommonHelper::responseWithData(['records' => $roles]);
    }

    /**
     * Delegation catalog — a branch owner may only grant permissions it holds
     * (its owner-role set), never the full branch catalog.
     */
    public function rolePermissions()
    {
        $branchId = $this->branchId();
        if (!$branchId) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        $allowed = $this->ownerPermissionNames($branchId);
        $categories = PermissionCategory::with(['permissions' => fn ($q) => $q->whereIn('name', $allowed)])
            ->get()
            ->filter(fn ($c) => $c->permissions->isNotEmpty())
            ->values();
        return CommonHelper::responseWithData(['categories' => $categories]);
    }

    public function saveRole(Request $request)
    {
        $branchId = $this->branchId();
        if (!$branchId || !$this->can('branch_role_manage')) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        $validator = Validator::make($request->all(), ['name' => 'required|string|max:100']);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $role = new Role();
        $role->name       = $this->storedName($branchId, $request->name);
        $role->guard_name = 'web';
        $role->branch_id   = $branchId;
        $role->save();

        $this->syncRolePermissions($role, (array) $request->permissions);

        return CommonHelper::responseSuccess('role_saved_successfully');
    }

    public function editRole($id)
    {
        $branchId = $this->branchId();
        if (!$branchId) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        $role = Role::where('id', $id)->where('branch_id', $branchId)->where('name', '!=', $this->ownerRoleName($branchId))->first();
        // Always return the delegation catalog so the edit modal can render the
        // permission checkboxes (not just the currently-selected ids).
        $allowed = $this->ownerPermissionNames($branchId);
        $data = [
            'categories' => PermissionCategory::with(['permissions' => fn ($q) => $q->whereIn('name', $allowed)])
                ->get()
                ->filter(fn ($c) => $c->permissions->isNotEmpty())
                ->values(),
            'user_permissions' => [],
        ];
        if ($role) {
            $data['name'] = $this->displayName($role->name);
            $data['user_permissions'] = $role->permissions()->pluck('id')->toArray();
        }
        return CommonHelper::responseWithData($data);
    }

    public function updateRole(Request $request)
    {
        $branchId = $this->branchId();
        if (!$branchId || !$this->can('branch_role_manage')) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        $role = Role::where('id', $request->id)->where('branch_id', $branchId)->where('name', '!=', $this->ownerRoleName($branchId))->first();
        if (!$role) {
            return CommonHelper::responseError('invalid_role_selected');
        }
        if ($request->filled('name')) {
            $role->name = $this->storedName($branchId, $request->name, $role->id);
            $role->save();
        }
        $this->syncRolePermissions($role, (array) $request->permissions);

        return CommonHelper::responseSuccess('role_updated_successfully');
    }

    public function deleteRole(Request $request)
    {
        $branchId = $this->branchId();
        if (!$branchId || !$this->can('branch_role_manage')) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }
        $role = Role::where('id', $request->id)->where('branch_id', $branchId)->where('name', '!=', $this->ownerRoleName($branchId))->first();
        if (!$role) {
            return CommonHelper::responseSuccess('role_deleted_successfully');
        }
        $inUse = Admin::where('role_id', $role->id)->count();
        if ($inUse > 0) {
            return CommonHelper::responseError('you_cannot_delete_this_role_this_role_assigned_to_users', ['users' => $inUse]);
        }
        $role->delete();
        return CommonHelper::responseSuccess('role_deleted_successfully');
    }

    /* =============================== helpers =============================== */

    /** Grant only permissions the OWNER holds (the delegation ceiling). */
    private function syncRolePermissions(Role $role, array $permissionIds): void
    {
        $allowedIds = Permission::whereIn('name', $this->ownerPermissionNames((int) $role->branch_id))->pluck('id')->all();
        $ids = array_values(array_intersect(array_map('intval', $permissionIds), array_map('intval', $allowedIds)));
        $role->syncPermissions(Permission::whereIn('id', $ids)->get());
    }

    /** Unique stored name (spatie name+guard unique) — prefixed per branch. */
    private function storedName(int $branchId, string $display, ?int $ignoreId = null): string
    {
        $base = 'branch' . $branchId . ':' . trim($display);
        $name = $base;
        $i = 1;
        while (Role::where('name', $name)->when($ignoreId, fn ($q) => $q->where('id', '!=', $ignoreId))->exists()) {
            $i++;
            $name = $base . ' (' . $i . ')';
        }
        return $name;
    }

    /** Strip the internal "branch{id}:" prefix for display. */
    private function displayName(string $stored): string
    {
        return preg_replace('/^branch\d+:/', '', $stored);
    }
}
