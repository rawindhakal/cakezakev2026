<template>
    <div class="list-page" :class="{ 'chat-fullscreen': isNarrow && active }">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('chat') }}</h3>
            <div class="d-flex align-items-center gap-2 flex-wrap ms-auto">
                <AppSelect v-if="czShowCountry" class="cz-sel" v-model="czCountryId" :options="czCountryOptions"
                    :searchable="czCountryOptions.length > 6" :allow-empty="false" label-key="label" track-by="id"
                    :placeholder="__('country')" @update:model-value="czOnCountry">
                    <template #singleLabel="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                    <template #option="{ option }"><span class="cz-opt"><img v-if="option.logo_url"
                                :src="option.logo_url" class="cz-flag" />{{ option.label }}</span></template>
                </AppSelect>
                <AppSelect v-if="czShowZoneDropdown" class="cz-sel" v-model="czZoneId" :options="czZoneOptions"
                    :searchable="false" :allow-empty="false" label-key="label" track-by="id"
                    :placeholder="__('zone')" @update:model-value="czOnZone" />
                <button class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                    @click="openNew = true">
                    <Plus :size="16" /><span>{{ __('new_chat') }}</span>
                </button>
            </div>
        </div>

        <div class="row chat-wrap">
            <!-- Conversation list -->
            <div class="col-lg-4" v-show="!isNarrow || !active">
                    <div class="chat-list list-surface">
                        <div class="chat-search">
                            <Search class="chat-search-icon" />
                            <input type="search" class="form-control" v-model="search"
                                :placeholder="__('search')" @input="debouncedLoad" />
                        </div>
                        <div class="chat-tabs-wrap">
                            <button type="button" class="tab-nav-btn" @click="scrollTabs(-1)" :title="__('previous')">
                                <ChevronLeft :size="16" />
                            </button>
                            <ul class="nav nav-tabs chat-tabs" ref="tabsScroll">
                                <li class="nav-item" v-for="t in tabs" :key="t.key">
                                    <a class="nav-link" href="#" :class="{ active: typeFilter === t.key }"
                                        @click.prevent="typeFilter = t.key; loadConversations()">
                                        <component :is="t.icon" :size="14" /> {{ t.label }}
                                    </a>
                                </li>
                            </ul>
                            <button type="button" class="tab-nav-btn" @click="scrollTabs(1)" :title="__('next')">
                                <ChevronRight :size="16" />
                            </button>
                        </div>
                        <div class="chat-conv-scroll" @scroll.passive="onConvScroll">
                            <template v-if="loadingList">
                                <div v-for="n in 7" :key="'convskel-' + n" class="conv-item">
                                    <div class="conv-avatar skel"></div>
                                    <div class="flex-grow-1 min-w-0">
                                        <div class="skel skel-line" style="width:70%;margin-bottom:.45rem"></div>
                                        <div class="skel skel-line" style="width:90%;margin-bottom:.45rem"></div>
                                        <div class="skel skel-line" style="width:40%;margin-bottom:0"></div>
                                    </div>
                                </div>
                            </template>
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
                                        <span v-if="c.parties" class="conv-title text-truncate">
                                            {{ c.parties.from }}
                                            <ArrowLeftRight :size="12" class="mx-1 text-muted" />
                                            {{ c.parties.to }}
                                        </span>
                                        <span v-else class="conv-title text-truncate">{{ c.title }}</span>
                                        <small class="text-muted text-nowrap">{{ convTime(c.last_time) }}</small>
                                    </div>
                                    <div class="d-flex justify-content-between align-items-center">
                                        <small class="text-muted text-truncate">{{ c.last_message || '—' }}</small>
                                        <span v-if="c.unread_count" class="conv-unread">{{ c.unread_count }}</span>
                                    </div>
                                    <small class="conv-type">{{ typeLabel(c.type) }}<span v-if="c.order_id"> · {{ c.order_number || ('#' + String(c.order_id).padStart(5, '0')) }}</span></small>
                                </div>
                            </div>

                            <!-- The next page arrives before the bottom is reached, so this
                                 is usually a flicker rather than a wait. -->
                            <div v-if="loadingMoreConvs" class="conv-more">
                                <b-spinner small></b-spinner>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Thread -->
                <div class="col-lg-8 mt-3 mt-lg-0" v-show="!isNarrow || active">
                    <div class="chat-thread list-surface">
                        <template v-if="active">
                            <div class="thread-header">
                                <button v-if="isNarrow" type="button" class="thread-back"
                                    :title="__('back')" @click="closeConversation">
                                    <ChevronLeft :size="18" />
                                </button>
                                <div class="conv-avatar">
                                    <img v-if="active.avatar" :src="active.avatar" alt="" />
                                    <template v-else>{{ initials(active.title) }}</template>
                                </div>
                                <div class="min-w-0">
                                    <div class="conv-title" v-if="active.parties">
                                        <span :class="{ 'chat-link': canOpenCustomer }" @click="openCustomer()">{{ active.parties.from }}</span>
                                        <ArrowLeftRight :size="13" class="mx-1 text-muted" />
                                        <span :class="{ 'chat-link': canOpenDeliveryBoy }" @click="openDeliveryBoy()">{{ active.parties.to }}</span>
                                    </div>
                                    <!-- Non order-scoped: the title IS the counterparty — customer or rider. -->
                                    <div class="conv-title" v-else>
                                        <span :class="{ 'chat-link': canOpenCustomer || canOpenDeliveryBoy }"
                                            @click="canOpenCustomer ? openCustomer() : openDeliveryBoy()">{{ active.title }}</span>
                                    </div>
                                    <!-- Type · order · contact, all on the one meta line. -->
                                    <small class="text-muted conv-meta">
                                        <span>{{ typeLabel(active.type) }}</span>
                                        <span v-if="active.order_id" :class="{ 'chat-link': canOpenOrder }"
                                            @click="openOrder(active.order_id)" v-b-tooltip.hover
                                            :title="canOpenOrder ? __('view') : ''">{{ active.order_number || ('#' + String(active.order_id).padStart(5, '0')) }}</span>
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
                                    <div v-for="m in g.items" :key="m.id" class="msg-row"
                                        :class="{ mine: m.sender_type === 'admin' }">
                                        <!-- Image: bare image, time overlaid bottom-right -->
                                        <div v-if="m.attachment_type === 'image'" class="img-bubble">
                                            <a :href="m.attachment_url" target="_blank">
                                                <img :src="m.attachment_url" class="msg-img" alt="" @load="scrollBottom" />
                                            </a>
                                            <span class="img-time">{{ shortTime(m.created_at) }}</span>
                                        </div>
                                        <!-- Audio -->
                                        <div v-else-if="m.attachment_type === 'audio'" class="msg-bubble audio-bubble">
                                            <audio controls :src="m.attachment_url" class="msg-audio"></audio>
                                            <small class="msg-time audio-time">{{ shortTime(m.created_at) }}</small>
                                        </div>
                                        <!-- Video -->
                                        <div v-else-if="m.attachment_type === 'video'" class="img-bubble">
                                            <video controls :src="m.attachment_url" class="msg-video"></video>
                                            <span class="img-time">{{ shortTime(m.created_at) }}</span>
                                        </div>
                                        <!-- Other file -->
                                        <div v-else-if="m.attachment_url" class="msg-bubble"
                                            :style="m.sender_type === 'admin' ? { background: primaryColor, borderColor: primaryColor } : {}">
                                            <a :href="m.attachment_url" target="_blank" class="file-link"><Paperclip :size="14" /> {{ __('file') }}</a>
                                            <small class="msg-time">{{ shortTime(m.created_at) }}</small>
                                        </div>
                                        <!-- Text -->
                                        <div v-else class="msg-bubble"
                                            :style="m.sender_type === 'admin' ? { background: primaryColor, borderColor: primaryColor } : {}">
                                            <div>{{ m.message }}</div>
                                            <small class="msg-time">{{ shortTime(m.created_at) }}</small>
                                        </div>
                                    </div>
                                </template>
                            </div>
                            <div v-if="canSend">
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
                                    <!-- Phones: the four attach buttons fold into one menu so the text box keeps its width. -->
                                    <div v-if="isNarrow" class="dropup">
                                        <button class="chat-attach-btn" data-bs-toggle="dropdown" aria-expanded="false" :title="__('attach_file')">
                                            <Plus :size="20" />
                                        </button>
                                        <ul class="dropdown-menu chat-attach-menu">
                                            <li><button class="dropdown-item" @click="$refs.file.click()"><ImageIcon :size="16" /> {{ __('attach_image') }}</button></li>
                                            <li><button class="dropdown-item" @click="$refs.audio.click()"><Mic :size="16" /> {{ __('attach_audio') }}</button></li>
                                            <li><button class="dropdown-item" @click="$refs.video.click()"><Video :size="16" /> {{ __('attach_video') }}</button></li>
                                            <li><button class="dropdown-item" @click="$refs.doc.click()"><Paperclip :size="16" /> {{ __('attach_file') }}</button></li>
                                        </ul>
                                    </div>
                                    <template v-else>
                                        <button class="chat-attach-btn" @click="$refs.file.click()" :title="__('attach_image')">
                                            <ImageIcon :size="18" />
                                        </button>
                                        <button class="chat-attach-btn" @click="$refs.audio.click()" :title="__('attach_audio')">
                                            <Mic :size="18" />
                                        </button>
                                        <button class="chat-attach-btn" @click="$refs.video.click()" :title="__('attach_video')">
                                            <Video :size="18" />
                                        </button>
                                        <button class="chat-attach-btn" @click="$refs.doc.click()" :title="__('attach_file')">
                                            <Paperclip :size="18" />
                                        </button>
                                    </template>
                                    <input ref="draft" type="text" class="form-control" :placeholder="__('type_a_message')"
                                        @input="onDraftInput" @keyup.enter="send" />

                                    <button ref="sendBtn" class="btn btn-primary chat-send-btn" disabled
                                        :style="{ background: primaryColor, borderColor: primaryColor }" @click="send">
                                        <b-spinner small v-if="sending"></b-spinner><Send v-else :size="17" />
                                    </button>
                                </div>
                            </div>
                            <div v-else class="thread-input text-muted small justify-content-center">
                                {{ __('admin_cannot_message_this_conversation') }}
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

        <!-- New chat modal -->
        <b-modal v-model="openNew" :title="__('new_chat')" hide-footer>
            <div class="d-flex gap-2 mb-2">
                <button class="btn btn-sm" :class="newType === 'customer' ? 'btn-primary' : 'btn-outline-primary'" @click="newType = 'customer'; pickerSearch=''; loadPicker()">{{ __('customers') }}</button>
                <button class="btn btn-sm" :class="newType === 'delivery_boy' ? 'btn-primary' : 'btn-outline-primary'" @click="newType = 'delivery_boy'; pickerSearch=''; loadPicker()">{{ __('delivery_boys') }}</button>
            </div>
            <input type="search" class="form-control mb-2" v-model="pickerSearch" :placeholder="__('search')" @input="debouncedPicker" />
            <div class="picker-scroll">
                <div v-if="loadingPicker" class="text-center py-3"><b-spinner small></b-spinner></div>
                <div v-for="p in pickerItems" :key="p.id" class="picker-item" @click="startWith(p)">
                    <div class="conv-avatar">{{ initials(p.name) }}</div>
                    <span>{{ p.name }}</span>
                </div>
                <div v-if="!loadingPicker && !pickerItems.length" class="text-muted text-center py-3 small">{{ __('no_records_found') }}</div>
            </div>
        </b-modal>

        <OrderDetailSlider v-model="sliderShow" :order-id="sliderOrderId" />
    </div>
