# cakezake_deliveryboy — Deep User Manual

Delivery rider (courier) app. Screen-by-screen, field-by-field, flow-by-flow reference for building end-user documentation.

Stack: Flutter, Cubit, Dio, Hive, Firebase.

---

## 1. App Boot Flow

### Splash Screen
- Loading/orchestration only, no user input.
- **Boot sequence:**
  1. Check connectivity, load app Settings.
  2. If `appModeDeliveryBoy == '1'` (maintenance) → **Maintenance Screen**, back disabled, stuck until backend clears flag.
  3. Check force-update requirement → dialog, must tap "Continue" (re-checked on app foreground).
  4. Load language list, then localization strings (falls back to cached translations on failure).
  5. Navigate: saved login session (Hive) → **Main Screen**; else → **Login Screen**.
  6. No internet at splash → "no internet" indicator over splash visual.

### Maintenance Screen
- Non-dismissible (back blocked). Illustration + "App under maintenance" + custom remark or default message. No actions — fully blocked until backend clears flag.

---

## 2. Auth

### Login Screen
- **Email** (required, valid format), **Password** (required, min 6 chars, show/hide toggle).
- "Forgot Password?" link (top-right) → Forgot Password screen.
- **Login button:**
  1. Ensures FCM token exists (fetches/saves if missing).
  2. Calls login API (email, password, FCM token, platform, language id).
  3. Success → session saved, country/currency refreshed, replaces screen with **Main Screen** (no back to login).
  4. Failure → red error snackbar with server message.
- "Don't have an account? Sign Up" → Register screen.

### Register Screen (single scrolling form, not wizard)
1. Full Name (required).
2. Email (required, valid format).
3. Date of Birth (date picker, must be 18+, range 1950→18-years-ago).
4. Country (dropdown, defaults to first from API).
5. Mobile Number (country-code-aware, required, min 10 digits).
6. Password (required, min 6, show/hide).
7. Confirm Password (must match).
8. National ID image (required upload, camera/gallery).
9. Driving License image (required upload).
10. Earning Type: Salaried / Commission — Commission selected reveals **Commission %** field (required, 1-100 whole number).
- **"Sign Up" button:** validates all incl. images → register API → success = green "Account created" snackbar → **back to Login** (no auto-login; may require backend approval — no explicit pending-approval screen exists, but see Account Blocked dialog below). Failure → red snackbar.
- "Already have an account? Login" link.

### Forgot Password Screen
- Single **Email** field (required, valid format).
- **"Submit"** → forgot-password API. Success → green snackbar (default "OTP sent successfully") → pops back to Login. Failure → red snackbar.
- No in-app OTP-entry/reset-password screen — reset completes via emailed link/OTP outside the app.

---

## 3. Home / Dashboard

### Online/Offline Toggle
- Status pill + switch at top of header: green glowing dot "Online" or dim "Offline".
- **Caveat:** toggle only flips local/in-memory state — no dedicated API call persists it. Actual status (1/2/4) comes from a separate server status check on load/refresh. Document as "tap to toggle your availability" — persistence behavior may need backend confirmation.
- If server status = **4 (blocked)** → non-dismissible **Account Blocked** dialog auto-appears regardless of toggle.

### Dashboard Content (top → bottom)
1. **Header**: rider name + online/offline pill+toggle.
2. **"Today's Performance"** (date chip): Today's Earnings, Orders Delivered, Cash Collected, Available Balance.
3. **"Today's Overview"** 2×2 grid: Active Orders (info only), Available Balance (tap→Wallet), Cash In Hand (tap→Cash Collection), Total Orders (info only).
4. **Earnings Trend card** (if data exists) — chart over time.
5. **"Order Status"** card — counts per status w/ icons; falls back to simple Completed vs Cancelled if no breakdown.
6. **"Order Type"** — two progress bars: Quick Orders vs E-commerce Orders (count + %).
7. **"Financial Summary"** — Total Pay (all-time) + "Last paid on [date]·[amount]"; tap → Salary screen.
- States: loading spinner; error text; no internet → full-screen replacement; pull-to-refresh re-fetches dashboard+settings+status+country settings.

### Account Blocked Dialog
- Auto-triggered when status = 4. Non-dismissible. Red block icon, "Account Blocked" title, generic message + backend remark/reason if supplied.
- Single **OK** button → logs out (best-effort API call), clears session, sends to **Login screen** (stack cleared).

---

## 4. Main Screen / Bottom Navigation

- 4 tabs (`IndexedStack`, state kept alive): **Home** (Dashboard), **My Delivery** (Orders), **Earnings** (Wallet icon), **Profile**.
- Active tab: primary-tint icon, bold label, animated 3px underline.
- No numeric badges anywhere. No floating action button.
- Full app connectivity loss → entire Main Screen replaced by full-screen "no internet" (not per-tab).
- Tab switch is instant local state change, no API call.

