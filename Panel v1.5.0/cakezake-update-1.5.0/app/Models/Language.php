<?php

namespace App\Models;

use App\Helpers\CommonHelper;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Traits\LogsActivity;

class Language extends Model
{
    use HasFactory, LogsActivity;
    protected $hidden = ['created_at','updated_at'];
    // Translation strings live in files (see LanguageFileService), not on this row.
    protected $fillable = ['supported_language_id','system_type','is_default','display_name','status','slug'];
    protected $appends = ['system_type_name'];

    public const SYSTEM_TYPE_CUSTOMER_APP = 1;
    public const SYSTEM_TYPE_DELIVERY_BOY_APP = 2;
    public const SYSTEM_TYPE_WEBSITE = 3;
    public const SYSTEM_TYPE_ADMIN_PANEL = 4;

    public static $systemTypeCustomerApp = self::SYSTEM_TYPE_CUSTOMER_APP;
    public static $systemTypeDeliveryBoyApp = self::SYSTEM_TYPE_DELIVERY_BOY_APP;
    public static $systemTypeWebsite = self::SYSTEM_TYPE_WEBSITE;
    public static $systemTypeAdminPanel = self::SYSTEM_TYPE_ADMIN_PANEL;


    public static function get_system_types(): array {
        $string = CommonHelper::getColumnComment("languages", "system_type");
        $arrays = explode(',',$string);
        $system_types = array();
        foreach ($arrays as $key => $code){
            $data = array();
            $array = explode('=>',$code);
            $data['id'] = intval($array[0]);
            $data['name'] = trim($array[1]);
            $system_types[$key] = $data;
        }
        return $system_types;
    }

    public function getSystemTypeNameAttribute(){
        $system_types = $this->get_system_types();
        $system_type = $this->system_type;

        $filtered_array = array_filter($system_types, function($element) use ($system_type) {
            return $element['id'] == $system_type;
        });
        $type_array = reset($filtered_array);
        return $type_array['name'];
    }

    public function getTypeAttribute($value)
    {
        return strtoupper($value);
    }

    /**
     * Slug derived from the linked supported language's name: lowercase, non-alphanumeric
     * -> hyphen, parenthetical qualifier dropped ("Catalan (Valencian)" -> "catalan").
     */
    public static function makeSlug(string $name): string
    {
        $base = preg_replace('/\(.*$/', '', $name);
        $base = trim(strtolower(preg_replace('/[^a-z0-9]+/i', '-', (string) $base)), '-');
        return $base !== '' ? $base : 'language';
    }

    public static function slugForSupportedLanguage($supportedLanguageId): string
    {
        $name = SupportedLanguage::where('id', $supportedLanguageId)->value('name');
        return self::makeSlug((string) $name);
    }

    protected static function booted()
    {
        // Set on create from the supported language name. Supported language is not
        // editable on update, so the slug is never regenerated afterwards.
        static::creating(function (Language $language) {
            if (empty($language->slug)) {
                $language->slug = self::slugForSupportedLanguage($language->supported_language_id);
            }
        });
    }

}
