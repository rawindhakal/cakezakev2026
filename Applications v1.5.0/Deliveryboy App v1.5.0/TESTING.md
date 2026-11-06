# Testing Plan — CakeZake Delivery Boy App

Feature-by-feature test case checklist. Built 1 by 1, product-ready pass —
each feature covered on **3 layers: unit, widget, integration** — before next
feature starts.

## Setup (done)

`pubspec.yaml` `dev_dependencies` (added, marked with a comment pointing here):
```yaml
bloc_test: ^10.0.0   # ^9.x pins bloc ^8, incompatible with flutter_bloc ^9.1.1
mocktail: ^1.0.4
integration_test:
  sdk: flutter
```

Dirs:
- `test/features/<feature>/...` — unit (models, repository, cubit) + widget tests. Mirrors `lib/features/<feature>/...`.
- `test/fixtures/<feature>/` — real API response payloads as JSON. Refresh these when the backend contract changes instead of editing assertions inline.
- `test/helpers/` — shared test infra:
  - `pump_test_widget.dart` — wraps the widget under test in `AppTheme.lightTheme()` + `MaterialApp` (+ `Scaffold` unless `wrapInScaffold: false`).
  - `mock_cubits.dart` — `MockCubit` classes per cubit (`MockSignInCubit`, `MockCountriesCubit`, …).
  - `mock_api_client.dart` / `mock_auth_repository.dart` — mocktail mocks for the network and repository layers.
  - `hive_test_helper.dart` — opens a plain temp-dir Hive box for code paths that read `AuthHiveBox` / `SettingsHiveBox`.
  - `test_logging.dart` — `printTestDivider(String label)` helper.
- `integration_test/` — full end-to-end flows: real router, real screens, real cubits and repositories, driven on a device/simulator (`flutter test integration_test/auth_flow_test.dart -d <device>`). The network is faked at the Dio adapter level via `FakeApiAdapter` + `ApiClient().httpClientAdapter` (a `@visibleForTesting` seam on `ApiClient`), and Hive runs against a temp dir.

Run everything headless (unit + widget) with `flutter test`. The default
template `test/widget_test.dart` (counter smoke test) was removed — it never
matched this app and always failed.

## Progress

| # | Feature | Unit | Widget | Integration |
|---|---------|------|--------|--------------|
| 1 | auth | ✅ | ✅ | ✅ |
| 2 | home | ✅ | ✅ | ✅ |
| 3 | orders | ✅ | ✅ | ✅⁴ |
| 4 | cash_collection | ✅ | ✅ | ✅ |
| 5 | earnings | N/A¹ | ✅ | ✅ |
| 6 | wallet | ✅ | ✅ | ✅ |
| 7 | salary | ✅ | ✅ | ✅ |
| 8 | settlement_history | ✅ | ✅ | ✅ |
| 9 | notifications | ✅ | ✅ | ✅ |
| 10 | chat | ✅ | ✅ | ✅ |
| 11 | profile | ✅ | ✅ | ✅³ |
| 12 | main / splash | ✅ | ✅ | ✅ |

Mark 🔲 → 🟡 (in progress) → ✅ (done, tests green) per column as we go.

¹ earnings has no model/repository/cubit of its own — it was refactored to
read `DashboardModel`/`DashboardCubit` from the home feature directly (see
"5. earnings" below). Its Unit layer is fully covered, just under `2. home`'s
tests rather than its own — nothing earnings-specific was left untested.

² earnings' and notifications' integration tests are written and analyze
clean, but could not be executed here: the iOS build fails in the Crashlytics
`upload-crashlytics-symbols` run-script phase (a missing `firebase-ios-sdk`
checkout in DerivedData), and no Android device was attached at the time.
settlement_history carried the same status until an Android device became
available and its suite was run for real (7/7 green, see its own section).
chat's and main/splash's integration suites were likewise later run for real
on a wirelessly connected Android device (`SM M066B`, API 36) once one became
available — see their own sections for what that run found and fixed. Running
multiple device-executed suites (`chat_flow_test.dart`, `main_flow_test.dart`,
`splash_flow_test.dart`) back to back in one `flutter test` invocation trips
VM-service/wireless-adb flakiness (`getVersion: Service has disappeared`) —
an infra issue with the wireless connection, not the app or the tests; each
suite is green run on its own.

³ profile's integration suite ran for real on device in the same session
that wrote it, unlike earnings'/notifications', which were only
`flutter analyze`-verified — see §11 for what its 4 tests cover and what's
deliberately deferred (language sheet, policies nav, offline swap).

⁴ orders' `orders_flow_test.dart` (list → detail → advance status → refreshed
list, plus an empty-list case) first hit a real, reproducible bug on the iOS
simulator, not a flake: `NotificationService.getToken()` was a bare
`_messaging.getToken()`, and `MainScreen._syncMissingFcmToken` calls it
unguarded on every post-login mount. `FirebaseMessaging.getToken()` throws
`[firebase_messaging/apns-token-not-set]` on iOS whenever the platform
hasn't handed out an APNs token yet — a real race on a fresh install/permission
grant, not just a simulator artifact — and nothing caught it, so it crashed
the app (and any test that mounts `MainScreen`; confirmed the already-✅
`main_flow_test.dart` hit the identical uncaught exception on repeated runs
on the same simulator). Fixed in `lib/core/services/notification_service.dart`:
`getToken()` now catches and returns null, which every caller already treats
as "nothing to sync yet" — no caller-side changes needed. Both
`orders_flow_test.dart` (2/2) and `main_flow_test.dart` (4/4) then ran green
for real on the iOS simulator (`iPhone 17 Pro Max`, iOS 26.2). One test-only
fix needed too: `tester.pageBack()` only recognizes
`BackButton`/`CupertinoNavigationBarBackButton`, but `CustomAppBar`'s leading
control is a plain `IconButton` — swapped for a direct tap.
Deliberately out of scope for `orders_flow_test.dart`: `OrderTrackingMapView`
(`google_maps_flutter`/`flutter_map`), which needs platform-channel map
mocking this repo doesn't have yet — the widgets it composes
(`OrderTrackingInfoCard`, `OrderTrackingNoLocation`) are covered directly in
`tracking_widgets_test.dart` instead.

---

## 1. auth — done ✅

`flutter test`: 85 unit + widget tests green. Integration: 10 tests green on
device (`auth_flow_test.dart` 5, `session_flow_test.dart` 5).

### A. Unit tests

**Models** — `AuthModel` / `AuthModelData`
- fromJson: full payload → all fields parsed correctly
- fromJson: null/missing fields → nulls not crash
- fromJson: `status` as bare int vs quoted string (`toSafeIntOrNull` lenient parse)
- toJson: round-trip (fromJson → toJson → same shape)

**Repository (`AuthRepository`)** — mock `ApiClient`
- `login` — sends correct fields (email/password/type=3/fcmToken/platform/languageId), parses `AuthModel`
- `register` — multipart fields built correctly per bonusType/returnBonusType branches (conditional field inclusion), image files attached when path given
- `forgotPassword` — correct field, returns message map
- `changePassword` — correct field mapping (old/new/confirm)
- `getProfile` — GET, parses `AuthModel`
- `addFcmToken` / `updateFcmToken` — correct fields sent
- `logout` — sends stored fcmToken from `AuthHiveBox`
- `getDeliveryBoyStatus` — status as bare int AND quoted string both parse; missing/null status → throws `ApiException`; remark passthrough
- `updateDeliveryBoyStatus` — correct status field
- `deleteAccount` — POST called
- `updateProfile` — conditional field inclusion same as register, image upload

**Cubits (bloc_test)** — mock `AuthRepository`
- `SignInCubit.login`
  - emits [Loading, Loaded] on success; saves session via `AuthHiveBox.saveLoginData`
  - emits [Loading, Error] on `ApiException`
  - `onSuccess`: analytics `eventLogin` fired, userId set on Analytics/Crashlytics/Clarity when `user.data?.id` present; skipped when id null
  - `reset()` → back to Initial
- `SignUpCubit.register`
  - emits [Loading, Loaded] w/ message from response or localized fallback
  - emits [Loading, Error] on failure
  - analytics `eventSignUp` fired on success only
  - `reset()` → Initial
- `AuthCubit`
  - `checkAuth()`: emits Authenticated when `AuthHiveBox.isLoggedIn` true + token non-empty
  - `checkAuth()`: emits Unauthenticated when logged out OR token empty
  - `logout()`: emits Loading → Unauthenticated; clears local auth even if server call throws (swallowed)
- `ForgotPasswordCubit.forgotPassword` — [Loading, Loaded]/[Loading, Error], message fallback
- `ChangePasswordCubit.changePassword` — [Loading, Loaded]/[Loading, Error], message fallback
- `DeleteAccountCubit.deleteAccount` — [Loading, Loaded]; clears `AuthHiveBox` on success
- `LogoutCubit.logout` — [Loading, Loaded]; clears `AuthHiveBox`
- `AddFcmTokenCubit.addFcmToken` / `UpdateFcmTokenCubit.updateFcmToken` — [Loading, Loaded]/[Loading, Error]

### B. Widget tests

- `sign_in_screen.dart` / `login_form.dart`
  - empty email/password → validation error shown, no submit call
  - invalid email format rejected
  - valid input → `SignInCubit.login` called w/ entered values
  - loading state → button shows spinner / disabled
  - error state → error message/snackbar shown
  - success → navigates to home
- `sign_up_screen.dart` / `register_form.dart` + `register_credential_fields.dart` + `register_identity_docs.dart`
  - required field validation (name, mobile, password, confirmPassword match)
  - password ≠ confirmPassword → validation error
  - bonusType conditional fields show/hide correctly
  - image pickers (profile/national id/driving license) set path on selection
  - submit success → navigates / shows success
  - submit error → error shown, form stays
- `forgot_password_screen.dart`
  - empty email → validation error
  - valid submit → `ForgotPasswordCubit` called, success message shown
  - error → error shown

### C. Integration tests

Real router, real screens, real cubits and repositories; only the network is
faked. Run with `flutter test integration_test/<file> -d <device>`.

`integration_test/auth_flow_test.dart` — getting in:
- **Login success**: session persisted to Hive, sign-in screen left behind.
- **Login rejected**: server message surfaced, stays on sign-in, nothing persisted.
- **Forgot password**: sheet opens from the login form, submits, hits the endpoint.
- **Sign-up validation**: an empty form never reaches the register endpoint.
- **Session persistence**: token survives a full app rebuild (stand-in for a cold start).

`integration_test/session_flow_test.dart` — getting out (logout/delete dialogs
live in the profile feature but drive auth cubits and clear `AuthHiveBox`):
- **Logout success**: endpoint called, session cleared, back on sign-in.
- **Logout cancelled**: no request, session intact.
- **Logout failed**: `LogoutCubit` surfaces the error and keeps the session (unlike `AuthCubit.logout`, which clears regardless).
- **Delete account success**: endpoint called, session cleared, back on sign-in.
- **Delete cancelled**: no request, account intact.

Not covered here: the **blocked-account** flow (`getDeliveryBoyStatus` returning
4). The repository parsing is unit-tested, but the dialog is driven by
`DashboardScreen` — it belongs to the home feature's own integration test.

---

## 2. home — done ✅

`flutter test`: 137 unit + widget tests green. Integration: 8 green on device
(`home_flow_test.dart`). Every file under `lib/features/home/` has its own
test.

### A. Unit
- **Model** (`dashboard_model_test.dart`, 16) — every section of the real
  `/dashboard` payload (profile, today, wallet, cash, salary, orders, status
  breakdown, returns + nested breakdown, earnings trend, recent cash,
  withdrawals), plus a missing `data` block, an empty `data` block, and a
  `toJson` round trip.
- **Repository** (4) — endpoint, default and explicit `trend` query, error
  propagation.
- **Cubits** (14) — `DashboardCubit` (5, incl. refresh-after-error);
  `DeliveryBoyStatusCubit` (9, incl. the optimistic toggle, API-error rollback,
  silent rollback on an unexpected error, blocked no-op, and no-op before a
  status is loaded).
