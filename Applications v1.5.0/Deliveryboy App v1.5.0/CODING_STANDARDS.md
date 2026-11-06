# cakezake_deliveryboy App — Coding Standards & Patterns

> This is a CodeCanyon product (rider/delivery-boy companion app). All code must be **dynamic**, **clean**, **maintainable**, and easy for buyers to integrate and customize.

---

## 1. Multi-Language Strings (No Hardcoded Text)

- **Never** use raw strings directly in widgets (e.g., `Text("Welcome")`)
- All display text uses a **string key** constant from `LanguageLabelKeys` (`lib/core/localization/language_label_key.dart`)
- Actual values come from the API and are cached locally; `assets/languages/en.json` is the fallback
- `LanguageCubit` (in `lib/core/localization/cubit/`) loads available languages at startup
- In every widget's `build()` method, use the **`context.translate(key)`** extension — it resolves the key via `LocalizationService`

```dart
// BAD
Text("Mark as Delivered")

// GOOD
Text(context.translate(LanguageLabelKeys.markAsDelivered))
```

### How it works
```
assets/languages/en.json  ← fallback strings (buyer edits for customization)
      ↓ loaded via LocalizationService
LanguageCubit             ← placed at app root (BlocProvider in main.dart)
      ↓ accessed via
context.translate(key)    ← extension on BuildContext → LocalizationService.instance.translate(key)
```

### Adding a new string
1. Add the key constant in `lib/core/localization/language_label_key.dart`
2. Add the key-value pair in `assets/languages/en.json`
3. Use `context.translate(LanguageLabelKeys.yourKey)` in the widget

---

## 2. No Hardcoded Font Sizes or Text Styles

- **Never** use raw `fontSize`, `fontWeight`, or `color` inline on any widget
- Always use `context.tt` (shorthand for `Theme.of(context).textTheme`) for text styles
- For variations, use **`copyWith`** on a `context.tt.*` style

```dart
// BAD
Text("Order #1234", style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500))

// BAD — raw Text with context.tt inline, bypasses AppText
Text("Order #1234", style: context.tt.bodyMedium)

// GOOD — use AppText, which resolves style from context.tt internally
AppText.bodyMedium("Order #1234")

// GOOD — color/fontWeight overrides as named params, not copyWith
AppText.bodyMedium("Order #1234", color: context.cs.primary, fontWeight: FontWeight.w600)
```

### Context shorthand extensions (`lib/utils/extensions/context_extensions.dart`)

| Extension | Full form | Use |
|-----------|-----------|-----|
| `context.tt` | `Theme.of(context).textTheme` | Text styles |
| `context.cs` | `Theme.of(context).colorScheme` | Colors |
| `context.isDark` | `Theme.of(context).brightness == Brightness.dark` | Dark mode check |
| `context.translate(key)` | `LocalizationService.instance.translate(key)` | Localized strings |

---

## 3. State Management — Cubit Only

- Use **flutter_bloc** — **Cubit** only (no Events/Bloc)
- **All states are defined in the same file as the cubit** — no separate `_state.dart` file
- Use **Dart `sealed` classes** for states — never `abstract class`
- Never use `setState` inside screens; all logic lives in the Cubit
- Only emit state for **meaningful transitions** (loading, success, error)

```dart
// ❌ BAD — abstract class allows unintended subclasses, no exhaustive switch
abstract class OrderDetailState {}
class OrderDetailLoading extends OrderDetailState {}
class OrderDetailLoaded extends OrderDetailState { ... }

// ✅ GOOD — sealed class: compiler-enforced, exhaustive, no Equatable needed
// ── States (top of the file, same file as cubit) ──────────────────
sealed class OrderDetailState {}
final class OrderDetailInitial extends OrderDetailState {}
final class OrderDetailLoading extends OrderDetailState {}
final class OrderDetailLoaded  extends OrderDetailState { final OrderModel order; OrderDetailLoaded(this.order); }
final class OrderDetailError   extends OrderDetailState { final String message; OrderDetailError(this.message); }

// ── Cubit ─────────────────────────────────────────────────────────
class OrderDetailCubit extends Cubit<OrderDetailState> {
  OrderDetailCubit(this._repo) : super(OrderDetailInitial());
  final OrderRepository _repo;

  Future<void> fetchOrder(int orderId) async {
    emit(OrderDetailLoading());
    try {
      final order = await _repo.getOrderDetail(orderId);
      emit(OrderDetailLoaded(order));
    } on ApiException catch (e) {
      emit(OrderDetailError(e.message));
    } catch (_) {
      emit(OrderDetailError(context.translate(LanguageLabelKeys.somethingWentWrong)));
    }
  }
}
```

