<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('chat') }}</h3>
            <button class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                :style="{ background: primaryColor, borderColor: primaryColor }" @click="contactAdmin">
                <Headset :size="16" /><span>{{ __('contact_admin') }}</span>
            </button>
        </div>

        <div class="row chat-wrap">
            <!-- Conversation list -->
            <div class="col-md-4">
                <div class="chat-list list-surface">
                    <div class="chat-search">
                        <Search class="chat-search-icon" />
                        <input type="search" class="form-control" v-model="search"
                            :placeholder="__('search_by_customer_or_order_id')" @input="debouncedSearch" />
                    </div>
                    <div class="chat-conv-scroll">
                        <div v-if="loadingList" class="text-center py-3"><b-spinner small></b-spinner></div>
                        <!-- Order id typed but no thread yet → start chat for that assigned order -->
                        <div v-else-if="!conversations.length && isNumericSearch" class="text-center py-3">
                            <p class="text-muted small mb-2">{{ __('no_records_found') }}</p>
                            <button class="btn btn-sm btn-primary" :style="{ background: primaryColor, borderColor: primaryColor }"
                                :disabled="startingOrder" @click="startOrder(search)">
                                <b-spinner small v-if="startingOrder"></b-spinner>
                                <span v-else>{{ __('start_chat_for_order') }} #{{ String(search).padStart(5,'0') }}</span>
                            </button>
                        </div>
                        <div v-else-if="!conversations.length" class="chat-empty-list">
                            <MessagesSquare :size="26" />
                            <span>{{ __('no_records_found') }}</span>
                        </div>
                        <div v-for="c in conversations" :key="c.id" class="conv-item"
                            :class="{ active: active && active.id === c.id }" @click="openConversation(c)">
                            <div class="conv-avatar">
                                <img v-if="c.avatar" :src="c.avatar" alt="" />
                                <template v-else>{{ initials(c.title) }}</template>
                            </div>
                            <div class="flex-grow-1 min-w-0">
                                <div class="d-flex justify-content-between align-items-center">
                                    <span class="conv-title text-truncate">{{ c.title }}</span>
                                    <small class="text-muted text-nowrap">{{ convTime(c.last_time) }}</small>
                                </div>
                                <div class="d-flex justify-content-between align-items-center">
                                    <small class="text-muted text-truncate">{{ c.last_message || '—' }}</small>
                                    <span v-if="c.unread_count" class="conv-unread">{{ c.unread_count }}</span>
                                </div>
                                <small class="conv-type" v-if="c.order_id">{{ __('orders') }} · {{ c.order_number || ('#' + String(c.order_id).padStart(5, '0')) }}</small>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Thread -->
            <div class="col-md-8">
                <div class="chat-thread list-surface">
                    <template v-if="active">
                        <div class="thread-header">
                            <div class="conv-avatar">
                                <img v-if="active.avatar" :src="active.avatar" alt="" />
                                <template v-else>{{ initials(active.title) }}</template>
                            </div>
                            <div class="min-w-0">
                                <div class="conv-title">{{ active.title }}</div>
                                <small class="text-muted conv-meta" v-if="active.order_id || contact">
                                    <span v-if="active.order_id">{{ active.order_number || ('#' + String(active.order_id).padStart(5, '0')) }}</span>
                                    <span v-if="contact && contact.mobile">
                                        <Phone :size="12" />
                                        <a v-if="canContact" class="chat-link" :href="telHref(contact.country_code, contact.mobile)"
                                            v-b-tooltip.hover :title="__('call')">{{ contact.country_code }} {{ $filters.mobileMask(contact.mobile) }}</a>
                                        <template v-else>{{ contact.country_code }} {{ $filters.mobileMask(contact.mobile) }}</template>
                                    </span>
                                    <span v-if="contact && contact.email">
                                        <Mail :size="12" />
                                        <a v-if="canContact" class="chat-link" :href="'mailto:' + contact.email"
                                            v-b-tooltip.hover :title="__('send_email')">{{ $filters.emailMask(contact.email) }}</a>
                                        <template v-else>{{ $filters.emailMask(contact.email) }}</template>
                                    </span>
                                </small>
                            </div>
                        </div>
                        <div class="thread-body" ref="body" @scroll="onThreadScroll">
                            <div v-if="loadingOlder" class="text-center py-2"><b-spinner small></b-spinner></div>
                            <template v-for="g in groupedMessages" :key="g.key">
                                <div class="date-sep"><span>{{ g.label }}</span></div>
                                <div v-for="m in g.items" :key="m.id" class="msg-row" :class="{ mine: m.sender_type === 'delivery_boy' }">
                                    <div v-if="m.attachment_type === 'image'" class="img-bubble">
                                        <a :href="m.attachment_url" target="_blank"><img :src="m.attachment_url" class="msg-img" alt="" @load="scrollBottom" /></a>
                                        <span class="img-time">{{ shortTime(m.created_at) }}</span>
                                    </div>
                                    <div v-else-if="m.attachment_type === 'audio'" class="msg-bubble audio-bubble">
                                        <audio controls :src="m.attachment_url" class="msg-audio"></audio>
                                        <small class="msg-time audio-time">{{ shortTime(m.created_at) }}</small>
                                    </div>
                                    <div v-else-if="m.attachment_type === 'video'" class="img-bubble">
                                        <video controls :src="m.attachment_url" class="msg-video"></video>
                                        <span class="img-time">{{ shortTime(m.created_at) }}</span>
                                    </div>
                                    <div v-else-if="m.attachment_url" class="msg-bubble"
                                        :style="m.sender_type === 'delivery_boy' ? { background: primaryColor, borderColor: primaryColor } : {}">
                                        <a :href="m.attachment_url" target="_blank" class="file-link"><Paperclip :size="14" /> {{ __('file') }}</a>
                                        <small class="msg-time">{{ shortTime(m.created_at) }}</small>
                                    </div>
                                    <div v-else class="msg-bubble"
                                        :style="m.sender_type === 'delivery_boy' ? { background: primaryColor, borderColor: primaryColor } : {}">
                                        <div>{{ m.message }}</div>
                                        <small class="msg-time">{{ shortTime(m.created_at) }}</small>
                                    </div>
                                </div>
                            </template>
                        </div>
                        <div v-if="imagePreviews.length || audioFiles.length || videoFiles.length || docFiles.length" class="img-preview-strip">
                            <div v-for="(p, i) in imagePreviews" :key="'i'+i" class="img-preview">
                                <img :src="p" alt="" />
                                <button class="chip-remove" @click="removeImage(i)"><X :size="12" /></button>
                            </div>
                            <div v-for="(a, i) in audioFiles" :key="'a'+i" class="audio-chip">
                                <Music :size="14" /> <span class="text-truncate">{{ a.name }}</span>
                                <button class="chip-remove" @click="removeAudio(i)"><X :size="12" /></button>
                            </div>
                            <div v-for="(v, i) in videoFiles" :key="'v'+i" class="audio-chip">
                                <Video :size="14" /> <span class="text-truncate">{{ v.name }}</span>
                                <button class="chip-remove" @click="removeVideo(i)"><X :size="12" /></button>
                            </div>
                            <div v-for="(d, i) in docFiles" :key="'d'+i" class="audio-chip">
                                <FileIcon :size="14" /> <span class="text-truncate">{{ d.name }}</span>
                                <button class="chip-remove" @click="removeDoc(i)"><X :size="12" /></button>
                            </div>
                        </div>
                        <div class="thread-input">
                            <input ref="file" type="file" accept="image/*" multiple class="d-none" @change="onImage" />
                            <input ref="audio" type="file" accept="audio/*" multiple class="d-none" @change="onAudio" />
                            <input ref="video" type="file" accept="video/*" multiple class="d-none" @change="onVideo" />
                            <input ref="doc" type="file" multiple class="d-none" @change="onDoc" />
                            <button class="chat-attach-btn" @click="$refs.file.click()" :title="__('attach_image')"><ImageIcon :size="18" /></button>
                            <button class="chat-attach-btn" @click="$refs.audio.click()" :title="__('attach_audio')"><Mic :size="18" /></button>
                            <button class="chat-attach-btn" @click="$refs.video.click()" :title="__('attach_video')"><Video :size="18" /></button>
                            <button class="chat-attach-btn" @click="$refs.doc.click()" :title="__('attach_file')"><Paperclip :size="18" /></button>
                            <input type="text" class="form-control" v-model="draft" :placeholder="__('type_a_message')" @keyup.enter="send" />
                            <button class="btn btn-primary chat-send-btn" :style="{ background: primaryColor, borderColor: primaryColor }"
                                :disabled="sending || (!draft.trim() && !imageFiles.length && !audioFiles.length && !videoFiles.length && !docFiles.length)" @click="send">
                                <b-spinner small v-if="sending"></b-spinner><Send v-else :size="17" />
                            </button>
                        </div>
                    </template>
                    <div v-else class="thread-empty">
                        <img :src="$baseUrl + '/images/chat.svg'" alt="" class="thread-empty-art" />
                        <h5 class="thread-empty-title">{{ __('no_chats_yet') }}</h5>
                        <p class="thread-empty-text">{{ __('no_chats_yet_description') }}</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { initEcho, getEcho } from '../../echo.js';
