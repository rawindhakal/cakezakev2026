@php
    /**
     * Delivery receipt / parcel label.
     *
     * One template, five paper sizes: $size is 'a4' | 'a5' | 'label' (4x6in) |
     * 'thermal_80' | 'thermal_58'. Narrow rolls stack every block in a single
     * column and drop the item table's money columns — a courier only needs to
     * know what is in the box and what to collect.
     */
    $size = $size ?? 'a4';
    $narrow = in_array($size, ['thermal_80', 'thermal_58'], true);
    $tiny   = $size === 'thermal_58';
    $label  = $size === 'label';

    $appName = \App\Models\Setting::get_value('app_name') ?: 'CakeZake';
    $supportEmail  = \App\Models\Setting::get_value('support_email') ?? '';
    $supportNumber = \App\Models\Setting::get_value('support_number') ?? '';

    $logo = \App\Models\Setting::get_value('logo') ?? '';

    $logoDisk = $logo !== '' ? public_path('storage/' . $logo) : null;
    $logo_full_path = ($logoDisk && is_file($logoDisk)) ? $logoDisk : public_path('images/favicon.png');

    $primary = \App\Models\Setting::get_value('admin_theme_color');
    if (!preg_match('/^#[0-9a-fA-F]{6}$/', (string) $primary)) { $primary = '#435ebe'; }

    $currency = trim((string) ($order->currency ?? ''));
    $money = fn ($v) => $currency . ' ' . number_format((float) $v, 2);

    // Shipping address is a snapshot on the order (JSON or plain string).
    $addr = $order->address ?? '';
    $addr = is_string($addr) ? (json_decode($addr, true) ?: ['address' => $addr]) : (array) $addr;
    $shipName   = $addr['name'] ?? ($order->user_name ?? '');
    $shipLine   = $addr['address'] ?? '';
    $shipMobile = $addr['mobile'] ?? ($order->mobile ?? '');
    $shipAlt    = $addr['alternate_mobile'] ?? '';

    $isPickup = ($order->delivery_type ?? 'delivery') === 'pickup';
    $docTitle = $isPickup ? __('pickup_slip') : __('delivery_receipt');

    $isCod  = strtolower((string) ($order->payment_method ?? '')) === 'cod';
    // What the rider actually collects: COD orders still net off any wallet paid.
    $collect = $isCod ? (float) ($order->remaining_final ?? $order->final_total ?? 0) : 0.0;

    /* Print settings (Settings → Invoice → Delivery Receipt). */
    $rcfg = $receipt_cfg ?? \App\Helpers\CommonHelper::documentSettings()['receipt'];

    // 'auto' keeps the original rule: prices only where the rider collects money and
    // the paper is wide enough. 'always'/'never' are the client's explicit override.
    $showMoney = match ($rcfg['prices']) {
        'always' => true,
        'never'  => false,
        default  => $isCod && !$narrow,
    };
    $showItems = !empty($rcfg['show_products']);

    $items = collect($order_items ?? []);
    $totalQty = (int) $items->sum('quantity');

    // Courier details live per item (ecommerce); show them when the whole receipt
    // shares one courier, which is the case for a single-item receipt.
    $couriers = $items->pluck('courier_agency')->filter()->unique()->values();
    $trackIds = $items->pluck('tracking_id')->filter()->unique()->values();

    // Barcode payload: what the delivery app needs to open the right screen —
    // the order's DB id and its channel (plus the item id on an item parcel).
    // Human-readable order number stays printed beside it for people.
    // Just the order id: digits only keeps the bars short enough for a 58 mm roll.
    // The scan endpoint returns the channel and the item to open, so nothing is lost.
    // Code128C encodes digits in pairs, so an odd-length id takes a leading zero —
    // scanners read "0244", which is still the number 244.
    $scanCode = (string) $order->order_id;
    if (strlen($scanCode) % 2 === 1) { $scanCode = '0' . $scanCode; }

    // Courier / tracking / rider — the box is skipped when none of them is set.
    $hasDetails = !$isPickup && (!empty($order->delivery_boy_name) || $couriers->count() === 1
        || $trackIds->count() === 1);

    // The per-size steps stay, scaled by the configured body size (11px = as before).
    $rk   = ((float) $rcfg['font_size']) / 11;
    $sc   = fn ($px) => round(((float) $px) * $rk, 2);
    $fs   = $sc($tiny ? 8 : ($narrow ? 9 : 10.5));
    $pad  = $narrow ? '4px 5px' : '7px 9px';
    $rWeight = !empty($rcfg['bold_text']) ? 'bold' : 'normal';
