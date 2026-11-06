# cakezake_customer — Deep User Manual

Customer-facing Flutter e-commerce app. Screen-by-screen, field-by-field, flow-by-flow reference for building end-user documentation.

Stack: Flutter, Cubit, Dio, Hive, Firebase.

---

## 1. App Boot Flow

### Splash Screen
- Shows logo + loading animation on primary-color background.
- No internet → full-screen "No Internet" overlay on top, auto-retries when connection returns.
- **Boot sequence:**
  1. Load app settings from server.
  2. If maintenance flag ON → redirect to **Maintenance screen**, back gesture disabled, user fully blocked.
  3. Check forced/optional app update (store version compare) → blocking dialog if forced, dismissible if optional.
  4. Load language list, then translation strings for selected/default language (falls back to cached translations on failure).
  5. Navigate to **Onboarding** (first run) or **Main/Home** (returning user).

### Maintenance Screen
- Illustration + "Under Maintenance" title + admin's custom remark (or default message).
- Back button disabled — app fully blocked until maintenance lifts + restart.

### Onboarding Screen
- 3 auto-advancing (2s) swipeable slides: Shop / Delivery / Payment themed. Manual swipe resets timer. Dot indicators.
- **Skip** (top-right, all pages): marks onboarding seen → opens Location Setup sheet → if location set, goes straight to **Main/Home** (guest browsing, no login required). If sheet dismissed without picking location, stays on onboarding.
- **Next/Get Started** (bottom): pages 1-2 advance; page 3 button = "Get Started" → marks onboarding seen → goes to **Sign In screen** (login path, not guest).

---

## 2. Auth

Behavior driven by admin-configured flags: `phoneLogin`, `emailLogin`, `googleLogin`, `appleLogin` (iOS only), `firebaseAuthentication`, `customSmsGatewayOtpBased` (Custom SMS), `phoneAuthPassword`.

### Sign In Screen
- **Skip** (top-right) → Main screen, guest mode.
- Mode toggle Email/Phone shown only if both enabled; else single mode shown.
- **Email mode:** Email (required, format validated), Password (required, min 6 chars). "Forgot password?" → Forgot Password (type=email).
- **Phone mode:** Phone + country-code picker (required, min 10 digits). Password field appears only if phone+password enabled. "Forgot password?" → Forgot Password (type=phone).
- Primary button label: "Sign In" (email/phone+password) or "Send OTP" (phone+OTP).
- Tap outcomes: email→sign-in API; phone+password→sign-in API; phone+Firebase OTP→send OTP→OTP Verification screen; phone+Custom SMS OTP→send OTP→OTP Verification screen.
- Social buttons (Google always if enabled; Apple iOS-only if enabled) → native flow → backend login.
- **Results:**
  - Success → guest cart synced into account → enter app.
  - USER_NOT_FOUND/USER_NOT_EXIST/EMAIL_NOT_VERIFIED → redirect to **Sign Up**, pre-filled with known data.
  - Other errors → red snackbar with server message.
- "Don't have an account? Sign Up" link at bottom.

### Sign Up Screen
- Header differs: social sign-up = "Complete your profile to continue"; else "Fill in your details to get started".
- Fields: Full Name (required, min 2 chars; read-only for social), Email (required unless phone-only mode; read-only for social), Phone+country (required for phone signup; read-only if pre-verified), Country dropdown, Password+Confirm (only for Email mode or Phone+password mode; min 6 chars, must match), Referral Code (optional).
- Button label: "Send OTP" (phone, unverified) or "Create Account".
- **Phone+OTP flow:** fill form → Send OTP → OTP sent (Firebase/Custom SMS) → Register OTP screen (6-digit) → success = account created + logged in + cart synced. Resend has 59s countdown.
- **Email flow:** fill form → Create Account → if OTP required, Register OTP screen (email OTP) → success = registered+logged in. If no OTP required: token returned = auto-login; else message shown, user sent to Sign In manually.
- **Social flow:** name/email pre-filled read-only, add phone/password if required → Create Account → direct registration, no OTP.
- Errors → red snackbar with server text. "Already have an account? Sign In" link.

### OTP Verification Screen (sign-in path)
- "Code sent to [+cc] [phone]", 6-digit boxes. Empty/incomplete → "Enter OTP" error.
- Verify → Custom SMS or Firebase verify → success = cart synced + enter app. USER_NOT_FOUND → redirect to Sign Up, phone pre-filled+verified.
- Resend: 59s countdown, resets on tap. "Change phone number" link → back to Sign In.

