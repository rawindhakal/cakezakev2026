<?php

namespace App\Services;

use App\Events\MessageSent;
use App\Models\AdminToken;
use App\Models\Conversation;
use App\Models\Admin;
use App\Models\DeliveryBoy;
use App\Models\Message;
use App\Models\Order;
use App\Models\Role;
use App\Models\Setting;
use App\Models\User;
use App\Models\UserToken;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Central chat logic shared by admin / customer / delivery-boy controllers.
 *
 * Conversation types:
 *   admin_customer        – general (one per customer)
 *   admin_delivery_boy    – general (one per delivery boy)
 *   delivery_boy_customer – order-scoped (one per order)
 */
class ChatService
{
    /** Validation rules shared by every send endpoint. */
    public static function sendRules(): array
    {
        return [
            'conversation_id' => 'required|integer',
            'message'         => 'nullable|string|max:2000',
            'images.*'        => 'nullable|image|mimes:jpeg,png,jpg,gif,webp|max:5120',
            // Audio/video validated by extension — m4a/3gp/mov are MP4-family containers
            // whose sniffed MIME is unreliable (video/mp4, octet-stream), so mimetypes fails.
            'audios.*'        => ['nullable', 'file', 'max:20480', function ($attr, $value, $fail) {
                $ext = strtolower($value->getClientOriginalExtension());
                if (!in_array($ext, ['mp3', 'wav', 'ogg', 'oga', 'm4a', 'aac', 'webm', 'mp4', 'mpeg', 'mpga', '3gp', 'amr', 'caf'], true)) {
                    $fail(__('invalid_audio_file'));
                }
            }],
            'videos.*'        => ['nullable', 'file', 'max:20480', function ($attr, $value, $fail) {
                $ext = strtolower($value->getClientOriginalExtension());
                if (!in_array($ext, ['mp4', 'mov', 'webm', 'mkv', 'avi', '3gp', 'm4v', 'mpeg', 'mpg'], true)) {
                    $fail(__('invalid_video_file'));
                }
            }],
            // Generic docs (pdf/excel/word/etc). Block executable/script types for safety.
            'files.*'         => ['nullable', 'file', 'max:20480', function ($attr, $value, $fail) {
                $blocked = ['php', 'phtml', 'phar', 'exe', 'sh', 'bat', 'cmd', 'com', 'js', 'jar', 'msi', 'dll', 'app', 'bin', 'pl', 'py', 'rb', 'cgi', 'html', 'htm', 'svg'];
                $ext = strtolower($value->getClientOriginalExtension());
                if ($ext === '' || in_array($ext, $blocked, true)) {
                    $fail(__('invalid_file'));
                }
            }],
        ];
    }

    /** Branch uploaded images + audio under chat disk; returns paths (images first). */
    public static function collectAttachments(\Illuminate\Http\Request $request): array
    {
        $paths = [];
        // Branch each kind in its own subfolder so the type is unambiguous (mp4/webm/3gp
        // extensions are shared by audio + video; sniffed MIME is unreliable too).
        $groups = [
            'chat'       => (array) $request->file('images'),
            'chat/audio' => (array) $request->file('audios'),
            'chat/video' => (array) $request->file('videos'),
            'chat/file'  => (array) $request->file('files'),
        ];
        foreach ($groups as $dir => $files) {
            foreach ($files as $file) {
                if (!$file) {
                    continue;
                }
                $ext = strtolower($file->getClientOriginalExtension());
                $name = \Illuminate\Support\Str::random(40) . ($ext !== '' ? '.' . $ext : '');
                $paths[] = $file->storeAs($dir, $name, 'public');
            }
        }
        return $paths;
    }

    public function adminCustomer(int $userId): Conversation
    {
        return Conversation::firstOrCreate(
            ['type' => Conversation::TYPE_ADMIN_CUSTOMER, 'user_id' => $userId],
        );
    }

