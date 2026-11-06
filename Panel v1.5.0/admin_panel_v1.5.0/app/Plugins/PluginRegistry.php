<?php

namespace App\Plugins;

use App\Plugins\PluginManifest;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Which universal plugins are installed, and which of them may run.
 *
 * Universal plugins share the `plugins` table with our own packages — one Plugins page,
 * one licence recheck, one uninstall — and are told apart by `kind = 'universal'`. The
 * row carries licence state and the on/off switch; the folder carries the manifest.
 *
 * Resolved once per request and held, because the payment dispatcher, the webhook door
 * and the panel all ask the same question and a plugin that was runnable at the start
 * of a request must not become unrunnable halfway through it.
 */
final class PluginRegistry
{
    /** @var array<string,PluginPackage>|null */
    private ?array $modules = null;

    /** Every installed universal plugin, licensed or not. @return array<string,PluginPackage> */
    public function all(): array
    {
        if ($this->modules !== null) {
            return $this->modules;
        }

        $rows = $this->rows();
        $modules = [];

        foreach (PluginManifest::installedSlugs() as $slug) {
            $row = $rows[$slug] ?? null;

            $module = PluginPackage::fromDisk(
                $slug,
                (string) ($row->licence_state ?? 'unverified'),
                (bool) ($row->enabled ?? false)
            );

            if ($module) {
                $modules[$slug] = $module;
            }
        }

        return $this->modules = $modules;
    }

    public function get(string $slug): ?PluginPackage
    {
        return $this->all()[$slug] ?? null;
    }

    /** @return array<string,PluginPackage> */
    public function runnable(): array
    {
        return array_filter($this->all(), fn (PluginPackage $m) => $m->runnable());
    }

    /** @return array<string,PluginPackage> */
    public function runnableOfType(string $type): array
    {
        return array_filter($this->runnable(), fn (PluginPackage $m) => $m->type() === $type);
    }

    /**
     * Installed but unusable, with the reason — so the panel can say "re-install" or
     * "enter your purchase code" instead of showing a card that silently does nothing.
     *
     * @return array<string,string> slug => reason key
     */
    public function broken(): array
    {
        $out = [];

        foreach ($this->all() as $slug => $module) {
            if (!$module->isIntact()) {
                $out[$slug] = 'plugin_files_are_missing';
            } elseif (!$module->licenceUsable()) {
                $out[$slug] = 'plugin_licence_is_not_valid';
            }
        }

        return $out;
    }

    public function flush(): void
    {
        $this->modules = null;
    }

    /**
     * Row state, keyed by slug.
     *
     * A missing table or an unreachable database leaves every plugin unlicensed and
     * switched off rather than throwing: discovery runs on ordinary requests, including
     * during a migration, and a plugin that cannot be checked must not be assumed good.
     */
    private function rows(): array
    {
        try {
            if (!Schema::hasTable('plugins')) {
                return [];
            }

            return DB::table('plugins')
                ->get(['slug', 'enabled', 'licence_state', 'version'])
                ->keyBy('slug')
                ->all();
        } catch (\Throwable $e) {
            return [];
        }
    }
}