### Register OTP Screen (sign-up path)
- Same 6-digit UI, used for finishing registration (email/Firebase-phone/Custom SMS-phone OTP).
- Header: "Code sent to [email or phone]".
- Verify → completes account creation + logs in + syncs cart, or error snackbar.
- Resend re-triggers original OTP send; shows confirmation toast; resets countdown.

### Forgot Password Screen — 3 phases
1. **Enter identifier**: phone (cc+number, min 10 digits) or email (format validated) → "Send OTP".
2. **Enter OTP**: header "Code sent to [x]"; 6-digit, must be exactly 6 or "Enter 6-digit OTP" error.
   - Email flow: New Password + Confirm Password shown alongside OTP; "Reset Password" verifies+resets in one step.
   - Phone flow: OTP + "Verify OTP" only; password fields come in phase 3.
   - Resend: 59s countdown.
3. **Set new password** (phone only): New Password (min 6) + Confirm (must match) → "Reset Password" → success = green snackbar + navigate back to Sign In.
- Errors at any phase → red snackbar with server text.

### Change Password (bottom sheet, Account Settings)
- Only for Email-auth accounts.
- Old Password, New Password, Confirm New Password (all required, min 6, confirm must match).
- Warning: "You'll be logged out after changing your password."
- Success → sheet closes, green snackbar, forced logout → Sign In screen. Error → red snackbar.

### Delete Account (confirmation dialog)
- Title "Delete Account", warning body. Cancel / Delete (spinner while processing).
- Success → redirect to Sign In, account removed, local auth cleared. Error → red snackbar.

### Logout (confirmation dialog)
- "Logout" / "Are you sure you want to logout?" Cancel / Logout (spinner).
- Success → Sign In screen, back stack cleared. Error → red snackbar.

---

## 3. Profile

### Profile Screen
- No internet → full-screen no-internet state.
- Header card: avatar, name, email/phone. Guest → "Guest" + "Login/Register" link. Logged in → "Edit" pill → Edit Profile.
- **Personal Data** (logged-in only): My Orders, My Addresses, Transaction History, Wallet History, Refer & Earn.
- **Preferences** (always): "Change Language" row (shows current lang, opens language sheet); "Change Theme" row (shows current mode, opens appearance sheet).
- **Quick Access**: Notifications list; "Share App" (opens store link externally).
- **Help & Support**: "Chat with Support" (logged-in only); Blog; "Rate Us" (external store link).
- **Help & Policies**: FAQ direct link + accordion: About Us, Contact Us, Privacy Policy, Terms & Conditions, Return Policy, Shipping Policy, Cancellation Policy.
- **Account** (logged-in only): Settings → Account Settings; Logout → confirmation dialog.

### Account Settings Screen
- Notification Settings (always) → Notification Settings screen.
- Change Password (Email-auth accounts only) → bottom sheet.
- Delete Account (logged-in only) → confirmation dialog.

### Edit Profile Screen
- Avatar with camera badge → bottom sheet: Take Photo / Choose from Gallery (85% quality cap).
- Full Name (required, min 2), Email (optional, valid format if given; read-only for Google/Apple/Email auth types), Mobile+country (min 10 digits; read-only if Phone-auth), Country dropdown (prefilled from profile/store default).
- "Update Profile" (sticky bottom) → success = green "Profile updated successfully" + close; error = red snackbar; loading = spinner.

### Refer & Earn Screen
- Hero card: dynamic bonus amount/currency from country settings.
- Referral code card: large code text, Copy icon (→ clipboard + green snackbar), "Share Code" (native share sheet with pre-written message).
- Rewards breakdown (conditional): Min Order, You Earn, Friend Earns.
- "How It Works" 4-step static explainer: Share Code → Friend Registers → Friend Orders (delivered, past return window) → Both Earn Bonus (credited to wallets).

### Policies Screen
- Generic viewer for About/Contact/Privacy/Terms/Return/Shipping/Cancellation.
- Renders server HTML. No internet → full-screen state (auto-retry). Loading spinner, error+retry. Empty content → "[Policy] content not available".

---

## 4. Notifications

### Notifications List
- Paginated, infinite scroll, pull-to-refresh. Card: title, 2-line preview, image or bell icon, relative date.
- Tap routes by type: `url`→external browser; `product`→Product Detail; `category`→sub-category listing; `user`/other→no-op.
- Empty: "No notifications yet". Error: message + "Pull to refresh" + retry.

