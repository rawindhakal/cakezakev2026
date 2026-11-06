<template>
  <div class="page-content-wrapper">
    <div class="page-heading">
      <div class="page-head">
        <h3 class="page-head-title">{{ plugin.name || __('plugin_settings') }}</h3>
        <span v-if="plugin.version" class="badge rounded-pill bg-light text-dark ms-2">v{{ plugin.version }}</span>
        <router-link to="/plugins" class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
          <ArrowLeft :size="16" /> {{ __('back') }}
        </router-link>
      </div>
    </div>

    <div class="page-content">
      <div v-if="isLoading" class="text-center py-5">
        <b-spinner variant="primary" label="Spinning"></b-spinner>
      </div>

      <template v-else>
        <!-- Nothing to configure, or configured somewhere else entirely. -->
        <div v-if="scope !== 'settings'" class="alert alert-info">
          {{ __('plugin_settings_live_elsewhere') }}
          <span v-if="scope === 'country'">{{ __('plugin_settings_in_country_form') }}</span>
        </div>

        <div v-else-if="!fields.length" class="card">
          <div class="card-body text-center py-5 text-muted">{{ __('this_plugin_has_no_settings') }}</div>
        </div>

        <div v-else class="card">
          <div class="card-header">
            <h4 class="mb-0">{{ __(group || 'settings') }}</h4>
          </div>

          <div class="card-body">
            <div class="row">
              <template v-for="field in fields" :key="field.key">
                <!-- A note is documentation, not an input. -->
                <div v-if="field.type === 'note'" class="col-12">
                  <div class="alert alert-light border small">{{ __(field.label) }}</div>
                </div>

                <div v-else class="form-group col-12 col-md-6">
                  <label :for="'f_' + field.key">
                    {{ __(field.label) }}
                    <span v-if="field.required" class="text-danger">*</span>
                  </label>

                  <!-- toggle -->
                  <div v-if="field.type === 'toggle'" class="form-check form-switch">
                    <input type="checkbox" true-value="1" false-value="0" class="form-check-input"
                      :id="'f_' + field.key" v-model="values[field.key]">
                  </div>

                  <!-- select -->
                  <select v-else-if="field.type === 'select'" class="form-select" :id="'f_' + field.key"
                    v-model="values[field.key]">
                    <option v-for="opt in normalizeOptions(field.options)" :key="opt.value" :value="opt.value">
                      {{ __(opt.label) }}
                    </option>
                  </select>

                  <!-- multiselect -->
                  <select v-else-if="field.type === 'multiselect'" class="form-select" multiple
                    :id="'f_' + field.key" v-model="values[field.key]">
                    <option v-for="opt in normalizeOptions(field.options)" :key="opt.value" :value="opt.value">
                      {{ __(opt.label) }}
                    </option>
                  </select>

                  <!-- textarea -->
                  <textarea v-else-if="field.type === 'textarea'" class="form-control" rows="3"
                    :id="'f_' + field.key" v-model="values[field.key]"
                    :placeholder="field.placeholder ? __(field.placeholder) : ''"></textarea>

                  <!-- One of this plugin's webhook URLs, shown where it belongs rather
                       than in a list at the bottom. Copy only — core owns the route. -->
                  <div v-else-if="field.type === 'webhook_url'" class="input-group">
                    <input type="text" class="form-control" :id="'f_' + field.key" readonly
                      :value="webhookUrlFor(field.action)">
                    <button class="btn btn-outline-secondary mb-0" type="button"
                      @click="copy(webhookUrlFor(field.action))">
                      <Copy :size="15" />
                    </button>
                  </div>

                  <template v-else-if="choiceFor(field)">
                    <div class="input-group">
                      <span class="input-group-text">{{ __('in_use') }}</span>
                      <input type="text" class="form-control" readonly :value="effectiveValue(field)">
                      <button class="btn btn-outline-secondary mb-0" type="button"
                        @click="copy(effectiveValue(field))">
                        <Copy :size="15" />
                      </button>
                    </div>

                    <div class="form-check form-switch mt-1">
                      <input type="checkbox" class="form-check-input" :id="'o_' + field.key"
                        :checked="overriding[field.key]" @change="toggleOverride(field, $event)">
                      <label class="form-check-label small" :for="'o_' + field.key">
                        {{ __('use_a_custom_url') }}
                      </label>
                    </div>

                    <input v-if="overriding[field.key]" :type="inputType(field)" class="form-control mt-1"
                      :id="'f_' + field.key" v-model="values[field.key]"
                      :placeholder="effectiveValue(field)">
                  </template>

                  <!-- a URL the admin copies out, never types in -->
                  <div v-else-if="field.type === 'readonly_url'" class="input-group">
                    <input type="text" class="form-control" :id="'f_' + field.key" readonly
                      :value="values[field.key]">
                    <button class="btn btn-outline-secondary" type="button" @click="copy(values[field.key])">
                      <Copy :size="15" />
                    </button>
                  </div>

                  <!-- text / password / number / email / url -->
                  <input v-else :type="inputType(field)" class="form-control" :id="'f_' + field.key"
                    v-model="values[field.key]" :autocomplete="field.secret ? 'new-password' : 'off'"
                    :placeholder="placeholderFor(field)">

                  <!-- Both, not one or the other: a field can need explaining AND
                       already hold a saved secret. -->
                  <small v-if="field.hint" class="text-muted d-block">{{ __(field.hint) }}</small>
                  <small v-if="field.secret && secretSet[field.key]" class="text-muted d-block">
                    {{ __('leave_blank_to_keep_the_saved_value') }}
                  </small>
                </div>
              </template>
            </div>

            <!-- Webhook URLs the admin has to paste at the provider. -->
            <div v-if="looseWebhooks.length" class="mt-2">
              <h6 class="mb-2">{{ __('webhook_urls') }}</h6>
              <div class="input-group mb-2" v-for="hook in looseWebhooks" :key="hook.action">
                <span class="input-group-text">{{ __(hook.label) }}</span>
                <input type="text" class="form-control" :value="hook.url" readonly>
                <button class="btn btn-outline-secondary mb-0" type="button" @click="copy(hook.url)">
                  <Copy :size="15" />
                </button>
              </div>
            </div>
          </div>

          <div class="card-footer d-flex justify-content-end">
            <b-button variant="primary" :disabled="isSaving" v-if="$can('manage_plugins')" @click="save()">
              <b-spinner v-if="isSaving" small label="Spinning"></b-spinner>
              {{ __('update') }}
            </b-button>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<script>