    /**
     * Where a customer sits when the app sent no coordinates with the message: their
     * default address, else the zone of their most recent order. Null when neither
     * exists — the push then goes to admins only, since no branch serves them yet.
     */
    public static function customerZoneId(int $userId): ?int
    {
        $zoneId = DB::table('user_addresses')
            ->where('user_id', $userId)
            ->whereNotNull('zone_id')
            ->orderByDesc('is_default')
            ->orderByDesc('id')
            ->value('zone_id');

        if (!$zoneId) {
            $zoneId = DB::table('orders')
                ->where('user_id', $userId)
                ->whereNotNull('zone_id')
                ->orderByDesc('id')
                ->value('zone_id');
        }

        return $zoneId ? (int) $zoneId : null;
    }

    public function adminDeliveryBoy(int $deliveryBoyId): Conversation
    {
        return Conversation::firstOrCreate(
            ['type' => Conversation::TYPE_ADMIN_DELIVERY_BOY, 'delivery_boy_id' => $deliveryBoyId],
        );
    }

    /**
     * Order-scoped customer <-> assigned delivery boy.
     * Quick orders assign one delivery boy at the order level. Ecommerce orders assign
     * delivery boys per item, so the caller resolves the item's delivery boy and passes it
     * in — the conversation is keyed by (order, delivery boy) so one order can have a
     * separate thread per delivery boy handling its items.
     */
    public function orderConversation(Order $order, ?int $deliveryBoyId = null): ?Conversation
    {
        $deliveryBoyId = $deliveryBoyId ?: ($order->delivery_boy_id ?? null);
        if (!$order->user_id || !$deliveryBoyId) {
            return null; // needs both a customer and an assigned delivery boy
        }
        return Conversation::firstOrCreate(
            ['type' => Conversation::TYPE_DELIVERY_BOY_CUSTOMER, 'order_id' => $order->id, 'delivery_boy_id' => $deliveryBoyId],
            ['user_id' => $order->user_id],
        );
    }

    /** Order-scoped customer <-> admin. */
    public function orderAdminConversation(Order $order): ?Conversation
    {
        if (!$order->user_id) {
            return null; // needs a customer
        }
        return Conversation::firstOrCreate(
            ['type' => Conversation::TYPE_ORDER_ADMIN, 'order_id' => $order->id],
            ['user_id' => $order->user_id],
        );
    }

    /**
     * Persist a message, denormalize the conversation, broadcast + push notify.
     */
    /**
     * @param int|null $zoneId Where the sender is, when the client could tell us. Used
     *                         only to aim the push: branch panels outside that zone are
     *                         not notified. Nothing about it is stored.
     */
    public function postMessage(Conversation $conversation, string $senderType, int $senderId, ?string $text, ?string $attachmentPath = null, ?int $zoneId = null): Message
    {
        $text = $text !== null ? trim($text) : '';
        $message = Message::create([
            'conversation_id' => $conversation->id,
            'sender_type'     => $senderType,
            'sender_id'       => $senderId,
            'message'         => $text !== '' ? $text : null,
            'attachment'      => $attachmentPath,
        ]);

        $conversation->forceFill([
            'last_message'     => $text !== '' ? $text : $this->attachmentPreview($attachmentPath),
            'last_sender_type' => $senderType,
            'last_message_at'  => $message->created_at,
        ])->save();

        $payload = $this->shapeMessage($message);

        // Broadcast + FCM are network calls; run them after the HTTP response so
        // the send endpoint returns immediately (esp. multi-image sends).
        dispatch(function () use ($message, $payload, $conversation, $zoneId) {
            // FCM first: if the Reverb broadcast endpoint is slow/unreachable its cURL can
            // block ~10s, so run the push before it to avoid delaying notification delivery.
            try {
                $this->notify($conversation, $message, $zoneId);
            } catch (\Throwable $e) {
                Log::error('Chat notify error: ' . $e->getMessage());
            }
            try {
                broadcast(new MessageSent($message, $payload, $conversation));
            } catch (\Throwable $e) {
                Log::error('Chat broadcast error: ' . $e->getMessage());
            }
        })->afterResponse();

        return $message;
    }

