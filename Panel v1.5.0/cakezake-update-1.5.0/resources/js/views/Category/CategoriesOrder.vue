<template>
    <div class="list-page">
        <!-- Title outside the card; the sortable list stays inside it. -->
        <div class="page-head">
            <h3 class="page-head-title">{{ __('main_categories_order_list') }}</h3>
        </div>

        <div class="card">
                        <div class="card-body">
                            <b-row>
                                <b-col md="12">
                                    <div class="mb-2 d-flex justify-content-between align-items-center gap-2 flex-wrap">
                                        <div class="form-check form-switch cat-order-switch">
                                            <label class="form-check-label" for="cat-order-dnd">{{ __('enable_drag_and_drop') }}</label>
                                            <input id="cat-order-dnd" type="checkbox" role="switch"
                                                v-model="editable" class="form-check-input">
                                        </div>
                                        <!-- Narrow the list to one parent's children so a subtree can be
                                             reordered without scrolling past every other category. -->
                                        <div class="d-flex align-items-center gap-2">
                                            <label class="small text-muted mb-0 cat-order-filter-label">{{ __('select_category') }}</label>
                                            <AppSelect class="form-select cat-order-filter" v-model="parentFilter"
                                                :options="parentOptions" :searchable="parentOptions.length > 6"
                                                :allow-empty="false" :placeholder="__('all_categories')" />
                                        </div>
                                    </div>
                                </b-col>
                            </b-row>
                            <b-row>
                                <b-col md="12" style="overflow-y:scroll; overflow-x:auto; height:600px;">
                                    <ul ref="sortableList" class="list-group">
                                        <li v-for="category in visibleList" :key="category.id" :data-id="category.id"
                                            class="list-group-item d-flex justify-content-between align-items-center">
                                            <span>
                                                <span class="text-left mr-2">{{ category.row_order }}</span>
                                                <span class="text-left mr-2">-</span>
                                                <span class="text-left mr-2">{{ category.id }}</span>
                                                <span class="text-left mr-2"><img :src="category.image_url"
                                                        height="30"></span>
                                                <span class="text-left mr-2">{{ getCategoryName(category) }}</span>
                                                <span v-if="category.all_parents" class="ml-4 all_parents">
                                                    <span class="ml-4"
                                                        v-for="(parent, index) in getParentsList(category.all_parents)"
                                                        :key="index">
                                                        <span class="d-inline-flex align-items-center">
                                                            <ChevronLeft :size="14" class="me-1 text-muted" />
                                                            <span class="text-left"><img :src="parent.image_url"
                                                                    height="20"
                                                                    :title="parent.id + '-' + getCategoryName(parent)"></span>
                                                        </span>
                                                    </span>
                                                </span>
                                            </span>
                                            <span class="cat-order-grip"><Move :size="16" /></span>
                                        </li>
                                    </ul>
                                    <p v-if="!visibleList.length" class="text-muted text-center py-4 mb-0">
                                        {{ __('no_records_found') }}
                                    </p>
                                </b-col>
                            </b-row>
                        </div>
        </div>
    </div>
