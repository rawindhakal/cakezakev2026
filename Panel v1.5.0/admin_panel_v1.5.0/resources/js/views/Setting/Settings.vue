<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('settings') }}</h3>
            <!-- Twenty-odd cards: typing is faster than scanning. -->
            <div class="list-search ms-auto">
                <Search class="list-search-icon" />
                <input type="search" v-model="search" class="form-control"
                    :placeholder="__('search_settings_placeholder')" />
            </div>
        </div>

        <!-- Grouped card grid: each card is one settings area. -->
        <template v-for="group in visibleGroups" :key="group.title">
            <div class="set-group-title">{{ group.title }}</div>
            <div class="card-grid set-grid">
                <router-link v-for="item in group.items" :key="item.title" :to="item.to" class="set-card">
                    <span class="set-card-icon" :class="'tone-' + item.tone">
                        <component :is="item.icon" :size="24" />
                    </span>
                    <div class="set-card-meta">
                        <div class="set-card-title">{{ item.title }}</div>
                        <div class="set-card-desc">{{ item.desc }}</div>
                    </div>
                    <div class="set-card-foot">{{ __('go_to_settings') }} <ArrowRight :size="15" /></div>
                </router-link>
            </div>
        </template>

        <div v-if="!visibleGroups.length" class="text-center text-muted py-5">
            {{ __('no_records_found') }}
        </div>
    </div>
</template>

<script>
import { ChevronRight, ArrowRight, Search } from 'lucide-vue-next';
// One definition of the hub, shared with the global search palette.
import { settingsGroups } from '../../utils/settingsCatalog';

export default {
    name: 'Settings',
    components: { ChevronRight, ArrowRight, Search },
    data() {
        return {
            search: '',
        };
    },
    computed: {
        // Only render a group if at least one card survived the permission filter and
        // the search box. Matching is on the card's own title and description, plus the
        // group name, so "mail" finds the SMTP card under Communication.
        visibleGroups() {
            const q = this.search.trim().toLowerCase();
            const hit = (item, groupTitle) => !q
                || [item.title, item.desc, groupTitle, item.keywords]
                    .some(t => (t || '').toLowerCase().includes(q));

            return this.groups
                .map(g => ({
                    ...g,
                    items: g.items.filter(i => (!i.permission || this.$can(i.permission)) && hit(i, g.title)),
                }))
                .filter(g => g.items.length);
        },
        groups() {
            return settingsGroups();
        },
    },
};
</script>

<style scoped>
.set-group-title {
    font-size: .72rem;
    font-weight: 700;
    letter-spacing: .06em;
    text-transform: uppercase;
    color: var(--app-muted);
    margin: 1.25rem 0 .6rem;
}
.set-group-title:first-of-type { margin-top: 0; }

/* Fixed column counts rather than auto-fill: the tiles are square, so the count
   per row has to be predictable at each breakpoint. */
.set-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 0.85rem;
}
@media (min-width: 768px) {
    .set-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
@media (min-width: 1200px) {
    .set-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); }
}

.set-card {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: .5rem;
    aspect-ratio: 2 / 1;
    padding: 1rem;
    border: 1px solid var(--app-card-border);
    border-radius: 12px;
    background: var(--app-card-bg);
    text-decoration: none;
    transition: border-color .18s var(--app-ease), box-shadow .18s var(--app-ease), transform .18s var(--app-ease);
}
.set-card:hover {
    border-color: rgba(var(--bs-primary-rgb), .35);
    box-shadow: 0 6px 20px rgba(16, 24, 40, .1);
    transform: translateY(-2px);
}
.set-card-icon {
    width: 54px;
    height: 54px;
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 11px;
    background: rgba(var(--bs-primary-rgb), .1);
    color: var(--bs-primary);
}
.set-card-icon.tone-green { background: rgba(22, 163, 74, .12); color: #16a34a; }
.set-card-icon.tone-amber { background: rgba(245, 158, 11, .14); color: #d97706; }
.set-card-icon.tone-violet { background: rgba(124, 58, 237, .12); color: #7c3aed; }
.set-card-icon.tone-cyan { background: rgba(6, 182, 212, .12); color: #0891b2; }
.set-card-icon.tone-slate { background: rgba(100, 116, 139, .14); color: #64748b; }
.set-card-icon.tone-teal { background: rgba(13, 148, 136, .12); color: #0d9488; }

.set-card-meta { min-width: 0; width: 100%; margin-top: auto; }
.set-card-desc {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
}
.set-card-title {
    font-size: .9rem;
    font-weight: 600;
    color: var(--app-ink);
    line-height: 1.3;
}
.set-card-desc {
    font-size: .75rem;
    color: var(--app-muted);
    line-height: 1.35;
    margin-top: 2px;
}
.set-card-foot {
    display: inline-flex;
    align-items: center;
    gap: .35rem;
    margin-top: .5rem;
    font-size: .8rem;
    font-weight: 600;
    color: var(--bs-primary);
}
.set-card-foot svg { transition: transform .15s var(--app-ease); }
.set-card:hover .set-card-foot svg { transform: translateX(3px); }

/* Phone: the title and a 220px box do not share one row — give search its own. */
@media (max-width: 575.98px) {
    .page-head { flex-wrap: wrap; row-gap: .5rem; }
    .page-head .list-search { width: 100%; margin-inline-start: 0 !important; }
    .page-head .list-search .form-control { width: 100%; }
}
</style>
