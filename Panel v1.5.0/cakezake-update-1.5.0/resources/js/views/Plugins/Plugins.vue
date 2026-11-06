<template>
  <div class="page-content-wrapper">
    <div class="page-heading">
      <div class="page-head">
        <h3 class="page-head-title">{{ __('plugins') }}</h3>
        <span v-if="coreVersion" class="badge rounded-pill bg-light text-dark ms-2">
          {{ __('version') + ' ' + coreVersion }}
        </span>
      </div>
    </div>

    <div class="page-content">
      <!-- The master switch is off: nothing boots, so say so before anything else. -->
      <div v-if="!pluginsEnabled" class="alert alert-warning d-flex align-items-start gap-2">
        <TriangleAlert :size="18" class="flex-shrink-0 mt-1" />
        <div>
          <strong>{{ __('plugins_are_switched_off') }}</strong>
          <div class="small">{{ __('plugins_switched_off_hint') }}</div>
        </div>
      </div>

      <div v-if="isLoading" class="text-center py-5">
        <b-spinner variant="primary" label="Spinning"></b-spinner>
      </div>

      <template v-else>
        <!-- Installed -->
        <h5 class="mb-3">{{ __('installed_plugins') }}</h5>

        <div v-if="!installed.length" class="card">
          <div class="card-body text-center py-5">
            <!-- An svg is inline, so text-center alone leaves it wherever the line starts. -->
            <div class="d-flex justify-content-center mb-2">
              <PackageOpen :size="40" class="text-muted" />
            </div>
            <h6 class="mb-1">{{ __('no_plugins_installed_yet') }}</h6>
            <p class="text-muted mb-0">{{ __('no_plugins_installed_hint') }}</p>
          </div>
        </div>

        <div v-else class="row align-items-stretch">
          <div class="col-12 col-xl-6 d-flex" v-for="plugin in installed" :key="plugin.slug">
            <div class="card plugin-card h-100" :class="{ 'border-danger': isBroken(plugin) }">
              <div class="card-body">
                <div class="d-flex align-items-start gap-3">
                  <div class="plugin-icon">
                    <component :is="iconFor(plugin)" :size="22" />
                  </div>

                  <div class="flex-grow-1">
                    <div class="d-flex align-items-center flex-wrap gap-2">
                      <h5 class="mb-0">{{ plugin.name }}</h5>
                      <span class="badge bg-light text-dark">v{{ plugin.version }}</span>
                      <span class="badge" :class="statusClass(plugin)">{{ __(plugin.status) }}</span>
                      <span class="badge" :class="licenceClass(plugin)">
                        {{ __('licence') }}: {{ __(plugin.licence_state) }}
                      </span>
                      <span v-if="plugin.type" class="badge bg-light text-dark">{{ __(plugin.type) }}</span>
                    </div>

                    <div class="small text-muted mt-1">
                      <span v-if="plugin.purchase_code_last4">
                        {{ __('purchase_code') }}: ****{{ plugin.purchase_code_last4 }}
                      </span>
                      <span v-if="plugin.licence_verified_at" class="ms-2">
                        {{ __('last_verified') }}: {{ $filters.formatDateTime(plugin.licence_verified_at) }}
                      </span>
                    </div>

                    <!-- Problems worth acting on, one line each. -->
                    <div v-if="!plugin.files_present" class="alert alert-danger py-1 px-2 mt-2 mb-0 small">
                      {{ __('plugin_files_are_missing_reinstall_it') }}
                    </div>
                    <div v-else-if="!plugin.core_compatible" class="alert alert-warning py-1 px-2 mt-2 mb-0 small">
                      {{ __('plugin_is_not_compatible_with_this_core_version') }}
                      <span v-if="plugin.core_min">({{ __('requires') }} {{ plugin.core_min }}+)</span>
                    </div>
                    <div v-else-if="plugin.broken_reason" class="alert alert-warning py-1 px-2 mt-2 mb-0 small">
                      {{ __(plugin.broken_reason) }}
                    </div>
                    <div v-if="plugin.licence_state === 'grace' && plugin.grace_until"
                      class="alert alert-warning py-1 px-2 mt-2 mb-0 small">
                      {{ __('licence_grace_until') }}: {{ $filters.formatDateTime(plugin.grace_until) }}
                    </div>
                    <div v-if="plugin.licence_message" class="small text-danger mt-1">{{ plugin.licence_message }}</div>
                    <div v-if="plugin.update_available" class="alert alert-info py-1 px-2 mt-2 mb-0 small">
                      {{ __('plugin_update_available') }}: v{{ plugin.latest_version }}
                    </div>
                  </div>

                  <!-- Enable / disable. -->
                  <div class="form-check form-switch ms-2" v-if="$can('manage_plugins')">
                    <input type="checkbox" class="form-check-input" :checked="plugin.enabled"
                      :disabled="busy === plugin.slug" @change="toggle(plugin)">
                  </div>
                </div>
              </div>

              <!-- No documentation link here: an installed plugin's reading is done. The
                   catalogue card below still carries one, where it helps someone decide. -->
              <div class="card-footer d-flex flex-wrap gap-2 justify-content-end mt-auto">
                <b-button v-if="plugin.has_settings" size="sm" variant="outline-primary"
                  :to="'/plugins/' + plugin.slug">
                  {{ __('settings') }}
                </b-button>
                <b-button v-if="$can('manage_plugins')" size="sm" variant="outline-danger"
                  :disabled="busy === plugin.slug" @click="uninstall(plugin)">
                  {{ __('uninstall') }}
                </b-button>
              </div>
            </div>
          </div>
        </div>

        <!-- Catalogue -->
        <h5 class="mb-3 mt-2">{{ __('available_plugins') }}</h5>
        <p class="text-muted small mt-n2">{{ __('available_plugins_hint') }}</p>

        <div class="row">
          <div class="col-12 col-md-6 col-xl-4" v-for="item in available" :key="item.slug">
            <div class="card h-100">
              <div class="card-body">
                <div class="d-flex align-items-start gap-3">
                  <div class="plugin-icon">
                    <component :is="iconFor(item)" :size="22" />
                  </div>
                  <div class="flex-grow-1">
                    <div class="d-flex align-items-center flex-wrap gap-2">
                      <h6 class="mb-0">{{ item.name }}</h6>
                      <span v-if="item.is_installed" class="badge bg-success">{{ __('installed') }}</span>
                    </div>
                    <p class="text-muted small mb-2 mt-1">{{ __(item.tagline) }}</p>
                    <ul class="plugin-highlights small text-muted mb-0">
                      <li v-for="point in (item.highlights || [])" :key="point">{{ __(point) }}</li>
                    </ul>
                    <div v-if="!item.core_compatible" class="alert alert-warning py-1 px-2 mt-2 mb-0 small">
                      {{ __('plugin_requires_a_newer_core_version') }} ({{ item.core_min }}+)
                    </div>
                    <div v-else-if="item.update_available" class="alert alert-info py-1 px-2 mt-2 mb-0 small">
                      {{ __('plugin_update_available') }}: v{{ item.version }}
                    </div>
                    <!-- Uninstalled with its data kept: installing again resumes rather
                         than starting empty, which is worth saying before they upload. -->
                    <div v-else-if="item.has_retained_data" class="alert alert-info py-1 px-2 mt-2 mb-0 small">
                      {{ __('plugin_data_from_a_previous_install_is_kept') }}
                    </div>
                  </div>
                </div>
              </div>
              <div class="card-footer d-flex flex-wrap gap-2 justify-content-end mt-auto">
                <b-button v-if="item.docs_url" size="sm" variant="outline-secondary"
                  :href="item.docs_url" target="_blank" rel="noopener">{{ __('documentation') }}</b-button>
                <b-button v-if="item.buy_url && !item.is_installed" size="sm" variant="outline-primary"
                  :href="item.buy_url" target="_blank" rel="noopener">{{ __('buy_plugin') }}</b-button>
                <b-button v-if="$can('manage_plugins')" size="sm" variant="primary"
                  :disabled="!item.core_compatible"
                  :title="item.core_compatible ? '' : __('plugin_requires_a_newer_core_version')"
                  @click="openInstall(item)">
                  {{ item.is_installed ? __('upload_update') : __('install') }}
                </b-button>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- Install / update -->
    <b-modal v-model="installModal" :title="__('install_plugin')" centered :no-close-on-backdrop="installing"
      :no-close-on-esc="installing" :no-footer="true">
      <p class="text-muted small">{{ __('install_plugin_hint') }}</p>
      <!-- Opened from a card: name the plugin, so a mismatched zip is obvious before upload. -->
      <p v-if="installTarget" class="small mb-2">
        <strong>{{ installTarget.name }}</strong>
      </p>

      <div class="form-group">
        <label class="small">{{ __('purchase_code') }}</label>
        <input type="text" v-model.trim="form.purchase_code" class="form-control" autocomplete="off"
          :placeholder="__('enter_the_purchase_code')">
      </div>

      <div class="form-group mt-3">
        <label class="small">{{ __('plugin_package_zip') }}</label>
        <input ref="fileInput" type="file" accept=".zip" class="form-control" @change="onFile">
        <small class="text-muted d-block mt-1">{{ __('plugin_package_name_hint') }}</small>
      </div>

      <div v-if="form.fileName" class="alert alert-light border d-flex align-items-center gap-2 mt-3 mb-0">
        <FileArchive :size="18" /> <span>{{ form.fileName }}</span>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4">
        <b-button variant="outline-secondary" :disabled="installing" @click="installModal = false">
          {{ __('cancel') }}
        </b-button>
        <b-button variant="primary" :disabled="installing || !form.file || !form.purchase_code" @click="install()">
          <b-spinner v-if="installing" small label="Spinning"></b-spinner>
          {{ installing ? __('installing') : __('install') }}
        </b-button>
      </div>
    </b-modal>
  </div>