### Notification Settings Screen
- 3 pill tabs: **Email / Notification (push) / SMS**. Each lists order-status events (from server) with per-channel toggle.
- **Not auto-save** — sticky "Save Settings" button required. Success → green "Settings saved" + reload. Error → red snackbar. Loading → button spinner.

---

## 5. Global Settings (Language & Theme)

### Language (Profile → "Change Language")
- Bottom sheet "Select Language", radio list (name + code) from API.
- Tap → spinner next to title → saves locally (id/code/type) → app retranslates **live, no restart**. If logged in, FCM token updated to reflect language. Sheet auto-closes. Failure → inline error, sheet stays open.

### Theme (Profile → "Change Theme")
- Bottom sheet "Appearance", radio: **System Default / Light / Dark**.
- Tap applies instantly app-wide, no separate save step, sheet auto-closes.

---

## 6. Bottom Navigation & Floating Cart Bar

### Main Screen
- 4 tabs: Home, Categories, Favourites, Profile — animated sliding underline. No numeric badges anywhere.
- Screens kept alive via `IndexedStack` (state preserved on tab switch).
- Cart auto-loads from API on entering main screen (if logged in).

### Floating Cart Bar
- Overlay pinned above bottom nav, shown on Home/Categories/Favourites tabs only — **hidden on Profile tab**.
- Hidden when cart empty; slides up + morphs from a small circular bubble into full pill on first add; shakes on subsequent adds; morphs back down when cart returns to 0.
- Pill shows: up to 3 overlapping product thumbnails, "View cart" text, "N item(s)" count, forward arrow.
- Tap anywhere → navigates to Checkout.

---

## 7. Home

### Location Gate
- No saved delivery location → Home tab replaced by "Where should we deliver?" prompt with "Set Delivery Location" button → opens location-setup sheet. App also silently requests OS location permission on start; auto-opens location sheet if granted and none saved yet.

### Header (pinned, collapses on scroll)
- Location label/address → tap reopens location-setup sheet.
- "Quick" vs "Shop All" channel toggle (if store offers both) — switching reloads home layout + switches cart context.
- Search bar with animated rotating placeholder + mic icon → Product Search screen.
- Horizontal category tabs → filters home content, scrolls to top on select.
- Delivery time/distance indicator (if provided).

### Body (server-driven sections, pull-to-refresh reloads cart too)
- Banner carousels (5 styles: full-width, peek, card, story/progress-bar, spotlight) → tap opens product/category/URL.
- Category blocks (grid/circular/horizontal) → tap opens Category screen.
- Brand blocks → tap currently no-op.
- Product blocks (grid/horizontal/list) with "View more" → Product Grid screen scoped to that section.
- Grid banners (2-col image) → tap opens product/category/URL.
- Optional home popup dialog (promo image, once per session or every visit per admin setting).
- States: loading spinner; error = illustration + message + "pull to refresh" + retry; empty layout = "No content available".

---

## 8. Category

### Category Screen
- Paginated grid (4 col phone / 6 tablet), infinite scroll, pull-to-refresh. Empty: "No categories found." Error + retry.
- Tap: has sub-categories → Sub-Category screen with sidebar; leaf category → Sub-Category screen directly (sidebar hidden).

### Sub-Category Screen
- Left sidebar (when present): scrollable sub-category avatars, infinite scroll.
- Right panel: filter bar — "Filters" pill (brand/attribute/price-range sheet) + "Sort" pill (Default, Newest First, Price High→Low, Price Low→High, Discount High→Low, Popularity) — highlighted when active.
- Product grid (2-5 cols depending on sidebar/tablet), infinite scroll.
- Empty: "No products in this category."

---

## 9. Products

### Product Card (used everywhere)
- Image carousel (swipe variant images) + pagination dots, product-type badge, favourite heart (top-right; login required, redirects if guest; heart-burst animation on add).
- Out of stock → "Sold Out" ribbon, card dimmed 45%, add-to-cart button hidden.
- Price row: current + struck-through original + "XX% OFF" dashed label.
- Name (3-line max), star rating + review count (hidden if none).
- "Time to deliver"; low-stock warning if flagged ("X left in stock").
- Add-to-cart "+": single-variant adds directly with qty stepper (capped at `totalAllowedQuantity`); multi-variant opens bottom sheet listing each variant (image, unit, price/discount, own add control).

