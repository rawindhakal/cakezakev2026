# Testing Plan — CakeZake Customer App

Feature-by-feature test case checklist. Built 1 by
1, product-ready pass — each feature covered on **3 layers: unit, widget,
integration** — before the next feature starts.

## Setup (done)

`pubspec.yaml` `dev_dependencies` (added, marked with a comment pointing here):
```yaml
bloc_test: ^10.0.0   # ^9.x pins bloc ^8, incompatible with flutter_bloc ^9.1.1
mocktail: ^1.0.4
integration_test:
  sdk: flutter
```

`lib/core/api/api_client.dart` gained a test-only seam
(`@visibleForTesting set httpClientAdapter`), so
integration/widget tests can swap in a `FakeApiAdapter` instead of hitting the
network. Nothing else in `ApiClient` changed.

Dirs:
- `test/features/<feature>/...` — unit (models, repository, cubit) + widget
  tests. Mirrors `lib/features/<feature>/...`.
- `test/fixtures/<feature>/` — real API response payloads as JSON. Refresh
  these when the backend contract changes instead of editing assertions
  inline.
- `test/helpers/` — shared test infra:
  - `pump_test_widget.dart` — wraps the widget under test in
    `AppTheme.lightTheme(AppColors.primary)` + `MaterialApp` (+ `Scaffold`
    unless `wrapInScaffold: false`). Note:
    `AppTheme.lightTheme` here takes a `Color primary` argument (the app's
    primary color is server-configurable via `SettingsCubit`) — tests pass
    `AppColors.primary`, the same placeholder value the real app falls back
    to before settings load.
  - `mock_cubits.dart` — `MockCubit` classes per cubit, added as each
    feature's tests are written (not pre-populated).
  - `mock_api_client.dart` — mocktail mock for `ApiClient` + fallback-value
    registration for `FormData`/`Options`.
  - `fake_api_adapter.dart` — canned-response Dio adapter for widgets/screens
    that build their own cubit internally. Same class duplicated under
    `integration_test/helpers/` — keep the two in sync.
  - `hive_test_helper.dart` — opens a plain temp-dir Hive box for code paths
    that read `AuthHiveBox` / `SettingsHiveBox` / `GuestCartHiveBox`.
  - `test_logging.dart` — `printTestDivider(String label)` helper.
- `integration_test/` — full end-to-end flows: real router, real screens,
  real cubits and repositories, driven on a device/simulator (`flutter test
  integration_test/<feature>_flow_test.dart -d <device>`). The network is
  faked at the Dio adapter level via `FakeApiAdapter` +
  `ApiClient().httpClientAdapter` (a `@visibleForTesting` seam on
  `ApiClient`), and Hive runs against a temp dir. An `auth_test_app.dart`-style
  harness (real router/screens wired to a `FakeApiAdapter`, `RouteNames.main`
  swapped for a placeholder) will be added once the first feature's
  integration tests are written — its provider list depends on which cubits
  that feature actually needs (this app's cubits include cart/checkout/
  promo_code/payment_method/blog/faq/onboarding/favourite/location, among
  others).

Run everything headless (unit + widget) with `flutter test`. The default
template `test/widget_test.dart` (counter smoke test) was removed — it never
matched this app and always failed.

`test/commons/cubit/base_pagination_cubit_test.dart` covers `BasePaginationCubit`/
`FilteredPaginationCubit` mechanics once, added alongside faq (the first
feature built) since every `*PaginationCubit` feature after it extends the
same base. This app's base cubit differs from delivery-boy's: no `meta`
payload, no stale-response guard on `fetchInitial`, but it does add
`updateItem`/`removeItem` list-mutation helpers — the test file documents
and covers exactly that surface, not delivery-boy's.

## Progress

| # | Feature | Unit | Widget | Integration |
|---|---------|------|--------|--------------|
| 1 | auth | ✅ | ✅ | 🟡 |
| 2 | onboarding | 🔲 | 🔲 | 🔲 |
| 3 | splash / main | 🔲 | 🔲 | 🔲 |
| 4 | home | 🔲 | 🔲 | 🔲 |
| 5 | category | 🔲 | 🔲 | 🔲 |
| 6 | products | 🔲 | 🔲 | 🔲 |
| 7 | favourite | 🔲 | 🔲 | 🔲 |
| 8 | cart | 🔲 | 🔲 | 🔲 |
| 9 | promo_code | 🔲 | 🔲 | 🔲 |
| 10 | address | 🔲 | 🔲 | 🔲 |
| 11 | location | 🔲 | 🔲 | 🔲 |
| 12 | checkout | 🔲 | 🔲 | 🔲 |
| 13 | payment_method | 🔲 | 🔲 | 🔲 |
| 14 | orders | 🔲 | 🔲 | 🔲 |
| 15 | wallet | 🔲 | 🔲 | 🔲 |
| 16 | notifications | 🔲 | 🔲 | 🔲 |
| 17 | chat | 🔲 | 🔲 | 🔲 |
| 18 | profile | 🟡 | 🔲 | 🔲 |
| 19 | blog | ✅ | ✅ | ✅ |
| 20 | faq | ✅ | ✅ | ✅ |

Mark 🔲 → 🟡 (in progress) → ✅ (done, tests green) per column as we go.

Feature order above is a suggestion (roughly the shopping funnel: browse →
cart → checkout → post-purchase), not a hard requirement — reorder freely
once work starts, based on priority (e.g. highest-traffic paths first, then
fill in the rest).

---

## 1. auth — unit ✅, widget ✅, integration 🟡

By far the biggest surface of any feature built so far, and the first one
with real Firebase dependencies: one model (`AuthModel`/`AuthModelData`), one
`AuthRepository` mixing plain API calls with Firebase Auth/Messaging calls,
**eleven** cubits (`AuthCubit`, `SignInCubit`, `SignUpCubit`, `VerifyOtpCubit`,
`ForgotPasswordCubit`, `ChangePasswordCubit`, `LogoutCubit`,
`DeleteAccountCubit`, `AddFcmTokenCubit`, `UpdateFcmTokenCubit`,
`CustomSmsSendPhoneOtpCubit`, `CustomSmsVerifyPhoneOtpCubit` —
`CustomSmsSendPhoneOtpCubit`/`CustomSmsVerifyPhoneOtpCubit` counted once each,
twelve total), five screens (sign in, sign up, forgot password, OTP
verification, register OTP), and eleven reusable widgets. Picked as feature
#1 per the progress table despite the size, since every other feature's
integration harness needs a logged-in (or deliberately logged-out) session
this one establishes the pattern for.

