@php
    $appName = \App\Models\Setting::get_value('app_name');
    if($appName == "" || $appName == null){ $appName = "CakeZake"; }

    $supportEmail = \App\Models\Setting::get_value('support_email') ?? '';
    $supportNumber = \App\Models\Setting::get_value('support_number') ?? '';

    $logo = \App\Models\Setting::get_value('logo') ?? '';

    $logoDisk = $logo !== '' ? public_path('storage/'.$logo) : null;
    $logo_full_path = ($logoDisk && is_file($logoDisk)) ? $logoDisk : public_path('images/favicon.png');

    /* Print settings (Settings → Invoice). Callers pass them in; the fallback keeps
       this template usable on its own. */
    $cfg = $invoice_cfg ?? \App\Helpers\CommonHelper::documentSettings()['invoice'];
    // A custom invoice logo overrides the app logo; both fall back to the favicon.
    if (!empty($cfg['logo'])) { $logo_full_path = $cfg['logo']; }
    // Every hard-coded size in the stylesheet below is scaled off the configured body size.
    $k  = ((float) $cfg['font_size']) / 11;
    $fs = fn ($px) => round(((float) $px) * $k, 2);
    $bodyWeight = !empty($cfg['bold_text']) ? 'bold' : 'normal';

    $currency = trim((string) ($order->currency ?? ''));

    // Brand / primary colour (admin theme), fallback to default.
    $primary = \App\Models\Setting::get_value('admin_theme_color');
    if(!preg_match('/^#[0-9a-fA-F]{6}$/', (string) $primary)){ $primary = '#435ebe'; }
    // Mono mode: thermal and laser-mono printers render a tinted fill as grey mush.
    if (!empty($cfg['mono'])) { $primary = '#000000'; }

    $money = fn($v) => $currency.' '.number_format((float) $v, 2);
    $pct   = fn($v) => rtrim(rtrim(number_format((float) $v, 3, '.', ''), '0'), '.').'%';

    $isTaxInvoice = !empty($order->branch_tax_number);
    $docSub = $isTaxInvoice ? 'Tax Invoice' : '';