- **Socket service** (12) — `MaintenanceSocketService` driven against a real
  local WebSocket server rather than a mock (point `broadcast_config` at
  127.0.0.1 and the service resolves to it): handshake → subscribe, ping/pong
  keepalive, toggle on/off, persistence to the settings box, ignoring another
  surface's toggle, remark language fallback, malformed frames, no-key skip,
  duplicate connect, reconnect after disconnect.

### B. Widget (91)
Stat card/column, order status grid, return-requests card, earnings trend card
(+ `trendValueForPeriod`), dashboard list card, home header + profile row,
toggle-status dialog, account-blocked dialog, overview section (rate maths,
zero-total guards, clamping, status-7 filtering), performance section, the
charts and skeleton loader (`active_status_chart`, `return_requests_pie_chart`,
`earnings_line_chart`, `dashboard_skeleton_loader`), the maintenance scheduled
dialog (19: window logic, once-per-session, dismissal, countdown, duration
wording), and `dashboard_screen` itself (13: initial fetches, skeleton, loaded,
error, header persistence across states, offline swap, online/offline mapping,
toggle dialog, blocked dialog, pull-to-refresh).

### C. Integration (`integration_test/home_flow_test.dart`)
Dashboard loads and renders; default trend window; header reflects server
status (online and offline); status toggle persists and flips the header;
blocked account raises the dialog; acknowledging it clears the session and
returns to sign-in; a failed fetch shows the error state without crashing.

