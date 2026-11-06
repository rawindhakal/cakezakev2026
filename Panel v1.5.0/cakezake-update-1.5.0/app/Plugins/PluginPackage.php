<?php

namespace App\Plugins;

use App\Plugins\PluginManifest;

/**
 * One installed plugin: its row state and its on-disk manifest, together.
 *
 * Both halves are needed to answer anything useful and either can go missing on its
 * own — a licence row survives an FTP delete, a folder survives a dropped database —
 * so they are carried as one value and `isIntact()` is what callers check before
 * trusting the pair.
 */
final class PluginPackage
{
    public function __construct(
        public readonly string $slug,
        public readonly array $manifest,
        /** 'valid' | 'invalid' | 'unverified' */
        public readonly string $licenceState,
        public readonly bool $enabled,
        public readonly ?string $version = null,
    ) {}

    public static function fromDisk(string $slug, string $licenceState = 'unverified', bool $enabled = false): ?self
    {
        $manifest = PluginManifest::readValidated($slug);

        if (!$manifest) {
            return null;
        }

        return new self(
            slug: $slug,
            manifest: $manifest,
            licenceState: $licenceState,
            enabled: $enabled,
            version: isset($manifest['version']) ? (string) $manifest['version'] : null,
        );
    }

    public function name(): string
    {
        return (string) ($this->manifest['name'] ?? $this->slug);
    }

    /**
     * The code this plugin is addressed by: `orders.payment_method`, the
     * `{code}_*` credential keys on a country, and its webhook path.
     *
     * Defaults to the slug, which is what makes a plugin work with no catalogue entry
     * at all. A catalogue entry may shorten it — `payu` rather than
     * `payu-india-payment-gateway` — so a product's own apps keep sending the
     * identifier they always sent while the package keeps the slug it has everywhere.
     */
    public function code(): string
    {
        $entry = app(\App\Services\Plugin\PluginCatalog::class)->find($this->slug);
        $code = strtolower(trim((string) ($entry['payment_code'] ?? '')));

        return $code !== '' ? $code : $this->slug;
    }

    public function paymentLabel(): string
    {
        $entry = app(\App\Services\Plugin\PluginCatalog::class)->find($this->slug);
        $label = trim((string) ($entry['payment_label'] ?? ''));

        return $label !== '' ? $label : $this->name();
    }

    /** 'universal' | 'product' — see PluginManifest::scope(). */
    public function scope(): string
    {
        return PluginManifest::scope($this->slug, $this->manifest);
    }

    /** Only a product-scoped plugin may bring schema or commands of its own. */
    public function isProductScoped(): bool
    {
        return $this->scope() === 'product';
    }

    /** 'payment', 'shipping', … */
    public function type(): ?string
    {
        return PluginManifest::type($this->slug, $this->manifest);
    }

    /** The plugin's working class, already checked to be inside its own namespace. */
    public function mainClass(): ?string
    {
        return PluginManifest::mainClass($this->slug, $this->manifest);
    }

    /** Optional: a service provider the plugin wants registered. */
    public function providerClass(): ?string
    {
        $provider = $this->manifest['provider'] ?? null;

        if (!is_string($provider) || $provider === '') {
            return null;
        }

        // Same containment rule as main_class: a plugin may only boot its own code.
        return str_starts_with($provider, PluginManifest::namespaceFor($this->slug)) ? $provider : null;
    }

    /** @return array<int,array{column:string,label?:string,type?:string,options?:array}> */
    public function settingsFields(): array
    {
        return PluginManifest::settingsFields($this->slug, $this->manifest);
    }

    /** The generic credential columns this plugin actually asks for. */
    public function settingColumns(): array
    {
        return array_values(array_unique(array_map(
            fn (array $f) => (string) $f['column'],
            $this->settingsFields()
        )));
    }

    /**
     * The plugin's logo, which ships with core rather than inside the package.
     *
     * A plugin is PHP a client paid for, not a web root: anything it carried would
     * either need a controller to serve it safely or sit somewhere a zip could drop an
     * executable into. Keeping the handful of logos in `public/images/plugins/` costs
     * one file per plugin we sell and removes that question entirely.
     */
    public function iconUrl(): ?string
    {
        $file = 'images/plugins/' . $this->slug . '.svg';

        return is_file(public_path($file)) ? asset($file) : null;
    }

    /**
     * Are the plugin's files actually there.
     *
     * Deliberately a question about the disk, not about `class_exists()`. A class is
     * only loadable once its namespace has been mapped, which happens at boot — so
     * during the request that installs a plugin the mapping was made before the folder
     * existed, and asking the autoloader would report a plugin that is sitting right
     * there as missing. It corrected itself on the next request, which is the worst
     * kind of bug: visible, alarming and gone by the time anyone looks.
     */
    public function isIntact(): bool
    {
        $class = $this->mainClass();

        if ($class === null) {
            return false;
        }

        return is_file(PluginManifest::path($this->slug, PluginManifest::mainClassFile($this->slug, $class)));
    }

    /**
     * A licence that permits running.
     *
     * The same rule as Plugin::licenceAllowsBoot(), and it has to stay the same rule:
     * two answers to "may this run" means the panel can show a plugin as licensed while
     * the registry quietly refuses to load it — the kind of fault nobody reports,
     * because nothing errors.
     *
     * `unverified` counts: it means the stored purchase code could not be decrypted
     * after an APP_KEY rotation, which is our key changing, not a client who stopped
     * paying. Anything else, including a state string we do not recognise, does not.
     */
    public function licenceUsable(): bool
    {
        return in_array($this->licenceState, ['valid', 'unverified'], true);
    }

    /** Everything satisfied: switched on, licensed, and its code actually there. */
    public function runnable(): bool
    {
        return $this->enabled && $this->licenceUsable() && $this->isIntact();
    }

    /** What the panel shows on the card. */
    public function toPanelArray(): array
    {
        return [
            'slug'            => $this->slug,
            'name'            => $this->name(),
            'version'         => $this->version,
            'type'            => $this->type(),
            'enabled'         => $this->enabled,
            'licence_state'   => $this->licenceState,
            'intact'          => $this->isIntact(),
            'settings_fields' => $this->settingsFields(),
        ];
    }
}
