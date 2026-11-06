<template>
    <div>
        <div class="list-page">
            <!-- Storage usage + unused-image cleanup: admin panel only, never branch users. -->
            <StorageCleanup v-if="!$isBranchUser()" @changed="getMedia()" />

            <div class="page-head">
                <h3 class="page-head-title">{{ __('media_upload_form') }}</h3>
            </div>

            <div class="list-surface p-3 mb-4">
                <form method="POST" enctype="multipart/form-data">
                    <div
                        id="dropzone"
                        class="dropzone-area"
                        @dragover="$dragoverFile($event)"
                        @dragleave="$dragleaveFile($event)"
                        @drop.prevent="handleDrop"
                        @click="$refs.fileInput.click()"
                        style="border: 2px dashed #ccc; padding: 40px; text-align: center; cursor: pointer; border-radius: 8px;"
                    >
                        <input
                            ref="fileInput"
                            type="file"
                            :accept="dropzoneOptions.acceptedFiles"
                            multiple
                            style="display: none;"
                            @change="handleFileSelect"
                        />
                        <div class="dropzone-custom-content">
                            <h3 class="dropzone-custom-title d-inline-flex align-items-center gap-2"><Upload :size="18" /> {{ __('drag_and_drop_to_upload_image') }}</h3>
                            <div class="subtitle">{{__('or_click_to_select_a_image_from_your_device')}}</div>
                        </div>
                        <div v-if="queuedFiles.length" class="mt-2">
                            <span class="badge bg-primary">{{ queuedFiles.length }} {{ __('files_selected') || 'file(s) selected' }}</span>
                        </div>
                    </div>
                    <div class="d-flex justify-content-end mt-2">
                        <button type="button" :disabled="submitBtn === true" @click="uploadImage()" class="btn btn-primary list-add-btn">
                            <Upload :size="16" v-if="!isLoading" /> {{ __('upload') }}
                            <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                        </button>
                    </div>
                </form>
            </div>

            <div class="page-head">
                <h3 class="page-head-title">{{ __('media_list')}}</h3>
                <div class="page-head-actions">
                    <b-dropdown size="sm" dropright :text="__('actions')" split-variant="outline-primary"
                                variant="primary" :disabled="selectedItems.length === 0">
                        <b-dropdown-item href="javascript:void(0);" @click="multipleDelete"><span
                            class="text-danger d-inline-flex align-items-center gap-1" style="font-weight: bold;"><Trash2 :size="15" /> {{ __('delete_selected_media') }}</span>
                        </b-dropdown-item>
                    </b-dropdown>
                </div>
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

                    <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getMedia()">
                        <RefreshCw :class="{ 'is-spinning': isLoading }" />
                    </button>
                </div>

                <MazerDatatable
                    responsive="sm"
                    :items="media"
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

                    <template #head(select)="row">
                        <input type="checkbox" v-model="all_select" @click="allSelectCheckBox"
                               class="form-check-input">
                    </template>
                    <template #cell(select)="row">
                        <input type="checkbox" v-model="selectedItems" @change="selectCheckBox"
                               :value="`${row.item.id}`" class="form-check-input">
                    </template>

                    <template #cell(image)="row">
                        <template v-if="row.item.name">
                            <!-- The library holds clips too; an <img> would show a broken tile. -->
                            <video v-if="isVideo(row.item)"
                                   :src="$storageUrl + row.item.sub_directory + row.item.name"
                                   class="list-thumb list-thumb-video" controls muted playsinline
                                   preload="metadata"></video>
                            <img v-else :src="$storageUrl + row.item.sub_directory + row.item.name" class="list-thumb" />
                        </template>
                    </template>
                    <template #cell(actions)="row">
                        <div class="list-actions">
                            <button type="button" class="btn btn-sm btn-outline-primary"
                                    @click="copyPath(row.item)">
                                <span v-if="!copies.includes(row.item.id)">
                                    {{ __('copy') }}
                                </span>
                                <span v-if="copies.includes(row.item.id)">Copied!</span>
                            </button>
                            <button type="button" class="list-action-btn is-delete"
                                    v-b-tooltip.hover :title="__('delete')"
                                    @click="deleteMedia(row.index,row.item.id)">
                                <Trash2 :size="15" />
                            </button>
                        </div>
                    </template>

                </MazerDatatable>

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
                        <!-- Library totals: how many files and how much space they take. -->
                        <span class="list-range media-totals">
                            <ImageIcon :size="13" /> {{ totalRows }} {{ __('media') }}
                            <span class="media-totals-sep">·</span>
                            <HardDrive :size="13" /> {{ totalMediaSize }}
                        </span>
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
import axios from "axios";
import Auth from '../../Auth.js';
import { Search, RefreshCw, Upload, Trash2, HardDrive, Image as ImageIcon } from 'lucide-vue-next';
import StorageCleanup from './StorageCleanup.vue';