### Bugs found and fixed
`DashboardScreen`'s error branch used `SliverFillRemaining(hasScrollBody:
false)` around `EmptyStateWidget`, whose root is a `LayoutBuilder`. The sliver
measures its child's intrinsic height, which a `LayoutBuilder` cannot provide —
so **every failed dashboard fetch** threw "LayoutBuilder does not support
returning intrinsic dimensions" and then a null-check crash in the viewport.
Reproduced in isolation with just those two widgets. Fixed by switching to
`hasScrollBody: true`; both the widget test and the integration test now guard
against it.

`DashboardStatCard`'s inner `Column` overflowed vertically by 1px on a real
device — the row leaves it only as much height as the 32px icon, which the
label + value are within a pixel of once the real (downloaded) font's metrics
differ slightly from the fallback's. It rendered the debug overflow stripes and
only reproduced on device, never in widget tests. Fixed by making the column
`mainAxisSize.min` with both lines `Flexible`, so they give way instead of
overflowing.

### Still open (backend/model mismatches, not fixed)
- `DashboardDataModel.fromJson` reads `recent_fund_transfers`, but the API
  sends `recent_settlements`, so `recentFundTransfers` is always null. Its
  `id` also arrives as a String (`"W-34"`) into an `int?` field, and
  `entry_type` isn't parsed. Latent — nothing in the UI reads the list yet.
- `EarningsTrend.data` is `List<int>` and rounds every point (`526.25 → 526`,
  `96.7 → 97`), so the chart loses the paise that `total` keeps.

---

## 3. orders — done ✅

`flutter test`: 277 unit + widget tests green under `test/features/orders/`.
Integration: `integration_test/orders_flow_test.dart`, 2/2 green on a real
device run (iOS simulator) — real navigation through list → detail → advance
status → refreshed list. Along the way this also fixed a real (non-simulator-
only) crash in the shared FCM sync path — see footnote 4 above.

### A. Unit
- **Models** — `order_model`, `order_detail_model`, `order_status_model`,
  `ecommerce_order_model`, `return_order_model`: fromJson/toJson edge cases.
- **Repository** (`order_repository_test.dart`) — every `OrderRepository`
  method against a mock `ApiClient`: endpoint + params, pagination, error
  propagation.
- **Cubits** — every cubit under `lib/features/orders/cubit/` has a
  `bloc_test` case, including `RoadRouteCubit` (OSRM-route fetch: snapped
  points on success, null points — not an error state — on failure, since
  it's a decorative overlay with a straight-line fallback).
- **Utils** — `payment_breakdown_test.dart` (combined-total / split-payment /
  collect-cash maths shared by cards and detail screens).

### B. Widget
Every widget under `lib/features/orders/widgets/` is covered, either directly
or through the screen/card test that composes it:
- Cards, sheets and filters: order/return/ecommerce cards, billing/items/note/
  timeline cards, `payment_summary_section`, `order_status_sheet` +
  `ecommerce_order_status_sheet` + `return_order_status_sheet` (each drives
  its own real, internally-created cubits against a `FakeApiAdapter` — they
  can't take an injected mock), `delivery_otp_bottom_sheet`, `orders_filter` +
  `return_orders_filter`.
- Small presentational pieces (`small_widgets_test.dart`) — `OrderAppBarTitle`,
  `OrderStatusSlideBar` (drag-to-confirm gesture), `OrderDateFilterRow`,
  `StatusFilterChips`.
- List wrappers (`order_lists_test.dart`) — `OrderListView`'s empty state and
  pagination footer, plus each of `OrderList`/`ReturnOrdersList`/
  `EcommerceOrderList` wiring its own item type and empty copy into it.
- Tracking widgets (`tracking_widgets_test.dart`) — `OrderActionButtons` (4
  tiles, 5th "Track Order" tile only while out for delivery, null-order
  safety), `OrderTrackingInfoCard`, `OrderTrackingNoLocation`. Not covered:
  `OrderTrackingMapView` itself — see footnote 4.
- Screens (`test/features/orders/screens/`) — `orders_screen_test.dart`
  (pre-existing, all 3 tabs); new: `order_detail_screen_test.dart`,
  `ecommerce_order_detail_screen_test.dart` (loading → loaded, hidden-status-
  bar branch, error + retry, each screen's own internally-created cubit
  driven through a `FakeApiAdapter`), `return_order_detail_screen_test.dart`,
  `return_orders_screen_test.dart` (skeleton → cards, offline placeholder,
  error + retry).

### C. Integration (`integration_test/orders_flow_test.dart`)
Mounted through `MainScreen` (like `main_flow_test.dart`) rather than a
standalone route — `OrdersScreen` only exists as the "My Delivery" tab, there's
no route that opens it directly. Covers: orders tab lists a quick order → tap
opens `OrderDetailScreen` → slide-to-confirm advances Out For Delivery to
Delivered → `update_status` sent with the right `status_id` → detail reloads
showing "Delivered" → back navigates to the list; plus the no-orders empty
state.

### Bugs found and fixed
`NotificationService.getToken()` (`lib/core/services/notification_service.dart`)
didn't catch `FirebaseMessaging.getToken()`'s `apns-token-not-set` exception,
so `MainScreen`'s post-login FCM sync crashed the app whenever iOS hadn't
handed out an APNs token yet — a real race on any fresh install/permission
grant, found here because the integration suite mounts `MainScreen` for real
on device. Fixed by catching and returning null, which every caller (this
screen's retry, the service's own startup sync) already treats as "nothing to
sync yet" — see footnote 4. Also see individual widget/screen test files for
gesture and provider-scoping fixes made while writing them (e.g.
`SlideToConfirmButton`'s track must be the drag target, not its padded
container — the same lesson `order_status_sheet_test.dart` had already
documented).

---

## 4. cash_collection — done ✅

`flutter test test/features/cash_collection`: 48 unit + widget tests green.
Integration: 4 tests green on device (`cash_collection_flow_test.dart`).

Thin `FilteredPaginationCubit` feature (list + search/date filters + summary
totals) — pagination mechanics themselves are covered once in
`test/commons/cubit/base_pagination_cubit_test.dart`; this feature's tests
focus on what it adds over the base.

### A. Unit
- **Model** (`cash_collection_model_test.dart`) — `CashCollectionData.fromJson`:
  `transactions` list parsed, missing `transactions` → empty list (not null);
  `cash_in_hand`/`cash_collected` passthrough as `dynamic` (server sends
  string or number, both must survive untouched). `CashCollectionModel.fromJson`:
  every field `?.toString()`'d from a full real payload; `order_note` defaults
  to `''` when absent (only field with a non-null fallback); null/missing
  fields don't crash.
- **Repository** (`cash_collection_repository_test.dart`) — mock `ApiClient`:
  endpoint, default offset/limit, every optional filter (search/startDate/endDate)
  sent only when non-empty, `total` int-parsed from the response, `meta`
  carries `cashInHand`/`cashCollected` through from `data`, null `data` block
  → empty list without crashing.
- **Cubit** (`cash_collection_cubit_test.dart`) — bloc_test against
  `FilteredPaginationCubit`: `loadCollections`/`loadMore`/`updateFilters`/
  `clearFilters` forward to the repository with the right params (mirrors the
  `OrderCubit` test shape); `cashInHand`/`cashCollected` getters read off
  `PaginationLoaded.meta` and are `null` outside the loaded state;
  `hasActiveFilters` true for search-only, date-only, and both.

### B. Widget
- `cash_collection_card.dart` — order id (falls back to `id` then `—`),
  formatted date (`transactionDate` falling back to `createdAt`), status text
  capitalized, message truncation (2 lines) with `—` fallback when empty,
  amount with currency symbol prefix and `0` fallback.
- `cash_collection_list.dart` — empty state shown when `collections` is empty;
  otherwise renders one `CashCollectionCard` per item through
  `PaginatedListView` (loading-more indicator, pull-to-refresh call-through).
- `cash_collection_summary_card.dart` — `_fmt` branches (null → `'0'`, empty/
  `'null'` string → `'0'`, parseable string, `num`); shows `'—'` for both
  stats outside `CashCollectionLoaded`; currency symbol from
  `CountrySettingsCubit` prefixed onto both values.
- `cash_collection_app_bar_actions.dart` — date-range button shows an active
  dot + tooltip range only when a date filter is set; clear-filters button
  only rendered when `hasActiveFilters`; both callbacks fire on tap.
- `cash_collection_screen.dart` — initial `loadCollections()` call; loading →
  skeleton; error → `EmptyStateWidget` with retry wired to `loadCollections`;
  loaded → summary card + list; offline → `AppNoInternetFullScreen` replaces
  the body (summary card included) with its own retry; search text debounced
  into `updateFilters` alongside the current dates; date-range picker result
  merged with the current search text; clear-filters resets the search field
  too.

### C. Integration
Real router/screen/cubit/repository, network faked at the Dio adapter.
Primary journey: navigate in → list loads → apply a search/date filter →
list narrows → pull to refresh → clear filters → paginate via `loadMore`.

### Bugs found and fixed
Three "X" icons could render at once in the app bar while searching with an
active filter: the search field's own inline clear, the app bar's
search-cancel button, and `CashCollectionAppBarActions`'s clear-filters
button — the last two read as duplicates of the same action. Added an
`isSearching` flag to `CashCollectionAppBarActions` that hides the
clear-filters button while the search field is open; it reappears once
search is cancelled. Covered by a widget test
(`cash_collection_app_bar_actions_test.dart`).

## 5. earnings — done ✅

`flutter test test/features/earnings`: 16 widget tests green. Integration: 6
tests written (`earnings_flow_test.dart`) — not executed here (no device
attached), verified by `flutter analyze` instead.

Refactored feature: `lib/features/earnings/` has no model, repository, or
cubit of its own any more — `EarningsScreen` instantiates home's
`DashboardCubit` directly and reads `DashboardModel`/`DashboardLoaded.data.data`
the same way `HomeScreen` does. That cubit/model/repository already have full
unit coverage under `2. home` (`dashboard_cubit_test.dart`,
`dashboard_model_test.dart`, `dashboard_repository_test.dart`) — writing a
second copy here would just duplicate those assertions against the same
class, so there is no `test/features/earnings/cubit` or `.../models` dir.
Only the Widget and Integration layers are earnings-specific.

### A. Unit
None — see above. Covered by `2. home`'s `DashboardCubit`/`DashboardModel`/
`DashboardRepository` tests.

### B. Widget
- `earnings_summary_card.dart` — total/today earning formatted to 2 decimals
  with the currency symbol prefix, including the zero case.
- `earnings_stat_card.dart` — value/label render, `onTap` fires, no crash
  when `onTap` is null (root is `Expanded`, so tests wrap it in a `Row`).
- `earnings_skeleton_loader.dart` — shimmer wrapper plus the expected shimmer
  box count (1 summary placeholder + 2 stat-tile rows × 2 boxes = 5), no
  render exception.
- `earnings_quick_access_section.dart` — wallet/cash/salary formatted values
  and `'0.00'` fallback when their model is null; each of the 4 tiles fires
  its own tap callback independently.
- `earnings_screen.dart` — since the screen builds its own `DashboardCubit`
  internally (same reasoning as `order_status_sheet_test.dart`: a mock cubit
  can't be injected), the real cubit/repository run through the
  `ApiClient().httpClientAdapter = FakeApiAdapter(...)` seam instead of a
  mocked `DashboardCubit`. Covers: initial `getDashboard()` fetch + skeleton
  while loading, loaded state rendering the summary card and quick-access
  section with data threaded through correctly from the fixture, error state
  with a working retry, offline swap to `AppNoInternetFullScreen` (with its
  own working retry), a `ConnectivityConnected` reconnect refetching, and a
  `LanguageLoaded.selectedId` change refetching. Pull-to-refresh is driven via
  `RefreshIndicatorState.show()` rather than a manual drag gesture — a
  hand-driven drag was flaky here depending on viewport height (see the
  RefreshIndicator gotcha below), and `show()` exercises the same `onRefresh`
  callback without depending on the content actually overflowing the
  viewport.

### C. Integration (`integration_test/earnings_flow_test.dart`, not run — no device)
Mounted at `RouteNames.earnings` through `AuthTestApp` (keeps the test inside
this feature's boundary per the auth-suite gotcha). Dashboard loads and
renders the summary + quick-access sections with fixture data
(`home_fixtures.dart`'s `dashboardResponseFixture`, reused rather than
duplicated); pull-to-refresh refetches; tapping each of the 4 quick-access
tiles is asserted by the destination screen actually mounting
(`WalletScreen`/`SalaryScreen`/`CashCollectionScreen`/`SettlementHistoryScreen`)
— navigation only, not those screens' own data/behavior, which belongs to
their own feature's integration test.

### Bugs / inconsistencies found (not fixed — cosmetic, left for product call)
`EarningsQuickAccessSection`'s settlement-history tile interpolates
`settlementHistory` directly (`'$currencySymbol$settlementHistory'`) instead
of `.toStringAsFixed(2)` like the other three tiles (wallet/cash/salary).
Since the value is a `double`, this renders `"₹298657.15"` acceptably when the
fractional part happens to be 2 digits, but `"₹0.0"` (not `"₹0.00"`) for a
whole number — inconsistent with its siblings on the same row. Documented by
`earnings_quick_access_section_test.dart` rather than silently normalized.

## 6. wallet — done ✅

`flutter test test/features/wallet`: 74 unit + widget tests green. Integration:
6/6 tests green on device (`wallet_flow_test.dart`).

Thin `FilteredPaginationCubit` feature (list + status filter + wallet balance
in `meta`, page-count `hasMore`) plus a separate `BaseAsyncCubit` for the
withdrawal-submit flow — pagination mechanics themselves are covered once in
`test/commons/cubit/base_pagination_cubit_test.dart`; `WalletCubit`'s tests
focus on what it adds over the base, same approach `cash_collection` took.

### A. Unit
- **Model** (`withdrawal_request_model_test.dart`) — `Data.fromJson`:
  `withdraw_requests` list parsed, missing key stays `null` (not an empty
  list, unlike cash_collection's transactions), `balance` passthrough as a
  string via `?.toString()`, `toJson` round trip. `WithdrawRequests.fromJson`:
  every field `?.toString()`'d from a full real transaction, `remark`/
  `receipt_image_url` survive as real `null` when absent and parse correctly
  when present (the approved-row fixture entry), null/missing fields don't
  crash, numeric id/amount stringified, `toJson` round trip.
- **Repository** (`wallet_repository_test.dart`) — mock `ApiClient`:
  `getWithdrawalRequests` — endpoint, default offset/limit, `search`/`status`
  sent only when non-empty (including the falsy-looking `status: '0'` for
  "pending", which must still be sent), `meta` carries the wallet balance
  through as a parsed `double`, a null `data` block returns an empty list and
  `0.0` balance without crashing. `addWithdrawalRequest` — `amount` always
  sent, `message` sent only when non-empty.
- **Cubits** (`wallet_cubit_test.dart`, `withdrawal_cubit_test.dart`) —
  bloc_test against `WalletCubit` (`FilteredPaginationCubit`): the
  backward-compatible aliases (`loadWallet`/`search`/`filterByStatus`/
  `loadMore`/`fetchWalletData`) all forward to the repository with the right
  params and preserve the other filter when only one changes; the `balance`
  getter reads off `PaginationLoaded.meta` and is `0.0` outside the loaded
  state; the page-count `hasMore` override (`data.length >= pageLimit`, not
  total-based) — verified both that a full page keeps `hasMore` true and that
  `loadMore` is consequently a no-op on a short page, since the base cubit
  guards `fetchMore` on `hasMore`; API error surfaced as the loaded error
  message. `WithdrawalCubit.submit` — `[Loading, Loaded]` on success with
  amount/message forwarded, `[Loading, Error]` with the API message on
  failure, `reset()` back to `Initial`.

### B. Widget
- `wallet_balance_card.dart` — balance formatted to a whole number
  (`toStringAsFixed(0)`) prefixed with the currency symbol from
  `CountrySettingsCubit`, including the zero case; `onWithdraw` fires on tap.
- `wallet_transaction_item.dart` — request id line, currency-prefixed amount
  with a `'0'` fallback when both amount and currency are null, every
  `WithdrawalStatus` → status-text mapping (pending/approved/rejected/
  unknown-falls-back-to-`all`); tapping a row with a message or remark opens
  the detail sheet, a row with neither is not tappable (`InkWell.onTap` is
  `null`, not a no-op handler).
- `wallet_transaction_detail_sheet.dart` — `hasWalletTransactionDetail`'s
  `_clean` normalization (null/empty/whitespace/the literal `"null"` string
  all count as absent, case-insensitively); the sheet shows only the
  sections that have content, independently for message and remark.
- `wallet_loaded_body.dart` — balance card always rendered; empty state when
  the transaction list is empty; one `WalletTransactionItem` per entry
  otherwise; a `LoadingWidget` footer while `hasMore` is true; pull-to-refresh
  calls `WalletCubit.loadWallet()`.
- `wallet_filter_sheet.dart` — all four `WithdrawalStatus` options rendered;
  selecting one calls `WalletCubit.filterByStatus` with that status's raw
  value and closes the sheet (verified by generic type — `RadioListTile`'s
  bare type argument defaults to `<dynamic>` under `find.byType` and silently
  matches nothing, so the finder must pin `<WithdrawalStatus>` explicitly).
- `withdrawal_sheet.dart` — like `order_status_sheet_test.dart`, the sheet
  builds its own `WithdrawalCubit` internally, so the real cubit/repository
  run through the `ApiClient().httpClientAdapter = FakeApiAdapter(...)` seam
  rather than a mocked cubit (`WalletCubit`/`CountrySettingsCubit` are still
  mocked, since those are read via `context.read` from outside). Covers: an
  empty amount never submits; a valid submit sends the trimmed amount and
  message; success reloads the wallet, pops the sheet, and shows the success
  snackbar; a server rejection shows its message and leaves the sheet open
  (amount field content, submit button) without reloading the wallet;
  cancel closes without submitting.
- `wallet_screen.dart` — initial `loadWallet()` call; loading → skeleton;
  error → `EmptyStateWidget` with retry wired to `loadWallet`; loaded →
  balance card + transaction list; offline → `AppNoInternetFullScreen`
  replaces the body (balance card included) with its own retry; a
  `ConnectivityConnected` reconnect refetches; search text debounced into
  `WalletCubit.search`; tapping the filter icon (identified by its
  `AppSvgIcon` asset path, since the app bar's search-start button is also an
  unkeyed-by-tooltip `IconButton`) opens the status filter sheet.

### C. Integration (`integration_test/wallet_flow_test.dart`, 6/6 green on device)
Mirrors `cash_collection_flow_test.dart`'s structure — real router, real
screen, real cubit and repository, network faked at the `ApiClient` adapter
seam, mounted directly at `RouteNames.wallet` (its own route-level
`BlocProvider<WalletCubit>`, same as cash_collection) to keep the test inside
this feature's boundary. Fixtures duplicated as Dart constants in
`integration_test/helpers/wallet_fixtures.dart` per the "fixtures must be Dart
constants, not file reads" gotcha. Covers: balance and transaction list load
on entry; applying the "Pending" status filter narrows the list and sends
`status=0`; pull-to-refresh refetches; tapping a transaction with a message
opens its detail sheet; a successful withdrawal reloads the wallet and shows
the success message; a rejected withdrawal surfaces the server's error
message and leaves the sheet open.

Two bugs surfaced only on-device (never in the headless widget tests, which
run at a fixed surface size and don't drive real IME timing): the test file
originally matched button/option labels with `find.text(LanguageLabelKeys.*)`
— the raw translation *key* (`"pending"`, `"withdraw"`, `"submit"`) — instead
of the actual rendered string (`"Pending"`, `"Withdraw"`, `"Submit"`).
Headless widget tests never catch this because translations aren't loaded
under `flutter test` there, so `context.translate` just echoes the key back —
on-device the real asset loads and the literal key no longer matches anything
onscreen. Also, `find.text('Pending')` alone was ambiguous: a transaction row
can itself carry a "Pending" status label, so the filter sheet's own option
needed `.last`.

### Bugs found
`_WithdrawalSheet`'s form (amount/message fields + buttons) had no scroll
container. Tapping Submit closes the keyboard; during that close animation the
sheet's `Flexible`-bound height transiently shrinks, and the unscrollable
`Column` overflowed by 190px — reproduced only on a real device (the IME
close animation doesn't run under `flutter test`'s fixed-frame pumping) and
only on the path that keeps the sheet mounted afterward (rejected withdrawal;
a successful one pops the sheet before the transient frame renders). Fixed by
wrapping the sheet's `SlideAnimationList` in a `SingleChildScrollView`.

None otherwise. `WalletCubit`'s page-count `hasMore` (mirroring `CashCollectionCubit`)
means a `loadMore()`/`fetchWalletData(isLoadMore: true)` call is silently a
no-op whenever the most recent page came back shorter than
`AppConfig.pageLimit`, even if more pages exist server-side going by `total`
— this is existing, intentional behavior per the cubit's own doc comment
("Original behaviour paginates by page-count (limit) rather than total"), not
a defect, but it did require the cubit tests to stub a full-size page before
exercising `loadMore` (a short page never reaches the repository a second
time).

## 7. salary — done ✅

`flutter test test/features/salary`: 38 unit + widget tests green. Integration:
4/4 tests green on device (`salary_flow_test.dart`).

The simplest `*PaginationCubit` list feature yet — a plain
`BasePaginationCubit<SalaryModel>` with no search/date/status filters at all
(unlike `cash_collection`/`wallet`, which extend `FilteredPaginationCubit`).
Pagination mechanics themselves are covered once in
`test/commons/cubit/base_pagination_cubit_test.dart`; `SalaryCubit`'s own
tests focus on just the fetcher wiring and the `loadSalaries`/`loadMore`
aliases.

### A. Unit
- **Model** (`salary_model_test.dart`) — `SalaryModel.fromJson`: every field
  parsed from a full real payment entry; `note`/`paidOn` default to `''`
  (not `null`) both when the key is missing and when it is explicitly
  `null`; `amount` defaults to `0.0` via `toSafeDouble` (not `null` — unlike
  `id`/`currency`, which stay `null`); `id`/`amount` lenient-parse numeric
  strings; `toJson` round trip.
- **Repository** (`salary_repository_test.dart`) — mock `ApiClient`: hits
  `ApiEndpoints.salary`, default offset/limit sent, custom offset/limit
  forwarded, every field parses off the fixture through
  `SalaryModel.fromJson`, a null or missing `data` key both return an empty
  list without crashing (the generic `PaginatedResponse.fromJson` reads
  `data` as a flat list here — no nested wrapper object like
  `cash_collection`'s `data.transactions`).
- **Cubit** (`salary_cubit_test.dart`) — bloc_test against `SalaryCubit`:
  `loadSalaries` fetches offset 0; `loadMore` fetches from the offset
  already held; the API's error message surfaces on failure.

### B. Widget
- `salary_card.dart` — id falls back to `—` when null (shown inline as
  `"id  #—"`, translation key untranslated under `flutter test`); `paidOn`
  falls back to `—` only for a real `null` (its `fromJson` default is `''`,
  a distinct branch from the card's own `??` fallback, so the model was
  built directly with `paidOn: null` to reach it); amount falls back to `0`
  when null; currency prefixed onto the amount; tap opens the detail sheet
  only when `hasSalaryDetail(note)` is true — a card with no note, or with
  the literal `"null"` string, has `InkWell.onTap == null` (not a no-op
  handler).
- `salary_detail_sheet.dart` — `hasSalaryDetail` mirrors wallet's
  `hasWalletTransactionDetail`/`_clean` exactly (null/empty/whitespace/the
  literal `"null"` string, case-insensitive, all count as absent), minus
  the second remark field wallet has — salary only carries `note`. The sheet
  shows the `transactionDetail` title, the `message` label, and the trimmed
  note text.
- `salary_list.dart` — empty state shown when `salaries` is empty;
  otherwise one `SalaryCard` per item through `PaginatedListView`
  (loading-more footer, pull-to-refresh call-through) — same shape as
  `cash_collection_list_test.dart`/`wallet_loaded_body_test.dart`.
- `salary_screen.dart` — initial `loadSalaries()` call; loading → skeleton;
  error → `EmptyStateWidget` with retry wired to `loadSalaries`; loaded →
  `SalaryList`; offline → `AppNoInternetFullScreen` (with its own working
  retry) replaces the body while the app bar stays; a `ConnectivityConnected`
  reconnect refetches. No search/filter UI to test, since the cubit has none.

### C. Integration (`integration_test/salary_flow_test.dart`, 4/4 green on device)
Mirrors `cash_collection_flow_test.dart`'s structure — real router, real
screen, real cubit and repository, network faked at the `ApiClient` adapter
seam, mounted directly at `RouteNames.salary` (its own route-level
`BlocProvider<SalaryCubit>`) to keep the test inside this feature's
boundary. Fixtures duplicated as Dart constants in
`integration_test/helpers/salary_fixtures.dart` per the "fixtures must be
Dart constants, not file reads" gotcha, split into two pages (3 + 2, total
5) to cover both the initial load and `loadMore`. Covers: the first page
loads on entry; pull-to-refresh refetches; scrolling near the bottom pages
in the second batch (asserted on the follow-up request's non-zero offset,
per the `ListView.builder` mounted-items gotcha); tapping an entry with a
note (`id 701`) opens the detail sheet and shows its text.

### Bugs found
None. Unlike `cash_collection`/`wallet`, this feature has no date-formatting
dependency on `SettingsHiveBox` (`paidOn` renders as the raw server string),
so its widget tests don't need `HiveTestHelper` at all — one less moving
part than its two template features.

## 8. settlement_history — done ✅

`flutter test test/features/settlement_history`: 98 unit + widget tests green.
Integration: 7/7 tests green on device (`SM M066B`, API 36, `settlement_history_flow_test.dart`).

The richest `*PaginationCubit` list feature so far — a
`FilteredPaginationCubit` with **four** filters (search, entry type, and a
start/end date range), one more than `cash_collection`/`wallet` carry.
Pagination mechanics themselves are covered once in
`test/commons/cubit/base_pagination_cubit_test.dart`; `SettlementHistoryCubit`'s
own tests focus on the fetcher wiring, how the four filters merge, and the
`hasActiveFilters` getter the screen's badge reads.

### A. Unit (41)
- **Enums** (`settlement_direction_test.dart`, `settlement_entry_type_test.dart`)
  — `SettlementDirection.fromValue` is deliberately asymmetric: only the
  literal `"credit"` (case-insensitively) is a credit and *everything* else —
  null, `''`, `' credit'`, an unknown server value — falls back to debit, which
  is what drives the card's `+`/`-` sign and accent colour.
  `SettlementEntryType`'s `value` strings are the wire format for the api's
  `entry_type` filter, so each is asserted literally rather than round-tripped
  through the enum (a typo would silently send a filter the backend ignores);
  `fromValue` round trips every known value, maps `''` to `all` (the "no
  filter" case), and falls back to `all` on anything unknown.
- **Model** (`settlement_history_model_test.dart`) —
  `SettlementHistoryResponse.fromJson`: envelope + every entry off the real
  payload; a null `data` key leaves `data` **null** (not an empty list, unlike
  the generic `PaginatedResponse` — this model has its own hand-rolled
  parser); a missing `message` becomes `''`; `status`/`total` lenient-parse
  numeric strings and stay null on non-numeric input.
  `SettlementHistoryData.fromJson`: every field off a full credit entry; a
  numeric `id` coerces to `String`; amounts parse from both strings and
  numbers; `amount`/`opening_balance`/`closing_balance` default to `0.0` via
  `toSafeDouble` whether the key is missing or explicitly null — never null,
  unlike every string field, which stays null; a non-numeric amount falls back
  to `0.0` rather than throwing; a null `message` stays null rather than
  becoming the string `"null"`. `toJson` round trips back to the api key names
  (value-preserving, not byte-identical — numerics normalise to double on the
  way through) and emits all 13 keys even for an empty entry.
- **Repository** (`settlement_history_repository_test.dart`) — mock
  `ApiClient`: hits `ApiEndpoints.settlementHistory`, default offset/limit
  sent, custom offset/limit forwarded, all four filters sent when set, and each
  omitted entirely when null or empty — including the `all` entry type, whose
  wire value is `''` and so sends no `entry_type` at all. A null *or* missing
  `data` block returns a null list without crashing.
- **Cubit** (`settlement_history_cubit_test.dart`) — `loadTransfers` fetches
  offset 0 with empty filters; a null `data` block loads as an empty page
  rather than an error (the fetcher's `result.data ?? []`); `updateFilters`
  applies all four and reloads from offset 0; **the filter asymmetry is pinned
  down explicitly** — an omitted `search`/`entryType` keeps its current value,
  while an omitted `startDate`/`endDate` is *cleared*, so callers must re-pass
  dates to keep them (which is exactly what the screen's `_onSearchChanged`
  does); `loadMore` pages from the held offset with the active filters still
  applied; `clearFilters` resets all four; `hasActiveFilters` is false when
  fresh, true for any single filter on its own, and false again for the `all`
  entry type; the API's error message surfaces on failure.

### B. Widget (57)
- `settlement_history_card.dart` (11) — id line, signed amount and capitalised
  type for a credit; a debit renders `-`; an *unknown* type also renders `-`
  (the `fromValue` fallback, seen through the UI); `id`/`type` fall back to
  `—` when null; created_at that can't be parsed passes through as-is and a
  null one renders empty rather than the word `"null"`; tapping opens the
  detail sheet, and — unlike `SalaryCard` — `InkWell.onTap` is **never** null,
  because the sheet always has balances to show. Date assertions stay off the
  formatted output on purpose (it is timezone-dependent through
  `AppDateFormatter`), matching `wallet_transaction_item_test.dart`.
- `settlement_history_detail_sheet.dart` (10) — title, type, both balances and
  the message off a full entry; the currency symbol prefixes both balances;
  balances still render (`₹0.0`) on an entry with none — the reason the card
  needs no "is there detail?" guard. Both conditional blocks are covered on
  every branch: the settlement-type block hides for absent/whitespace-only
  `entry_type` and shows the trimmed value when padded; the message block
  hides for absent/whitespace-only/the literal `"null"` string
  (case-insensitive) and shows the trimmed message otherwise.
- `settlement_history_list.dart` (4) — note the class is named `TransferList`,
  not `SettlementHistoryList`. Empty state when `transfers` is empty;
  otherwise one `SettlementHistoryCard` per item through `PaginatedListView`
  (loading-more footer, pull-to-refresh call-through) — same shape as
  `cash_collection_list_test.dart`/`salary_list_test.dart`.
- `settlement_history_filter_sheet.dart` (11) — date-range field plus all six
  entry-type radios; the sheet preselects the cubit's current entry type and
  defaults to `All`; the cubit's dates show in the field. Apply sends the
  selected type's wire value with the dates, re-sends the current filters
  unchanged when nothing is touched, sends `''` for `All`, and sends both dates
  null after clearing the range in-sheet. Clear only closes the sheet when
  nothing is filtered (no `clearFilters`, no `onClearSearch`), clears both the
  cubit filters and the search box when something is, and never calls
  `updateFilters` — clearing is not an apply.
- `settlement_history_screen.dart` (21) — initial `loadTransfers()`; app-bar
  title; loading → skeleton; initial → app bar only; error → `EmptyStateWidget`
  with the API message and a working retry; loaded → `TransferList`; offline →
  `AppNoInternetFullScreen` (with its own working retry) replaces the body
  while the app bar stays; a `ConnectivityConnected` reconnect refetches.
  Search: typing debounces into `updateFilters` **re-passing the cubit's
  current dates** (the asymmetry above, seen from the screen side), trims the
  query, collapses rapid typing to one call, resets the query on cancel when
  text was present and sends nothing when it wasn't, and hides the filter icon
  while searching. Filters: the icon opens the sheet, the active-filter dot
  appears only when `hasActiveFilters`, applying a type forwards it, and
  clearing from the sheet also empties the search box.

### C. Integration (`integration_test/settlement_history_flow_test.dart`, 7/7 green on device)
Mirrors `salary_flow_test.dart`'s structure — real router, real screen, real
cubit and repository, network faked at the `ApiClient` adapter seam, mounted
directly at `RouteNames.settlementHistory` (its own route-level
`BlocProvider<SettlementHistoryCubit>`) rather than through the earnings screen
that links to it, to keep the test inside this feature's boundary. Fixtures
duplicated as Dart constants in
`integration_test/helpers/settlement_history_fixtures.dart` per the "fixtures
must be Dart constants, not file reads" gotcha, split into two pages (3 + 2,
total 5) plus a single-entry filtered page, so one adapter covers the initial
load, `loadMore`, and both filter paths — it branches on whether the request
carries a `search`/`entry_type` value. Covers: the first page loads on entry
with no filters sent; pull-to-refresh refetches; scrolling near the bottom
pages in the second batch (asserted on the follow-up request's non-zero offset,
per the `ListView.builder` mounted-items gotcha); tapping an entry opens the
detail sheet with its message and both balances; searching refetches with the
query and renders the filtered page; applying an entry-type filter sends
`entry_type=withdrawal` and lights the badge; clearing from the sheet reloads
the unfiltered page with no `entry_type` sent.

Fixture created_at values are all `12:00:00` on purpose — `AppDateFormatter`
reinterprets the api's wall-clock strings as UTC and converts to device local
time, so a midday timestamp keeps the same calendar date on any device
timezone the test might run under.

### Bugs found
- **The filter `IconButton` has no `tooltip`** (`settlement_history_screen.dart:113`),
  unlike the identical filter buttons on `cash_collection_screen.dart:215` and
  `orders_screen.dart:421`, which both pass
  `tooltip: context.translate(LanguageLabelKeys.filters)`. It is a
  screen-reader/long-press affordance gap rather than a visible defect, so it
  is left as a product call — the tests locate the button through the SVG asset
  it renders instead of `find.byTooltip`. Worth aligning with its two siblings.

Not a bug, but worth knowing before reading assertions: the card's
`item.amount ?? 0` fallback prints as `"0.0"`, not `"0"` — `??` against a
`double?` types the right operand as a double, so the literal `0` is coerced
before interpolation. `SalaryCard`'s equivalent line prints `"0"` because its
model's amount is nullable in a different position.

## 9. notifications — done ✅

`flutter test test/features/notifications`: 39 unit + widget tests green
(22 unit, 17 widget). Integration: 4 tests written
(`notifications_flow_test.dart`) — not executed here (no device attached),
verified by `flutter analyze` instead (zero issues).

`lib/features/notifications/`: model (`AppNotificationSettings` → list of
`AppNotificationSettingsData` category → list of `Events` → `Channels`
mail/push/sms bools, any of which may be null = channel n/a for that event),
`NotificationRepository` (GET + POST both against
`ApiEndpoints.notificationPreferences`), two `BaseAsyncCubit`s
(`NotificationCubit` load, `NotificationSaveCubit` save — kept separate so a
save-in-flight spinner doesn't fight the list's own loading state),
`NotificationScreen` (3-tab email/mobile/sms view over the same category
list, `_channelValue` picks the field per tab), `NotificationSaveBar`
(bottom save button, collects every category's events into one flat list),
`NotificationSettingsSkeletonLoader`. `NotificationScreen` builds both
cubits itself via an internal `MultiBlocProvider` (only `ConnectivityCubit`
is read from outside) — same shape as `earnings_screen_test.dart`/
`withdrawal_sheet_test.dart`, so its widget test runs the real cubits and
repository through the `ApiClient().httpClientAdapter = FakeApiAdapter(...)`
seam rather than a mocked cubit.

### A. Unit (22)
- **Model** (`notification_settings_model_test.dart`, 15) — `fromJson`/
  `toJson` round trip at all 4 levels; `Channels.fromJson` per-field null vs
  bool-lenient-parse (`toSafeBoolOrNull`), including an unparsable value
  falling back to null; `Channels.toJson` omits a null channel field instead
  of writing `null`; `Events.fromJson` missing `channels` stays null, not a
  default `Channels()`; `AppNotificationSettingsData` missing `events` stays
  null, not `[]`; `AppNotificationSettings` missing/null `data` stays null
  (not `[]`, unlike cash_collection's `transactions`); `status`/`total`
  lenient int parse from a quoted numeric string.
- **Repository** (`notification_repository_test.dart`, 3) — mock
  `ApiClient`: `getNotificationSettings` hits
  `ApiEndpoints.notificationPreferences` via GET and parses the response;
  `saveNotificationSettings` POSTs the same endpoint with `preferences`
  built from `key`/`channels.toJson()` per event, and the null `sms` field
  is confirmed omitted from the sent body, not sent as `null`.
- **Cubits** (`notification_cubit_test.dart`, `notification_save_cubit_test.dart`,
  4) — bloc_test against `BaseAsyncCubit`: `[Loading, Loaded]` on success,
  `[Loading, Error]` on `ApiException`, for each of the two cubits
  independently; `NotificationSaveCubit` additionally verifies the exact
  `preferences` list instance is forwarded to the repository untouched.

### B. Widget (17)
- `notification_settings_skeleton_loader.dart` (2) — shimmer wrapper,
  default `itemCount` 6 tiles rendered (2 `ShimmerBox`es each — label +
  switch pill), custom `itemCount` respected, `NeverScrollableScrollPhysics`.
- `notification_save_bar.dart` (5) — hidden (`SizedBox.shrink`) when
  `NotificationCubit` isn't `Loaded`, and when loaded with an empty category
  list; visible when loaded with categories; tap flattens every category's
  events into one list (in category order) and calls
  `NotificationSaveCubit.saveNotificationSettings` with it; button shows a
  spinner (`LoadingWidget`) while `NotificationSaveCubit` is loading.
- `notification_screen.dart` (10, via `FakeApiAdapter` — real cubits, see
  above) — initial fetch and skeleton on first build; error state with a
  working retry; loaded with an empty category list shows the empty state;
  loaded with data renders the 3-tab `TabBarView`; the sms tab hides a
  category whose events are all `null` for sms, header included (`Payments`/
  `Promotions` in the fixture both vanish there, only `Order Updates`
  survives); toggling a switch mutates `Events.channels` in place with no
  cubit call — verified by toggling, then tapping Save and inspecting what
  actually got POSTed, since the mutation itself triggers no rebuild-visible
  side effect; a successful save shows a snackbar and refetches the list; a
  rejected save surfaces the server message and does not refetch; offline
  replaces the body with `AppNoInternetFullScreen` and hides both the tab
  bar and the save bar; a `ConnectivityConnected` reconnect refetches.

### C. Integration (`integration_test/notifications_flow_test.dart`, written, not run — no device)
Mounted directly at `RouteNames.notifications` through `AuthTestApp`. Unlike
`cash_collection`/`wallet`/`salary`, no extra `BlocProvider` is added at the
test app level — `NotificationScreen` already builds its own cubits, so the
route mount alone is enough to exercise the real cubits/repository against
the faked adapter. Fixtures duplicated as Dart constants in
`integration_test/helpers/notifications_fixtures.dart` per the "fixtures
must be Dart constants, not file reads" gotcha. Covers: settings load and
render across all 3 tabs, including the sms tab's category-hiding behavior;
toggling a switch then tapping Save sends the mutated preference and shows
the success snackbar; a save rejection surfaces the server error and leaves
the toggle as the user set it (no refetch overwrites it); pull-to-refresh
refetches.

### Bugs found
None. The screen, save bar, and skeleton loader all matched their documented
behavior on the first pass; the only test-side surprise was in
`notification_screen_test.dart`'s toggle-then-save assertion — a successful
save triggers an automatic refetch, so the fake adapter's *last* recorded
request is that follow-up GET (body-less), not the POST being asserted on.
Picking the request out by `r.data is Map` instead of by recency fixed it;
noted here in case another feature's "inspect what got sent" assertion hits
the same shape (save-then-refetch cubits all share this listener pattern —
see `wallet`/`cash_collection`).

## 10. chat — done ✅

`flutter test test/features/chat`: 197 unit + widget tests green. Integration:
7/7 tests green on a real device (`chat_flow_test.dart`, Android `SM M066B`,
API 36, over wireless adb).

`lib/features/chat/`: models (`ChatConversation`, `ChatMessage`/
`ChatAttachment`), `ChatRepository` (start admin/order conversation, REST
message history + multipart send, broadcast auth, attachment download),
two cubits (`ChatCubit` for a single room's connect/send/receive lifecycle,
`ChatConversationsCubit` for the inbox list), `ChatSocketService` (realtime
transport — see below), `ChatConversationResolver` (turns a
`ChatScreenArgs` into a REST-backed `conversationId`), `ChatScreen` and its
widgets (bubble, date divider, input bar with attach menu/emoji picker,
skeleton loader, and the per-attachment-type renderers this pass added
tests for). Models/repository/cubits/`ChatScreen`/`ChatBubble`/
`ChatDateDivider`/`ChatInputBar`/`ChatSkeletonLoader`/
`ChatConversationResolver` were already built and green before this pass
(141 tests); this pass added the socket service and the seven
per-attachment-type widgets that had no test file yet (56 tests).

### A. Unit
- **Models, repository, cubits, `ChatConversationResolver`** — already
  covered (pre-existing, not detailed further here since nothing changed).
- **`ChatSocketService`** (`chat_socket_service_test.dart`, 16, new this
  pass) — driven against a real local WebSocket server, same approach as
  `2. home`'s `MaintenanceSocketService` suite, rather than mocking the
  socket. The service speaks two protocols: a legacy raw-JSON room socket
  (self-hosted server) and the real Pusher/Reverb private-channel protocol
  (connect → `pusher:connection_established` → `pusher:subscribe` with
  `ChatRepository.getBroadcastAuth` → `pusher_internal:subscription_succeeded`).
  Covered: the subscribe frame is keyed by the given `channelId`, falling
  back to `roomId` when none is given; the subscribe frame's `auth` field
  comes from `ChatRepository.getBroadcastAuth`; ping/pong keepalive;
  subscription success reaches `connected`; a broadcast on the subscribed
  channel is parsed into a `ChatMessage`, one on a different channel is
  ignored; a `pusher_internal:subscription_error` frame and a silently
  un-acked subscribe (the 10s ack-timeout timer) both fall back to
  `disconnected` and schedule a reconnect; a `getBroadcastAuth` failure and
  a malformed auth response (no `auth` field) both do the same; the server
  dropping the connection triggers the backed-off reconnect
  (`reconnectAttempts * 2s`); `disconnect()` stops any pending reconnect;
  a fresh `connect()` after `disconnect()` resets the retry budget (the
  comment in `ChatSocketService.connect` calls this out explicitly — without
  it, a post-disconnect reconnect only gets one attempt). `sendMessage`'s
  no-op while the real protocol is active is covered; its legacy send path,
  and the legacy protocol's connect/reconnect end to end, are not — see
  "Not covered" below. `_onData`'s frame-shape parsing (an `event` key routes
  to the Pusher handler, its absence to the legacy raw-JSON parser) is
  shape-based rather than mode-based, so the legacy message shape is
  exercised over the same local real-protocol connection.

### B. Widget
- **Already covered (pre-existing)**: `chat_bubble.dart` (13),
  `chat_date_divider.dart` (5), `chat_input_bar.dart` (8, up to but not
  through the platform-channel record/pick calls), `chat_skeleton_loader.dart`
  (4).
- **New this pass** (7 files, 40 tests):
  - `attachment_preview.dart` (9) — label/sublabel per attachment kind
    (image/audio/file), file-name fallback to the generic label, tapping
    close fires `onRemove`, a local image path renders `Image.file` while a
    remote-only one renders the icon tile, audio/file thumbnails pick the
    right icon.
  - `chat_attach_menu.dart` (4) — the sheet shows all three options with
    their icons and the attachment title; each option fires its own
    callback independently.
  - `chat_audio_attachment.dart` (6) — `audioplayers`' channels aren't
    mocked (same silent-failure reliance `chat_bubble_test.dart` already
    made for this widget), so coverage stays to what's reachable without a
    real player: initial play icon + "00:00" + zero-progress bar render, the
    `isMe` colour branch (onPrimary vs primary), and that tapping play
    doesn't throw.
  - `chat_emoji_picker.dart` (2) — renders `EmojiPicker` in a 280px box wired
    to the given controller. `EmojiPicker.initState` reads its recent-emoji
    cache off `SharedPreferences` via a `Future(() async {...})` (scheduled
    through `Timer.run`); needed both `SharedPreferences.setMockInitialValues({})`
    and two duration-bearing `pump()`s to drain it before the pending-timer
    invariant check at test end — see "Gotchas" below.
  - `chat_file_attachment.dart` (8) — file name/generic-label fallback,
    video vs non-video icon, tapping a local file opens it directly with no
    cubit involved, tapping a remote-only one downloads through
    `ChatCubit.downloadAttachment` (spinner shown meanwhile) then opens the
    saved path, a download failure shows the "could not download" snackbar
    and resets the spinner, no source on the attachment is a no-op, and a
    second tap mid-download doesn't fire a second download. Faked
    `OpenFilePlatform`/`PathProviderPlatform` instead of hitting real
    platform channels.
  - `chat_image_attachment.dart` (7) — local path renders `Image.file`,
    remote-only renders `AppNetworkImage`, neither renders the broken-image
    icon (including a local path that was never actually written to disk,
    which `ChatAttachment.hasLocal`'s `existsSync()` check correctly treats
    as absent), tapping pushes `ChatFullScreenImage`, and that screen's own
    two source branches (network view / broken-image fallback).
  - `chat_status_icon.dart` (4) — sending shows a sized spinner (not an svg
    icon), sent shows the read-check icon at `onPrimary` 0.7 alpha, failed
    shows the info-circle icon in the error colour, and every `MessageStatus`
    renders exactly one indicator.

### C. Integration (`integration_test/chat_flow_test.dart`, 7/7 green on device)
Run for real on a wirelessly connected Android device. One test-side bug
surfaced only there: "typing a message sends it over REST and adds it to the
thread" asserted `find.byType(ChatBubble), findsNWidgets(5)` after sending —
on the real device's viewport the `ListView.builder` only keeps on-screen
bubbles mounted (the same gotcha `wallet`/`salary`/`settlement_history`
integration suites already hit), so only 3 of the 5 were actually built.
Fixed by asserting `findsAtLeastNWidgets(1)` plus the new message's text,
instead of the total mounted count.

### Not covered
`ChatSocketService`'s legacy self-hosted branch (`_useRealProtocol == false`)
only ever resolves to `AppConfig.socketBaseUrl` — a hardcoded production
`wss://` URL with no test seam to redirect it to a local server, unlike the
real-protocol branch, which resolves through `SocketUrlResolver` off
Hive-cached settings and so can be pointed at 127.0.0.1. That leaves the
legacy branch's own connect/disconnect/reconnect-backoff and its
`sendMessage` send path untested here — driving them would mean either
hitting the real production endpoint from a test run or adding a config seam
to the service, neither of which this pass did. Everything *shape*-dependent
rather than *branch*-dependent (the legacy raw-JSON message parser) is still
covered, since `_onData` dispatches on the frame's own shape regardless of
which protocol connected the socket.