import axios from 'axios';
import { ArrowLeft, Copy } from 'lucide-vue-next';

/**
 * Renders whatever an plugin declares in its manifest.
 *
 * Plugins ship no JavaScript, so every plugin's settings page is this one component
 * driven by the field list the API returns.
 */
export default {
  name: 'PluginSettings',
  components: { ArrowLeft, Copy },
  data() {
    return {
      isLoading: true,
      isSaving: false,
      slug: this.$route.params.slug,
      plugin: {},
      scope: 'settings',
      group: '',
      fields: [],
      values: {},
      secretKeys: [],
      secretSet: {},
      webhooks: [],
      choices: {},
      overriding: {},
    };
  },
  computed: {
    looseWebhooks() {
      const placed = this.fields
        .filter(f => f.type === 'webhook_url' && f.action)
        .map(f => f.action);

      return this.webhooks.filter(h => !placed.includes(h.action));
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    /** The plugin's description of this field, when it computes one. */
    choiceFor(field) {
      return this.choices[field.key] || null;
    },
    /** What the plugin would use if this field were left empty. */
    effectiveValue(field) {
      const choice = this.choiceFor(field);
      if (!choice) return '';
      if (choice.value !== undefined) return choice.value;

      const selector = choice.depends_on ? this.values[choice.depends_on] : '';

      return (choice.values || {})[selector] || '';
    },
    /* Opening the box leaves it empty for a URL to be typed; closing it clears what was
       typed, which is what makes the plugin fall back to its own value. */
    toggleOverride(field, event) {
      const on = !!event.target.checked;
      this.overriding[field.key] = on;
      if (!on) {
        this.values[field.key] = '';
      }
    },
    webhookUrlFor(action) {
      return (this.webhooks.find(h => h.action === action) || {}).url || '';
    },
    fetch() {
      this.isLoading = true;
      axios.get(this.$apiUrl + '/plugins/settings', { params: { slug: this.slug } }).then(res => {
        const data = res.data;
        if (data.status !== 1) {
          this.showError(data.message || __('something_went_wrong'));
          this.$router.push('/plugins');
          return;
        }
        const d = data.data;
        this.plugin = { name: d.name, version: d.version };
        this.scope = d.scope || 'settings';
        this.group = d.group || '';
        this.fields = d.fields || [];
        this.secretKeys = d.secret_keys || [];
        this.secretSet = d.secret_set || {};
        this.webhooks = d.webhooks || [];
        this.choices = d.choices || {};
        this.values = this.seed(d.values || {});
        // A stored value means somebody already overrode this field, so show it open.
        this.overriding = {};
        Object.keys(this.choices).forEach(key => {
            this.overriding[key] = String(this.values[key] ?? '') !== '';
        });
      }).catch(err => {
        this.showError(err?.response?.data?.message || err?.message || __('something_went_wrong'));
      }).finally(() => {
        this.isLoading = false;
      });
    },

    /** Every declared key must exist on `values` or v-model cannot bind to it. */
    seed(stored) {
      const out = {};
      this.fields.forEach(f => {
        if (f.type === 'note') return;
        let value = stored[f.key];
        if (value === undefined || value === null) value = f.default ?? '';
        /* A select has no empty entry, so an empty value would display the first option
           while holding nothing — and save nothing. Settle it here instead. */
        if (f.type === 'select' && String(value) === '') {
          const options = this.normalizeOptions(f.options);
          value = f.default ?? (options.length ? options[0].value : '');
        }
        if (f.type === 'toggle') value = String(value === true || value === 1 || value === '1' ? 1 : 0);
        if (f.type === 'multiselect' && !Array.isArray(value)) {
          value = typeof value === 'string' && value !== '' ? value.split(',') : [];
        }
        out[f.key] = value;
      });

      return out;
    },
    normalizeOptions(options) {
      return (options || []).map(opt => (
        typeof opt === 'object' ? { value: opt.value, label: opt.label ?? opt.value } : { value: opt, label: opt }
      ));
    },
    inputType(field) {
      return ({ password: 'password', number: 'number', email: 'email', url: 'url' })[field.type] || 'text';
    },
    placeholderFor(field) {
      if (field.secret && this.secretSet[field.key]) return '••••••••';

      return field.placeholder ? __(field.placeholder) : '';
    },
    copy(text) {
      if (!text) return;
      navigator.clipboard?.writeText(text).then(() => this.showMessage('success', __('copied')));
    },
    save() {
      const payload = { ...this.values };

      // A multiselect goes back as a comma list, which is what the settings table holds.
      this.fields.forEach(f => {
        if (f.type === 'multiselect' && Array.isArray(payload[f.key])) {
          payload[f.key] = payload[f.key].join(',');
        }
      });

      this.isSaving = true;
      axios.post(this.$apiUrl + '/plugins/settings/save', { slug: this.slug, settings: payload })
        .then(res => {
          const data = res.data;
          if (data.status === 1) {
            this.showMessage('success', data.message);
            this.fetch(); // secrets come back masked, and defaults may have filled in
          } else {
            this.showError(data.message || __('something_went_wrong'));
          }
        })
        .catch(err => {
          this.showError(err?.response?.data?.message || err?.message || __('something_went_wrong'));
        })
        .finally(() => {
          this.isSaving = false;
        });
    },
  },
};
</script>

<style scoped>
.page-content {
  padding-bottom: 2rem;
}
</style>
