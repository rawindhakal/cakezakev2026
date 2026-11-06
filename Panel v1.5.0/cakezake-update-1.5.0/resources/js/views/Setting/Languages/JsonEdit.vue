<template>
    <b-modal ref="json-edit-modal" :title="modal_title" @hidden="$emit('modalClose')" size="lg" scrollable centered no-close-on-backdrop no-fade static>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()"
                :disabled="isLoading || isLoadingJson || !!error">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">
            <div class="row">
                <div class="form-group col-md-12">
                    <!-- Toolbar: what file is open, how big it is, and the format action. -->
                    <div class="je-toolbar">
                        <div class="je-meta">
                            <span class="je-badge">{{ system_type ? system_type.name : '' }}</span>
                            <code v-if="filePath" class="je-path" :title="filePath">{{ filePath }}</code>
                        </div>
                        <div class="je-actions">
                            <span v-if="!isLoadingJson" class="je-count">{{ keyCount }} {{ __('keys') }}</span>
                            <button type="button" class="btn btn-sm btn-outline-primary" :disabled="isLoadingJson || !!error"
                                @click="formatJson">
                                <Wand2 :size="14" class="me-1" />{{ __('format') }}
                            </button>
                        </div>
                    </div>

                    <div v-if="isLoadingJson" class="je-loading">
                        <b-spinner small></b-spinner>
                        <span>{{ __('loading') }}</span>
                    </div>

                    <textarea v-else
                        class="form-control je-editor"
                        rows="20"
                        spellcheck="false"
                        v-model="json_data"
                        name="json_data"
                        id="json_data"
                        :class="{ 'is-invalid': error }"
                        @input="validateJson"
                        placeholder='{"key": "value"}'>
                    </textarea>

                    <!-- The parse error was previously computed but never rendered. -->
                    <div v-if="error" class="je-status is-error">
                        <AlertCircle :size="14" />
                        <span>{{ error }}</span>
                    </div>
                    <div v-else-if="!isLoadingJson && json_data" class="je-status is-ok">
                        <CheckCircle2 :size="14" />
                        <span>{{ __('valid_json_format') }}</span>
                    </div>
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import { Wand2, AlertCircle, CheckCircle2 } from 'lucide-vue-next';
import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

