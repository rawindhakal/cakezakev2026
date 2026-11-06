<?php

use App\Http\Controllers\API\BlogsApiController;
use App\Http\Controllers\API\CountryApiController;
use App\Http\Controllers\API\Customer\AddressApiController;
use App\Http\Controllers\API\Customer\BasicApiController;
use App\Http\Controllers\API\Customer\CartApiController;
use App\Http\Controllers\API\Customer\ChatApiController as CustomerChatApiController;
use App\Http\Controllers\API\Customer\CustomerAuthController;
use App\Http\Controllers\API\Customer\OrderApiController;
use App\Http\Controllers\WebhookController;
use App\Http\Controllers\API\Customer\ProductsApiController;
use App\Http\Controllers\API\Customer\SettingApiController;
use App\Http\Controllers\API\Customer\ShippingApiController as CustomerShippingApiController;
use App\Http\Controllers\API\Customer\SpinWheelApiController as CustomerSpinWheelApiController;
use App\Http\Controllers\API\Customer\HomeLayoutApiController as CustomerHomeLayoutApiController;
use App\Http\Controllers\API\LanguageApiController;
use App\Http\Controllers\API\OrdersApiController;
use App\Http\Controllers\API\GeneralSettingsApiController;
use App\Http\Controllers\API\NotificationPreferencesApiController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Route;

// Map / Places routes (public). Provider-agnostic — pick google vs OSM
Route::get('/places_autocomplete', [GeneralSettingsApiController::class, 'placesAutocomplete']);
Route::get('/places_details', [GeneralSettingsApiController::class, 'placesDetails']);
Route::get('/maps_geocoding', [GeneralSettingsApiController::class, 'mapsGeocoding']);