---

## 5. Profile

### Profile Screen
- Title "My Profile", no back button (root tab).
- Header card: avatar, name, email; "Edit" pill → Edit Profile screen. (Guest-state theoretically unreachable in normal flow.)
- **Preferences** section (Language/Theme — see Section 7).
- **Help & Support**: "Chat with Support" (opens/resolves admin chat); "Rate Us" (external URL — note: code currently binds this to currency symbol, likely a bug, not store link — flag to devs); expandable "Help & Policies": Privacy Policy, Terms & Conditions.
- **Account**: Settings → Account Settings; Logout → confirmation dialog.

### Edit Profile Screen — 2-step form (step indicator at top)
**Step 1 — Personal Details:**
- Full Name (required), Email (optional but validated if filled), Date of Birth (optional here, 18+ picker), Country (read-only, pre-filled), Mobile Number (required, country locked), National ID image (upload/replace), Driving License image (upload/replace), Address (required, multi-line), Earning Type toggle + Commission % (required 1-100 if Commission).

**Step 2 — Bank Details:**
- Bank Name (required), Account Number (required, numeric), IFSC Code (required, auto-uppercase), Account Holder Name (required).

- Step 1 buttons: Cancel / Next (validates, advances). Step 2: Back / "Update Profile" (validates, submits).
- Success → green "Profile updated" snackbar → closes to Profile. Failure → red snackbar.

### Account Settings Screen
- "General" card: **Notifications** → Notification Settings; **Change Password** → bottom sheet; **Delete Account** → confirmation dialog.

**Change Password bottom sheet:**
- New Password (required, min 6, show/hide), Confirm Password (must match).
- Warns upfront: "You'll be logged out after updating your password."
- "Update Password" → success = sheet closes, green snackbar, forced logout → Login screen. Failure → red snackbar, sheet stays open.

**Delete Account dialog:**
- Irreversibility warning. Cancel / Delete (inline spinner). Success → redirected to Login (session removed). Failure → red snackbar.

**Logout dialog** (reused across app):
- "Are you sure you want to logout?" Cancel / Logout (inline spinner). Success → Login screen, stack cleared. Failure → red snackbar, dialog closes regardless.

### Policies Screen
- Reused for Privacy Policy / Terms & Conditions (title/content switches). HTML content from app settings.
- States: loading spinner, error+retry, no-internet full screen, empty-state if content not configured ("Privacy Policy not available"/"Terms not available").

---

## 6. Orders ("My Delivery")

### Orders Screen
- 3 tabs/channels: **Quick**, **Ecommerce**, **Returns**.
- Status chips row (dynamic from server, filtered by channel; statuses "7"/"8" — cancelled/returned — excluded from filter chips).
- Search (magnifying glass): available on Quick and Returns tabs only, not Ecommerce.
- Filter icon (tune) → sheet: Order Type chooser, Date Range picker, Clear/Apply. Primary-dot badge when filter active.
- Pull-to-refresh, infinite scroll (150px trigger). No internet → full-screen state.

### Order Card
- "Order ID#{id}" + date/time, status chip, up to 2 line items (+N more), payment method badge (COD/Prepaid), Final Total.
- Return card adds Return ID + reason/remarks in detail.

### Order Detail — Quick Orders
1. App bar: status name + "Order #{id}".
2. **Pickup & Delivery card** — route UI: storefront icon (store name/address/phone) → line → pin icon (customer name/mobile/alt-mobile/address). Action chips each side: Call, Chat (delivery side only, if `isDeliveryBoyChatVisible`), Get Directions.
3. Delivery Instruction note card (if present) — sticky-note style.
4. **Track Order** button (yellow tile) — only when active status = 5 (Out for Delivery).
5. **Timeline card** — vertical status history, current status highlighted.
6. Items card — images, variants, qty, price.
7. **Bill Summary** — Sub Total, Delivery Charge, Tax, Discount, Promo Discount, Wallet Used, surge charges, Refund Amount, Total, Payment Method badge.
8. Bottom bar: single **"Mark as {NextStatus}"** slide-to-confirm button — hidden when active status is 1, 2, 7, 8, or 9.

Quick-action tiles (order_action_buttons): Call Customer, Call Seller, Customer Directions, Seller Directions (opens `tel:` or maps deep link). Full-width Track Order tile appears when status = 5.

