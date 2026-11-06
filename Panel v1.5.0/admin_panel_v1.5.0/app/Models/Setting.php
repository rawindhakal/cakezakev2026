<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class Setting extends Model
{
    use HasFactory, LogsActivity;

    public $timestamps = false;
    protected $fillable = ['variable', 'value'];

    public static $codModeGlobal = "global";
    public static $codModeProduct = "product";


    public static function get_value($name)
    {
        return self::where('variable', $name)->value('value') ?? '';
    }

    public static function update_value($name, $value)
    {
        $settings = self::where('variable', $name);
        if ($settings->count() == 0) throw new \Exception("Empty Setting for " . $name);

        $setting = $settings->first();
        $setting->value = $value;
        $setting->save();
    }
}
