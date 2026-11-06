<template>
  <b-modal ref="my-modal" :title="modal_title" @hide="onModalHide" @hidden="$emit('modalClose')" scrollable centered no-close-on-backdrop no-fade static size="lg">
    <template #footer>
      <b-button variant="primary" @click="$refs['dummy_submit'].click()" :disabled="isLoading">
        {{ __('save') }}
        <b-spinner v-if="isLoading" small></b-spinner>
      </b-button>
      <b-button variant="secondary" @click="hideModal">{{ __('cancel') }}</b-button>
    </template>

    <form ref="my-form" @submit.prevent="saveRecord" novalidate>
      <!-- Live-usage warning: this attribute is already on products. -->
      <div v-if="attributeInUse" class="alert alert-warning d-flex gap-2 py-2 px-3 small mb-3">
        <TriangleAlert :size="18" class="flex-shrink-0" style="margin-top:1px" />
        <div>
          <div class="fw-bold">{{ __('attribute_in_use') }}</div>
          <div>{{ usageWarningText }}</div>
        </div>
      </div>

      <b-tabs v-if="languages.length" v-model="activeTab" content-class="mt-3" :nav-class="languages.length <= 1 ? 'd-none' : null">
        <b-tab v-for="lang in languages" :key="lang.id" :title="lang.name" :active="lang.is_default == 1">
          <div class="row">
            <div class="form-group col-md-6">
              <label>{{ __('name') }}</label>
              <i class="text-danger" v-if="lang.is_default">*</i>
              <input type="text" class="form-control" v-model="form[lang.id].name" :placeholder="__('enter_name')" :required="lang.is_default ? true : undefined">
            </div>

            <div class="form-group col-md-6" v-if="id && lang.is_default">
              <label>{{ __('status') }}</label>
              <div class="text-left mt-1">
                <div class="btn-group btn-group-toggle" role="group">
                  <label class="btn btn-outline-primary" :class="{ active: status == 0, disabled: attributeInUse }">
                    <input type="radio" :value="0" v-model.number="status" autocomplete="off" :disabled="attributeInUse"> {{ __('deactivate') }}
                  </label>
                  <label class="btn btn-outline-primary" :class="{ active: status == 1 }">
                    <input type="radio" :value="1" v-model.number="status" autocomplete="off"> {{ __('activate') }}
                  </label>
                </div>
                <small v-if="attributeInUse" class="text-muted d-block mt-1">
                  {{ __('cannot_deactivate_attribute_in_use') || 'This attribute is used by existing products and cannot be deactivated.' }}
                </small>
              </div>
            </div>
          </div>

          <hr>
          <h6>{{ __('values') }}</h6>
          <p class="text-muted small" v-if="!lang.is_default">{{ __('add_or_translate_values') }}</p>

          <div class="form-group">
            <label>{{ __('value') }}<i class="text-danger" v-if="lang.is_default">*</i></label>
            <textarea class="form-control" rows="3" v-model="valuesText[lang.id]" :placeholder="__('enter_comma_separated_values')"></textarea>
            <small class="text-muted">{{ __('enter_comma_separated_values') }}</small>
            <!-- Values already on product variants can be renamed but not removed. -->
            <small v-if="lang.is_default && inUseValueLabels.length" class="text-warning d-block mt-1">
              {{ __('values_in_use_cannot_be_removed') || 'These values are used by products and cannot be removed:' }}
              <strong>{{ inUseValueLabels.join(', ') }}</strong>
            </small>
          </div>
        </b-tab>

        <!-- Translate control, inline with the language tabs. -->
        <template #tabs-end>
          <li class="nav-item ms-auto d-flex align-items-center">
            <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId" :busy="translating"
              :progress="translateProgress" @translate="runTranslate" />
          </li>
        </template>
      </b-tabs>

      <button ref="dummy_submit" style="display:none;"></button>
    </form>
  </b-modal>
</template>

<script>
import axios from 'axios';
import { TriangleAlert } from 'lucide-vue-next';
import TranslationHelper from '../../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../../mixins/UnsavedChanges.js';