`flutter test test/features/auth`: **149 unit + widget tests green** (96
unit across `auth_model_test.dart`/`auth_repository_test.dart`/12 cubit test
files, 53 widget across 11 small-widget files + all 5 screen test files —
`sign_in_screen_test.dart` (4), `sign_up_screen_test.dart` (4),
`forgot_password_screen_test.dart` (6), `otp_verification_screen_test.dart`
(5), `register_otp_screen_test.dart` (5)). Full suite (`flutter test`) stays
green at 400 (pre-existing, unrelated failures in
`test/features/profile/widgets/profile_dialogs_test.dart` from a different
feature's in-progress pass are not touched by this one). Integration:
`integration_test/auth_flow_test.dart` written (3 cases) but **not run on a
real device this pass** — see the integration gotchas below for why.

### A. Unit
- **`auth_model_test.dart`** — `AuthModel.fromJson`: envelope `status` is a
  bare `int` here (`parseInt(...) ?? 0`), *not* a stringified value like
  every faq/blog envelope field — asserted explicitly since it's an easy
  copy-paste mismatch from the pagination features' pattern; `message`/
  `statusCode` default to `''`; `data` parses via `AuthModelData.fromJson`
  only when the raw `data` value is actually a `Map` — missing, `null`, *or*
  a non-Map value (e.g. a stray string) all leave `data` `null`, never a
  default object. `AuthModelData.fromJson`: every string field defaults to
  `''`, `id` defaults to `0`, but `countryId` stays `null` (bare `parseInt`,
  no `?? 0`) and `balance` defaults to `0.0` (via `parseDouble`'s own
  built-in default) — the three defaults genuinely differ per field, worth
  asserting each rather than assuming one covers all. `toJson` round trip;
  `AuthModel.toJson` omits the `data` key entirely when `data` is `null`
  (same pattern as blog's `category`).
- **`auth_repository_test.dart`** (mock `ApiClient` + mock `FirebaseAuth`) —
  covers only the methods that don't call `getFcmToken()` internally (see
  gotcha below): `verifyUserExist`, `sendEmailForgotPasswordOtp`,
  `sendCustomSmsForgotPasswordOtp`, `verifyCustomSmsOtpForForgotPassword`,
  `forgotPassword`, `changePassword`, `getProfile` (needs `settingsBox`
  open, sends the cached lat/lng), `addFcmToken`, `updateFcmToken`, `logout`
  (needs `authBox` open, sends the cached fcm token), `deleteAccount`,
  `updateProfile` (multipart upload), `customSmsSendPhoneOtp`,
  `customSmsVerifyPhoneOtp` — 13 methods total, each asserting the right
  endpoint/params and the `ApiException` rethrow-vs-wrap split.
- **Cubit tests** (12 files, one per cubit) — every cubit using
  `ApiErrorGuard` (`AddFcmTokenCubit`, `ChangePasswordCubit`,
  `CustomSmsSendPhoneOtpCubit`, `CustomSmsVerifyPhoneOtpCubit`,
  `DeleteAccountCubit`, `ForgotPasswordCubit`, `LogoutCubit`,
  `UpdateFcmTokenCubit`, `VerifyOtpCubit`) is fully covered — success,
  `ApiException`, and generic-error branches, plus session persistence via
  `AuthHiveBox` where the cubit calls `saveLoginData`/`clearAuth`
  (`authBox` opened per test via `HiveTestHelper`). `AuthCubit.checkAuth`
  covers the "logged in but empty token still counts as unauthenticated"
  edge (`isAuthenticated` requires both the flag *and* a non-empty token,
  not just the flag). `SignInCubit`/`SignUpCubit` are **partially** covered
  — see the gotcha below for exactly which branches and why.

### B. Widget
- The 11 small/reusable widgets each got their own file: `auth_otp_fields`
  (Pinput length/onChanged/onCompleted), `auth_resend_section` (countdown vs.
  tappable resend link at `Duration.zero`), `auth_screen_header` (title +
  subtitle), `auth_social_buttons` (Google button visible/tappable/
  disabled-while-loading; Apple button — see gotcha below), `auth_terms_bar`
  (terms/privacy links render, each its own `AppText`), `sign_in_mode_toggle`
  (both options render, tapping either calls `onChanged`, including
  re-tapping the already-active one), `sign_in_email_form`/
  `sign_in_phone_form` (field visibility toggles, forgot-password callback),
  `sign_up_form` (name always present; email/phone/password each
  independently toggle on their own `show*` flag; name field read-only in
  google/apple mode), `forgot_password_input_section` (email vs. phone field
  swap, send-OTP button disabled while loading),
  `forgot_password_password_section` (requirements checklist mounts only
  once the password field has text; submit button disabled while loading).
- **`sign_in_screen_test.dart`** (4 cases) — loading state while
  `SettingsCubit` hasn't resolved yet; the welcome header + email form render
  once settings load (email-only config, to sidestep the phone-default
  gotcha below); submitting valid email/password calls
  `SignInCubit.loginWithEmailPassword` with the right `id`/`password`/`type`;
  a `SignInError` state surfaces its message via a snackbar (driven with
  `whenListen`, not `bloc_test`, since this is a widget test around a mocked
  cubit rather than a cubit test).
- **`sign_up_screen_test.dart`** (4 cases) — renders the sign-up form +
  "Create Account" CTA for email mode (name/email/phone/password fields all
  present — phone is required in *every* mode here, see gotcha below); phone
  mode with firebase OTP enabled shows a "Send OTP" CTA instead and
  submitting a valid phone number calls
  `SignUpCubit.sendPhoneOtpForSignUp(phoneNumber, countryCode)`; a
  `SignUpError` state surfaces its message via a snackbar; submitting valid
  email/password (with a phone number still filled in) calls
  `SignUpCubit.signUpWithEmail` with the right `name`/`email`/`password`.
  Needs `MockSettingsCubit`/`MockSignUpCubit`/
  `MockCustomSmsSendPhoneOtpCubit`/`MockCountriesCubit` — the same cluster
  `sign_in_screen_test.dart` wires, minus `SignInCubit` plus `SignUpCubit`.
- **`otp_verification_screen_test.dart`** (5 cases) — renders the
  code-sent-to text (phone + country code) and the OTP/resend widgets;
  tapping verify with an incomplete OTP shows a validation snackbar and
  never reaches either cubit; firebase `authType` (the default) calls
  `SignInCubit.verifyPhoneOtp` with the right `phoneNumber`/`type`/
  `phoneAuthType`/`countryCode`; custom `authType` calls
  `CustomSmsVerifyPhoneOtpCubit.customSmsVerifyPhoneOtp` instead — the
  screen's one real fork, covered both ways; a `SignInError` state surfaces
  its message via a snackbar. Needs `MockSettingsCubit` (read directly via
  `context.read` inside `_isFirebaseOtp`, not a `BlocBuilder`) plus
  `MockSignInCubit`/`MockCustomSmsSendPhoneOtpCubit`/
  `MockCustomSmsVerifyPhoneOtpCubit` — all four regardless of `authType`.
- **`register_otp_screen_test.dart`** (5 cases) — email `authType` renders
  the target email + OTP field, and a full OTP calls
  `VerifyOtpCubit.verifyEmail(email, otp)`; firebase `authType` calls
  `VerifyOtpCubit.verifyPhoneOtpAndSignUp` with `verificationId`/`smsCode`/
  `name`/`mobile` (plus the rest passed through); custom `authType` calls
  `CustomSmsVerifyPhoneOtpCubit.customSmsVerifyPhoneOtp` — all three of
  `_onVerify`'s branches, since branching on `authType` is this screen's
  entire reason to exist; a `VerifyOtpError` state surfaces its message via
  a snackbar. Needs `MockVerifyOtpCubit`/`MockSignUpCubit`/
  `MockCustomSmsSendPhoneOtpCubit`/`MockCustomSmsVerifyPhoneOtpCubit` — all
  four regardless of `authType` (`MultiBlocListener` + nested `BlocBuilder`s
  for the verify button's loading state read every one of them).
- **`forgot_password_screen_test.dart`** (6 cases) — phone `type` shows the
  phone field + phone-specific subtitle (email field absent); email `type`
  shows the email field + email-specific subtitle (phone field absent);
  submitting a valid phone number calls
  `ForgotPasswordCubit.verifyPhoneAndSendOtp(mobile, countryCode, isFirebase)`;
  submitting a valid email calls `ForgotPasswordCubit.sendEmailOtp(email)`; a
  `ForgotPasswordOtpSent` state moves phase 0 to the OTP phase (Pinput +
  code-sent subtitle appear); a `ForgotPasswordError` state surfaces its
  message via a snackbar. Needed a small, additive production change to
  make this screen testable at all — see the gotcha below.

All four previously-uncovered screens (`sign_up_screen.dart`,
`forgot_password_screen.dart`, `otp_verification_screen.dart`,
`register_otp_screen.dart`) now have widget tests, so the widget layer is
marked ✅. `test/helpers/mock_cubits.dart` gained `MockSignUpCubit`,
`MockForgotPasswordCubit`, `MockVerifyOtpCubit`, and
`MockCustomSmsVerifyPhoneOtpCubit` alongside the ones `sign_in_screen_test.dart`
already added.

### C. Integration (`integration_test/auth_flow_test.dart`, written, not run)
Mounted via `integration_test/helpers/auth_test_app.dart` at `RouteNames.login`
— same `onGenerateInitialRoutes`-skips-splash trick as faq/blog, but with
real **global** provider wiring on top of what `AppRouter.generateRoute`'s
`/login` case already supplies (`SignInCubit`/`CustomSmsSendPhoneOtpCubit`):
`SettingsCubit`/`CountriesCubit` are provided app-wide in `main.dart`, not
per-route, so `SignInScreen` (which reads both directly) needs them from the
harness itself — the "broader provider wiring" the setup section anticipated
for this feature's harness. Covers: the sign-in screen loads once settings/
countries resolve; a successful login persists the token via `AuthHiveBox`
and lands on `RouteNames.locationRequired` (not `RouteNames.main` — see
gotcha below); invalid credentials surface the api message via snackbar and
never navigate. `integration_test/helpers/auth_fixtures.dart` documents the
same numeric-`status: 1` envelope gotcha faq's fixtures found, plus that
`AuthModel.status` is independently a bare `int` on top of that.

**Not run on a real device this pass.** `flutter devices` in this
environment surfaced no simulator and only unreliable real hardware (a
wirelessly-tethered Android device with an `adb` connection error, and an
iOS device not yet paired for wireless debugging) — no iOS simulator was
booted the way faq/blog's suites had one (`iPhone 17 Pro Max`) available.
The suite is written and passed `flutter analyze`, but is unverified against
a live binding. Next pass (or whoever has a booted simulator handy) should
run `flutter test integration_test/auth_flow_test.dart -d <device>` before
flipping this column to ✅.

### Bugs / gotchas found while building this
- **`AuthRepository.getFcmToken()` — called at the top of nearly every login/
  signup method — hits real `FirebaseMessaging.instance`, which throws
  synchronously under `flutter test`'s unit/widget runners** (no platform
  channel registered, no `Firebase.initializeApp()` call anywhere in the test
  binary). Affected repository methods (`loginWithPhoneOtp`,
  `loginWithPhonePassword`, `loginWithGoogle`, `loginWithApple`, `verifyEmail`,
  `verifyPhoneOtp`, `signUp`) are excluded from `auth_repository_test.dart`
  entirely — only the 13 methods that never call it are tested there. At the
  **cubit** layer this doesn't matter, since cubit tests mock `AuthRepository`
  wholesale (mocktail never runs the real Firebase-touching code), so
  `SignInCubit`/`SignUpCubit`/`VerifyOtpCubit`'s success/failure paths *are*
  fully exercised there instead — this is a repository-layer testing gap, not
  a cubit-layer one.
- **`SignInCubit`'s successful-login path (`SignInLoaded`) and every method's
  generic (non-`ApiException`) `catch` block are still untestable even at the
  cubit layer**, because they call `AnalyticsService.instance`/
  `CrashlyticsService.instance` directly (not through `ApiErrorGuard`, which
  never touches either) — both are singletons whose first access
  synchronously evaluates `FirebaseAnalytics.instance`/
  `FirebaseCrashlytics.instance`, which throw without a real Firebase app.
  `sign_in_cubit_test.dart`/`sign_up_cubit_test.dart` cover every
  `ApiException`-driven branch (`SignInError`, `SignInUserNotFound`,
  `SignInCancelled`) since those run *before* either singleton is touched,
  plus `sendPhoneOtp`/`signUpWithEmail`/`sendPhoneOtpForSignUp` in full (none
  of the three ever call Analytics/Crashlytics on any branch) — documented
  inline at the top of both test files rather than silently skipped. Every
  cubit using `ApiErrorGuard` instead (the other 9) has no such gap, since
  `ApiErrorGuard.guard` never references either service.
- **`AppText`'s `isRequired: true` renders a standalone `RichText` with a
  trailing `" *"`, not a `Text`** — `find.text(LanguageLabelKeys.email)`
  finds nothing on any required field label, both because `find.text`
  ignores standalone `RichText` by default (`findRichText: false`) *and*
  because the rendered string is `"email *"`, not `"email"`, even with
  `findRichText: true` turned on — a widget test has to match the full
  `"$key *"` string. `sign_in_email_form_test.dart`, `sign_in_phone_form_test.dart`,
  and `sign_up_form_test.dart` all hit this on the fields that happen to be
  marked required (email/password in the sign-in forms, name/email/phone in
  sign-up); `forgot_password_input_section.dart`'s labels aren't marked
  required and needed no such workaround, worth checking the widget's own
  `isRequired` value rather than assuming plain `Text` in every field label.
- **`ForgotPasswordPasswordSection`'s and `SignUpForm`'s password fields read
  `SettingsHiveBox` during their very first build**, not only once text is
  typed — `AppTextField`'s `validator: (v) => v.validateNewPassword(context)`
  (and `validatePassword`) call `PasswordPolicy.fromSettings()`
  unconditionally as part of `FormFieldState`'s initial validation pass, so
  even a widget test that never types anything needs `settingsBox` open via
  `HiveTestHelper`, or it throws a `HiveError` *during the first `pump`* —
  the same class of gotcha blog's date-formatting widgets found, but
  triggered by a validator instead of a display formatter.
- **The Apple sign-in button never renders under `flutter test`, on any
  platform, even when `isAppleEnabled` is true** — `AuthSocialButtons` gates
  it on `Platform.isIOS`, which reflects the *host test VM's* OS
  (`flutter test` always runs as a Dart VM process, never as an actual iOS
  app), not the app's real deployment target — this only becomes visible on
  a real iOS integration/device run, not in any widget test, on any
  developer machine, macOS included. `auth_social_buttons_test.dart` asserts
  this absence explicitly rather than silently only testing Google.
- **`SignInScreen._initModeIfNeeded` defaults `_mode` to phone whenever phone
  login is enabled at all**, regardless of whether email login is *also*
  enabled (`_mode = _isPhoneLogin ? SignInMode.phone : SignInMode.email` —
  phone wins the tie) — a rendering/interaction test written against
  "email and phone both on" settings silently lands on the phone form
  instead and every email-field finder comes up empty. Fixed by testing the
  email flow against email-only settings (`phoneLogin: '0'`) in
  `sign_in_screen_test.dart`, leaving the tab-switch interaction itself as a
  gap for whoever covers `sign_up_screen`/the other three screens next.
- **A successful login does not land on `RouteNames.main`** —
  `GuestCartSyncHelper.syncAndNavigate` (called from `SignInCubit`'s
  `SignInLoaded` listener) routes to `RouteNames.locationRequired` instead
  whenever `SettingsHiveBox.hasLocation` is false, which it always is for a
  fresh temp-dir Hive box with no saved location — worth knowing before
  writing an integration assertion that expects `MainScreen` to appear
  post-login without first saving a location into the fixture/hive setup.
  `LocationRequiredScreen` conveniently builds its own
  `BlocProvider<UserLocationCubit>`, so `auth_test_app.dart` needs no extra
  provider to land there, unlike the sprawling provider list a `MainScreen`
  assertion would have required.
- **`AppButton`'s label is a plain, non-required `AppText` (a `Text`, not a
  `RichText`), but so is a screen's `AppBar` title built the same way**
  (`CustomAppBar(title: context.translate(LanguageLabelKeys.verifyOtp))` on
  both `OtpVerificationScreen` and `RegisterOtpScreen`) — `find.text(...)`
  on the CTA's own label (e.g. `LanguageLabelKeys.verifyOtp`) matches *two*
  widgets, one of them off in the app bar, and `.tap()`/`.tap(...).last)` on
  the ambiguous finder either throws ("found 2 widgets, expected 1") or
  silently taps the wrong one depending on tree order — several of this
  pass's first attempts at tapping "Verify OTP" produced zero calls to the
  underlying cubit method with no other error, since the tap landed on the
  (inert) app bar title instead of the button. Fixed in
  `otp_verification_screen_test.dart`/`register_otp_screen_test.dart` by
  tapping `find.byType(AppButton)` directly (there's exactly one on each of
  these screens) instead of matching by label text — worth doing by default
  whenever a screen's app bar title happens to share text with its primary
  CTA, rather than assuming `.first`/`.last` picks the right one.
