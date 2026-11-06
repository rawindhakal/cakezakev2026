<?php

$definitions = [
    'vendor' => [
        'label'    => 'Composer dependencies',
        'chip'     => 'vendor',
        'title'    => 'Dependencies not installed',
        'subtitle' => 'The <b>vendor</b> folder is missing.',
        'intro'    => 'This application ships without its Composer dependencies. Install them once, then reload this page.',
        'hint'     => 'This screen disappears once the <b>vendor</b> folder is present.',
        'steps'    => [
            [
                'text'    => 'From the project root, install the PHP dependencies:',
                'command' => 'composer install --no-dev --optimize-autoloader',
            ],
            ['text' => 'Wait for Composer to finish — it creates the <b>vendor</b> folder.'],
        ],
    ],
    'env' => [
        'label'    => 'Configuration file',
        'chip'     => '.env',
        'title'    => 'Configuration file not found',
        'subtitle' => 'The application needs a <b>.env</b> file to run.',
        'intro'    => 'This application ships without a <code>.env</code> file for security. Create one from the provided example, set your values, then reload this page.',
        'hint'     => 'This screen disappears once a <b>.env</b> file is present.',
        'steps'    => [
            [
                'text'    => 'Copy the example file to <b>.env</b> in the project root:',
                'command' => 'cp .env.example .env',
            ],
            ['text' => 'Open <b>.env</b> and set your database and app details (DB name, user, password, APP_URL, etc.).'],
        ],
    ],
    'build' => [
        'label'    => 'Front-end assets',
        'chip'     => 'public/build',
        'title'    => 'Front-end assets not built',
        'subtitle' => 'The <b>public/build</b> folder is missing.',
        'intro'    => 'The admin panel is a compiled Vue application. Build the front-end assets once, then reload this page.',
        'hint'     => 'This screen disappears once <b>public/build</b> is present.',
        'steps'    => [
            [
                'text'    => 'Install the Node dependencies (only needed the first time):',
                'command' => 'npm install',
            ],
            [
                'text'    => 'Compile the assets into <b>public/build</b>:',
                'command' => 'npm run build',
            ],
        ],
    ],
];

$active = array_values(array_intersect(array_keys($definitions), (array) ($missing ?? [])));
if (!$active) {
    $active = ['env'];
}

$multiple = count($active) > 1;

if ($multiple) {
    // Everything that is missing is reported at once, each with its own fix,
    // so the operator does not discover them one reload at a time.
    $chips    = array_map(static fn ($k) => $definitions[$k]['chip'], $active);
    $last     = array_pop($chips);
    $listed   = $chips ? implode(', ', $chips) . ' and ' . $last : $last;
    $title    = 'Setup required';
    $subtitle = count($active) . ' required items are missing.';
    $intro    = 'These pieces are not in place yet: <b>' . $listed . '</b>. Work through each section below, then reload this page.';
    $hint     = 'This screen disappears once every item above is in place.';
} else {
    $current  = $definitions[$active[0]];
    $title    = $current['title'];
    $subtitle = $current['subtitle'];
    $intro    = $current['intro'];
    $hint     = $current['hint'];
}

// One block per missing item. The final "reload" step is appended once, to the
// last block, so it never repeats when several items are listed.
$groups = [];
foreach ($active as $key) {
    $groups[] = [
        'label' => $definitions[$key]['label'],
        'chip'  => $definitions[$key]['chip'],
        'steps' => $definitions[$key]['steps'],
    ];
}
$groups[count($groups) - 1]['steps'][] = [
    'text' => 'Reload this page — the setup / installation will continue automatically.',
];

