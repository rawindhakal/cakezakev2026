<?php

namespace App\Http\Controllers\API;

use App\Helpers\CommonHelper;
use App\Http\Controllers\Controller;
use App\Models\EmailTemplate;
use App\Models\EmailTemplateTranslation;
use App\Models\Language;
use App\Models\NotificationAdminSetting;
use App\Models\NotificationTemplate;
use App\Models\NotificationTemplateTranslation;
use App\Models\Setting;
use App\Models\SmsTemplate;
use App\Models\SmsTemplateTranslation;
use App\Services\NotificationService;
use App\Services\Shipping\CourierStatusService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * Event-centric notification management for admins. One event exposes its
 * mail/sms/push templates + master toggles together.
 */
class NotificationSettingsApiController extends Controller
{
    /** channel => [templateModel, translationModel, fk, hasTitle] */
    private function channelMeta(): array
    {
        return [
            'mail' => [EmailTemplate::class, EmailTemplateTranslation::class, 'email_template_id', true],
            'sms'  => [SmsTemplate::class, SmsTemplateTranslation::class, 'sms_template_id', false],
            'push' => [NotificationTemplate::class, NotificationTemplateTranslation::class, 'notification_template_id', true],
        ];
    }

    private function label(string $key, string $audience): string
    {
        // Translated event name + audience, e.g. "Order Shipped - Customer".
        $locale = app()->getLocale();
        return NotificationService::eventLabel($key, $locale) . ' - ' . NotificationService::eventLabel($audience, $locale);
    }

    /** List every catalog event with per-channel enabled + template presence. */
    public function events(Request $request)
    {
        $adminRows = NotificationAdminSetting::get()
            ->keyBy(fn ($r) => $r->event_key . '|' . $r->audience . '|' . $r->channel);
        $meta = $this->channelMeta();

        $items = [];
        foreach (NotificationService::events() as $e) {
            $channels = [];
            foreach ($e['channels'] as $channel => $default) {
                $type = NotificationService::templateType($e['key'], $e['audience']);
                $model = $meta[$channel][0];
                $enabledRow = $adminRows->get($e['key'] . '|' . $e['audience'] . '|' . $channel);
                $channels[$channel] = [
                    'enabled'       => $enabledRow ? (bool) $enabledRow->is_enabled : (bool) $default,
                    'template_type' => $type,
                    'has_template'  => $type ? $model::where('type', $type)->exists() : false,
                ];
            }
            $items[] = [
                'key'      => $e['key'],
                'audience' => $e['audience'],
                'category' => $e['category'],
                'label'    => $this->label($e['key'], $e['audience']),
                'channels' => $channels,
            ];
        }

        // Filters
        if ($request->filled('audience')) {
            $items = array_values(array_filter($items, fn ($i) => $i['audience'] === $request->audience));
        }
        if ($request->filled('category')) {
            $items = array_values(array_filter($items, fn ($i) => $i['category'] === $request->category));
        }
        if ($request->filled('search')) {
            $s = strtolower((string) $request->search);
            $items = array_values(array_filter($items, fn ($i) => str_contains(strtolower($i['label']), $s) || str_contains(strtolower($i['key']), $s)));
        }

        return CommonHelper::responseWithData([
            'categories' => \App\Services\NotificationService::categories(),
            'audiences'  => ['customer', 'delivery_boy', 'admin'],
            'events'     => $items,
            // Who tells the customer about a courier's progress — see
            // CourierStatusService, which honours this.
            'courier_customer_notifications' => CourierStatusService::customerNotificationMode(),
            'courier_notification_modes'     => CourierStatusService::NOTIFICATION_MODES,
            // What happens to a line whose parcel the courier brought back.
            'courier_rto_action'             => CourierStatusService::rtoAction(),
            'courier_rto_actions'            => CourierStatusService::RTO_ACTIONS,
            'has_shipping_provider'          => !empty(app(\App\Plugins\Registries\ShippingProviderRegistry::class)->usable('ecommerce')),
        ]);
    }

    /**
     * What happens when a parcel comes back undelivered.
     *
     * The goods are on the shelf again and a prepaid customer is owed their money, so the
     * default settles the line the moment the carrier confirms the parcel is back. A branch
     * that would rather open the box first can have the line flagged instead.
     */
    public function saveCourierRtoAction(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'action' => 'required|in:' . implode(',', array_keys(CourierStatusService::RTO_ACTIONS)),
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $row = Setting::firstOrNew(['variable' => CourierStatusService::RTO_SETTING]);
        $row->value = (string) $request->input('action');
        $row->save();

        return CommonHelper::responseSuccess('settings_updated_successfully');
    }

    /**
     * Who notifies the customer while a parcel is travelling.
     *
     * A courier sends its own SMS on pickup, transit and delivery, so notifying again
     * from here means the customer is told twice about the same event. The default is
     * therefore to stay quiet until the parcel is delivered; a client who switches the
     * courier's own messages off can move it to every stage.
     */
    public function saveCourierNotifications(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'mode' => 'required|in:' . implode(',', array_keys(CourierStatusService::NOTIFICATION_MODES)),
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $row = Setting::firstOrNew(['variable' => CourierStatusService::NOTIFICATION_SETTING]);
        $row->value = (string) $request->input('mode');
        $row->save();

        return CommonHelper::responseSuccess('settings_updated_successfully');
    }

