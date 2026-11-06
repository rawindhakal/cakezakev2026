<?php

use App\Http\Controllers\API\AdminAuthController;
use App\Http\Controllers\API\Customer\BasicApiController;
use App\Http\Controllers\API\ChatApiController;
use App\Http\Controllers\API\CountryApiController;
use App\Http\Controllers\API\DeliveryBoysApiController;
use App\Http\Controllers\API\LanguageApiController;
use App\Http\Controllers\API\NotificationPreferencesApiController;
use App\Http\Controllers\API\OrdersApiController;
use App\Http\Controllers\API\WithdrawalRequestsApiController;
use App\Http\Controllers\DeliveryBoyController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Route;

// Public (no auth)
Route::post('register', [AdminAuthController::class, 'deliveryBoyRegister']);
Route::post('login', [AdminAuthController::class, 'login']);

Route::middleware('conditional')->group(function () {
    Route::get('settings', [DeliveryBoyController::class, 'getSettings']);
    Route::get('country_setting', [DeliveryBoyController::class, 'getCountrySetting']);
    Route::get('system_languages', [LanguageApiController::class, 'getSystemLanguages']);
    Route::get('countries', [CountryApiController::class, 'active']);
    Route::get('zones', [DeliveryBoyController::class, 'zones']);
});

// Authenticated delivery boy (Passport guard; the logged-in admin's linked boy)
Route::middleware(['auth:api', 'conditional'])->group(function () {

    Route::post('broadcasting/auth', fn(Request $request) => Broadcast::auth($request));

    // Profile (self — derived from the authenticated user, no id param)
    Route::get('edit', [DeliveryBoysApiController::class, 'edit']);
    Route::post('update', [DeliveryBoysApiController::class, 'update'])->name('delivery_boy.update');
    Route::post('reset_password', [DeliveryBoyController::class, 'resetPassword'])->name('delivery_boy.reset_password');
    Route::get('notification_preferences', [NotificationPreferencesApiController::class, 'deliveryBoyIndex']);
    Route::post('notification_preferences', [NotificationPreferencesApiController::class, 'deliveryBoySave']);
    Route::get('get_delivery_boy_status', [DeliveryBoysApiController::class, 'getStatus'])->name('delivery_boy.get_status');
    Route::post('update_delivery_boy_status', [DeliveryBoysApiController::class, 'updateStatus'])->name('delivery_boy.update_boy_status');

    // Auth / device
    Route::post('add_fcm_token', [AdminAuthController::class, 'addFcmToken'])->name('delivery_boy.add_fcm_token');
    Route::post('update_fcm_token', [AdminAuthController::class, 'updateFcmToken'])->name('delivery_boy.update_fcm_token');
    Route::post('logout', [AdminAuthController::class, 'logout'])->name('delivery_boy.logout');

    // Dashboard / orders
    Route::get('dashboard', [DeliveryBoyController::class, 'index']);
    Route::get('orders', [DeliveryBoyController::class, 'getOrders']);
    // Ecommerce: item-wise list + per-item status update.
    Route::get('ecom_orders', [DeliveryBoyController::class, 'getEcomOrders']);
    Route::post('update_item_status', [DeliveryBoyController::class, 'updateItemStatus']);
    Route::get('order_by_id', [DeliveryBoyController::class, 'getOrder']);
    Route::post('scan_delivery_receipt', [DeliveryBoyController::class, 'scanDeliveryReceipt']);
    Route::post('update_status', [OrdersApiController::class, 'updateStatus'])->name('delivery_boy.update_status');
    Route::get('order_statuses', [DeliveryBoyController::class, 'getOrderStatus']);

    // Earnings
    Route::get('cash_collection', [DeliveryBoyController::class, 'getCashCollection']);
    Route::get('settlement_history', [DeliveryBoyController::class, 'getSettlementHistory']);
    Route::get('salary_transactions', [DeliveryBoyController::class, 'getSalaryTransactions']);

    // Account
    Route::get('delete_account', [BasicApiController::class, 'deleteDeliveryBoyAccount'])->name('delivery_boy.delete_account');

    // Withdrawal requests
    Route::group(['prefix' => 'withdrawal_requests'], function () {
        Route::get('/', [WithdrawalRequestsApiController::class, 'getWithdrawalRequests']);
        Route::post('add', [DeliveryBoyController::class, 'addWithdrawalRequest']);
    });

    // Return requests
    Route::get('return_requests', [DeliveryBoyController::class, 'returnRequests']);
    Route::post('return_request_status_update', [DeliveryBoyController::class, 'deliveryBoyUpdate'])->name('delivery_boy.return_requests.update');

    // Live tracking
    Route::post('manage_live_tracking', [DeliveryBoyController::class, 'manageLiveTracking'])->name('delivery_boy.manage_live_tracking');

    // Chat
    Route::group(['prefix' => 'chat'], function () {
        Route::get('conversations', [ChatApiController::class, 'deliveryBoyConversations']);
        Route::post('start_admin', [ChatApiController::class, 'deliveryBoyStartAdmin']);
        Route::post('start_order', [ChatApiController::class, 'deliveryBoyStartOrder']);
        Route::get('messages', [ChatApiController::class, 'deliveryBoyMessages']);
        Route::get('unread_count', [ChatApiController::class, 'deliveryBoyUnreadCount']);
        Route::post('mark_read', [ChatApiController::class, 'deliveryBoyMarkRead']);
        Route::post('send', [ChatApiController::class, 'deliveryBoySend'])->name('delivery_boy.chat.send');
    });
});
