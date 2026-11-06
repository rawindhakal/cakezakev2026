@php
    /**
     * Invoice for a narrow roll (80 mm / 58 mm / custom narrow paper).
     *
     * The A4 template is built from two-column cards and a wide item table; neither
     * survives a 58 mm page, so a roll gets its own single-column layout: every block
     * stacks, the item table keeps only name / qty × rate / amount, and the tax detail
     * collapses into one line per head. Same settings drive both (Settings → Invoice).
     */
    $cfg  = $invoice_cfg ?? \App\Helpers\CommonHelper::documentSettings()['invoice'];
    $size = $size ?? 'thermal_80';
    $tiny = $size === 'thermal_58';

    $appName = \App\Models\Setting::get_value('app_name');
    if ($appName === '' || $appName === null) { $appName = 'CakeZake'; }
    $supportEmail  = \App\Models\Setting::get_value('support_email') ?? '';
    $supportNumber = \App\Models\Setting::get_value('support_number') ?? '';

    $logo = \App\Models\Setting::get_value('logo') ?? '';
    $logoDisk = $logo !== '' ? public_path('storage/' . $logo) : null;
    $logoPath = !empty($cfg['logo'])
        ? $cfg['logo']
        : (($logoDisk && is_file($logoDisk)) ? $logoDisk : public_path('images/favicon.png'));

    // Mono mode prints black; otherwise the roll carries the theme colour like the
    // A4 template does (the Colours setting decides, not the paper width).
    $primary = \App\Models\Setting::get_value('admin_theme_color');
    if (!preg_match('/^#[0-9a-fA-F]{6}$/', (string) $primary)) { $primary = '#435ebe'; }
    if (!empty($cfg['mono'])) { $primary = '#000000'; }

    $base = (float) $cfg['font_size'];
    // 58 mm is 40 % narrower than 80 mm: shrink the base with it or lines wrap to mush.
    if ($tiny) { $base = max(6, $base - 2); }
    $fs = fn ($mult) => round($base * $mult, 2);
    $bodyWeight = !empty($cfg['bold_text']) ? 'bold' : 'normal';

    $currency = trim((string) ($order->currency ?? ''));
    $money = fn ($v) => $currency . ' ' . number_format((float) $v, 2);

    $addresses = \App\Helpers\CommonHelper::orderAddresses($order->address ?? null);
    $shipTo = $addresses['shipping'] ?? [];
    $billTo = $addresses['billing'] ?? $shipTo;

    $allItems      = collect($order_items);
    $activeItems   = $allItems->filter(fn ($i) => !in_array((int) $i->active_status, [7, 8]))->values();
    $refundedItems = $allItems->filter(fn ($i) => in_array((int) $i->active_status, [7, 8]))->values();
    $refundedTotal = (float) $refundedItems->sum('refund_amount');
    $orderStatus   = (int) ($order->active_status ?? 0);

    $isPickup = ($order->delivery_type ?? 'delivery') === 'pickup';

    // Tax heads across items and charges, summed for the one-line-per-head summary.
    $headTotals = [];
    $taxTotal   = 0.0;
    $taxable    = 0.0;
    foreach ($activeItems as $item) {
        $taxTotal += (float) ($item->tax_total ?? 0);
        $taxable  += (float) ($item->sub_total ?? 0) - (float) ($item->tax_total ?? 0);
        foreach (($item->tax_lines ?? []) as $line) {
            $name = data_get($line, 'component_name');
            if ($name) {
                $headTotals[$name] = ($headTotals[$name] ?? 0) + (float) data_get($line, 'amount', 0);
            }
        }
    }

    $itemsTotal = (float) $activeItems->sum('sub_total');
    $charges = [];
    if ((float) ($order->delivery_charge ?? 0) > 0) {
        $charges[] = ['label' => 'Delivery Charge', 'amount' => (float) $order->delivery_charge];
    }
    foreach ((array) ($order->surge_charges ?? []) as $row) {
        $amt = (float) (data_get($row, 'charge') ?? data_get($row, 'amount') ?? 0);
        if ($amt > 0) { $charges[] = ['label' => data_get($row, 'name', 'Surge'), 'amount' => $amt]; }
    }
    foreach ((array) ($order->additional_charges ?? []) as $row) {
        $amt = (float) (data_get($row, 'amount') ?? 0);
        if ($amt > 0) { $charges[] = ['label' => data_get($row, 'name', 'Charge'), 'amount' => $amt]; }
    }
