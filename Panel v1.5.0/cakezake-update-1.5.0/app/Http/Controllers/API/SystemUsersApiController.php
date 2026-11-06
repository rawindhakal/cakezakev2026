<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Admin;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Spatie\Permission\Models\Role;

class SystemUsersApiController extends Controller
{
    public function index(){

        // Delivery boys are managed on their own page — hide the role + those users here.
        $deliveryRoleId = \App\Models\Role::$roleDeliveryBoy;

        // Branch-panel users are managed from the Branches module, not here.
        $query = Admin::with('role')->where('role_id', '!=', $deliveryRoleId)->whereNull('branch_id');
        if (isDemoMode()) {
            $query->where('id', '!=', 1); // hide the real super admin in demo
        }
        $records = $query->orderBy('id', 'DESC')->get();

        $roles = Role::where('id', '!=', $deliveryRoleId)
            ->whereNull('branch_id')
            ->where('name', '!=', \App\Models\Role::$roleNameBranch)
            ->get();

        $data = [
            'records' => $records,
            'roles' => $roles,
        ];

        return CommonHelper::responseWithData($data);
    }
    public function save(Request $request){

        $validator = Validator::make($request->all(),[
            'username' => 'required',
            'email' => 'required|unique:admins,email',
            'role_id' => 'required',
            'password' => 'required_with:confirm_password|same:confirm_password',
            'confirm_password' => '',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if (($pwErr = CommonHelper::validatePasswordPolicy($request->password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }

        $admin = new Admin();
        $admin->username = $request->username;
        $admin->email = $request->email;
        $admin->password = bcrypt($request->password);
        $admin->created_by = auth()->user()->id;
        $admin->role_id = $request->role_id;
        $admin->save();

        return CommonHelper::responseSuccess(__('system_user_saved_successfully'));
    }

    public function update(Request $request){

        $validator = Validator::make($request->all(),[
            'id' => 'required',
            'role_id' => 'required',
            'username' => 'required',
            'email' => 'required|unique:admins,email,'.$request->id,
        ]);

        if(isset($request->password) && $request->password!=''){
            $validator = Validator::make($request->all(),[
                'id' => 'required',
                'username' => 'required',
                'email' => 'required|unique:admins,email,'.$request->id,
                'password' => 'required_with:confirm_password|same:confirm_password',
                'confirm_password' => '',
            ]);
        }

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
        if (isset($request->password) && $request->password != ''
            && ($pwErr = CommonHelper::validatePasswordPolicy($request->password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }
        if(isset($request->id)){
            $admin = Admin::find($request->id);
            $admin->username = $request->username;
            $admin->email = $request->email;
            $admin->role_id = $request->role_id;
            if(isset($request->password) && $request->password!=''){
                $admin->password = bcrypt($request->password);
            }
                      
            $admin->save();
        }
        return CommonHelper::responseSuccess(__('system_user_updated_successfully'));
    }

    public function delete(Request $request){
        if(isset($request->id)){
            $admin = Admin::find($request->id);
            if($admin){
                $admin->delete();
                return CommonHelper::responseSuccess(__('system_user_deleted_successfully'));
            }else{
                return CommonHelper::responseSuccess("System User Already Deleted!");
            }
        }
    }

    public function changePassword(Request $request){
        $validator = Validator::make($request->all(),[
            'username' => 'required',
            'old_password' => 'required',
            'new_password' => 'required|required_with:confirm_password|same:confirm_password',
            'confirm_password' => 'required',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if (($pwErr = CommonHelper::validatePasswordPolicy($request->new_password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }

        $user = auth()->user();

        if (!Hash::check($request->old_password, $user->password)) {
            return CommonHelper::responseError(__('incorrect_current_password'));
        }

        $user->username = $request->username;
        $user->password = bcrypt($request->new_password);
        $user->save();

        return CommonHelper::responseSuccess(__('username_password_changed_successfully'));
    }
}
