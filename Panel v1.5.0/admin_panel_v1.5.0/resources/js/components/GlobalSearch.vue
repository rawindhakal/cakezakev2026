<template>
    <teleport to="body">
        <div v-if="open" class="gs-backdrop" @mousedown.self="close">
            <div class="gs-panel" role="dialog" aria-modal="true">
                <div class="gs-input-row">
                    <Search :size="18" class="gs-input-icon" />
                    <input ref="input" v-model="query" type="text" class="gs-input"
                        :placeholder="__('search_everything_placeholder')"
                        @keydown.down.prevent="move(1)"
                        @keydown.up.prevent="move(-1)"
                        @keydown.enter.prevent="go(flat[cursor])"
                        @keydown.esc.prevent="close" />
                    <kbd class="gs-kbd">esc</kbd>
                </div>

                <div ref="list" class="gs-results">
                    <template v-for="section in sections" :key="section.title">
                        <div class="gs-section">{{ section.title }}</div>
                        <button v-for="item in section.items" :key="item.type + item.to + item.title"
                            type="button" class="gs-item"
                            :class="{ 'is-active': flat[cursor] === item }"
                            @mousemove="cursor = flat.indexOf(item)"
                            @click="go(item)">
                            <span class="gs-item-icon">
                                <component :is="item.icon || defaultIcon(item)" :size="16" />
                            </span>
                            <span class="gs-item-body">
                                <span class="gs-item-title">{{ item.title }}</span>
                                <span class="gs-item-sub">{{ item.group }}{{ item.desc ? ' — ' + item.desc : '' }}</span>
                            </span>
                            <ArrowRight :size="14" class="gs-item-go" />
                        </button>
                    </template>

                    <div v-if="!flat.length" class="gs-empty">
                        {{ __('no_records_found') }}
                    </div>
                </div>

                <div class="gs-foot">
                    <span><kbd class="gs-kbd">↑</kbd><kbd class="gs-kbd">↓</kbd> {{ __('navigate') }}</span>
                    <span><kbd class="gs-kbd">↵</kbd> {{ __('open') }}</span>
                    <span class="ms-auto">{{ shortcutLabel }}</span>
                </div>
            </div>
        </div>
    </teleport>
</template>

<script>
import { ArrowRight, Compass, Search, Settings2, Zap } from 'lucide-vue-next';
import { menuEntries, settingsEntries, actionEntries } from '../utils/searchCatalog';

/** How many results a section shows before the rest are dropped. */
const SECTION_LIMIT = 6;

export default {
    name: 'GlobalSearch',
    components: { ArrowRight, Search },
    props: {
        // The sidebar tree, so the menu is defined in one place only.
        menu: { type: Array, default: () => [] },
    },
    data() {
        return {
            open: false,
            query: '',
            cursor: 0,
        };
    },
    computed: {
        shortcutLabel() {
            return (navigator.platform || '').toLowerCase().includes('mac') ? '⌘K' : 'Ctrl K';
        },
        /** Everything searchable, minus whatever this admin may not open. */
        entries() {
            const allowed = (e) => {
                if (e.role) return this.$role('Super Admin');
                return !e.permission || this.$can(e.permission);
            };

            return [
                ...menuEntries(this.menu),
                ...settingsEntries(),
                ...actionEntries(),
            ].filter(e => e.to && allowed(e));
        },
        /**
         * Ranked matches. A title hit outranks a group hit, which outranks a keyword
         * hit, so typing "invoice" offers the Invoice Settings page before the pages
         * that merely mention invoices.
         */
        matches() {
            const q = this.query.trim().toLowerCase();
            if (!q) {
                // Nothing typed: show the shortcuts people use most.
                return this.entries.filter(e => e.type === 'action').slice(0, 8);
            }

            const words = q.split(/\s+/).filter(Boolean);
            const scored = [];

            this.entries.forEach(e => {
                const title = (e.title || '').toLowerCase();
                const group = (e.group || '').toLowerCase();
                const rest = ((e.desc || '') + ' ' + (e.keywords || '')).toLowerCase();
                let score = 0;

                for (const w of words) {
                    if (title.startsWith(w)) score += 100;
                    else if (new RegExp('\\b' + w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).test(title)) score += 70;
                    else if (title.includes(w)) score += 50;
                    else if (group.includes(w)) score += 20;
                    else if (rest.includes(w)) score += 12;
                    else return; // every word has to land somewhere
                }

                // Shorter titles are the more precise answer for the same score.
                scored.push({ e, score: score - title.length * 0.1 });
            });

            return scored.sort((a, b) => b.score - a.score).map(s => s.e);
        },
        sections() {
            const order = [
                { type: 'menu', title: __('menu') },
                { type: 'setting', title: __('settings') },
                { type: 'action', title: __('actions') },
            ];

            return order
                .map(s => ({ title: s.title, items: this.matches.filter(m => m.type === s.type).slice(0, SECTION_LIMIT) }))
                .filter(s => s.items.length);
        },
        /** The sections flattened, which is what the arrow keys walk. */
        flat() {
            return this.sections.flatMap(s => s.items);
        },
    },
    watch: {
        matches() {
            this.cursor = 0;
        },
    },
    mounted() {
        window.addEventListener('keydown', this.onKeydown);
    },
    beforeUnmount() {
        window.removeEventListener('keydown', this.onKeydown);
    },
    methods: {
        defaultIcon(item) {
            if (item.type === 'setting') return Settings2;
            if (item.type === 'action') return Zap;
            return Compass;
        },
        onKeydown(e) {
            const key = (e.key || '').toLowerCase();
            if ((e.metaKey || e.ctrlKey) && key === 'k') {
                e.preventDefault();
                this.open ? this.close() : this.show();
            }
        },
        show() {
            this.open = true;
            this.query = '';
            this.cursor = 0;
            this.$nextTick(() => this.$refs.input && this.$refs.input.focus());
        },
        close() {
            this.open = false;
        },
        move(step) {
            if (!this.flat.length) return;
            this.cursor = (this.cursor + step + this.flat.length) % this.flat.length;
            this.$nextTick(() => {
                const el = this.$refs.list && this.$refs.list.querySelector('.gs-item.is-active');
                if (el) el.scrollIntoView({ block: 'nearest' });
            });
        },
        go(item) {
            if (!item) return;
            this.close();
            if (this.$route.fullPath !== item.to) this.$router.push(item.to);
        },
    },
};
</script>

