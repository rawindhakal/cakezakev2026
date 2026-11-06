<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\Plugin;
use App\Models\ShippingConfiguration;
use App\Plugins\Adapters\PaymentAdapter;
use App\Plugins\Adapters\ShippingAdapter;
use App\Plugins\PluginManifest;
use App\Plugins\PluginRegistry;
use App\Plugins\Registries\PaymentGatewayRegistry;
use App\Plugins\Registries\ShippingProviderRegistry;
use App\Plugins\Registries\SmsGatewayRegistry;
use App\Services\Plugin\PluginCatalog;
use App\Services\Plugin\PluginInstaller;
use App\Services\Plugin\PluginLicenceService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * The Plugins page.
 *
 * Every write is gated on `manage_plugins` here as well as in the panel: installing a
 * plugin copies PHP into the project, so it is not something a hand-crafted request
 * should be able to reach with a settings-level token. Demo mode blocks the same set of
 * actions the System Updater blocks.
 */
class PluginApiController extends Controller
{
    public function __construct(
        private PluginCatalog $catalog,
        private PluginInstaller $installer,
        private PluginLicenceService $licences,
    ) {}

    /** Installed plugins + the catalogue of what else is available. */
    public function index(Request $request)
    {
        if ($denied = $this->denyWithout($request)) {
            return $denied;
        }

        return CommonHelper::responseWithData([
            'installed'    => $this->catalog->installed(),
            'available'    => $this->catalog->available(),
            'core_version' => (string) currentVersion(),
            'plugins_path' => 'app/Modules/',
            'enabled'      => (bool) config('plugins.enabled', true),
            'max_zip_kb'   => (int) config('plugins.install.max_zip_kb', 102400),
        ]);
    }

    /**
     * Upload a zip + purchase code. The same endpoint updates an installed plugin.
     *
     * `expected_slug` is a guard, never the source of the slug: the installer reads
     * that from the manifest inside the archive, so a mistyped or malicious name is
     * caught rather than used to decide where the files land.
     */
    public function install(Request $request)
    {
        if ($denied = $this->denyWithout($request, true)) {
            return $denied;
        }

        $validator = Validator::make($request->all(), [
            'plugin_file'   => 'required|file|max:' . (int) config('plugins.install.max_zip_kb', 102400),
            'purchase_code' => 'required|string|max:191',
            'expected_slug' => 'nullable|string|max:64',
        ]);

        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        return $this->respond($this->installer->install(
            $request->file('plugin_file'),
            trim((string) $request->purchase_code),
            optional($request->user())->id,
            trim((string) $request->input('expected_slug', ''))
        ));
    }

    public function toggle(Request $request)
    {
        if ($denied = $this->denyWithout($request, true)) {
            return $denied;
        }

        $plugin = $this->plugin($request);

        if (!$plugin) {
            return CommonHelper::responseError('plugin_not_found');
        }

        $enable = filter_var($request->input('enabled', true), FILTER_VALIDATE_BOOLEAN);

        return $this->respond($enable
            ? $this->installer->enable($plugin)
            : $this->installer->disable($plugin));
    }

    public function uninstall(Request $request)
    {
        if ($denied = $this->denyWithout($request, true)) {
            return $denied;
        }

        $plugin = $this->plugin($request);

        if (!$plugin) {
            return CommonHelper::responseError('plugin_not_found');
        }

        return $this->respond($this->installer->uninstall($plugin));
    }

    /**
     * Schema + current values for a shipping plugin's settings form.
     *
     * Only shipping plugins have a page of their own. A payment plugin's credentials
     * are per country, so they are rendered inside the country's payment step instead —
     * a page for them could only say so.
     *
     * The form shows two kinds of field. The plugin's own, from `module.json`, are its
     * credentials. The host's, from the adapter, are decisions about how this shop
     * wants the carrier used — which a portable package has no business declaring.
     */
    public function settings(Request $request)
    {
        if ($denied = $this->denyWithout($request)) {
            return $denied;
        }

        $plugin = $this->plugin($request);

        if (!$plugin) {
            return CommonHelper::responseError('plugin_not_found');
        }

        [$package, $adapter] = $this->shippingPlugin($plugin);

        if (!$package) {
            return CommonHelper::responseError('this_plugin_has_no_settings_page');
        }

        $config = ShippingConfiguration::forProvider($plugin->slug);
        $columns = $package->settingColumns();
        $policyFields = $adapter?->policyFields() ?? [];

        $values = $config->exposedValues($columns);

        foreach ($policyFields as $field) {
            $values[$field['key']] = $config->policy($field['key'], $field['default'] ?? '');
        }

        return CommonHelper::responseWithData([
            'slug'       => $plugin->slug,
            'name'       => $package->name(),
            'version'    => $plugin->version,
            'scope'      => 'settings',
            'fields'     => array_merge($this->renderableFields($package->settingsFields()), $policyFields),
            'values'     => $values,
            'secret_set' => $config->secretsSet($columns),
            'status'     => (bool) $config->status,
            // Where the carrier should push tracking updates, for the admin to paste
            // into their dashboard.
            'webhooks'   => [
                ['action' => 'track', 'url' => url('plugin/' . PluginManifest::webhookSegment($plugin->slug, (array) $plugin->manifest) . '/track')],
            ],
        ]);
    }