@endphp
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>INVOICE #{{ $order->order_id }} - {{ $appName }}</title>
    <style>
        body { font-family: sans-serif; color:#1f2430; font-size:{{ $fs(11) }}px; background:#fff; margin:0;
               font-weight:{{ $bodyWeight }}; }
        .invoice { background:#fff; width:100%; padding:0; }
        .inv-topbar { height:6px; background:{{ $primary }}; font-size:0; line-height:0; }
        .inv-brand { font-size:{{ $fs(20) }}px; font-weight:bold; color:{{ $primary }}; }
        .inv-doc { font-size:{{ $fs(22) }}px; font-weight:bold; color:#12161f; letter-spacing:.5px; }
        .inv-doc-sub { font-size:{{ $fs(9.5) }}px; color:#8a93a5; }

        /* Micro-caps section label. Carries the accent so headings stay black. */
        .eyebrow { font-size:{{ $fs(9) }}px; font-weight:bold; color:{{ $primary }}; text-transform:uppercase; letter-spacing:.8px; }

        /* Label/value pairs: muted key, bold value, no rules — the alignment does the work. */
        table.kv { width:100%; border-collapse:collapse; font-size:{{ $fs(10.5) }}px; }
        table.kv td { padding:2.5px 0; vertical-align:top; line-height:1.45; }
        table.kv .k { color:#8a93a5; width:44%; }
        table.kv .v { font-weight:bold; color:#1f2430; }

        .cardbox { border:1px solid #e4e9f0; border-radius:8px; background:#fff; }
        table.split { width:100%; border-collapse:collapse; }
        table.split td { padding:11px 14px; vertical-align:top; }
        table.split td.rgt { border-left:1px solid #eef1f6; }

        table.hstrip { width:100%; border-collapse:collapse; }
        table.hstrip td { padding:5px 8px 1px 0; vertical-align:top; }
        .hk { color:#8a93a5; font-size:{{ $fs(8.5) }}px; text-transform:uppercase; letter-spacing:.5px; }
        .hv { font-weight:bold; color:#1f2430; font-size:{{ $fs(10.5) }}px; }

        .nm { font-weight:bold; font-size:{{ $fs(11.5) }}px; color:#12161f; }
        .sub { color:#7a8397; font-size:{{ $fs(10.5) }}px; line-height:1.65; }

        .sec-h { font-size:{{ $fs(12) }}px; font-weight:bold; color:#12161f; text-transform:uppercase; letter-spacing:.6px; }
        .sec-c { font-size:{{ $fs(9.5) }}px; color:#8a93a5; }

        .thead-cap { height:8px; background:{{ $primary }}; border-radius:8px 8px 0 0;
                     font-size:0; line-height:0; }
        .thead-cap-red { height:8px; background:#b3261e; border-radius:8px 8px 0 0;
                         font-size:0; line-height:0; }
        table.items { width:100%; border-collapse:collapse; font-size:{{ $fs(10.5) }}px; }
        table.items thead th { background:{{ $primary }}; color:#fff; padding:6px 6px 8px; font-weight:bold;
                               font-size:{{ $fs(8.8) }}px; text-transform:uppercase; letter-spacing:.6px; }
        table.items tbody td { padding:9px 6px; border-bottom:1px solid #eef1f6; vertical-align:top; }
        table.items tbody tr.alt td { background:#f7f9fb; }
        table.items tfoot td { padding:8px 6px; font-weight:bold; border-top:1.5px solid #d9dfea; }
        .pname { font-weight:bold; color:#1f2430; }
        .psub { color:#98a0af; font-size:{{ $fs(9.5) }}px; }
        .rate-note { color:#98a0af; font-size:{{ $fs(9) }}px; }
        table.tot { width:100%; border-collapse:collapse; font-size:{{ $fs(10.5) }}px; }
        table.tot td { padding:6px 2px; border-bottom:1px dotted #dfe4ec; }
        table.tot .tk { color:#7a8397; }
        table.tot .tv { text-align:right; font-weight:bold; color:#1f2430; }
        table.tot tr.grand td { border-bottom:none; border-top:1.5px solid #cfd6e2; padding-top:9px; }
        table.tot tr.grand .tk { color:#12161f; font-weight:bold; font-size:{{ $fs(12.5) }}px; }
        table.tot tr.grand .tv { color:{{ $primary }}; font-weight:bold; font-size:{{ $fs(15) }}px; }
        table.tot tr.refund .tk, table.tot tr.refund .tv { color:#c0392b; font-weight:bold; }

        .footnote { color:#98a0af; font-size:{{ $fs(9) }}px; }
        .footbrand { font-weight:bold; font-size:{{ $fs(9) }}px; color:#4b5566; }
        .thanks { background:{{ $primary }}; color:#fff; font-weight:bold; text-align:center;
                  padding:10px; border-radius:5px; font-size:{{ $fs(11) }}px; letter-spacing:.3px; }
        .rule { border-top:1px solid #eef1f6; font-size:0; line-height:0; }

        /* Status banner keeps the panel language: tint plus a coloured left edge. */
        .banner { padding:9px 13px; border-radius:8px; font-weight:bold; font-size:{{ $fs(11) }}px;
                  background:#fdecea; color:#c0392b; border-left:3px solid #c0392b; }
        .badge-st { display:inline-block; padding:2px 8px; border-radius:9px; font-size:{{ $fs(9) }}px; font-weight:bold; }
        .b-cancel { background:#fdecea; color:#c0392b; }
        .b-return { background:#fff4e5; color:#b9770e; }
        table.ritems { width:100%; border-collapse:collapse; font-size:{{ $fs(10.5) }}px; }
        table.ritems thead th { background:#b3261e; color:#fff; padding:6px 6px 8px; font-weight:bold;
                                font-size:{{ $fs(8.8) }}px; text-transform:uppercase; letter-spacing:.6px; }
        table.ritems tbody td { padding:9px 6px; border-bottom:1px solid #f3d6d3; }
    </style>
</head>
<body>

@php

    $addresses = \App\Helpers\CommonHelper::orderAddresses($order->address ?? null);
    $shipTo = $addresses['shipping'] ?? [];
    $billTo = $addresses['billing'] ?? $shipTo;

    $allItems      = collect($order_items);
    $activeItems   = $allItems->filter(fn($i) => !in_array((int) $i->active_status, [7, 8]))->values();
    $refundedItems = $allItems->filter(fn($i) => in_array((int) $i->active_status, [7, 8]))->values();
    $refundedTotal = (float) $refundedItems->sum('refund_amount');
    $orderStatus   = (int) ($order->active_status ?? 0);

    /* --- GOODS: heads used by the item lines only. A head that exists solely on a
           delivery fee gets no column here — a column of zeros reads as an error. */
    $itemHeadNames = $activeItems
        ->flatMap(fn($i) => collect($i->tax_lines ?? [])->map(fn($l) => data_get($l, 'component_name')))
        ->filter()->unique()->values()->all();

    $itemHeadTotals = array_fill_keys($itemHeadNames, 0.0);
    $itemsTax       = 0.0;
    $itemsTaxable   = 0.0;
    $itemsTotal     = 0.0;

    foreach ($activeItems as $item) {
        // tax_total is the LINE figure; tax_amount is per unit.
        $lineTax     = (float) ($item->tax_total ?? 0);
        $lineTaxable = (float) ($item->taxable_value ?? 0);
        $itemsTax     += $lineTax;
        $itemsTaxable += $lineTaxable;
        $itemsTotal   += (float) $item->sub_total;

        // Each head carries its own rate so the column can print "₹ 12.50 (9%)" —
        // that is where the rate lives now, in place of a separate summary table.
        $heads = collect($item->tax_lines ?? [])
            ->groupBy(fn($l) => data_get($l, 'component_name'))
            ->map(fn($g) => [
                'amount' => round(collect($g)->sum(fn($l) => (float) data_get($l, 'amount')), 2),
                'rate'   => (float) data_get(collect($g)->first(), 'rate'),
            ]);
        foreach ($heads as $name => $head) {
            $itemHeadTotals[$name] = round(($itemHeadTotals[$name] ?? 0) + $head['amount'], 2);
        }
        $item->_heads   = $heads;
        $item->_lineTax = $lineTax;
        $item->_taxable = $lineTaxable;
    }

    /* --- CHARGES: delivery / surge / additional, each with its own tax. These are NOT
           goods — they get their own page so the item table stays a clean tax invoice. */
    $chargeLines = collect($order->charge_tax_lines ?? []);
    $linesFor = fn($source, $ref = null) => $chargeLines->filter(function ($l) use ($source, $ref) {
        if (data_get($l, 'source') !== $source) { return false; }
        return $ref === null ? true : ((string) data_get($l, 'source_ref') === (string) $ref);
    })->values();

    $chargeRows = [];
    $pushCharge = function ($label, $total, $lines) use (&$chargeRows) {
        $total = (float) $total;
        if ($total <= 0 && $lines->isEmpty()) { return; }
        $tax = round($lines->sum(fn($l) => (float) data_get($l, 'amount')), 2);
        $chargeRows[] = [
            'label'   => $label,
            'taxable' => round($total - $tax, 2),
            'tax'     => $tax,
            'total'   => round($total, 2),
            'heads'   => $lines->groupBy(fn($l) => data_get($l, 'component_name'))
                               ->map(fn($g) => [
                                   'amount' => round(collect($g)->sum(fn($l) => (float) data_get($l, 'amount')), 2),
                                   'rate'   => (float) data_get(collect($g)->first(), 'rate'),
                               ]),
        ];
    };

    // A self-pickup order has no delivery to charge for, so no line for it.
    $isPickup = ($order->delivery_type ?? 'delivery') === 'pickup';
    if (!$isPickup) {
        $pushCharge('Delivery Charge', $order->delivery_charge ?? 0, $linesFor('delivery'));
    }

    $surge = $order->surge_charges ?? [];
    $surge = is_string($surge) ? (json_decode($surge, true) ?: []) : (is_array($surge) ? $surge : []);
    foreach ($surge as $slot) {
        $label = $slot['label'] ?? 'Surge';
        $pushCharge($label, $slot['charge'] ?? 0, $linesFor('surge', $label));
    }

    $additional = $order->additional_charges ?? [];
    $additional = is_string($additional) ? (json_decode($additional, true) ?: []) : (is_array($additional) ? $additional : []);
    foreach ($additional as $c) {
        $name = $c['title'] ?? $c['name'] ?? 'Additional Charge';
        $pushCharge($name, $c['amount'] ?? 0, $linesFor('additional', $c['name'] ?? $name));
    }

    $chargeHeadNames  = $chargeLines->map(fn($l) => data_get($l, 'component_name'))->filter()->unique()->values()->all();
    $chargeHeadTotals = $chargeLines->groupBy(fn($l) => data_get($l, 'component_name'))
        ->map(fn($g) => round(collect($g)->sum(fn($l) => (float) data_get($l, 'amount')), 2))->all();
    $chargeTaxTotal = round($chargeLines->sum(fn($l) => (float) data_get($l, 'amount')), 2);
    $chargeTaxable  = round(collect($chargeRows)->sum('taxable'), 2);

    $allHeadNames = array_values(array_unique(array_merge($itemHeadNames, $chargeHeadNames)));
    $allHeadTotals = [];
    foreach ($allHeadNames as $head) {
        $allHeadTotals[$head] = round(($itemHeadTotals[$head] ?? 0) + ($chargeHeadTotals[$head] ?? 0), 2);
    }
  
    $chargesPayable     = !in_array($orderStatus, [7, 8], true);
    $tableChargeRows    = $chargesPayable ? $chargeRows : [];
    $chargesTotal       = round(collect($tableChargeRows)->sum('total'), 2);
    $orderTotal         = round($itemsTotal + $chargesTotal, 2);
    $allTaxable = round($itemsTaxable + ($chargesPayable ? $chargeTaxable : 0), 2);
    $allTax     = round($itemsTax + ($chargesPayable ? $chargeTaxTotal : 0), 2);

    // Column widths shrink as tax heads are added. A head column has to fit
    // "₹ 1,234.56" plus its rate, so it never drops below 11%. Items and charges share one
    // table, so the head columns are the union of both.
    $prodWidth   = max(16, 48 - 11 * count($allHeadNames));

    $branchName = $order->branch_name ?? $order->branch_name ?? $appName;

    /* The two identity groups as flat [label, value] lists. Empty facts drop out here so
       the strip below never prints a blank column, and each group lays itself out three
       to a line. Page 2 reuses both without restating a single field. */
    $invFacts = array_values(array_filter([
        ['Invoice No.',  $order->invoice_number ?? ('#' . $order->order_id)],
        ['Invoice Date', $order->orders_created_at_local ?? $order->orders_created_at],
        ['Order No.',    $order->order_number ?? ('#' . $order->order_id)],
        !empty($order->place_of_supply_label) ? ['Place of Supply', $order->place_of_supply_label] : null,
    ]));

    // Contact details come off the branch row; each one drops out when it is not filled in.
    $branchPhone   = trim((string) ($order->branch_contact_number ?? ''));
    $branchEmail   = trim((string) ($order->branch_email ?? $order->branch_email ?? ''));
    $branchAddress = trim((string) ($order->branch_formatted_address ?: ($order->branch_address ?? '')));

    $branchFacts = array_values(array_filter([
        ['Branch', $branchName],
        !empty($order->branch_tax_number)  ? [$order->branch_registration_type ?? 'Tax No', $order->branch_tax_number] : null,
        $branchEmail !== '' ? ['Email', $branchEmail] : null,
        $branchPhone !== '' ? ['Phone', $branchPhone] : null,
    ]));
@endphp

    <section class="invoice" id="printMe">

        {{-- ---------------------------------------------------------------- page 1 --}}
        <div class="inv-topbar">&nbsp;</div>
        <br>

        <table width="100%">
            <tr>
                <td width="58%" style="vertical-align:middle;">
                    {{-- The logo already carries the wordmark, so the name is printed
                         only when the logo is off. --}}
                    @if(!empty($cfg['show_logo']))
                        <img src="{{ $logo_full_path }}" height="{{ (int) $cfg['logo_height'] }}" style="vertical-align:middle;">
                    @else
                        <span class="inv-brand" style="vertical-align:middle;">{{ $appName }}</span>
                    @endif
                </td>
                <td width="42%" style="vertical-align:middle; text-align:right;">
                    <span class="inv-doc">INVOICE</span>
                    @if($docSub)<br><span class="inv-doc-sub">{{ $docSub }}</span>@endif
                    @if($cfg['header_note'] !== '')<br><span class="inv-doc-sub">{{ $cfg['header_note'] }}</span>@endif
                </td>
            </tr>
        </table>
        <br>

        <div class="cardbox">
            <table class="split">
                <tr>
                    <td width="50%">
                        <span class="eyebrow">Invoice Details</span>
                        <table class="hstrip">
                            @foreach(array_chunk($invFacts, 3) as $row)
                                <tr>
                                    @foreach($row as $fact)
                                        <td width="33%"><span class="hk">{{ $fact[0] }}</span><br><span class="hv">{{ $fact[1] }}</span></td>
                                    @endforeach
                                    @for($i = count($row); $i < 3; $i++)<td width="33%"></td>@endfor
                                </tr>
                            @endforeach
                        </table>
                    </td>
                    <td width="50%" class="rgt">
                        <span class="eyebrow">Sold By</span>
                        <table class="hstrip">
                            @foreach(array_chunk($branchFacts, 3) as $row)
                                <tr>
                                    @foreach($row as $fact)
                                        <td width="33%"><span class="hk">{{ $fact[0] }}</span><br><span class="hv">{{ $fact[1] }}</span></td>
                                    @endforeach
                                    @for($i = count($row); $i < 3; $i++)<td width="33%"></td>@endfor
                                </tr>
                            @endforeach
                            {{-- Full width: an address does not fit a third of the strip. --}}
                            @if($branchAddress !== '')
                                <tr>
                                    <td colspan="3"><span class="hk">Address</span><br><span class="hv">{{ $branchAddress }}</span></td>
                                </tr>
                            @endif
                        </table>
                    </td>
                </tr>
            </table>
        </div>
        <br>

        {{-- Both parties, always printed in full. A tax invoice states each address
             explicitly — a cross-reference in place of one is not a record. --}}
        <div class="cardbox">
            <table class="split">
                <tr>
                    <td width="50%">
                        <div class="eyebrow">Bill To</div>
                        {{-- A business buyer is billed in its registered name; the person who
                             placed the order is then the contact, printed under it. --}}
                        @php
                            $buyerBusiness = $order->buyer_business_name ?: null;
                            $buyerContact  = $billTo['name'] ?: ($order->user_name ?? '');
                        @endphp
                        <div class="nm" style="padding-top:5px;">{{ $buyerBusiness ?: $buyerContact }}</div>
                        <div class="sub" style="padding-top:3px;">
                            @if($buyerBusiness && $buyerContact){{ $buyerContact }}<br>@endif
                            {{ $billTo['address'] ?? '' }}<br>
                            @php $billMobile = $billTo['mobile'] ?: trim(($order->user_country_code ?? '').' '.($order->user_mobile ?? '')); @endphp
                            @if($billMobile){{ $billMobile }}<br>@endif
                            @if(!empty($order->user_email)){{ $order->user_email }}<br>@endif
                            {{-- The buyer's own registration number: without it on the face of
                                 the invoice the buyer cannot claim credit for the tax it paid. --}}
                            @if(!empty($order->buyer_tax_number))
                                <b>{{ $order->buyer_tax_label ?: 'Tax No' }}:</b> {{ $order->buyer_tax_number }}
                            @endif
                        </div>
                    </td>
                    <td width="50%" class="rgt">
                        @if($isPickup)
                        {{-- Collected at the counter: the branch is where the goods went. --}}
                        <div class="eyebrow">Pickup From</div>
                        <div class="nm" style="padding-top:5px;">{{ $order->branch_name ?? '' }}</div>
                        <div class="sub" style="padding-top:3px;">
                            {{ $order->branch_formatted_address ?: ($order->branch_address ?? '') }}<br>
                            @if(!empty($order->branch_contact_number)){{ $order->branch_contact_number }}@endif
                        </div>
                        @else
                        <div class="eyebrow">Ship To</div>
                        <div class="nm" style="padding-top:5px;">{{ $shipTo['name'] ?: ($order->user_name ?? '') }}</div>
                        <div class="sub" style="padding-top:3px;">
                            {{ $shipTo['address'] ?? '' }}<br>
                            @php $shipMobile = $shipTo['mobile'] ?: trim(($order->user_country_code ?? '').' '.($order->user_mobile ?? '')); @endphp
                            @if($shipMobile){{ $shipMobile }}@endif
                        </div>
                        @endif
                    </td>
                </tr>
            </table>
        </div>
        <br>

        @if($orderStatus === 7)
            <div class="banner">This order has been cancelled. Refunded: {{ $money($order->refund_amount ?? $refundedTotal) }}</div>
            <br>
        @elseif($orderStatus === 8)
            <div class="banner">This order has been returned. Refunded: {{ $money($order->refund_amount ?? $refundedTotal) }}</div>
            <br>
        @endif

        @if($activeItems->count())
        <table width="100%" style="margin-bottom:6px;">
            <tr>
                <td class="sec-h">Items, Charges &amp; Tax Details</td>
                <td class="sec-c" align="right"></td>
            </tr>
        </table>
        <div class="thead-cap">&nbsp;</div>
        <table class="items">
            <thead>
                <tr>
                    <th align="center" width="4%">#</th>
                    <th align="left" width="{{ $prodWidth }}%">Particulars</th>
                    <th align="right" width="11%">Price</th>
                    <th align="right" width="12%">Disc.</th>
                    @if(count($allHeadNames))
                        <th align="right" width="12%">Taxable</th>
                        @foreach($allHeadNames as $head)
                            <th align="right" width="11%">{{ $head }}</th>
                        @endforeach
                    @else
                        <th align="right" width="15%">Tax</th>
                    @endif
                    <th align="right" width="13%">Total</th>
                </tr>
            </thead>
            <tbody>
                @foreach($activeItems as $index => $item)
                    <tr class="{{ $index % 2 ? 'alt' : '' }}">
                        <td align="center" class="psub">{{ $index+1 }}</td>
                        <td align="left">
                            <span class="pname">{{ $item->quantity }} &times; {{ $item->product_name }}</span>
                            @php
                                /* Display only: the addon money is already inside the unit
                                   price, so listing it here adds nothing to any total. */
                                $addons = collect((array) ($item->addons ?? []))
                                    ->map(fn ($a) => is_array($a)
                                        ? trim(((int) ($a['qty'] ?? 1) > 1 ? (int) $a['qty'] . ' × ' : '') . ($a['option_name'] ?? ''))
                                        : (string) $a)
                                    ->filter()->implode(', ');
                            @endphp
                            @if($addons)<br><span class="psub">{{ __('addons') }}: {{ $addons }}</span>@endif
                            @if(!empty($item->hsn_code))<br><span class="psub">HSN: {{ $item->hsn_code }}</span>@endif
                        </td>
                        @php
                            $paidUnit = (float) $item->discounted_price;
                            $discUnit = max(0, round((float) $item->price - $paidUnit, 2));
                        @endphp
                        <td align="right">{{ $money($paidUnit) }}</td>
                        <td align="right">{{ $money($discUnit) }}</td>
                        @if(count($allHeadNames))
                            <td align="right">{{ $money($item->_taxable) }}</td>
                            @foreach($allHeadNames as $head)
                                <td align="right">
                                    {{ $money($item->_heads[$head]['amount'] ?? 0) }}
                                    @if(isset($item->_heads[$head]))<br><span class="rate-note">({{ $pct($item->_heads[$head]['rate']) }})</span>@endif
                                </td>
                            @endforeach
                        @else
                            <td align="right">{{ $money($item->_lineTax) }} <span class="rate-note">({{ $item->tax_percentage }}%)</span></td>
                        @endif
                        <td align="right">{{ $money($item->sub_total) }}</td>
                    </tr>
                @endforeach

                {{-- Charges continue the same table so the invoice reads as one running
                     bill instead of splitting across pages. --}}
                @foreach($tableChargeRows as $index => $row)
                    <tr class="{{ ($activeItems->count() + $index) % 2 ? 'alt' : '' }}">
                        <td align="center" class="psub">{{ $activeItems->count() + $index + 1 }}</td>
                        <td align="left"><span class="pname">{{ $row['label'] }}</span></td>
                        {{-- A charge has no list price or discount: its amount IS the price. --}}
                        <td align="right">{{ $money($row['total']) }}</td>
                        <td align="right">{{ $money(0) }}</td>
                        @if(count($allHeadNames))
                            <td align="right">{{ $money($row['taxable']) }}</td>
                            @foreach($allHeadNames as $head)
                                <td align="right">
                                    {{ $money($row['heads'][$head]['amount'] ?? 0) }}
                                    @if(isset($row['heads'][$head]))<br><span class="rate-note">({{ $pct($row['heads'][$head]['rate']) }})</span>@endif
                                </td>
                            @endforeach
                        @else
                            <td align="right">{{ $money($row['tax']) }}</td>
                        @endif
                        <td align="right">{{ $money($row['total']) }}</td>
                    </tr>
                @endforeach
            </tbody>
            <tfoot>
                <tr>
                    <td colspan="2" align="right">Total</td>
                    <td align="right"></td>
                    <td align="right"></td>
                    @if(count($allHeadNames))
                        <td align="right">{{ $money($allTaxable) }}</td>
                        @foreach($allHeadNames as $head)
                            <td align="right">{{ $money($allHeadTotals[$head] ?? 0) }}</td>
                        @endforeach
                    @else
                        <td align="right">{{ $money($allTax) }}</td>
                    @endif
                    <td align="right">{{ $money($orderTotal) }}</td>
                </tr>
            </tfoot>
        </table>
        <br>
        @endif

        {{-- Cancelled / Returned items (refunded) --}}
        @if($refundedItems->count())
        <table width="100%" style="margin-bottom:6px;">
            <tr>
                <td class="sec-h" style="color:#b3261e;">Cancelled / Returned Items</td>
                <td class="sec-c" align="right">{{ $refundedItems->count() }} {{ $refundedItems->count() === 1 ? 'Item' : 'Items' }}</td>
            </tr>
        </table>
        <div class="thead-cap-red">&nbsp;</div>
        <table class="ritems">
            <thead>
                <tr>
                    <th align="center" width="5%">#</th>
                    <th align="left" width="55%">Particulars</th>
                    <th align="center" width="18%">Status</th>
                    <th align="right" width="22%">Refund</th>
                </tr>
            </thead>
            <tbody>
                @foreach($refundedItems as $index => $item)
                    <tr>
                        <td align="center" class="psub">{{ $index+1 }}</td>
                        <td align="left">
                            <span class="pname">{{ $item->quantity }} &times; {{ $item->product_name }}</span>
                            @if(!empty($item->hsn_code))<br><span class="psub">HSN: {{ $item->hsn_code }}</span>@endif
                        </td>
                        <td align="center">
                            <span class="badge-st {{ (int)$item->active_status === 8 ? 'b-return' : 'b-cancel' }}">
                                {{ (int)$item->active_status === 8 ? 'Returned' : 'Cancelled' }}
                            </span>
                        </td>
                        <td align="right">{{ $money($item->refund_amount ?? 0) }}</td>
                    </tr>
                @endforeach
            </tbody>
        </table>
        <br>
        @endif

        <div class="cardbox">
            <table class="split">
                <tr>
                    <td width="50%">
                        <div class="eyebrow">Payment &amp; Notes</div>
                        <table class="kv" style="padding-top:4px;">
                            <tr>
                                <td class="k">Payment Method</td>
                                <td class="v">{{ strtoupper($order->payment_method) }}</td>
                            </tr>
                            @if($supportEmail)
                                <tr><td class="k">Support</td><td class="v">{{ $supportEmail }}</td></tr>
                            @endif
                            @if($supportNumber)
                                <tr><td class="k">Helpline</td><td class="v">{{ $supportNumber }}</td></tr>
                            @endif
                        </table>
                        <div class="sub" style="padding-top:7px;">Thank you for shopping with {{ $appName }}.</div>
                    </td>
                    <td width="50%" class="rgt">
                        <table class="tot">
                            @if(!empty($cfg['show_tax_summary']) && (count($allHeadNames) || $allTax > 0))
                                <tr>
                                    <td class="tk">Taxable Amount</td>
                                    <td class="tv">{{ $money($allTaxable) }}</td>
                                </tr>
                                @foreach($allHeadNames as $head)
                                    <tr>
                                        <td class="tk">{{ $head }}</td>
                                        <td class="tv">{{ $money($allHeadTotals[$head]) }}</td>
                                    </tr>
                                @endforeach
                                @if(!count($allHeadNames))
                                    <tr>
                                        <td class="tk" style="color:#1f2430; font-weight:bold;">Tax</td>
                                        <td class="tv">{{ $money($allTax) }}</td>
                                    </tr>
                                @endif
                            @endif


                            @if(floatval($order->promo_discount) > 0)
                                <tr><td class="tk">Promo @if($order->promo_code)({{ $order->promo_code }})@endif</td><td class="tv">- {{ $money($order->promo_discount) }}</td></tr>
                            @endif
                            @if(floatval($order->wallet_balance) > 0)
                                <tr><td class="tk">Wallet Used</td><td class="tv">- {{ $money($order->wallet_balance) }}</td></tr>
                            @endif
                            <tr class="grand"><td class="tk">Grand Total</td><td class="tv">{{ $money($order->remaining_final) }}</td></tr>
                            @if($refundedTotal > 0)
                                <tr class="refund"><td class="tk">Refunded</td><td class="tv">{{ $money($refundedTotal) }}</td></tr>
                            @endif
                        </table>
                    </td>
                </tr>
            </table>
        </div>
        <br>

        {{-- Signature: an image when one is uploaded, otherwise a ruled space to sign. --}}
        @if(!empty($cfg['show_signature']))
            <table width="100%" style="margin-top:6px;">
                <tr>
                    <td width="62%"></td>
                    <td width="38%" align="center">
                        @if(!empty($cfg['signature']))
                            <img src="{{ $cfg['signature'] }}" height="{{ (int) round(38 * $k) }}"><br>
                        @else
                            <br><br>
                        @endif
                        <div class="rule">&nbsp;</div>
                        <span class="footnote">{{ $cfg['signature_label'] }}</span>
                    </td>
                </tr>
            </table>
            <br>
        @endif

        <div class="rule">&nbsp;</div>
        <table width="100%" style="margin-top:8px;">
            <tr>
                <td width="60%" class="footnote">{{ $cfg['footer_note'] }}</td>
                <td width="40%" class="footbrand" align="right">
                    {{ $appName }}@if(!empty($order->branch_region_name)) &bull; {{ $order->branch_region_name }}@endif
                </td>
            </tr>
        </table>
        @if(!empty($cfg['show_thanks']) && $cfg['thanks_text'] !== '')
            <br>
            <div class="thanks">{{ $cfg['thanks_text'] }}</div>
        @endif
    </section>

</body>
</html>
