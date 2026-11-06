<template>
    <div>
        <div class="list-page">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('product_ratings') }}</h3>
            </div>

            <div class="list-surface">
                <div class="list-toolbar">
                    <div class="list-toolbar-start d-flex flex-wrap gap-2">
                        <AppSelect class="form-control form-select list-select-lg" v-model="category_id"
                            :options="categoryOptions" :allow-empty="false" :searchable="categoryOptions.length > 6"
                            :placeholder="__('all_categories')" @update:model-value="onFilterChange" />
                        <AppSelect class="form-control form-select list-select-lg" v-model="brand_id"
                            :options="brandOptions" :allow-empty="false" :searchable="brandOptions.length > 6"
                            :placeholder="__('all_brands')" @update:model-value="onFilterChange" />
                        <AppSelect class="form-control form-select list-select-lg" v-model="product_id"
                            :options="productOptions" :allow-empty="false" :searchable="productOptions.length > 6"
                            :placeholder="__('all_products')" @update:model-value="getRecords()" />
                    </div>

                    <div class="list-search">
                        <Search class="list-search-icon" />
                        <input
                            id="filter-input"
                            v-model="filter"
                            type="search"
                            class="form-control"
                            :placeholder="__('search')">
                    </div>

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getRecords()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable responsive
                    :items="ratings"
                    :fields="fields"
                    :current-page="currentPage"
                    :per-page="perPage"
                    :filter="filter"
                    :filter-included-fields="filterOn"
                    v-model:sort-by="sortBy"
                    v-model:sort-desc="sortDesc"
                    :sort-direction="sortDirection"

                    :busy="isLoading"
                    stacked="md"
                    show-empty
                    small>

                    <template #cell(product_name)="row">
                        <div class="rating-entity" :class="{ 'is-link': canOpenProduct }"
                            @click="openProduct(row.item.product_id)">
                            <img v-if="row.item.product_image_url" :src="row.item.product_image_url"
                                class="list-thumb rating-entity-img" alt="" />
                            <span class="text-start">{{ row.item.product_name || '-' }}</span>
                        </div>
                    </template>

                    <template #cell(user_name)="row">
                        <div v-if="row.item.user" class="rating-entity" :class="{ 'is-link': canOpenCustomer }"
                            @click="openCustomer(row.item.user.id)">
                            <img :src="row.item.user.profile" class="rating-entity-avatar" alt="" />
                            <span class="rating-entity-lines text-start">
                                <span class="fw-semibold">{{ row.item.user.name || '-' }}</span>
                                <small v-if="row.item.user.email" class="text-muted d-block">
                                    {{ $filters.emailMask(row.item.user.email) }}
                                </small>
                                <small v-if="row.item.user.mobile" class="text-muted d-block">
                                    {{ row.item.user.country_code }} {{ $filters.mobileMask(row.item.user.mobile) }}
                                </small>
                            </span>
                        </div>
                        <span v-else class="text-muted">-</span>
                    </template>

                    <template #cell(rate)="row">
                        {{ renderStarRating(row.item.rate) }}
                    </template>

                    <template #cell(review)="row">
                        <div class="review-cell text-start">
                            <span>{{ isReviewExpanded(row.item.id) || !isLongReview(row.item.review) ? row.item.review : shortReview(row.item.review) }}</span>
                            <a v-if="isLongReview(row.item.review)" href="javascript:void(0)"
                                class="d-block small text-primary" @click="toggleReview(row.item.id)">
                                {{ isReviewExpanded(row.item.id) ? __('view_less') : __('view_more') }}
                            </a>
                        </div>
                    </template>

                    <template #cell(updated_at)="row">
                        {{ $filters.formatDateTime(row.item.updated_at) }}
                    </template>
                    <template #cell(images)="row">
                        <span v-if="!row.item.images || !row.item.images.length" class="text-muted">-</span>
                        <a v-for="(image, index) in row.item.images" :key="index" href="javascript:void(0)"
                            @click.prevent="openLightbox(row.item.images, index)">
                        <img class="images_border list-thumb" style="cursor:pointer" :src="image.image_url" alt="Image">
                        </a>
                    </template>
                    <template #cell(status)="row">
                        <span class="status-pill is-active" v-if="row.item.status == 1">{{ __('activate') }}</span>
                        <span class="status-pill is-inactive" v-if="row.item.status == 0">{{ __('deactivate') }}</span>
                    </template>
                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <button class="list-action-btn is-edit" @click="edit_record = row.item"  v-b-tooltip.hover :title="__('edit')"><Pencil :size="15" /></button>
                            <button class="list-action-btn is-delete" @click="deleteDietary(row.index,row.item.id)"  v-b-tooltip.hover :title="__('delete')"><Trash2 :size="15" /></button>
                        </div>
                    </template>

                </MazerDatatable>

                <!-- Image lightbox (click a review image to open full size). -->
                <div v-if="lightboxOpen" class="rating-lightbox" @click.self="closeLightbox">
                    <button type="button" class="rating-lightbox-close" @click="closeLightbox"><X :size="26" /></button>
                    <button type="button" v-if="lightboxImages.length > 1" class="rating-lightbox-nav prev" @click.stop="lightboxPrev"><ChevronLeft :size="26" /></button>
                    <img :src="lightboxImages[lightboxIndex]" class="rating-lightbox-img" alt="" />
                    <button type="button" v-if="lightboxImages.length > 1" class="rating-lightbox-nav next" @click.stop="lightboxNext"><ChevronRight :size="26" /></button>
                </div>

                <div class="list-footer">
                    <div class="list-perpage">
                        <span>{{ __('per_page') }}</span>
                        <b-form-select
                            id="per-page-select"
                            v-model="perPage"
                            :options="pageOptions"
                            size="sm"
                            class="form-select"
                        ></b-form-select>
                        <span class="list-range">{{ __('total_ratings') }} {{totalRows}}   , {{ __('average_rating') }} {{ calculateAverageRating().toFixed(2) }}</span>
                    </div>

                    <b-pagination
                        v-model="currentPage"
                        :total-rows="totalRows"
                        :per-page="perPage"
                        size="sm"
                        class="mb-0 list-pagination"
                    ></b-pagination>
                </div>
            </div>
        </div>
    </div>
