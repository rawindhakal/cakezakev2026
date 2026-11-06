<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Passport\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;
use App\Traits\LogsActivity;
class User extends Authenticatable
{
    use SoftDeletes, LogsActivity;
    use HasApiTokens, HasFactory, Notifiable,HasRoles;

    protected $fillable = ['email','name','password','mobile','friends_code','language_id'];

    protected $hidden = ['password'];


    public static $deactive = 0;
    public static $active = 1;
    public static $register = 2;

    public static $activeStatus = "Active";
    public static $deactiveStatus = "Deactive";
    public static $registerStatus = "Register";

    public function getProfileAttribute($value){
        if(trim((string) $value) == ""){
            return asset('images/user_default_profile.png');
        }
        return asset('storage/'.$value);
    }

    /**
     * Back-compat virtual balance: wallets are country-wise now (user_wallets).
     * Reads the user's registration-country wallet. Writes must use the country-aware
     * CommonHelper wallet helpers.
     */
    public function getBalanceAttribute()
    {
        return (float) (UserWallet::where('user_id', $this->id)
            ->where('country_id', (int) ($this->country_id ?? 0))
            ->value('balance') ?? 0);
    }

    public function language()
    {
        return $this->belongsTo(Language::class, 'language_id');
    }

    public function country()
    {
        return $this->belongsTo(Country::class, 'country_id');
    }

    public function wallets()
    {
        return $this->hasMany(UserWallet::class, 'user_id');
    }
}