### Bugs found
None. `ChatSocketService` and all seven newly-tested widgets matched their
documented behavior on the first pass.

### Gotchas this suite added
- **`EmojiPicker`'s `initState` schedules a real `Timer` that the fake test
  clock doesn't drain with a zero-duration `pump()`.** It reads its
  recently-used cache via `Future(() async {...})`, and `Future()`'s
  constructor schedules through `Timer.run` — under `flutter test`'s fake
  clock that leaves a "Timer is still pending" invariant failure at test end
  unless the test also calls `SharedPreferences.setMockInitialValues({})`
  and pumps with an actual duration (`pump(Duration(milliseconds: 50))`, not
  `pump()`) at least twice.
- **`open_file`/`path_provider` are testable through their platform
  interfaces without a real device**, same pattern as this repo's Firebase
  faking: set `OpenFilePlatform.platform`/`PathProviderPlatform.instance` to
  a fake subclass in `setUp` rather than trying to mock the method channel
  directly.

## 12. main / splash — unit + widget done ✅, integration written 🟡

`flutter test test/features/main test/features/splash`: 67 unit + widget tests
green (26 main, 41 splash). Integration: 9 tests written
(`splash_flow_test.dart` 5, `main_flow_test.dart` 4) — not executed here (see
footnote 2), verified by `flutter analyze` instead (zero issues).

