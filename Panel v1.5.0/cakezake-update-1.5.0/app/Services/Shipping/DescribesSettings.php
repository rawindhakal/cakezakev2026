<?php

namespace App\Services\Shipping;

/**
 * An plugin that can tell the settings form what a field would hold on its own.
 *
 * Some fields exist only to override something the plugin already knows: a base URL it
 * picks from the selected mode, a path it derives from the install. A form that shows
 * them as empty boxes tells an admin nothing — not what is in use, nor that typing
 * anything replaces it.
 *
 * Implementing this lets the form show the value in force and keep the box closed until
 * someone deliberately opens it. The values come from the plugin's own constants, so
 * there is one source of truth rather than a copy in the manifest.
 */
interface DescribesSettings
{
    /**
     * Fields whose value is computed, keyed by setting key.
     *
     * Each entry is:
     *   'depends_on' => the setting key that selects among the values (optional)
     *   'values'     => [selector value => the value that would be used]
     *   'value'      => a single value, when nothing selects it
     *
     * @return array<string, array{depends_on?: string, values?: array<string, string>, value?: string}>
     */
    public function settingChoices(): array;
}