export default {
    components: { Wand2, AlertCircle, CheckCircle2 },
    props: ['record', 'system_type'],
    mixins: [UnsavedChanges],
    data: function () {
        return {
            isLoading: false,
            // Bundle is fetched from its file on mount (see loadJson).
            isLoadingJson: false,
            filePath: '',
            id: this.record ? this.record.id : null,
            system_type_id: this.record ? this.record.system_type : (this.system_type ? this.system_type.id : null),
            supported_language_id: this.record ? this.record.supported_language_id : null,
            json_data: "{}",
            error: null,
        };
    },
    computed: {
        modal_title: function () {
            let title = __('edit_json_data');
            if (this.system_type) {
                title += ' - ' + this.system_type.name;
            }
            return title;
        },
        keyCount() {
            try {
                return Object.keys(JSON.parse(this.json_data || '{}')).length;
            } catch (e) {
                return 0;
            }
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard
        formState() {
            return { json_data: this.json_data };
        },
        loadJson() {
            // Existing row -> read its file; brand-new system type -> start empty.
            if (!this.id) {
                this.json_data = "{}";
                // No async load in this path, so snapshot the "clean" baseline now.
                this.captureFormBaseline();
                return;
            }
            this.isLoadingJson = true;
            axios.get(this.$apiUrl + '/languages/get_json', { params: { id: this.id } })
                .then(res => {
                    const d = res.data.data || {};
                    this.json_data = JSON.stringify(d.json_data || {}, null, 2);
                    this.filePath = d.file_path || '';
                })
                .catch(() => { this.error = __('something_went_wrong'); })
                .finally(() => {
                    this.isLoadingJson = false;
                    // Snapshot the loaded JSON as the "clean" baseline for the guard.
                    this.captureFormBaseline();
                });
        },
        showModal() {
            this.$refs['json-edit-modal'].show()
        },
        hideModal() {
            this.$refs['json-edit-modal'].hide()
        },
        formatJson() {
            try {
                this.json_data = JSON.stringify(JSON.parse(this.json_data || '{}'), null, 2);
                this.error = null;
            } catch (e) {
                this.error = __('invalid_json_format') + ': ' + e.message;
            }
        },
        validateJson() {
            if (!this.json_data || this.json_data.trim() === '') {
                this.error = null;
                return;
            }
            
            try {
                JSON.parse(this.json_data);
                this.error = null;
            } catch (e) {
                this.error = __('invalid_json_format') + ': ' + e.message;
            }
        },
        saveRecord: function () {
            if (!this.json_data || this.json_data.trim() === '') {
                this.showError(__('json_data_is_required'));
                return;
            }

            try {
                JSON.parse(this.json_data);
            } catch (e) {
                this.showError(__('invalid_json_format') + ': ' + e.message);
                return;
            }

            this.isLoading = true;
            let formData = new FormData();
            
            if (this.id) {
                formData.append('id', this.id);
            }
            
            formData.append('system_type', this.system_type_id);
            formData.append('supported_language', this.supported_language_id);
            // Base64-wrap so hosting WAF rules don't 403 the raw JSON. Server decodes "b64:".
            const encodeJson = (str) => 'b64:' + btoa(unescape(encodeURIComponent(String(str == null ? '' : str))));
            try {
                const parsedJson = JSON.parse(this.json_data);
                formData.append('json_data', encodeJson(JSON.stringify(parsedJson)));
            } catch (e) {
                formData.append('json_data', encodeJson(this.json_data));
            }
            formData.append('display_name', this.record ? this.record.display_name : '');
            formData.append('is_default', this.record ? this.record.is_default : 0);
            formData.append('status', this.record ? this.record.status : 1);

            let url = this.$apiUrl + '/languages/update_json';
            axios.post(url, formData).then(res => {
                let data = res.data;
                if (data.status === 1) {
                    // Mark clean so closing the modal doesn't trip the unsaved-changes guard.
                    this.captureFormBaseline();
                    this.$eventBus.emit('recordSaved', data.message);
                    this.hideModal();
                    this.$emit('jsonSaved');
                    this.$emit('modalClose');
                } else {
                    this.showError(data.message);
                    this.isLoading = false;
                }
            }).catch(error => {
                this.isLoading = false;
                if (error?.request?.statusText) {
                    this.showError(error.request.statusText);
                }else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError(__("something_went_wrong"));
                }
            });
        }
    },
    // NOTE: a second mounted() used to be declared here. Duplicate keys in an object
    // literal silently overwrite, so loadJson() never ran and the editor opened empty.
    mounted() {
        this.showModal();
        this.loadJson();
    }
}
</script>

<style scoped>
.je-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: .5rem;
    margin-bottom: .5rem;
}
.je-meta {
    display: flex;
    align-items: center;
    gap: .5rem;
    min-width: 0;
}
.je-badge {
    font-size: .75rem;
    font-weight: 600;
    padding: .15rem .5rem;
    border-radius: 999px;
    background: rgba(var(--bs-primary-rgb), .12);
    color: var(--bs-primary);
    flex-shrink: 0;
}
.je-path {
    font-size: .72rem;
    color: var(--app-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.je-actions {
    display: flex;
    align-items: center;
    gap: .5rem;
    flex-shrink: 0;
}
.je-count {
    font-size: .72rem;
    color: var(--app-muted);
}
.je-loading {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: .5rem;
    height: 420px;
    color: var(--app-muted);
    border: 1px solid var(--app-card-border);
    border-radius: .5rem;
}
/* Monospace + tab support makes a 600-key bundle readable. */
.je-editor {
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: .8rem;
    line-height: 1.5;
    tab-size: 2;
    white-space: pre;
    overflow-wrap: normal;
    overflow-x: auto;
}
.je-status {
    display: flex;
    align-items: center;
    gap: .35rem;
    margin-top: .4rem;
    font-size: .78rem;
}
.je-status.is-ok { color: #198754; }
.je-status.is-error { color: #dc3545; }
</style>

