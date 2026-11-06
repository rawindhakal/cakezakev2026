<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('faqs_list') }}</h3>

            <button
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="create_new = true"
                v-if="$can('faq_create')">
                <Plus :size="16" />
                <span>{{ __('add') }}</span>
            </button>
        </div>

        <div class="list-surface">
            <div class="list-toolbar">
                <div class="list-search">
                    <Search class="list-search-icon" />
                    <input
                        id="filter-input"
                        v-model="filter"
                        type="search"
                        class="form-control"
                        :placeholder="__('search')">
                </div>

                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getFaqs()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>

            <!-- Sortable list: the order here is the order the app shows. Dragging is
                 off while a search filter is active — a partial list can't be reordered. -->
            <div class="faq-list" v-if="!isLoading && visibleFaqs.length">
                <draggable v-model="faqs" item-key="id" handle=".faq-grip" :disabled="!canDrag"
                    ghost-class="faq-ghost" @end="saveOrder">
                    <template #item="{ element: faq, index }">
                        <div class="faq-row" v-show="matchesFilter(faq)">
                            <span class="faq-grip" :class="{ 'is-off': !canDrag }"
                                v-b-tooltip.hover :title="canDrag ? __('drag_to_reorder') : __('clear_search_to_reorder')">
                                <GripVertical :size="16" />
                            </span>
                            <span class="faq-no">{{ index + 1 }}</span>
                            <div class="faq-body">
                                <div class="faq-q">{{ displayFaq(faq).question }}</div>
                                <div class="faq-answer">
                                    <p class="mb-0" v-if="!shouldTruncate(displayFaq(faq).answer) || expandedFaqs[faq.id]">
                                        {{ displayFaq(faq).answer }}
                                    </p>
                                    <p class="mb-0" v-else>{{ getTruncatedText(displayFaq(faq).answer) }}</p>
                                    <a v-if="shouldTruncate(displayFaq(faq).answer)" @click="toggleFaqExpansion(faq.id)"
                                        href="javascript:void(0)" class="faq-more">
                                        {{ expandedFaqs[faq.id] ? __('view_less') : __('view_more') }}
                                    </a>
                                </div>
                            </div>
                            <div class="list-actions">
                                <button class="list-action-btn is-edit" @click="edit_record = faq"
                                    v-b-tooltip.hover :title="__('edit')" v-if="$can('faq_update')">
                                    <Pencil :size="15" />
                                </button>
                                <button class="list-action-btn is-delete" @click="deleteSocialMedia(index, faq.id)"
                                    v-b-tooltip.hover :title="__('delete')" v-if="$can('faq_delete')">
                                    <Trash2 :size="15" />
                                </button>
                            </div>
                        </div>
                    </template>
                </draggable>
                <p v-if="!visibleFaqs.length" class="text-muted text-center py-4 mb-0">{{ __('no_records_found') }}</p>
            </div>
            <div v-else-if="isLoading" class="text-center py-5"><b-spinner small></b-spinner></div>
            <p v-else class="text-muted text-center py-5 mb-0">{{ __('no_records_found') }}</p>
        </div>

        <!-- Add / Edit -->
        <app-edit-record v-if="create_new || edit_record" :record="edit_record"
            @saved="onFaqSaved" @modalClose="hideModal()"></app-edit-record>
    </div>
</template>
<script>
import EditRecord from './Edit.vue';
import axios from "axios";
import draggable from 'vuedraggable';
import { Search, RefreshCw, Plus, Pencil, Trash2, GripVertical } from 'lucide-vue-next';