- **`ForgotPasswordCubit()`'s default constructor cannot be reached at all
  under `flutter test`, even to just render the screen** —
  `AuthRepository()`'s constructor initializer list unconditionally
  evaluates `FirebaseAuth.instance` (`_firebaseAuth = firebaseAuth ??
  FirebaseAuth.instance`), which throws synchronously with no
  `Firebase.initializeApp()` in the test binary, and `showForgotPasswordSheet`
  always built its own `ForgotPasswordCubit()` inline with no injection
  seam. Unlike `SignInCubit`/`SignUpCubit`'s Firebase gap (only certain
  *methods* touch Firebase, so a mocked-cubit widget test sidesteps it
  entirely), this one crashes on the sheet's very first `build()` —
  `BlocConsumer<ForgotPasswordCubit,_>.initState` reads the cubit
  immediately, before any test interaction happens — so no amount of
  "only test the parts that don't call Firebase" scoping helps; the whole
  screen was unreachable. Fixed with a small, additive production change:
  `showForgotPasswordSheet` gained an optional `@visibleForTesting
  ForgotPasswordCubit? cubit` parameter (mirrors `ApiClient.httpClientAdapter`'s
  existing test-only seam) — when supplied, the function uses
  `BlocProvider.value` instead of `create: (_) => ForgotPasswordCubit()`, so
  `forgot_password_screen_test.dart` can inject a `MockForgotPasswordCubit`.
  Zero behavior change for the real call sites, which never pass it.
