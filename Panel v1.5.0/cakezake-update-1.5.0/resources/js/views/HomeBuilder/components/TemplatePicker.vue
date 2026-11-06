<template>
    <div class="hb-tpl-overlay" @click.self="$emit('close')">
        <div class="hb-tpl-modal">
            <div class="hb-tpl-head">
                <div>
                    <h5 class="m-0">{{ __('section_templates') }}</h5>
                    <small class="text-muted">{{ __('click_template_to_add') }}</small>
                </div>
                <button type="button" class="btn btn-sm btn-light" @click="$emit('close')">
                    <X :size="16" />
                </button>
            </div>

            <div class="hb-tpl-tabs">
                <button type="button" class="btn btn-sm"
                    :class="tab === 'builtin' ? 'btn-primary' : 'btn-outline-primary'"
                    @click="tab = 'builtin'">
                    {{ __('built_in') }}
                </button>
                <button type="button" class="btn btn-sm"
                    :class="tab === 'mine' ? 'btn-primary' : 'btn-outline-primary'"
                    @click="tab = 'mine'">
                    {{ __('my_templates') }}
                    <span class="badge ms-1" :class="tab === 'mine' ? 'hb-tab-count-active' : 'bg-light text-dark'">{{ customTemplates.length }}</span>
                </button>
            </div>

            <div class="hb-tpl-body">
                <div v-if="loading" class="text-center py-4">
                    <b-spinner small></b-spinner>
                </div>

                <div v-else-if="tab === 'builtin'" class="hb-tpl-grid">
                    <button v-for="t in BUILTIN_TEMPLATES" :key="t.id" type="button"
                        class="hb-tpl-card" @click="pickBuiltin(t)">
                        <div class="hb-tpl-icon"><component :is="t.icon" :size="22" /></div>
                        <div class="hb-tpl-name">{{ t.name }}</div>
                        <div class="hb-tpl-desc">{{ t.description }}</div>
                        <span class="hb-tpl-type">{{ __(t.section_type) }}</span>
                    </button>
                </div>

                <div v-else>
                    <div v-if="!customTemplates.length" class="text-center text-muted py-4">
                        <Bookmark :size="28" class="mb-2" />
                        {{ __('no_custom_templates_yet') }}
                    </div>
                    <div v-else class="hb-tpl-grid">
                        <div v-for="t in customTemplates" :key="t.id" class="hb-tpl-card-wrap">
                            <button type="button" class="hb-tpl-card" @click="pickCustom(t)">
                                <div class="hb-tpl-icon">
                                    <component :is="templateIcon(t)" :size="22" />
                                </div>
                                <div class="hb-tpl-name">{{ t.name }}</div>
                                <div class="hb-tpl-desc">{{ t.description || '' }}</div>
                                <span class="hb-tpl-type">{{ __(t.section_type) }}</span>
                            </button>
                            <button type="button" class="hb-tpl-del" :title="__('delete')"
                                @click.stop="confirmDelete(t)">
                                <Trash2 :size="14" />
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { BUILTIN_TEMPLATES, SECTION_TYPES, cloneAndReidSection } from '../homeBuilderHelpers.js';
import {
    X, Bookmark, Trash2, Images, LayoutGrid, Package, PanelTop, Tags, Grid3x3,
    Image as ImageIcon, Heading, Zap, Star, Award, Flame, Gift, Trophy,
} from 'lucide-vue-next';

