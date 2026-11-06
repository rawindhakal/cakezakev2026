# cakezake_user App — Coding Standards & Patterns

> This is a CodeCanyon product. All code must be **dynamic**, **clean**, **maintainable**, and easy for buyers to integrate and customize.

---

## 1. Multi-Language Strings (No Hardcoded Text)

- **Never** use raw strings directly in widgets (e.g., `Text("Welcome")`)
- All display text uses a **string key** constant from `LanguageLabelKeys` (`lib/core/localization/language_label_key.dart`)
- Actual values come from the API and are cached locally; `assets/languages/en.json` is the fallback
- `LanguageCubit` (in `lib/core/localization/cubit/`) loads available languages at startup
- In every widget's `build()` method, use the **`context.translate(key)`** extension — it resolves the key via `LocalizationService`

```dart
// BAD
Text("Welcome to CakeZake")

// GOOD
Text(context.translate(LanguageLabelKeys.welcomeToApp))
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
Text("Hello", style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500))

// GOOD — use text theme
Text("Hello", style: context.tt.bodyMedium)

// GOOD — copyWith for variations
Text("Hello", style: context.tt.bodyMedium?.copyWith(color: context.cs.primary, fontWeight: FontWeight.w600))
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
abstract class HomeState {}
class HomeLoading extends HomeState {}
class HomeLoaded extends HomeState { ... }

// ✅ GOOD — sealed class: compiler-enforced, exhaustive, no Equatable needed
// ── States (top of the file, same file as cubit) ──────────────────
sealed class HomeState {}
final class HomeInitial  extends HomeState {}
final class HomeLoading  extends HomeState {}
final class HomeLoaded   extends HomeState { final HomeData data; HomeLoaded(this.data); }
final class HomeError    extends HomeState { final String message; HomeError(this.message); }

// ── Cubit ─────────────────────────────────────────────────────────
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repo) : super(HomeInitial());
  final HomeRepository _repo;

  Future<void> fetchHome() async {
    emit(HomeLoading());
    try {
      final data = await _repo.getHomeData();
      emit(HomeLoaded(data));
    } on ApiException catch (e) {
      emit(HomeError(e.message));
    } catch (_) {
      emit(HomeError(context.translate(LanguageLabelKeys.somethingWentWrong)));
    }
  }
}
```

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
  - `AppButton` (primary, outlined variants)
  - `AppTextField`
  - `LoadingWidget` / shimmer
  - `EmptyStateWidget`
  - `AppNoInternetWidget`
  - `AppNetworkImage` (with placeholder/error)
  - `AppSnackBar`
  - `CustomAppBar`

---

## 5. Folder Structure