@endphp
<html>
<head>
    <meta charset="utf-8">
    <title>{{ $docTitle }} #{{ $order->order_id }} - {{ $appName }}</title>
    <style>
        body { font-family: sans-serif; color:#12161f; font-size:{{ $fs }}px; margin:0;
               font-weight:{{ $rWeight }}; }
        .rule { border-top:1px solid #d9dfea; font-size:0; line-height:0; }
        .muted { color:#12161f; }
        .cap { font-size:{{ $sc($tiny ? 6.5 : 7.5) }}px; text-transform:uppercase; letter-spacing:.6px; color:#12161f; }
        .doc { font-size:{{ $sc($narrow ? 12 : 17) }}px; font-weight:bold; letter-spacing:.5px; }
        .brand { font-size:{{ $sc($narrow ? 10 : 13) }}px; font-weight:bold; color:{{ $primary }}; }
        /* Border sits on the cell: mPDF drops a table border once a nested table
           fills the cell, which is exactly what the detail boxes do. */
        .box td.cell { border:1px solid #cfd6e2; padding:{{ $pad }}; }
        .box td { padding:{{ $pad }}; }
        /* The address is the most-read block, so it gets weight and space rather than
           a frame — a boxed label reads as a form field, not as an address. */
        .shipto { padding:{{ $narrow ? '2px 0 4px' : '2px 0 6px' }}; }
        .shipname { font-size:{{ $sc($tiny ? 10 : ($narrow ? 12 : 14)) }}px; font-weight:bold; }
        .shipline { font-size:{{ $sc($tiny ? 8.5 : ($narrow ? 10 : 12)) }}px; line-height:1.5; }
        .phone { font-size:{{ $sc($tiny ? 9 : ($narrow ? 11 : 12.5)) }}px; font-weight:bold; }
        table { border-collapse:collapse; width:100%; }
        table.kv td { padding:1.5px 0; vertical-align:top; }
        table.kv .k { color:#12161f; width:42%; }
        .shipto table.kv .k { width:{{ $narrow ? '30%' : '18%' }}; }
        table.kv .v { font-weight:bold; }
        table.split td { vertical-align:top; padding:0; }
        table.items th { background:{{ $primary }}; color:#fff; text-align:left;
                         padding:{{ $narrow ? '3px 4px' : '5px 6px' }}; font-size:{{ $sc($tiny ? 6.5 : 8) }}px;
                         text-transform:uppercase; letter-spacing:.5px; }
        table.items td { padding:{{ $narrow ? '4px' : '6px' }}; border-bottom:1px solid #e9edf4; vertical-align:top; }
        table.items td.num, table.items th.num { text-align:right; }
        .pay { padding:{{ $narrow ? '5px 6px' : '9px 12px' }}; border-radius:{{ $narrow ? 3 : 6 }}px;
               text-align:center; font-weight:bold; }
        .pay-cod { background:#fff4e5; border:1.5px solid #b3261e; color:#b3261e; }
        .pay-paid { background:#eaf7ee; border:1.5px solid #1e7c39; color:#1e7c39; }
        .pay-amt { font-size:{{ $sc($tiny ? 12 : ($narrow ? 15 : 20)) }}px; }
        .foot { font-size:{{ $sc($tiny ? 6.5 : 8) }}px; color:#12161f; }
        barcode { }
    </style>
</head>
<body>

{{-- ---------- header: who is sending, what this is ---------- --}}
<table class="split">
    <tr>
        <td style="width:{{ $narrow ? '100%' : '60%' }};">
            @if($narrow || empty($rcfg['show_logo']))
                <span class="brand">{{ $appName }}</span><br>
            @else
                <img src="{{ $logo_full_path }}" style="height:26px;"><br>
            @endif
        </td>
        @if(!$narrow)
        <td style="width:40%; text-align:right;">
            <span class="doc">{{ strtoupper($docTitle) }}</span>
        </td>
        @endif
    </tr>
</table>

@if($narrow)
    <div style="text-align:center; margin-top:4px;">
        <span class="doc">{{ strtoupper($docTitle) }}</span>
    </div>
    {{-- No width to sit beside the barcode, so the same rows stack above it. --}}
    <table class="kv" style="margin-top:4px;">
        <tr><td class="k">{{ __('order_id') }}</td>
            <td class="v">#{{ $order->order_number ?: $order->order_id }}</td></tr>
        <tr><td class="k">{{ __('order_date') }}</td>
            <td class="v">{{ $order->orders_created_at_local ?? '' }}</td></tr>
    </table>
@endif

{{-- Barcode of the order id: warehouse and courier scanners read this, not the text.
     Wide paper puts the order details beside it; a roll stacks them. --}}
@if(!$narrow)
<table class="split" style="margin-top:8px;">
    <tr>
        <td style="width:46%; vertical-align:middle;">
            <table class="kv">
                <tr><td class="k">{{ __('order_id') }}</td>
                    <td class="v">#{{ $order->order_number ?: $order->order_id }}</td></tr>
                <tr><td class="k">{{ __('order_date') }}</td>
                    <td class="v">{{ $order->orders_created_at_local ?? '' }}</td></tr>
            </table>
        </td>
        <td style="width:54%; text-align:right; vertical-align:middle;">
@endif
<div style="text-align:center; margin:{{ $narrow ? '6px 0' : '0' }}; padding:{{ $narrow ? '2px 6px' : '2px 0' }}; background:#fff;">
    {{-- C128C packs digits two per symbol — the most compact code for a numeric id,
         so the bars can afford to be WIDER on small paper, not narrower. A 203 dpi
         thermal head prints 0.125 mm dots; thin modules land between dots and merge,
         which is why a scan failed while a zoom looked fine. --}}
    <barcode code="{{ $scanCode }}" type="C128C"
             size="{{ $narrow ? 2 : ($label ? 1.8 : 1.4) }}"
             height="{{ $narrow ? 0.55 : 1 }}" />
    <div class="cap" style="margin-top:4px; letter-spacing:1px;">
        {{ __('order_id') }} {{ $scanCode }} · {{ $order->order_number ?: '' }}
    </div>
</div>
@if(!$narrow)
        </td>
    </tr>
</table>
@endif

<div class="rule" style="margin:{{ $narrow ? '4px 0' : '8px 0' }};"></div>

<div class="rule" style="margin:{{ $narrow ? '5px 0' : '10px 0' }};"></div>

{{-- ---------- ship to: the one block that must be unmissable ---------- --}}
<table class="split">
    <tr>
        <td style="width:{{ $narrow || $label ? '100%' : '58%' }}; padding-right:{{ $narrow ? 0 : '10px' }};">
            <div class="shipto">
                @if($isPickup)
                <span class="cap">{{ __('pickup_from') }}</span>
                <table class="kv" style="margin-top:3px;">
                    <tr><td class="k">{{ __('branch') }}</td>
                        <td class="v shipname">{{ $order->branch_name ?? '' }}</td></tr>
                    <tr><td class="k">{{ __('address') }}</td>
                        <td class="v shipline">{{ $order->branch_formatted_address ?: ($order->branch_address ?? '') }}</td></tr>
                    @if(!empty($order->branch_contact_number))
                    <tr><td class="k">{{ __('contact') }}</td>
                        <td class="v phone">{{ $order->branch_contact_number }}</td></tr>
                    @endif
                    <tr><td class="k">{{ __('customer') }}</td>
                        <td class="v">{{ $shipName }}</td></tr>
                    <tr><td class="k">{{ __('mobile') }}</td>
                        <td class="v phone">{{ $shipMobile }}</td></tr>
                </table>
                @else
                <span class="cap">{{ __('ship_to') }}</span>
                <table class="kv" style="margin-top:3px;">
                    <tr><td class="k">{{ __('name') }}</td>
                        <td class="v shipname">{{ $shipName }}</td></tr>
                    <tr><td class="k">{{ __('address') }}</td>
                        <td class="v shipline">{{ $shipLine }}</td></tr>
                    <tr><td class="k">{{ __('mobile') }}</td>
                        <td class="v phone">{{ $shipMobile }}</td></tr>
                    @if($shipAlt)
                    <tr><td class="k">{{ __('alternate_mobile') }}</td>
                        <td class="v phone">{{ $shipAlt }}</td></tr>
                    @endif
                </table>
                @endif
            </div>
        </td>
        @if(!$narrow && !$label)
        <td style="width:42%;">
            @if($hasDetails)
            <table class="box"><tr><td class="cell">
                <table class="kv">
                    @if(!empty($order->delivery_boy_name))
                    <tr><td class="k">{{ __('delivery_boy') }}</td>
                        <td class="v">{{ $order->delivery_boy_name }}</td></tr>
                    @endif
                    @if($couriers->count() === 1)
                    <tr><td class="k">{{ __('courier_agency') }}</td>
                        <td class="v">{{ $couriers->first() }}</td></tr>
                    @endif
                    @if($trackIds->count() === 1)
                    <tr><td class="k">{{ __('tracking_id') }}</td>
                        <td class="v">{{ $trackIds->first() }}</td></tr>
                    @endif
                </table>
            </td></tr></table>
            @endif
        </td>
        @endif
    </tr>
</table>

@if(($narrow || $label) && $hasDetails)
    <table class="box" style="margin-top:{{ $narrow ? '4px' : '8px' }};"><tr><td class="cell">
        <table class="kv">
            @if(!empty($order->delivery_boy_name))
            <tr><td class="k">{{ __('delivery_boy') }}</td><td class="v">{{ $order->delivery_boy_name }}</td></tr>
            @endif
            @if($couriers->count() === 1)
            <tr><td class="k">{{ __('courier_agency') }}</td><td class="v">{{ $couriers->first() }}</td></tr>
            @endif
            @if($trackIds->count() === 1)
            <tr><td class="k">{{ __('tracking_id') }}</td><td class="v">{{ $trackIds->first() }}</td></tr>
            @endif
        </table>
    </td></tr></table>
@endif

{{-- ---------- payment: what the rider collects, or that nothing is due ---------- --}}
<div class="pay {{ $isCod ? 'pay-cod' : 'pay-paid' }}" style="margin:{{ $narrow ? '5px 0' : '9px 0' }};">
    @if($isCod)
        {{ strtoupper(__('cash_on_delivery')) }} — {{ __('amount_to_collect') }}<br>
        <span class="pay-amt">{{ $money($collect) }}</span>
    @else
        <span class="pay-amt">{{ strtoupper(__('prepaid')) }}</span><br>
        {{ __('do_not_collect_cash') }}
    @endif
</div>

{{-- ---------- packing list (hidden when the client prints parcel-only receipts) ---------- --}}
@if($showItems)
<table class="items">
    <thead>
        <tr>
            <th style="width:{{ $narrow ? '8%' : '6%' }};">#</th>
            <th>{{ __('product') }}</th>
            @if($showMoney)
                <th class="num" style="width:18%;">{{ __('total') }}</th>
            @endif
        </tr>
    </thead>
    <tbody>
        @foreach($items as $i => $item)
            @php
                $attrs = collect((array) ($item->variant_attributes ?? []))
                    ->map(fn ($a) => is_array($a) ? (($a['name'] ?? '') . ': ' . ($a['value'] ?? '')) : (string) $a)
                    ->filter()->implode(', ');
            @endphp
            <tr>
                <td>{{ $i + 1 }}</td>
                <td>
                    <b>{{ (int) $item->quantity }} &times; {{ $item->product_name }}</b>
                    @if($attrs)<br><span class="muted">{{ $attrs }}</span>@endif
                    @php
                        $addons = collect((array) ($item->addons ?? []))
                            ->map(fn ($a) => is_array($a)
                                ? trim(((int) ($a['qty'] ?? 1) > 1 ? (int) $a['qty'] . ' × ' : '') . ($a['option_name'] ?? ''))
                                : (string) $a)
                            ->filter()->implode(', ');
                    @endphp
                    @if($addons)<br><span class="muted">{{ __('addons') }}: {{ $addons }}</span>@endif
                    @if(!empty($item->tracking_id) && $trackIds->count() > 1)
                        <br><span class="muted">{{ __('tracking_id') }}: {{ $item->tracking_id }}</span>
                    @endif
                </td>
                @if($showMoney)
                    <td class="num">{{ $money($item->sub_total ?? 0) }}</td>
                @endif
            </tr>
        @endforeach
    </tbody>
</table>
@else
    {{-- No item list: the rider still needs to know how many pieces are in the box. --}}
    <table class="box" style="margin-top:{{ $narrow ? '4px' : '8px' }};"><tr><td class="cell">
        <span class="cap">{{ __('total_quantity') }}</span>
        <span class="shipname" style="float:right;">{{ $totalQty }}</span>
    </td></tr></table>
@endif

@if(!empty($order->order_note))
    <table class="box" style="margin-top:{{ $narrow ? '4px' : '8px' }};"><tr><td class="cell">
        <span class="cap">{{ __('order_note') }}</span><br>
        <span class="shipline">{{ $order->order_note }}</span>
    </td></tr></table>
@endif

@if(!empty($rcfg['show_signature']))
    {{-- Ruled space: the customer signs on handover. --}}
    <table style="margin-top:{{ $narrow ? '8px' : '14px' }};">
        <tr><td style="width:{{ $narrow ? '100%' : '55%' }};">
            <br>
            <div class="rule"></div>
            <span class="cap">{{ $rcfg['signature_label'] }}</span>
        </td>
        @if(!$narrow)<td style="width:45%;"></td>@endif
        </tr>
    </table>
@endif

<div class="rule" style="margin:{{ $narrow ? '4px 0' : '9px 0' }};"></div>
@if($rcfg['footer_note'] !== '')
    <div class="foot" style="text-align:center;">{{ $rcfg['footer_note'] }}</div>
@endif
<div class="foot" style="text-align:center;">
    {{ $appName }}@if($supportEmail) · {{ $supportEmail }}@endif @if($supportNumber) · {{ $supportNumber }}@endif
</div>

</body>
</html>
