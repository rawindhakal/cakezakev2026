<template>
    <div class="list-page">
      <div class="page-head">
        <h3 class="page-head-title">{{ __('notification_templates') }}</h3>
        <router-link to="/settings"
          class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
          <ArrowLeft :size="16" /> {{ __('back') }}
        </router-link>
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

          <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="getTemplates()">
            <RefreshCw :class="{ 'is-spinning': isLoading }" />
          </button>
        </div>

        <MazerDatatable responsive
          :items="templates"
          :fields="fields"
          :filter="filter"
          :filter-included-fields="filterOn"
          v-model:sort-by="sortBy"
          v-model:sort-desc="sortDesc"
          :sort-direction="sortDirection"

          :busy="isLoading"
          stacked="md"
          show-empty
          small
        >
          <template #cell(type)="row">
          {{ row.item.label || row.item.type }}
          </template>
          <template #cell(message)="row">
          {{ row.item.message || '-' }}
          </template>
          <template #cell(actions)="row">
            <div class="list-actions">
              <button
                class="list-action-btn is-edit"
                v-b-tooltip.hover
                :title="__('edit')"
                @click="openEdit(row.item)"
              >
                <Pencil :size="15" />
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
            <span class="list-range">{{ __('total_records') }} : {{ totalRows }}</span>
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

      <app-edit-record v-if="editRecord" :record="editRecord" @modalClose="editRecord = null" @saved="onTemplateSaved"></app-edit-record>
    </div>
  </template>
  
  <script>
  import EditRecord from './Edit.vue';
  import { Search, RefreshCw, Pencil, ArrowLeft } from 'lucide-vue-next';

  export default {
    components: {
      'app-edit-record': EditRecord,
      Search, RefreshCw, Pencil, ArrowLeft,
    },
    data() {
      return {
        fields: [
          { key: 'id', label: __('id'), class: 'text-left', sortable: true, thStyle: { width: '5%' } },
          { key: 'type', label: __('type'), class: 'text-left', sortable: false, thStyle: { width: '20%' } },
          { key: 'message', label: __('message'), class: 'text-left', sortable: false, thStyle: { width: '65%' } },
          { key: 'actions', label: __('actions'), class: 'text-center', sortable: false, thStyle: { width: '10%' } },
        ],
        totalRows: 1,
        currentPage: 1,
        perPage: 10,
        pageOptions: this.$pageOptions,
        sortBy: 'id',
        sortDesc: false,
        sortDirection: 'asc',
        filter: null,
        filterOn: ['type'],
        templates: [],
        isLoading: false,
        editRecord: null,
      };
    },
    watch: {
      filter() {
        clearTimeout(this._searchTimer);
        this._searchTimer = setTimeout(() => {
          if (this.currentPage !== 1) this.currentPage = 1; else this.getTemplates();
        }, 400);
      },
      currentPage() {
        this.getTemplates();
      },
      perPage() {
        this.getTemplates();
      },
    },
    created() {
      this.getTemplates();
    },
    methods: {      getTemplates() {
        this.isLoading = true;
        const params = {
          offset: this.currentPage,
          limit: this.perPage,
          filter: this.filter || '',
        };
        axios.get(this.$apiUrl + '/notification_templates', { params }).then((response) => {
          this.isLoading = false;
          const data = response.data;
          this.templates = data.data || [];
          this.totalRows = data.total || 0;
        }).catch(() => {
          this.isLoading = false;
        });
      },
      openEdit(record) {
        this.editRecord = record;
      },
      onTemplateSaved() {
        this.editRecord = null;
        this.showMessage('success', this.__('notification_template_updated_successfully'));
        this.getTemplates();
      },
    },
  };
  </script>
  