### Product Detail Screen
- Opens as "peek card" expanding to full screen on scroll (hero-flight animation); pull-down while collapsed dismisses back.
- Image gallery (variant-specific if selected) + dot indicators, tap → full-screen viewer. "Key features" side-drawer (category/brand/made-in/sold-by). App bar: back, share (native share + deep link), favourite.
- Info block: name, short description, rating badge, delivery-time chip. Prescription-required banner for pharmacy products.
- Variant selectors: chip row per attribute (Color, Size, etc); unavailable combos shown disabled (not hidden).
- Policy strip: Return (days or "Not available"), COD (available/not), Cancellable (available/not).
- Expandable "Product Info" (full HTML description) and custom spec sections (label/value + optional images, store-configurable).
- Ratings & Reviews (only if ≥1 rating): average score, 5-star histogram, review-photo strip, individual review tiles (avatar, name, date, colored star badge, text, images), "Load more" pagination.
- "Upgrade your order" upsell grid, "Similar Products" grid (max 6 + View more), "Recently Visited" grid (max 6 + View more).
- Bottom bar: price + "Sold Out" pill or add-to-cart stepper. First add-of-session auto-scrolls to Upsell section.
- States: loading = shimmer skeleton matching layout; error = icon+message+Retry; not-found = explicit message.

### Ratings — submission
- **Not from Product Detail** — submitted from Orders (rate a delivered product) via "Rate Product"/"Write a Review" bottom sheet: 5-star tap (required, error if 0 stars), optional multiline text, optional multiple photos (add/remove). Submit → success dialog or error snackbar. Same sheet reused to edit existing rating.

### Similar / Recently Visited / Upsell
- 3-col grids, capped 6 + "View more" (reuses fetched data, no extra call). Recently-visited auto-tracked on every product-detail open.

### Product Search
- Search bar, 500ms debounce. Before typing: "Recent Searches" list (re-run/remove/clear-all) or "Start typing to search" empty prompt.
- Results grid (3 col phone / 5 tablet), skeleton while loading.
- Sort pill only (same 6 options as category) — no brand/price/attribute filter on search itself.
- Empty: "No results found." Infinite scroll; floating cart bar shows once items in cart; add-to-cart directly from grid.

### Filters (shared sheet: Category/Sub-category/Product-grid)
- Left rail groups + right options: **Brand** (checklist w/ logos, multi-select), **Attribute filters** (per-category, multi-select), **Price Range** (slider bounded by actual catalog min/max).
- "Clear All" / "Apply" (re-fetches). Loads async, updates live.

### Sort (Category/Sub-category/Product grid/Search)
Default, Newest First, Price High→Low, Price Low→High, Discount High→Low, Popularity.

---

## 10. Favourites

- Login required to load; heart toggle elsewhere redirects guest to Login.
- Grid/List view toggle in app bar, both remember scroll, infinite scroll + pull-to-refresh.
- Add/remove: optimistic UI flip, reverts silently on API failure. Removing while on Favourites screen removes it from the visible list immediately. Heart-burst animation only on add.
- Empty: "No wishlist found"/"No favourites". Error: illustration+message+retry.
- No sort/filter — only grid/list toggle.

---

## 11. Cart

**No dedicated Cart screen** — cart lives inside Checkout. Add/remove/qty happen inline on grid/detail/search tiles via cart button.

### Add to Cart
- "ADD" label at qty 0 → morphs into stepper (–qty+) once tapped. Local state in `CartCubit`, instant optimistic update + haptic + bounce animation.
- Multi-variant item: "ADD" + "N options" sub-label → opens variant picker instead of direct increment.
- Logged-in: taps debounced 500ms, coalesced into one API call.
- Guest: nothing sent to server, persisted to Hive per channel (quick/ecommerce).
- Limits enforced client-side: per-product `totalAllowedQuantity`, global `maxCartItemsCount` — blocked with warning snackbar, not silently capped.

### Remove/Update Qty (Checkout cart list)
- Same +/– stepper, same debounce/sync; qty→0 removes row.

### Guest Cart
- Stored locally per channel; live pricing fetched via server call (variantIds+quantities), not trusted from local cache.
- Checkout screen load: fetches guest cart pricing if not logged in; qty changes debounced 500ms then silently re-fetched (no loading flash).

### Login Sync
- Bulk-adds all guest cart entries (both channels) to server cart → clears local guest data → reloads cart from API → navigates to Main (clears stack).

### Cart Recommendations
- "Frequently Bought Together" + "Upgrade Your Order" — horizontal carousels below cart items on Checkout, infinite scroll. Also shown on product detail (scoped to that product).

### Floating Cart Bar
See Section 6.

---

## 12. Checkout

