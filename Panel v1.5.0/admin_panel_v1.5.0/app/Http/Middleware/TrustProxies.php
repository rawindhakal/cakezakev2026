<?php

namespace App\Http\Middleware;

use Illuminate\Http\Middleware\TrustProxies as Middleware;
use Illuminate\Http\Request;

class TrustProxies extends Middleware
{
    /**
     * The trusted proxies for this application.
     *
     * @var array<int, string>|string|null
     */
    protected $proxies;

    /**
     * Read the proxy list from config (TRUSTED_PROXIES in .env): `*` behind Cloudflare or
     * any load balancer whose address is not fixed, or a comma-separated list of proxy
     * IPs / CIDRs. With it set, `$request->ip()` — and therefore sessions, throttling and
     * every stored IP — resolves to the visitor instead of the proxy. Left empty, nothing
     * is trusted and forwarded headers are ignored (Laravel's default).
     */
    public function __construct()
    {
        $proxies = trim((string) config('app.trusted_proxies', ''));
        if ($proxies === '') {
            return;
        }

        $this->proxies = $proxies === '*'
            ? '*'
            : array_values(array_filter(array_map('trim', explode(',', $proxies))));
    }

    /**
     * The headers that should be used to detect proxies.
     *
     * @var int
     */
    protected $headers =
        Request::HEADER_X_FORWARDED_FOR |
        Request::HEADER_X_FORWARDED_HOST |
        Request::HEADER_X_FORWARDED_PORT |
        Request::HEADER_X_FORWARDED_PROTO |
        Request::HEADER_X_FORWARDED_AWS_ELB;
}