</template>
<script>
import Sortable from 'sortablejs';
import axios from "axios";
import { ChevronLeft, Move } from 'lucide-vue-next';
export default {
    components: { ChevronLeft, Move },
    data: function () {
        return {
            categories: [],
            list: [],
            // '' = every category (the original flat list); otherwise a parent id,
            // narrowing the list to that parent's direct children.
            parentFilter: '',
            editable: true,
            isLoading: false,
            currentLanguageId: null,
            activeLanguages: [],
            sortableInstance: null,
        }
    },
    computed: {
        // Only parents worth picking: a category with no children has nothing to reorder.
        parentOptions() {
            const withChildren = new Set(
                this.list.map(c => Number(c.parent_id) || 0).filter(Boolean)
            );
            const opts = this.list
                .filter(c => withChildren.has(Number(c.id)))
                .map(c => ({ id: c.id, name: this.getCategoryName(c) }))
                .sort((a, b) => String(a.name).localeCompare(String(b.name)));
            return [{ id: '', name: __('all_categories') }].concat(opts);
        },
        visibleList() {
            if (this.parentFilter === '' || this.parentFilter === null) return this.list;
            return this.list.filter(c => Number(c.parent_id) === Number(this.parentFilter));
        },
    },
    watch: {
        editable(val) {
            if (this.sortableInstance) {
                this.sortableInstance.option('disabled', !val);
            }
        },
    },
    created: function () {
        this.$eventBus.on('categorySaved', () => {
            this.getCategories();
        });
        this.fetchActiveLanguages().then(() => {
            this.getCategories();
        });
    },
    mounted() {
        this.$nextTick(() => {
            this.initSortable();
        });
    },
    beforeUnmount() {
        if (this.sortableInstance) {
            this.sortableInstance.destroy();
        }
    },
    methods: {
        initSortable() {
            if (!this.$refs.sortableList) return;
            this.sortableInstance = Sortable.create(this.$refs.sortableList, {
                animation: 200,
                ghostClass: 'ghost',
                disabled: !this.editable,
                onEnd: (evt) => {
                    // Indices are against the RENDERED list, which may be a filtered subset.
                    const view = this.visibleList.slice();
                    const moved = view.splice(evt.oldIndex, 1)[0];
                    view.splice(evt.newIndex, 0, moved);
                    this.applyViewOrder(view);
                },
            });
        },
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
        getCategoryName(category) {
            if (!category) return '';
            if (this.currentLanguageId && category.translations && Array.isArray(category.translations)) {
                const translation = category.translations.find(
                    t => t.language_id === this.currentLanguageId
                );
                if (translation && translation.name && translation.name.trim() !== '') {
                    return translation.name;
                }
            }
            return category.name || '';
        },
        getParentsList(parent) {
            let parents = [];
            while (parent) {
                parents.push(parent);
                parent = parent.all_parents;
            }
            return parents;
        },
        /**
         * Put the reordered view back into the master list. When filtered, the moved
         * rows only permute among the slots they already occupied, so every category
         * outside the filter keeps its position — and its row_order.
         */
        applyViewOrder(view) {
            if (this.parentFilter === '' || this.parentFilter === null) {
                this.list = view;
            } else {
                const slots = [];
                this.list.forEach((c, i) => {
                    if (Number(c.parent_id) === Number(this.parentFilter)) slots.push(i);
                });
                const next = this.list.slice();
                slots.forEach((position, k) => { next[position] = view[k]; });
                this.list = next;
            }
            this.updateCategoriesOrder();
        },
        updateList() {
            this.list.forEach((category, index) => {
                category.row_order = index + 1;
            });
        },
        getCategories() {
            axios.get(this.$apiUrl + '/categories/row_order')
                .then((response) => {
                    let data = response.data;
                    this.list = data.data.map((category) => {
                        return {
                            id: category.id,
                            name: category.name,
                            row_order: category.row_order,
                            image_url: category.image_url,
                            parent_id: category.parent_id,
                            all_parents: category.all_parents,
                            translations: category.translations,
                            fixed: false
                        };
                    });
                  
                    if (this.parentFilter !== '' && !this.list.some(c => Number(c.id) === Number(this.parentFilter))) {
                        this.parentFilter = '';
                    }
                });
        },
        updateCategoriesOrder() {
            this.updateList();
            this.isLoading = true;
            let formData = this.list;
            let url = this.$apiUrl + '/categories/updateOrder';
            axios.post(url, formData).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    this.showMessage("success", data.message);
                    this.isLoading = false;
                    this.getCategories();
                } else {
                    this.showError(data.message);
                    this.isLoading = false;
                }
            }).catch(error => {
                this.isLoading = false;
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError(__('something_went_wrong'));
                }
            });
        },
    }
};
</script>
<style scoped>
.ghost {
    opacity: 0.5;
    background: #c8ebfb;
}

.list-group {
    min-height: 20px;
}

.list-group-item {
    cursor: move;
}

.list-group-item i {
    cursor: pointer;
}

.cat-order-switch {
    display: flex;
    align-items: center;
    gap: .5rem;
    padding-left: 0;
    min-height: auto;
}

.cat-order-switch .form-check-input {
    float: none;
    margin: 0;
    flex-shrink: 0;
}

.cat-order-switch .form-check-label {
    margin: 0;
    cursor: pointer;
}

.cat-order-filter {
    width: 240px;
    min-width: 200px;
}

/* "Select Category" was wrapping to two lines even with room to spare. */
.cat-order-filter-label {
    white-space: nowrap;
    flex-shrink: 0;
}

@media (max-width: 575.98px) {
    .cat-order-filter { width: 100%; }
}
</style>