### On Open
- Logged in: parallel fetch cart, addresses, payment methods → auto-select default (or first) address → re-fetch cart pricing scoped to address lat/lng → re-validate any applied promo.
- Guest: fetch guest cart pricing only (no address/payment — must log in to pay).
- Empty cart → "Cart is empty" illustration. Loading → shimmer skeleton. Error → illustration+message+"Pull to refresh"+retry.

### Screen Sections (top→bottom, pull-to-refresh)
1. **Cart items card**: delivery ETA header, "Clear Cart" link (confirm dialog, clears server+local), line items (image, name, variant chips, discount badge, price, qty stepper).
2. **Recommendations** carousels.
3. **Promo section**: no promo → "View all coupons" row → Promo Code screen. Unlock hint → "Unlock <CODE>" + APPLY pill. Applied → "You saved {amt} with 'CODE'" + red "Remove" link + "View all coupons" below.
4. **Wallet section** (only if balance > 0): checkbox "{AppName} Wallet" + "Available balance {amt}" + info icon. If selected but insufficient, orange "Total: {remaining}" warning.
5. **Delivery Instructions** (Quick channel only): row → bottom sheet, multiline field (max 200 chars), Clear/Submit.
6. **Bill Details**: collapsed row (Total, strikethrough original, "You saved" pill, Cashback pill for flat promos) → tap opens bottom sheet itemizing Item Total, Delivery Charge (or "Free"), surge charges (refundable/non-refundable tooltip), zone charges, Promo discount, Total, Wallet Used, Payable.

### Bottom Bar
- No address → "Choose Address at Next Step" button → opens address picker.
- Address selected → "Delivering to {Type}" + short address + "Change" link; Payment method selector (hidden if wallet fully covers order) → Payment Picker screen; Place Order button (total + "Place Order" + arrow; spinner while placing).
- Guest → single "Login & Checkout" button → Login.

### Address Picker Sheet
- Draggable sheet, "Select Address" + "Add New". Lists saved addresses (type icon/badge, formatted address, phone), checkmark on selected. Empty → "No addresses found" + "Add Address" button. Selecting re-fetches cart pricing for new address + re-validates promo.

### COD Eligibility
- Server-determined per cart (`codAllowed`). Payment Picker simply omits COD tile if not eligible — no separate error.

### Place Order Validation (client-side order)
1. No address → "Please select delivery address".
2. Invalid address id → "Invalid address".
3. Out of delivery zone → zone-unavailable error.
4. Wallet doesn't fully cover + no payment method chosen → "Please select payment method".
5. Else calls place-order with addressId, paymentMethod ('wallet' if fully covered, else gateway), promoCodeId, orderNote, walletUsed flag, walletBalance used.

### After Place Order
- COD or wallet-fully-covered → straight to **Order Success** screen (route replaced).
- Else → **Payment Methods** screen, preselected gateway auto-triggers.
- Error → red snackbar.

---

## 13. Payment Methods

- Reached after Place Order (non-COD/non-fully-wallet) with auto-pay attempt on preselected gateway (spinner shown; falls back to list on failure), or manually for wallet top-up.
- Gateways (filtered to backend-enabled): PhonePe, Midtrans, Paystack, Stripe, PayPal, Razorpay, Cashfree, PayTabs, COD, DPO.
- **Flow types:**
  - SDK popup: Razorpay, Stripe, Paystack.
  - WebView: PhonePe, Midtrans, PayPal, Cashfree, PayTabs, DPO.
  - COD: immediate success, no gateway call.
- Bottom bar: Total Amount (or "Add to Wallet" for top-up) + "Pay Now"/"Add Money" button; "Processing…" + spinner while active; disabled until method picked.
- **Completion:** SDK/webview success records transaction server-side. PhonePe polls order status (SUCCESS/COMPLETED = success; FAILED/DECLINED/CANCELLED = specific errors).
- Order flow success → Order Success screen (clears back-stack). Top-up success → "Money added to wallet" snackbar, pop back to wallet.
- Error → red snackbar; auto-pay attempts reveal method list for retry. Cancel/back on SDK sheet resets to initial, reveals list.

---

## 14. Order Success Screen

- Animated checkmark + pulse rings + confetti. "Order Placed!" + "Your order is confirmed and is being prepared for delivery." + Order ID card.
- Buttons: "Track My Order" (→ Order Detail, ongoing) / "Continue Shopping" (→ Main, clear stack).
- Clears cart (server+local) on entry so floating bar resets. Back navigation disabled.

---

## 15. Promo Code