### Status Update Flow (Quick & Ecommerce — identical mechanism)
- **Single button only**: "Mark as {Next Status Name}" slide-to-confirm — always targets the next status in server-defined sequence. **Rider cannot skip or pick arbitrary status.**
- If next status = **"6" (Delivered)** → sliding first opens **"Enter Delivery OTP"** bottom sheet:
  - "Enter the OTP shared by the customer to confirm delivery" — numeric field, digits only.
  - Live-validates against order's stored OTP once length matches; "Invalid OTP. Please try again." on mismatch.
  - Cancel / Submit — locally verified (not a server round-trip at this step).
  - **Rider must ask customer for OTP and enter it to mark Delivered.** No OTP needed for other transitions.
- Confirm → status-update API call → green "Order status updated" snackbar or red error; detail screen reloads.
- **No Accept/Reject action anywhere** — orders arrive pre-assigned; rider only progresses status-by-status.

### Ecommerce Order Detail
- Same layout as Quick + "Item #{id}" alongside "Order #{id}", extra Customer Info card. Same Mark-as/OTP flow. Update button hidden for statuses 1, 2, 3, 7, 8.

### Return Orders
- Tab: "Return Delivery" — own search + status chips + date filter.
- Detail: Pickup/Delivery card (reversed — pickup = customer, delivery = store), Timeline, Product card, "Why Return?" card (reason/remarks), red "Cancel Reason" block if rejected, Bill Summary/Payment card.
- Status flow: same slide-to-confirm pattern — Out for Pickup → Received from Customer → Return to Store. Hidden at status 8 or 3. **No OTP step for returns.**

### Order Tracking Screen
- Reached via "Track Order" (status = 5 only).
- Live map (Google/OSM per setting): rider's current location + customer delivery pin.
- Rider GPS posted to server every **30 seconds** automatically while screen open (orderStatus "5") — this is how customer/admin see live location.
- Recenter button. No location/permission denied → dedicated "no location" state + Retry.
- Chat-with-customer button if `chatVisible` flag passed.

---

## 7. Chat

Two contexts, same `ChatScreen`:
- **Customer chat** (`deliveryBoyChat`): scoped per order (`order_{orderId}`). Entry: chat icon on Quick order-detail Pickup/Delivery card (only if `isDeliveryBoyChatVisible`), and chat button on Order Tracking screen. **Not available** on Ecommerce or Return order detail.
- **Support chat** (`adminChat`): room `admin_user_{riderId}`. Entry: Profile → Help & Support → "Chat with Support".

- App bar title = recipient name (customer name, or "Help Center").
- REST history + socket live messages; pull-to-refresh for older. Empty: "No messages yet"/"Start the conversation below".
- Date-divided, right-aligned (primary) own bubbles, left-aligned (grey) other party, send-status icon (sending/sent/failed) on own bubbles.
- **Message types**: text, image (camera/gallery), file/document (any type via picker), voice (press-hold mic → stop → sends `.m4a`). Attach menu (paperclip): Camera/Gallery/File. Emoji picker toggle.
- Size limits: images ≤5MB, other attachments ≤20MB — "file too large" snackbar if exceeded.
- Input bar icon toggles: mic (idle) → send (text/attachment present) → stop (recording).

---

## 8. Cash Collection

**Read-only ledger** — no mark-collected/deposit/handover action exists (single GET endpoint only).

- Entry points: Home "Cash Collection" tile, Earnings quick-link. Not in bottom nav.
- Search (500ms debounce "Search collections…"), date-range filter + clear-filters icon.
- **Summary card**: "Cash in Hand" (running total held) + "Cash Collected" (total collected).
- Paginated list, each entry: "Order ID#{id}" + date/time, status chip, Type row (from backend), Message row (free-text note), Amount row.
- Pull-to-refresh + infinite scroll.
- **For the manual**: COD isn't "marked collected" by rider in-app — presumably recorded server-side when order marked Delivered (COD). Rider only views running balance/history. No in-app deposit-to-admin button — reconciliation happens outside the app.

---

## 9. Earnings

- Title "Earnings", root tab, no back button. Pull-to-refresh, auto-reload on reconnect. Single dashboard API call (no separate daily/weekly/monthly endpoint).
- **Hero gradient card**: Total Earning (large) + Today Earning pill below.
- **No charts/graphs, no date-range filter** — live snapshot only.
- "Wallet" row (tappable) → Wallet screen. 6 stat tiles (3×2): Available Balance, Wallet Balance, Total Earned, Total Debited, Pending Withdrawal, Total Withdrawn.
- **"Quick Access"** 3 tiles: Salary (total paid, → Salary screen), Cash Collection (cash in hand, → Cash Collection screen), Fund Transfer (recent count, → Fund Transfer screen).
- No per-delivery earning breakdown, no incentive/bonus lines anywhere.

