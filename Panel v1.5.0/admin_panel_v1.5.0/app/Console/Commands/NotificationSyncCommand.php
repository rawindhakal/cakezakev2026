<?php

namespace App\Console\Commands;

use App\Models\EmailTemplate;
use App\Models\EmailTemplateTranslation;
use App\Models\NotificationAdminSetting;
use App\Models\NotificationTemplate;
use App\Models\NotificationTemplateTranslation;
use App\Models\SmsTemplate;
use App\Models\SmsTemplateTranslation;
use App\Services\NotificationService;
use Illuminate\Console\Command;

/**
 * Idempotent sync of the notification catalog into the DB:
 *  - seed notification_admin_settings from config defaults (never overrides admin choices)
 *  - tag existing template rows with audience + category
 *  - seed the new delivery-boy order-status SMS template
 *  - migrate legacy mail_settings (customer order-status) -> notification_preferences
 *
 * Safe to re-run any time (e.g. after adding catalog events).
 */
class NotificationSyncCommand extends Command
{
    protected $signature = 'notifications:sync {--fresh-prefs : also re-migrate mail_settings}';

    protected $description = 'Sync notification catalog: admin settings, template tags, preference migration';

    public function handle(): int
    {
        $this->seedAdminSettings();
        $this->pruneAdminSettings();
        $this->ensureTemplates();
        $this->tagTemplates();
        $this->pruneTemplates();

        $this->info('Notification catalog sync complete.');
        return self::SUCCESS;
    }

    /** Template types that are legit but NOT part of the notification catalog. */
    private const NON_CATALOG_TEMPLATES = [];

    /**
     * Delete template rows whose type isn't in the catalog (e.g. a channel removed
     * from an event, or a seeded row for a since-dropped event) + their translations.
     * Keeps the small whitelist of legit non-catalog templates.
     */
    private function pruneTemplates(): void
    {
        $valid = NotificationService::reverseTemplateMap(); // canonical type => [key, audience]
        $defs = [
            [SmsTemplate::class, SmsTemplateTranslation::class, 'sms_template_id'],
            [EmailTemplate::class, EmailTemplateTranslation::class, 'email_template_id'],
            [NotificationTemplate::class, NotificationTemplateTranslation::class, 'notification_template_id'],
        ];
        $deleted = 0;
        foreach ($defs as [$model, $trModel, $fk]) {
            foreach ($model::all() as $row) {
                if (isset($valid[$row->type]) || in_array($row->type, self::NON_CATALOG_TEMPLATES, true)) {
                    continue;
                }
                $trModel::where($fk, $row->id)->delete();
                $row->delete();
                $deleted++;
            }
        }
        if ($deleted) {
            $this->info("Pruned orphan templates: {$deleted}.");
        }
    }

    /** HTML placeholders (e.g. order_items_html) only make sense in email. */
    private static function placeholdersForChannel(array $ph, string $channel): array
    {
        if ($channel === 'mail') {
            return $ph;
        }
        return array_values(array_filter($ph, fn ($p) => !str_ends_with($p, '_html')));
    }

    /** Remove admin-setting rows for (event,audience,channel) no longer in the catalog. */
    private function pruneAdminSettings(): void
    {
        $valid = [];
        foreach (NotificationService::events() as $e) {
            foreach (array_keys($e['channels']) as $channel) {
                $valid[$e['key'] . '|' . $e['audience'] . '|' . $channel] = true;
            }
        }
        $deleted = 0;
        foreach (NotificationAdminSetting::get() as $row) {
            if (!isset($valid[$row->event_key . '|' . $row->audience . '|' . $row->channel])) {
                $row->delete();
                $deleted++;
            }
        }
        if ($deleted) {
            $this->info("Pruned stale admin settings: {$deleted}.");
        }
    }

    /**
     * Guarantee every catalog (event, audience, channel) has a template row so a
     * fresh install has all of them. Missing rows are created with the catalog
     * placeholders + a sensible default body; existing rows are left untouched.
     */
    private function ensureTemplates(): void
    {
        $maps = [
            'sms'  => [SmsTemplate::class, false],
            'mail' => [EmailTemplate::class, true],
            'push' => [NotificationTemplate::class, true],
        ];
        $created = 0;

        foreach (NotificationService::events() as $e) {
            $label = ucwords(str_replace('_', ' ', $e['key']));
            $phRaw = array_map(fn ($p) => trim($p, '{}'), $e['placeholders'] ?? []);
            foreach (array_keys($e['channels']) as $channel) {
                $type = NotificationService::templateType($e['key'], $e['audience']);
                if (!$type) {
                    continue;
                }
                [$model, $hasTitle] = $maps[$channel];
                if ($model::where('type', $type)->exists()) {
                    continue;
                }
                $row = new $model();
                $row->type = $type;
                $row->audience = $e['audience'];
                $row->category = $e['category'];
                $row->placeholders = self::placeholdersForChannel($phRaw, $channel);
                if ($hasTitle) {
                    $row->title = $label . ' - {{app_name}}';
                }
                $row->message = $label . ' notification.';
                $row->save();
                $created++;
            }
        }
        if ($created) {
            $this->info("Ensured templates (created missing): {$created}.");
        }
    }

    private function seedAdminSettings(): void
    {
        $count = 0;
        foreach (NotificationService::events() as $e) {
            foreach ($e['channels'] as $channel => $default) {
                $row = NotificationAdminSetting::firstOrCreate(
                    ['event_key' => $e['key'], 'audience' => $e['audience'], 'channel' => $channel],
                    ['is_enabled' => (bool) $default]
                );
                if ($row->wasRecentlyCreated) {
                    $count++;
                }
            }
        }
        $this->info("Admin settings seeded: {$count} new rows.");
    }

    private function tagTemplates(): void
    {
        $maps = [
            'sms'  => SmsTemplate::class,
            'mail' => EmailTemplate::class,
            'push' => NotificationTemplate::class,
        ];
        foreach (NotificationService::events() as $e) {
            // Full placeholder set for the event (bare keys) — every channel's
            // template gets ALL of them so no necessary placeholder is ever missed.
            $ph = array_values(array_unique(array_map(fn ($p) => trim($p, '{}'), $e['placeholders'] ?? [])));
            foreach (array_keys($e['channels']) as $channel) {
                $type = NotificationService::templateType($e['key'], $e['audience']);
                if (!$type) {
                    continue;
                }
                $model = $maps[$channel];
                $model::where('type', $type)->update([
                    'audience'     => $e['audience'],
                    'category'     => $e['category'],
                    'placeholders' => json_encode(self::placeholdersForChannel($ph, $channel)),
                ]);
            }
        }
        $this->info('Templates tagged (audience + category + full placeholders).');
    }

}