Two small features tested together because they are the app's entry and its
shell: `SplashScreen` decides where the app opens, `MainScreen` is what it
opens into. Neither has a repository or a model worth the name — `NavCubit`
is one int, `BottomNavItem` is a value holder — so the Unit layer here is
thin by nature and most of the behavior lives in the Widget layer.

### A. Unit (7)
- **`NavCubit`** (`nav_cubit_test.dart`, 5) — starts on tab 0; `changeTab`
  emits the selected index; a run of switches emits in order; and the
  non-obvious one: `NavState` has no value equality, so re-selecting the tab
  already showing still emits (including `changeTab(0)` from the initial
  state). `MainScreen`'s back gesture depends on that rebuild landing.
- **`BottomNavItem`** (`bottom_navigation_test.dart`, 2) — label and both icon
  paths held as given; both icon paths genuinely optional, which is the branch
  `BottomNavBar._buildNavIcon` falls back on.
- No repository or model parsing exists in either feature. `SplashScreen`'s
  three cubits (`SettingsCubit`/`LanguageCubit`/`LocalizationCubit`) are
  app-wide, not splash's own, and belong to `lib/commons` and
  `lib/core/localization`.

### B. Widget (60)
- `bottom_navigation.dart` (10) — one tappable cell per item with its label;
  active vs inactive icon variant (read off the `ValueKey('<path>-active')`
  the widget sets, since the SVGs are indistinguishable to a finder); tap
  reports the right index, including a tap on the already-active tab; the
  whole cell hit-tests (`behavior: opaque`), not just the label; a null *or*
  empty icon path renders no icon; the active label is `w600` against `w500`;
  and the indicator's position/width maths (`screenWidth / items * index`
  offsets) with the indicator moving when the tab changes.