// A clip in the library can be dropped straight into a product gallery, so it is held to
// the same ceiling the product form enforces (ProductApisController::GALLERY_MAX_MB).
// Stills keep no cap here, as they always have.
const VIDEO_MAX_MB = 5;

export default {
    components: {
        Search, RefreshCw, Upload, Trash2, HardDrive, ImageIcon, StorageCleanup,
    },
    data: function () {
        return {
            login_user: Auth.user,
            queuedFiles: [],

            dropzoneOptions: {
                url: this.$apiUrl + '/media/save',
                thumbnailWidth: 175,
                maxFilesize: 0.5,
                addRemoveLinks: true,
                paramName: "files",
                autoProcessQueue: false,
                parallelUploads: 10,
                autoDiscover: false,
                dictResponseError: 'Error',
                uploadMultiple: true,
                headers: {"My-Awesome-Header": "header value", "Authorization": 'Bearer ' +Auth.token},
                acceptedFiles: 'image/jpeg,image/png,image/jpg,image/gif,image/webp,image/svg+xml,video/mp4', // images, svg, and mp4
                dictFileTooBig: 'File is too big ({{filesize}}MB). Max file size: {{maxFilesize}}MB.', // Custom error message for file size
                dictInvalidFileType: 'Invalid file type. Only image, SVG and MP4 files are allowed.', // Custom error message for file type
            },
            submitBtn: false,
            fields: [
                {key: 'select', label: '', sortable: false, class: 'text-center'},
                {key: 'id', label: __('id'), sortable: true, sortDirection: 'desc', class: 'text-center'},
                {key: 'image', label: __('image'), sortable: false, class: 'text-center'},
                {key: 'name', label: __('name'), sortable: false, class: 'text-center'},
                {key: 'extension', label: __('extension'), sortable: true, class: 'text-center'},
                {key: 'type', label: __('type'), sortable: true, class: 'text-center'},
                {key: 'sub_directory', label: __('sub_directory'), sortable: false, class: 'text-center'},
                {key: 'size', label: __('size'), sortable: true, class: 'text-center'},
                {key: 'actions', label: __('actions'), sortable: false}
            ],
            totalRows: 1,
            currentPage: 1,
            perPage: this.$perPage,
            pageOptions: this.$pageOptions,
            sortBy: '',
            sortDesc: false,
            sortDirection: 'asc',
            filter: null,
            filterOn: [],
            page: 1,

            isLoading: false,
            sectionStyle: 'style_1',
            max_visible_units: 12,
            max_col_in_single_row: 3,
            media: [],
            copyIcon: true,
            copies: [],
            selectedItems: [],
            all_select: false,
        }
    },
    computed: {
        /**
         * Total library size. `media.size` is stored already formatted ("220.71 KB"),
         * so each row is parsed back to bytes, summed, then re-formatted.
         */
        totalMediaSize() {
            const units = { '': 1, B: 1, KB: 1024, MB: 1024 ** 2, GB: 1024 ** 3, TB: 1024 ** 4 };
            const bytes = (this.media || []).reduce((sum, m) => {
                const match = String(m.size || '').trim().match(/^([\d.]+)\s*([A-Za-z]*)$/);
                if (!match) return sum;
                const unit = units[match[2].toUpperCase()] ?? 1;
                return sum + (parseFloat(match[1]) || 0) * unit;
            }, 0);

            if (!bytes) return '0 KB';
            const names = ['B', 'KB', 'MB', 'GB', 'TB'];
            const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), names.length - 1);
            return (bytes / (1024 ** i)).toFixed(i === 0 ? 0 : 2) + ' ' + names[i];
        },
        sortOptions() {
            // Create an options list from our fields
            return this.fields
                .filter(f => f.sortable)
                .map(f => {
                    return {text: f.label, value: f.key}
                })
        },
    },
    mounted() {
        // Set the initial number of items
        this.totalRows = this.media.length
    },
    created: function () {
        this.getMedia();
    },
    methods: {
        /** A library row is a clip when its stored MIME type says so. */
        isVideo(item) {
            return String(item && item.type || '').startsWith('video/');
        },
        getMedia() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/media')
                .then((response) => {
                    this.media = response.data.data;
                    this.totalRows = this.media.length;
                    this.isLoading = false;
                });
        },
        handleFileSelect(event) {
            const files = Array.from(event.target.files);
            this.queuedFiles = files;
        },
        handleDrop(event) {
            event.preventDefault();
            const files = Array.from(event.dataTransfer.files);
            this.queuedFiles = files;
        },
        uploadImage() {
            this.isLoading = true;
            if (this.queuedFiles.length === 0) {
                this.isLoading = false;
                this.showError("Select at least one image or selected image is too large!");
                return;
            }
            if (this.queuedFiles.length > 10) {
                this.isLoading = false;
                this.showError("You can upload 10 medias file at a time");
                return false;
            }
            // Checked here as well as on the server, so a rejected clip is not uploaded first.
            const tooBig = this.queuedFiles.find(f => String(f.type || '').startsWith('video/')
                && f.size > VIDEO_MAX_MB * 1024 * 1024);
            if (tooBig) {
                this.isLoading = false;
                this.showError(__('file_size_exceeds_limit_x', { size: VIDEO_MAX_MB + ' MB' }));
                return false;
            }
            let formData = new FormData();
            this.queuedFiles.forEach((file) => {
                formData.append('files[]', file);
            });
            axios.post(this.$apiUrl + '/media/save', formData, {
                headers: {
                    'Content-Type': 'multipart/form-data',
                    'Authorization': 'Bearer ' + Auth.token,
                }
            }).then((response) => {
                this.uploadSuccess(response.data);
            }).catch((error) => {
                this.isLoading = false;
                this.showError(error.response ? error.response.data.message : 'Upload failed');
            });
        },
        uploadSuccess(response) {
            if (response.status === 1) {
                this.getMedia();
                this.isLoading = false;
                this.showMessage("success", response.message);
                this.queuedFiles = [];
                if (this.$refs.fileInput) this.$refs.fileInput.value = '';
            } else {
                this.isLoading = false;
                this.showError(response.message);
            }
        },
        deleteMedia(index, id) {
            this.$swal.fire({
                title: "Are you Sure?",
                text: "You want be able to revert this",
                confirmButtonText: "Yes, Sure",
                cancelButtonText: "Cancel",
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
                    axios.post(this.$apiUrl + '/media/delete', postData)
                        .then((response) => {
                            this.isLoading = false
                            this.media.splice(index, 1)
                            this.showMessage('success', response.data.message);
                        });
                }
            });
        },
        copyPath(item) {
            // Copy the storage path (e.g. products/media/x.jpg) — usable in the
            // product form and the bulk import image columns.
            const path = item.sub_directory + item.name;
            navigator.clipboard.writeText(path).catch(() => {
                // http / older browsers: clipboard API unavailable — fall back.
                const ta = document.createElement('textarea');
                ta.value = path;
                document.body.appendChild(ta);
                ta.select();
                document.execCommand('copy');
                ta.remove();
            });
            this.copies.push(item.id);
            setTimeout(() => { this.copies = this.copies.filter(i => i !== item.id); }, 1500);
        },

        allSelectCheckBox() {
            if (this.all_select == false) {
                this.all_select = true
                this.media.forEach(media => {
                    this.selectedItems.push(media.id)
                });
            } else {
                this.all_select = false
                this.selectedItems = []
            }
        },
        selectCheckBox() {
            let uniqueSelectedItems = [...new Set(this.selectedItems)];
            if (this.media.length === uniqueSelectedItems.length) {
                this.all_select = true
            } else {
                this.all_select = false
            }
        },
        multipleDelete() {
            let uniqueSelectedItems = [...new Set(this.selectedItems)];
            if (uniqueSelectedItems.length !== 0) {
                this.$swal.fire({
                    title: "Are you Sure?",
                    text: "You want be able to revert this",
                    confirmButtonText: "Yes, Sure",
                    cancelButtonText: "Cancel",
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonColor: window.adminThemeColor || '#435ebe',
                    cancelButtonColor: '#d33',
                }).then(result => {
                    if (result.value) {
                        let ids = uniqueSelectedItems.toString();
                        this.isLoading = true
                        let postData = {
                            ids: ids
                        }
                        axios.post(this.$apiUrl + '/media/multiple_delete', postData)
                            .then((response) => {
                                this.isLoading = false
                                let data = response.data;
                                this.getMedia();
                                this.selectedItems = [];
                                this.all_select = false;
                                this.showMessage("success", data.message);

                            });
                    }
                });
            } else {
                this.showWarning("Select at least one record!");
            }
        }
    }
};
</script>

<style scoped>
/* vue3-dropzone styles are included automatically */

/* Library totals sit beside the per-page select in the table footer. */
.media-totals {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    white-space: nowrap;
}
.media-totals svg {
    flex-shrink: 0;
    opacity: .7;
}
.media-totals-sep {
    opacity: .5;
    margin: 0 2px;
}
/* The list thumb is square; a player needs room for its own controls. */
.list-thumb-video {
    width: 110px;
    height: auto;
    background: #000;
}
</style>
<style>
.vue-dropzone>.dz-preview .dz-error-message{
    top: 1px !important;
}
</style>