    /**
     * Latest page of messages (newest-first window), returned ascending for display.
     * Returns ['messages' => [...asc], 'has_more' => bool].
     */
    public function pagedMessages(Conversation $conversation, int $limit = 30, int $offset = 0): array
    {
        $limit = max(1, min($limit, 100));
        $offset = max(0, $offset);

        $total = Message::where('conversation_id', $conversation->id)->count();
        $rows = Message::where('conversation_id', $conversation->id)
            ->orderByDesc('id')
            ->skip($offset)->take($limit)
            ->get()
            ->reverse()
            ->values();

        return [
            'messages' => $rows->map(fn ($m) => $this->shapeMessage($m))->values(),
            'total'    => $total,
        ];
    }

    /** Count of conversations with unread messages, from a viewer's perspective. */
    public function unreadConversationCount(string $viewerType, ?int $deliveryBoyId = null): int
    {
        $q = Conversation::query();
        if ($viewerType === Message::SENDER_DELIVERY_BOY) {
            $q->where('delivery_boy_id', $deliveryBoyId);
        } else {
            $q->whereIn('type', [Conversation::TYPE_ADMIN_CUSTOMER, Conversation::TYPE_ADMIN_DELIVERY_BOY, Conversation::TYPE_ORDER_ADMIN]);
        }
        return $q->whereHas('messages', function ($m) use ($viewerType) {
            $m->where('sender_type', '!=', $viewerType)->whereNull('read_at');
        })->count();
    }