Route::group(['middleware' => ['auth.customer', 'conditional']], function () {

    Route::post('send_sms', [CustomerAuthController::class, 'sendSms']);
    Route::post('verify_user', [CustomerAuthController::class, 'verifyContact']);
    Route::post('register', [CustomerAuthController::class, 'register']);
    Route::post('verify_email', [CustomerAuthController::class, 'verifyEmail']);
    Route::post('verify_user_exist', [CustomerAuthController::class, 'verifyUserExist']);
    Route::post('login', [CustomerAuthController::class, 'login']);
    Route::get('login', [CustomerAuthController::class, 'notLogin'])->name('login');
    Route::post('add_fcm_token', [CustomerAuthController::class, 'addFcmToken']);
    Route::post('send_email_forgot_password_otp', [CustomerAuthController::class, 'forgetPasswordOtp']);
    Route::post('forgot_password', [CustomerAuthController::class, 'forgotPassword']);

    // Guest
    Route::get('categories', [BasicApiController::class, 'getCategories']);
    Route::get('home_layout', [CustomerHomeLayoutApiController::class, 'getHomeLayout']);
    Route::get('brands', [BasicApiController::class, 'getBrands']);

    Route::get('categories/get_seo', [BasicApiController::class, 'getSeoThings']);
    Route::get('page_builder', [CustomerHomeLayoutApiController::class, 'getPage']);
    Route::get('countries', [CountryApiController::class, 'active']);
    Route::get('cart/guest_cart', [CartApiController::class, 'getGuestCart']);

    /* Pincode serviceability. Guest-reachable on purpose: a shopper should find out a
       parcel cannot reach them before filling a cart. Answers "cannot check" when no
       courier plugin is installed. */
    Route::post('check_serviceability', [CustomerShippingApiController::class, 'checkServiceability']);

    Route::group(['prefix' => 'products'], function () {
        Route::get('/', [ProductsApiController::class, 'getProducts']);
        Route::get('filters', [ProductsApiController::class, 'getProductFilters']);
        Route::get('ratings_list', [ProductsApiController::class, 'productRatingsList']);
        Route::get('rating/image_list', [ProductsApiController::class, 'productRatingImageList']);
        Route::get('get_seo', [ProductsApiController::class, 'getSeoThings']);
    });
    Route::get('product_by_id', [ProductsApiController::class, 'getProduct']);
    Route::get('cart/recommendations', [CartApiController::class, 'getCartRecommendations']);
    Route::get('faqs', [BasicApiController::class, 'getFaqs']);
    Route::get('social_media', [BasicApiController::class, 'getSocialMedia']);

    // Settings
    Route::group(['prefix' => 'settings'], function () {
        Route::get('/', [SettingApiController::class, 'getSettings']);
        Route::get('payment_methods', [SettingApiController::class, 'getPaymentMethods']);
        Route::get('get_seo_settings', [SettingApiController::class, 'getSeoSettings']);
    });
    
    Route::get('country_setting', [SettingApiController::class, 'getCountrySetting']);
    Route::get('regions', [AddressApiController::class, 'regions']);
    Route::get('blogs', [BasicApiController::class, 'getBlogs']);
    Route::get('blog_categories', [BasicApiController::class, 'getBlogCategories']);
    Route::post('blog_view_count', [BlogsApiController::class, 'trackBlogView']);
    Route::get('blogs/most_viewed', [BlogsApiController::class, 'getMostViewedBlogs']);
    Route::get('blog_popular_tags', [BlogsApiController::class, 'getPopularBlogTags']);

    //Languages
    Route::get('system_languages', [LanguageApiController::class, 'getSystemLanguages']);

    // zone deliverable
    Route::get('zone', [BasicApiController::class, 'getZone']);
    Route::get('zones', [BasicApiController::class, 'getZones']);

    Route::get('notifications', [BasicApiController::class, 'getNotifications']);

    // Spin wheel: the wheel itself is public (a guest sees the teaser)
    Route::get('spin_wheel', [CustomerSpinWheelApiController::class, 'index']);

    /***********************************************************************************************/
    // API After Login here
    Route::group(['middleware' => ['auth:api-customers', 'customer.active']], function () {

        // Token-authenticated broadcasting auth (Echo private channels for customers).
        Route::post('broadcasting/auth', fn(Request $request) => Broadcast::auth($request));

        // User
        Route::post('logout', [CustomerAuthController::class, 'logout']);
        Route::post('delete_account', [CustomerAuthController::class, 'deleteAccount']);
        Route::post('edit_profile', [CustomerAuthController::class, 'editProfile']);
        Route::post('reset_password', [CustomerAuthController::class, 'ResetPassword']);
        Route::post('update_fcm_token', [CustomerAuthController::class, 'updateFcmToken']);
        Route::get('user_details', [CustomerAuthController::class, 'getLoginUserDetails']);
        Route::get('notification_preferences', [NotificationPreferencesApiController::class, 'customerIndex']);
        Route::post('notification_preferences', [NotificationPreferencesApiController::class, 'customerSave']);

        // Transactions
        Route::get('get_user_transactions', [BasicApiController::class, 'getUserTransactions']);

        // Address
        Route::group(['prefix' => 'address'], function () {
            Route::get('/', [AddressApiController::class, 'getAddress']);
            Route::post('add', [AddressApiController::class, 'save']);
            Route::post('update', [AddressApiController::class, 'update']);
            Route::post('delete', [AddressApiController::class, 'delete']);
        });

        // Favorites
        Route::group(['prefix' => 'favorites'], function () {
            Route::get('/', [BasicApiController::class, 'getFavorites']);
            Route::post('add', [BasicApiController::class, 'addToFavorite']);
            Route::post('remove', [BasicApiController::class, 'removeFromFavorite']);
        });

        // Carts
        Route::group(['prefix' => 'cart'], function () {
            Route::get('/', [CartApiController::class, 'getUserCart']);
            Route::post('add', [CartApiController::class, 'addToCart']);
            Route::post('remove', [CartApiController::class, 'removeFromCart']);
            Route::post('bulk_add_to_cart_items', [CartApiController::class, 'BulkAddToCartItems']);
        });

        Route::post('spin_wheel/spin', [CustomerSpinWheelApiController::class, 'spin']);
        // What this customer has won and can still use.
        Route::get('spin_wheel/rewards', [CustomerSpinWheelApiController::class, 'rewards']);

        // Promo Code
        Route::group(['prefix' => 'promo_code'], function () {
            Route::get('/', [BasicApiController::class, 'getPromoCode']);
            Route::post('validate', [BasicApiController::class, 'validatePromoCode']);
        });

        // Chat
        Route::group(['prefix' => 'chat'], function () {
            Route::post('start_admin', [CustomerChatApiController::class, 'startAdmin']);
            Route::post('start_order_delivery_boy', [CustomerChatApiController::class, 'startOrderDeliveryBoy']);
            Route::post('start_order_admin', [CustomerChatApiController::class, 'startOrderAdmin']);
            Route::get('messages', [CustomerChatApiController::class, 'messages']);
            Route::post('mark_read', [CustomerChatApiController::class, 'markRead']);
            Route::post('send', [CustomerChatApiController::class, 'send'])->name('customer.chat.send');
        });

        Route::group(['prefix' => 'products'], function () {
            Route::post('rating/add', [ProductsApiController::class, 'productRatingSave']);
            Route::post('rating/edit', [ProductsApiController::class, 'productRatingEdit']);
            Route::post('rating/update', [ProductsApiController::class, 'productRatingUpdate']);
            Route::get('recently_visited', [ProductsApiController::class, 'getRecentlyVisitedProducts']);
            Route::post('add_recently_visited_product', [ProductsApiController::class, 'addRecentlyVisitedProduct']);
        });

        // order
        Route::get('orders', [OrderApiController::class, 'getOrders']); //Quick orders
        Route::get('ecom_orders', [OrderApiController::class, 'getEcomOrders']); //Ecommerce orders
        Route::post('invoice_download', [OrderApiController::class, 'downloadOrderInvoice']);
        Route::post('item_invoice_download', [OrdersApiController::class, 'downloadOrderItemInvoice']);
        Route::get('order_status_lists', [BasicApiController::class, 'getOrderStatusLists']);
        Route::get('live_tracking', [OrderApiController::class, 'getLiveTrackingDetails']);

        //Checkout
        Route::post('place_order', [OrderApiController::class, 'placeOrder']);
        Route::post('payment_proof', [OrderApiController::class, 'submitPaymentProof']);
        Route::post('initiate_transaction', [OrderApiController::class, 'initiateTransaction']);
        // A payment SDK asking the server to sign one of its own calls.
        Route::post('payment_sdk_hash', [OrderApiController::class, 'paymentSdkHash']);
        Route::post('add_transaction', [OrderApiController::class, 'addTransaction']);
        Route::post('update_order_status', [OrderApiController::class, 'updateOrderStatus']);
        Route::post('delete_order', [OrderApiController::class, 'deletePaymentPendingOrder']);

        //Phonepe
        Route::get('order_status_phonepe', [WebhookController::class, 'getOrderStatusPhonepe']);
    });
});

