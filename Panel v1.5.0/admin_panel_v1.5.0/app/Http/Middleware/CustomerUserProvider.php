<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class CustomerUserProvider
{

    public function handle(Request $request, Closure $next)
    {
        config(['auth.guards.api.provider' => 'users']);

        return $next($request);
    }
}