- **A modal bottom sheet is pushed as a sibling route on the same
  `Navigator`, not as a descendant of the widget tree that opened it** —
  wrapping `BlocProvider`s only around `MaterialApp`'s `home` (the pattern
  every other screen test in this file uses, since they build the screen
  directly) left `showForgotPasswordSheet`'s sheet content unable to find
  `CountriesCubit`/`SettingsCubit` via `context.read`, throwing a
  `ProviderNotFoundException` the moment the sheet tried to mount. Fixed by
  wrapping `MultiBlocProvider` around `MaterialApp` itself in
  `forgot_password_screen_test.dart`'s harness — providers placed above the
  `Navigator` are visible to every route it pushes, including a modal sheet;
  providers placed only inside a route's own content are not visible to a
  sibling route.

## 18. profile — unit 🟡, widget 🔲, integration 🔲

No `models/` or `repositories/` directory under `lib/features/profile/` — the
feature reuses `AuthModel`/`AuthModelData` and `AuthRepository` wholesale
(`getProfile`/`updateProfile`, both already covered by
`auth_model_test.dart`/`auth_repository_test.dart`), so this feature's own
unit surface is just its two cubits: `ProfileDetailCubit` (uses
`ApiErrorGuard`, no Firebase touch, fully testable) and `ProfileUpdateCubit`
(plain `Cubit`, calls `AuthHiveBox`/`AnalyticsService`/`CrashlyticsService`
directly, only partially testable — see gotcha below). Widget/integration
layers not started this pass — screens (`ProfileScreen`, `EditProfileScreen`,
`AccountSettingsScreen`, `PoliciesScreen`, `ReferEarnScreen`) and sheets/
dialogs (`appearance_sheet`, `language_sheet`, `profile_dialogs.dart`) are
next; none of them exist as `MockCubit`s in `test/helpers/mock_cubits.dart`
yet (`MockProfileDetailCubit`/`MockProfileUpdateCubit` will be needed there).

