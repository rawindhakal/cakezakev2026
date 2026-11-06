<template>
    <b-modal ref="my-modal" :title="modal_title" @hidden="$emit('modalClose')" size="lg" scrollable centered no-close-on-backdrop
        no-fade static>
        <template #footer>
            <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">{{ __('save') }}
                <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
            </b-button>
            <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
        </template>
        <form ref="my-form" @submit.prevent="saveRecord">

            <div class="row">
                <!-- System Type - Only show when editing (id exists) -->
                <div class="form-group" v-if="id">
                    <label for="branch">{{ __('system_type') }}</label>
                    <AppSelect v-model="system_type" class="form-control form-select" :options="system_types"
                        :placeholder="__('select_system_type')" :searchable="false" disabled />
                    <small class="text-muted">{{ __('system_type_cannot_be_changed_when_editing') }}</small>
                </div>
                <div class="row">
                    <div class="form-group col-12 col-lg-6">
                        <label for="supported_language">{{ __('supported_language') }}</label><span
                            class="text-danger">*</span>
                        <!-- Searchable: the supported-language list is long. -->
                        <AppSelect v-model="supported_language" class="form-control form-select"
                            :options="supported_languages" :placeholder="__('select_supported_language')"
                            :disabled="!!id" />
                        <small v-if="id" class="text-muted">{{ __('supported_language_cannot_be_changed_when_editing')
                            }}</small>
                    </div>

                    <div class="form-group col-12 col-lg-6">
                        <label for="display_name">{{ __('display_name') }}<span class="text-danger">*</span></label>
                        <input name="display_name" id="display_name" v-model="display_name" class="form-control" :placeholder="__('display_name')">
                    </div>
                </div>
                <!-- When creating (no id), show JSON file inputs for all system types -->
                <template v-if="!id">

                    <div class="form-group col-12 col-lg-6" v-for="systemType in system_types" :key="systemType.id">
                        <FileUpload v-model="jsonFiles[systemType.id]"
                            :label="__('json_file') + ' - ' + systemType.name" required accept="application/json"
                            :show-preview="false" :error="getError('json_data_' + systemType.id)"
                            @change="(file) => onJsonFileChange(file, systemType.id)" />

                        <div class="form-group mt-2" v-if="getJsonData('json_data_' + systemType.id)">
                            <label :for="'json_data_' + systemType.id">{{ __('json_data') }} - {{ systemType.name
                                }}</label>
                            <textarea readonly class="form-control" rows="5"
                                :value="getJsonData('json_data_' + systemType.id)" :name="'json_data_' + systemType.id"
                                :id="'json_data_' + systemType.id"></textarea>
                        </div>
                    </div>
                </template>

                <!-- When editing (id exists), show single JSON file input with theme's drag-and-drop -->
                <template v-else>
                    <div class="form-group">
                        <FileUpload v-model="json_file" :label="__('json_file')" accept="application/json"
                            :show-preview="false" :error="error" @change="onMainJsonFileChange" />

                        <div class="form-group mt-2" v-if="json_data">
                            <label for="json_data">{{ __('json_data') }}</label>
                            <textarea readonly class="form-control" rows="10" v-model="json_data" name="json_data"
                                id="json_data">{{ json_data
                                }}</textarea>
                        </div>
                    </div>
                </template>
                <div class="form-group">
                    <input name="is_default" id="is_default" v-model="is_default" true-value="1" false-value="0"
                        :checked="is_default" type="checkbox" class="form-check-input">
                    <label for="is_default">{{ __('set_as_a_default_language') }}</label>
                </div>
                <div class="form-group">
                    <label>{{ __('status') }}</label>
                    <div class="col-md-9 text-left mt-1">
                        <div class="btn-group btn-group-toggle" role="group">
                            <label class="btn btn-outline-primary" :class="{ active: status == 0 }">
                                <input type="radio" :value="0" v-model.number="status" autocomplete="off"> {{ __('deactivate') }}
                            </label>
                            <label class="btn btn-outline-primary" :class="{ active: status == 1 }">
                                <input type="radio" :value="1" v-model.number="status" autocomplete="off"> {{ __('activate') }}
                            </label>
                        </div>
                    </div>
                </div>
            </div>
            <button ref="dummy_submit" style="display:none;"></button>
        </form>
    </b-modal>
