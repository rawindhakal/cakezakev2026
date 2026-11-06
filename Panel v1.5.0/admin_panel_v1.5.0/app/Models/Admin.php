<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Passport\HasApiTokens;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Traits\HasRoles;
use App\Traits\LogsActivity;
use Illuminate\Support\Facades\DB;

class Admin extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable,HasRoles, LogsActivity;

    protected $appends = ['allPermissions','delivery_boy_status'];
    protected $hidden = [
        'password',
        'two_factor_token', 'two_factor_code', 'two_factor_attempts',
        'two_factor_sends', 'two_factor_sent_at', 'two_factor_expires_at',
    ];

    protected $fillable = ['username','email','password','role_id','created_by','branch_id','is_branch_owner'];

    public function role(){
        return $this->hasOne(Role::class,'id','role_id');
    }

    public function branch(){
        return $this->belongsTo(Branch::class, 'branch_id');
    }

    public function isBranchUser(): bool
    {
        return $this->branch_id !== null;
    }

    public function getAllPermissionsAttribute()
    {
        $permissions = [];
       
        if ($this->role){
            $rolePermissions = DB::table('role_has_permissions')
                ->where('role_id', $this->role->id)
                ->get()->pluck('permission_id')->toArray();
        $permissions = Permission::whereIn('id', $rolePermissions)->get()->pluck('name')->toArray();
        }
        return $permissions;
    }

    public function notifications()
    {
        return $this->morphMany(PanelNotification::class, 'notifiable')->orderBy('created_at', 'desc');
    }

    public function deliveryBoy(){
        return $this->belongsTo(DeliveryBoy::class,'id','admin_id');
    }

    public function getDeliveryBoyStatusAttribute()
    {
        $status = 0;
        if($this->deliveryBoy){
            $status = $this->deliveryBoy->status;
        }
        return $status;
    }
}