$e = static fn ($v) => htmlspecialchars((string) $v, ENT_QUOTES, 'UTF-8');
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Setup required — <?= $e($title) ?></title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            background: #0f172a;
            color: #1e293b;
        }
        .backdrop {
            position: fixed;
            inset: 0;
            background: radial-gradient(1200px 600px at 50% -10%, rgba(254, 60, 94, .18), transparent), #0b1220;
        }
        .modal {
            position: relative;
            width: 100%;
            max-width: 560px;
            background: #ffffff;
            border-radius: 18px;
            box-shadow: 0 30px 80px rgba(0, 0, 0, .45);
            overflow: hidden;
            animation: pop .3s cubic-bezier(.4, 0, .2, 1) both;
        }
        @keyframes pop { from { opacity: 0; transform: translateY(14px) scale(.97); } to { opacity: 1; transform: none; } }
        .modal-head {
            display: flex;
            align-items: center;
            gap: 14px;
            padding: 22px 26px;
            background: linear-gradient(135deg, rgba(245, 158, 11, .12), rgba(245, 158, 11, .02));
            border-bottom: 1px solid #f1f5f9;
        }
        .modal-icon {
            width: 46px;
            height: 46px;
            flex: none;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #fff4e0;
            color: #b45309;
        }
        .modal-icon svg { width: 24px; height: 24px; }
        .modal-title { font-size: 1.18rem; font-weight: 700; color: #0f172a; line-height: 1.2; }
        .modal-sub { font-size: .82rem; color: #64748b; margin-top: 2px; }
        .modal-body { padding: 22px 26px 8px; }
        .modal-body p { font-size: .92rem; color: #475569; line-height: 1.55; margin-bottom: 18px; }
        .grp + .grp { border-top: 1px solid #f1f5f9; padding-top: 16px; }
        .grp-title {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: .84rem;
            font-weight: 700;
            color: #0f172a;
            margin-bottom: 12px;
        }
        .grp-num {
            width: 20px;
            height: 20px;
            flex: none;
            border-radius: 6px;
            background: #fff4e0;
            color: #b45309;
            font-size: .72rem;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .grp-chip {
            font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
            font-size: .72rem;
            font-weight: 500;
            color: #64748b;
            background: #f1f5f9;
            border-radius: 5px;
            padding: 2px 6px;
        }
        .steps { list-style: none; counter-reset: step; }
        .steps li {
            position: relative;
            counter-increment: step;
            padding: 0 0 18px 42px;
            font-size: .9rem;
            color: #334155;
            line-height: 1.5;
        }
        .steps li::before {
            content: counter(step);
            position: absolute;
            left: 0;
            top: -1px;
            width: 26px;
            height: 26px;
            border-radius: 50%;
            background: #FE3C5E;
            color: #fff;
            font-size: .78rem;
            font-weight: 700;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .steps li:not(:last-child)::after {
            content: '';
            position: absolute;
            left: 12.5px;
            top: 28px;
            bottom: 4px;
            width: 1px;
            background: #e2e8f0;
        }
        .cmd {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            margin-top: 8px;
            background: #0f172a;
            border-radius: 10px;
            padding: 10px 12px;
            font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
            font-size: .82rem;
            color: #e2e8f0;
        }
        .cmd code { color: #86efac; white-space: nowrap; overflow-x: auto; }
        .copy-btn {
            flex: none;
            border: 0;
            background: rgba(255, 255, 255, .12);
            color: #fff;
            border-radius: 6px;
            padding: 5px 10px;
            font-size: .74rem;
            cursor: pointer;
        }
        .copy-btn:hover { background: rgba(255, 255, 255, .22); }
        .modal-foot {
            padding: 16px 26px 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
            flex-wrap: wrap;
        }
        .hint { font-size: .78rem; color: #94a3b8; }
        .reload-btn {
            border: 0;
            border-radius: 10px;
            background: #FE3C5E;
            color: #fff;
            font-weight: 600;
            font-size: .9rem;
            padding: 10px 18px;
            cursor: pointer;
        }
        .reload-btn:hover { background: #0c7f1e; }
    </style>
</head>

<body>
    <div class="backdrop"></div>
    <div class="modal" role="dialog" aria-modal="true" aria-labelledby="setupTitle">
        <div class="modal-head">
            <span class="modal-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                    <line x1="12" y1="9" x2="12" y2="13" />
                    <line x1="12" y1="17" x2="12.01" y2="17" />
                </svg>
            </span>
            <div>
                <div class="modal-title" id="setupTitle"><?= $e($title) ?></div>
                <div class="modal-sub"><?= $subtitle ?></div>
            </div>
        </div>

        <div class="modal-body">
            <p><?= $intro ?></p>
            <?php $cmdId = 0; ?>
            <?php foreach ($groups as $g => $group): ?>
                <div class="grp">
                    <?php if ($multiple): ?>
                        <div class="grp-title">
                            <span class="grp-num"><?= (int) $g + 1 ?></span>
                            <?= $e($group['label']) ?>
                            <code class="grp-chip"><?= $e($group['chip']) ?></code>
                        </div>
                    <?php endif; ?>
                    <ol class="steps">
                        <?php foreach ($group['steps'] as $step): ?>
                            <li>
                                <?= $step['text'] ?? '' ?>
                                <?php if (!empty($step['command'])): $cmdId++; ?>
                                    <div class="cmd">
                                        <code id="cmd<?= $cmdId ?>"><?= $e($step['command']) ?></code>
                                        <button type="button" class="copy-btn" onclick="copyCmd(<?= $cmdId ?>, this)">Copy</button>
                                    </div>
                                <?php endif; ?>
                            </li>
                        <?php endforeach; ?>
                    </ol>
                </div>
            <?php endforeach; ?>
        </div>

        <div class="modal-foot">
            <span class="hint"><?= $hint ?></span>
            <button type="button" class="reload-btn" onclick="location.reload()">Reload</button>
        </div>
    </div>

    <script>
        function copyCmd(i, btn) {
            var el = document.getElementById('cmd' + i);
            if (!el) return;
            navigator.clipboard && navigator.clipboard.writeText(el.textContent);
            if (btn) { btn.textContent = 'Copied'; setTimeout(function () { btn.textContent = 'Copy'; }, 1500); }
        }
    </script>
</body>

</html>