</template>

<script>
import axios from 'axios';
import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

export default {
    props: ['record', 'system_types', 'supported_languages'],
    mixins: [UnsavedChanges],
    data: function () {
        return {
            isLoading: false,

            id: this.record ? this.record.id : null,
            system_type: this.record ? this.record.system_type : "",
            supported_language: this.record ? this.record.supported_language_id : "",
            display_name: this.record ? this.record.display_name : "",
            json_file: "",
            json_data: "",
            // Current bundle read from its file (edit mode); also the revert target
            // when the admin clears a freshly picked upload.
            originalJsonData: "",
            is_default: this.record ? this.record.is_default : 0,
            status: this.record ? this.record.status : 1,
            error: null,
            jsonDataObjects: {},
            errors: {},
            jsonFiles: {},
        };
    },
    computed: {
        modal_title: function () {
            let title = this.id ? __('edit_language') : __('add_language');
            return title;
        },
    },

    methods: {
        // Tracked state for the UnsavedChanges guard
        formState() {
            return {
                supported_language: this.supported_language,
                display_name: this.display_name,
                is_default: this.is_default,
                status: this.status,
                json_data: this.json_data,
                jsonDataObjects: this.jsonDataObjects,
            };
        },
        loadExistingJson() {
            // Edit mode: the bundle lives in a file, so fetch it rather than reading
            // a blob off the grid row (that column is gone).
            if (!this.id) {
                // Add mode: no async load, so snapshot the "clean" baseline now.
                this.captureFormBaseline();
                return;
            }
            axios.get(this.$apiUrl + '/languages/get_json', { params: { id: this.id } })
                .then(res => {
                    const d = res.data.data || {};
                    this.originalJsonData = JSON.stringify(d.json_data || {});
                    this.json_data = this.originalJsonData;
                })
                .catch(() => {})
                .finally(() => {
                    // Snapshot the loaded form as the "clean" baseline for the guard.
                    this.captureFormBaseline();
                });
        },
        showModal() {
            this.$refs['my-modal'].show()
        },
        hideModal() {
            this.$refs['my-modal'].hide()
        },
        getError(key) {
            return this.errors[key] || '';
        },
        getJsonData(key) {
            return this.jsonDataObjects[key] || '';
        },
        // Base64-wrap the language JSON so hosting WAF rules don't 403 the raw
        // translation payload. Server decodes the "b64:" prefix.
        encodeJson(str) {
            const s = str == null ? '' : String(str);
            if (s === '') return s;
            return 'b64:' + btoa(unescape(encodeURIComponent(s)));
        },

        onJsonFileChange(file, systemTypeId) {
            const jsonDataKey = 'json_data_' + systemTypeId;

            if (!file) {
                this.jsonDataObjects[jsonDataKey] = "";
                this.errors[jsonDataKey] = "";
                return;
            }

            const reader = new FileReader();
            reader.onload = () => {
                try {
                    const jsonData = JSON.parse(reader.result);
                    this.jsonDataObjects[jsonDataKey] = JSON.stringify(jsonData, null, 2);
                    this.errors[jsonDataKey] = "";
                } catch (error) {
                    this.errors[jsonDataKey] = "Invalid JSON file. Please upload a valid JSON file.";
                    this.jsonDataObjects[jsonDataKey] = "";
                    this.jsonFiles[systemTypeId] = null;
                }
            };
            reader.readAsText(file);
        },
        onMainJsonFileChange(file) {
            if (!file) {
                this.json_data = this.originalJsonData;
                this.error = null;
                return;
            }

            const reader = new FileReader();
            reader.onload = () => {
                try {
                    const jsonData = JSON.parse(reader.result);
                    this.json_data = JSON.stringify(jsonData);
                    this.error = "";
                } catch (error) {
                    this.error = "Invalid JSON file. Please upload a valid JSON file.";
                    this.json_data = "";
                    this.json_file = null;
                }
            };
            reader.readAsText(file);
        },
        saveRecord: function () {
            let vm = this;

            if (!this.supported_language) {
                this.showError("Supported language is required.");
                return;
            }

            if (!this.id) {
                let hasAllJsonData = true;
                let missingSystemTypes = [];

                this.system_types.forEach(systemType => {
                    const jsonDataKey = 'json_data_' + systemType.id;
                    if (!this.jsonDataObjects[jsonDataKey]) {
                        hasAllJsonData = false;
                        missingSystemTypes.push(systemType.name);
                    }
                });

                if (!hasAllJsonData) {
                    this.showError("Please upload JSON files for all system types. Missing: " + missingSystemTypes.join(", "));
                    return;
                }
            } else {
                if (!this.json_data) {
                    this.showError("JSON data is required.");
                    return;
                }
            }

            this.isLoading = true;
            let formData = new FormData();

            if (this.id) {
                formData.append('id', this.id);
                formData.append('system_type', this.system_type);
                formData.append('supported_language', this.supported_language);
                formData.append('display_name', this.display_name);
                formData.append('json_data', this.encodeJson(this.json_data));
                formData.append('is_default', this.is_default);
                formData.append('status', this.status);

                // JSON bundles are written by update_json (files); update() only
                // handles the row's settings and would ignore an uploaded bundle.
                let url = this.$apiUrl + '/languages/update_json';
                axios.post(url, formData).then(res => {
                    let data = res.data;
                    if (data.status === 1) {
                        // Mark clean so the post-save redirect doesn't trip the unsaved-changes guard.
                        this.captureFormBaseline();
                        this.$eventBus.emit('recordSaved', data.message);
                        vm.$router.push({ path: '/languages' });
                        this.hideModal();
                    } else {
                        vm.showError(data.message);
                        vm.isLoading = false;
                    }
                }).catch(error => {
                    vm.isLoading = false;

                    let errorMessage = "Something went wrong!";

                    if (error.response && error.response.data) {
                        if (error.response.data.message) {
                            errorMessage = error.response.data.message;
                        } else if (error.response.data.error) {
                            errorMessage = error.response.data.error;
                        }
                    } else if (error.request && error.request.statusText) {
                        errorMessage = error.request.statusText;
                    } else if (error.message) {
                        errorMessage = error.message;
                    }

                    this.showError(errorMessage);
                });
            } else {
                formData.append('supported_language', this.supported_language);
                formData.append('display_name', this.display_name);
                formData.append('is_default', this.is_default);
                formData.append('status', this.status);

                this.system_types.forEach(systemType => {
                    const jsonDataKey = 'json_data_' + systemType.id;
                    if (this.jsonDataObjects[jsonDataKey]) {
                        formData.append(jsonDataKey, this.encodeJson(this.jsonDataObjects[jsonDataKey]));
                    }
                });

                let url = this.$apiUrl + '/languages/save';
                axios.post(url, formData).then(res => {
                    let data = res.data;
                    if (data.status === 1) {
                        // Mark clean so the post-save redirect doesn't trip the unsaved-changes guard.
                        this.captureFormBaseline();
                        this.$eventBus.emit('recordSaved', data.message);
                        vm.$router.push({ path: '/languages' });
                        this.hideModal();
                    } else {
                        vm.showError(data.message);
                        vm.isLoading = false;
                    }
                }).catch(error => {
                    vm.isLoading = false;

                    let errorMessage = "Something went wrong!";

                    if (error.response && error.response.data) {
                        if (error.response.data.message) {
                            errorMessage = error.response.data.message;
                        } else if (error.response.data.error) {
                            errorMessage = error.response.data.error;
                        }
                    } else if (error.request && error.request.statusText) {
                        errorMessage = error.request.statusText;
                    } else if (error.message) {
                        errorMessage = error.message;
                    }

                    this.showError(errorMessage);
                });
            }
        }
    },
    mounted() {
        this.loadExistingJson();
        this.showModal();
    }
}
</script>

<style scoped>
.image_preview {
    margin-top: 5px;
}
</style>