`flutter test test/features/profile`: 6 unit tests green (3 per cubit). Full
suite (`flutter test`) stays green at 267.

### A. Unit
- **`profile_detail_cubit_test.dart`** — `loadProfile()`: `Loading` →
  `Loaded(profile)` on success; `ApiException` message surfaces via
  `ProfileDetailError`; a generic (non-`ApiException`) failure emits the
  localized "something went wrong" fallback — all three branches testable
  since `ApiErrorGuard.guard` never touches Firebase.
- **`profile_update_cubit_test.dart`** — only the `on ApiException catch (e)`
  branch is covered (see gotcha below); asserts `Loading` → `Error(message)`
  and that `repository.updateProfile` is called with the right named args
  (untouched optional params passed through as `null`).

### Bugs / gotchas found while building this
- **`ProfileUpdateCubit.updateProfile`'s success path calls
  `AnalyticsService.instance.logEvent(...)` immediately before
  `emit(ProfileUpdateLoaded(...))`, and its generic `catch` block calls
  `CrashlyticsService.instance.recordError(...)`** — both are singletons that
  lazily construct a real `FirebaseAnalytics`/`FirebaseCrashlytics` instance
  and throw synchronously under `flutter test`, the same class of gotcha
  `SignInCubit`'s `SignInLoaded` path already documents. Here it's worse:
  the `AnalyticsService` throw happens *inside* the method's own `try` block,
  so it's caught by the `catch (error, stack)` clause, which then calls
  `CrashlyticsService.instance.recordError` — a *second* Firebase singleton
  throw, this time with nothing left to catch it, so it escapes the method
  entirely rather than landing in a state. Both the `Loaded` success path and
  the generic-error path are therefore untestable at the cubit level; only
  `on ApiException catch (e)` runs before either singleton is ever touched.
  `ProfileDetailCubit` has no such gap — `ApiErrorGuard.guard` never
  references Analytics/Crashlytics, so all three of its branches are covered.

---

## 20. faq — done ✅

`flutter test test/features/faq test/commons/cubit/base_pagination_cubit_test.dart`:
50 unit + widget tests green (35 of them the shared base-cubit suite, 15
faq-specific). Integration: `integration_test/faq_flow_test.dart`, 4/4 green
on device (iOS simulator, `iPhone 17 Pro Max`, iOS 26.2).

The simplest possible `*PaginationCubit` feature — `FaqCubit` is a plain
`BasePaginationCubit<FaqData>` with no aliases, filters, or extra state of
its own; it's driven directly via the base's `fetchInitial`/`fetchMore`/
`refresh`. Picked as the first feature built precisely because it's the
smallest surface: model, repository, cubit, one screen, one list tile, one
skeleton loader, no auth/Hive/detail-sheet dependencies.

### A. Unit
- **Model** (`faq_model_test.dart`) — `FaqResponse.fromJson`: envelope +
  every entry from a full payload; a missing or explicitly-null `data` key
  both default to an empty list, never `null` (this model's own hand-rolled
  parser, not the generic `PaginatedResponse`); `status`/`total` are
  `?.toString()`'d so a raw int off the wire still lands as a string.
  `FaqData.fromJson`: every field parsed; missing/null fields default to
  `''` (not `null`) for every string field and `false` for `isExpanded`;
  `id` (and every other field) lenient-tostrings a numeric value; `toJson`
  round trip.
- **Repository** (`faq_repository_test.dart`) — mock `ApiClient`: hits
  `ApiEndpoints.faq`, default offset/limit sent, custom offset/limit
  forwarded, every field parses off the fixture through `FaqData.fromJson`,
  a null or missing `data` block returns an empty list without crashing.
- **Cubit** (`faq_cubit_test.dart`) — `fetchInitial`/`fetchMore` fetch the
  right offsets and map `FaqResponse.data`/`.total` (a string) into the
  base's `PaginatedResponse<FaqData>` (an int) — including a null
  `total`/`data` falling back to `0`/`[]` rather than crashing; the API's
  error message surfaces on failure. No aliases to test beyond that, since
  `FaqCubit` adds none — everything else is covered once in
  `base_pagination_cubit_test.dart`.

### B. Widget
- `faq_tile.dart` (3) — question always visible, answer hidden until
  tapped, tapping again collapses it back (the tile owns its own expand
  state internally, independent of `FaqData.isExpanded`, which the model
  parses but the widget never reads).
- `faq_list_skeleton_loader.dart` (2) — default 8-tile placeholder count ×
  2 shimmer boxes each (question line + chevron) = 16; a custom `itemCount`
  scales the same way.
- `faq_screen.dart` (10) — initial `fetchInitial()` call; loading →
  `FaqListSkeletonLoader`; loaded → one `FaqTile` per entry; loaded-but-empty
  → `EmptyStateWidget` with its own no-faqs copy (distinct from the error
  copy); error → `EmptyStateWidget` with the API message and a working
  retry wired to `refresh()` (not `fetchInitial()` — the error branch's own
  retry callback, confirmed by reading the screen rather than assumed);
  offline → `AppNoInternetView` replaces the body; a `ConnectivityConnected`
  reconnect refetches via `fetchInitial()`.