export default {
  mixins: [TranslationHelper, UnsavedChanges],
  components: { TriangleAlert },
  props: ['record'],
  data() {
    return {
      id: null,
      status: 1,
      languages: [],
      defaultLanguageId: null,
      activeTab: 0,
      form: {},
      valuesText: {},
      initialFilled: {},
      defaultValueIds: [],
      isLoading: false,
      translatableFields: ['name'],
      // How many live products/variants use this attribute (edit mode only).
      usage: { product_count: 0, variant_count: 0, values: {} },
    };
  },
  watch: {
    record: {
      immediate: true,
      deep: true,
      handler(newVal) {
        if (newVal && newVal.id) {
          this.id = newVal.id;
          if (this.languages.length > 0) this.loadWithTranslations();
        } else {
          this.id = null;
          this.resetForm();
        }
      },
    },
  },
  computed: {
    modal_title() { return this.id ? __('edit_attribute') : __('add_attribute'); },
    attributeInUse() { return this.id && this.usage.product_count > 0; },
    inUseValueLabels() {
      if (!this.attributeInUse) return [];
      const vals = (this.form[this.defaultLanguageId] && this.form[this.defaultLanguageId].values) || [];
      const usageMap = this.usage.values || {};
      return vals
        .filter(v => v && v.id && Number(usageMap[v.id] || 0) > 0)
        .map(v => v.value)
        .filter(v => v && String(v).trim() !== '');
    },
    usageWarningText() {
      // "... used by N product(s) across M variant(s). Renaming a value updates it
      //  everywhere; removing a value deletes it from those variants."
      const tpl = __('attribute_in_use_warning') || 'This attribute is used by :products product(s) across :variants variant(s). Renaming a value updates it on all of them; removing a value will delete it from those variants.';
      return tpl.replace(':products', this.usage.product_count).replace(':variants', this.usage.variant_count);
    },
  },
  methods: {
    // Tracked state for the UnsavedChanges guard (warn before leaving with edits).
    formState() {
      return { form: this.form, valuesText: this.valuesText, status: this.status };
    },
  
    onModalHide(bvEvt) {
      if (this._ucAllowClose) { this._ucAllowClose = false; return; }
      if (!this.isFormDirty) return;
      bvEvt.preventDefault();
      this._ucConfirmLeave().then(ok => {
        if (ok) { this._ucAllowClose = true; this.$refs['my-modal'].hide(); }
      });
    },
    resetForm() {
      this.form = {};
      this.valuesText = {};
      this.initialFilled = {};
      this.defaultValueIds = [];
      this.status = 1;
      this.activeTab = 0;
      this.languages.forEach(l => {
        this.form[l.id] = { name: '', values: [] };
        this.valuesText[l.id] = '';
      });
    },
    // Split comma-separated text into trimmed, non-empty values,
    // mapping each onto its existing id positionally (keeps translation/FK linking).
    parseValues(langId) {
      const parts = (this.valuesText[langId] || '').split(',').map(s => s.trim()).filter(s => s !== '');
      const existing = this.form[langId] && Array.isArray(this.form[langId].values) ? this.form[langId].values : [];
      const byText = new Map(existing.map(v => [String(v.value).trim(), v.id]));
      return parts.map(value => ({ id: byText.has(value) ? byText.get(value) : null, value }));
    },
    // Values payload for a language. Default owns the canonical set (blanks
    // dropped — they must not create empty values). For a non-default language
    // we send every existing value id positionally, keeping blanks so the
    // backend can DELETE a translation the admin cleared.
    buildValuesPayload(langId) {
      if (Number(langId) === Number(this.defaultLanguageId)) return this.parseValues(langId);
      let existing = this.form[langId] && Array.isArray(this.form[langId].values) ? this.form[langId].values : [];
      // On create the form has no value ids yet — fall back to the ids the default
      // save just created, so a single (comma-less) translation still attaches.
      if (!existing.length && this.defaultValueIds.length) {
        existing = this.defaultValueIds.map(id => ({ id }));
      }
      const parts = (this.valuesText[langId] || '').split(',').map(s => s.trim());
      return existing.map((v, i) => ({ id: v.id, value: parts[i] !== undefined ? parts[i] : '' }));
    },
   
    async fetchDefaultValueIds(attrId) {
      try {
        const res = await axios.get(this.$apiUrl + '/attributes', { params: { id: attrId } });
        const row = Array.isArray(res.data.data) ? res.data.data[0] : res.data.data;
        const vals = row && Array.isArray(row.values) ? row.values : [];
        this.defaultValueIds = vals.map(v => v.id);
      } catch (e) {
        this.defaultValueIds = [];
      }
    },
    showModal() { this.$refs['my-modal'].show(); },
    hideModal() { this.$refs['my-modal'].hide(); },
    initializeForm() {
      this.languages.forEach(l => {
        if (!this.form[l.id]) this.form[l.id] = { name: '', values: [] };
        if (this.valuesText[l.id] === undefined) this.valuesText[l.id] = '';
      });
    },
    loadLanguages() {
      return axios.get(this.$apiUrl + '/active_languages').then(res => {
        this.languages = res.data.data;
        const def = this.languages.find(l => l.is_default);
        this.defaultLanguageId = def?.id || null;
        this.initializeForm();
        if (this.id) return this.loadWithTranslations();
      });
    },
    // Warn the operator when the attribute is already live on products.
    fetchUsage() {
      this.usage = { product_count: 0, variant_count: 0, values: {} };
      if (!this.id) return;
      axios.get(this.$apiUrl + '/attributes/usage', { params: { id: this.id } })
        .then(res => { this.usage = res.data.data || this.usage; })
        .catch(() => {});
    },
    loadWithTranslations() {
      if (!this.id) return;
      if (!this.languages.length) return this.loadLanguages();
      this.fetchUsage();
      return axios.get(this.$apiUrl + '/attributes', { params: { id: this.id } }).then(res => {
        const row = Array.isArray(res.data.data) ? res.data.data[0] : res.data.data;
        if (!row) return;
        this.status = row.status;
        const values = Array.isArray(row.values) ? row.values : [];

        this.languages.forEach(lang => {
          const tr = Array.isArray(row.translations) ? row.translations.find(t => t.language_id === lang.id) : null;
          const name = tr && tr.name && tr.name.trim() !== '' ? tr.name : (lang.is_default ? (row.name || '') : '');
          const valuesForLang = values.map(v => {
            const vt = Array.isArray(v.translations) ? v.translations.find(t => t.language_id === lang.id) : null;
            const valueLabel = vt && vt.value && vt.value.trim() !== '' ? vt.value : (lang.is_default ? (v.value || '') : '');
            return { id: v.id, value: valueLabel };
          });
          this.form[lang.id] = { name, values: valuesForLang };
          this.valuesText[lang.id] = valuesForLang.map(v => v.value).filter(v => v && v.trim() !== '').join(', ');
          // Remember which non-default languages arrived with a translation, so a
          // later full clear of that language is still sent (to remove it).
          const hadName = !!(name && name.trim() !== '');
          const hadValue = valuesForLang.some(v => v.value && v.value.trim() !== '');
          this.initialFilled[lang.id] = hadName || hadValue;
        });
      });
    },
    validateDefaultLanguage() {
      if (!this.defaultLanguageId) { this.showError(__('default_language_not_found')); return false; }
      const f = this.form[this.defaultLanguageId];
      if (!f.name || !f.name.trim()) {
        this.showError(__('please_fill_name_in_default_language'));
        const idx = this.languages.findIndex(l => l.id === this.defaultLanguageId);
        if (idx !== -1) this.activeTab = idx;
        return false;
      }
      const parsed = this.parseValues(this.defaultLanguageId);
      if (parsed.length === 0) {
        this.showError(__('at_least_one_value_required'));
        const idx = this.languages.findIndex(l => l.id === this.defaultLanguageId);
        if (idx !== -1) this.activeTab = idx;
        return false;
      }
      return true;
    },
    // Default-language value labels being REMOVED that are still live on product
    // variants. Removing them would delete them from those variants, so we block it.
    removedInUseValueLabels() {
      if (!this.attributeInUse) return [];
      const vals = (this.form[this.defaultLanguageId] && this.form[this.defaultLanguageId].values) || [];
      const usageMap = this.usage.values || {};
      const survivingIds = this.parseValues(this.defaultLanguageId).map(v => v.id).filter(Boolean);
      return vals
        .filter(v => v && v.id && Number(usageMap[v.id] || 0) > 0 && !survivingIds.includes(v.id))
        .map(v => (v.value && String(v.value).trim() !== '') ? v.value : ('#' + v.id));
    },
    // Hard guard: an in-use attribute and its in-use values are protected from removal.
    validateInUseProtections() {
      const toDefaultTab = () => {
        const idx = this.languages.findIndex(l => l.id === this.defaultLanguageId);
        if (idx !== -1) this.activeTab = idx;
      };
      const removed = this.removedInUseValueLabels();
      if (removed.length) {
        const tpl = __('cannot_remove_values_in_use') || 'These values are used by product variants and cannot be removed: :values';
        this.showError(tpl.replace(':values', removed.join(', ')));
        toDefaultTab();
        return false;
      }
      if (this.attributeInUse && Number(this.status) === 0) {
        this.showError(__('cannot_deactivate_attribute_in_use') || 'This attribute is used by existing products and cannot be deactivated.');
        toDefaultTab();
        return false;
      }
      return true;
    },
    saveRecord() {
      if (!this.validateDefaultLanguage()) return;
      if (!this.validateInUseProtections()) return;
      this.performSave();
    },
    performSave() {
      const isUpdate = !!this.id;
      this.isLoading = true;

      const toSave = [];
      const def = this.languages.find(l => l.is_default);
      if (def) toSave.push(def);
      this.languages.forEach(l => {
        if (l.is_default) return;
        // On update, send every non-default language so a cleared name/value is
        // reconciled (removed) server-side. On create, only send languages that
        // actually have input — the backend rejects non-default on create anyway.
        const f = this.form[l.id];
        const hasName = f.name && f.name.trim() !== '';
        const hasValue = (this.valuesText[l.id] || '').trim() !== '';
        if (hasName || hasValue || this.initialFilled[l.id]) toSave.push(l);
      });

      const sequential = async () => {
        let attrId = this.id;
        const wasCreate = !this.id;
        for (const lang of toSave) {

          if (!lang.is_default && wasCreate && attrId && !this.defaultValueIds.length) {
            await this.fetchDefaultValueIds(attrId);
          }
          const f = this.form[lang.id];
          const payload = {
            language_id: lang.id,
            name: f.name,
            values: this.buildValuesPayload(lang.id),
          };
          if (lang.is_default) {
            payload.status = this.status;
          }
          if (attrId) payload.id = attrId;

          const url = attrId ? this.$apiUrl + '/attributes/update' : this.$apiUrl + '/attributes/save';
          const res = await axios.post(url, payload);
          if (!attrId && res.data.data?.id) attrId = res.data.data.id;
        }
        return attrId;
      };

      sequential().then(async (attrId) => {
        const msg = isUpdate ? __('attribute_updated_successfully') : __('attribute_saved_successfully');
        this.$emit('saved', msg, attrId);
        this.id = attrId;
        await this.loadWithTranslations();
        // Mark clean so closing after save doesn't trip the unsaved-changes guard.
        this.captureFormBaseline();
        this.hideModal();
      }).finally(() => { this.isLoading = false; });
    },
  },
  mounted() {
    this.resetForm();
    // Show only once languages (and translations for edit) are loaded — avoids
    // the modal opening empty then popping content in.
    Promise.resolve(this.loadLanguages())
      // Data loaded — snapshot the clean baseline for the unsaved-changes guard.
      .then(() => this.captureFormBaseline())
      .finally(() => this.showModal());
  },
};
</script>