    /** Full detail for one event: per-channel template + translations + toggle. */
    public function event(Request $request)
    {
        $key = (string) $request->input('key');
        $audience = (string) $request->input('audience');

        $catalog = collect(NotificationService::events())
            ->first(fn ($e) => $e['key'] === $key && $e['audience'] === $audience);
        if (!$catalog) {
            return CommonHelper::responseError('notification_event_not_found');
        }

        // system_type 4 = the panel language set; template translations key off these ids.
        $languages = Language::where('status', 1)->where('system_type', 4)
            ->orderByRaw('is_default DESC, display_name ASC')
            ->get(['id', 'display_name as name', 'slug as code', 'is_default', 'system_type'])
            ->makeHidden(['system_type_name']);
        $meta = $this->channelMeta();
        $channels = [];

        foreach ($catalog['channels'] as $channel => $default) {
            [$model, $trModel, $fk, $hasTitle] = $meta[$channel];
            $type = NotificationService::templateType($key, $audience);
            $tpl = $model::where('type', $type)->first();

            $translations = [];
            if ($tpl) {
                foreach ($trModel::where($fk, $tpl->id)->get() as $tr) {
                    $translations[(int) $tr->language_id] = [
                        'title'   => $hasTitle ? ($tr->title ?? '') : '',
                        'message' => $tr->message ?? '',
                    ];
                }
            }

            $enabled = NotificationAdminSetting::where('event_key', $key)->where('audience', $audience)
                ->where('channel', $channel)->value('is_enabled');

            // Channel-wise placeholders (bare keys): prefer the template row's own list
            // (they can differ per channel), fall back to the catalog event's list.
            $tplPh = $tpl && is_array($tpl->placeholders) ? $tpl->placeholders : [];
            $srcPh = !empty($tplPh) ? $tplPh : ($catalog['placeholders'] ?? []);
            $placeholders = array_values(array_unique(array_map(fn ($p) => trim($p, '{}'), $srcPh)));

            $channels[$channel] = [
                'enabled'       => $enabled === null ? (bool) $default : (bool) $enabled,
                'template_type' => $type,
                'has_title'     => $hasTitle,
                'placeholders'  => $placeholders,
                'base_title'    => $hasTitle ? ($tpl->title ?? '') : '',
                'base_message'  => $tpl->message ?? '',
                'translations'  => $translations,
            ];
        }

        return CommonHelper::responseWithData([
            'key'          => $key,
            'audience'     => $audience,
            'category'     => $catalog['category'],
            'label'        => $this->label($key, $audience),
            'placeholders' => $catalog['placeholders'] ?? [],
            'languages'    => $languages,
            'channels'     => $channels,
        ]);
    }

    /** Save toggles + template bodies for all channels of one event. */
    public function saveEvent(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'key'      => 'required|string',
            'audience' => 'required|string',
            'channels' => 'required|array',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        $key = $request->input('key');
        $audience = $request->input('audience');
        $catalog = collect(NotificationService::events())
            ->first(fn ($e) => $e['key'] === $key && $e['audience'] === $audience);
        if (!$catalog) {
            return CommonHelper::responseError('notification_event_not_found');
        }

        $defaultLangId = CommonHelper::getDefaultLanguageId();
        $meta = $this->channelMeta();
        $placeholders = $catalog['placeholders'] ?? [];

        foreach ($request->input('channels') as $channel => $payload) {
            if (!isset($meta[$channel]) || !isset($catalog['channels'][$channel])) {
                continue;
            }
            [$model, $trModel, $fk, $hasTitle] = $meta[$channel];
            $type = NotificationService::templateType($key, $audience);
            $enabled = (bool) ($payload['enabled'] ?? false);
            $translations = $payload['translations'] ?? [];

            // Default-language body is the fallback source; block enabling an empty one.
            $defBody = trim((string) ($translations[$defaultLangId]['message'] ?? ''));
            $defTitle = trim((string) ($translations[$defaultLangId]['title'] ?? ''));
            if ($enabled && $defBody === '') {
                return CommonHelper::responseError('cannot_enable_channel_with_empty_template');
            }

            // Upsert the template row (create if missing). Placeholders are seed-owned
            // (channel-wise) — only set them when creating a brand-new row.
            $tpl = $model::firstOrNew(['type' => $type]);
            $tpl->audience = $audience;
            $tpl->category = $catalog['category'];
            if (!$tpl->exists) {
                $tpl->placeholders = array_map(fn ($p) => trim($p, '{}'), $placeholders);
            }
            if ($hasTitle) {
                $tpl->title = $defTitle;
            }
            $tpl->message = $defBody;
            $tpl->save();

            // Per-language translations.
            foreach ($translations as $langId => $vals) {
                $langId = (int) $langId;
                $data = ['message' => (string) ($vals['message'] ?? '')];
                if ($hasTitle) {
                    $data['title'] = (string) ($vals['title'] ?? '');
                }
                $trModel::updateOrCreate([$fk => $tpl->id, 'language_id' => $langId], $data);
            }

            // Master toggle.
            NotificationAdminSetting::updateOrCreate(
                ['event_key' => $key, 'audience' => $audience, 'channel' => $channel],
                ['is_enabled' => $enabled]
            );
        }

        return CommonHelper::responseSuccess('notification_event_saved_successfully');
    }

    /** Quick single-channel master toggle from the listing. */
    public function toggle(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'key'        => 'required|string',
            'audience'   => 'required|string',
            'channel'    => 'required|in:mail,sms,push',
            'is_enabled' => 'required|boolean',
        ]);
        if ($validator->fails()) {
            return CommonHelper::responseError($validator->errors()->first());
        }

        NotificationAdminSetting::updateOrCreate(
            ['event_key' => $request->key, 'audience' => $request->audience, 'channel' => $request->channel],
            ['is_enabled' => $request->boolean('is_enabled')]
        );

        return CommonHelper::responseSuccess('notification_setting_updated');
    }
}
