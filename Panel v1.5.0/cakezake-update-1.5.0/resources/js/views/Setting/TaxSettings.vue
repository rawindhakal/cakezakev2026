<template>
    <div class="list-page">
        <div class="page-head">
            <div>
                <h3 class="page-head-title">{{ __('tax_settings') }}</h3>
                <p class="text-muted small mb-0">{{ __('tax_settings_hint') }}</p>
            </div>
            <router-link to="/settings" class="btn btn-outline-secondary d-inline-flex align-items-center gap-2">
                <ArrowLeft :size="15" /> {{ __('back') }}
            </router-link>
        </div>

        <!-- Two halves of one job: a category says what a product is, a rule says what
             a jurisdiction charges for it. Tabs keep them side by side, with Add on the
             same line — the embedded lists render no header of their own. -->
        <div class="tax-tabbar">
            <ul class="nav nav-tabs tax-tabs">
                <li class="nav-item">
                    <a class="nav-link" :class="{ active: tab === 'categories' }"
                        href="#" @click.prevent="setTab('categories')">
                        <Percent :size="15" /> {{ __('tax_categories') }}
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" :class="{ active: tab === 'rules' }"
                        href="#" @click.prevent="setTab('rules')">
                        <Scale :size="15" /> {{ __('tax_rules') }}
                    </a>
                </li>
            </ul>

            <button v-if="$can('tax_create')" type="button"
                class="btn btn-primary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap"
                @click="addRecord">
                <Plus :size="16" />
                <span>{{ __('add') }}</span>
            </button>
        </div>

        <!-- v-if, not v-show: each tab loads its own list, and the inactive one should
             not fetch or hold stale rows. -->
        <TaxCategories v-if="tab === 'categories'" ref="list" embedded />
        <TaxRules v-else ref="list" embedded />
    </div>
</template>

<script>
import { ArrowLeft, Percent, Scale, Plus } from 'lucide-vue-next';
import TaxCategories from '../Product/TaxCategories/TaxCategories.vue';
import TaxRules from '../Product/TaxRules/TaxRules.vue';

export default {
    name: 'TaxSettings',
    components: { ArrowLeft, Percent, Scale, Plus, TaxCategories, TaxRules },
    data() {
        return {
            // ?tab= keeps the choice through a reload and makes the tab linkable.
            tab: this.$route.query.tab === 'rules' ? 'rules' : 'categories',
        };
    },
    methods: {
        // The Add button belongs to the tab bar, but the form lives in whichever list
        // is mounted.
        addRecord() {
            this.$refs.list?.openCreate();
        },
        setTab(tab) {
            if (this.tab === tab) return;
            this.tab = tab;
            this.$router.replace({ query: { ...this.$route.query, tab } });
        },
    },
};
</script>

<style scoped>
/* Tabs and Add share one line, with the border running the full width beneath. */
.tax-tabbar {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 1rem;
    flex-wrap: wrap;
    border-bottom: 1px solid var(--app-card-border);
    margin-bottom: 1rem;
    padding-bottom: .35rem;
}
.tax-tabs {
    border-bottom: 0;
    margin-bottom: -.35rem;
    flex-wrap: wrap;
}
.tax-tabs .nav-link {
    display: inline-flex;
    align-items: center;
    gap: .4rem;
    border: 0;
    border-bottom: 2px solid transparent;
    color: var(--app-muted);
    font-weight: 600;
    font-size: .85rem;
}
.tax-tabs .nav-link.active {
    color: var(--bs-primary);
    border-bottom-color: var(--bs-primary);
    background: transparent;
}

</style>
