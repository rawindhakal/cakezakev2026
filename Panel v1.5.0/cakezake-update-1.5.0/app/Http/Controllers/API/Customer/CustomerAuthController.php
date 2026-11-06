<?php

namespace App\Http\Controllers\API\Customer;

use App\Helpers\CommonHelper;
use App\Helpers\SmsHelper;
use App\Http\Controllers\Controller;
use App\Models\NotificationPreference;
use App\Models\Setting;
use App\Models\SmsVerification;
use App\Models\UserToken;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use App\Models\User;
use Illuminate\Validation\Rule;

class CustomerAuthController extends Controller
{
    
    private function normalizeCountryCode($code): string
    {
        $default = Setting::where('variable', 'country_code')->value('value') ?? '+91';
        // Ensure default itself is normalized
        if ($default && !str_starts_with($default, '+')) {
            $default = '+' . ltrim(preg_replace('/\D/', '', $default), '0');
        }

        if (!$code) {
            return $default;
        }

        $digits = preg_replace('/\D/', '', (string) $code);

        if (!$digits) {
            return $default;
        }

        return '+' . ltrim($digits, '0');
    }

    /**
     * @param int|null $countryId When given, `balance` is that country's wallet; otherwise
     *                            the user's home-country balance (back-compat).
     */
    private function formatUserResponse($user, $accessToken = null, $countryId = null): array
    {
        $balance = $countryId
            ? CommonHelper::getUserWalletBalance($user->id, $countryId)
            : $user->balance;

        $data = [
            'id'            => $user->id,
            'name'          => $user->name,
            'email'         => $user->email,
            'country_code'  => $user->country_code,
            'country_id'    => (int) $user->country_id,
            'mobile'        => $user->mobile,
            'profile'       => $user->profile,
            'balance'       => $balance,
            'wallets'       => CommonHelper::getUserWallets($user->id),
            'referral_code' => $user->referral_code ?? '',
            'type'          => $user->type,
        ];

        if ($accessToken !== null) {
            $data['access_token'] = $accessToken;
        }

        return $data;
    }

    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'type'    => 'required|in:phone,google,apple,email',
            'id'      => 'required', // mobile for phone, email for google/apple/email
            'country_code' => 'required_if:type,phone|nullable|string',
            'phone_auth_type' => 'required_if:type,phone|in:phone_auth_otp,phone_auth_password',
            'password' => [
                'required_if:type,email',
            ],
        ], [
            'password.min' => 'invalid_password',
        ]);

        if ($validator->fails()) {
            $firstKey = $validator->errors()->first();
            return CommonHelper::responseError($firstKey, strtoupper($firstKey));
        }
        if ($request->type == 'phone') {
            $loginCountryCode = $this->normalizeCountryCode($request->input('country_code'));
            // Find user by mobile+country_code regardless of registration type.
            // This lets an email-registered user who added a mobile in their profile log in via phone.
            $user = User::where('mobile', $request->id)
                ->where('country_code', $loginCountryCode)
                ->where('status', 0)
                ->first();
            if ($user) {
                return CommonHelper::responseError('user_deactivated', 'USER_DEACTIVATED');
            }
            $user = User::where('mobile', $request->id)
                ->where('country_code', $loginCountryCode)
                ->first();

            if (!$user) {
                return CommonHelper::responseError('user_not_exist', 'USER_NOT_EXIST');
            }

            if ($request->phone_auth_type == 'phone_auth_password') {
                if (empty($user->password)) {
                    return CommonHelper::responseError('user_exist_password_blank', 'USER_EXIST_PASSWORD_BLANK');
                }
            }
            Auth::login($user);
            if (
                ($request->type == 'email' || ($request->type == 'phone' && $request->phone_auth_type == 'phone_auth_password'))
            ) {
                if (empty($user->password) || !password_verify($request->password, $user->password)) {
                    return CommonHelper::responseError(__('invalid_password'), 'INVALID_PASSWORD');
                }
            }
            $accessToken = $user->createToken('authToken')->accessToken;
            $res = $this->formatUserResponse($user, $accessToken);
            // **Update or create FCM token - match by user_id + fcm_token**
            if (isset($request->fcm_token)) {
                UserToken::updateOrCreate(
                    ['user_id' => auth()->user()->id, 'fcm_token' => $request->fcm_token],
                    ['type' => 'customer', 'platform' => $request->platform ?? 'android', 'language_id' => $request->input('language_id') ?: CommonHelper::getDefaultLanguageId()]
                );
            }

            return CommonHelper::responseSuccessWithData('user_already_exist', $res, 'USER_ALREADY_EXIST');
        }

        if ($request->type === 'email') {
            // Allow a phone-registered user (who has this email in their profile) to log in via email.
            // Social accounts (google/apple) still can't be password-logged.
            $existingUserWithDifferentType = User::where('email', $request->id)
                ->whereNotIn('type', [$request->type, 'phone'])
                ->first();

            if ($existingUserWithDifferentType) {
                $existType = $existingUserWithDifferentType->type;
                return CommonHelper::responseError('user_exist_with_' . $existType, 'USER_EXIST_WITH_' . strtoupper($existType));
            }

            $user =  User::where('email', $request->id)
                ->where('type', $request->type)
                ->where('status', 0)
                ->first();
            if ($user) {
                return CommonHelper::responseError('user_deactivated', 'USER_DEACTIVATED');
            }
            $user = User::where('email', $request->id)
                ->where('is_verified', 0)
                ->where('type', $request->type)
                ->first();

            if ($user) {
                $verificationCode = rand(100000, 999999);
                $user->email_verification_code = $verificationCode;
                $user->is_verified = false; // Initially not verified

                try {
                    CommonHelper::sendMailByTemplate($user->email, 'verify_email_customer', [
                        'customer_name' => $user->name ?? '',
                        'code'          => $verificationCode,
                    ], $user->language_id ? (int) $user->language_id : null);

                    $user->save();
                } catch (\Exception $e) {
                    Log::error('Failed to send verification email: ' . $e->getMessage());
                    return CommonHelper::responseError('failed_to_send_verification_email', 'FAILED_TO_SEND_VERIFICATION_EMAIL');
                }

                return CommonHelper::responseError('email_not_verified', 'EMAIL_NOT_VERIFIED');
            }
        }

        if (in_array($request->type, ['google', 'apple'])) {

            $user =  User::where('email', $request->id)
                ->where('type', $request->type)
                ->where('status', 0)
                ->first();
            if ($user) {
                return CommonHelper::responseError('user_deactivated', 'USER_DEACTIVATED');
            }
            $user = User::where('email', $request->id)->first();

            if ($user) {
                if (strtolower($user->type) !== strtolower($request->type)) {
                    Auth::login($user);
                    return CommonHelper::responseError('user_exist_with_' . $user->type, 'USER_EXIST_WITH_' . strtoupper($user->type));
                }
            }
        }

        if ($request->type === 'phone') {
            $loginCountryCode = $this->normalizeCountryCode($request->input('country_code'));
            $user = User::select('id', 'name', 'email', 'country_code', 'mobile', 'profile', 'country_id', 'referral_code', 'status', 'type', 'password')
                ->where('type', $request->type)
                ->where('mobile', $request->id)
                ->where('country_code', $loginCountryCode)
                ->first();
        } elseif (in_array($request->type, ['google', 'apple'])) {
            $user = User::select('id', 'name', 'email', 'country_code', 'mobile', 'profile', 'country_id', 'referral_code', 'status', 'type')
                ->where('type', $request->type)
                ->where('email', $request->id)
                ->first();
        } elseif ($request->type === 'email') {
            // Match a verified email-registered user, OR a phone-registered user that owns this email.
            $user = User::select('id', 'name', 'email', 'password', 'country_code', 'mobile', 'profile', 'country_id', 'referral_code', 'status', 'type')
                ->where('email', $request->id)
                ->where(function ($q) {
                    $q->where(function ($q2) {
                        $q2->where('type', 'email')->where('is_verified', 1);
                    })->orWhere('type', 'phone');
                })
                ->first();
        }

        if ($user) {
            // **For email login and phone login with password**
            if (
                ($request->type == 'email' || ($request->type == 'phone' && $request->phone_auth_type == 'phone_auth_password'))
            ) {
                if (empty($user->password) || !password_verify($request->password, $user->password)) {
                    return CommonHelper::responseError(__('invalid_password'), 'INVALID_PASSWORD');
                }
            }

            // **Check if the user is inactive**
            if ($user->status == User::$deactive) {
                return CommonHelper::responseError(__('this_customer_account_is_deactivated_kindly_contact_admin'), 'ACCOUNT_DEACTIVATED');
            }

            // **Login user and create access token**
            Auth::login($user);
            $accessToken = $user->createToken('authToken')->accessToken;
            $res = $this->formatUserResponse($user, $accessToken);

            // **Update or create FCM token - match by user_id + fcm_token**
            if (isset($request->fcm_token)) {
                UserToken::updateOrCreate(
                    ['user_id' => auth()->user()->id, 'fcm_token' => $request->fcm_token],
                    ['type' => 'customer', 'platform' => $request->platform ?? 'android', 'language_id' => $request->input('language_id') ?: CommonHelper::getDefaultLanguageId()]
                );
            }

            return CommonHelper::responseSuccessWithData('success', $res, 'SUCCESS');
        } else {
            return CommonHelper::responseError(__('user_not_exist'), 'USER_NOT_EXIST');
        }
    }

    public function register(Request $request)
    {
        $requestData = $request->all();

        $registerCountryCode = $this->normalizeCountryCode($request->input('country_code'));
        $mobileRules = ['required_if:type,phone', 'nullable', 'numeric'];

        if ($request->filled('mobile')) {
            $mobileRules[] = Rule::unique('users', 'mobile')
                ->where(function ($query) use ($registerCountryCode) {
                    $query->where('country_code', $registerCountryCode)
                        ->where(function ($q) {
                            $q->where('type', '!=', 'phone')->orWhere('is_verified', 1);
                        });
                })
                ->whereNull('deleted_at');
        }

        $validator = Validator::make($requestData, [
            'type'            => 'required|in:phone,apple,google,email',
            'country_code'    => 'required_if:type,phone|nullable|string',
            'mobile'          => $mobileRules,
            'email'           => 'required_if:type,apple,google,email|email',
            'phone_auth_type' => 'nullable|in:phone_auth_otp,phone_auth_password',
            'password'        => [
                'nullable',
                function ($attribute, $value, $fail) use ($request) {
                    if (
                        ($request->type == 'phone' && $request->phone_auth_type == 'phone_auth_password') ||
                        $request->type == 'email'
                    ) {
                        if (empty($value)) {
                            $fail('password_required');
                        }
                    }
                }
            ],
        ], [
            'mobile.unique' => 'mobile_number_already_registered_please_login',
            'email.unique' => 'email_already_taken',
        ]);


        if ($validator->fails()) {
            $firstKey = $validator->errors()->first();
            return CommonHelper::responseError($firstKey, strtoupper($firstKey));
        }

        // Enforce the configured password policy wherever a password is supplied.
        if ($request->filled('password')
            && ($pwErr = CommonHelper::validatePasswordPolicy($request->password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }

        try {
            // Mobile + country_code is unique across ALL types. An unverified phone row
            // is an abandoned attempt, so it is reused rather than refused.
            $pendingUser = null;
            if ($request->type == 'phone') {
                $existing = User::where('mobile', $request->mobile)
                    ->where('country_code', $registerCountryCode)
                    ->first();
                if ($existing) {
                    if ((int) $existing->is_verified === 1 || $existing->type !== 'phone') {
                        return CommonHelper::responseError('user_already_exist', 'USER_ALREADY_EXIST');
                    }
                    $pendingUser = $existing;
                }
            }

            /* Email started but never verified: the customer never typed the code, or
               closed the dialog. Send a fresh code and let them carry on — the old
               behaviour returned EMAIL_NOT_VERIFIED with no new mail, which left the
               address unusable from the register screen. */
            if ($request->type === 'email') {
                $pending = User::where('email', $request->email)
                    ->where('type', $request->type)
                    ->where('is_verified', 0)
                    ->first();

                if ($pending) {
                    if ($pending->status == User::$deactive) {
                        return CommonHelper::responseError(__('this_customer_account_is_deactivated_kindly_contact_admin'), 'ACCOUNT_DEACTIVATED');
                    }

                    // The retry may carry a different name or password — keep the latest.
                    if ($request->filled('name')) {
                        $pending->name = $request->name;
                    }
                    if ($request->filled('password')) {
                        $pending->password = bcrypt($request->password);
                    }
                    if ($request->filled('country_id')) {
                        $pending->country_id = $request->country_id;
                    }
                    if ($request->filled('friends_code')) {
                        $pending->friends_code = $request->friends_code;
                    }

                    $verificationCode = rand(100000, 999999);
                    $pending->email_verification_code = $verificationCode;
                    $pending->is_verified = false;

                    try {
                        CommonHelper::sendMailByTemplate($pending->email, 'verify_email_customer', [
                            'customer_name' => $pending->name ?? '',
                            'code'          => $verificationCode,
                        ], $pending->language_id ? (int) $pending->language_id : null);
                        $pending->save();
                    } catch (\Exception $e) {
                        Log::error('Failed to send verification email: ' . $e->getMessage());
                        return CommonHelper::responseError('failed_to_send_verification_email', 'FAILED_TO_SEND_VERIFICATION_EMAIL');
                    }

                    if ($request->hasFile('profile')) {
                        $pending->profile = CommonHelper::uploadFile($request, 'profile', 'customers', $pending->profile);
                        $pending->save();
                    }

                    return CommonHelper::responseSuccess('verification_mail_sent_successfully', 'VERIFICATION_MAIL_SENT');
                }
            }

            if (in_array($request->type, ['google', 'apple', 'email'])) {
                $user = User::where('email', $request->email)->first();

                if ($user) {
                    return CommonHelper::responseError('user_exist_with_' . $user->type, 'USER_EXIST_WITH_' . strtoupper($user->type));
                }
            }

            // Also check if email is already used when registering via phone
            if ($request->type == 'phone' && $request->filled('email')) {
                $existingEmailUser = User::where('email', $request->email)->first();
                if ($existingEmailUser) {
                    return CommonHelper::responseError('user_exist_with_' . $existingEmailUser->type, 'USER_EXIST_WITH_' . strtoupper($existingEmailUser->type));
                }
            }

            if ($request->type == 'phone') {
                // Either the abandoned row from above, or none (a brand-new number).
                $user = $pendingUser;
            } elseif (in_array($request->type, ['google', 'apple', 'email'])) {
                $user = User::where('type', $request->type)
                    ->where('email', $request->email)
                    ->first();
            }

            $needsEmailVerificationReturn = false;
            if ($user) {
                if ($user->status == User::$deactive) {
                    return CommonHelper::responseError(__('this_customer_account_is_deactivated_kindly_contact_admin'), 'ACCOUNT_DEACTIVATED');
                }

                // Retried phone registration: refresh what they re-entered and treat the
                // number as verified (the OTP is checked before register is called).
                if ($request->type == 'phone' && $user === $pendingUser) {
                    if ($request->filled('name')) {
                        $user->name = $request->name;
                    }
                    if ($request->filled('email')) {
                        $user->email = $request->email;
                    }
                    if ($request->filled('password')) {
                        $user->password = bcrypt($request->password);
                    }
                    if ($request->filled('country_id')) {
                        $user->country_id = $request->country_id;
                    }
                    if ($request->filled('friends_code')) {
                        $user->friends_code = $request->friends_code;
                    }
                    $user->is_verified = true;
                    $user->save();
                }
            } else {
                // Create a new user
                $referral_code = strtoupper(substr(sha1(microtime()), 0, 6));

                $user = new User();
                $user->name = $request->input('name', '');
                $user->email = $request->input('email', '');
                $user->referral_code = $referral_code;
                $user->status = 1;
                $user->country_code = $registerCountryCode;
                $user->country_id = $request->input('country_id') ?: null;
                $user->mobile = $request->input('mobile', '');
                $user->password = $request->password ? bcrypt($request->password) : null;
                $user->type = $request->type;
                $user->friends_code = $request->friends_code ?? null;
                $user->language_id = CommonHelper::getDefaultLanguageId();
                // Phone (OTP) and social identities arrive already proven; only email
                // has to verify here, and the block below sets its code.
                $user->is_verified = $request->type !== 'email';

                // Save user first to get ID (needed for profile filename)
                $user->save();

                // Welcome the freshly-registered customer.
                CommonHelper::sendWelcomeNotification($user);

                // Email Verification Process - defer return so profile can be processed first
                if ($request->type == 'email') {
                    $verificationCode = rand(100000, 999999);
                    $user->email_verification_code = $verificationCode;
                    $user->is_verified = false;
                    $user->save();

                    try {
                        CommonHelper::sendMailByTemplate($user->email, 'verify_email_customer', [
                            'customer_name' => $user->name ?? '',
                            'code'          => $verificationCode,
                        ], $user->language_id ? (int) $user->language_id : null);
                        $needsEmailVerificationReturn = true;
                    } catch (\Exception $e) {
                        Log::error('Failed to send verification email: ' . $e->getMessage());
                        return CommonHelper::responseError('failed_to_send_verification_email', 'FAILED_TO_SEND_VERIFICATION_EMAIL');
                    }
                }
            }

            // Single profile upload block - runs for both new and existing users
            if ($request->hasFile('profile')) {
                $user->profile = CommonHelper::uploadFile($request, 'profile', 'customers', $user->profile);
                $user->save();
            }

            if ($needsEmailVerificationReturn) {
                return CommonHelper::responseSuccess('verification_mail_sent_successfully', 'VERIFICATION_MAIL_SENT');
            }

            // Authenticate user
            Auth::login($user);
            $accessToken = $user->createToken('authToken')->accessToken;
            $res = $this->formatUserResponse($user, $accessToken);

            // Save FCM token if provided
            if ($request->has('fcm_token') && filled($request->fcm_token)) {
                $language_id = $request->input('language_id') ?: CommonHelper::getDefaultLanguageId();
                UserToken::updateOrCreate(
                    ['fcm_token' => $request->fcm_token],
                    [
                        'user_id' => auth()->user()->id,
                        'platform' => $request->platform ?? 'android',
                        'type' => 'customer',
                        'language_id' => $language_id,
                    ]
                );
            }

            return CommonHelper::responseSuccessWithData('success', $res, 'SUCCESS');
        } catch (\Exception $e) {
            Log::error('Register : ' . $e->getMessage());
            return CommonHelper::responseError($e->getMessage(), 'REGISTER_FAILED');
        }
    }

    public function logout(Request $request)
    {
        if (isset($request->fcm_token)) {
            UserToken::where('type', 'customer')
                ->where('user_id', $request->user()->id)
                ->where('fcm_token', $request->fcm_token)
                ->delete();
        }

        $token = $request->user()->token();
        $token->revoke();

        return CommonHelper::responseSuccess(__('you_have_been_successfully_logged_out'));
    }

    public function notLogin()
    {
        return CommonHelper::responseError(__('unauthorized'));
    }

    public function deleteAccount(Request $request)
    {
        try {
            $user_id = auth()->user()->id;
            $user = User::where('id', $user_id)->first();

            if ($user->mobile == '9876543210') {
                return CommonHelper::responseError("This function is not available in demo mode!");
            }
            if ($user->balance > 0) {
                return CommonHelper::responseError("cannot_delete_account_with_balance");
            }
            NotificationPreference::where('user_type', 0)->where('user_id', $user_id)->delete();
            UserToken::where('user_id', $user_id)->delete();

            $user->delete();
            return CommonHelper::responseSuccess("your_account_deleted_successfully");
        } catch (\Exception $e) {
            Log::error('Login : ' . $e->getMessage());
            return CommonHelper::responseError($e->getMessage());
        }
    }

    public function editProfile(Request $request)
    {
        $user = auth()->user();
        $profileCountryCode = $this->normalizeCountryCode($request->input('country_code', $user->country_code));
        $validator = Validator::make($request->all(), [
            'name'   => 'required',
            'email'  => 'required|unique:users,email,' . $user->id . ',id,deleted_at,NULL',
            'country_id' => 'nullable|integer|exists:countries,id',
            'country_code' => 'required_with:mobile|nullable|string',
            'mobile' => [
                'nullable',
                Rule::unique('users', 'mobile')
                    ->ignore($user->id)
                    ->where(function ($query) use ($profileCountryCode) {
                        $query->where('country_code', $profileCountryCode);
                    })
                    ->whereNull('deleted_at'),
            ],
        ], [
            'email.unique'  => 'email_has_already_taken',
            'mobile.unique' => 'mobile_number_has_already_taken',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }
 
        if ($user->mobile == '9876543210') {
            return CommonHelper::responseError("This function is not available in demo mode!");
        }
        
        $user->name = $request->name;
        $user->email = $request->email;

        if ($request->filled('country_id')) {
            $user->country_id = (int) $request->country_id;
        }

        if (isset($request->mobile) && $user->type != 'phone') {
            $user->mobile = $request->mobile;
            $user->country_code = $profileCountryCode;
        }

        if ($request->hasFile('profile')) {
            $user->profile = CommonHelper::uploadFile($request, 'profile', 'customers', $user->profile);
        }

        if ($user->status == 2) {
            if (isset($request->referral_code)) {
                $validCode = User::where('status', 1)
                    ->where('referral_code', $request->referral_code)->first();
                if ($validCode) {
                    $user->friends_code = $request->referral_code;
                }
            }
            $user->status = 1;
        }

        $user->save();

        // Balance for the current-location country (when lat/long provided).
        $countryId = null;
        if ($request->filled('latitude') && $request->filled('longitude')) {
            $channel = strtolower(trim((string) $request->header('channel')));
            $channel = in_array($channel, ['quick', 'ecommerce'], true) ? $channel : null;
            $countryId = optional(CommonHelper::resolveCountry($request->latitude, $request->longitude, $channel))->id;
        }

        return CommonHelper::responseSuccessWithData('profile_updated_successfully', $this->formatUserResponse($user, null, $countryId), 'SUCCESS');
    }

    public function ResetPassword(Request $request)
    {
        if (!$request->filled('new_password_confirmation') && $request->filled('password_confirmation')) {
            $request->merge(['new_password_confirmation' => $request->input('password_confirmation')]);
        }

        $validator = Validator::make($request->all(), [
            'old_password' => 'required',
            'new_password' => 'required|confirmed',
        ], [
            'new_password.confirmed' => __('The new password confirmation does not match.')
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if (($pwErr = CommonHelper::validatePasswordPolicy($request->new_password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }

        $user = auth()->user();

        // Verify that the old password matches the current password in the database
        if (!Hash::check($request->old_password, $user->password)) {
            return CommonHelper::responseError(__('The old password is incorrect.'));
        }

        // Update password to new password
        $user->password = bcrypt($request->new_password);
        $user->save();

        // Security alert: tell the customer their password was just changed.
        CommonHelper::sendPasswordChangedNotification($user);

        return CommonHelper::responseSuccess(__('password_updated_successfully'));
    }

    public function addFcmToken(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'fcm_token' => 'required|string',
            'platform' => 'required|string|in:android,ios,web', // Adjust platform types as per your app
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user = $request->user('api-customers');
        $user_id = $user ? $user->id : 0;

        $language_id = $request->input('language_id') ?: CommonHelper::getDefaultLanguageId();

        // Track the customer's preferred language on their account (drives language-wise SMS).
        if ($user_id && $request->has('language_id')) {
            User::where('id', $user_id)->update(['language_id' => $language_id]);
        }

        $token = UserToken::where('fcm_token', $request->fcm_token)->first();

        if ($token) {
            if ($token->user_id == 0 && $user_id != 0) {
                $token->user_id = $user_id;
                $token->platform = $request->platform;
                $token->language_id = $language_id;
                $token->save();
                return CommonHelper::responseSuccess(__('token_updated_successfully'));
            }
            if ($request->has('language_id')) {
                $token->language_id = $language_id;
                $token->save();
            }
            return CommonHelper::responseSuccess(__('token_already_exists'));
        }

        UserToken::create([
            'user_id' => $user_id,
            'type' => 'customer',
            'fcm_token' => $request->fcm_token,
            'platform' => $request->platform,
            'language_id' => $language_id,
        ]);

        return CommonHelper::responseSuccess(__('token_added_successfully'));
    }

    public function updateFcmToken(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'fcm_token' => 'required',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user_id = $request->user('api-customers') ? $request->user('api-customers')->id : 0;

        $token = UserToken::where('fcm_token', $request->fcm_token)->first();
        $language_id = $request->input('language_id') ?: CommonHelper::getDefaultLanguageId();

        // Track the customer's preferred language on their account (drives language-wise SMS).
        if ($user_id && $request->has('language_id')) {
            User::where('id', $user_id)->update(['language_id' => $language_id]);
        }

        // Assign guest token to user when they log in (user_id must be set)
        if ($token && ($token->user_id == 0 || $token->user_id == '') && $user_id) {
            $token->user_id = $user_id;
            $token->platform = $request->platform ?? 'android';
            $token->language_id = $language_id;
            $token->save();
            return CommonHelper::responseSuccess(__('token_updated_successfully'));
        }
        if ($token && $request->has('language_id')) {
            $token->language_id = $language_id;
            $token->save();
        }

        // Match by user_id + fcm_token - if same token exists, update it
        UserToken::updateOrCreate(
            ['user_id' => $user_id, 'fcm_token' => $request->fcm_token],
            ['type' => 'customer', 'platform' => $request->platform ?? 'android', 'language_id' => $language_id]
        );
        return CommonHelper::responseSuccess(__('token_added_successfully'));
    }

    public function getLoginUserDetails(Request $request)
    {
        $user_id = $request->user('api-customers') ? $request->user('api-customers')->id : '';
        $user = User::where('id', $user_id)->first();
        if (!empty($user)) {
            // Balance for the current-location country (when lat/long provided).
            $countryId = null;
            if ($request->filled('latitude') && $request->filled('longitude')) {
                $channel = strtolower(trim((string) $request->header('channel')));
                $channel = in_array($channel, ['quick', 'ecommerce'], true) ? $channel : null;
                $countryId = optional(CommonHelper::resolveCountry($request->latitude, $request->longitude, $channel))->id;
            }
            return CommonHelper::responseSuccessWithData('success', $this->formatUserResponse($user, null, $countryId), 'SUCCESS');
        } else {
            return CommonHelper::responseError(__('unauthorized'));
        }
    }

    public function verifyEmail(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
            'code' => 'required|numeric',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user = User::where('email', $request->email)->first();

        if (!$user || $user->email_verification_code != $request->code) {
            return CommonHelper::responseError(__('Invalid verification code'));
        }

        // Mark the user as verified
        $user->is_verified = true;
        $user->email_verification_code = null; // Clear the verification code
        $user->save();

        $accessToken = $user->createToken('authToken')->accessToken;

        $res = $this->formatUserResponse($user, $accessToken);
        return CommonHelper::responseSuccessWithData('success', $res, 'SUCCESS');
    }
    
    public function forgetPasswordOtp(Request $request)
    {
        $requestData = $request->all();
        $validator = Validator::make($requestData, [
            'email' => 'required|email',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $user = User::where('type', 'email')
            ->where('email', $request->email)
            ->where('is_verified', 1)
            ->first();

        if ($user) {
            $verificationCode = random_int(100000, 999999);

            $user->email_verification_code = $verificationCode;

            // Send forgot password code to email
            try {
                CommonHelper::sendMailByTemplate($user->email, 'verify_email_customer', [
                    'customer_name' => $user->name ?? '',
                    'code'          => $verificationCode,
                ], $user->language_id ? (int) $user->language_id : null);
                // Email sent successfully, you can log this or proceed as needed
                Log::info('Verification email sent to ' . $user->email);
                // Save the user record
                $user->save();
                return CommonHelper::responseSuccess('verification_mail_sent_successfully');
            } catch (\Exception $e) {
                // Handle any errors that occur during sending
                Log::error('Failed to send verification email: ' . $e->getMessage());
                return CommonHelper::responseError('Failed to send verification email.');
            }
        } else {
            return CommonHelper::responseError('email_is_not_registered');
        }
    }

    public function forgotPassword(Request $request)
    {
        $requestData = $request->all();

        // Validation rules
        $validator = Validator::make($requestData, [
            'type'    => 'required|in:phone,google,apple,email',
            'email'   => 'required_if:type,email|email',
            'mobile'  => 'required_if:type,phone|numeric',
            'country_code' => 'nullable|string',
            'otp_verify_method' => 'required_if:type,phone|in:twilio,firebase',
            'otp'               => 'required_if:otp_verify_method,twilio|integer',
            'password' => 'required|string|confirmed',
            'password_confirmation' => 'required'
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        if ($request->type === 'email') {
            // Check OTP in users table for email
            $user = User::where('email', $request->email)
                ->where('email_verification_code', $request->otp)
                ->first();

            if (!$user) {
                return CommonHelper::responseError('Invalid or expired OTP');
            }
        } elseif ($request->type === 'phone') {
            $forgotCc = $this->normalizeCountryCode($request->input('country_code'));
            $otpPhoneKey = $forgotCc . $request->mobile;

            if ($request->otp_verify_method === 'twilio') {
                // Check OTP in sms_verifications table for phone
                $smsVerification = DB::table('sms_verifications')
                    ->where('otp', $request->otp)
                    ->where(function ($q) use ($otpPhoneKey, $request) {
                        $q->where('phone', $otpPhoneKey)->orWhere('phone', (string) $request->mobile);
                    })
                    ->first();

                if (!$smsVerification) {
                    return CommonHelper::responseError('Invalid or expired OTP');
                }
            }

            // If otp_verify_method is 'firebase', skip OTP check
            // Find the user based on mobile after OTP verification (or directly for Firebase)
            $user = User::where('mobile', $request->mobile)
                ->where('country_code', $forgotCc)
                ->first();

            if (!$user) {
                return CommonHelper::responseError('User not found');
            }
        }

        if (!$user) {
            return CommonHelper::responseError('Invalid request');
        }

        if (($pwErr = CommonHelper::validatePasswordPolicy($request->password)) !== null) {
            return CommonHelper::responseError($pwErr);
        }

        // Reset password
        $user->password = Hash::make($request->password);
        $user->email_verification_code = null; // Clear OTP for email
        $user->save();

        return CommonHelper::responseSuccess(__('password_updated_successfully'));
    }

    public function verifyUserExist(Request $request) //Used while forgot fassword
    {
        $validator = Validator::make($request->all(), [
            'mobile' => 'required|string',
            'country_code' => 'required|string',
            'type'    => 'required|in:phone,google,apple,email',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $existCc = $this->normalizeCountryCode($request->country_code);
        $user = User::where('mobile', $request->mobile)
            ->where('country_code', $existCc)
            ->where('type', $request->type)
            ->first();

        if (!$user) {
            return response()->json(['status' => 1, 'message' => 'user_not_exist']);
        }

        return response()->json(['status' => 1, 'message' => 'user_already_exist']);
    }

    public function sendSms(Request $request)
    {
        try {
            $otp = random_int(100000, 999999);
            $request->validate([
                'mobile' => 'required|string',
            ]);
            $mobile = $request->input('mobile');
            $languageId = $request->input('language_id') ?: null;
            $success = SmsHelper::sendByTemplate($mobile, 'otp_customer', ['otp' => $otp], $languageId);
            if ($success == true) {
                $expiresAt = Carbon::now()->addMinutes(10);
                SmsVerification::insert([
                    'phone' => $mobile,
                    'otp' => $otp,
                    'status' => 'pending',
                    'expires_at' => $expiresAt,
                    'created_at' => Carbon::now(),
                    'updated_at' => Carbon::now(),
                ]);
                return CommonHelper::responseSuccess('otp_sent_successfully', 'OTP_SENT');
            }

            return CommonHelper::responseError('otp_could_not_be_sent', 'OTP_NOT_SENT');
        } catch (\Exception $e) {
            return CommonHelper::responseError($e->getMessage(), 'OTP_NOT_SENT');
        }
    }

    public function verifyContact(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'mobile' => 'required|numeric',
            'otp' => 'required|string',
            'country_code' => 'required|string',
        ]);

        if ($validator->fails()) {
            $firstKey = $validator->errors()->first();
            return CommonHelper::responseError($firstKey, strtoupper($firstKey));
        }

        $phone = $request->input('country_code') . $request->input('mobile');
        $otp = $request->input('otp');

        $otpRecord = SmsVerification::where('phone', $phone)
            ->latest('created_at')
            ->first();

        if ($otpRecord && $otpRecord->otp == $otp && $otpRecord->status == 'pending' && $otpRecord->expires_at > Carbon::now()) {
            $otpRecord->status = 'verified';
            $otpRecord->save();

            $normalizedCc = $this->normalizeCountryCode($request->input('country_code'));
            $user = User::where('mobile', $request->input('mobile'))->where('country_code', $normalizedCc)->first();
            if ($user) {
                $accessToken = $user->createToken('authToken')->accessToken;
                $res = ['user' => $user, 'access_token' => $accessToken];
                return CommonHelper::responseSuccessWithData('otp_verified_successfully', $res, 'OTP_VERIFIED');
            } else {
                return CommonHelper::responseError('otp_valid_but_user_not_found', 'USER_NOT_EXIST');
            }
        } else {
            return CommonHelper::responseError('otp_invalid_or_expired', 'OTP_INVALID_OR_EXPIRED');
        }
    }
}