<style scoped>
.gs-backdrop {
    position: fixed;
    inset: 0;
    z-index: 1090; /* over the header (20) and the sidebar drawer (22) */
    background: rgba(16, 24, 40, .45);
    display: flex;
    justify-content: center;
    align-items: flex-start;
    padding: 8vh 1rem 1rem;
}
.gs-panel {
    width: min(640px, 100%);
    background: var(--app-card-bg, #fff);
    border: 1px solid var(--app-card-border);
    border-radius: .9rem;
    box-shadow: 0 24px 60px rgba(16, 24, 40, .28);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    max-height: 70vh;
}
.gs-input-row {
    display: flex;
    align-items: center;
    gap: .6rem;
    padding: .8rem 1rem;
    border-bottom: 1px solid var(--app-border);
}
.gs-input-icon { color: var(--app-muted); flex-shrink: 0; }
.gs-input {
    flex: 1;
    border: 0;
    outline: none;
    background: transparent;
    font-size: .95rem;
    color: var(--app-ink);
}
.gs-results { overflow-y: auto; padding: .35rem 0 .5rem; }
.gs-section {
    font-size: .68rem;
    font-weight: 700;
    letter-spacing: .06em;
    text-transform: uppercase;
    color: var(--app-muted);
    padding: .6rem 1rem .25rem;
}
.gs-item {
    width: 100%;
    display: flex;
    align-items: center;
    gap: .65rem;
    padding: .5rem 1rem;
    border: 0;
    background: transparent;
    text-align: start;
    color: var(--app-ink);
}
.gs-item.is-active { background: rgba(var(--bs-primary-rgb), .1); }
.gs-item-icon {
    display: inline-flex;
    width: 28px;
    height: 28px;
    align-items: center;
    justify-content: center;
    border-radius: .5rem;
    background: var(--app-thead-bg);
    color: var(--bs-primary);
    flex-shrink: 0;
}
.gs-item-body { min-width: 0; display: flex; flex-direction: column; }
.gs-item-title { font-size: .875rem; font-weight: 600; }
.gs-item-sub {
    font-size: .74rem;
    color: var(--app-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.gs-item-go { margin-inline-start: auto; color: var(--app-muted); opacity: 0; flex-shrink: 0; }
.gs-item.is-active .gs-item-go { opacity: 1; }
.gs-empty { padding: 2rem 1rem; text-align: center; color: var(--app-muted); font-size: .85rem; }
.gs-foot {
    display: flex;
    align-items: center;
    gap: .9rem;
    padding: .5rem 1rem;
    border-top: 1px solid var(--app-border);
    font-size: .72rem;
    color: var(--app-muted);
}
.gs-kbd {
    background: var(--app-thead-bg);
    border: 1px solid var(--app-border);
    border-radius: .3rem;
    padding: 0 .3rem;
    font-size: .68rem;
    color: var(--app-muted);
    margin-inline-end: .15rem;
}
@media (max-width: 575.98px) {
    .gs-backdrop { padding: 4vh .6rem .6rem; }
    .gs-panel { max-height: 84vh; }
}
</style>