</template>

<script>
import axios from 'axios';
import {
  FileArchive, PackageOpen, Package, Truck, CreditCard,
  MessageSquareText, TriangleAlert,
} from 'lucide-vue-next';
import { markRaw } from 'vue';

/** Catalogue icon names → components, so the static file stays plain data. */
const ICONS = {
  truck: markRaw(Truck),
  'credit-card': markRaw(CreditCard),
  message: markRaw(MessageSquareText),
  package: markRaw(Package),
};

export default {
  name: 'Plugins',
  components: { FileArchive, PackageOpen, TriangleAlert },
  data() {
    return {
      isLoading: true,
      installing: false,
      installTarget: null,   // the card the dialog was opened from, if any
      installModal: false,
      busy: null,          // slug currently being acted on
      busyAction: null,    // 'toggle' | 'licence' | 'uninstall'
      installed: [],
      available: [],
      coreVersion: '',
      pluginsEnabled: true,
      maxZipKb: 102400,
      form: { purchase_code: '', file: null, fileName: '' },
    };
  },
  mounted() {
    this.fetch();
  },
  methods: {
    fetch() {
      this.isLoading = true;
      axios.get(this.$apiUrl + '/plugins').then(res => {
        const data = res.data;
        if (data.status === 1) {
          this.apply(data.data);
        } else {
          this.showError(data.message || __('something_went_wrong'));
        }
      }).catch(err => {
        this.showError(err?.response?.data?.message || err?.message || __('something_went_wrong'));
      }).finally(() => {
        this.isLoading = false;
      });
    },
    apply(data) {
      this.installed = data.installed || [];
      this.available = data.available || [];
      if (data.core_version !== undefined) this.coreVersion = data.core_version;
      if (data.enabled !== undefined) this.pluginsEnabled = !!data.enabled;
      if (data.max_zip_kb) this.maxZipKb = data.max_zip_kb;
    },
    iconFor(plugin) {
      return ICONS[plugin.icon] || ICONS[plugin.type === 'shipping' ? 'truck' : 'package'] || ICONS.package;
    },
    isBroken(plugin) {
      return !plugin.files_present || !plugin.core_compatible || !!plugin.broken_reason;
    },
    statusClass(plugin) {
      return {
        active: 'bg-success',
        installed: 'bg-info',
        disabled: 'bg-secondary',
        broken: 'bg-danger',
        uninstalled: 'bg-secondary',
      }[plugin.status] || 'bg-secondary';
    },
    licenceClass(plugin) {
      return {
        valid: 'bg-success',
        grace: 'bg-warning text-dark',
        invalid: 'bg-danger',
        unverified: 'bg-secondary',
      }[plugin.licence_state] || 'bg-secondary';
    },

    /* ------------------------------------------------------------- install */

    /**
     * @param item the catalogue card that was clicked. Every plugin has a card, so the
     *             dialog is always opened for a known plugin and the upload is checked
     *             against that slug — a PayU zip cannot land on the Shiprocket card.
     */
    openInstall(item = null) {
      if (item && item.core_compatible === false) return;

      this.form = { purchase_code: '', file: null, fileName: '' };
      this.installTarget = item ? { slug: item.slug, name: item.name } : null;
      if (this.$refs.fileInput) this.$refs.fileInput.value = '';
      this.installModal = true;
    },
    onFile(e) {
      const f = e.target.files && e.target.files[0];
      this.form.file = f || null;
      this.form.fileName = f ? f.name : '';
    },
    install() {
      if (!this.form.file || !this.form.purchase_code) return;
      if (!/\.zip$/i.test(this.form.file.name)) {
        this.showError(__('please_upload_a_valid_zip_file'));
        return;
      }
      if (this.form.file.size / 1024 > this.maxZipKb) {
        this.showError(__('file_is_too_large'));
        return;
      }

      this.installing = true;
      const fd = new FormData();
      fd.append('plugin_file', this.form.file);
      fd.append('purchase_code', this.form.purchase_code);
      // Installing from a specific card means that plugin and no other.
      if (this.installTarget) fd.append('expected_slug', this.installTarget.slug);

      axios.post(this.$apiUrl + '/plugins/install', fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      }).then(res => {
        const data = res.data;
        if (data.status === 1) {
          this.apply(data.data || {});
          this.installModal = false;
          this.showMessage('success', data.message);
          return;
        }

        this.showError(data.message || __('something_went_wrong'));
      }).catch(err => {
        this.showError(err?.response?.data?.message || err?.message || __('something_went_wrong'));
      }).finally(() => {
        this.installing = false;
      });
    },

    /* -------------------------------------------------------- state changes */

    toggle(plugin) {
      const enable = !plugin.enabled;
      this.post('/plugins/toggle', { slug: plugin.slug, enabled: enable }, plugin.slug, 'toggle');
    },
    /* One confirm, no data question. A plugin owns no tables — core owns every one —
       so there is nothing of the shop's to keep or remove, and the answer the admin
       used to have to get right no longer exists to get wrong. */
    uninstall(plugin) {
      this.$swal.fire({
        title: __('are_you_sure'),
        text: __('uninstall_plugin_confirm'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: __('uninstall'),
        cancelButtonText: __('cancel'),
        confirmButtonColor: '#d33',
      }).then(result => {
        if (!result.isConfirmed) return;
        this.post('/plugins/uninstall', { slug: plugin.slug }, plugin.slug, 'uninstall');
      });
    },

    /** One place for the three state-changing calls: same busy flag, same refresh. */
    post(url, payload, slug, action, refetch = false) {
      this.busy = slug;
      this.busyAction = action;
      axios.post(this.$apiUrl + url, payload).then(res => {
        const data = res.data;
        if (data.status === 1) {
          if (refetch) {
            this.fetch();
          } else {
            this.apply(data.data || {});
          }
          this.showMessage('success', data.message);
        } else {
          this.showError(data.message || __('something_went_wrong'));
          this.fetch(); // the switch in the DOM no longer matches the server
        }
      }).catch(err => {
        this.showError(err?.response?.data?.message || err?.message || __('something_went_wrong'));
        this.fetch();
      }).finally(() => {
        this.busy = null;
        this.busyAction = null;
      });
    },
  },
};
</script>

<style scoped>
.page-content {
  padding-bottom: 2rem;
}

.card {
  margin-bottom: 1.5rem;
}

/* Two cards side by side carry different amounts of text — one plugin has an extra
   badge, another a warning line — so the card fills the row's height and the buttons
   sit on one line instead of floating up with the shorter card. */
.plugin-card {
  width: 100%;
}

.plugin-card>.card-body {
  flex: 1 1 auto;
}

.plugin-icon {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(67, 94, 190, .1);
  color: #435ebe;
  flex-shrink: 0;
}

.plugin-highlights {
  padding-left: 1.1rem;
  margin-bottom: 0;
}

.mt-n2 {
  margin-top: -.5rem;
}
</style>