> **Migration note:** existing cubits in this repo (`SalaryCubit`, `CashCollectionCubit`, etc.) still use `abstract class` for states. Treat `sealed class` as the standard for **all new cubits**; migrate old ones opportunistically when touched, don't do a blanket rewrite.

### Why `sealed` over `abstract`
| | `abstract class` | `sealed class` |
|---|---|---|
| Exhaustive `switch` | ❌ compiler won't warn on missing case | ✅ compile error if case missing |
| Subclassing outside file | ✅ anyone can extend | ❌ only same file — intentional |
| Boilerplate | same | same |

---

## 4. Common Widgets

- Build reusable UI components in `lib/commons/widgets/`
- Before creating any widget in a feature, check if a common one exists
- Core common widgets to maintain:
  - `AppText` — wraps `Text` with a named constructor per `context.tt.*` slot (`AppText.bodyMedium(...)`, `AppText.titleSmall(...)`, etc). Use instead of raw `Text(style: context.tt.x)`.
  - `AppButton`
  - `AppTextField`
  - `LoadingWidget` / `ShimmerLoading` / `ListSkeletonLoader`
  - `EmptyStateWidget`
  - `AppNoInternetWidget`
  - `AppNetworkImage`
  - `AppSnackBar`
  - `CustomAppBar`
  - `StatusChip` — order/return/transaction status pill
  - `SlideToConfirmButton` — used for order status progression ("Mark as …")
  - `PaginatedListFooter` — bottom-of-list loading/end indicator for paginated screens
  - `AppPaymentBadge` — COD/Prepaid badge
  - `CountryPhoneField` / `CountryDropdownField` / `CountryPickerSheet` — used in Register/Edit Profile
  - `AppImageUploadField` — National ID / Driving License uploads
  - `EarningTypeSelector` — Salaried/Commission toggle

---

## 5. Folder Structure