### C. Integration (`integration_test/faq_flow_test.dart`, 4/4 green on device)
Mounted via a new minimal harness, `integration_test/helpers/faq_test_app.dart`
— real router (`AppRouter.generateRoute`), real `FaqScreen`/`FaqCubit`/
`FaqRepository`, network faked at the `ApiClient` adapter seam. Unlike
delivery-boy's per-feature `auth_test_app.dart`-style harnesses, this one
needs no auth session and provides only `ConnectivityCubit` — the faq route
wires its own `BlocProvider<FaqCubit>`. Covers: the first page loads on
entry; tapping a tile expands it and shows its answer; pull-to-refresh
refetches; scrolling near the bottom pages in the second batch (asserted on
the follow-up request's non-zero offset, per the `ListView.builder`
mounted-items gotcha already documented in delivery-boy's suites).

### Bugs / gotchas found while building this
- **`MaterialApp.initialRoute` always builds `RouteNames.splash` first.**
  `Navigator.defaultGenerateInitialRoutes` unconditionally seeds the
  navigation history with the app's default (`/`) route before the
  requested one, so a harness that only provides the one feature's own
  dependencies crashes with a `ProviderNotFoundException` for
  `SettingsCubit` — `SplashScreen` needs it, mounted or not, invisible or
  not. Not a delivery-boy carryover: their `auth_test_app.dart` sidesteps
  this by providing every cubit `SplashScreen`/`MainScreen` could need.
  Fixed here without pulling in that whole provider list: `FaqTestApp`
  overrides `MaterialApp.onGenerateInitialRoutes` to build only
  `RouteNames.faq`'s route directly, skipping the forced splash route
  entirely — the right call for a single, self-contained route.
- **Every real request needs `settingsBox`/`authBox` open, even
  logged-out, auth-free endpoints.** `ApiClient._withLangHeader` reads
  `SettingsHiveBox.instance.languageCode` and `DioInterceptor.onRequest`
  reads `AuthHiveBox.instance.getToken()` unconditionally for any endpoint
  outside a small allowlist (login/register/forgot-password) — faq isn't on
  that allowlist despite needing no login, so both boxes must be opened in
  a temp-dir `Hive.init` before any request, or every call throws a
  `HiveError` that surfaces as a generic API error (not a crash — easy to
  miss without checking the actual `EmptyStateWidget` message on screen).
- **Fixture envelope `status` must be a numeric `1`, not `'1'`.** Every
  other field on `FaqResponse`/`FaqData` tolerates a stringified value via
  `?.toString()`, but `ApiClient._handleResponse` checks the raw JSON body's
  `status` field with `== 1` (an int literal) *before* any of that parsing
  runs. A JSON-encoded string `"1"` fails that check silently and turns
  every canned response into an error surfaced with the envelope's own
  `message` field instead of the actual faq data — no exception thrown,
  just an empty list where tiles should be. Caught only by checking the
  on-screen `EmptyStateWidget` text during debugging, not from any stack
  trace. Documented in `integration_test/helpers/faq_fixtures.dart` itself
  so the next feature's fixtures don't repeat it.

None of the three findings above touched `lib/` production code — they were
all test-harness setup gaps, unlike delivery-boy's first few features which
did surface real app bugs. `AppTheme.lightTheme` also takes a `Color primary`
parameter here (server-configurable via `SettingsCubit`), unlike
delivery-boy's zero-arg version — already handled by `pump_test_widget.dart`
during the setup pass, not something faq's own tests needed to work around.

---

## 19. blog — done ✅

Bigger surface than faq: two models (`Blog`, `BlogCategory`), two cubits
(`BlogCubit` — a `FilteredPaginationCubit<Blog, String?>` filtered by category
id — and `BlogCategoryCubit`, a plain `Cubit` using the `ApiErrorGuard` mixin,
not `BasePaginationCubit`), a list screen with a category filter bar, and a
detail screen.

`flutter test test/features/blog`: 82 unit + widget tests green (39 unit
across `blog_model_test.dart`/`blog_category_model_test.dart`/
`blog_repository_test.dart`/`blog_cubit_test.dart`/
`blog_category_cubit_test.dart`, 43 widget across
`blog_meta_info_test.dart`/`blog_list_skeleton_loader_test.dart`/
`blog_card_test.dart`/`category_filter_bar_test.dart`/`blog_screen_test.dart`/
`blog_detail_screen_test.dart`). Full suite (`flutter test`) stays green at
132. Integration: `integration_test/blog_flow_test.dart`, 6/6 green on device
(iOS simulator, `iPhone 17 Pro Max`, iOS 26.2).

Sections A and B below are what actually got built (kept in the original
planned form since the plan matched what shipped); the gotchas subsections at
the end are new — real findings from building this, not anticipated ones.

### A. Unit
- **`blog_model_test.dart`**
  - `BlogResponse.fromJson`: envelope `status`/`message`/`total` all
    `?.toString()`'d; every entry parsed via `Blog.fromJson`; `data` missing,
    `null`, or not a `List` (e.g. a `Map`) all fall back to `[]`, never `null`.
  - `Blog.fromJson`: every field parsed off a full fixture; missing/null
    string fields default to `''` except `id` → `'0'`, `categoryId` → `'0'`,
    `status` → `'0'`, `viewsCount` → `'0'`, `readTime` → `'0'` (`parseString`
    fallbacks differ per field — assert each, don't assume one default);
    `tagNames`: a JSON `List` maps to `List<String>` via `.toString()` on each
    element (covers non-string entries), missing/non-`List` → `[]` (not
    `null`); `category`: a nested `Map` parses via `BlogCategory.fromJson`,
    anything else (missing, `null`, wrong type) → `null` (not a default
    object — unlike the string fields); `lang` is the one field with no
    `?? ""` fallback — stays `null` when absent, assert that explicitly.
  - `toJson` round trip: includes `category` key only when `category != null`
    (assert it's *absent*, not `null`, when the blog has no category) —
    every other key always present.
- **`blog_category_model_test.dart`**
  - `BlogCategoryResponse.fromJson`: same envelope/`data`-fallback shape as
    `BlogResponse` (no `total` field here, unlike blogs).
  - `BlogCategory.fromJson`: every field parsed; missing/null → `''` for
    strings, `'0'` for `id`/`status`/`activeBlogsCount`; unlike `Blog.lang`,
    `BlogCategory.lang` *does* default to `''`, not `null` — contrast the two
    explicitly since it's easy to assume they match.
  - `toJson` round trip (note `lang` is intentionally omitted from `toJson`
    even though it's parsed — assert it's absent from the output map).
- **`blog_repository_test.dart`** (mock `ApiClient`)
  - `getBlogCategories()` hits `ApiEndpoints.blogCategories`, no query params;
    parses a fixture into `BlogCategoryResponse`; a null/missing `data` block
    returns `[]` without throwing; an `ApiException` from the client rethrows
    as-is (not wrapped) — assert same instance/message; a non-`ApiException`
    (e.g. a raw `DioException`) is wrapped via `ApiException.fromDioError`.
  - `getBlogs()` hits `ApiEndpoints.blogs`; default `offset`/`limit`
    (`AppConfig.pageLimit`) sent when omitted; custom `offset`/`limit`
    forwarded; `categoryId: null` is *dropped* from query params entirely
    (`removeWhere`), not sent as a literal `null` — assert the params map
    key is absent, not present-with-null-value; a non-null `categoryId` is
    forwarded; same rethrow/wrap split on `ApiException` vs. other errors as
    above.
- **`blog_cubit_test.dart`** (`BlogCubit extends FilteredPaginationCubit`)
  - `loadBlogs({categoryId})` → `applyFilters(categoryId)` → `fetchInitial()`
    fetches offset 0 with that category id; the response's `data` maps
    straight through and `total` (a string off the wire) parses via
    `int.tryParse(...) ?? 0` into the base's `int total` — including a
    non-numeric or missing `total` falling back to `0` rather than throwing;
    a null `data` in the fetcher's mapped `PaginatedResponse` falls back to
    `[]` (the cubit's own `?? []`, not the model's).
  - `computeHasMore` override: page-length based, *not* total-based — assert
    `hasMore == true` when a page returns exactly `AppConfig.pageLimit` items
    (even if `total` says otherwise) and `false` when a page returns fewer,
    the opposite of the base class's default `allData.length < total` check
    (worth a directly contrasting test since this is the one place `BlogCubit`
    diverges from `FaqCubit`'s reliance on the base default).
  - `filterByCategory(id)` calls `applyFilters(id)`, resets to `fetchInitial()`
    (not `fetchMore`) — list replaced, not appended, and `currentFilters`
    reflects the new id afterward; calling it with `null` clears back to the
    unfiltered fetch.
  - `fetchMore()`/pagination-error/loading transitions: covered once in
    `base_pagination_cubit_test.dart`, not re-asserted here — only
    `BlogCubit`'s own overrides (`buildFetcher`, `computeHasMore`,
    `loadBlogs`/`filterByCategory`) need feature-specific tests, same
    division of labor as `FaqCubit`'s suite.
- **`blog_category_cubit_test.dart`** (plain `Cubit` + `ApiErrorGuard`, *not*
  a pagination cubit — no shared base coverage to lean on, so this one needs
  its own full state-transition suite)
  - `loadCategories()` emits `BlogCategoryLoading()` then
    `BlogCategoryLoaded(categories)` on success, `categories` sourced from
    `result.data ?? []` (assert the `null`-data fallback specifically, since
    the repository's own `data` field can itself be `null`/missing).
  - On repository failure: `ApiException` → `BlogCategoryError(e.message)`
    with the exception's own message; a non-`ApiException` throw →
    `BlogCategoryError` with the generic "something went wrong" localized
    string, mirroring `ApiErrorGuard.guard`'s split — assert both branches,
    not just one.
  - Initial state is `BlogCategoryInitial()` before `loadCategories()` is
    ever called.

### B. Widget
- `blog_meta_info.dart` — read-time and views text always shown (`readTime`/
  `viewsCount` fall back to `'0'` when null, per the model, so assert the
  widget renders `'0 <read/views label>'` rather than blank); date row only
  when `showDate: true` *and* `createdAt` non-empty — both a `showDate: false`
  case and a `showDate: true` + empty-`createdAt` case should hide it,
  covered as distinct cases since either condition alone suppresses the date.
- `blog_list_skeleton_loader.dart` — default `itemCount: 4` cards, each with
  its fixed shimmer-box layout (image + category/date row + 2 title lines +
  2 description lines + 2 meta boxes); a custom `itemCount` scales the card
  count, shape per card unchanged.
- `blog_card.dart` — title/short-description/category chip/date/image all
  render when present; each is independently omitted when its source field
  is empty (image row, category chip, date, short-description are each
  individually conditional — don't collapse into one "renders card" case);
  `BlogMetaInfo` is embedded with `showDate: false` (card never shows its own
  date twice); tapping the card navigates to `RouteNames.blogDetail` with the
  tapped `Blog` as the route argument (verify via a mocked/observed
  navigator, not by asserting on `BlogDetailScreen` actually mounting —
  keep this a card-level unit, the actual detail render is `blog_screen`'s
  or `blog_detail_screen`'s own widget test).
- `category_filter_bar.dart` — renders nothing (`SizedBox.shrink`-equivalent)
  while `BlogCategoryCubit` is not yet `Loaded` or its `categories` list is
  empty (assert both the pre-load and loaded-but-empty cases collapse the
  bar, since either alone must not show it); once loaded with categories, an
  "All" chip plus one `CategoryChip` per category render, "All" selected
  when `BlogCubit.currentFilters == null`; tapping "All" calls
  `filterByCategory(null)`, tapping a category chip calls
  `filterByCategory(cat.id)`; selected-state styling (fill vs. outline) flips
  to whichever id matches `currentFilters` — assert selection follows the
  cubit's filter state after a tap, not just the tapped chip's own visual.
- `blog_screen.dart` — on `initState` both `BlogCategoryCubit.loadCategories()`
  and `BlogCubit.loadBlogs()` fire (two, not one — easy to only assert the
  blog fetch and miss the category one); app bar's `bottom` `PreferredSize`
  collapses to height 0 (and `CategoryFilterBar` effectively hidden) until
  categories are loaded and non-empty, matching `category_filter_bar.dart`'s
  own hide condition — a redundant-looking pair of checks (`select`'d bool
  here, cubit-state check inside the bar) worth testing at both layers since
  a screen-level regression wouldn't necessarily be caught by the bar's own
  widget test; `PaginationInitial` state *also* triggers a `loadBlogs()` call
  from inside `build()` (not just `initState`) before rendering the skeleton
  — an odd double-fetch path worth its own case rather than assuming
  `initState` alone covers it; loading → `BlogListSkeletonLoader`; loaded +
  non-empty → one `BlogCard` per entry via `ListView.separated`; loaded +
  empty → `EmptyStateWidget` with the "no blogs" copy (distinct from the
  error copy, distinct from faq's own empty copy); error →
  `EmptyStateWidget` with the API message, retry wired to `loadBlogs()` (not
  `refresh()` — the opposite of faq's error-retry wiring, confirm by reading
  the screen rather than assuming parity with faq); offline →
  `AppNoInternetView` replaces the body (app bar untouched); reconnect via
  `ConnectivityConnected` re-fires both `loadCategories()` and `loadBlogs()`;
  paginated footer (`PaginatedListFooter`) appears as the trailing list item
  only while `isFetchingMore`.
- `blog_detail_screen.dart` — title/description (`HtmlWidget`) always
  rendered when present; hero image only when `imageUrl` non-empty; category
  chip + formatted `createdAt` row only when at least one of the two is
  present (each independently optional inside that row, same pattern as
  `blog_card`); tags (`Wrap` of `#tag` chips) only when `tagNames` non-empty;
  `BlogMetaInfo` embedded with `showDate: false` (detail screen shows its own
  date in the header row instead, so the meta row must not duplicate it —
  worth asserting explicitly given `blog_card` does the same suppression for
  a different reason).

### C. Integration (`integration_test/blog_flow_test.dart`, 6/6 green on device)
Mounted via `integration_test/helpers/blog_test_app.dart`, same harness
pattern as faq's (`onGenerateInitialRoutes` overridden to skip the forced
splash route, `settingsBox`/`authBox` opened in a temp-dir `Hive.init`
before any request, fixture envelope `status` as numeric `1`), but
`RouteNames.blog`'s own route already wires **both**
`BlogCategoryCubit`+`BlogCubit` providers (see `AppRouter.generateRoute`) —
the harness itself needed no extra provider wiring beyond `ConnectivityCubit`,
same as faq's. `integration_test/helpers/blog_fixtures.dart` stubs **two**
endpoints (`ApiEndpoints.blogCategories` and `ApiEndpoints.blogs`, the latter
keyed off both `category_id` and `offset`) — sequencing matters since
`BlogScreen.initState` fires both loads together. Page 1 of the unfiltered
fixture returns exactly `AppConfig.pageLimit` (10) items on purpose:
`BlogCubit.computeHasMore` is page-length based, so a short page 1 would
silently make `hasMore` false and the pagination test a false negative.
Covers: first page of blogs (10 cards) + category chips (`Delivery`,
`Groceries`) both load on entry; tapping the `Delivery` chip re-fetches
`blogs` with `category_id=2` and replaces the list (1 card, not appended);
tapping "All" clears the filter and re-fetches unfiltered (back to 10);
tapping a `BlogCard` navigates to a real `BlogDetailScreen` carrying that
blog; scrolling near the bottom pages in the next batch, asserted on the
follow-up request's non-zero offset (same `ListView.builder`
mounted-items-aren't-stable gotcha as faq's suite); pull-to-refresh
re-fetches with the *currently active* category filter still applied (not
reset to unfiltered — `BlogCubit.refresh()` inherits `fetchInitial()`, which
reads `_filters` as of the last `applyFilters` call, not a fresh `null`).

### Bugs / gotchas found while building the unit + widget layers
- **`BlogCubit.loadBlogs()`/`FilteredPaginationCubit.applyFilters()` is
  declared `void`, not `Future<void>`** (`applyFilters`'s own `Future<void>`
  return value is discarded by the `void loadBlogs(...) => applyFilters(...)`
  arrow body) — `await cubit.loadBlogs()` doesn't compile (`void` isn't a
  `Future`). Cubit tests call `cubit.loadBlogs()` un-awaited, then
  `await pumpEventQueue();` to let the fire-and-forget fetch settle before
  asserting on `cubit.state`. `filterByCategory()` is the one method on
  `BlogCubit` that *does* return `Future<void>` and can be awaited directly —
  worth double-checking a cubit's actual return type before assuming `await`
  works, rather than copying the pattern from a sibling method.
- **Any widget that formats `blog.createdAt` (`BlogCard`, `BlogDetailScreen`)
  needs a real Hive `settingsBox` open**, even in a plain widget test with no
  cubit involved — `AppDateFormatter.formatDateTime` reads
  `SettingsHiveBox.instance.dateFormat` unconditionally. Faq never hit this
  since nothing in its widgets formats a date. Fixed via
  `HiveTestHelper.setUp(settingsBox)`/`tearDown` in `setUpAll`/`tearDownAll`
  for `blog_card_test.dart`, `blog_screen_test.dart` (renders `BlogCard`s),
  and `blog_detail_screen_test.dart` — omitting it throws a `HiveError`
  *during build*, not a silently-wrong render, so it fails loudly.
- **`context.translate(key)` returns the raw key string itself when no
  translations are loaded** (`LocalizationService.translate`'s
  `fallback ?? key` path) — untranslated widget tests see literal key values
  like `"all"`/`"read"`/`"views"`, not their human-readable copy (`"All"`,
  etc.). `category_filter_bar_test.dart` initially asserted on `'All'`
  (capitalized) and failed; fixed by asserting against
  `LanguageLabelKeys.filterAll` directly instead of a guessed literal —
  robust to whatever the constant's raw value actually is, not just this key.
- **A `ListView` inside the default `flutter test` viewport (800×600) only
  lays out as many items as fit on screen**, even with
  `NeverScrollableScrollPhysics` — `BlogListSkeletonLoader`'s default 4 cards
  only produced 18 `ShimmerBox`es (2 cards) instead of the expected 36 until
  the test widened the viewport (`tester.view.physicalSize = Size(500,
  2000)`), the same fix `faq_screen_test.dart` already needed for its own
  list. Applies to any list-shaped widget test, not just skeleton loaders —
  worth checking viewport size first when a list-count assertion comes up
  short by exactly "how many fit on screen."
- Confirms two faq findings still hold unchanged for blog: `MaterialApp`
  needs no splash-route workaround at the widget-test layer (that's an
  integration-harness-only concern), and translated/copy-driven assertions
  should reference the `LanguageLabelKeys` constant rather than a hardcoded
  guess at the string.

### Bugs / gotchas found while building the integration layer
- **`BlogCard`'s own category badge and `CategoryFilterBar`'s chip render the
  same text** (`"Delivery"`) — on a real device, `find.text('Delivery').first`
  landed on a *card's* badge, not the filter chip, because the card's
  `GestureDetector` (which navigates to the detail screen) sits earlier in
  hit-test/tree order than the filter bar. The category-filter test silently
  navigated away instead of filtering, surfacing as `categoryId` staying
  `null` in the next request rather than a crash. Fixed by scoping the finder
  to the filter bar specifically: `find.descendant(of:
  find.byType(CategoryFilterBar), matching: find.text(label))`. Same risk
  applies to any label a card repeats from chrome around it — prefer a scoped
  `descendant` finder over `.first` whenever two different widgets can
  plausibly render identical text.
- **`find.byType(ListView)` is ambiguous on the blog screen**: the vertical
  blog list and `CategoryFilterBar`'s horizontal chip row are both
  `ListView`s. `tester.drag()` on the unscoped finder throws immediately
  ("ambiguously found multiple matching widgets") rather than silently
  picking one — fixed with `find.byWidgetPredicate((w) => w is ListView &&
  w.scrollDirection == Axis.vertical)`. Doesn't come up in faq (only one
  list on screen); worth checking for before reusing a `find.byType(ListView)`
  drag pattern on any screen with more than one scrollable.
- **The pagination fixture must return a full page for `hasMore` to flip
  true.** `BlogCubit.computeHasMore` is page-length based
  (`response.data.length >= AppConfig.pageLimit`, i.e. 10), unlike faq's
  total-based default — an initial attempt at page 1 with only 2-3 items (like
  faq's own fixture) made `hasMore` false immediately, so no amount of
  scrolling ever fired a follow-up request; the pagination test failed by
  sending exactly one request, not by erroring. Fixed by generating a page 1
  fixture with exactly `AppConfig.pageLimit` items
  (`blog_fixtures.dart`'s `_blog()` helper + `List.generate(10, ...)`).
- **Cards are much taller than faq's tiles**, so faq's own scroll-distance
  constants (20 drags × 60px) weren't enough to cross the
  `PaginationScrollController`'s 200px-from-bottom threshold over a
  10-card list — the drag completed without error but never triggered
  `fetchMore`, read initially as "pagination isn't wired up" rather than
  "the test didn't scroll far enough." Driving the drag directly on the
  scrollable (`tester.drag(list, ...)` in a loop) rather than a raw
  `startGesture`-at-a-screen-point made the distance-tuning visible and
  reliable, instead of guessing at gesture pixel deltas.