- `ultra_painter.dart` (8) — driven against a recording `Canvas` rather than a
  pumped widget, which is the only way to read the three arcs back: exactly
  three drawn, all inset by the 4px padding and scaling with the canvas; the
  base ring is a full circle at alpha 0.06; the trailing arc starts at 12
  o'clock, sweeps 1.3π, alpha 0.15, round cap; the bright head starts exactly
  where the trailing arc ends and sweeps 0.5π at full alpha; no arc uses a
  center wedge; `shouldRepaint` always true.
- `ultra_loader.dart` (6) — paints through `UltraPainter` at the default 55px
  and at a custom size; takes its color from the `onPrimary` role; the
  rotation advances frame to frame and *wraps* after one 500ms cycle (rather
  than running to an end and stopping); disposal stops the ticker.
- `splash_visual.dart` (5) — logo and loader when online; no overlay while
  connected; offline renders `AppNoInternetFullScreen(embedded: true)` (a
  nested scaffold would paint over the primary-colored splash background);
  the logo and loader stay mounted *underneath* the overlay, since splash
  keeps loading and navigates as soon as connectivity returns; the logo is
  sized to 40% of the screen width.
- `maintenance_screen.dart` (6) — illustration and title; the generic subtitle
  when the remark is null or empty; the server remark when there is one; and
  `PopScope(canPop: false)` — maintenance blocks the whole app. A
  whitespace-only remark is documented rather than normalized: the check is
  `isNotEmpty`, not a trimmed one (unlike `hasSalaryDetail` /
  `hasWalletTransactionDetail`), so a blank-but-present remark renders as an
  empty message line.
- `splash_screen.dart` (16) — every branch of the settings → languages →
  translations chain, driven through mocked cubits with hand-fed streams and a
  host `MaterialApp` whose `onGenerateRoute` records what splash pushed:
  settings fetched on first build; loaded settings continue to the language
  list (and so does a response with no `data` block); `app_mode_delivery_boy
  == '1'` routes straight to `RouteNames.maintenance` with the remark as the
  route argument and never loads languages; a settings failure falls back to
  cached translations; a selected language id loads that language while a
  null/empty one falls back to cache, as does a language-list failure; a
  logged-out session lands on login and a stored session on main; a
  translations *failure* still lets the app in (raw keys beat a stuck splash);
  splash navigates exactly once however often the chain re-fires, maintenance
  included; the offline overlay appears while disconnected; reconnecting
  retries the settings fetch, but not when settings are already loaded.
- `main_screen.dart` (9) — the four tab labels in order, starting on tab 0;
  tapping a tab moves both the `IndexedStack` index and the bar's
  `currentIndex`; all four children stay mounted (that is the point of an
  `IndexedStack`); `canPop` is true on home and false elsewhere, and the
  blocked back gesture returns to tab 0; a language change reloads the
  dashboard and all three order lists, while re-emitting the *same*
  `selectedId` reloads nothing (the `listenWhen` guard); the post-login FCM
  retry registers a token when login left the stored one blank, and stays
  quiet when the session already has one.

### C. Integration (written, not run — see footnote 2)
`integration_test/splash_flow_test.dart` (5) — real router, real
`SplashScreen`, real settings/language/localization cubits and repositories,
network faked at the `ApiClient` adapter seam. This is the one flow that
legitimately crosses feature boundaries (deciding where the app opens *is*
what splash does), but it stops at the destination route mounting:
`RouteNames.main` still resolves to `AuthTestApp`'s `PostLoginPlaceholder`.
Covers: a cold start with no session runs the whole chain (settings → language
list → that language's translations, told apart by the `id` query parameter on
the shared `/system_languages` endpoint) and lands on `SignInScreen`; a stored
session lands past login instead; maintenance mode shows `MaintenanceScreen`
with the server remark and never asks for languages; a total settings outage
(nothing stubbed → 404) still lets the app in via the bundled English asset;
and splash navigates only once.

`integration_test/main_flow_test.dart` (4) — the real four tab screens mounted
together, which is the one place that legitimately happens. Every list
endpoint answers empty on purpose: the assertions are about the shell, not
about what a tab renders. Covers: opens on the home tab with all four tabs
available (matched on the *rendered* strings — `'My Delivery'`, not the
`my_delivery` key — since integration tests load the real translations);
each tab switches the shell to its screen; every tab stays mounted across
switches; the back gesture returns to the home tab instead of leaving.

Fixtures are Dart constants in `integration_test/helpers/splash_fixtures.dart`
per the "fixtures must be Dart constants, not file reads" gotcha;
`home_fixtures.dart`'s `dashboardResponseFixture` is reused rather than
duplicated.

Not covered in `main_flow_test.dart`: the post-login FCM retry. It depends on
the device actually issuing a token (a simulator without APNs may hand back
none), which would make the flow pass or fail for reasons unrelated to the
code. Both branches are asserted deterministically in `main_screen_test.dart`
against the fake messaging platform instead.

### Bugs found
None. Both features matched their documented behavior on the first pass.