@endphp
<html>
<head>
    <meta charset="utf-8">
    <title>INVOICE #{{ $order->order_id }} - {{ $appName }}</title>
    <style>
        body { font-family: sans-serif; color:#000; font-size:{{ $fs(1) }}px; margin:0;
               font-weight:{{ $bodyWeight }}; }
        .c { text-align:center; }
        .b { font-weight:bold; }
        .brand { font-size:{{ $fs(1.35) }}px; font-weight:bold; color:{{ $primary }}; }
        .doc { font-size:{{ $fs(1.15) }}px; font-weight:bold; letter-spacing:.5px; color:{{ $primary }}; }
        .muted { color:#555; font-size:{{ $fs(0.82) }}px; }
        .sec { font-weight:bold; font-size:{{ $fs(0.9) }}px; text-transform:uppercase;
               letter-spacing:.4px; color:{{ $primary }}; border-bottom:1px solid {{ $primary }};
               padding:2px 0 1px; margin-top:5px; }
        table { width:100%; border-collapse:collapse; }
        table.kv td { font-size:{{ $fs(0.88) }}px; padding:1px 0; vertical-align:top; }
        table.kv td.k { color:#555; width:42%; }
        table.it td { font-size:{{ $fs(0.88) }}px; padding:2px 0; vertical-align:top; }
        table.it tr.hd td { font-weight:bold; border-bottom:1px solid {{ $primary }}; }
        table.tt td { font-size:{{ $fs(0.9) }}px; padding:1.5px 0; }
        table.tt td.v { text-align:right; font-weight:bold; }
        table.tt tr.grand td { font-size:{{ $fs(1.1) }}px; font-weight:bold;
                               border-top:1px solid {{ $primary }}; padding-top:3px; }
        table.tt tr.grand td.v { color:{{ $primary }}; }
        .dash { border-top:1px dashed #000; font-size:0; line-height:0; margin:4px 0; }
        .note { font-size:{{ $fs(0.78) }}px; color:#333; }
        .banner { border:1px solid #000; padding:3px; font-weight:bold; font-size:{{ $fs(0.88) }}px; }
    </style>
</head>
<body>

<div class="c">
    {{-- Logo or name, never both: the logo already carries the wordmark. --}}
    @if(!empty($cfg['show_logo']))
        <img src="{{ $logoPath }}" height="{{ (int) $cfg['logo_height'] }}"><br>
    @else
        <span class="brand">{{ $appName }}</span><br>
    @endif
    <span class="doc">{{ !empty($order->branch_tax_number) ? 'TAX INVOICE' : 'INVOICE' }}</span>
    @if($cfg['header_note'] !== '')<br><span class="muted">{{ $cfg['header_note'] }}</span>@endif
</div>

<div class="dash">&nbsp;</div>

<table class="kv">
    <tr><td class="k">Invoice No</td><td class="b">{{ $order->invoice_number ?? $order->order_id }}</td></tr>
    <tr><td class="k">Order No</td><td class="b">{{ $order->order_number ?? $order->order_id }}</td></tr>
    <tr><td class="k">Date</td><td class="b">{{ $order->created_at_formatted ?? $order->created_at }}</td></tr>
    <tr><td class="k">Payment</td><td class="b">{{ strtoupper((string) $order->payment_method) }}</td></tr>
    @if(!empty($order->branch_tax_number))
        <tr><td class="k">{{ $order->branch_registration_type ?? 'Tax No' }}</td><td class="b">{{ $order->branch_tax_number }}</td></tr>
    @endif
</table>

<div class="sec">Bill To</div>
@php
    $buyerBusiness = $order->buyer_business_name ?: null;
    $buyerContact  = $billTo['name'] ?: ($order->user_name ?? '');
@endphp
<div class="b">{{ $buyerBusiness ?: $buyerContact }}</div>
<div class="muted">
    @if($buyerBusiness && $buyerContact){{ $buyerContact }}<br>@endif
    {{ $billTo['address'] ?? '' }}
    @php $billMobile = $billTo['mobile'] ?: trim(($order->user_country_code ?? '') . ' ' . ($order->user_mobile ?? '')); @endphp
    @if($billMobile)<br>{{ $billMobile }}@endif
    {{-- The buyer's own registration number, so a business order's slip is claimable. --}}
    @if(!empty($order->buyer_tax_number))<br>{{ $order->buyer_tax_label ?: 'Tax No' }}: {{ $order->buyer_tax_number }}@endif
</div>

@if($isPickup)
    <div class="sec">Pickup From</div>
    <div class="b">{{ $order->branch_name ?? '' }}</div>
    <div class="muted">
        {{ $order->branch_formatted_address ?: ($order->branch_address ?? '') }}
        @if(!empty($order->branch_contact_number))<br>{{ $order->branch_contact_number }}@endif
    </div>
@elseif(($shipTo['address'] ?? '') !== '')
    <div class="sec">Ship To</div>
    <div class="b">{{ $shipTo['name'] ?: ($order->user_name ?? '') }}</div>
    <div class="muted">{{ $shipTo['address'] }}</div>
@endif

@if($orderStatus === 7 || $orderStatus === 8)
    <div class="dash">&nbsp;</div>
    <div class="banner">
        This order has been {{ $orderStatus === 8 ? 'returned' : 'cancelled' }}.
        Refunded: {{ $money($order->refund_amount ?? $refundedTotal) }}
    </div>
@endif

@if($activeItems->count())
    <div class="sec">Items</div>
    <table class="it">
        <tr class="hd">
            <td>Item</td>
            <td align="right" width="{{ $tiny ? 34 : 30 }}%">Amount</td>
        </tr>
        @foreach($activeItems as $item)
            <tr>
                <td>
                    {{ $item->product_name }}<br>
                    @php
                        /* Display only — the addon money is already inside the unit price
                           printed below, so this adds nothing to the total. */
                        $addons = collect((array) ($item->addons ?? []))
                            ->map(fn ($a) => is_array($a)
                                ? trim(((int) ($a['qty'] ?? 1) > 1 ? (int) $a['qty'] . ' × ' : '') . ($a['option_name'] ?? ''))
                                : (string) $a)
                            ->filter()->implode(', ');
                    @endphp
                    @if($addons)<span class="muted">+ {{ $addons }}</span><br>@endif
                    <span class="muted">
                        {{ $item->quantity }} &times; {{ $money($item->discounted_price) }}
                        @if(!empty($item->hsn_code)) &bull; HSN {{ $item->hsn_code }}@endif
                    </span>
                </td>
                <td align="right" class="b">{{ $money($item->sub_total) }}</td>
            </tr>
        @endforeach
        @foreach($charges as $row)
            <tr>
                <td>{{ $row['label'] }}</td>
                <td align="right">{{ $money($row['amount']) }}</td>
            </tr>
        @endforeach
    </table>
@endif

@if($refundedItems->count())
    <div class="sec">Cancelled / Returned</div>
    <table class="it">
        @foreach($refundedItems as $item)
            <tr>
                <td>{{ $item->quantity }} &times; {{ $item->product_name }}<br>
                    <span class="muted">{{ (int) $item->active_status === 8 ? 'Returned' : 'Cancelled' }}</span>
                </td>
                <td align="right">{{ $money($item->refund_amount ?? 0) }}</td>
            </tr>
        @endforeach
    </table>
@endif

<div class="dash">&nbsp;</div>

<table class="tt">
    <tr><td>Items Total</td><td class="v">{{ $money($itemsTotal) }}</td></tr>
    @if(!empty($cfg['show_tax_summary']) && ($taxTotal > 0 || count($headTotals)))
        <tr><td>Taxable</td><td class="v">{{ $money($taxable) }}</td></tr>
        @foreach($headTotals as $head => $amount)
            <tr><td>{{ $head }}</td><td class="v">{{ $money($amount) }}</td></tr>
        @endforeach
        @if(!count($headTotals))
            <tr><td>Tax</td><td class="v">{{ $money($taxTotal) }}</td></tr>
        @endif
    @endif
    @if(floatval($order->promo_discount ?? 0) > 0)
        <tr><td>Promo @if($order->promo_code)({{ $order->promo_code }})@endif</td><td class="v">- {{ $money($order->promo_discount) }}</td></tr>
    @endif
    @if(floatval($order->wallet_balance ?? 0) > 0)
        <tr><td>Wallet Used</td><td class="v">- {{ $money($order->wallet_balance) }}</td></tr>
    @endif
    <tr class="grand"><td>Grand Total</td><td class="v">{{ $money($order->remaining_final) }}</td></tr>
    @if($refundedTotal > 0)
        <tr><td>Refunded</td><td class="v">{{ $money($refundedTotal) }}</td></tr>
    @endif
</table>

@if(!empty($cfg['show_signature']))
    <div class="dash">&nbsp;</div>
    <div class="c">
        @if(!empty($cfg['signature']))
            <img src="{{ $cfg['signature'] }}" height="{{ (int) round($base * 2.6) }}"><br>
        @else
            <br><br>
        @endif
        <span class="note">{{ $cfg['signature_label'] }}</span>
    </div>
@endif

<div class="dash">&nbsp;</div>
<div class="c note">
    @if($cfg['footer_note'] !== ''){{ $cfg['footer_note'] }}<br>@endif
    @if($supportNumber){{ $supportNumber }}@endif
    @if($supportEmail) &bull; {{ $supportEmail }}@endif
    @if(!empty($cfg['show_thanks']) && $cfg['thanks_text'] !== '')
        <br><span class="b">{{ $cfg['thanks_text'] }}</span>
    @endif
</div>

</body>
</html>