    public function saveSettings(Request $request)
    {
        if ($denied = $this->denyWithout($request, true)) {
            return $denied;
        }

        $plugin = $this->plugin($request);

        if (!$plugin) {
            return CommonHelper::responseError('plugin_not_found');
        }

        [$package, $adapter] = $this->shippingPlugin($plugin);

        if (!$package) {
            return CommonHelper::responseError('this_plugin_has_no_settings_page');
        }

        $submitted = (array) $request->input('settings', []);
        $config = ShippingConfiguration::forProvider($plugin->slug);
        $columns = $package->settingColumns();
        $policyKeys = $adapter?->policyKeys() ?? [];
        $rules = [];

        foreach ($package->settingsFields() as $field) {
            $column = (string) $field['column'];

            if (($field['required'] ?? true) === false) {
                continue;
            }

            /* A secret already stored need not be retyped to save the rest of the form,
               so it is only required while there is nothing there. The form sends an
               empty value for an untouched secret, and an empty value leaves it alone. */
            if (($field['type'] ?? '') === 'password' && filled($config->{$column})) {
                continue;
            }

            $rules['settings.' . $column] = 'required';
        }

        if ($rules) {
            $validator = Validator::make($request->all(), $rules, [], $this->attributeNames($package->settingsFields()));

            if ($validator->fails()) {
                return CommonHelper::responseError($validator->errors()->first());
            }
        }

        foreach ($columns as $column) {
            if (!array_key_exists($column, $submitted)) {
                continue;
            }

            $value = $submitted[$column];

            /* An untouched secret arrives empty and must not overwrite a working one.
               Empty means null as often as it means '': Laravel's
               ConvertEmptyStringsToNull turns a blank form field into null before this
               ever runs, so comparing against '' alone silently wiped the stored
               password on every save that did not retype it. */
            if (blank($value) && $config->isSecretColumn($column) && filled($config->{$column})) {
                continue;
            }

            $config->{$column} = $value;
        }

        foreach ($policyKeys as $key) {
            if (array_key_exists($key, $submitted)) {
                $config->setPolicy($key, (int) filter_var($submitted[$key], FILTER_VALIDATE_BOOLEAN));
            }
        }

        if ($request->has('status')) {
            $config->status = filter_var($request->input('status'), FILTER_VALIDATE_BOOLEAN);
        }

        $config->save();

        return CommonHelper::responseSuccess('plugin_settings_saved_successfully');
    }

    /**
     * Payment gateways contributed by plugins, for the Country form.
     *
     * Their credentials live in the same `countries.payment_gateways` JSON as every core
     * gateway, so the form writes them into the object it already saves. This endpoint
     * only describes the fields and the defaults; it never returns a country's values.
     *
     * Public to any authenticated panel user with country access — a gateway's field
     * list is not a secret, and `manage_plugins` is not what a country editor holds.
     */
    public function paymentSchemas(Request $request)
    {
        $registry = app(PaymentGatewayRegistry::class);
        $installed = collect($this->catalog->installed())->keyBy('slug');

        $gateways = [];
        $defaults = [];

        foreach ($registry->keys() as $code) {
            $driver = $registry->driver($code);

            if (!$driver instanceof PaymentAdapter) {
                continue;
            }

            $slug = $registry->ownerOf($code);
            $fields = [];

            foreach ($driver->settingsSchema() as $field) {
                $key = (string) ($field['key'] ?? '');

                if ($key === '') {
                    continue;
                }

                $fields[] = [
                    'key'         => $key,
                    'type'        => $field['type'] ?? 'text',
                    'label'       => $field['label'] ?? $key,
                    'hint'        => $field['hint'] ?? null,
                    'placeholder' => $field['placeholder'] ?? $field['label'] ?? $key,
                    'options'     => $field['options'] ?? null,
                    'required'    => !empty($field['required']),
                    'secret'      => !empty($field['secret']),
                ];
                $defaults[$key] = $field['default'] ?? '';
            }

            // The per-country on/off switch, the same `{code}_payment_method` key
            // hasEnabledPaymentMethod() already scans for.
            $defaults[$code . '_payment_method'] = 0;

            $gateways[] = [
                'code'         => $code,
                'label'        => $driver->label(),
                'payment_label' => $driver->paymentLabel(),
                'plugin'       => $slug,
                'plugin_name'  => $installed[$slug]['name'] ?? $slug,
                'toggle_key'   => $code . '_payment_method',
                'fields'       => $fields,
                'webhook_url'  => url('plugin/' . $code . '/callback'),
                'redirect_url' => url('plugin/' . $code . '/redirect'),
            ];
        }

        return CommonHelper::responseWithData([
            'gateways' => $gateways,
            'defaults' => $defaults,
        ]);
    }

