<template>
    <button type="button" class="hb-stc" @click="$emit('pick', type)">
        <!-- Wireframe: what the section actually lays out, drawn in plain boxes so the
             shape reads at a glance without loading any real content. -->
        <div class="hb-stc-wire">
            <template v-if="type === 'banner_slider'">
                <div class="w-bar tall"></div>
                <div class="w-dots"><i class="on"></i><i></i><i></i></div>
            </template>

            <template v-else-if="type === 'category_section' || type === 'occasion_section' || type === 'relationship_section'">
                <div class="w-row">
                    <div class="w-item" v-for="i in 4" :key="i">
                        <div class="w-circle"></div><div class="w-line short"></div>
                    </div>
                </div>
            </template>

            <template v-else-if="type === 'product_slider'">
                <div class="w-row">
                    <div class="w-card" v-for="i in 3" :key="i">
                        <div class="w-thumb"></div>
                        <div class="w-line"></div>
                        <div class="w-line short"></div>
                    </div>
                </div>
            </template>

            <template v-else-if="type === 'product_tabs'">
                <div class="w-row w-tabs">
                    <div class="w-item" v-for="i in 4" :key="'t' + i">
                        <div class="w-square small"></div>
                        <div class="w-line short"></div>
                    </div>
                </div>
                <div class="w-row">
                    <div class="w-card" v-for="i in 3" :key="i">
                        <div class="w-thumb"></div>
                        <div class="w-line"></div>
                        <div class="w-line short"></div>
                    </div>
                </div>
            </template>

            <template v-else-if="type === 'brand_section'">
                <div class="w-row">
                    <div class="w-item" v-for="i in 4" :key="i"><div class="w-square"></div></div>
                </div>
            </template>

            <template v-else-if="type === 'grid_banner'">
                <div class="w-grid">
                    <div class="w-tile" v-for="i in 4" :key="i"></div>
                </div>
            </template>

            <template v-else-if="type === 'title_image'">
                <div class="w-bar"></div>
            </template>

            <template v-else-if="type === 'text_section'">
                <div class="w-text">
                    <div class="w-line heading"></div>
                    <div class="w-line"></div>
                    <div class="w-line short"></div>
                </div>
            </template>
        </div>

        <div class="hb-stc-meta">
            <span class="hb-stc-name">
                <component :is="icon" :size="14" /> {{ __(type) }}
            </span>
            <small class="hb-stc-hint">{{ hint }}</small>
        </div>
    </button>
</template>

<script>
import {
    Images, LayoutGrid, Package, PanelTop, Tags, Grid3x3, Image as ImageIcon, Heading, PartyPopper, Heart,
} from 'lucide-vue-next';

// One line each, in plain words: what the client gets, not what the field is called.
const HINTS = {
    banner_slider: 'banner_slider_hint',
    category_section: 'category_section_hint',
    product_slider: 'product_slider_hint',
    product_tabs: 'product_tabs_hint',
    brand_section: 'brand_section_hint',
    occasion_section: 'occasion_section_hint',
    relationship_section: 'relationship_section_hint',
    grid_banner: 'grid_banner_hint',
    title_image: 'title_image_hint',
    text_section: 'text_section_hint',
};

export default {
    name: 'SectionTypeCard',
    components: { Images, LayoutGrid, Package, PanelTop, Tags, Grid3x3, ImageIcon, Heading, PartyPopper, Heart },
    props: {
        type: { type: String, required: true },
        icon: { type: String, default: 'Images' },
    },
    emits: ['pick'],
    computed: {
        hint() { return __(HINTS[this.type] || ''); },
    },
};
</script>

<style scoped>
.hb-stc {
    width: 100%; text-align: left; padding: 0; overflow: hidden;
    border: 1px solid var(--app-card-border); border-radius: .55rem;
    background: var(--app-card-bg); cursor: pointer;
    transition: border-color .12s, box-shadow .12s;
}
.hb-stc:hover { border-color: var(--bs-primary); box-shadow: 0 2px 10px rgba(0, 0, 0, .08); }

.hb-stc-wire {
    height: 76px; padding: 10px; background: var(--app-thead-bg);
    border-bottom: 1px solid var(--app-card-border);
    display: flex; flex-direction: column; justify-content: center; gap: 5px;
}
.hb-stc-meta { padding: .45rem .6rem .55rem; display: block; }
.hb-stc-name { font-size: .78rem; font-weight: 600; display: flex; align-items: center; gap: 5px; color: var(--app-ink); }
.hb-stc-hint { display: block; font-size: .66rem; color: var(--app-muted); line-height: 1.35; margin-top: 2px; }

/* Wireframe parts. Primary tint marks the "content", grey marks labels. */
.w-bar { background: rgba(var(--bs-primary-rgb), .35); border-radius: 4px; height: 30px; }
.w-bar.tall { height: 38px; }
.w-dots { display: flex; gap: 4px; justify-content: center; }
.w-dots i { width: 5px; height: 5px; border-radius: 50%; background: var(--app-card-border); }
.w-dots i.on { background: rgba(var(--bs-primary-rgb), .6); width: 10px; border-radius: 3px; }

.w-row { display: flex; gap: 6px; }
.w-item { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 4px; }
.w-circle { width: 24px; height: 24px; border-radius: 50%; background: rgba(var(--bs-primary-rgb), .35); }
.w-square { width: 26px; height: 26px; border-radius: 5px; background: rgba(var(--bs-primary-rgb), .35); }
.w-square.small { width: 16px; height: 16px; }
.w-tabs { margin-bottom: 4px; }

.w-card { flex: 1; display: flex; flex-direction: column; gap: 3px; }
.w-thumb { height: 26px; border-radius: 4px; background: rgba(var(--bs-primary-rgb), .35); }

.w-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 5px; }
.w-tile { height: 22px; border-radius: 4px; background: rgba(var(--bs-primary-rgb), .35); }

.w-text { display: flex; flex-direction: column; gap: 5px; }
.w-line { height: 5px; border-radius: 3px; background: var(--app-card-border); }
.w-line.short { width: 60%; }
.w-line.heading { height: 9px; width: 75%; background: rgba(var(--bs-primary-rgb), .45); }
</style>