import {
    Search, Headset, MessagesSquare, Paperclip, X, Music, Video, Phone, Mail,
    File as FileIcon, Image as ImageIcon, Mic, Send,
} from 'lucide-vue-next';

export default {
    name: 'DeliveryBoyChat',
    components: {
        Search, Headset, MessagesSquare, Paperclip, X, Music, Video, Phone, Mail, FileIcon, ImageIcon, Mic, Send,
    },
    data() {
        return {
            conversations: [],
            active: null,
            messages: [],
            hasMore: false,
            loadingOlder: false,
            pageSize: 30,
            draft: '',
            imageFiles: [],
            imagePreviews: [],
            audioFiles: [],
            videoFiles: [],
            docFiles: [],
            loadingList: false,
            sending: false,
            search: '',
            startingOrder: false,
            _searchDebounce: null,
        };
    },
    computed: {
        primaryColor() { return window.adminThemeColor || '#435ebe'; },
        customer() { return (this.active && this.active.customer) || null; },
        contact() { return this.customer; },
        canContact() { return this.$isDemo != 1; },
        isNumericSearch() { return /^\d+$/.test((this.search || '').trim()); },
        groupedMessages() {
            const groups = [];
            let lastKey = null;
            for (const m of this.messages) {
                const d = new Date((m.created_at || '').replace(' ', 'T'));
                const key = isNaN(d) ? (m.created_at || '') : d.toISOString().slice(0, 10);
                if (key !== lastKey) {
                    groups.push({ key, label: this.dateLabel(d), items: [] });
                    lastKey = key;
                }
                groups[groups.length - 1].items.push(m);
            }
            return groups;
        },
    },
    created() {
        this.loadConversations();
        initEcho();
        this._onIncoming = () => this.loadConversations(true);
        window.addEventListener('chat:incoming', this._onIncoming);
        // Deep-link: /chat?open=<id> (from the order slider's chat button).
        const openId = Number(this.$route.query.open || 0);
        if (openId) this.$nextTick(() => this.openConversation({ id: openId }));
    },
    beforeUnmount() {
        this.leaveChannel();
        if (this._onIncoming) window.removeEventListener('chat:incoming', this._onIncoming);
    },
    methods: {
        /** tel: needs digits and a leading +, nothing else. */
        telHref(code, mobile) {
            return 'tel:' + String((code || '') + (mobile || '')).replace(/[^\d+]/g, '');
        },
        loadConversations(silent = false) {
            if (!silent) this.loadingList = true;
            axios.get(this.$deliveryBoyApiUrl + '/chat/conversations', { params: { search: this.search } })
                .then(res => { this.conversations = res.data.data || []; })
                .finally(() => { this.loadingList = false; });
        },
        debouncedSearch() {
            clearTimeout(this._searchDebounce);
            this._searchDebounce = setTimeout(() => this.loadConversations(), 400);
        },
        // Start (or open) the customer chat for an assigned order id.
        startOrder(orderId) {
            this.startingOrder = true;
            axios.post(this.$deliveryBoyApiUrl + '/chat/start_order', { order_id: orderId })
                .then(res => {
                    if (res.data.status === 1 && res.data.data) {
                        this.search = '';
                        this.loadConversations(true);
                        this.openConversation(res.data.data);
                    } else {
                        this.showError(res.data.message || __('something_went_wrong'));
                    }
                })
                .catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.startingOrder = false; });
        },
        contactAdmin() {
            axios.post(this.$deliveryBoyApiUrl + '/chat/start_admin').then(res => {
                this.loadConversations(true);
                if (res.data.data) this.openConversation(res.data.data);
            });
        },
        openConversation(c) {
            this.active = c;
            this.messages = [];
            this.hasMore = false;
            this.loadingOlder = false;
            c.unread_count = 0; // initialLoad marks read server-side; clear badge now
            this.initialLoad();
            this.subscribe(c.id);
        },
        initialLoad() {
            if (!this.active) return;
            axios.get(this.$deliveryBoyApiUrl + '/chat/messages', { params: { conversation_id: this.active.id, limit: this.pageSize, offset: 0 } })
                .then(res => {
                    const d = res.data.data;
                    this.messages = d.messages || [];
                    this.hasMore = this.messages.length < (res.data.total || 0);
                    if (d.conversation) this.active = { ...this.active, ...d.conversation };
                    this.$nextTick(this.scrollBottom);
                    window.dispatchEvent(new Event('chat:refresh-unread'));
                });
        },
        refreshMessages() {
            if (!this.active) return;
            axios.get(this.$deliveryBoyApiUrl + '/chat/messages', { params: { conversation_id: this.active.id, limit: this.pageSize, offset: 0 } })
                .then(res => {
                    const d = res.data.data;
                    if (d.conversation) this.active = { ...this.active, ...d.conversation };
                    const incoming = d.messages || [];
                    const known = new Set(this.messages.map(m => m.id));
                    const fresh = incoming.filter(m => !known.has(m.id));
                    if (fresh.length) {
                        this.messages.push(...fresh);
                        this.$nextTick(this.scrollBottom);
                    }
                });
        },
        onThreadScroll() {
            const el = this.$refs.body;
            if (el && el.scrollTop < 50) this.loadOlder();
        },
        loadOlder() {
            if (!this.active || !this.hasMore || this.loadingOlder) return;
            this.loadingOlder = true;
            const el = this.$refs.body;
            const prevHeight = el ? el.scrollHeight : 0;
            axios.get(this.$deliveryBoyApiUrl + '/chat/messages', { params: { conversation_id: this.active.id, limit: this.pageSize, offset: this.messages.length } })
                .then(res => {
                    const d = res.data.data;
                    const older = d.messages || [];
                    if (older.length) {
                        this.messages = [...older, ...this.messages];
                        this.$nextTick(() => {
                            if (el) el.scrollTop = el.scrollHeight - prevHeight;
                        });
                    }
                    this.hasMore = this.messages.length < (res.data.total || 0);
                })
                .finally(() => { this.loadingOlder = false; });
        },
        onImage(e) {
            const files = Array.from(e.target.files || []);
            files.forEach(f => {
                this.imageFiles.push(f);
                this.imagePreviews.push(URL.createObjectURL(f));
            });
            if (this.$refs.file) this.$refs.file.value = '';
        },
        removeImage(i) {
            this.imageFiles.splice(i, 1);
            this.imagePreviews.splice(i, 1);
        },
        onAudio(e) {
            const files = Array.from(e.target.files || []);
            files.forEach(f => this.audioFiles.push(f));
            if (this.$refs.audio) this.$refs.audio.value = '';
        },
        removeAudio(i) {
            this.audioFiles.splice(i, 1);
        },
        onVideo(e) {
            const files = Array.from(e.target.files || []);
            files.forEach(f => this.videoFiles.push(f));
            if (this.$refs.video) this.$refs.video.value = '';
        },
        removeVideo(i) {
            this.videoFiles.splice(i, 1);
        },
        onDoc(e) {
            const files = Array.from(e.target.files || []);
            files.forEach(f => this.docFiles.push(f));
            if (this.$refs.doc) this.$refs.doc.value = '';
        },
        removeDoc(i) {
            this.docFiles.splice(i, 1);
        },
        clearImages() {
            this.imageFiles = [];
            this.imagePreviews = [];
            this.audioFiles = [];
            this.videoFiles = [];
            this.docFiles = [];
            if (this.$refs.file) this.$refs.file.value = '';
            if (this.$refs.audio) this.$refs.audio.value = '';
            if (this.$refs.video) this.$refs.video.value = '';
            if (this.$refs.doc) this.$refs.doc.value = '';
        },
        send() {
            const text = this.draft.trim();
            if ((!text && !this.imageFiles.length && !this.audioFiles.length && !this.videoFiles.length && !this.docFiles.length) || !this.active) return;
            this.sending = true;
            const fd = new FormData();
            fd.append('conversation_id', this.active.id);
            fd.append('message', text);
            this.imageFiles.forEach(f => fd.append('images[]', f));
            this.audioFiles.forEach(f => fd.append('audios[]', f));
            this.videoFiles.forEach(f => fd.append('videos[]', f));
            this.docFiles.forEach(f => fd.append('files[]', f));
            axios.post(this.$deliveryBoyApiUrl + '/chat/send', fd)
                .then(res => {
                    this.draft = '';
                    this.clearImages();
                    const data = res.data.data;
                    const arr = Array.isArray(data) ? data : (data ? [data] : []);
                    arr.forEach(m => { if (!this.messages.find(x => x.id === m.id)) this.messages.push(m); });
                    this.$nextTick(this.scrollBottom);
                    this.loadConversations(true);
                })
                .catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.sending = false; });
        },
        subscribe(id) {
            this.leaveChannel();
            const echo = getEcho();
            if (!echo) return;
            try {
                // Remember the name we actually joined. openConversation() already points
                // `active` at the NEW conversation by the time we get here, so deriving the
                // name from `active` on leave would unsubscribe the channel we just joined
                // and strand the previous one.
                this._channelName = 'chat.conversation.' + id;
                echo.private(this._channelName).listen('.message.sent', (e) => {
                    if (this.active && this.active.id === id) {
                        if (!this.messages.find(m => m.id === e.id)) {
                            this.messages.push(e); this.$nextTick(this.scrollBottom);
                        }
                        if (e.sender_type !== 'delivery_boy') this.markReadActive();
                    }
                    this.loadConversations(true);
                });
            } catch (err) { /* realtime best-effort */ }
        },
        leaveChannel() {
            const echo = getEcho();
            if (echo && this._channelName) { try { echo.leave(this._channelName); } catch (e) {} }
            this._channelName = null;
        },
        markReadActive() {
            if (!this.active) return;
            const id = this.active.id;
            axios.post(this.$deliveryBoyApiUrl + '/chat/mark_read', { conversation_id: id })
                .then(() => window.dispatchEvent(new Event('chat:refresh-unread')))
                .catch(() => {});
            this.active.unread_count = 0;
            const c = this.conversations.find(x => x.id === id);
            if (c) c.unread_count = 0;
        },
        scrollBottom() {
            const el = this.$refs.body;
            if (el) el.scrollTop = el.scrollHeight;
        },
        dateLabel(d) {
            if (isNaN(d)) return '';
            const today = new Date(); today.setHours(0, 0, 0, 0);
            const that = new Date(d); that.setHours(0, 0, 0, 0);
            const diff = Math.round((today - that) / 86400000);
            if (diff === 0) return __('today');
            if (diff === 1) return __('yesterday');
            return that.toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' });
        },
        shortTime(dt) {
            let s = (dt || '').replace(' ', 'T');
            // API times are UTC; add Z (when no offset present) so Date converts to local.
            if (s && !/[zZ]|[+-]\d{2}:?\d{2}$/.test(s)) s += 'Z';
            const d = new Date(s);
            if (isNaN(d)) return '';
            return d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
        },
        // Conversation-list timestamp: time if today, "yesterday", else short date.
        convTime(dt) {
            let s = (typeof dt === 'string' ? dt : (dt ? String(dt) : '')).replace(' ', 'T');
            if (!s) return '';
            if (!/[zZ]|[+-]\d{2}:?\d{2}$/.test(s)) s += 'Z';
            const d = new Date(s);
            if (isNaN(d)) return '';
            const today = new Date();
            if (d.toDateString() === today.toDateString()) return this.shortTime(dt);
            const yest = new Date(today);
            yest.setDate(today.getDate() - 1);
            if (d.toDateString() === yest.toDateString()) return __('yesterday');
            return d.toLocaleDateString(undefined, { day: '2-digit', month: 'short' });
        },
        initials(name) {
            const n = (name || '').trim();
            if (!n) return '?';
            return n.split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase();
        },
    },
};
</script>