export default {
    components: {
        'app-edit-record': EditRecord,
        draggable, Search, RefreshCw, Plus, Pencil, Trash2, GripVertical,
    },
    data: function () {
        return {
            filter: '',
            savingOrder: false,

            isLoading: false,
            sectionStyle: 'style_1',
            max_visible_units: 12,
            max_col_in_single_row: 3,
            create_new: null,
            edit_record: null,
            faqs: [],
            expandedFaqs: {}, // Track which FAQs are expanded
            maxLength: 200, // Maximum characters to show before truncation
            currentLanguageId: null,
            activeLanguages: [],

        }
    },
    computed: {
        canDrag() { return !this.savingOrder && !(this.filter || '').trim() && this.$can('faq_update'); },
        visibleFaqs() { return this.faqs.filter(f => this.matchesFilter(f)); },
    },
    created() {
        this.fetchActiveLanguages().then(() => {
            this.getFaqs();
        });
    },
    methods: {
        fetchActiveLanguages() {
            return axios.get(this.$apiUrl + '/active_languages')
                .then(response => {
                    if (response.data.data && Array.isArray(response.data.data)) {
                        this.activeLanguages = response.data.data;

                        const appLocale = window.appLocale || 'en';

                        const currentLanguage = this.activeLanguages.find(
                            lang => lang.code === appLocale
                        );

                        if (currentLanguage) {
                            this.currentLanguageId = currentLanguage.id;
                        } else {
                            const defaultLanguage = this.activeLanguages.find(
                                lang => lang.is_default === 1
                            );
                            if (defaultLanguage) {
                                this.currentLanguageId = defaultLanguage.id;
                            }
                        }
                    }
                })
                .catch(error => {
                    console.error('Error loading languages:', error);
                });
        },
        // Question/answer in the panel language, falling back to the default text.
        displayFaq(faq) {
            if (!this.currentLanguageId || !Array.isArray(faq.translations)) return faq;
            const t = faq.translations.find(x => x.language_id === this.currentLanguageId);
            if (!t) return faq;
            return {
                ...faq,
                question: (t.question && t.question.trim()) ? t.question : faq.question,
                answer: (t.answer && t.answer.trim()) ? t.answer : faq.answer,
            };
        },
        matchesFilter(faq) {
            const q = (this.filter || '').trim().toLowerCase();
            if (!q) return true;
            const d = this.displayFaq(faq);
            return String(d.question || '').toLowerCase().includes(q) || String(d.answer || '').toLowerCase().includes(q);
        },
        getFaqs() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/faqs')
                .then(response => {
                    const data = response.data || {};
                    this.faqs = Array.isArray(data.data) ? data.data : [];
                    this.isLoading = false;
                })
                .catch(() => {
                    this.faqs = [];
                    this.isLoading = false;
                });
        },
        // Persist the dragged order: ids top-to-bottom become sort_order 1..n.
        saveOrder() {
            const ids = this.faqs.map(f => f.id);
            this.savingOrder = true;
            axios.post(this.$apiUrl + '/faqs/update_order', { ids })
                .then(res => {
                    if (res.data.status === 1) this.showMessage('success', res.data.message);
                    else { this.showError(res.data.message); this.getFaqs(); }
                })
                .catch(() => { this.showError(__('something_went_wrong')); this.getFaqs(); })
                .finally(() => { this.savingOrder = false; });
        },

        deleteSocialMedia(index, id) {
            this.$swal.fire({
                title: __('are_you_sure'),
                text: __('you_want_be_able_to_revert_this'),
                confirmButtonText: __('yes_sure'),
                cancelButtonText: __('cancel'),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: window.adminThemeColor || '#435ebe',
                cancelButtonColor: '#d33',
            }).then(result => {

                if (result.value) {
                    this.isLoading = true
                    let postData = {
                        id: id
                    }
                    axios.post(this.$apiUrl + '/faqs/delete', postData)
                        .then((response) => {
                            this.isLoading = false
                            this.faqs.splice(index, 1)
                            //this.showSuccess(response.data.message)
                            this.showMessage("success", response.data.message);
                        });
                }
            });
        },
        hideModal() {
            this.create_new = false
            this.edit_record = false
        },
        // Component emit (not the global bus) — fires exactly once per save, so
        // the success toast can't double up when the page is revisited.
        onFaqSaved(message) {
            this.showMessage('success', message);
            this.getFaqs();
            this.hideModal();
        },
        // Toggle FAQ expansion state
        toggleFaqExpansion(faqId) {
            this.expandedFaqs[faqId] = !this.expandedFaqs[faqId];
        },
        // Check if FAQ answer should be truncated
        shouldTruncate(answer) {
            return answer && answer.length > this.maxLength;
        },
        // Get truncated text for display
        getTruncatedText(answer) {
            if (!answer) return '';
            return answer.length > this.maxLength ? answer.substring(0, this.maxLength) + '...' : answer;
        },
    }
};
</script>
<style scoped>
.faq-list { padding: .5rem .75rem .75rem; }
.faq-row {
    display: flex; align-items: flex-start; gap: .6rem;
    padding: .7rem .5rem; border-bottom: 1px solid var(--app-card-border); background: var(--app-card-bg);
}
.faq-row:last-child { border-bottom: 0; }
.faq-grip { color: var(--app-muted); cursor: grab; padding-top: 2px; flex-shrink: 0; }
.faq-grip.is-off { cursor: not-allowed; opacity: .4; }
.faq-no { width: 26px; flex-shrink: 0; font-size: .78rem; color: var(--app-muted); padding-top: 3px; text-align: center; }
.faq-body { flex: 1; min-width: 0; }
.faq-q { font-weight: 600; color: var(--app-ink); }
.faq-answer { font-size: .85rem; color: var(--app-muted); margin-top: .2rem; white-space: pre-line; }
.faq-more { font-size: 12px; cursor: pointer; }
.faq-ghost { opacity: .4; background: rgba(var(--bs-primary-rgb), .08); }
.sortable-chosen { box-shadow: 0 6px 18px rgba(0,0,0,.08); }
</style>