Follow [CakeZake Flutter Folder Structure](https://cakezake-in.github.io/flutter-folder-structure/) strictly. See `FOLDER_STRUCTURE.md` for full details.

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
│   │   ├── app_radius.dart          ← BorderRadius constants (r8, r12…)
│   │   └── app_sizes.dart           ← responsive sizes (tablet breakpoints)
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
│   └── routes/
│       ├── route_names.dart         ← route string constants
│       ├── app_router.dart          ← MaterialApp route configuration
│       └── product_detail_args.dart ← typed args models
├── commons/
│   ├── widgets/                     ← shared reusable widgets
│   ├── models/
│   ├── cubit/
│   │   ├── connectivity_cubit.dart  ← network state (global)
│   │   └── settings_cubit.dart      ← theme/language prefs (global)
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

### When to use which

| Need | Use |
|------|-----|
| `SizedBox` gap as a child widget | `AppSpacing.h16` / `AppSpacing.w8` |
| `Column(spacing:)` / `Row(spacing:)` param | `ThemeConstants.spaceL` |
| `EdgeInsets.all()` / `EdgeInsets.symmetric()` | `ThemeConstants.paddingL` |
| `BorderRadius.circular()` | → use `AppRadius.r12` directly |
| Component heights / icon sizes / border widths | `ThemeConstants.inputHeight` etc. |

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

### ThemeConstants reference (double values)

| Constant | Value | Use |
|----------|-------|-----|
| `ThemeConstants.spaceXS` | 4 | Column/Row spacing, tiny gaps |
| `ThemeConstants.spaceS` | 8 | Small spacing |
| `ThemeConstants.spaceM` | 12 | Card inner gap |
| `ThemeConstants.spaceL` | 16 | Standard spacing |
| `ThemeConstants.spaceXL` | 20 | Medium sections |
| `ThemeConstants.spaceXXL` | 24 | Major sections |
| `ThemeConstants.spaceXXXL` | 32 | Large dividers |
| `ThemeConstants.paddingL` | 16 | `EdgeInsets.all(16)` |
| `ThemeConstants.inputHeight` | 48 | All text inputs |
| `ThemeConstants.buttonHeightPrimary` | 52 | Filled buttons |
| `ThemeConstants.appBarHeight` | 56 | Top app bars |
| `ThemeConstants.bottomBarHeight` | 60 | Bottom nav bar |
| `ThemeConstants.iconM` | 20 | Standard icons |
| `ThemeConstants.iconL` | 24 | Nav bar icons |
| `ThemeConstants.borderThin` | 1 | Standard borders |
| `ThemeConstants.loaderSize` | 20 | Button loaders |

### AppRadius reference

| Constant | Value | Use |
|----------|-------|-----|
| `AppRadius.r4` | 4px | Chips, badges |
| `AppRadius.r8` | 8px | Input fields, small cards |
| `AppRadius.r12` | 12px | Cards, buttons |
| `AppRadius.r16` | 16px | Large cards |
| `AppRadius.r24` | 24px | Pill buttons |
| `AppRadius.cardRadius` | 16px | All cards |
| `AppRadius.buttonRadius` | 12px | All buttons |
| `AppRadius.bottomSheetRadius` | top 24px | Bottom sheets |

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
Text("hi", style: TextStyle(color: AppColors.error))

// GOOD
Container(color: context.cs.primary)
Text("hi", style: context.tt.bodyMedium?.copyWith(color: context.cs.error))
```

### ColorScheme mapping

| `context.cs.xxx` | AppColors equivalent | Hex (light) |
|-----------------|---------------------|-------------|
| `primary` | `AppColors.primary` | `#2E7D32` |
| `primaryContainer` | `AppColors.primaryContainer` | `#E8F5E9` |
| `secondary` | `AppColors.primaryLight` | `#4CAF50` |
| `surface` | `AppColors.surfaceLight` | `#FFFFFF` |
| `onSurface` | `AppColors.textPrimary` | `#1A1A1A` |
| `onSurfaceVariant` | `AppColors.textSecondary` | `#616161` |
| `outline` | `AppColors.border` | `#E0E0E0` |
| `outlineVariant` | `AppColors.divider` | `#EEEEEE` |
| `error` | `AppColors.error` | `#C62828` |
| `surfaceContainerLow` | `AppColors.backgroundLight` | `#F5F6FA` |

### Dark mode
- Use `context.isDark` to conditionally apply assets or decorations that need a dark variant
- Never hardcode light-only colors — `context.cs.*` handles both modes automatically

---

## 8. Dart Dot Shorthands (Compact Syntax)

Requires Dart ≥ 3.10. Use dot shorthand **everywhere** the type is inferable from context.

```dart
// BAD
Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start)
Text("hi", textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)
Container(decoration: BoxDecoration(shape: BoxShape.circle))

// GOOD
Row(mainAxisAlignment: .center, crossAxisAlignment: .start)
Text("hi", textAlign: .center, overflow: .ellipsis)
Container(decoration: BoxDecoration(shape: .circle))
```

---

## 9. Navigation — AppNavigator

- **Never** call `Navigator` directly in widget `build()` methods
- Use `AppNavigator` (`lib/core/constants/navigation_service.dart`) for all navigation
- Route name strings come from `RouteNames` (`lib/core/routes/route_names.dart`)

```dart
// BAD
Navigator.pushNamed(context, '/product-detail', arguments: args);
Navigator.pushReplacementNamed(context, '/main');
Navigator.of(context).pushAndRemoveUntil(...);

// GOOD
AppNavigator.pushNamed(context, RouteNames.productDetail, arguments: args);
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
// lib/core/routes/product_detail_args.dart (or near the screen)
class ProductDetailArgs {
  final int productId;
  final String? slug;

  const ProductDetailArgs({required this.productId, this.slug});
}

// Navigation call-site
AppNavigator.pushNamed(
  context,
  RouteNames.productDetail,
  arguments: ProductDetailArgs(productId: product.id, slug: product.slug),
);

// In the screen
final args = ModalRoute.of(context)!.settings.arguments as ProductDetailArgs;
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
class ProductRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<ProductModel>> getProducts({int offset = 0}) async {
    final result = await _apiClient.get(
      ApiEndpoints.products,
      queryParameters: {ApiParameters.offset: offset},
    );
    return (result['data'] as List)
        .map((e) => ProductModel.fromJson(Map.from(e)))
        .toList();
    // ApiException from ApiClient propagates automatically
  }
}
```

### Cubit — two-tier catch

```dart
Future<void> fetchProducts() async {
  emit(ProductLoading());
  try {
    final products = await _repo.getProducts();
    emit(ProductLoaded(products));
  } on ApiException catch (e) {
    emit(ProductError(e.message));        // ← API/network message
  } catch (_) {
    emit(ProductError(context.translate(LanguageLabelKeys.somethingWentWrong)));  // ← parsing failures
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
// fromJson type mismatches, null errors etc. will crash or show raw Dart messages
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
  return BlocListener<ProductCubit, ProductState>(
    listener: (context, state) {
      if (state is ProductError) {
        AppSnackBar.showError(context, state.message);
      }
    },
    child: AppScaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildAddToCartButton(),
    ),
  );
}

// ✅ BlocSelector — rebuilds only when loading changes
Widget _buildAddToCartButton() {
  return BlocSelector<ProductCubit, ProductState, bool>(
    selector: (state) => state is ProductLoading,
    builder: (context, isLoading) => AppButton(
      label: context.translate(LanguageLabelKeys.addToCart),
      isLoading: isLoading,
      onTap: isLoading ? null : () => context.read<ProductCubit>().addToCart(),
    ),
  );
}

// ✅ BlocBuilder — rebuilds the list
Widget _buildBody() {
  return BlocBuilder<ProductCubit, ProductState>(
    builder: (context, state) {
      if (state is ProductLoading) return const LoadingWidget();
      if (state is ProductError) return EmptyStateWidget(message: state.message);
      if (state is ProductLoaded) return _ProductList(products: state.products);
      return const SizedBox.shrink();
    },
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
import 'package:customer/core/theme/app_colors.dart';
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

---

## 16. Spacing in Column / Row — Use `spacing` Param

Use the `spacing` parameter in `Column` / `Row` instead of inserting `AppSpacing.*` children.

```dart
// BAD
Column(
  children: [
    AppSpacing.h16,
    Text("Hello"),
    AppSpacing.h16,
    Text("World"),
  ],
)

// GOOD
Column(
  spacing: ThemeConstants.spaceL,
  children: [
    Text("Hello"),
    Text("World"),
  ],
)
```

> Use `AppSpacing.*` only when a single gap is needed inside a `Stack` or when mixing different gap sizes within one list.

---

## 17. Widget Class vs Private Method

**Use a separate widget class when:**
- The widget has its own logic/state
- The widget is reused in multiple screens
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

## 19. Paginated APIs — BasePaginationCubit

Use `BasePaginationCubit<T>` for **any API that returns a paginated list** (offset + total).
**Do NOT use it for simple non-paginated APIs** — it adds unnecessary overhead for single-page responses.

### When to use

| Scenario | Use |
|----------|-----|
| API returns `{ data: [...], total: N }` with offset-based pagination | ✅ `BasePaginationCubit<T>` |
| API returns a flat list, no pagination | ❌ Regular cubit |
| Single-item fetch (profile, settings, detail) | ❌ Regular cubit |
| Mutation (create, update, delete) | ❌ Regular cubit |

### Problem it solves

Multiple cubits (`NotificationsCubit`, `CompletedOrderCubit`, `BlogCubit`, `TransactionCubit`…) each repeat ~50 lines of identical pagination boilerplate: `isLoadingMore`, `hasMore`, `copyWith`, `loadMore()`, `refresh()`. `BasePaginationCubit` eliminates all of it.

### States

```dart
PaginationInitial<T>
PaginationLoading<T>   // initial full-screen load
PaginationLoaded<T>
  .data              → List<T>
  .total             → total count from API
  .isFetchingMore    → true while appending next page
  .hasMore           → data.length < total
PaginationError<T>
  .message           → error string
```

### Feature cubit — one-liner

```dart
// ✅ GOOD — thin cubit, no boilerplate
class NotificationsCubit extends BasePaginationCubit<NotificationModelData> {
  NotificationsCubit()
    : super(fetcher: (offset) => NotificationRepository().getNotifications(offset: offset));
}

// ❌ BAD — 50 lines of duplicate isLoadingMore / hasMore / copyWith boilerplate
class NotificationsCubit extends Cubit<NotificationsState> {
  // loadMore(), refresh(), copyWith(), isLoadingMore, hasMore — all manually written
}
```

### Repository — return `PaginatedResponse<T>`

```dart
Future<PaginatedResponse<NotificationModelData>> getNotifications({int offset = 0}) async {
  final result = await _apiClient.get(
    ApiEndpoints.getNotifications,
    queryParameters: {ApiParameters.offset: offset, ApiParameters.limit: AppConfig.pageLimit},
  );
  return PaginatedResponse.fromJson(result, NotificationModelData.fromJson);
}
```

### Screen — full pattern

```dart
// Typedef aliases reduce generic noise in BlocBuilder signatures
typedef NotiState   = PaginationState<NotificationModelData>;
typedef NotiLoaded  = PaginationLoaded<NotificationModelData>;
typedef NotiError   = PaginationError<NotificationModelData>;
typedef NotiLoading = PaginationLoading<NotificationModelData>;

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scroll = ScrollController();
  NotificationsCubit get cubit => context.read();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.maxScrollExtent - _scroll.position.pixels <= 200) {
      cubit.fetchMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _buildBody() {
    return BlocBuilder<NotificationsCubit, NotiState>(
      builder: (context, state) {
        if (state is NotiLoading) return const LoadingWidget();
        if (state is NotiError)   return EmptyStateWidget(message: state.message);
        if (state is NotiLoaded) {
          if (state.data.isEmpty) return EmptyStateWidget(message: '...');
          return RefreshIndicator(
            onRefresh: () async => cubit.refresh(),
            child: ListView.builder(
              controller: _scroll,
              itemCount: state.data.length + (state.isFetchingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.data.length) return const LoadingWidget();
                return _NotificationTile(item: state.data[index]);
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
```

### Rules
- **Typedef aliases** for generic state types — keeps `BlocBuilder` signatures readable
- **Scroll preload threshold = 200px** — trigger `fetchMore()` before user hits the bottom
- **`RefreshIndicator`** wraps the list — calls `cubit.refresh()`
- **Bottom slot** in `itemBuilder`: when `index >= data.length`, show `LoadingWidget`

---

## 20. Screen Navigation — Args Model Pattern

**Never pass multiple individual params via `Navigator` arguments.** Always wrap navigation data in a single typed `Args` class.

Rules:
- One `Args` class per screen, named `<ScreenName>Args` (e.g., `ProductDetailArgs`)
- Define the `Args` class in the same file as the screen (at the top, before the screen class), OR in `lib/core/routes/` if shared across multiple screens
- All fields should be `required` and non-nullable where possible
- The screen extracts args once: `final args = ModalRoute.of(context)!.settings.arguments as ScreenArgs;`
- The view takes a single `required args` param — no individual fields

```dart
// ── Args ──────────────────────────────────────────────────────────────────────
class BlogDetailArgs {
  final int blogId;
  final String title;

  const BlogDetailArgs({required this.blogId, required this.title});
}

// ── Screen ────────────────────────────────────────────────────────────────────
class BlogDetailScreen extends StatelessWidget {
  const BlogDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as BlogDetailArgs;
    return BlocProvider(
      create: (_) => BlogDetailCubit()..fetchDetail(args.blogId),
      child: _BlogDetailView(args: args),
    );
  }
}

// ── View ──────────────────────────────────────────────────────────────────────
class _BlogDetailView extends StatelessWidget {
  final BlogDetailArgs args;
  const _BlogDetailView({required this.args});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: CustomAppBar(title: args.title),
      body: ...,
    );
  }
}
```

Navigation call-site example:
```dart
// BAD — loose map, breaks on any new field
AppNavigator.pushNamed(context, RouteNames.blogDetail, arguments: {'blogId': blog.id, 'title': blog.title});

// GOOD — single typed object
AppNavigator.pushNamed(context, RouteNames.blogDetail, arguments: BlogDetailArgs(
  blogId: blog.id,
  title: blog.title,
));
```

Adding a new field → update only `BlogDetailArgs` + the call-site. No constructor chain to update.

---

## 21. Translation Wrapper — No Raw `Text` for Localised Strings

Every widget that displays a `LanguageLabelKeys.*` constant must call `context.translate(key)` — **never** pass the raw key string to `Text`.

```dart
// ❌ BAD — renders raw key string "login" instead of translated text
Text(LanguageLabelKeys.login, style: context.tt.bodyMedium)

// ✅ GOOD — resolved to translated string
Text(context.translate(LanguageLabelKeys.login), style: context.tt.bodyMedium)
```

### When to use what

| Situation | Use |
|-----------|-----|
| Displaying any `LanguageLabelKeys.*` constant | `Text(context.translate(key))` — always |
| Dynamic runtime value (price, username, date) | `Text(value)` — not a localisation key |
| Button label, AppBar title | `context.translate(LanguageLabelKeys.key)` |

```dart
// Dynamic value — translate not needed
Text(r'$1032.00', style: context.tt.labelLarge)
Text(dateText, style: context.tt.bodySmall)

// Localised label — translate required
Text(context.translate(LanguageLabelKeys.subtotal), style: context.tt.titleSmall)
Text(context.translate(LanguageLabelKeys.totalAmount), style: context.tt.labelLarge)
```

---

## 22. Screen Root — Use `AppScaffold`, Not Raw `Scaffold`

**Never** build a screen with a raw `Scaffold`. Every screen's root uses **`AppScaffold`** (`lib/commons/widgets/app_scaffold.dart`). It wraps `Scaffold` and centralises behaviour that every screen needs — so buyers get consistent status/nav-bar styling and safe-area handling for free.

### What `AppScaffold` handles for you
- **System UI overlay styling** — status-bar + system-nav-bar colors and icon brightness auto-resolve for light/dark mode (`AnnotatedRegion<SystemUiOverlayStyle>`)
- **Bottom-nav inset** — reserves the measured height of `bottomNavigationBar` (re-measures after layout, so multi-line bars never overlap the body) and collapses it when the keyboard opens
- **System nav-bar color** — sits behind the bottom nav surface when present, otherwise the scaffold background

```dart
// ❌ BAD — raw Scaffold: no system-UI styling, manual safe-area/bottom-nav handling
Scaffold(
  appBar: CustomAppBar(title: '...'),
  body: _buildBody(),
  bottomNavigationBar: _buildBottomBar(),
)

// ✅ GOOD — AppScaffold
AppScaffold(
  appBar: CustomAppBar(title: '...'),
  body: _buildBody(),
  bottomNavigationBar: _buildBottomBar(),
)
```

### API

| Param | Type | Purpose |
|-------|------|---------|
| `body` | `Widget` (required) | Screen content |
| `appBar` | `PreferredSizeWidget?` | Usually `CustomAppBar` |
| `bottomNavigationBar` | `Widget?` | Bottom nav / floating action bar — its height is auto-reserved |
| `backgroundColor` | `Color?` | Defaults to `theme.scaffoldBackgroundColor` |
| `applyBottomInset` | `bool` (default `true`) | Set **`false`** when the screen positions its own flush-to-bottom overlay (e.g. a bar meant to sit against the bottom nav) — otherwise the reserved bottom padding leaves a gap |

---

## 23. Decorations — Use `AppDecorations`, Not Inline `BoxDecoration`

**Never** write an inline `BoxDecoration` / `OutlineInputBorder` in a widget. Use a named preset from **`AppDecorations`** (`lib/core/theme/app_decorations.dart`). This keeps corner radii, borders, and shadows consistent app-wide and lets buyers restyle from one place.

```dart
// ❌ BAD — inline decoration, magic radius, ad-hoc shadow
Container(
  decoration: BoxDecoration(
    color: context.cs.surface,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
  ),
)

// ✅ GOOD — named preset
Container(
  decoration: AppDecorations.shadowedCard(
    color: context.cs.surface,
    shadowColor: context.cs.shadow,
  ),
)
```

### Preset reference

| Method | Use |
|--------|-----|
| `AppDecorations.dragHandle({color})` | Bottom-sheet drag handle bar |
| `AppDecorations.primaryIconBox({color, borderRadius})` | Square tinted icon box |
| `AppDecorations.outlinedCard({color?, borderColor, borderRadius, boxShadow?})` | Bordered card (color optional = no fill) |
| `AppDecorations.shadowedCard({color, shadowColor, borderRadius, blurRadius, offset})` | Card with drop shadow |
| `AppDecorations.bottomSheet({color, borderRadius, boxShadow?})` | Bottom-sheet container body |
| `AppDecorations.bottomSheetFooter({color, borderColor})` | Sheet footer / action-button row |
| `AppDecorations.inputBorder({color, width, borderRadius})` | Single `OutlineInputBorder` for a field |
| `AppDecorations.inputBorderSet(cs, {borderRadius})` | Full themed border set (border/enabled/focused/error/focusedError) |
| `AppDecorations.circleIconBadge({color})` | Circular icon badge |
| `AppDecorations.selectableOption({primaryColor, outlineColor, selected, borderRadius})` | Flat selectable option tile |
| `AppDecorations.box({color?, gradient?, borderRadius?, shape, border?, boxShadow?})` | Generic one-off builder (gradients, conditional shadows) — use only when no named preset fits |

### Rules
- **Prefer a named preset** whose shape matches your need
- Use **`AppDecorations.box()`** only for genuine one-offs (gradient fills, per-call borders) that no preset covers
- Colors passed in must come from **`context.cs.*`** (never `AppColors.*` — see §14)
- Radii inside presets come from **`AppRadius.*`** — don't pass raw pixel values where a preset already defaults to one

---

## CodeCanyon-Specific Rules

- Buyer-configurable values (API URL, app name, feature flags) → `app_config.dart` only
- String translations → `assets/languages/en.json` (buyers add their own JSON files)
- Complex logic must have `///` doc comments — write for a developer unfamiliar with the codebase
- No hardcoded business logic buried inside feature code
- Payment gateway type constants live in `AppConstants` — never hardcode payment type strings