### Browse (Promo Code Screen)
- Manual entry field (auto-uppercase) + "Apply" button (per-code spinner).
- List of promo tiles: image/icon, title or "X% off", "Use code CODE", discount detail line, unlock/eligibility message, expandable description ("+ Read more"). "Apply" disabled if not applicable. Pull-to-refresh. Empty: "No offers available".

### Apply Validation
- Success (`isApplicable == 1`) → screen pops, returns data to Checkout → success dialog with server message + "You saved {amt}!" if discount > 0.
- Not applicable (expired/min-order/invalid) → stays on screen, red snackbar with **server's exact message** (no hardcoded per-reason copy).
- Network error → red snackbar.
- Changing delivery address auto-revalidates applied promo against new subtotal — silently updates or shows error toast (does NOT auto-remove on failed revalidation).

### Remove
- Red "Remove" link next to applied-promo row on Checkout.

---

## 16. Wallet at Checkout

- Section only shown if `userBalance > 0`. **Checkbox toggle, not automatic.**
- Unchecked: full amount to gateway/COD, wallet untouched.
- Checked + balance ≥ total: wallet covers fully. Payment picker hidden entirely, `paymentMethod='wallet'` forced. Success → straight to Order Success (like COD).
- Checked + balance < total (partial): orange "Total: {remaining}" warning shown. Payment picker still required for remainder. `walletUsed='1'` + `walletBalance=<used>` sent alongside chosen gateway. Proceeds to Payment Methods screen for remaining amount after order placed.
- Bill Details sheet reflects: "Wallet Used: -{amt}" then separate "Payable: {amt}".
- Toggling recomputes live client-side, no network call.

---

## 17. Orders

### Orders List
- App bar: calendar icon (date-range filter, icon fills when active, long-press clears), funnel icon (channel filter sheet).
- **Channel filter sheet**: radio "Quick" / "Ecommerce" — separate cubits/lists per channel.
- **Date filter**: native range picker (5 years back to today), applies `startDate`/`endDate` to both lists.
- **No free-text search** on orders list.
- Tabs: "Ongoing" / "Completed" (pill style).

### Quick-order card
- Header: "Order ID#{id}" + date + status chip. Up to 2 items shown (+N more). Total price row.
- Buttons (conditional): "Track" (only if Out for Delivery), "Reorder" (bulk-adds items to cart → checkout). No Cancel on card — only on detail screen.

### Ecommerce item card (per line item)
- Status icon+name+date, product box (tap→item detail), "Return within N days" hint if returnable, 5-star quick-rate row if delivered+unrated.
- Buttons: "Track" (ongoing + timeline exists), "Reorder".

- Empty: "No ongoing/completed orders". Pull-to-refresh always available. Error: message+"Pull to refresh"+Retry. Infinite scroll with footer loader.

### Order Detail — Quick order
1. Status banner (colored, tap → full timeline bottom sheet, vertical dot/line, current step highlighted).
2. Refund banner (if refundAmount > 0) — "credited to wallet".
3. Delivery-OTP card (ongoing only) — 4-6 digit tiles + Copy/Share OTP.
4. Items card (per item + rate control once delivered).
5. Order-detail card: Order ID (copy), Payment Method, Customer Info, Deliver To, Order Placed date, Cancellation Reason. Footer: "Cancel Order" (red outline, only if `isCancellable`).
6. Delivery instruction card (if note exists).
7. Bill summary: Subtotal, Delivery Charge, Tax, Discount, Promo, Wallet Used, surge charges (refundable/non-refundable tooltip), Total. Inline Invoice download link. "You saved" ribbon, Cashback banner.
8. Delivery-partner card (if `isDeliveryBoyChatVisible`): name, OTP, call button (`tel:` dial), "Chat with us" row.

### Order Detail — Ecommerce item
1. Status banner + "N more item(s) in this order" strip if siblings exist.
2. Return-reject reason card (red, if return rejected).
3. Refund banner.
4. OTP card.
5. Tracking card (courier agency, tracking ID+copy, "Track Shipment" external link) if shipped.
6. Items card (this item + controls) + "Other Items in Order" card if siblings.
7. Order-detail card: Order ID, Payment Method, Mobile, Delivery Address, Placed date, Cancel/Return reason.
8. Bill summary (same structure) + Invoice icon.
9. Store-delivery card (delivery boy name only, no chat/call here) if assigned and not delivered/cancelled/returned.

