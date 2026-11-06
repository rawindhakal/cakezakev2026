<?php

use App\Models\Admin;
use App\Models\Conversation;
use App\Models\Role;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
|
| Here you may register all of the event broadcasting channels that your
| application supports. The given channel authorization callbacks are
| used to check if an authenticated user can listen to the channel.
|
*/

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

/**
 * Private chat channel — authorized for any of the three actors that belong to
 * the conversation. Guards: web/api (admins + delivery boys) and api-customers.
 */
Broadcast::channel('chat.conversation.{id}', function ($user, $id) {
    $conversation = Conversation::find($id);
    if (!$conversation) {
        return false;
    }

    // Customer (api-customers guard resolves App\Models\User).
    if ($user instanceof User) {
        return (int) $conversation->user_id === (int) $user->id;
    }

    // Admin / Delivery boy (both are App\Models\Admin; delivery boy = role 3).
    if ($user instanceof Admin) {
        if ((int) $user->role_id === Role::$roleDeliveryBoy) {
            $deliveryBoyId = optional($user->deliveryBoy)->id;
            return $deliveryBoyId && (int) $conversation->delivery_boy_id === (int) $deliveryBoyId;
        }
        // Super Admin / Admin — and branch panel users — can listen.
        return in_array((int) $user->role_id, [Role::$roleSuperAdmin, Role::$roleAdmin], true)
            || $user->isBranchUser();
    }

    return false;
}, ['guards' => ['web', 'api', 'api-customers']]);

/** Admin inbox — any super admin / admin (sidebar unread badge). */
Broadcast::channel('chat.admins', function ($user) {
    return $user instanceof Admin
        && (in_array((int) $user->role_id, [Role::$roleSuperAdmin, Role::$roleAdmin], true)
            || $user->isBranchUser());
}, ['guards' => ['web', 'api']]);

/** Delivery-boy inbox — only that delivery boy. */
Broadcast::channel('chat.delivery_boy.{id}', function ($user, $id) {
    return $user instanceof Admin
        && (int) $user->role_id === Role::$roleDeliveryBoy
        && (int) optional($user->deliveryBoy)->id === (int) $id;
}, ['guards' => ['web', 'api']]);

/** Customer inbox. */
Broadcast::channel('chat.user.{id}', function ($user, $id) {
    return $user instanceof User && (int) $user->id === (int) $id;
}, ['guards' => ['api-customers']]);

/** Admin orders feed — any panel admin (not delivery boys) for live new-order updates. */
Broadcast::channel('admin.orders', function ($user) {
    return $user instanceof Admin && (int) $user->role_id !== Role::$roleDeliveryBoy;
}, ['guards' => ['web', 'api']]);