export default {
    name: 'TemplatePicker',
    components: {
        X, Bookmark, Trash2, Images, LayoutGrid, Package, PanelTop, Tags, Grid3x3,
        ImageIcon, Heading, Zap, Star, Award, Flame, Gift, Trophy,
    },
    props: {
        defaultLang: { type: [Number, String], default: null },
    },
    emits: ['close', 'pick'],
    data() {
        return {
            BUILTIN_TEMPLATES,
            tab: 'builtin',
            customTemplates: [],
            loading: false,
        };
    },
    created() {
        this.load();
    },
    methods: {
        // Custom templates may branch no icon (or an old FA string) — derive the
        // lucide icon from the section type instead.
        templateIcon(t) {
            const st = SECTION_TYPES.find(x => x.value === t.section_type);
            return st ? st.icon : 'Bookmark';
        },
        load() {
            this.loading = true;
            axios.get(this.$apiUrl + '/home_layout_templates')
                .then(res => {
                    this.customTemplates = res.data?.data || [];
                })
                .catch(() => {})
                .finally(() => { this.loading = false; });
        },
        pickBuiltin(t) {
            const section = t.build(this.defaultLang);
            this.$emit('pick', section);
        },
        pickCustom(t) {
            // section_json may arrive as object or string per JSON cast
            let src = t.section_json;
            if (typeof src === 'string') {
                try { src = JSON.parse(src); } catch (e) { src = null; }
            }
            if (!src) {
                this.showError(__('something_went_wrong'));
                return;
            }
            this.$emit('pick', cloneAndReidSection(src));
        },
        confirmDelete(t) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('confirm_delete_template'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
                confirmButtonText: __('yes_delete'),
                cancelButtonText: __('cancel'),
            }).then(result => {
                if (!result.isConfirmed) return;
                const form = new FormData();
                form.append('id', t.id);
                axios.post(this.$apiUrl + '/home_layout_templates/delete', form)
                    .then(() => {
                        this.customTemplates = this.customTemplates.filter(x => x.id !== t.id);
                        this.showMessage('success', __('deleted_successfully'));
                    })
                    .catch(err => {
                        this.showError(err.response?.data?.message || __('something_went_wrong'));
                    });
            });
        },
    },
};
</script>

<style scoped>
/* Count on the active (primary) tab: white text on a translucent white chip. */
.hb-tab-count-active {
    background-color: rgba(255, 255, 255, .28) !important;
    color: var(--app-card-bg) !important;
}
.hb-tpl-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, .45);
    z-index: 1080;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
}
.hb-tpl-modal {
    background: var(--app-card-bg);
    border-radius: .75rem;
    width: 100%;
    max-width: 880px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 12px 30px rgba(0, 0, 0, .25);
}
.hb-tpl-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: .85rem 1rem;
    border-bottom: 1px solid #eee;
}
.hb-tpl-tabs {
    display: flex;
    gap: .35rem;
    padding: .65rem 1rem 0;
}
.hb-tpl-body {
    overflow-y: auto;
    padding: 1rem;
}
.hb-tpl-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: .65rem;
}
.hb-tpl-card-wrap {
    position: relative;
}
.hb-tpl-card {
    width: 100%;
    text-align: left;
    background: var(--app-card-bg);
    border: 1px solid var(--app-card-border);
    border-radius: .55rem;
    padding: .75rem;
    cursor: pointer;
    transition: border-color .15s, transform .1s;
    display: flex;
    flex-direction: column;
    gap: .25rem;
}
.hb-tpl-card:hover {
    border-color: var(--bs-primary);
    transform: translateY(-1px);
}
.hb-tpl-icon {
    width: 36px;
    height: 36px;
    border-radius: .45rem;
    background: rgba(var(--bs-primary-rgb), .12);
    color: var(--bs-primary);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1rem;
    margin-bottom: .25rem;
}
.hb-tpl-name {
    font-weight: 600;
    font-size: .85rem;
}
.hb-tpl-desc {
    font-size: .7rem;
    color: var(--app-muted);
    line-height: 1.25;
}
.hb-tpl-type {
    font-size: .65rem;
    color: #adb5bd;
    margin-top: .2rem;
    text-transform: uppercase;
    letter-spacing: .03em;
}
.hb-tpl-del {
    position: absolute;
    top: .35rem;
    right: .35rem;
    width: 26px;
    height: 26px;
    border-radius: 50%;
    border: 0;
    background: rgba(255, 255, 255, .9);
    color: #d33;
    font-size: .7rem;
    cursor: pointer;
    box-shadow: 0 1px 3px rgba(0, 0, 0, .15);
    opacity: 0;
    transition: opacity .15s;
}
.hb-tpl-card-wrap:hover .hb-tpl-del {
    opacity: 1;
}
</style>
