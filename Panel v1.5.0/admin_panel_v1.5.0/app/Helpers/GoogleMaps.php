<?php
namespace App\Helpers;

use App\Models\Setting;

class GoogleMaps
{
    var $secret_key = "";

    function __construct()
    {
        $this->secret_key = Setting::get_value('apiKey');
    }

    public function findGoogleMapDistance($origins = "", $destinations = "")
    {
        $origin = self::waypoint($origins);
        $destination = self::waypoint($destinations);

        if (!$origin || !$destination) {
            return ['body' => json_encode(['error' => ['message' => 'Invalid coordinates']]), 'http_code' => 400];
        }

        return self::routesCurl('https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix', [
            'origins'      => [$origin],
            'destinations' => [$destination],
            'travelMode'   => 'DRIVE',
        ], 'originIndex,destinationIndex,distanceMeters,duration,condition,status');
    }

    /** "lat,lng" → the Routes waypoint shape; null when either number is missing. */
    private static function waypoint($pair)
    {
        $parts = array_map('trim', explode(',', (string) $pair));
        if (count($parts) !== 2 || $parts[0] === '' || $parts[1] === '') {
            return null;
        }

        return ['waypoint' => ['location' => ['latLng' => [
            'latitude'  => (float) $parts[0],
            'longitude' => (float) $parts[1],
        ]]]];
    }

    /** POST to a googleapis v2 endpoint: key and field mask go in headers, body is JSON. */
    private function routesCurl($url, array $body, $fieldMask)
    {
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_RETURNTRANSFER => 1,
            CURLOPT_TIMEOUT        => 30,
            CURLOPT_POST           => 1,
            CURLOPT_POSTFIELDS     => json_encode($body),
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                'X-Goog-Api-Key: ' . $this->secret_key,
                'X-Goog-FieldMask: ' . $fieldMask,
            ],
        ]);
        $result = array(
            'body' => curl_exec($ch),
            'http_code' => curl_getinfo($ch, CURLINFO_HTTP_CODE),
        );
        unset($ch);

        return $result;
    }

}
?>
