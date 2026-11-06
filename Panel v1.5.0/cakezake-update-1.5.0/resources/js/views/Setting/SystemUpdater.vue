<template>
  <div class="page-content-wrapper">
    <div class="page-heading">
      <div class="page-head">
        <h3 class="page-head-title">{{ __('system_updater') }}</h3>
        <router-link to="/settings" class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
          <ArrowLeft :size="16" /> {{ __('back') }}
        </router-link>
      </div>
    </div>

    <div class="page-content">
      <div class="row">
        <!-- Upload-and-apply an official update package. -->
        <div class="col-12 col-md-6">
          <div class="card">
            <div class="card-header d-flex justify-content-between align-items-center">
              <h4 class="mb-0">{{ __('update_the_system') }}</h4>
              <span class="badge rounded-pill bg-success">{{ __('version') + ' ' + $currentVersion }}</span>
            </div>
            <div class="card-body">
              <p class="text-muted mb-3">{{ __('system_update_hint') }}</p>

              <div class="form-group">
                <label class="small" for="purchase_code">{{ __('enter_the_purchase_code') }}</label>
                <input type="text" id="purchase_code" v-model.trim="purchaseCode" class="form-control"
                  :placeholder="__('enter_the_purchase_code')" autocomplete="off">
              </div>

              <div class="form-group mt-3">
                <label class="small" for="update_file">{{ __('update_package_zip') }}</label>
                <input ref="fileInput" type="file" accept=".zip" id="update_file" class="form-control"
                  @change="onFile">
              </div>

              <div v-if="fileName" class="alert alert-light border d-flex align-items-center gap-2 mt-3 mb-0">
                <FileArchive :size="18" /> <span>{{ fileName }}</span>
              </div>

              <div class="alert alert-warning mt-3 mb-0">
                <strong>{{ __('important') }}:</strong> {{ __('system_update_warning') }}
              </div>
            </div>
            <div class="card-footer d-flex justify-content-end">
              <b-button v-if="$isDemo != 1 || (login_user && login_user.id === 1)"
                @click="uploadUpdate" type="button" variant="primary"
                :disabled="isLoading || !file || !purchaseCode">
                <span v-if="isLoading"><b-spinner small label="Spinning"></b-spinner> {{ __('system_is_updating') }}</span>
                <span v-else>{{ __('upload_and_update') }}</span>
              </b-button>
            </div>
          </div>
        </div>

        <!-- Cache maintenance. -->
        <div class="col-12 col-md-6">
          <div class="card">
            <div class="card-header">
              <h4 class="mb-0">{{ __('clear_cache') }}</h4>
            </div>
            <div class="card-body">
              <p class="text-muted mb-3">{{ __('clear_cache_hint') }}</p>
              <div class="d-flex flex-wrap gap-2">
                <span class="badge bg-light text-dark">cache:clear</span>
                <span class="badge bg-light text-dark">config:clear</span>
                <span class="badge bg-light text-dark">route:clear</span>
                <span class="badge bg-light text-dark">view:clear</span>
              </div>
            </div>
            <div class="card-footer d-flex justify-content-end">
              <b-button @click="clearCache" type="button" variant="primary" :disabled="isClearingCache">
                <b-spinner v-if="isClearingCache" small label="Spinning"></b-spinner>
                {{ __('clear_cache') }}
              </b-button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Blocking updating modal: no close, no cancel, no backdrop/esc dismiss. -->
    <b-modal v-model="isLoading" centered :no-close-on-backdrop="true" :no-close-on-esc="true"
      :no-header-close="true" :no-header="true" :no-footer="true">
      <div class="text-center py-4">
        <b-spinner variant="primary" style="width: 3rem; height: 3rem;" label="Spinning"></b-spinner>
        <h5 class="mt-3 mb-1">{{ __('system_is_updating') }}</h5>
        <p class="text-muted mb-0">{{ __('do_not_close_this_window') }}</p>
      </div>
    </b-modal>
  </div>
</template>
<script>
import axios from "axios";
import { ArrowLeft, FileArchive } from 'lucide-vue-next';
import Auth from '../../Auth.js';

export default {
  components: { ArrowLeft, FileArchive },
  data: function () {
    return {
      login_user: Auth.user,
      isLoading: false,
      isClearingCache: false,
      file: null,
      fileName: '',
      purchaseCode: '',
    };
  },
  methods: {
    onFile(e) {
      const f = e.target.files && e.target.files[0];
      this.file = f || null;
      this.fileName = f ? f.name : '';
    },
    uploadUpdate() {
      if (!this.file) return;
      if (!this.purchaseCode) {
        this.showError(__('enter_the_purchase_code'));
        return;
      }
      if (!/\.zip$/i.test(this.file.name)) {
        this.showError(__('please_upload_a_valid_zip_file'));
        return;
      }
      this.$swal.fire({
        title: __('are_you_sure'),
        text: __('system_update_warning'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: __('ok'),
        cancelButtonText: __('cancel'),
        confirmButtonColor: window.adminThemeColor || '#435ebe',
        cancelButtonColor: '#d33',
      }).then(result => {
        if (!result.value) return;
        this.isLoading = true;
        const fd = new FormData();
        fd.append('update_file', this.file);
        fd.append('purchase_code', this.purchaseCode);
        axios.post(this.$apiUrl + '/store_settings/system_update', fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        }).then(response => {
          const data = response.data;
          if (data.status === 1) {
            this.showMessage('success', data.message || __('system_updated_successfully'));
            setTimeout(() => window.location.reload(), 2000);
          } else {
            this.showError(data.message || __('something_went_wrong'));
            this.isLoading = false;
          }
        }).catch(error => {
          this.isLoading = false;
          this.showError(error?.response?.data?.message || error?.message || __('something_went_wrong'));
        });
      });
    },
    clearCache() {
      this.$swal.fire({
        title: __('are_you_sure'),
        text: __('clear_cache_confirm'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: __('ok'),
        cancelButtonText: __('cancel'),
        confirmButtonColor: window.adminThemeColor || '#435ebe',
        cancelButtonColor: '#d33',
      }).then(result => {
        if (!result.value) return;
        this.isClearingCache = true;
        axios.get(this.$apiUrl + '/clear').then(response => {
          const data = response.data;
          if (data.status === 1) {
            this.showMessage('success', data.message || __('cache_cleared_successfully'));
            setTimeout(() => window.location.reload(), 1500);
          } else {
            this.showError(data.message || __('something_went_wrong'));
            this.isClearingCache = false;
          }
        }).catch(error => {
          this.isClearingCache = false;
          this.showError(error?.request?.statusText || error?.message || __('something_went_wrong'));
        });
      });
    },
  },
};
</script>

<style scoped>
.page-content-wrapper {
  min-height: calc(95vh - 200px);
  display: flex;
  flex-direction: column;
}

.page-content {
  flex: 1;
  padding-bottom: 2rem;
}

.card {
  margin-bottom: 2rem;
}

@media (min-height: 600px) {
  .page-content-wrapper {
    min-height: calc(95vh - 150px);
  }
}
</style>
