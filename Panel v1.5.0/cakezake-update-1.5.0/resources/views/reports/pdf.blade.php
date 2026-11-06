<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        * { font-family: sans-serif; }
        body { color: #1f2937; font-size: 10px; margin: 0; }

        .head { border-bottom: 2px solid {{ $theme }}; padding-bottom: 8px; margin-bottom: 12px; }
        .head h1 { margin: 0 0 4px; font-size: 17px; color: {{ $theme }}; }
        .head .meta { color: #6b7280; font-size: 9px; }

        .kpis { width: 100%; margin-bottom: 14px; }
        .kpis td {
            width: 25%; padding: 7px 9px; border: 1px solid #e5e7eb;
            border-radius: 4px; background: #f9fafb;
        }
        .kpis .k-label { color: #6b7280; font-size: 8px; text-transform: uppercase; letter-spacing: .3px; }
        .kpis .k-value { font-size: 13px; font-weight: bold; color: #111827; padding-top: 2px; }

        table.data { width: 100%; border-collapse: collapse; }
        table.data th {
            background: {{ $theme }}; color: #fff; text-align: left;
            padding: 6px 7px; font-size: 9px; text-transform: uppercase; letter-spacing: .3px;
        }
        table.data td { padding: 5px 7px; border-bottom: 1px solid #eef0f4; font-size: 9px; }
        table.data tr:nth-child(even) td { background: #fafbfc; }
        .num { text-align: right; }

        .foot { margin-top: 14px; color: #9ca3af; font-size: 8px; text-align: center; }
        .empty { padding: 20px; text-align: center; color: #9ca3af; }
    </style>
</head>
<body>

<div class="head">
    <h1>{{ $title }}</h1>
    <div class="meta">
        {{ $app_name }}
        @if($scope) &nbsp;•&nbsp; {{ $scope }} @endif
        &nbsp;•&nbsp; {{ $period_label }}
        @if($range) ({{ $range }}) @endif
        &nbsp;•&nbsp; {{ __('generated') }}: {{ $generated_at }}
    </div>
</div>

@if(!empty($kpis))
    <table class="kpis">
        @foreach(array_chunk($kpis, 4) as $chunk)
            <tr>
                @foreach($chunk as $k)
                    <td>
                        <div class="k-label">{{ $k['label'] }}</div>
                        <div class="k-value">{{ $k['value'] }}</div>
                    </td>
                @endforeach
                {{-- pad the last row so the cells keep their width --}}
                @for($i = count($chunk); $i < 4; $i++)
                    <td style="border: none; background: none;"></td>
                @endfor
            </tr>
        @endforeach
    </table>
@endif

@if(count($rows))
    <table class="data">
        <thead>
        <tr>
            @foreach($headings as $h)
                <th>{{ $h }}</th>
            @endforeach
        </tr>
        </thead>
        <tbody>
        @foreach($rows as $row)
            <tr>
                @foreach($row as $cell)
                    <td class="{{ is_numeric(str_replace([',', '.'], '', (string) $cell)) ? 'num' : '' }}">{{ $cell }}</td>
                @endforeach
            </tr>
        @endforeach
        </tbody>
    </table>
@else
    <div class="empty">{{ __('no_records_found') }}</div>
@endif

<div class="foot">{{ $app_name }} — {{ $title }}</div>

</body>
</html>