    /**
     * SMS gateways contributed by plugins, for the SMS settings page.
     *
     * Readable with the SMS-settings permission, not `manage_plugins`: the person
     * choosing a gateway is not necessarily the person installing plugins.
     */
    public function smsGateways(Request $request)
    {
        $registry = app(SmsGatewayRegistry::class);
        $installed = collect($this->catalog->installed())->keyBy('slug');

        $gateways = [];

        foreach ($registry->keys() as $key) {
            $slug = $registry->ownerOf($key);
            $plugin = $slug ? $installed->get($slug) : null;

            $gateways[] = [
                'key'          => $key,
                'label'        => $plugin['name'] ?? $key,
                'plugin'       => $slug,
                'settings_url' => $slug ? '/plugins/' . $slug : null,
                'has_settings' => (bool) ($plugin['has_settings'] ?? false),
            ];
        }

        return CommonHelper::responseWithData(['gateways' => $gateways]);
    }

    /* ---------------------------------------------------------------- helpers */

    /**
     * A shipping plugin's package and its adapter, or nulls when it is not one.
     *
     * The adapter can be absent while the package is present — a plugin that is
     * installed but switched off is not in the registry — so the settings page still
     * renders its credentials, just without the host's policy switches, which would
     * have nothing to act on.
     *
     * @return array{0: ?\App\Plugins\PluginPackage, 1: ?ShippingAdapter}
     */
    private function shippingPlugin(Plugin $plugin): array
    {
        $package = app(PluginRegistry::class)->get($plugin->slug);

        if (!$package || $package->type() !== 'shipping') {
            return [null, null];
        }

        $provider = app(ShippingProviderRegistry::class)->provider($plugin->slug);

        return [$package, $provider instanceof ShippingAdapter ? $provider : null];
    }

    private function plugin(Request $request): ?Plugin
    {
        $slug = (string) $request->input('slug', $request->route('slug'));

        return $slug !== '' ? Plugin::where('slug', $slug)->first() : null;
    }

    /**
     * Managing plugins runs code on the server, so the permission is enforced here and
     * not only in the panel. Writes are additionally blocked in demo mode.
     */
    private function denyWithout(Request $request, bool $isWrite = false)
    {
        $held = (array) (optional($request->user())->allPermissions ?? []);

        if (!in_array('manage_plugins', $held, true)) {
            return CommonHelper::responseError('you_do_not_have_access_to_this_section');
        }

        if ($isWrite && shouldDemoMask()) {
            return CommonHelper::responseError('this_action_is_disabled_in_demo_mode');
        }

        return null;
    }

    /**
     * The manifest's fields as the panel renders them.
     *
     * The shared format describes a field as `{column, label, type, options}` with
     * options as a `{value: label}` map; the panel wants a list. Translating here keeps
     * the format's own shape out of the front end.
     */
    private function renderableFields(array $fields): array
    {
        return collect($fields)->map(function (array $field) {
            $out = [
                'key'      => (string) $field['column'],
                'type'     => (string) ($field['type'] ?? 'text'),
                'label'    => (string) ($field['label'] ?? $field['column']),
                'required' => ($field['required'] ?? true) !== false,
                'secret'   => ($field['type'] ?? '') === 'password',
                // A note under the input. The panel translates it, so a plugin ships the
                // key in its own lang file rather than the sentence.
                'hint'     => isset($field['hint']) ? (string) $field['hint'] : null,
            ];

            if (!empty($field['options']) && is_array($field['options'])) {
                $out['options'] = [];

                foreach ($field['options'] as $value => $label) {
                    $out['options'][] = is_int($value)
                        ? ['value' => (string) $label, 'label' => (string) $label]
                        : ['value' => (string) $value, 'label' => (string) $label];
                }
            }

            return $out;
        })->values()->all();
    }

    /** So a validation message names the field the admin can see, not its column. */
    private function attributeNames(array $fields): array
    {
        $names = [];

        foreach ($fields as $field) {
            $names['settings.' . $field['column']] = (string) ($field['label'] ?? $field['column']);
        }

        return $names;
    }

    /**
     * The answer to a write, carrying the refreshed lists.
     *
     * Install, toggle and uninstall all change what the page is showing, so the new
     * state travels back with the result rather than costing a second round trip —
     * and, more usefully, the page cannot end up displaying a list from before the
     * change. The registry is flushed by the installer before this runs, so the
     * rebuild here reads the rows as they now are.
     */
    private function respond(array $result)
    {
        if (empty($result['ok'])) {
            /* The placeholders are filled here, not by responseError — its second
               argument is an HTTP status code, so passing the replacements there left
               ":found" in the message and put the array on the wire as a status code. */
            return CommonHelper::responseError(__($result['message'], $result['replace'] ?? []));
        }

        return CommonHelper::responseSuccessWithData($result['message'], $result + [
            'installed' => $this->catalog->installed(),
            'available' => $this->catalog->available(),
        ]);
    }
}