Follow [CakeZake Flutter Folder Structure](https://cakezake-in.github.io/flutter-folder-structure/) strictly. See `FOLDER_STRUCTURE.md` / `PROJECT_ARCHITECTURE.md` for full details.

```
assets/
└── languages/
    └── en.json              ← English fallback strings (buyer edits this)

lib/
├── core/
│   ├── theme/
│   │   ├── app_colors.dart          ← all color palette constants
│   │   ├── app_theme.dart           ← ThemeData setup (light/dark)
│   │   ├── app_spacing.dart         ← SizedBox spacing constants (h4, w8…)
│   │   └── app_radius.dart          ← BorderRadius constants (r8, r12…)
│   ├── localization/
│   │   ├── language_label_key.dart  ← all key constants
│   │   ├── locale_resolver.dart     ← resolves TextDirection + Locale
│   │   └── cubit/
│   │       └── language_cubit.dart  ← language management (global)
│   ├── configs/
│   │   └── app_config.dart          ← base URL, default language, flags
│   ├── constants/
│   │   ├── app_constants.dart       ← app name, platform type, payment types
│   │   ├── assets_constants.dart    ← asset path strings
│   │   └── navigation_service.dart  ← AppNavigator wrapper
│   ├── api/
│   │   ├── api_client.dart          ← Dio HTTP client (singleton)
│   │   ├── api_endpoints.dart       ← all endpoint URL constants
│   │   ├── api_exception.dart       ← typed exception class
│   │   └── api_parameters.dart      ← query param key constants
│   ├── services/
│   │   ├── notification_service.dart ← FCM + local notifications
│   │   └── connectivity_service.dart
│   └── routes/
│       ├── route_names.dart         ← route string constants
│       └── app_router.dart          ← MaterialApp route configuration
├── commons/
│   ├── widgets/                     ← shared reusable widgets
│   ├── models/
│   ├── cubit/                       ← global cubits (connectivity, settings, etc.)
│   └── repositories/
├── features/
│   └── <feature_name>/
│       ├── screens/
│       ├── widgets/
│       ├── cubit/
│       │   └── <feature>_cubit.dart ← states + cubit in one file
│       ├── models/
│       └── repositories/
│           └── <feature>_repository.dart
└── utils/
    ├── extensions/
    │   ├── context_extensions.dart  ← context.cs, context.tt, context.translate()
    │   └── num_extensions.dart
    ├── input_validators.dart
    └── json_parsers.dart
```

---

## 6. No Hardcoded Spacing or Sizing

- **Never** write raw numbers for spacing, padding, or border radius in widgets
- Use `AppSpacing` (`lib/core/theme/app_spacing.dart`) for `SizedBox` spacing
- Use `AppRadius` (`lib/core/theme/app_radius.dart`) for `BorderRadius`
- Use `ThemeConstants` (`lib/core/constants/theme_constants.dart`) padding doubles for `EdgeInsets`/`EdgeInsetsDirectional` values

```dart
// BAD
SizedBox(height: 16)
SizedBox(width: 8)
BorderRadius.circular(12)
EdgeInsets.all(16)
EdgeInsetsDirectional.symmetric(horizontal: 20)

// GOOD
AppSpacing.h16
AppSpacing.w8
AppRadius.r12
EdgeInsetsDirectional.all(ThemeConstants.paddingL)
EdgeInsetsDirectional.symmetric(horizontal: ThemeConstants.paddingXL)
```

### ThemeConstants padding reference

| Constant | Value | Use |
|----------|-------|-----|
| `ThemeConstants.paddingXS` | 4px | Tight inner padding |
| `ThemeConstants.paddingS` | 8px | Small padding |
| `ThemeConstants.paddingM` | 12px | Card inner padding |
| `ThemeConstants.paddingL` | 16px | Standard page / card padding |
| `ThemeConstants.paddingXL` | 20px | Section horizontal padding |
| `ThemeConstants.paddingXXL` | 24px | Large section padding |

### AppSpacing reference (SizedBox children)

| Constant | Value | Constant | Value |
|----------|-------|----------|-------|
| `AppSpacing.h4` | height: 4 | `AppSpacing.w4` | width: 4 |
| `AppSpacing.h8` | height: 8 | `AppSpacing.w8` | width: 8 |
| `AppSpacing.h12` | height: 12 | `AppSpacing.w12` | width: 12 |
| `AppSpacing.h16` | height: 16 | `AppSpacing.w16` | width: 16 |
| `AppSpacing.h20` | height: 20 | `AppSpacing.w20` | width: 20 |
| `AppSpacing.h24` | height: 24 | `AppSpacing.w24` | width: 24 |
| `AppSpacing.h32` | height: 32 | `AppSpacing.w32` | width: 32 |

### AppRadius reference

| Constant | Value | Use |
|----------|-------|-----|
| `AppRadius.r4` | 4px | Chips, badges (e.g. `StatusChip`) |
| `AppRadius.r8` | 8px | Input fields, small cards |
| `AppRadius.r12` | 12px | Cards, buttons |
| `AppRadius.r16` | 16px | Large cards |
| `AppRadius.r24` | 24px | Pill buttons, slide-to-confirm track |
| `AppRadius.cardRadius` | 16px | All cards |
| `AppRadius.buttonRadius` | 12px | All buttons |
| `AppRadius.bottomSheetRadius` | top 24px | Bottom sheets (Withdrawal, Delivery OTP, Filters) |

> Confirm exact constant values against `app_spacing.dart` / `app_radius.dart` before use — the table above mirrors this app's actual token names; do not invent new ones without adding them to the source file first.

### Screen-relative height/width — no raw `MediaQuery`, use `SizeExtensions`

- **Never** call `MediaQuery.of(context).size` / `.padding` / `.viewInsets` directly in a widget
- Use `SizeExtensions` (`lib/utils/extensions/size_extensions.dart`) for any height/width that must scale with device screen size (full-screen containers, bottom-sheet/dialog max height, safe-area offsets, keyboard-aware padding)
- This is **separate** from `AppSpacing`/`AppRadius` above — those are for fixed design-system spacing (icons, padding, gaps, radii); `SizeExtensions` is only for values that are legitimately a fraction of the device screen

```dart
// BAD
MediaQuery.of(context).size.height * 0.5
MediaQuery.of(context).padding.top

// GOOD
context.heightFraction(0.5)
context.topSafePadding
```

| Member | Use |
|--------|-----|
| `context.screenWidth` / `context.screenHeight` | Raw device width/height |
| `context.widthFraction(x)` / `context.heightFraction(x)` | Proportional sizing, e.g. bottom sheet at 70% of screen height |
| `context.topSafePadding` | Status bar / notch height — add to top offsets under the status bar |
| `context.bottomSafePadding` | System nav bar / home indicator height — add to bottom-pinned bars/sheets instead of wrapping in `SafeArea` |
| `context.keyboardInset` | On-screen keyboard height, `0` when closed — push bottom-pinned content above it |

> Fixed pixel values (icon `size:`, `Divider(height:)`, avatar dims, skeleton placeholder sizes) are **not** screen-relative — leave them as literals or `AppSpacing`/`AppRadius`. Do not force these through `widthFraction`/`heightFraction`; that makes them scale incorrectly across devices instead of staying a fixed design size.

---

## 7. Theme Colors via Context

- **Never** reference `AppColors.xxx` directly inside widget `build()` methods
- Always access colors through `context.cs.xxx` (see `context_extensions.dart`)
- `AppColors` is used **only** in `AppTheme` to define the `ColorScheme` — nowhere else in UI
- The app supports **dark mode** — `context.cs.*` automatically resolves to the correct light/dark color

```dart
// BAD
Container(color: AppColors.primary)
Text("Rejected", style: TextStyle(color: AppColors.error))

// GOOD
Container(color: context.cs.primary)
Text("Rejected", style: context.tt.bodyMedium?.copyWith(color: context.cs.error))
```

### Status colors (order/wallet/return status chips)

Use semantic `context.cs.*` slots consistently for status meaning across the app — don't invent one-off hex colors per screen:
- Success/Delivered/Approved/Credit → `context.cs.primary` (or a `success` slot if defined in `AppTheme`)
- Pending/Processing → warning/amber slot
- Rejected/Failed/Cancelled/Debit → `context.cs.error`

### Dark mode
- Use `context.isDark` to conditionally apply assets or decorations that need a dark variant
- Never hardcode light-only colors — `context.cs.*` handles both modes automatically

---

## 8. Dart Dot Shorthands (Compact Syntax)

Requires Dart ≥ 3.10. Use dot shorthand **everywhere** the type is inferable from context.

```dart
// BAD
Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start)
Text("Order Delivered", textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)
Container(decoration: BoxDecoration(shape: BoxShape.circle))

// GOOD
Row(mainAxisAlignment: .center, crossAxisAlignment: .start)
Text("Order Delivered", textAlign: .center, overflow: .ellipsis)
Container(decoration: BoxDecoration(shape: .circle))
```

---

## 9. Navigation — AppNavigator

- **Never** call `Navigator` directly in widget `build()` methods
- Use `AppNavigator` (`lib/core/constants/navigation_service.dart`) for all navigation
- Route name strings come from `RouteNames` (`lib/core/routes/route_names.dart`)

```dart
// BAD
Navigator.pushNamed(context, '/order-detail', arguments: args);
Navigator.pushReplacementNamed(context, '/main');

// GOOD
AppNavigator.pushNamed(context, RouteNames.orderDetail, arguments: args);
AppNavigator.pushReplacementNamed(context, RouteNames.main);
AppNavigator.pushNamedAndRemoveUntil(context, RouteNames.main);
AppNavigator.pop(context);
```

### AppNavigator API

| Method | Purpose |
|--------|---------|
| `AppNavigator.push(context, page)` | Push a widget directly |
| `AppNavigator.pushNamed(context, route, {arguments})` | Push a named route |
| `AppNavigator.pushReplacementNamed(context, route)` | Replace current route |
| `AppNavigator.pushNamedAndRemoveUntil(context, route)` | Clear stack and push |
| `AppNavigator.pushNamedAndRemoveUntilRoute(context, route, keepUntil)` | Pop until a specific route, then push |
| `AppNavigator.pop(context, [result])` | Pop current route |
| `AppNavigator.canPop(context)` | Check if pop is possible |
| `AppNavigator.popUntil(context, routeName)` | Pop until route |

### Typed Args Pattern

**Never pass multiple individual params as raw arguments.** Always wrap in a typed `Args` class.

```dart
// ── Args ──────────────────────────────────────────────────────────────────────
class OrderDetailArgs {
  final int orderId;
  final bool isQuickOrder;

  const OrderDetailArgs({required this.orderId, required this.isQuickOrder});
}

// ── Navigation call-site ─────────────────────────────────────────────────────
AppNavigator.pushNamed(
  context,
  RouteNames.orderDetail,
  arguments: OrderDetailArgs(orderId: order.id, isQuickOrder: order.channel == 'quick'),
);

// ── In the screen ────────────────────────────────────────────────────────────
final args = ModalRoute.of(context)!.settings.arguments as OrderDetailArgs;
```

---

## 10. API Architecture — ApiClient → Repository → Cubit

```
ApiClient        ← Dio HTTP client (singleton), throws ApiException
     ↓
Repository       ← business logic, data mapping — lets ApiException propagate
     ↓
Cubit            ← catches ApiException, emits states
     ↓
Screen/Widget    ← listens to states via BlocBuilder/BlocListener
```

- **Cubits never call ApiClient directly** — always through a repository
- **Repositories never have UI logic** — they only call ApiClient and map/parse data
- All API/network errors use a single typed exception: **`ApiException`** (`lib/core/api/api_exception.dart`)

### ApiException — the single error type

```dart
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? messageStatusCode;

  const ApiException({required this.message, this.statusCode, this.messageStatusCode});

  factory ApiException.fromDioError(Object error) { ... }

  @override
  String toString() => message;
}
```

### Repository — let ApiException propagate, no re-wrapping

```dart
// ✅ GOOD — clean, no try/catch needed
class OrderRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<OrderModel>> getOrders({int offset = 0, required String channel}) async {
    final result = await _apiClient.get(
      ApiEndpoints.orders,
      queryParameters: {ApiParameters.offset: offset, ApiParameters.channel: channel},
    );
    return (result['data'] as List)
        .map((e) => OrderModel.fromJson(Map.from(e)))
        .toList();
    // ApiException from ApiClient propagates automatically
  }
}
```

### Cubit — two-tier catch

```dart
Future<void> fetchOrders() async {
  emit(OrdersLoading());
  try {
    final orders = await _repo.getOrders(channel: 'quick');
    emit(OrdersLoaded(orders));
  } on ApiException catch (e) {
    emit(OrdersError(e.message));        // ← API/network message
  } catch (_) {
    emit(OrdersError(context.translate(LanguageLabelKeys.somethingWentWrong)));  // ← parsing failures
  }
}
```

### What NOT to do

```dart
// ❌ BAD — leaks raw Dart error to user ("type 'String' is not a subtype of type 'int'")
} catch (e) {
  emit(SomeError(e.toString()));
}

// ❌ BAD — only catching ApiException with no generic fallback
} on ApiException catch (e) {
  emit(SomeError(e.message));
}
// missing: catch (_) { emit(SomeError(genericMessage)); }

// ❌ BAD — re-wrapping ApiException in repository
} catch (e) {
  throw ApiException(message: e.toString());
}
```

---

## 11. Bloc Widget Usage — BlocListener / BlocBuilder / BlocSelector

| Widget | When to use |
|--------|-------------|
| `BlocListener` | Side effects only — snackbars, navigation, dialogs. Wrap the **entire screen** body. |
| `BlocBuilder` | Rebuild a widget subtree whose **UI depends on state**. Wrap only the smallest changing widget. |
| `BlocSelector` | Rebuild based on a **single derived value** (bool, int, enum). Prefer over `BlocBuilder` when extracting one field. |

```dart
@override
Widget build(BuildContext context) {
  return BlocListener<OrderStatusUpdateCubit, OrderStatusUpdateState>(
    listener: (context, state) {
      if (state is OrderStatusUpdateError) {
        AppSnackBar.showError(context, state.message);
      }
      if (state is OrderStatusUpdateSuccess) {
        AppSnackBar.showSuccess(context, context.translate(LanguageLabelKeys.orderStatusUpdated));
      }
    },
    child: AppScaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildStatusButton(),
    ),
  );
}

// ✅ BlocSelector — rebuilds only when loading changes
Widget _buildStatusButton() {
  return BlocSelector<OrderStatusUpdateCubit, OrderStatusUpdateState, bool>(
    selector: (state) => state is OrderStatusUpdateLoading,
    builder: (context, isLoading) => SlideToConfirmButton(
      label: context.translate(LanguageLabelKeys.markAsDelivered),
      isLoading: isLoading,
      onConfirm: isLoading ? null : () => context.read<OrderStatusUpdateCubit>().updateStatus(),
    ),
  );
}
```

### Rules
- **`BlocListener` at screen root** — one listener catches all side effects
- **`BlocBuilder` wraps only the smallest changing subtree** — never the whole `Scaffold`
- **`BlocSelector` over `BlocBuilder`** when you only need one derived value
- **Static UI needs no bloc widget** — place it outside any builder

---

## 12. General Code Quality Rules

| Rule | Detail |
|------|--------|
| **Naming** | `snake_case` for files, `PascalCase` for classes, `camelCase` for variables |
| **Imports** | Group: dart → flutter → packages → project |
| **Models** | Plain `fromJson`/`toJson`; never decode JSON inline in UI |
| **Assets** | Declared in `pubspec.yaml`; referenced via `AssetsConstants.xxx` |
| **Magic numbers** | Zero tolerance; extract to `AppSpacing`, `AppRadius`, or named constants |
| **print()** | Never — use `debugPrint()` during dev only |
| **Doc comments** | `///` on all public APIs and cubit methods |
| **New colors** | Any design color not yet in `AppColors` → add it immediately before use |

---

## 13. Pixel-Perfect Design Implementation

Every screen and widget **must exactly match** the design.

| Property | Rule |
|----------|------|
| **Font size / weight / color** | Must match design — use `context.tt.*` or `.copyWith(fontSize:)` |
| **Spacing / padding / margin** | Must match — use `AppSpacing.*` constants |
| **Border radius** | Must match — use `AppRadius.*` constants |
| **Icon size** | Must match design value |
| **Shadow / elevation** | Must match design shadow values |

### How to verify
1. Open the design node (Dev Mode) and note every spacing, size, and color value
2. Map each value to the nearest `AppSpacing` / `AppRadius` / `context.cs.*` / `context.tt.*` constant
3. If a value has no constant yet → **add it to the correct file first**, then use it

---

## 14. Strict AppColors Ban in Widgets

`AppColors` exists **only** to define the palette in `AppTheme`. Widget `build()` methods must **never** import or reference it directly.

```dart
// BAD — importing AppColors in a widget file
import 'package:deliveryboy/core/theme/app_colors.dart';
...
color: AppColors.primary
color: AppColors.textPrimary
color: AppColors.backgroundLight

// GOOD — use ColorScheme slot via context.cs
color: context.cs.primary
color: context.cs.onSurface
color: context.cs.surfaceContainerLow
```

> **If a design color has no `colorScheme` slot** → add it to `AppTheme.lightTheme()` first, then access via `context.cs.*`. Never bypass this pipeline.

---

## 15. RTL-Safe Spacing — EdgeInsetsDirectional

The app supports RTL languages. **Never use `EdgeInsets.only(left:)` or `EdgeInsets.only(right:)`** — they break RTL layouts.

```dart
// BAD — absolute left/right won't flip in RTL
padding: EdgeInsets.only(left: 16)
padding: EdgeInsets.only(right: 8)
padding: EdgeInsets.fromLTRB(16, 12, 16, 8)

// GOOD — start/end flip automatically for RTL
padding: EdgeInsetsDirectional.only(start: 16)
padding: EdgeInsetsDirectional.only(end: 8)
padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8)
```

> **`EdgeInsets.symmetric()`** and **`EdgeInsets.all()`** are inherently RTL-safe and may be kept.
>
> The Pickup/Delivery route card (store icon → line → pin icon) and status timelines must be checked explicitly in RTL — directional connector lines are easy to leave visually reversed.

---

## 16. Spacing in Column / Row — Use `spacing` Param

Use the `spacing` parameter in `Column` / `Row` instead of inserting `AppSpacing.*` children.

```dart
// BAD
Column(
  children: [
    AppSpacing.h16,
    Text("Order #1234"),
    AppSpacing.h16,
    Text("Delivered"),
  ],
)

// GOOD
Column(
  spacing: ThemeConstants.spaceL,
  children: [
    Text("Order #1234"),
    Text("Delivered"),
  ],
)
```

> Use `AppSpacing.*` only when a single gap is needed inside a `Stack` or when mixing different gap sizes within one list.

---

## 17. Widget Class vs Private Method

**Use a separate widget class when:**
- The widget has its own logic/state
- The widget is reused in multiple screens (e.g. `StatusChip`, `SlideToConfirmButton`, `OrderCard`)
- The widget is large or complex
- You want independent rebuild control

**Use a private method (`Widget _buildX()`) when:**
- The widget is small
- Used only inside the same screen
- Has no logic/state
- Is just UI grouping

---

## 18. Dark Mode Support

- The app ships with both `lightTheme` and `darkTheme` via `AppTheme`
- `context.isDark` checks current brightness
- Never hardcode colors for dark mode — always use `context.cs.*`
- For assets/images that need a dark variant, use `context.isDark` to pick the correct asset

```dart
// BAD
color: Colors.white  // invisible in light mode

// GOOD
color: context.cs.onPrimary
```

---

## 19. Paginated Lists

Most list screens in this app (Orders, Return Orders, Wallet, Salary, Fund Transfer, Cash Collection, Notifications) are **offset-paginated** with infinite scroll + pull-to-refresh.

This repo now has a shared **`BasePaginationCubit<T>`** (`lib/commons/cubit/base_pagination_cubit.dart`, ported from `ecom_user`), with generic `PaginationState<T>` (`PaginationInitial` / `PaginationLoading` / `PaginationLoaded` / `PaginationError`) and a `PaginatedResponse<T>` model (`lib/commons/models/paginated_response.dart`). Use it for **all new paginated feature cubits** — do not hand-roll `isLoadingMore` / `hasMore` / `loadMore()` again.

- Plain paginated list, no extra filter params → extend `BasePaginationCubit<T>` directly. Implement the `fetcher` getter, call `fetchInitial()` / `fetchMore()` / `refresh()`. Migrated example: `SalaryCubit`.
- Paginated list with filter params (search, status, date range, etc.) → extend `FilteredPaginationCubit<T, F>` with `F` as a record type holding the filters. Implement `buildFetcher(filters)`, call `applyFilters(filters)` to reset + refetch. Migrated examples: `FundTransferCubit`, `OrderCubit`, `EcommerceOrderCubit`, `ReturnOrderCubit`.
- Loaded state needs extra fields beyond list/total (a running summary, a balance, etc.) → **don't force it into `BasePaginationCubit`**. Keep the feature's own hand-rolled state shape (`isFetchingMore`, `hasMore`, `copyWith`) as before. Current examples that stay hand-rolled for this reason: `CashCollectionCubit` (`cashInHand`/`cashCollected`), `WalletCubit` (`balance`).

```dart
// Plain list — extends BasePaginationCubit<T> directly
class SalaryCubit extends BasePaginationCubit<SalaryModel> {
  final SalaryRepository _repository;
  SalaryCubit({SalaryRepository? repository}) : _repository = repository ?? SalaryRepository();

  @override
  PaginationFetcher<SalaryModel> get fetcher => (offset) async {
        final result = await _repository.getSalaries(offset: offset);
        return PaginatedResponse(data: result.data ?? [], total: int.tryParse(result.total ?? '0') ?? 0);
      };
}

// Filtered list — extends FilteredPaginationCubit<T, F> with a record as the filter type
typedef OrderFilters = ({String? status, String? search, DateTime? startDate, DateTime? endDate});

class OrderCubit extends FilteredPaginationCubit<OrderModel, OrderFilters> {
  OrderCubit({OrderRepository? repository})
      : _repository = repository ?? OrderRepository(),
        super((status: null, search: null, startDate: null, endDate: null));
  final OrderRepository _repository;

  @override
  PaginationFetcher<OrderModel> buildFetcher(OrderFilters filters) => (offset) async {
        final result = await _repository.getOrders(offset: offset, filters: filters);
        return PaginatedResponse(data: result.data, total: result.total);
      };
}
```

- **Scroll preload threshold = 150px** (this repo's existing convention — e.g. Salary at 150px, Orders at 150px) from bottom to trigger `fetchMore()`. Match whatever the nearest sibling screen in the same feature area already uses; don't mix 150px and 200px within the same list type.
- **`RefreshIndicator`** wraps the list — calls `cubit.refresh()`.
- **`PaginatedListFooter`** common widget renders the bottom-of-list state: loading spinner while fetching more, or an end-of-list message ("All records loaded" / "No more transfers").
- State field names from the base cubit are generic: `state.data` (not `.salaries`/`.orders`), `state.isFetchingMore` (not `.isLoadingMore`), `state.hasMore`, `state.total`.
- `applyFilters(F filters)` is positional and inherited from `FilteredPaginationCubit` — don't try to override it with named params (signature conflict). If a feature wants a named-arg convenience method, give it a different name (e.g. `updateFilters(...)`) that builds the record and calls `applyFilters(...)`.

---

## 20. Screen Navigation — Args Model Pattern

**Never pass multiple individual params via `Navigator` arguments.** Always wrap navigation data in a single typed `Args` class.

Rules:
- One `Args` class per screen, named `<ScreenName>Args` (e.g., `OrderDetailArgs`, `ChatArgs`)
- Define the `Args` class in the same file as the screen (at the top, before the screen class), OR in `lib/core/routes/` if shared across multiple screens
- All fields should be `required` and non-nullable where possible
- The screen extracts args once: `final args = ModalRoute.of(context)!.settings.arguments as ScreenArgs;`
- The view takes a single `required args` param — no individual fields

```dart
// ── Args ──────────────────────────────────────────────────────────────────────
class ChatArgs {
  final ChatType type;
  final int? orderId;
  final String recipientName;

  const ChatArgs({required this.type, this.orderId, required this.recipientName});
}

// ── Screen ────────────────────────────────────────────────────────────────────
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as ChatArgs;
    return BlocProvider(
      create: (_) => ChatCubit()..connect(args),
      child: _ChatView(args: args),
    );
  }
}

// ── View ──────────────────────────────────────────────────────────────────────
class _ChatView extends StatelessWidget {
  final ChatArgs args;
  const _ChatView({required this.args});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: CustomAppBar(title: args.recipientName),
      body: ...,
    );
  }
}
```

Navigation call-site example:
```dart
// BAD — loose map, breaks on any new field
AppNavigator.pushNamed(context, RouteNames.chat, arguments: {'orderId': order.id, 'name': order.customerName});

// GOOD — single typed object
AppNavigator.pushNamed(context, RouteNames.chat, arguments: ChatArgs(
  type: ChatType.deliveryBoyChat,
  orderId: order.id,
  recipientName: order.customerName,
));
```

Adding a new field → update only the `Args` class + the call-site. No constructor chain to update.

---

## 21. Translation Wrapper — No Raw `Text` for Localised Strings

Every widget that displays a `LanguageLabelKeys.*` constant must call `context.translate(key)` — **never** pass the raw key string to `Text`.

```dart
// ❌ BAD — renders raw key string "cash_in_hand" instead of translated text
Text(LanguageLabelKeys.cashInHand, style: context.tt.bodyMedium)

// ✅ GOOD — resolved to translated string
Text(context.translate(LanguageLabelKeys.cashInHand), style: context.tt.bodyMedium)
```

### When to use what

| Situation | Use |
|-----------|-----|
| Displaying any `LanguageLabelKeys.*` constant | `Text(context.translate(key))` — always |
| Dynamic runtime value (order ID, amount, customer name, date) | `Text(value)` — not a localisation key |
| Button label, AppBar title, status chip label (if status names come from `LanguageLabelKeys`) | `context.translate(LanguageLabelKeys.key)` |

```dart
// Dynamic value — translate not needed
Text('#${order.id}', style: context.tt.labelLarge)
Text(order.deliveredDate, style: context.tt.bodySmall)

// Localised label — translate required
Text(context.translate(LanguageLabelKeys.cashInHand), style: context.tt.titleSmall)
Text(context.translate(LanguageLabelKeys.markAsDelivered), style: context.tt.labelLarge)
```

> Note: order/return **status names** often come directly from the backend (`order_statuses` API, dynamic per store config) rather than from `LanguageLabelKeys` — those are legitimately rendered as raw dynamic text, not translation keys. Don't force-wrap server-provided status labels in `context.translate()`.

---

## CodeCanyon-Specific Rules

- Buyer-configurable values (API URL, app name, feature flags) → `app_config.dart` only
- String translations → `assets/languages/en.json` (buyers add their own JSON files)
- Complex logic must have `///` doc comments — write for a developer unfamiliar with the codebase
- No hardcoded business logic buried inside feature code
- Payment gateway/type constants live in `AppConstants` — never hardcode payment type strings
- Order-status IDs (e.g. `"6"` = Delivered, `"7"` = Cancelled, `"8"` = Returned) are server-defined and can vary per store config — never hardcode status *names* client-side, only compare against the numeric/string IDs returned by the `order_statuses` API
