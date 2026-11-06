<?php

/*
|--------------------------------------------------------------------------
| Available plugins
|--------------------------------------------------------------------------
|
| The shop window on the Plugins page: what exists, what it does and where to buy it.
| Static for now — the panel reads this file, so nothing outside the install is
| contacted. A later release replaces PluginCatalog's reader with a cached HTTP fetch
| from cakezake.com; the shape of each entry is already what that endpoint will return, so
| only the source changes.
|
| `slug` must match the plugin's own slug: it is how an entry is paired with an
| installed row, so the card can say "Installed 1.0.0 — update available".
*/

return [

    'plugins' => [

        [
            'slug'         => 'shiprocket',
            'name'         => 'Shiprocket',
            'tagline'      => 'shiprocket_plugin_tagline',
            'description'  => 'shiprocket_plugin_description',
            'type'         => 'shipping',
            'version'      => '1.0.0',
            'core_min'     => '1.4.0',
            'countries'    => ['IN'],
            'icon'         => 'truck',
            'buy_url'      => 'https://cakezake.com/products/shiprocket-cakezake-add-on',
            'docs_url'     => 'https://cakezake.com/docs/cakezake/docs/admin/shiprocket-addon',
            'highlights'   => [
                'shiprocket_highlight_rates',
                'shiprocket_highlight_serviceability',
                'shiprocket_highlight_shipments',
                'shiprocket_highlight_tracking',
            ],
        ],

        [
            'slug'         => 'payu-india-payment-gateway',
            /* What the apps call this gateway. The slug identifies the package the
               same way in every CakeZake product, but it is long and it is not what
               CakeZake's apps already send as `payment_method`, so the short code is
               kept here and the slug stays the package's business. */
            'payment_code' => 'payu',
            'name'         => 'PayU India',
            'payment_label' => 'PayU',

            /*
             | How this plugin's fields are presented, without touching the package.
             |
             | `module.json` belongs to CakeZake and installs in every product, so its
             | field list is the plugin's business and its order is whatever suited the
             | product it was written for. Presentation is ours: which field an admin
             | should answer first, what a sensible starting value is, and which values
             | are actually accepted. Keeping that here means an update to the plugin
             | never overwrites it and the package stays identical everywhere.
             |
             | Anything not named here keeps the manifest's own order and type.
             */
            'fields'       => [
                // Asked first: it decides which of the two PayU environments the
                // credentials below belong to, so answering it last invites a mismatch.
                'payment_mode'  => [
                    'position' => 10,
                    /* PayU's own value for its non-live environment is `test`; the
                       default has to BE one of the options or the select renders
                       empty and the admin is asked to pick something that already
                       had an obvious answer. Relabelled Sandbox, which is what the
                       environment is called everywhere else in the panel. */
                    'default'  => 'test',
                    'options'  => ['test' => 'Sandbox', 'live' => 'Live'],
                ],
                /* PayU's Payment Links is a domestic India product and settles in
                   rupees; their multi-currency support is a separate cross-border
                   product this plugin does not call. A free-text box here only invites
                   a typo that fails at checkout, so it is the one value it can be. */
                'currency_code' => [
                    'position' => 90,
                    'type'     => 'select',
                    // The "(ISO 4217, e.g. INR)" the manifest carries was guidance for
                    // a free-text box; a one-option list needs none.
                    'label'    => 'Transaction Currency',
                    'options'  => ['INR' => 'INR'],
                    'default'  => 'INR',
                ],
            ],
            'tagline'      => 'payu_india_plugin_tagline',
            'description'  => 'payu_india_plugin_description',
            'type'         => 'payment',
            'version'      => '1.0.0',
            'core_min'     => '1.4.0',
            'countries'    => ['IN'],
            'icon'         => 'credit-card',
            'buy_url'      => 'https://cakezake.com/products/payu-add-ons',
            'docs_url'     => 'https://cakezake.com/docs/cakezake/docs/admin/payu-addon',
            'highlights'   => [
                'payu_india_highlight_payment_links',
                'payu_india_highlight_hosted_checkout',
                'payu_india_highlight_modes',
            ],
        ],

    ],

];