    /** Mark messages from the OTHER side as read for this viewer. */
    public function markRead(Conversation $conversation, string $viewerType): void
    {
        Message::where('conversation_id', $conversation->id)
            ->where('sender_type', '!=', $viewerType)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);
    }

    public function shapeMessage(Message $m): array
    {
        return [
            'id'              => (int) $m->id,
            'conversation_id' => (int) $m->conversation_id,
            'sender_type'     => $m->sender_type,
            'sender_id'       => (int) $m->sender_id,
            'message'         => $m->message,
            'attachment'      => $m->attachment,
            'attachment_url'  => $m->attachment ? asset('storage/' . $m->attachment) : null,
            'attachment_type' => $this->attachmentType($m->attachment),
            'read_at'         => $m->read_at ? $m->read_at->toDateTimeString() : null,
            'created_at'      => $m->created_at->toDateTimeString(),
            'time'            => $m->created_at,
        ];
    }

    /** Short preview text for a non-text message (list + push body). */
    private function attachmentPreview(?string $path): string
    {
        $type = $this->attachmentType($path);
        if ($type === 'audio') {
            return '🎤 ' . __('audio');
        }
        if ($type === 'video') {
            return '🎥 ' . __('video');
        }
        if ($type === 'file') {
            return '📎 ' . __('file');
        }
        return '📷 ' . __('photo');
    }

    /** Classify an attachment path as image | audio | video | file (null if none). */
    private function attachmentType(?string $path): ?string
    {
        if (!$path) {
            return null;
        }
        // Subfolder is authoritative for audio/video (set at upload time).
        if (str_contains($path, 'chat/audio/')) {
            return 'audio';
        }
        if (str_contains($path, 'chat/video/')) {
            return 'video';
        }
        $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
        if (in_array($ext, ['jpeg', 'jpg', 'png', 'gif', 'webp'], true)) {
            return 'image';
        }
        // Legacy paths (pre-subfolder) — best-effort by extension.
        if (in_array($ext, ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'mpga', 'amr', 'caf'], true)) {
            return 'audio';
        }
        if (in_array($ext, ['mov', 'mkv', 'avi', 'm4v'], true)) {
            return 'video';
        }
        return 'file';
    }

    /**
     * Conversation row for a list, from a viewer's perspective.
     * $viewerType: admin | customer | delivery_boy
     */
    public function shapeConversation(Conversation $c, string $viewerType): array
    {
        $unread = $this->unreadCount((int) $c->id, $viewerType);

        // The "title" is the counterparty from the viewer's perspective.
        $title = $this->counterpartName($c, $viewerType);

        return [
            'id'               => (int) $c->id,
            'type'             => $c->type,
            'order_id'         => $c->order_id ? (int) $c->order_id : null,
            'order_number'     => $this->orderNumber($c->order_id),
            'user_id'          => $c->user_id ? (int) $c->user_id : null,
            'customer'         => $this->customerContact($c->user_id),
            'delivery_boy'     => $this->deliveryBoyContact($c->delivery_boy_id),
            'delivery_boy_id'  => $c->delivery_boy_id ? (int) $c->delivery_boy_id : null,
            'title'            => $title,
            'avatar'           => $this->counterpartAvatar($c, $viewerType),
            // For order-scoped types the UI shows both participants ("A ⇄ B"); null otherwise.
            'parties'          => $this->orderParties($c),
            'last_message'     => $c->last_message,
            'last_sender_type' => $c->last_sender_type,
            'last_message_at'  => $c->last_message_at ? $c->last_message_at->toDateTimeString() : null,
            'last_time'        => $c->last_message_at ? $c->last_message_at : null,
            'unread_count'     => $unread,
        ];
    }

    /** Support/admin display name (falls back to translated "support"). */
    private function supportName(): string
    {
        if ($this->supportName === null) {
            $this->supportName = (string) (Setting::get_value('app_name') ?: __('support'));
        }
        return $this->supportName !== '' ? $this->supportName : (string) __('support');
    }

    /**
     * Per-request memos: shapeConversation() runs once per row in the list endpoints
     * and every row resolves the same customer / rider / order several times over.
     * preloadConversations() fills these in bulk so a 300-row list costs a handful of
     * queries instead of a handful per row.
     */
    private array $userCache = [];
    private array $dboyCache = [];
    private array $adminEmailCache = [];
    private array $orderNumberCache = [];
    /** conversation id => unread count, filled by preloadConversations(). */
    private ?array $unreadCache = null;
    private ?string $supportName = null;

    /**
     * Bulk-load everything the rows of a conversation list need.
     *
     * @param iterable<Conversation> $conversations
     */
    public function preloadConversations($conversations, string $viewerType): void
    {
        $rows = collect($conversations);
        if ($rows->isEmpty()) {
            return;
        }

        $userIds = $rows->pluck('user_id')->filter()->unique()->diff(array_keys($this->userCache))->values();
        if ($userIds->isNotEmpty()) {
            $found = User::whereIn('id', $userIds)->get()->keyBy('id');
            foreach ($userIds as $id) {
                $this->userCache[(int) $id] = $found->get($id);
            }
        }

        $dboyIds = $rows->pluck('delivery_boy_id')->filter()->unique()->diff(array_keys($this->dboyCache))->values();
        if ($dboyIds->isNotEmpty()) {
            $found = DeliveryBoy::whereIn('id', $dboyIds)->get()->keyBy('id');
            foreach ($dboyIds as $id) {
                $this->dboyCache[(int) $id] = $found->get($id);
            }
            // Rider contact shows the login email, which lives on the admin row.
            $adminIds = $found->pluck('admin_id')->filter()->unique()->diff(array_keys($this->adminEmailCache))->values();
            if ($adminIds->isNotEmpty()) {
                $emails = Admin::whereIn('id', $adminIds)->pluck('email', 'id');
                foreach ($adminIds as $id) {
                    $this->adminEmailCache[(int) $id] = (string) ($emails[$id] ?? '');
                }
            }
        }

        $orderIds = $rows->pluck('order_id')->filter()->unique()->diff(array_keys($this->orderNumberCache))->values();
        if ($orderIds->isNotEmpty()) {
            $numbers = Order::whereIn('id', $orderIds)->pluck('order_number', 'id');
            foreach ($orderIds as $id) {
                $this->orderNumberCache[(int) $id] = $numbers[$id] ?? null;
            }
        }

        // One grouped count instead of a count per row.
        $this->unreadCache = (array) Message::whereIn('conversation_id', $rows->pluck('id')->all())
            ->where('sender_type', '!=', $viewerType)
            ->whereNull('read_at')
            ->groupBy('conversation_id')
            ->selectRaw('conversation_id, COUNT(*) as aggregate')
            ->pluck('aggregate', 'conversation_id')
            ->all();
    }

    private function unreadCount(int $conversationId, string $viewerType): int
    {
        if (is_array($this->unreadCache)) {
            return (int) ($this->unreadCache[$conversationId] ?? 0);
        }
        return Message::where('conversation_id', $conversationId)
            ->where('sender_type', '!=', $viewerType)
            ->whereNull('read_at')
            ->count();
    }

    private function orderNumber(?int $orderId): ?string
    {
        if (!$orderId) {
            return null;
        }
        if (!array_key_exists($orderId, $this->orderNumberCache)) {
            $this->orderNumberCache[$orderId] = Order::where('id', $orderId)->value('order_number');
        }
        return $this->orderNumberCache[$orderId] ?: null;
    }

    private function customerUser(?int $userId): ?User
    {
        if (!$userId) {
            return null;
        }
        if (!array_key_exists($userId, $this->userCache)) {
            $this->userCache[$userId] = User::find($userId);
        }
        return $this->userCache[$userId];
    }

    private function deliveryBoy(?int $deliveryBoyId): ?DeliveryBoy
    {
        if (!$deliveryBoyId) {
            return null;
        }
        if (!array_key_exists($deliveryBoyId, $this->dboyCache)) {
            $this->dboyCache[$deliveryBoyId] = DeliveryBoy::find($deliveryBoyId);
        }
        return $this->dboyCache[$deliveryBoyId];
    }

    private function adminEmail(?int $adminId): string
    {
        if (!$adminId) {
            return '';
        }
        if (!array_key_exists($adminId, $this->adminEmailCache)) {
            $this->adminEmailCache[$adminId] = (string) (Admin::where('id', $adminId)->value('email') ?? '');
        }
        return $this->adminEmailCache[$adminId];
    }

    private function customerName(?int $userId): string
    {
        return optional($this->customerUser($userId))->name ?? __('customer');
    }

    /** Name + contact details for the rider on this thread. Null when there is none. */
    private function deliveryBoyContact(?int $deliveryBoyId): ?array
    {
        $b = $this->deliveryBoy($deliveryBoyId);
        if (!$b) {
            return null;
        }

        return [
            'id'           => (int) $b->id,
            'name'         => $b->name,
            'country_code' => (string) ($b->country_code ?? ''),
            'mobile'       => (string) ($b->getAttributes()['mobile'] ?? ''),
            'email'        => $this->adminEmail($b->admin_id),
        ];
    }

    /** Name + contact details shown in the chat thread header. Null when no customer. */
    private function customerContact(?int $userId): ?array
    {
        $u = $this->customerUser($userId);
        if (!$u) {
            return null;
        }

        return [
            'id'           => (int) $u->id,
            'name'         => (string) ($u->name ?? ''),
            'country_code' => (string) ($u->country_code ?? ''),
            'mobile'       => (string) ($u->getAttributes()['mobile'] ?? ''),
            'email'        => (string) ($u->email ?? ''),
        ];
    }

    /**
     * Both participants of an order-scoped conversation, from the ADMIN's perspective, so
     * the panel can render "customer ⇄ counterparty". Null for non-order-scoped types.
     */
    private function orderParties(Conversation $c): ?array
    {
        if (!in_array($c->type, Conversation::ORDER_SCOPED_TYPES, true)) {
            return null;
        }
        $to = $c->type === Conversation::TYPE_ORDER_ADMIN
            ? $this->supportName()
            : (optional($this->deliveryBoy($c->delivery_boy_id))->name ?? __('delivery_boy'));
        return ['from' => $this->customerName($c->user_id), 'to' => $to];
    }

    /** Customer's uploaded profile image, or null when none (raw check, no default). */
    private function customerAvatar(?int $userId): ?string
    {
        $u = $this->customerUser($userId);
        if (!$u) {
            return null;
        }
        $raw = (string) $u->getRawOriginal('profile');
        return trim($raw) !== '' ? asset('storage/' . $raw) : null;
    }

    /** Delivery boy's uploaded profile image, or null when none. */
    private function deliveryBoyAvatar(?int $dbId): ?string
    {
        return optional($this->deliveryBoy($dbId))->profile_url;
    }

    /** Counterparty avatar from the viewer's perspective (support/admin has none). */
    private function counterpartAvatar(Conversation $c, string $viewerType): ?string
    {
        if ($viewerType === Message::SENDER_ADMIN) {
            if (in_array($c->type, [Conversation::TYPE_ADMIN_CUSTOMER, Conversation::TYPE_ORDER_ADMIN, Conversation::TYPE_DELIVERY_BOY_CUSTOMER], true)) {
                return $this->customerAvatar($c->user_id);
            }
            return $this->deliveryBoyAvatar($c->delivery_boy_id);
        }
        if ($viewerType === Message::SENDER_CUSTOMER) {
            if (in_array($c->type, [Conversation::TYPE_ADMIN_CUSTOMER, Conversation::TYPE_ORDER_ADMIN], true)) {
                return null; // support
            }
            return $this->deliveryBoyAvatar($c->delivery_boy_id);
        }
        // Delivery boy viewing.
        if ($c->type === Conversation::TYPE_ADMIN_DELIVERY_BOY) {
            return null; // support
        }
        return $this->customerAvatar($c->user_id);
    }

    private function counterpartName(Conversation $c, string $viewerType): string
    {
        // Admin viewing → show the other party (customer / delivery boy).
        if ($viewerType === Message::SENDER_ADMIN) {

            if (in_array($c->type, [Conversation::TYPE_ADMIN_CUSTOMER, Conversation::TYPE_ORDER_ADMIN, Conversation::TYPE_DELIVERY_BOY_CUSTOMER], true)) {
                return optional($this->customerUser($c->user_id))->name ?? ('Customer #' . $c->user_id);
            }
            return optional($this->deliveryBoy($c->delivery_boy_id))->name ?? ('Delivery Boy #' . $c->delivery_boy_id);
        }
        // Customer viewing.
        if ($viewerType === Message::SENDER_CUSTOMER) {
            if (in_array($c->type, [Conversation::TYPE_ADMIN_CUSTOMER, Conversation::TYPE_ORDER_ADMIN], true)) {
                return $this->supportName();
            }
            return optional($this->deliveryBoy($c->delivery_boy_id))->name ?? __('delivery_boy');
        }
        // Delivery boy viewing.
        if ($c->type === Conversation::TYPE_ADMIN_DELIVERY_BOY) {
            return $this->supportName();
        }
        return optional($this->customerUser($c->user_id))->name ?? __('customer');
    }

    /** Push-notify the participant(s) on the other side of the message. */
    private function notify(Conversation $conversation, Message $message, ?int $zoneId = null): void
    {
        // Which branch serves this message. An order chat knows it from the order; a
        // general chat from the coordinates the app sent, else the customer's address.
        $zoneId = $zoneId
            ?: ($conversation->order_id ? Order::where('id', $conversation->order_id)->value('zone_id') : null)
            ?: ($conversation->user_id ? self::customerZoneId((int) $conversation->user_id) : null);
        $senderName = $this->senderName($message);
        $body = $message->message
            ? \Illuminate\Support\Str::limit($message->message, 120)
            : $this->attachmentPreview($message->attachment);
        $payloadId = $conversation->id;
        // Rendered via the `chat_message` notification template (per-language), so admins can
        // customise it like every other push. {{sender_name}} / {{message}} are the placeholders.
        $placeholders = ['sender_name' => $senderName, 'message' => $body];
        // For an image attachment, include the image URL so the push can show a preview.
        $imageUrl = $this->attachmentType($message->attachment) === 'image'
            ? asset('storage/' . $message->attachment)
            : '';

        $pushOpts = ['type' => 'chat', 'type_id' => $payloadId, 'image' => $imageUrl, 'payloadType' => 'chat', 'payloadId' => $payloadId];

        $notifyAdmins = function () use ($placeholders, $pushOpts, $zoneId) {
            // Admins hear about every conversation; a branch panel only about the ones in
            // the zone it serves, so a customer's chat never buzzes six unrelated branches.
            $tokens = AdminToken::whereNotNull('fcm_token')
                ->where('type', '!=', Role::$roleNameDeliveryBoy)
                ->where(function ($q) use ($zoneId) {
                    $q->where('type', '!=', Role::$roleNameBranch)
                        ->orWhereIn('user_id', self::branchAdminIdsForZone($zoneId));
                })
                ->get();
            foreach ($tokens->groupBy('user_id') as $adminId => $adminTokens) {
                if ($adminId === null || $adminId === '') {
                    NotificationService::pushIfAllowed('admin', null, 'chat_message', $adminTokens, $placeholders, $pushOpts);
                    continue;
                }
                NotificationService::pushIfAllowed('admin', (int) $adminId, 'chat_message', $adminTokens, $placeholders, $pushOpts);
            }
        };
        // Customer + delivery boy: gated by admin switch + recipient preference.
        $notifyCustomer = function (int $userId) use ($placeholders, $pushOpts) {
            NotificationService::pushIfAllowed('customer', $userId, 'chat_message',
                UserToken::where('user_id', $userId)->whereNotNull('fcm_token')->get(), $placeholders, $pushOpts);
        };
        $notifyDeliveryBoy = function (int $deliveryBoyId) use ($placeholders, $pushOpts) {
            $adminId = DeliveryBoy::where('id', $deliveryBoyId)->value('admin_id');
            if (!$adminId) return;
            NotificationService::pushIfAllowed('delivery_boy', (int) $adminId, 'chat_message',
                AdminToken::where('user_id', $adminId)->whereNotNull('fcm_token')->get(), $placeholders, $pushOpts);
        };

        switch ($conversation->type) {
            case Conversation::TYPE_ADMIN_CUSTOMER:
                $message->sender_type === Message::SENDER_CUSTOMER
                    ? $notifyAdmins()
                    : $notifyCustomer((int) $conversation->user_id);
                break;
            case Conversation::TYPE_ADMIN_DELIVERY_BOY:
                $message->sender_type === Message::SENDER_DELIVERY_BOY
                    ? $notifyAdmins()
                    : $notifyDeliveryBoy((int) $conversation->delivery_boy_id);
                break;
            case Conversation::TYPE_DELIVERY_BOY_CUSTOMER:
                $message->sender_type === Message::SENDER_CUSTOMER
                    ? $notifyDeliveryBoy((int) $conversation->delivery_boy_id)
                    : $notifyCustomer((int) $conversation->user_id);
                break;
            case Conversation::TYPE_ORDER_ADMIN:
                $message->sender_type === Message::SENDER_CUSTOMER
                    ? $notifyAdmins()
                    : $notifyCustomer((int) $conversation->user_id);
                break;
        }
    }

    /**
     * Panel users of the branches serving a zone. An unzoned conversation (a customer with
     * no address, no orders and no coordinates) belongs to no branch — admins only.
     *
     * @return int[] admin ids
     */
    public static function branchAdminIdsForZone(?int $zoneId): array
    {
        if (!$zoneId) {
            return [];
        }

        return Admin::whereIn('branch_id', function ($q) use ($zoneId) {
            $q->select('id')->from('branches')->where('zone_id', $zoneId);
        })->pluck('id')->map(fn ($id) => (int) $id)->all();
    }

    private function senderName(Message $m): string
    {
        if ($m->sender_type === Message::SENDER_CUSTOMER) {
            return optional(User::find($m->sender_id))->name ?? __('customer');
        }
        if ($m->sender_type === Message::SENDER_DELIVERY_BOY) {
            return optional(DeliveryBoy::find($m->sender_id))->name ?? __('delivery_boy');
        }
        return (string) (Setting::get_value('app_name') ?: __('support'));
    }
}