</template>
<script>
import draggable from 'vuedraggable';
import axios from "axios";
import { Search, RefreshCw, Pencil, Trash2, ChevronLeft, ChevronRight, X } from 'lucide-vue-next';
export default {
    components: {
        draggable,
        Search, RefreshCw, Pencil, Trash2, ChevronLeft, ChevronRight, X,
    },
    data: function () {
        return {
            fields: [
                { key: 'id', label: __('id'), class: 'text-center', sortable: true, sortDirection: 'desc' },
                { key: 'product_name', label: __('product'), sortable: true, class: 'text-center' },
                { key: 'user_name', label: __('user'), sortable: false, class: 'text-center' },
                { key: 'rate', label: __('product_ratings'), sortable: true, class: 'text-center' },
                { key: 'review', label: __('reviews'), sortable: false, class: 'text-center' },
                { key: 'images', label: __('image'), sortable: false, class: 'text-center' },
                { key: 'updated_at', label: __('date'),  class: 'text-center' },
                
            ],
            totalRows: 0,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            sortBy: 'id',
            sortDesc: false,
            sortDirection: 'asc',
            filter: null,
            filterOn: [],
            page: 1,
            ratings: [],
            list: [],
            editable: true,
            isDragging: false,
            delayedDragging: false,
            isLoading: false,
            products: [], 
            product_id:this.id !== undefined ? this.id : "",
            // Category / brand narrow the product dropdown AND the rows.
            categories: [],
            brands: [],
            category_id: '',
            brand_id: '',
            
            // Image lightbox state.
            lightboxOpen: false,
            lightboxImages: [],
            lightboxIndex: 0,
            // Ids of reviews shown in full (view more/less toggle).
            expandedReviews: [],
            reviewClamp: 120,
            // Language handling for translations
            currentLanguageId: null,
            activeLanguages: []
        }
    },
    computed: {
        // "All …" is always the first option so the filters can be cleared.
        categoryOptions() {
            return [{ id: '', name: __('all_categories') }]
                .concat((this.categories || []).map(c => ({ id: c.id, name: c.name })));
        },
        brandOptions() {
            return [{ id: '', name: __('all_brands') }]
                .concat((this.brands || []).map(b => ({ id: b.id, name: b.name })));
        },
        productOptions() {
            return [{ id: '', name: __('all_products') }].concat(this.translatedProducts || []);
        },
        // Route guards: /products/view/:id needs product_list, /users/view/:id needs order_list.
        canOpenProduct() { return this.$can('product_list'); },
        canOpenCustomer() { return this.$can('order_list'); },
        dragOptions() {
            return {
                animation: 0,
                group: "description",
                disabled: !this.editable,
                ghostClass: "ghost"
            };
        },
        listString() {
            return JSON.stringify(this.list, null, 2);
        },
        list2String() {
            return JSON.stringify(this.list2, null, 2);
        },
        // Computed property to translate products for dropdown
        translatedProducts: function() {
            if (!this.currentLanguageId || this.products.length === 0) {
                return this.products;
            }

            // Get default language ID for fallback
            const defaultLanguage = this.activeLanguages.find(lang => lang.is_default === 1);
            const defaultLanguageId = defaultLanguage ? defaultLanguage.id : null;

            return this.products.map(product => {
                const translatedProduct = { ...product };
                let translatedName = product.name; // Fallback to main table name

                if (product.translations && Array.isArray(product.translations)) {
                    // First try to find translation for current language
                    let translation = product.translations.find(
                        t => t.language_id === this.currentLanguageId
                    );

                    // If not found, try default language
                    if (!translation && defaultLanguageId) {
                        translation = product.translations.find(
                            t => t.language_id === defaultLanguageId
                        );
                    }

                    // Use translation name if available and not empty
                    if (translation && translation.name && translation.name.trim() !== '') {
                        translatedName = translation.name;
                    }
                }

                translatedProduct.name = translatedName;
                return translatedProduct;
            });
        },
    },
    watch: {
        isDragging(newValue) {
            if (newValue) {
                this.delayedDragging = true;
                return;
            }
            this.$nextTick(() => {
                this.delayedDragging = false;
            });
        }
    },
    mounted() { 
     
        $(document).on('click', '[data-toggle="lightbox"]', function(event) {
      event.preventDefault();
      $(this).ekkoLightbox();
    });

    },
    created: function () {
        this.id = this.$route.params.id;
        // A product may be pre-selected via route param; otherwise top 5 rated show.
        if (this.id) this.product_id = this.id;
        // Load languages first so we know currentLanguageId before mapping translations.
        // getRecords also returns the product-level dropdown list.
        this.loadFilterLists();
        this.fetchActiveLanguages().then(() => {
            this.getRecords();
        }).catch(() => {
            this.getRecords();
        });
    },
 
    methods: {
        // Fetch active languages and set current language ID
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
        // Open the review images in a fullscreen overlay at the clicked image.
        openLightbox(images, index = 0) {
            const urls = (images || []).map(i => (typeof i === 'string' ? i : i.image_url)).filter(Boolean);
            if (!urls.length) return;
            this.lightboxImages = urls;
            this.lightboxIndex = index < urls.length ? index : 0;
            this.lightboxOpen = true;
        },
        closeLightbox() {
            this.lightboxOpen = false;
        },
        lightboxPrev() {
            this.lightboxIndex = (this.lightboxIndex - 1 + this.lightboxImages.length) % this.lightboxImages.length;
        },
        lightboxNext() {
            this.lightboxIndex = (this.lightboxIndex + 1) % this.lightboxImages.length;
        },
        // Review view more / less.
        isLongReview(text) {
            return !!text && String(text).length > this.reviewClamp;
        },
        shortReview(text) {
            return String(text || '').slice(0, this.reviewClamp).trimEnd() + '…';
        },
        isReviewExpanded(id) {
            return this.expandedReviews.includes(id);
        },
        toggleReview(id) {
            const i = this.expandedReviews.indexOf(id);
            if (i === -1) this.expandedReviews.push(id);
            else this.expandedReviews.splice(i, 1);
        },
        calculateAverageRating() {
    if (this.ratings.length === 0) {
      return 0; // Return 0 if there are no ratings to avoid division by zero
    }

    const totalRatings = this.ratings.reduce((total, rating) => total + rating.rate, 0);
    const averageRating = totalRatings / this.ratings.length;

    return averageRating;
  },
         renderStarRating(rate) {
       const totalStars = 5;
    const filledStars = rate;
    const blankStars = totalStars - filledStars;

    const starIconFilled = '⭐️';
    const starIconBlank = '☆';

    const ratingString = starIconFilled.repeat(filledStars) + starIconBlank.repeat(blankStars);

    return ratingString;
    },
  

        openProduct(id) {
            if (!id || !this.canOpenProduct) return;
            this.$router.push('/products/view/' + id);
        },
        openCustomer(id) {
            if (!id || !this.canOpenCustomer) return;
            this.$router.push('/users/view/' + id);
        },
        // Category / brand change the product set, so a product picked under the old
        // filters would no longer be valid — clear it and reload.
        onFilterChange() {
            this.product_id = '';
            this.getRecords();
        },
        loadFilterLists() {
            axios.get(this.$apiUrl + '/categories', { params: { status: 1 } })
                .then(res => { this.categories = res.data?.data || []; })
                .catch(() => { this.categories = []; });
            // Brand routes live under the products prefix: /products/brands/*.
            // `/get` returns every active brand unpaginated; `/` is a paginated admin list.
            axios.get(this.$apiUrl + '/products/brands/get')
                .then(res => { this.brands = res.data?.data || []; })
                .catch(() => { this.brands = []; });
        },
      getRecords() {
            this.isLoading = true;
            let param = {
               "product_id": this.product_id || "",
               "category_id": this.category_id || "",
               "brand_id": this.brand_id || ""
            }

            axios.get(this.$baseUrl + '/customer/products/ratings_list', {
                params: param
            }).then((response) => {
                this.isLoading = false;
                const d = response.data.data || {};
                // Flatten user name onto the row — the datatable can't read nested "user.name".
                this.ratings = (d.rating_list || []).map(r => ({
                    ...r,
                    user_name: r.user ? r.user.name : '',
                }));

                if (Array.isArray(d.products)) this.products = d.products;
                this.currentPage = 1;
                this.totalRows = this.ratings.length
            });
        },
    }
};
</script>
<style scoped>
/* Product / customer cells: thumbnail + text, clickable through to their pages. */
.rating-entity {
    display: flex;
    align-items: center;
    gap: .5rem;
    text-align: start;
}

