<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/**
 * Blocks a customer whose account was deactivated while they were still logged
 * in. Admin deactivation also revokes their tokens (see CustomersApiController),
 * but this is the belt-and-braces check on every authenticated customer request:
 * if the resolved user is deactivated, kill the token and return 401 so the app
 * treats it as a forced logout.
 */
class EnsureCustomerActive
{
    public function handle(Request $request, Closure $next)
    {
        $user = auth('api-customers')->user();

        if ($user && (int) $user->status === 0) {
            // Revoke the presented token so subsequent calls also 401.
            if (method_exists($user, 'token') && $user->token()) {
                $user->token()->revoke();
            }

            return response()->json([
                'status'      => 0,
                'status_code' => 401,
                'logout'      => true,
                'message'     => __('account_deactivated'),
            ], 401);
        }

        return $next($request);
    }
}