### Gotchas this suite added
- **`PopScope` is generic, and `MainScreen`'s infers as `PopScope<Object>`.**
  A bare `find.byType(PopScope)` means `PopScope<dynamic>` and silently
  matches nothing — the same trap `RadioListTile` sprang in the wallet suite.
  Pin the type argument. (`MaintenanceScreen`'s, which takes no
  `onPopInvokedWithResult`, infers differently and *does* match the bare
  finder — so the two screens' tests look inconsistent for a real reason.)
- **`MaterialApp` contributes a `PositionedDirectional` of its own** (the
  Cupertino back-gesture detector), so the bottom bar's indicator finder has
  to be scoped to `BottomNavBar` or it throws "Too many elements".
- **`Paint` round-trips a color through floats**, so `paint.color == color` is
  false even when every channel matches. Compare `toARGB32()`.
- **An animation that repeats forever is not `==` to itself after one cycle.**
  `UltraLoader` lands on the same angle to ~1e-16, which fails a `Matrix4`
  comparison — read the rotation back out with `atan2` and use `closeTo`.
- **Mount `MainScreen` with connectivity *disconnected*.** Each tab then
  renders its own offline body instead of its real content, which keeps the
  test on what `MainScreen` owns rather than on four other features' startup
  paths. The tabs' `initState` calls still fire, so every cubit they read must
  still be provided — including the orders tab's filter getters
  (`hasActiveFilters`, `selectedStatus`), which its app bar reads even while
  offline, and an unstubbed one returns null into a bool and fails the build.
- **`DashboardCubit.getDashboard`'s `trend` defaults to `'7'`**, which is also
  what `HomeScreen` passes explicitly — so `verify(() => cubit.getDashboard())`
  matches the tab's own startup call too. Count the calls rather than
  expecting the reload to be the only one.
- **The force-update dialog cannot be reached from a host test.**
  `ForceUpdateHelper.getStatus` short-circuits to `UpdateStatus.none` on
  anything that isn't Android or iOS, and `flutter test` runs on the host, so
  the splash chain always continues straight to `_loadLanguages`. Its branches
  need a `ForceUpdateDialog` test of their own.
- **`lib/main.dart`'s maintenance-socket route push/remove is untested.** It
  lives in the `main()` function body, wired to
  `MaintenanceSocketService.instance.onToggled` and the global navigator key,
  with no seam to drive it from a test. The socket service itself is covered
  under `2. home`, and `MaintenanceScreen` is covered here; what is not
  covered is the push/`removeRoute` bookkeeping between them.


## 11. profile — done ✅

`flutter test test/features/profile`: 110 unit + widget tests green (10
cubit, 100 widget/screen). Integration: 4/4 tests green on device
(`SM M066B`, API 36, `profile_flow_test.dart`).

Correction: this section originally started from a stale progress-table row
(all three columns 🔲) and a from-scratch checklist written without checking
git first. Most of the suite already existed, committed, and green —
`profile_detail_cubit_test.dart`, `profile_update_cubit_test.dart`,
`profile_menu_widgets_test.dart`, `profile_header_test.dart`,
`profile_sections_test.dart` (covers `profile_account_section.dart`/
`profile_preferences_section.dart`/`profile_quick_help_section.dart`),
`appearance_sheet_test.dart`, `change_password_dialog_test.dart`,
`logout_dialog_test.dart`, `language_sheet_test.dart`,
`edit_profile_bottom_nav_test.dart`, `edit_profile_step2_test.dart`, and the
3 screen tests (`profile_screen_test.dart`, `account_settings_screen_test.dart`,
`policies_screen_test.dart`). Three of those were overwritten in place with
duplicate rewrites before the mismatch was caught (`git status` showed `M`
instead of the expected `??`) — restored via `git checkout --` before
anything was lost. Actually new this pass: `delete_account_dialog_test.dart`
(3), `edit_profile_step_indicator_test.dart` (1), `edit_profile_step1_test.dart`
(11), and `edit_profile_screen_test.dart` (10) — the four files that
genuinely had no test yet.

`lib/features/profile/`: no model, no repository — reuses auth's `AuthModel`/
`AuthRepository` wholesale (same shape as `5. earnings` reusing home's
`DashboardModel`/`DashboardCubit`). Two profile-owned cubits:
`ProfileDetailCubit` (`BaseAsyncCubit<AuthModel>` — `loadProfile` calls
`AuthRepository.getProfile()` then round-trips the result through
`AuthModel.fromJson(userProfile.toJson())`; `setProfile` applies an
already-fetched profile, e.g. after an update, without hitting the API) and
`ProfileUpdateCubit` (`updateProfile` forwards 21 fields to
`AuthRepository.updateProfile`, `onSuccess` logs
`AppConstants.eventProfileUpdate`, `onUnexpectedError` records to
Crashlytics). `ProfileScreen` is mounted as a `main`-screen tab, not a named
route — no `RouteNames.profile`.

Several dialogs/sheets under this feature build cubits that belong to
**auth** (`ChangePasswordCubit`, `DeleteAccountCubit`, `LogoutCubit`,
`UpdateFcmTokenCubit`) — those cubits are already unit-tested under
`1. auth`; this feature only needs to test that the right method gets called
with the right args and the UI reacts correctly to each state, not re-test
the cubits themselves. `AuthHiveBox` is read directly (not via a cubit) in
`ProfileHeader`, and written directly in `EditProfileScreen`'s
update-success listener and `ChangePasswordDialog`'s success listener
(`clearAuth()`).

**Dead code found, not yet removed**: `appearance_sheet.dart`'s
`showAppearanceSheet()` has no live caller — its only reference is a
commented-out block in `profile_preferences_section.dart`. The theme-toggle
menu item is likewise commented out there, leaving `ThemeCubit` watched but
its value unused. Flag for a product/cleanup call before deciding whether to
write tests for it — testing unreachable code just locks in dead weight.

### A. Unit (done, 10 tests)
- **`ProfileDetailCubit`** (`profile_detail_cubit_test.dart`, 5) —
  `loadProfile`: `[Loading, Loaded]` re-parsing the repository response
  (asserted not identical to the repository's own instance, since it
  round-trips through `fromJson(toJson())`), `[Loading, Error]` on
  `ApiException`, and `[Loading, Error]` with the localized generic message
  on a non-API error; `setProfile` emits `Loaded` with the exact instance
  passed in and never calls `getProfile`; starts in `ProfileDetailInitial`.
- **`ProfileUpdateCubit`** (`profile_update_cubit_test.dart`, 5) —
  `updateProfile`: `[Loading, Loaded]` forwarding the repository's own model
  instance as-is (unlike `ProfileDetailCubit`, no re-parse); every one of the
  21 params forwarded exactly via `captureAny`; omitted optional fields stay
  `null`; `[Loading, Error]` with the API message on failure; starts in
  `ProfileUpdateInitial`. `onSuccess`'s analytics call and
  `onUnexpectedError`'s Crashlytics call are not separately asserted — same
  convention as every other `BaseAsyncCubit` in this repo
  (`sign_in_cubit_test.dart`, `withdrawal_cubit_test.dart`, …): `onSuccess`
  failures are swallowed by `BaseAsyncCubit.run` itself, and no test anywhere
  drives the non-`ApiException` branch that would reach `onUnexpectedError`,
  since doing so would require mocking the Crashlytics platform channel for
  no behavior payoff.
- No model/repository tests here — see reuse note above.

### B. Widget (done, 100 tests)
- `profile_screen.dart` (4) — online renders `ProfileHeader` +
  `ProfilePreferencesSection` + `ProfileQuickHelpSection` +
  `ProfileAccountSection` in order; offline swaps to
  `AppNoInternetFullScreen(embedded: true)` with retry calling
  `loadProfile`; a `ConnectivityConnected` reconnect refetches.
- `profile_header.dart` (7) — driven off `AuthHiveBox.instance.listenable`
  directly, not a cubit. Logged-in: avatar (network image, falls back to a
  user-icon SVG on an empty or failed `imageUrl`), name/email single-line
  ellipsis, Edit chip → `RouteNames.editProfile`. Logged-out: "Guest" label,
  smaller icon-only avatar, no Edit chip, "Login/Register" tap →
  `RouteNames.login`.
- `profile_preferences_section.dart` / `profile_quick_help_section.dart` /
  `profile_account_section.dart` (`profile_sections_test.dart`, 9) —
  preferences: one live item (change-language → `showLanguageSheet`),
  trailing text shows `"Name (CODE)"` once `LanguageCubit` is
  `LanguageLoaded`, falls back to the uppercase code alone, and further back
  to `SettingsHiveBox.instance.languageCode` before `LanguageLoaded`
  (commented-out theme item, nothing to assert unless restored); quick-help:
  chat-with-support resolves an admin conversation id then pushes
  `RouteNames.chat` with `ChatScreenArgs` (guard `context.mounted` after the
  await), rate-us launches `SettingsCubit.getAppUrl()` externally
  (force-unwrapped — noted as a crash risk on a null URL, not practically
  testable via `url_launcher`), help-policies expandable section pushes
  `RouteNames.policies` with `PoliciesType.privacyPolicy` /
  `.termsConditions`; account: settings → `RouteNames.accountSettings`,
  logout → `showLogoutDialog`.
- `profile_menu_widgets.dart` (9) — `ProfileMenuCard` (divider between all
  but last item, RTL-aware chevron flip, optional trailing text/widget);
  `ProfileExpandableMenuSection` (`_expanded` toggle drives
  `AnimatedRotation` + `AnimatedCrossFade`, RTL-aware chevrons in children
  too).
- `account_settings_screen.dart` (6) — 3 static items: notifications →
  `RouteNames.notifications`, change password → `showChangePasswordSheet`,
  delete account → `showDeleteAccountDialog`.
- `appearance_sheet.dart` (4) — `showAppearanceSheet()`'s 3
  `AppRadioOptionTile` options each call the matching `ThemeCubit` setter and
  pop. Tested even though the sheet is currently dead code (see the note
  above) — the entry point still exists and works, only nothing in the live
  UI calls it yet.
- `change_password_dialog.dart` (8) — builds its own `ChangePasswordCubit`.
  Old/new/confirm fields with per-field obscure toggles; requirements
  checklist shown only once the new-password field is non-empty; confirm
  validated against new. `Loaded` → pop, success snackbar on the parent
  context, `AuthHiveBox.instance.clearAuth()`, then
  `pushNamedAndRemoveUntil(RouteNames.login)` — changing password forces a
  logout, unlike anything in `1. auth`. `Error` → inline banner above the
  submit button, sheet stays open.
- `delete_account_dialog.dart` (3, new this pass) — mirrors
  `logout_dialog_test.dart`'s shape: `AppConfirmDialog(isDestructive: true)`
  around a real `DeleteAccountCubit` run through the `ApiClient` adapter
  seam; confirmation copy/`isDestructive`/`isLoading` asserted; cancel closes
  with no request; a failed delete pops the dialog and surfaces the server
  message with no navigation. Success is **not** covered here, same reason
  as `logout_dialog_test.dart`: `DeleteAccountCubit.deleteAccount` clears the
  auth box on success, and a Hive write started inside a `testWidgets` body
  never completes (the test's fake clock never runs the event loop it
  finishes on, so `tearDown`'s `box.close()` blocks forever with no failure
  message) — left for `integration_test/profile_flow_test.dart`, same as
  logout's own success path.
- `logout_dialog.dart` (3) — mirrors delete-account's shape around
  `LogoutCubit` (`swapButtonEmphasis: true` is the only styling difference);
  same pop/redirect-on-success (not covered, see above), pop/snackbar-on-error,
  pop-only-on-cancel.
- `language_sheet.dart` (6) — builds its own `LanguageSelectCubit`, reads the
  ambient `LanguageCubit`. Selecting a language does **not** close the sheet
  immediately — it waits on a *second* listener for
  `UpdateFcmTokenLoaded` (per-row spinner via `_pendingId` in the meantime),
  so the sheet stays open through `LanguageSelectLoaded` while the FCM
  token call is in flight. On completion: `LanguageCubit.updateSelectedId`,
  persists id/code/type/`userSelected` flag to `SettingsHiveBox`. Covers
  `LanguageLoading`/`LanguageError`-with-retry/`LanguageSelectError`/empty
  language list.
- `edit_profile_step_indicator.dart` (1, new this pass) — thin
  `ProfileAvatarPicker(size: 88)` wrapper; asserts `image`/`imageUrl`/`size`
  pass through unchanged and `onProfileImagePicked` fires via the picker's
  own `onPicked`.
- `edit_profile_step1.dart` (11, new this pass) — fullName and address
  required, an empty form shows exactly 2 "field is required" errors;
  `ApiCountryPhoneField` falls back to its own `validateMobile` validator
  when step1 doesn't pass one, so mobile is required too even though its
  error message uses a different template (missed by a naive
  fieldRequired-text count, so pinned down explicitly once discovered); email
  optional but still format-validated when non-empty; DOB field read-only,
  tap fires `onPickDob`; mobile field's `countryReadOnly` is true; national
  id/driving license tiles surface their own `errorText`; both earning-type
  selectors sit inside a disabled (`ignoring: true`) `IgnorePointer`;
  commission block hidden when `earningType != commission`, shown and
  validated (empty commission fails `validate()`) when it is; the
  return-earning-type mirror block has **no** validator wired on
  `returnCommissionController` — pinned down explicitly as the documented
  asymmetry (leaving it empty still passes `validate()` once fullName/
  address/mobile are filled); commission/min/max fields are read-only with a
  digits-only `inputFormatters` entry (asserted structurally, since a
  read-only field silently ignores `tester.enterText` — there's no user path
  to actually type into it).
- `edit_profile_step2.dart` (5) — bankName/accountNumber(digits-only)/
  ifscCode(forced uppercase)/accountHolderName, all `validateRequired`.
- `edit_profile_bottom_nav.dart` (5) — step 0: Cancel(outline)/Next; step 1:
  Back/Submit (spinner via `isLoading`); every button disabled while
  `isLoading`.

- `edit_profile_screen.dart` (10, new this pass) — largest file (408 lines);
  `ProfileDetailCubit`/`ProfileUpdateCubit`/`CountriesCubit` are mocked
  (app-global providers per `main.dart`), but `ZonesCubit` is instantiated by
  the screen's own state (not injected) — the real cubit and repository run
  against the `ApiClient` adapter seam instead, same shape as
  `withdrawal_sheet_test.dart`/`notification_screen_test.dart`; needs both
  Hive boxes open, since `DioInterceptor` reads the token/language code on
  every request even for this unrelated `zones` call. Covers: country
  auto-prefill by the profile's `countryId` matching a real `CountriesCubit`
  fixture; falling back to the `isDefault`-flagged country when the id
  doesn't match anything in the list; the matched country's zones fetched
  automatically and the profile's `zoneId` auto-selected once they load; text
  fields and the commission block prefilled from a commission-earning
  profile (`bonus_type: 1` in the fixture); `Next` validates step 1 and
  advances to step 2; `Back` returns to step 1; `Cancel` at step 1 pops the
  screen (verified via a `NavigatorObserver`, not just the widget leaving the
  tree — `MaterialPageRoute`'s pop transition needs ~500ms of pumped time to
  fully settle before the popped route's widget actually leaves); submit
  forwards `bonusType`/`returnBonusType` as `'1'`/`'0'` strings; a
  trimmed-to-empty optional field (email) is sent as `null`, not `''`; a
  `ProfileUpdateError` surfaces the message and leaves the screen mounted;
  `ProfileUpdateLoading` sets `EditProfileBottomNav.isLoading`. The success
  path (`ProfileDetailCubit.setProfile` + `AuthHiveBox.updateUserData` +
  pop) is **not** covered here, same reason as `delete_account_dialog_test.dart`/
  `logout_dialog_test.dart`: the Hive write is fire-and-forget inside the
  listener, and a Hive write started inside a `testWidgets` body never
  completes under the fake clock — left for
  `integration_test/profile_flow_test.dart`.
- **Gotcha found writing this suite**: the bottom nav's step-1 button label
  key is `LanguageLabelKeys.updateProfile`, not `submit` — there is no
  `submit` key in this codebase. Also, `CustomAppBar`'s step-progress ring
  (`TweenAnimationBuilder<double>` driving a `CircularProgressIndicator`)
  makes `pumpAndSettle()` time out on this screen; every interaction here
  uses a bounded `pump()` + `pump(Duration(...))` pair instead, per this
  file's own documented convention for looping/long animations.

### B (continued). `policies_screen.dart` (9, done)
Reads `CountrySettingsCubit`; `Initial` triggers `loadCountrySettings()` as a
build-time side effect; `Loading` → `LoadingWidget`; `Error` →
`EmptyStateWidget` with message + retry; `Loaded` with null/empty html →
type-specific empty state (privacy vs terms have distinct copy keys);
`Loaded` with content → `SingleChildScrollView(HtmlWidget(html))`; offline →
`AppNoInternetFullScreen(embedded: true)` with `loadCountrySettings(force:
true)` retry, reconnect auto-reloads.

### C. Integration — done ✅ (`integration_test/profile_flow_test.dart`, 4/4 green on device, `SM M066B`, API 36)

Already covered by `1. auth`'s `session_flow_test.dart` — **not duplicated
here**: logout success/cancelled/failed, delete-account success/cancelled
(both dialogs live here but drive auth-owned cubits already exercised
end-to-end there).

`AuthTestApp`'s `mainScreenBuilder` stands in for the profile tab's own entry
point, same as `session_flow_test.dart`. Unlike `main.dart`, `AuthTestApp`
deliberately never kicks off `ProfileDetailCubit()..loadProfile()` /
`CountriesCubit()..fetchCountries()` from a provider's `create` (so other
features' tests aren't forced to stub these endpoints) — `ProfileScreen`
itself only reloads on a connectivity *transition*, never on first mount, so
this suite's own `_ProfileTabHost` wrapper replicates just that eager
kick-off in its `initState`, standing in for what `main.dart` does globally.
Fixtures are Dart constants in `integration_test/helpers/profile_fixtures.dart`
per the "fixtures must be Dart constants, not file reads" gotcha; the login
envelope is reused from `auth_fixtures.dart`.

Covers:
1. **View → edit → save**: profile tab loads, header shows the fetched name;
   Edit chip → `EditProfileScreen` with step 1 prefilled (name/mobile/address)
   and the zone auto-selected from `profile.zoneId` once the country's zones
   load; Next validates and advances; step 2 submit → `POST /update` →
   response threads back through `ProfileDetailCubit.setProfile` +
   `AuthHiveBox.updateUserData`, pops back to the profile tab, whose header
   now shows the updated name. This is the one journey that exercises the
   success side of `ProfileUpdateLoaded`'s listener (the `AuthHiveBox` write
   and the pop) — both are fire-and-forget/imperative paths the widget-layer
   tests (`edit_profile_screen_test.dart`, `delete_account_dialog_test.dart`,
   `logout_dialog_test.dart`) explicitly leave to this suite, since a Hive
   write started inside a `testWidgets` body never completes under the fake
   clock.