.rating-entity.is-link {
    cursor: pointer;
}

.rating-entity.is-link:hover {
    color: var(--bs-primary);
}

.rating-entity-img,
.rating-entity-avatar {
    width: 34px;
    height: 34px;
    object-fit: cover;
    border-radius: 6px;
    flex-shrink: 0;
}

.rating-entity-avatar {
    border-radius: 50%;
}

.rating-entity-lines {
    min-width: 0;
    line-height: 1.25;
}

.review-cell {
    max-width: 320px;
    white-space: normal;
    word-break: break-word;
    margin: 0 auto;
}
.rating-lightbox {
    position: fixed;
    inset: 0;
    z-index: 2000;
    background: rgba(0, 0, 0, 0.85);
    display: flex;
    align-items: center;
    justify-content: center;
}
.rating-lightbox-img {
    max-width: 90vw;
    max-height: 88vh;
    object-fit: contain;
    border-radius: 6px;
    box-shadow: 0 8px 40px rgba(0, 0, 0, 0.5);
}
.rating-lightbox-close {
    position: absolute;
    top: 18px;
    right: 24px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 42px;
    height: 42px;
    background: rgba(255, 255, 255, 0.12);
    border: none;
    border-radius: 50%;
    color: #fff;
    cursor: pointer;
    transition: background 0.15s;
}
.rating-lightbox-nav {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.12);
    border: none;
    color: #fff;
    width: 48px;
    height: 48px;
    border-radius: 50%;
    cursor: pointer;
    transition: background 0.15s;
}
.rating-lightbox-close:hover,
.rating-lightbox-nav:hover { background: rgba(255, 255, 255, 0.28); }
.rating-lightbox-close svg,
.rating-lightbox-nav svg { display: block; }
.rating-lightbox-nav.prev { left: 24px; }
.rating-lightbox-nav.next { right: 24px; }
.flip-list-move {
    transition: transform 0.5s;
}

.no-move {
    transition: transform 0s;
}

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
</style>
<style>
/* Add some basic styling to the lightbox */
#lightbox {
  display: none;
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.7);
  justify-content: center;
  align-items: center;
  overflow: hidden;
  z-index: 999;
}

#lightbox-content {
  position: relative;
  max-width: 80%;
  max-height: 80%;
}

.close {
  position: absolute;
  top: 15px;
  right: 15px;
  font-size: 30px;
  color: #fff;
  cursor: pointer;
}
</style>