### Cancel Flow
- **Whole-order (quick only)**: "Cancel Order" button (only if `isCancellable`) → bottom sheet "Cancel Order", "Are you sure...", **optional free-text** reason field, Cancel/Cancel Order buttons. Confirm → every non-cancelled item set to status `7` one by one → "Request submitted" snackbar. Order flips Ongoing→Completed once all items cancelled.
- **Per-item (ecommerce items)**: Cancel button (visible if item cancelable & not already cancelled) → simple AlertDialog, 2-line text field, free text, Cancel/Submit → status `7`.
- Quick-channel return-eligible items show **"Get Help"** button instead of Return (quick orders don't support in-app returns) — opens support chat scoped to order.

### Return Flow (ecommerce only)
- Eligible: delivered, `returnStatus==1`, not already requested. Card shows "Return within N days".
- Embedded quick-order row: "Return" → dialog "Return Item"/"Are you sure..." → free-text reason → status `8`.
- Ecommerce item-detail: "Return Item" → **pickup address picker sheet first** (saved addresses + "Add new address" fallback) → then reason sheet ("Enter return reason") → confirm sends status `8` + addressId → "Request submitted".
- Rejected return → `returnRejectReason` shown as red-tinted card on item detail.
- Refunds (cancel/return) → credited to **in-app wallet**, not original payment method; shown as banner on detail screen.

### Invoice Download
- Small "Invoice" link in Bill Summary header (both quick/ecommerce). Downloads PDF (`invoice_{id}.pdf`), opens with device default PDF viewer. Spinner while downloading, error snackbar on failure.

### Live Order Tracking
- Reachable only via "Track" button, only when status = Out for Delivery. Live polling gated to same status.
- Map (Google or OSM per app setting) centered on delivery address; live delivery-boy marker; recenter button.
- Draggable bottom sheet (18%/42%/88% snap):
  - Delivery-partner row: generic avatar, name, "reaching your location soon", circular call button (`tel:` dial, only if number exists), OTP chip. If no partner yet, OTP-only row.
  - "Your Delivery Details" card: Address, Name, Mobile, Payment Method, Order Placed date.
  - "Need Help" row → support/admin chat (no-op if not logged in).
  - Order Summary card: Order ID (copy), first 2 items, "View Order Summary" → full order detail.

---

## 18. Chat

Two contexts, same `ChatScreen`, different type:
- **Delivery-boy chat**: scoped per order (`room_id='order_{orderId}'`). Entry: order-detail "Chat with us" delivery-partner card.
- **Admin/support chat**: "Chat with Support". Entry: "Get Help" per-item button (quick orders), order-tracking "Need Help" row.

- Conversation IDs cached — repeat launches skip "start conversation" call.
- App bar = recipient name. Loads REST history first, then connects socket for live messages. Pull-to-refresh for older pages. Empty: "No messages"/"Start a conversation". Date dividers (Today/Yesterday/date).
- **Message types**: text; image (camera/gallery, max 5MB, tap→full-screen viewer); file (file picker, max 20MB, tap downloads+opens with OS app); audio (in-app recorder, tap-to-start/stop, in-bubble playback with scrubber); video routed through generic file/attachment path. Emoji picker in input bar.
- **Send status** (own messages only, no true read receipts): sending (spinner), sent (double-check icon), failed (error icon).

---

## 19. Address

### Address List
- App bar "My Addresses", bottom "Add Address" button. Each row: type icon, "Default" badge if applicable, full formatted address, Edit/Delete buttons.
- Delete → native AlertDialog confirm (red Delete). Empty: "No addresses found" + prompt. Infinite scroll + pull-to-refresh + no-internet state.

### Add/Edit Flow
- Routes through **Location Picker** first (map pick/search/current location), then **Address Form Sheet** pre-filled from reverse-geocode.
- **Fields**: Full Name (required, prefilled), Mobile+cc (required), Alternate Mobile (optional, min 6 digits if given), Address (required, prefilled), Landmark (required), Area/Locality (required), City (required) + Pincode (required, digits only), State (required) + Country (required).
- Address Type chips: Home/Work/Other (default Home).
- "Set as Default Address" toggle.
- "Save Address"/"Update Address" button, spinner while saving; success patches list locally, closes sheet(s).

### Location Picker Screen
- Full-screen map (Google/OSM), fixed pulsing center pin — point under pin = selection (drag-to-position, not draggable marker).
- Search bar → live suggestions (debounced) → pick → recenter + geocode.
- Current-location button (Geolocator, permission prompts as needed) → geocode + recenter.
- On map-idle, reverse-geocodes center → bottom card updates ("Loading address..." while in flight).
- **Zone check**: every coordinate change calls zone lookup. Not serviceable → bottom sheet swaps to "Zone unavailable" banner, confirm button hidden, only "Use current location" shown. Serviceable → normal card + "Confirm & Add/Edit Details" button (disabled while checking).

---

## 20. Location Setup (first-run / nudge flow — separate from Address picker)

### Location Setup Sheet
- Pin icon, "Where should we deliver?", subtitle. Buttons:
  - "Use current location" (label→"Detecting location..." while running) → GPS check → permission request → position → reverse-geocode → saved to local storage → auto-closes.
  - "Search location manually" → Location Search Screen; success pops back + closes sheet.
- Permission denied → shared permission dialog. Other errors ("GPS disabled", API errors) → error snackbar, resettable for retry.

### Location Search Screen
- App bar "Search Location", search field + clear button, hint "Search area, city, landmark". Live suggestions below (or empty prompt before typing).
- Pick → resolves place details, saves lat/lng/label/address locally, pops with success.
- **No zone/serviceability check here** — only the Address Location Picker enforces zone check.

---

## 21. City

- `CityCubit`/model/repository exist but **no screen or UI consumer anywhere**. Registered globally but never invoked (`loadCities()` never called, no `BlocBuilder<CityCubit>` usage found).
- City is only ever a free-text field inside the Address form (prefilled via reverse-geocode) — **not a real user-facing feature currently**. Flag as dead/in-progress code rather than documenting a city-picker flow.

---

## 22. Wallet

Two parallel UIs exist in code (older `WalletScreen` + newer `WalletTransactionsScreen`); newer one is richer/primary.

### Balance Display
- Gradient card, "Available Balance" + `{currency}{balance}` (large bold), live via Hive `ValueListenableBuilder` — updates instantly after wallet-affecting actions.
- Two actions: "Add Money" (+) / "Withdraw" (↑).

### Wallet History Screen ("Wallet History")
- Search bar (payment type/txn ID/message). Filter icon → "Filter by Type" sheet: All/Credit/Debit (badge dot when active).
- Tile: icon, title (payment type or "Order ID #{id}"), subtitle "TXN ID: {id}", Credit(green)/Debit(red) pill, optional message line, date/time, amount (+green/-red).
- Infinite scroll, pull-to-refresh. Empty: "No matching transactions" (filtered) / "No wallet history".

### Transaction History Screen (payment-gateway txns, separate from wallet)
- Similar tiles: method name/icon, "TXN: {id}", status pill Success(green)/Failed(red)/Pending(orange), date, amount.

### Add Money
- Bottom sheet "Add Money to Wallet". Amount field (numeric, decimal-restricted, must be >0 or "Enter a valid amount"). "Proceed to Pay" → Payment Methods screen (top-up mode); success reloads wallet.

### Withdrawal
- Bottom sheet "Withdrawal Request". Amount (required) + Message (optional, multiline). **No bank/UPI fields collected** — just amount+message. No client-side minimum enforced.
- Cancel/Submit. Success → "Withdrawal request submitted" snackbar, wallet reloads.
- Status tracked: Pending(orange)/Approved(green)/Rejected(red) pill shown in list. Older screen has "Filter by Status" sheet (All/Pending/Approved/Rejected).

---

## 23. Blog

### List Screen ("Blog")
- Category filter chips ("All" + categories, collapses if none) under app bar.
- Cards: cover image, category badge, title (2-line), excerpt (2-line), meta row (read time, views, date). Infinite scroll list.
- Tap → Blog Detail (full object passed). Empty: "No blogs found"/"No blogs in this category".

### Detail Screen ("Blog Detail")
- Large cover image, category badge, title, meta row (read time/views/date), tag chips (`#tag`), HTML body content.
- **No author name/avatar, no share button.**

---

## 24. FAQ

- Flat list (no categories), pull-to-refresh + infinite scroll.
- Accordion tiles: collapsed = question+chevron; expanded = question+divider+answer.
- **No search bar.** Empty: "No FAQs available".

---

## Appendix: Notes for Doc Writers

- `lib/features/cate` folder is empty — unused, ignore.
- `lib/features/city` — dead/unused feature, no UI (see Section 21).
- Full route list: `lib/core/routes/route_names.dart`.
- Cart has no standalone screen — document as part of Checkout (Section 12).
- Refunds from cancel/return always go to in-app wallet, never back to original payment method.
- COD visibility and promo-failure messages are entirely server-driven strings — don't hardcode copy in the manual beyond examples.
