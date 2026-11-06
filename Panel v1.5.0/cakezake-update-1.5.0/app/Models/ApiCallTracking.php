<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class ApiCallTracking extends Model
{
    protected $table = 'api_call_tracking';
    
    protected $fillable = [
        'api_name',
        'source',
        'count'
    ];

    /**
     * Increment the count for a specific API and source
     * If the record doesn't exist, create it with count = 1
     */
    public static function incrementCallCount($apiName, $source)
    {
        return self::updateOrCreate(
            [
                'api_name' => $apiName,
                'source' => $source
            ],
            [
                'count' => DB::raw('count + 1')
            ]
        );
    }

    /**
     * Get call count for a specific API and source
     */
    public static function getCallCount($apiName, $source)
    {
        $record = self::where('api_name', $apiName)
                     ->where('source', $source)
                     ->first();
        
        return $record ? $record->count : 0;
    }

    /**
     * Get all call counts for a specific API
     */
    public static function getCallCountsByApi($apiName)
    {
        return self::where('api_name', $apiName)->get();
    }

    /**
     * Get all call counts for a specific source
     */
    public static function getCallCountsBySource($source)
    {
        return self::where('source', $source)->get();
    }
} 