</template>

<script>
import { markRaw } from 'vue';
import axios from 'axios';
import { initEcho, getEcho } from '../../echo.js';
import {
    Plus, Search, ChevronLeft, ChevronRight, MessagesSquare, User, Bike, ShoppingCart, Phone, Mail,
    ArrowLeftRight, Paperclip, X, Music, Video, File as FileIcon, Image as ImageIcon,
    Mic, Send,
} from 'lucide-vue-next';
import CountryZoneFilter from '../../mixins/CountryZoneFilter.js';
import OrderDetailSlider from '../Orders/OrderDetailSlider.vue';

export default {
    name: 'AdminChat',
    mixins: [CountryZoneFilter],
    components: {
        OrderDetailSlider, Plus, Search, ChevronLeft, ChevronRight, MessagesSquare, User, Bike, ShoppingCart, Phone, Mail,
        ArrowLeftRight, Paperclip, X, Music, Video, FileIcon, ImageIcon, Mic, Send,
    },
    data() {
        return {
            czAllowAll: true,
            isNarrow: window.innerWidth < 992,
            conversations: [],
            convPageSize: 10,
            convTotal: 0,
            loadingMoreConvs: false,
            active: null,
            messages: [],
            hasMore: false,
            loadingOlder: false,
            pageSize: 30,
            sliderShow: false,
            sliderOrderId: null,
            imageFiles: [],
            imagePreviews: [],
            audioFiles: [],
            videoFiles: [],
            docFiles: [],
            search: '',
            typeFilter: '',
            loadingList: false,
            sending: false,
            openNew: false,
            newType: 'customer',
            pickerSearch: '',
            pickerItems: [],
            loadingPicker: false,
            _debounce: null,
            _pickerDebounce: null,
            _channel: null,
        };
    },
    computed: {
        moreConversations() {
            return this.conversations.length < this.convTotal;
        },
        primaryColor() { return window.adminThemeColor || '#435ebe'; },
        chatFullscreen() { return this.isNarrow && !!this.active; },
        customer() { return (this.active && this.active.customer) || null; },
        deliveryBoy() { return (this.active && this.active.delivery_boy) || null; },
        contact() { return this.customer || this.deliveryBoy; },
        canOpenCustomer() { return !!(this.customer && this.customer.id) && this.$can('order_list'); },
        canOpenOrder() { return !!(this.active && this.active.order_id) && this.$can('order_list'); },
        canOpenDeliveryBoy() { return !!(this.deliveryBoy && this.deliveryBoy.id) && this.$can('delivery_boy_list'); },
        canContact() { return this.$isDemo != 1; },
        tabs() {
            return [
                { key: '', label: __('all'), icon: markRaw(MessagesSquare) },
                { key: 'admin_customer', label: __('customers'), icon: markRaw(User) },
                { key: 'admin_delivery_boy', label: __('delivery_boys'), icon: markRaw(Bike) },
                { key: 'order_admin', label: __('orders'), icon: markRaw(ShoppingCart) },
                { key: 'delivery_boy_customer', label: __('delivery_customer'), icon: markRaw(ArrowLeftRight) },
            ];
        },
        canSend() {
            // Admin can message its own threads (support + order↔admin), but is observer-only
            // on customer↔delivery-boy (delivery_boy_customer).
            return this.active && ['admin_customer', 'admin_delivery_boy', 'order_admin'].includes(this.active.type);
        },
        // Admin only observes customer↔delivery-boy chats → never mark them read.
        isObserverOnly() {
            return this.active && this.active.type === 'delivery_boy_customer';
        },
        // Group messages by calendar date for WhatsApp-style date separators.
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
        this.czLoad(); // loads country then czOnFilter (loadConversations)
        initEcho();
        this._onIncoming = () => this.loadConversations(true);
        window.addEventListener('chat:incoming', this._onIncoming);
        // Deep-link: /chat?open=<id> (from an order/return slider's chat button).
        const openId = Number(this.$route.query.open || 0);
        if (openId) this.$nextTick(() => this.openConversation({ id: openId }));

        // Rotating a phone, or dragging a desktop window narrow, must swap layouts.
        this._onResize = () => { this.isNarrow = window.innerWidth < 992; };
        window.addEventListener('resize', this._onResize);
    },
    updated() {
        this.syncSendBtn();
    },
    beforeUnmount() {
        document.body.classList.remove('chat-lock');
        this.leaveChannel();
        window.activeChatConversationId = null;
        if (this._onIncoming) window.removeEventListener('chat:incoming', this._onIncoming);
        if (this._onResize) window.removeEventListener('resize', this._onResize);
    },
    methods: {
        /** Back to the list on a phone. The thread stays loaded; only the view changes. */
        closeConversation() {
            this.leaveChannel();
            this.active = null;
            this.messages = [];
            window.activeChatConversationId = null;
        },
        openCustomer() {
            if (!this.canOpenCustomer) return;
            this.$router.push('/users/view/' + this.customer.id);
        },
        openDeliveryBoy() {
            if (!this.canOpenDeliveryBoy) return;
            this.$router.push('/delivery_boys/view/' + this.deliveryBoy.id);
        },
        /** tel: needs digits and a leading +, nothing else. */
        telHref(code, mobile) {
            return 'tel:' + String((code || '') + (mobile || '')).replace(/[^\d+]/g, '');
        },
        czOnFilter() { this.loadConversations(); },
        debouncedLoad() {
            clearTimeout(this._debounce);
            this._debounce = setTimeout(() => this.loadConversations(), 400);
        },
        // Scroll the tab strip left (-1) / right (1) via the chevron buttons.
        scrollTabs(dir) {
            const el = this.$refs.tabsScroll;
            if (el) el.scrollBy({ left: dir * 140, behavior: 'smooth' });
        },
        /** The filters every conversations call carries. */
        convParams() {
            return {
                type: this.typeFilter,
                search: this.search,
                country_id: this.czCountryParam,
                zone_id: this.czZoneParam,
            };
        },
        loadConversations(silent = false) {
            if (!silent) this.loadingList = true;
            const limit = silent
                ? Math.max(this.conversations.length, this.convPageSize)
                : this.convPageSize;

            axios.get(this.$apiUrl + '/chat/conversations', {
                params: { ...this.convParams(), offset: 0, limit },
            })
                .then(res => {
                    this.conversations = res.data.data || [];
                    this.convTotal = Number(res.data.total) || this.conversations.length;
                })
                .finally(() => { this.loadingList = false; });
        },
        loadMoreConversations() {
            if (this.loadingMoreConvs || this.loadingList || !this.moreConversations) return;

            this.loadingMoreConvs = true;
            axios.get(this.$apiUrl + '/chat/conversations', {
                params: { ...this.convParams(), offset: this.conversations.length, limit: this.convPageSize },
            })
                .then(res => {
                    const seen = new Set(this.conversations.map(c => c.id));
                    const fresh = (res.data.data || []).filter(c => !seen.has(c.id));
                    this.conversations = this.conversations.concat(fresh);
                    this.convTotal = Number(res.data.total) || this.convTotal;
                    // Nothing new in a whole page means the list has shifted under us;
                    // stop asking rather than spinning on every scroll.
                    if (!fresh.length) this.convTotal = this.conversations.length;
                })
                .finally(() => { this.loadingMoreConvs = false; });
        },
        /** Within a page of the bottom: fetch the next one before it is needed. */
        onConvScroll(e) {
            const el = e.target;
            if (el.scrollHeight - el.scrollTop - el.clientHeight < 120) {
                this.loadMoreConversations();
            }
        },
        openConversation(c) {
            this.active = c;
            this.messages = [];
            this.hasMore = false;
            this.loadingOlder = false;
            // Observer-only threads (customer↔delivery-boy) are never marked read by admin,
            // so keep their unread badge; other threads clear now (server marks them read).
            if (c.type !== 'delivery_boy_customer') c.unread_count = 0;
            // Expose the open conversation so fcm.js can suppress the push for it (you're
            // already looking at it → the realtime handler shows the message).
            window.activeChatConversationId = c.id;
            this.initialLoad();
            this.subscribe(c.id);
        },
        // First page: latest messages.
        initialLoad() {
            if (!this.active) return;
            axios.get(this.$apiUrl + '/chat/messages', { params: { conversation_id: this.active.id, limit: this.pageSize, offset: 0 } })
                .then(res => {
                    const d = res.data.data;
                    this.messages = d.messages || [];
                    this.hasMore = this.messages.length < (res.data.total || 0);
                    if (d.conversation) this.active = { ...this.active, ...d.conversation };
                    this.$nextTick(this.scrollBottom);
                    // Opening marked it read server-side → refresh sidebar badge. Skip for
                    // observer-only threads (admin never marks those read).
                    if (!this.isObserverOnly) window.dispatchEvent(new Event('chat:refresh-unread'));
                });
        },
        // Poll: merge only newer messages, keep loaded history + scroll position.
        refreshMessages() {
            if (!this.active) return;
            axios.get(this.$apiUrl + '/chat/messages', { params: { conversation_id: this.active.id, limit: this.pageSize, offset: 0 } })
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
        // Scroll-up loads older messages, preserving viewport position.
        onThreadScroll() {
            const el = this.$refs.body;
            if (el && el.scrollTop < 50) this.loadOlder();
        },
        loadOlder() {
            if (!this.active || !this.hasMore || this.loadingOlder) return;
            this.loadingOlder = true;
            const el = this.$refs.body;
            const prevHeight = el ? el.scrollHeight : 0;
            axios.get(this.$apiUrl + '/chat/messages', { params: { conversation_id: this.active.id, limit: this.pageSize, offset: this.messages.length } })
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
        openOrder(id) {
            if (!this.canOpenOrder) return;
            this.sliderOrderId = Number(id);
            this.sliderShow = true;
        },
        onDraftInput() {
            this.syncSendBtn();
        },

        syncSendBtn() {
            const btn = this.$refs.sendBtn;
            if (!btn) return;
            const text = (this.$refs.draft ? this.$refs.draft.value : '').trim();
            const files = this.imageFiles.length || this.audioFiles.length || this.videoFiles.length || this.docFiles.length;
            btn.disabled = this.sending || (!text && !files);
        },
        send() {
            // Enter fires this directly — the button's :disabled doesn't guard the key.
            if (this.sending) return;
            const text = (this.$refs.draft ? this.$refs.draft.value : '').trim();
            if ((!text && !this.imageFiles.length && !this.audioFiles.length && !this.videoFiles.length && !this.docFiles.length) || !this.active) return;
            this.sending = true;
            // Clear the box now so a repeated Enter has nothing to resend; put it back on failure.
            if (this.$refs.draft) this.$refs.draft.value = '';
            this.syncSendBtn();
            const fd = new FormData();
            fd.append('conversation_id', this.active.id);
            fd.append('message', text);
            this.imageFiles.forEach(f => fd.append('images[]', f));
            this.audioFiles.forEach(f => fd.append('audios[]', f));
            this.videoFiles.forEach(f => fd.append('videos[]', f));
            this.docFiles.forEach(f => fd.append('files[]', f));
            axios.post(this.$apiUrl + '/chat/send', fd)
                .then(res => {
                    if (res.data && (res.data.status === 0 || res.data.error === true)) {
                        this.restoreDraft(text);
                        this.showError(res.data.message || __('something_went_wrong'));
                        return;
                    }
                    this.clearImages();
                    const data = res.data.data;
                    const arr = Array.isArray(data) ? data : (data ? [data] : []);
                    arr.forEach(m => { if (!this.messages.find(x => x.id === m.id)) this.messages.push(m); });
                    this.$nextTick(this.scrollBottom);
                    this.loadConversations(true);
                })
                .catch(err => {
                    // Surface the API's own error (validation / server message) instead of
                    // a generic string, so the SweetAlert tells the admin what actually failed.
                    const data = err && err.response && err.response.data;
                    let msg = data && (data.message || data.error);
                    if (!msg && data && data.errors) {
                        const first = Object.values(data.errors)[0];
                        msg = Array.isArray(first) ? first[0] : first;
                    }
                    this.restoreDraft(text);
                    this.showError(msg || __('something_went_wrong'));
                })
                .finally(() => { this.sending = false; });
        },
        restoreDraft(text) {
            if (!text || !this.$refs.draft) return;
            this.$refs.draft.value = text;
            this.syncSendBtn();
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
                this._channel = echo.private(this._channelName)
                    .listen('.message.sent', (e) => {
                        if (this.active && this.active.id === id) {
                            if (!this.messages.find(m => m.id === e.id)) {
                                this.messages.push(e);
                                this.$nextTick(this.scrollBottom);
                            }
                            // Viewing this thread → keep it read (don't show unread for active).
                            // But never mark observer-only (customer↔delivery-boy) threads read.
                            if (e.sender_type !== 'admin' && !this.isObserverOnly) this.markReadActive();
                        }
                        this.loadConversations(true);
                    });
            } catch (err) { /* realtime best-effort */ }
        },
        leaveChannel() {
            const echo = getEcho();
            if (echo && this._channelName) {
                try { echo.leave(this._channelName); } catch (e) {}
            }
            this._channelName = null;
            this._channel = null;
        },
        // Mark the active conversation read on the server + clear its badge locally.
        markReadActive() {
            if (!this.active) return;
            const id = this.active.id;
            axios.post(this.$apiUrl + '/chat/mark_read', { conversation_id: id })
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
        // New chat picker
        debouncedPicker() {
            clearTimeout(this._pickerDebounce);
            this._pickerDebounce = setTimeout(() => this.loadPicker(), 400);
        },
        loadPicker() {
            this.loadingPicker = true;
            const url = this.newType === 'customer' ? '/customers' : '/delivery_boys';
            axios.get(this.$apiUrl + url, { params: { search: this.pickerSearch, limit: 25 } })
                .then(res => {
                    const rows = res.data.data || [];
                    this.pickerItems = rows.map(r => ({ id: r.id, name: this.displayName(r.name) }));
                })
                .finally(() => { this.loadingPicker = false; });
        },
        startWith(p) {
            const url = this.newType === 'customer' ? '/chat/start_customer' : '/chat/start_delivery_boy';
            const body = this.newType === 'customer' ? { user_id: p.id } : { delivery_boy_id: p.id };
            axios.post(this.$apiUrl + url, body).then(res => {
                this.openNew = false;
                const conv = res.data.data;
                if (conv) {
                    this.loadConversations(true);
                    this.openConversation(conv);
                }
            }).catch(() => this.showError(__('something_went_wrong')));
        },
        openModalInit() { this.loadPicker(); },
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
        displayName(name) {
            if (name == null) return '';
            if (typeof name === 'string') return name;
            if (typeof name === 'object') {
                const loc = window.appLocale || localStorage.getItem('lang') || 'en';
                return name[loc] || Object.values(name).find(v => v && String(v).trim() !== '') || '';
            }
            return '';
        },
        typeLabel(t) {
            const m = { admin_customer: __('customers'), admin_delivery_boy: __('delivery_boys'), delivery_boy_customer: __('orders'), order_admin: __('orders') };
            return m[t] || t;
        },
    },
    watch: {
        openNew(v) { if (v) this.loadPicker(); },
        // Phone + open thread = the thread owns the screen; only its messages scroll.
        chatFullscreen: {
            immediate: true,
            handler(v) { document.body.classList.toggle('chat-lock', !!v); },
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

/* Tab strip: horizontally scrollable with prev/next chevrons; labels never truncate. */
.chat-tabs-wrap { display: flex; align-items: stretch; border-bottom: 1px solid var(--app-card-border); }
.chat-tabs { flex: 1; flex-wrap: nowrap; padding: 0 .25rem; overflow-x: auto; scrollbar-width: none; border-bottom: none; scroll-behavior: smooth; margin: 0; }
.chat-tabs::-webkit-scrollbar { display: none; }
.chat-tabs .nav-item { min-width: 0; flex: 0 0 auto; }
.chat-tabs .nav-link { display: inline-flex; align-items: center; gap: .3rem; color: var(--app-muted); font-weight: 500; font-size: .78rem; padding: .6rem .7rem; white-space: nowrap; border: none !important; }
.chat-tabs .nav-link.active { color: var(--bs-primary); background: transparent; }
.chat-tabs .nav-link.active:after { display: none; }
.tab-nav-btn { flex: 0 0 auto; display: inline-flex; align-items: center; border: none; background: transparent; color: var(--app-muted); padding: 0 .5rem; cursor: pointer; }
.tab-nav-btn:hover { color: var(--bs-primary); background: var(--chat-hover); }

.chat-conv-scroll { overflow-y: auto; flex: 1; }
/* The next page loading in, at the foot of the list. */
.conv-more { display: flex; justify-content: center; padding: .75rem 0; color: var(--app-muted); }
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
/* In the header the title stacks above the type — `.conv-title` is inline-flex
   (for the list rows), so force it to a block here or the type glues to the name. */
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
/* Image message: bare image, no card; time chip bottom-right. */
.img-bubble { position: relative; max-width: 72%; line-height: 0; }
.msg-img { max-width: 240px; max-height: 260px; border-radius: 12px; display: block; }
.msg-video { max-width: 240px; max-height: 260px; border-radius: 12px; display: block; background: #000; }
.img-time { position: absolute; right: 6px; bottom: 6px; background: rgba(0, 0, 0, .55); color: #fff; font-size: .62rem; line-height: 1; padding: .15rem .4rem; border-radius: .6rem; }
.audio-bubble { background: var(--app-card-bg) !important; }
.audio-bubble .msg-audio { display: block; height: 36px; max-width: 240px; }
.audio-bubble .audio-time { color: var(--app-muted); }
.file-link { color: inherit; text-decoration: none; font-size: .85rem; display: inline-flex; align-items: center; gap: .35rem; }

/* Attachment chips + preview strip */
.audio-chip { display: inline-flex; align-items: center; gap: .35rem; max-width: 170px; background: var(--app-thead-bg); border: 1px solid var(--app-card-border); border-radius: 8px; padding: .3rem .55rem; font-size: .75rem; color: var(--app-ink); }
.chip-remove { display: inline-flex; align-items: center; justify-content: center; width: 18px; height: 18px; border: none; border-radius: 50%; background: #ef4444; color: #fff; cursor: pointer; padding: 0; flex-shrink: 0; }
.img-preview-strip { display: flex; gap: .5rem; flex-wrap: wrap; padding: .6rem 1rem 0; align-items: center; }
.img-preview { position: relative; display: inline-block; }
.img-preview img { width: 66px; height: 66px; object-fit: cover; border-radius: 8px; border: 1px solid var(--app-card-border); }
.img-preview .chip-remove { position: absolute; top: -7px; right: -7px; }

/* Input bar */
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
.conv-title .chat-link:hover { color: var(--bs-primary); }

.thread-empty { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; color: var(--app-muted); padding: 1.5rem; }
.thread-empty-art { width: 100%; max-width: 230px; height: auto; margin-bottom: 1.4rem; }
.thread-empty-title { font-size: 1.05rem; font-weight: 700; color: var(--app-ink); margin: 0 0 .4rem; }
.thread-empty-text { font-size: .86rem; line-height: 1.55; margin: 0; max-width: 330px; }

.picker-scroll { max-height: 320px; overflow-y: auto; }
.picker-item { display: flex; gap: .6rem; align-items: center; padding: .5rem; cursor: pointer; border-radius: 8px; }
.picker-item:hover { background: var(--chat-hover); }
.gap-2 { gap: .5rem; }

/* --- Narrow screens: one pane at a time --- */
.thread-back {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    flex: 0 0 32px;
    margin-inline-end: .25rem;
    padding: 0;
    border: 1px solid var(--app-card-border);
    border-radius: 50%;
    background: var(--app-thead-bg);
    color: var(--app-ink);
}
.thread-back:hover { background: var(--app-hover); }

@media (max-width: 991.98px) {
    /* One pane fills the screen instead of two short boxes stacked. */
    .chat-list,
    .chat-thread {
        height: calc(100dvh - 190px);
        min-height: 320px;
    }
    .chat-fullscreen {
        position: fixed;
        top: var(--app-header-h, 64px);
        left: 0; right: 0; bottom: 0;
        z-index: 7;
        display: flex;
        flex-direction: column;
        margin: 0;
        padding: 0;
        background: var(--bs-body-bg);
    }
    .chat-fullscreen .page-head { display: none; }
    .chat-fullscreen .chat-wrap { flex: 1; min-height: 0; margin: 0; }
    .chat-fullscreen .chat-wrap > [class*="col-"] { height: 100%; padding: 0; margin-top: 0 !important; }
    .chat-fullscreen .chat-thread { height: 100%; min-height: 0; border-radius: 0; border-left: 0; border-right: 0; }
    .chat-fullscreen .thread-input { padding: .5rem .6rem; }
}
.chat-attach-menu { min-width: 180px; }
.chat-attach-menu .dropdown-item { display: flex; align-items: center; gap: .5rem; font-size: .85rem; }
</style>