---

## 10. Wallet

- Title "Wallet", back button. Search icon ("Search Transactions"), filter icon.
- **Balance card**: Available Balance + "Withdraw" button (↑) → bottom sheet.
- **Filter sheet** "Filter by Status": All / Pending / Approved / Rejected — applies immediately, closes sheet.
- **Transaction list** (paginated, infinite scroll): ID #{id}, created date/time (shown twice), amount+currency, status badge (Pending amber/Approved green/Rejected red), optional message/note box.
- Empty: "No Transactions Yet".

### Withdrawal Flow (bottom sheet "Withdrawal Request")
1. Amount field (numeric, currency-prefixed, required).
2. Message field (optional, multiline).
3. Cancel / Submit.
4. Success → "Withdrawal request submitted" snackbar, sheet closes, list refreshes. Error → error snackbar.
5. Appears in transaction list as "Pending" until admin approves/rejects.

---

## 11. Salary

- Title "Salary", back button. No summary/hero card — straight to paginated list (infinite scroll 150px trigger, pull-to-refresh).
- Each card: "ID: #{id}", paid-on date, status badge "PAID" (always green — this is payment history, not pending requests), Message (admin note, "—" if empty), "Total Pay" row (only if `paidOn` set).
- Footer: "Loading more" spinner or "All records loaded" divider. Empty: "No Salary Records".
- **Read-only payment history** — no request/download/PDF, no pending-vs-paid distinction (all entries = completed payments).

---

## 12. Fund Transfer

**Read-only ledger** — no create/submit action anywhere (no POST endpoint in repository). Admin-driven statement the rider can view/search only.

- Title "Fund Transfers", search ("Search Transfers"), clear-filters icon (shown only when filter active). Paginated, infinite scroll, pull-to-refresh.
- Each card: "ID #{id}", created date/time, Type badge CREDIT (green)/DEBIT (red), Opening Balance, Closing Balance, Amount (+green/−red with currency).
- Empty: "No Fund Transfers". Footer: "No more transfers".
- **Interpretation**: represents admin adjusting/transferring money into/out of rider's account (settling collected cash, deductions, credits) — a running passbook-style ledger. Rider cannot initiate a transfer.

---

## 13. Notifications

### Notification Settings Screen
- Reached via Profile → Settings → Notifications.
- 3-tab pill switcher: **Email / Notifications (push) / SMS**.
- Each tab lists every order-status type as a card with toggle — independent per channel/status.
- Sticky **"Save Settings"** button (hidden if nothing to show). Success → green "Settings saved" + reload. Failure → red snackbar, toggles stay as left.
- States: loading spinner, error+retry, pull-to-refresh per tab, no-internet full screen, empty state if no configurable statuses.
- Note: a parallel unused `notification_settings`/mail_settings sub-feature exists in code but isn't wired to any reachable route — document only the flow above as live.

---

## 14. Language & Theme (Profile → Preferences)

Both shown as rows in one "Preferences" card, trailing text shows current value, tap opens bottom sheet.

### Change Language
- Sheet "Select Language" — radio list (name+code) from backend, pre-checked current.
- States: loading spinner, error+Retry, per-item spinner while applying.
- Selecting: saves locally (id/code/type), re-registers FCM token tagged with new language, closes sheet once done. UI retranslates via global localization cubit.

### Change Theme (Appearance)
- Sheet "Appearance": System Default / Light / Dark radio options.
- Tap applies immediately (saved locally), sheet auto-closes, no separate save step.

---

## Appendix: Notes for Doc Writers

- No explicit "pending admin approval" screen after registration — flow is Register → success message → Login. Approval likely happens server-side; a newly-registered/unapproved rider may surface via the Account Blocked dialog (status 4) after login. Confirm with backend/product before documenting as a formal approval step.
- Online/offline toggle on Home has no dedicated persistence API in the code reviewed — document loosely as "tap to toggle availability," flag to engineering.
- No bottom-nav badges/counters (orders, notifications) exist anywhere.
- No floating action button on Home or Main screen.
- Account Blocked, Delete Account, Logout, and Change-Password-then-logout all funnel to Login screen with session cleared.
- Cash Collection and Fund Transfer are both **read-only ledgers** — no in-app action to deposit cash or initiate a transfer; reconciliation happens outside the app (admin/back office).
- Delivery OTP is verified **locally** against the order's stored OTP value at the "Mark as Delivered" step — not a separate server call at entry time.
- Customer chat is only available on Quick order detail + Order Tracking screen — not wired on Ecommerce or Return order detail.
- "Rate Us" profile link currently binds to currency symbol in code — likely a bug, not intended behavior; flag to devs, don't document as-is.