2. **Account settings navigation**: Settings → `AccountSettingsScreen`;
   Notifications → `NotificationScreen` mounts; back; change password → the
   sheet opens (3 fields present).
3. **Change password → forced logout**: submit valid old/new/confirm values
   from the sheet, success clears the session (`AuthHiveBox.isLoggedIn` →
   false) and lands on `SignInScreen` — unique to this feature, not covered
   by `1. auth`'s session tests.
4. **Guest header**: with no session, the header shows "Guest" (no Edit
   chip); tapping Login/Register lands on `SignInScreen`.

Not covered here (left for a future pass, same reasoning `earnings`/
`notifications` gave for what they deferred): the language sheet's full
select → persist → FCM-update → close journey (would need `LanguageCubit`
driven to `LanguageLoaded` first, which nothing in this harness does
automatically, unlike the real splash chain); the policies screen's
navigation from the quick-help section; and the offline swap on both
screens (`connectivity_plus`'s platform channel isn't faked in any of this
repo's integration suites — the `salary`/`wallet`/`cash_collection` flows
all leave that same swap to their own widget tests instead).

### Gotchas this suite added
- **On-device the real translation asset loads**, so matching a raw
  `LanguageLabelKeys.*` key finds nothing — the same trap the auth suite hit
  first. `LocalizationService.instance.translate(key)` first, same as
  `session_flow_test.dart`'s `tapConfirm`.
- **`CustomAppBar`'s back arrow is a plain `IconButton`, not the
  platform-specific back-button widget `WidgetTester.pageBack()` looks for**
  (`CupertinoNavigationBarBackButton` on this run's Android/Cupertino-styled
  binding) — `pageBack()` throws "One back button expected on screen" even
  though a back button is visibly there. Tap `find.byType(IconButton).first`
  instead.
- **Something outside the profile feature calls `GET /settings` on every
  mount here** — not yet tracked down to a specific widget/cubit, but it
  shows up as the first request in `adapter.requestedPaths` regardless of
  which screen is under test. Stub it (`ApiEndpoints.settings`) alongside
  the feature's own endpoints or every test 404s on it before anything else
  runs.

Not planned: `appearance_sheet.dart` — unreachable, see dead-code note above.

## 3. Remaining features

Same 3-layer shape as auth and home for each (write detailed checklist just before that
feature starts — avoids drift if repo/model shape changes meanwhile):

1. **Unit**
   - Models — fromJson/toJson edge cases (nulls, lenient int/double parse)
   - Repository — mock `ApiClient`, verify endpoint + params per method
   - Cubit — bloc_test, verify emitted state sequence per `BaseAsyncCubit`/paginated-list-cubit pattern, verify side effects (Hive writes, analytics)
2. **Widget** — validation, loading/error/success UI states, key interactions (tap, scroll/pagination, pull-to-refresh)
3. **Integration** — real navigation through the feature's primary user journey end-to-end (list → detail → action → result), mocked API layer only

Update progress table + write that feature's checklist section as it starts.

## Conventions (apply to every test file, from file 1)

1. Every `expect()` preceded by `print('expected: X, actual: Y')`.
2. Every `testWidgets`/`test` body opens `printTestDivider('<Widget/Unit> — what this checks')`.
3. `tearDownAll` → `GetIt.instance.reset()` if `setUpAll` registered anything.
4. Bounded `pump()` over `pumpAndSettle()` wherever a screen has looping/long animation (check widget source first).
5. Read full widget/cubit source before writing assertions — no guessing constructor params, callbacks, or `context.read<T>()` deps.
6. Integration tests never hit real network — swap `ApiClient().httpClientAdapter` for a `FakeApiAdapter`; use a temp Hive dir per test run.

## Gotchas found while writing the auth suite

- **`AppText(isRequired: true)` renders a `RichText` with a trailing `" *"`**, so `find.text(key)` misses it. Match on the widget instead: `find.byWidgetPredicate((w) => w is AppText && w.text == key)`.
- **Translations aren't loaded under `flutter test`**, so `LocalizationService.translate` returns the raw key. Assert against `LanguageLabelKeys.<key>` (e.g. `'email_required'`), not English copy. Integration tests call `LocalizationService.instance.loadFromAssets()` first, so those *do* see real English text.
- **`BaseAsyncCubit.run` swallows `onSuccess` failures** (wrapped in its own try/catch), so Firebase Analytics/Crashlytics/Clarity calls throwing `MissingPluginException` in tests never turn a success into an error state — no platform-channel mocks needed for cubit tests.
- **Anything touching `AuthHiveBox`/`SettingsHiveBox` needs an open box**, or it throws `HiveError: Box not found`. Includes non-obvious paths: `AuthRepository.logout` (reads the stored FCM token) and the register form's password checklist (`PasswordPolicy.fromSettings`).
- **The register form is far taller than the default 800×600 test surface.** Pin `tester.view.physicalSize` *and* `tester.view.devicePixelRatio = 1.0` — `physicalSize` alone is divided by a default ratio of 3.0, silently giving a third of the intended logical height.
- **`SignInScreen._onLogin` does not call `_formKey.currentState!.validate()`** — the login button submits whatever is typed and the server rejects it. Widget tests assert the validators through an explicit `Form.validate()` rather than pretending the button gates submission.
- **`AuthModelData.cashReceived` is `int?` while the API sends a double** (`15996.84` → `15996`). Tests document the truncation as current behavior; change the model to `double?` if the fractional part matters.

- **A screen whose `initState` reaches `NotificationService` needs Firebase faked.** `NotificationService.instance` builds `FirebaseMessaging.instance` in a field initializer, so merely touching the singleton throws `[core/no-app]`. Mocking the raw platform channels does *not* work — `firebase_core` talks over Pigeon channels now, and `Firebase.app()` reads a registered-apps map. `test/helpers/firebase_test_helper.dart` swaps `FirebasePlatform.instance` and `FirebaseMessagingPlatform.instance` for fakes instead; call `await FirebaseTestHelper.setUp()` in `setUpAll`.
- **Re-pumping the same widget after re-stubbing a mock cubit does not rebuild it.** Asserting two different states in one test silently checks the first one twice — split them into separate tests.
- **`RefreshIndicator` needs a scroll view that can actually move.** With a viewport tall enough to fit all the content, the scrollable never leaves its idle state and the pull is a silent no-op (the refetch just never happens). Give that one test a short viewport, and drive the gesture by hand (`startGesture` → repeated `moveBy` → `up`) — `drag()`/`fling()` can finish before the indicator arms.
- **Watch the viewport width too.** Shrinking it to make a list scrollable can push a header `Row` into a "RenderFlex overflowed" assert that has nothing to do with what's being tested.
- **`google_fonts` will hang any test that lets real wall-clock time pass.** The theme's text styles come from `google_fonts`, which falls back to *downloading* a font file when it isn't bundled. Under `flutter test` that request never resolves, so a test containing a `runAsync` block stalls the runner with no failure message at all. `pumpTestWidget` now sets `GoogleFonts.config.allowRuntimeFetching = false` for every widget test.
- **Popping a dialog that is the only route hangs the runner.** A handler ending in `AppNavigator.pop` empties the Navigator when the dialog was pumped directly. Open such dialogs through their real entry point (`showDialog`/`maybeShow`) from a host screen instead.
- **A Hive write started inside a widget test never completes.** The test's fake clock never runs the event loop the write finishes on, so the pending future then blocks `tearDown`'s `box.close()` forever — again with no failure message. Neither `runAsync` nor extra pumps rescue it, because the future belongs to the test's own zone. Assert storage side effects in a plain `test()` instead, and keep fire-and-forget writes out of `testWidgets` bodies.
- **Leaving a dialog mounted at test end keeps its timers alive.** Unmount with `pumpWidget(const SizedBox.shrink())` before the test finishes when the widget runs a `Timer.periodic`.

### Integration-test-specific (learned running auth on a real device)

- **`tester.pump(Duration)` does not wait wall-clock time under the live binding**, so an assertion right after a tap sees the pre-response UI even though the fake adapter "already" answered. Wait with `tester.runAsync(() => Future.delayed(...))` and then pump (the `waitForResponse` helper in `auth_flow_test.dart`).
- **Fixtures must be Dart constants, not file reads.** The test runs on the device, where the host's `test/fixtures/` path doesn't exist (`PathNotFoundException`) — and adding it to `pubspec.yaml` assets would ship test JSON inside the real app. `integration_test/helpers/auth_fixtures.dart` mirrors the JSON fixture; keep the two in sync.
- **`Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` must run in `setUpAll`**, exactly as `main()` does it — `SignInScreen` reads `FirebaseMessaging.instance` and otherwise throws `[core/no-app]`.
- **Let in-flight requests land before the tree is unmounted.** Teardown mid-request closes the cubits and each pending future then throws `Bad state: Cannot emit new states after calling close`, which is reported as the test failing (see `settleAndUnmount`).
- **A `ListView.builder` only keeps on-screen items mounted.** After scrolling
  to trigger `loadMore`, the earlier page's cards are gone from the tree —
  `find.byType` no longer sees them, so a total-widget-count assertion after
  a scroll is unreliable. Assert on the request the app actually sent instead
  (a follow-up fetch with a non-zero offset) rather than on how many cards are
  currently built.
- **Keep a feature's integration test inside that feature's boundary.** Letting login navigate into the real `MainScreen` pulled in dashboard/orders/profile startup — provider lookups, sockets, and a paint-time null check in `dashboard_screen.dart` — and auth flows failed on unrelated home-feature errors. `AuthTestApp` therefore routes `RouteNames.main` to a `PostLoginPlaceholder`; every other route goes through the real `AppRouter`. Do the same per feature.