<style scoped>
/* Colours come from the shell tokens so the whole page tracks dark mode. */
.chat-wrap { --chat-hover: var(--app-hover); }
.chat-list, .chat-thread { height: 74vh; overflow: hidden; }
.chat-list { display: flex; flex-direction: column; }

/* Search box with a leading icon (matches the list-page search). */
.chat-search { position: relative; padding: .75rem; border-bottom: 1px solid var(--app-card-border); }
.chat-search-icon { position: absolute; top: 50%; inset-inline-start: 1.4rem; transform: translateY(-50%); width: 15px; height: 15px; color: var(--app-muted); pointer-events: none; }
.chat-search .form-control { height: 38px; padding-inline-start: 2rem; border-radius: 8px; }

.chat-conv-scroll { overflow-y: auto; flex: 1; }
.chat-empty-list { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 2.5rem 1rem; color: var(--app-muted); font-size: .8rem; }
.chat-empty-list svg { opacity: .5; }
.conv-item { display: flex; gap: .6rem; padding: .7rem .85rem; cursor: pointer; border-bottom: 1px solid var(--app-card-border); transition: background-color .12s ease; }
.conv-item:hover { background: var(--chat-hover); }
.conv-item.active { background: rgba(var(--bs-primary-rgb), .08); box-shadow: inset 3px 0 0 var(--bs-primary); }
.conv-title { font-weight: 600; font-size: .85rem; color: var(--app-ink); display: inline-flex; align-items: center; }
.conv-avatar { width: 40px; height: 40px; flex: 0 0 40px; border-radius: 50%; background: linear-gradient(135deg, var(--bs-primary), #6d84d6); color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: .82rem; overflow: hidden; }
.conv-avatar img { width: 100%; height: 100%; object-fit: cover; }
.conv-type { color: var(--app-muted); font-size: .68rem; }
.conv-unread { min-width: 18px; height: 18px; padding: 0 5px; display: inline-flex; align-items: center; justify-content: center; border-radius: 999px; background: #ef4444; color: #fff; font-size: .62rem; font-weight: 700; }
.min-w-0 { min-width: 0; }

.chat-thread { display: flex; flex-direction: column; }
.thread-header { display: flex; gap: .7rem; align-items: center; padding: .8rem 1rem; border-bottom: 1px solid var(--app-card-border); }
.thread-header .conv-title { display: flex; }
.thread-header small { display: block; margin-top: 2px; }
.thread-body { flex: 1; overflow-y: auto; padding: 1rem; background: var(--app-thead-bg); }
.date-sep { display: flex; justify-content: center; margin: .7rem 0; }
.date-sep span { background: var(--app-card-bg); border: 1px solid var(--app-card-border); color: var(--app-muted); font-size: .68rem; font-weight: 600; padding: .2rem .75rem; border-radius: 999px; }
.msg-row { display: flex; margin-bottom: .5rem; }
.msg-row.mine { justify-content: flex-end; }
.msg-bubble { max-width: 72%; background: var(--app-card-bg); border: 1px solid var(--app-card-border); border-radius: 14px 14px 14px 4px; padding: .5rem .7rem; font-size: .85rem; color: var(--app-ink); box-shadow: 0 1px 1px rgba(16,24,40,.04); }
.msg-row.mine .msg-bubble { color: #fff; border-radius: 14px 14px 4px 14px; border-color: transparent; }
.msg-time { display: block; font-size: .62rem; opacity: .7; margin-top: .15rem; text-align: right; }
.img-bubble { position: relative; max-width: 72%; line-height: 0; }
.msg-img { max-width: 240px; max-height: 260px; border-radius: 12px; display: block; }
.msg-video { max-width: 240px; max-height: 260px; border-radius: 12px; display: block; background: #000; }
.img-time { position: absolute; right: 6px; bottom: 6px; background: rgba(0, 0, 0, .55); color: #fff; font-size: .62rem; line-height: 1; padding: .15rem .4rem; border-radius: .6rem; }
.audio-bubble { background: var(--app-card-bg) !important; }
.audio-bubble .msg-audio { display: block; height: 36px; max-width: 240px; }
.audio-bubble .audio-time { color: var(--app-muted); }
.file-link { color: inherit; text-decoration: none; font-size: .85rem; display: inline-flex; align-items: center; gap: .35rem; }

.audio-chip { display: inline-flex; align-items: center; gap: .35rem; max-width: 170px; background: var(--app-thead-bg); border: 1px solid var(--app-card-border); border-radius: 8px; padding: .3rem .55rem; font-size: .75rem; color: var(--app-ink); }
.chip-remove { display: inline-flex; align-items: center; justify-content: center; width: 18px; height: 18px; border: none; border-radius: 50%; background: #ef4444; color: #fff; cursor: pointer; padding: 0; flex-shrink: 0; }
.img-preview-strip { display: flex; gap: .5rem; flex-wrap: wrap; padding: .6rem 1rem 0; align-items: center; }
.img-preview { position: relative; display: inline-block; }
.img-preview img { width: 66px; height: 66px; object-fit: cover; border-radius: 8px; border: 1px solid var(--app-card-border); }
.img-preview .chip-remove { position: absolute; top: -7px; right: -7px; }

.thread-input { display: flex; gap: .4rem; padding: .7rem 1rem; border-top: 1px solid var(--app-card-border); align-items: center; }
.thread-input .form-control { border-radius: 999px; height: 40px; }
.chat-attach-btn { display: inline-flex; align-items: center; justify-content: center; width: 38px; height: 38px; flex-shrink: 0; border: none; border-radius: 50%; background: transparent; color: var(--app-muted); cursor: pointer; transition: background-color .12s ease, color .12s ease; }
.chat-attach-btn:hover { background: var(--chat-hover); color: var(--bs-primary); }
.chat-send-btn { width: 40px; height: 40px; flex-shrink: 0; border-radius: 50%; padding: 0; }

.conv-meta { display: flex; flex-wrap: wrap; align-items: center; gap: .1rem .45rem; }
.conv-meta > span { display: inline-flex; align-items: center; gap: .25rem; min-width: 0; }
.conv-meta > span + span::before { content: '·'; margin-right: .45rem; opacity: .6; }
.conv-meta svg { flex-shrink: 0; opacity: .7; }
.chat-link { cursor: pointer; color: inherit; text-decoration: none; }
.chat-link:hover { color: var(--bs-primary); }

.thread-empty { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; color: var(--app-muted); padding: 1.5rem; }
.thread-empty-art { width: 100%; max-width: 230px; height: auto; margin-bottom: 1.4rem; }
.thread-empty-title { font-size: 1.05rem; font-weight: 700; color: var(--app-ink); margin: 0 0 .4rem; }
.thread-empty-text { font-size: .86rem; line-height: 1.55; margin: 0; max-width: 330px; }
</style>