/* Gifting: occasions, recipient relationships and delivery types for the storefront and apps. */
Route::get('gifting/meta', function () {
    $rows = fn ($t) => \Illuminate\Support\Facades\DB::table($t)->where('status', 1)->orderBy('sort_order')->get()
        ->map(fn ($r) => collect($r)->except(['created_at', 'updated_at', 'status'])->all());
    return \App\Helpers\CommonHelper::responseWithData([
        'occasions' => $rows('occasions'),
        'relationships' => $rows('relationships'),
        'delivery_types' => $rows('gift_delivery_types'),
    ]);
})->name('customer.gifting.meta');

/* Scheduled delivery: booking window + per-date slot availability for the checkout picker. */
Route::get('gifting/schedule', function () {
    return \App\Helpers\CommonHelper::responseWithData(app(\App\Services\DeliverySchedulingService::class)->config());
})->name('customer.gifting.schedule');
Route::get('gifting/slots', function (\Illuminate\Http\Request $request) {
    $svc = app(\App\Services\DeliverySchedulingService::class);
    $date = $request->query('date', $svc->now()->toDateString());
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $date)) {
        return \App\Helpers\CommonHelper::responseError('Invalid date.');
    }
    return \App\Helpers\CommonHelper::responseWithData($svc->slotsFor($date));
})->name('customer.gifting.slots');
