<template>
    <div class="zone-form">
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ isEdit ? __('edit_zone') : __('add_zone') }}</h3>
                <router-link to="/zones" class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <form @submit.prevent="saveZone" novalidate>

                <!-- Zone Details -->
                <div class="card">
                    <div class="card-body">
                        <h6 class="mb-1">{{ __('zone_details') }}</h6>
                        <small class="text-muted d-block mb-3">{{ __('identity_and_boundary_of_zone') }}</small>
                        <div class="row g-3">
                            <div class="col-md-3">
                                <label class="form-label">{{ __('zone_name') }} <span class="text-danger">*</span></label>
                                <input type="text" class="form-control" v-model="form.name" :placeholder="__('zone_name')" required>
                                <small class="text-muted">{{ __('unique_name_used_across_branches_and_reports') }}</small>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">{{ __('city') }}</label>
                                <input type="text" class="form-control" v-model="form.city" :placeholder="__('city')">
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">{{ __('state_region') }}</label>
                                <AppSelect v-if="regions.length" class="form-select" v-model="form.region_id"
                                    :options="regionOptions" :placeholder="__('state_region')" />
                                <input v-else type="text" class="form-control" v-model="form.state"
                                    :placeholder="__('state')">
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">{{ __('country') }} <span class="text-danger">*</span></label>
                                <AppSelect class="form-select" v-model="form.country_id" :options="countryOptions"
                                    :placeholder="__('select_country')" @update:model-value="onCountryChange" />
                                <small class="text-muted" v-if="selectedCountry">{{ __('currency') }}: {{ selectedCountry.currency }} ({{ selectedCountry.currency_code }})</small>
                            </div>
                        </div>

                        <hr class="my-4">
                        <h6 class="mb-1">{{ __('delivery_charge') }}</h6>
                        <small class="text-muted d-block mb-2">{{ __('charge_taxable_hint') }}</small>
                        <div class="row g-3 align-items-start delivery-tax-row">
                            <div class="col-md-3">
                                <label class="form-label d-block mb-1" for="dc-taxable">{{ __('is_taxable') }}</label>
                                <div class="form-check form-switch">
                                    <input class="form-check-input" type="checkbox" role="switch" id="dc-taxable"
                                        v-model="form.delivery_charge_is_taxable">
                                </div>
                            </div>
                            <template v-if="form.delivery_charge_is_taxable">
                                <div class="col-md-3">
                                    <label class="form-label d-block mb-1">{{ __('tax_category') }}</label>
                                    <AppSelect class="form-select" v-model="form.delivery_charge_tax_category_id"
                                        :options="taxCategoryOptions" :placeholder="__('tax_category')" />
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label d-block mb-1" for="dc-incl">{{ __('tax_included_in_amount') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch" id="dc-incl"
                                            v-model="form.delivery_charge_tax_included">
                                    </div>
                                </div>
                            </template>
                        </div>

                        <!-- Sales channel + status -->
                        <hr class="my-4">
                        <div class="row">
                            <div class="col-md-6 form-group">
                                <label>{{ __('sales_channel') }}</label>
                                <small class="text-muted d-block mb-2">
                                    {{ __('quick_distance_based_ecommerce_flat_slab_city_area') }}
                                </small>
                                <div class="btn-group btn-group-toggle" role="group">
                                    <label class="btn btn-outline-primary"
                                        :class="{ active: form.sales_channel === 'quick' }">
                                        <input type="radio" value="quick" v-model="form.sales_channel"
                                            autocomplete="off"> {{ __('quick') }}
                                    </label>
                                    <label class="btn btn-outline-primary"
                                        :class="{ active: form.sales_channel === 'ecommerce' }">
                                        <input type="radio" value="ecommerce" v-model="form.sales_channel"
                                            autocomplete="off"> {{ __('ecommerce') }}
                                    </label>
                                    <label class="btn btn-outline-primary"
                                        :class="{ active: form.sales_channel === 'both' }">
                                        <input type="radio" value="both" v-model="form.sales_channel"
                                            autocomplete="off"> {{ __('both') }}
                                    </label>
                                </div>
                                <small v-if="form.sales_channel === 'both'" class="text-muted d-block mt-1">
                                    {{ __('both_channels_share_one_boundary_hint') }}
                                </small>
                            </div>
                            <div class="col-md-6 form-group">
                                <label class="d-block">{{ __('status') }}</label>
                                <small class="text-muted d-block mb-2">{{ __('inactive_zones_not_considered_for_deliveries') }}</small>
                                <div class="btn-group btn-group-toggle" role="group">
                                    <label class="btn btn-outline-primary" :class="{ active: form.status == 0 }">
                                        <input type="radio" :value="0" v-model.number="form.status" autocomplete="off"> {{ __('deactivate') }}
                                    </label>
                                    <label class="btn btn-outline-primary" :class="{ active: form.status == 1 }">
                                        <input type="radio" :value="1" v-model.number="form.status" autocomplete="off"> {{ __('activate') }}
                                    </label>
                                </div>
                            </div>
                        </div>

                    </div>
                </div>

                <div>

                <!-- Channel switch: a 'both' zone configures each channel independently —
                     its own catchment and its own pricing. type="button" matters here:
                     these sit inside the form and would otherwise submit it. -->
                <div class="btn-group channel-tabs mb-3" role="group" v-if="servedChannels.length > 1">
                    <button type="button" class="btn" v-for="ch in servedChannels" :key="'tab-' + ch"
                        :class="activeChannelTab === ch ? 'btn-primary' : 'btn-outline-primary'"
                        @click="activeChannelTab = ch">
                        <component :is="ch === 'quick' ? 'Zap' : 'ShoppingBag'" :size="15" class="me-1" />
                        {{ ch === 'quick' ? __('quick') : __('ecommerce') }}
                    </button>
                </div>

                <div class="card" v-if="servesQuick && activeChannelTab === 'quick'">
                    <div class="card-body">
                        <h6 class="mb-1">{{ __('polygon_boundary') }} — {{ __('quick') }} <i class="text-danger">*</i></h6>
                        <small class="text-muted d-block mb-1">{{ __('quick_catchment_hint') }}</small>
                        <small class="text-warning d-block mb-2">
                            <i class="fa fa-exclamation-triangle me-1"></i>
                            {{ __('polygon_must_not_overlap_existing_zones') }}
                        </small>
                        <BoundaryMap :key="'mapq-' + mapKey" v-model="form.polygon_boundary_quick"
                            :reserved-areas="reservedAreas.quick" searchable
                            @place-selected="onPlaceSelected" />
                    </div>
                </div>

                <!-- Quick commerce settings -->
                <div class="card" v-if="servesQuick && activeChannelTab === 'quick'">
                    <div class="card-header">
                        <h5 class="card-title text-uppercase mb-0">{{ __('quick_commerce_settings') }}</h5>
                    </div>
                    <div class="card-body">

                        <!-- Distance calculation -->
                        <div class="border rounded p-3 mb-4">
                            <h6>{{ __('distance_calculation') }}</h6>
                            <small class="text-muted d-block mb-3">{{ __('distance_calc_hint') }}</small>
                            <div class="row">
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('distance_unit') }}</label>
                                    <AppSelect class="form-select" v-model="form.quick.distance_unit" :options="distance_unitOptions" :searchable="false" />
                                    <small class="text-muted">{{ __('base_distance_and_per_unit_charge_use_this_unit') }}</small>
                                </div>
                            </div>
                        </div>

                        <!-- Basic charges -->
                        <div class="border rounded p-3 mb-4">
                            <h6>{{ __('basic_charges') }}</h6>
                            <small class="text-muted d-block mb-3">{{ __('basic_charges_hint') }}</small>
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('base_delivery_charge') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="form.quick.base_delivery_charge"
                                        min="0" step="0.01">
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('base_distance') }} ({{ distanceUnitShort }})</label>
                                    <input type="number" class="form-control" v-model="form.quick.base_distance" min="0"
                                        step="0.01">
                                </div>
                            </div>
                        </div>

                        <!-- Distance-based charges -->
                        <div class="border rounded p-3 mb-4">
                            <h6>{{ __('distance_based_charges') }}</h6>
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('charge_per') }} {{ distanceUnitShort }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="form.quick.charge_per_km" min="0"
                                        step="0.01">
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('travel_time_per') }} {{ distanceUnitShort }} ({{ __('minutes') }})</label>
                                    <input type="number" class="form-control" v-model="form.quick.travel_time_per_km" min="0"
                                        step="0.01">
                                    <small class="text-muted">{{ __('used_to_estimate_delivery_eta') }}</small>
                                </div>
                            </div>
                        </div>

                        <!-- Order value rules -->
                        <div class="border rounded p-3 mb-4">
                            <h6>{{ __('order_value_rules') }}</h6>
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('minimum_order_amount') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="form.quick.minimum_order_amount"
                                        min="0" step="0.01">
                                    <small class="text-muted">{{ __('optional_block_checkout_below_this_amount') }}</small>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('free_delivery_above_amount') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="form.quick.free_delivery_above"
                                        min="0" step="0.01">
                                </div>
                            </div>
                        </div>

                        <!-- Language switcher (surge + additional charges) -->
                        <ul class="nav nav-tabs mb-3 align-items-center" v-if="languages.length > 1">
                            <li class="nav-item" v-for="(lang, idx) in languages" :key="lang.id">
                                <a class="nav-link" :class="{ active: activeLanguageTab === idx }" href="#"
                                    @click.prevent="activeLanguageTab = idx">
                                    {{ lang.name }}<span v-if="Number(lang.id) === Number(defaultLanguageId)" class="ms-1 text-primary"></span>
                                </a>
                            </li>
                            <!-- Translate control, inline with the language tabs. -->
                            <li class="nav-item ms-auto d-flex align-items-center">
                                <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                                    :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                            </li>
                        </ul>

                        <!-- Surge pricing -->
                        <div class="border rounded p-3 mb-4">
                            <h6>{{ __('surge_pricing') }}
                                <span class="badge bg-secondary ms-2">{{ __('optional') }}</span>
                            </h6>
                            <small class="text-muted d-block mb-2">{{ __('charge_refundable_hint') }}</small>
                            <div v-for="(s, i) in form.quick.surge_slots" :key="'surge-' + i"
                                class="row g-3 mb-3 align-items-end">
                                <div class="col-12 col-sm-6 col-md-4 col-lg-2">
                                    <label class="form-label">{{ __('label') }}</label>
                                    <input type="text" class="form-control"
                                        :value="surgeLabelFor(i)"
                                        @input="setSurgeLabel(i, $event.target.value)"
                                        :placeholder="__('label')">
                                </div>
                                <div class="col-6 col-sm-3 col-md-2 col-lg-2">
                                    <label class="form-label">{{ __('slot_start') }}</label>
                                    <TimePicker v-model="s.start" :disabled="!isCurrentDefaultLang" />
                                </div>
                                <div class="col-6 col-sm-3 col-md-2 col-lg-2">
                                    <label class="form-label">{{ __('slot_end') }}</label>
                                    <TimePicker v-model="s.end" :disabled="!isCurrentDefaultLang" />
                                </div>
                                <div class="col-6 col-sm-4 col-md-3 col-lg-2">
                                    <label class="form-label">{{ __('charge') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="s.charge" min="0"
                                        step="0.01" :disabled="!isCurrentDefaultLang">
                                </div>
                                <div class="col-auto">
                                    <label class="form-label d-block">{{ __('refundable') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            v-model="s.is_refundable" :disabled="!isCurrentDefaultLang">
                                    </div>
                                </div>
                                <div class="col-auto">
                                    <label class="form-label d-block">{{ __('is_taxable') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            v-model="s.is_taxable" :disabled="!isCurrentDefaultLang">
                                    </div>
                                </div>
                                <div class="col-12 col-sm-6 col-md-4 col-lg-2" v-if="s.is_taxable">
                                    <label class="form-label">{{ __('tax_category') }}</label>
                                    <AppSelect class="form-select"
                                        v-model="s.tax_category_id" :options="taxCategoryOptions"
                                        :placeholder="__('tax_category')" :disabled="!isCurrentDefaultLang" />
                                </div>
                                <div class="col-auto" v-if="s.is_taxable">
                                    <label class="form-label d-block" :for="'surge-inc-' + i">{{ __('tax_included_in_amount') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            v-model="s.is_tax_included" :id="'surge-inc-' + i"
                                            :disabled="!isCurrentDefaultLang">
                                    </div>
                                </div>
                                <div class="col-auto ms-auto">
                                    <button type="button" class="btn btn-outline-danger"
                                        :disabled="!isCurrentDefaultLang"
                                        @click="removeSurgeSlot(i)">
                                        {{ __('remove') }}
                                    </button>
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm btn-primary"
                                :disabled="!isCurrentDefaultLang"
                                @click="addSurgeSlot()">
                                + {{ __('add_surge_slot') }}
                            </button>
                        </div>

                        <!-- Additional charges -->
                        <div class="border rounded p-3 mb-2">
                            <h6>{{ __('additional_charges') }}
                                <span class="badge bg-secondary ms-2">{{ __('optional') }}</span>
                            </h6>
                            <small class="text-muted d-block mb-2">{{ __('charge_refundable_hint') }}</small>
                            <div v-for="(c, i) in form.quick.additional_charges" :key="'ac-' + i"
                                class="row g-3 mb-3 align-items-end">
                                <div class="col-12 col-sm-6 col-md-4 col-lg-3">
                                    <label class="form-label">{{ __('charge_name') }}</label>
                                    <input type="text" class="form-control"
                                        :value="chargeNameFor('quick', i)"
                                        @input="setChargeName('quick', i, $event.target.value)"
                                        :placeholder="__('charge_name')">
                                </div>
                                <div class="col-6 col-sm-4 col-md-3 col-lg-2">
                                    <label class="form-label">{{ __('amount') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="c.amount" min="0" step="0.01"
                                        :disabled="!isCurrentDefaultLang">
                                </div>
                                <!-- Which orders pay it: home delivery, self pickup, or both. -->
                                <div class="col-6 col-sm-4 col-md-3 col-lg-2">
                                    <label class="form-label">{{ __('applies_to') }}</label>
                                    <AppSelect class="form-select" v-model="c.applies_to" :options="appliesToOptions"
                                        :searchable="false" :disabled="!isCurrentDefaultLang" />
                                </div>
                                <div class="col-auto">
                                    <label class="form-label d-block">{{ __('refundable') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            v-model="c.is_refundable" :disabled="!isCurrentDefaultLang">
                                    </div>
                                </div>
                                <div class="col-auto">
                                    <label class="form-label d-block">{{ __('is_taxable') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            v-model="c.is_taxable" :disabled="!isCurrentDefaultLang">
                                    </div>
                                </div>
                                <div class="col-12 col-sm-6 col-md-4 col-lg-3" v-if="c.is_taxable">
                                    <label class="form-label">{{ __('tax_category') }}</label>
                                    <AppSelect class="form-select"
                                        v-model="c.tax_category_id" :options="taxCategoryOptions"
                                        :placeholder="__('tax_category')" :disabled="!isCurrentDefaultLang" />
                                </div>
                                <div class="col-auto" v-if="c.is_taxable">
                                    <label class="form-label d-block" :for="'ac-quick-inc-' + i">{{ __('tax_included_in_amount') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            v-model="c.is_tax_included" :id="'ac-quick-inc-' + i"
                                            :disabled="!isCurrentDefaultLang">
                                    </div>
                                </div>
                                <!-- Remove sits at the far end of the row, away from the fields. -->
                                <div class="col-auto ms-auto">
                                    <button type="button" class="btn btn-outline-danger"
                                        :disabled="!isCurrentDefaultLang"
                                        @click="removeAdditionalCharge('quick', i)">
                                        {{ __('remove') }}
                                    </button>
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm btn-primary"
                                :disabled="!isCurrentDefaultLang"
                                @click="addAdditionalCharge('quick')">
                                + {{ __('add_additional_charge') }}
                            </button>
                        </div>

                    </div>
                </div>

                <!-- eCommerce settings -->
                <div class="card" v-if="servesEcommerce && activeChannelTab === 'ecommerce'">
                    <div class="card-body">
                        <h6 class="mb-1">{{ __('polygon_boundary') }} — {{ __('ecommerce') }} <i class="text-danger">*</i></h6>
                        <small class="text-muted d-block mb-1">{{ __('ecommerce_catchment_hint') }}</small>
                        <small class="text-warning d-block mb-2">
                            <i class="fa fa-exclamation-triangle me-1"></i>
                            {{ __('polygon_must_not_overlap_existing_zones') }}
                        </small>
                        <BoundaryMap :key="'mape-' + mapKey" v-model="form.polygon_boundary_ecommerce"
                            :reserved-areas="reservedAreas.ecommerce" searchable
                            @place-selected="onPlaceSelected" />
                    </div>
                </div>

                <div class="card" v-if="servesEcommerce && activeChannelTab === 'ecommerce'">
                    <div class="card-header">
                        <h5 class="card-title text-uppercase mb-0">{{ __('ecommerce_delivery_charges') }}</h5>
                        <small class="text-muted">
                            {{ __('manual_pricing_no_courier_api') }}
                            <router-link to="/delivery_cities">{{ __('delivery_cities') }}</router-link>
                            ·
                            <router-link to="/delivery_areas">{{ __('delivery_areas') }}</router-link>.
                            {{ __('inline_adds_write_to_same_tables') }}
                        </small>
                    </div>
                    <div class="card-body">
                        <div class="row mb-4">
                            <!-- How a parcel may actually leave this zone. Unticking a door
                                 hides it on every order of this zone, and a zone left with
                                 the courier alone also refuses pincodes it cannot reach. -->
                            <div class="col-12">
                                <label class="form-label">{{ __('ecommerce_delivery_methods') }}</label>
                                <div class="zone-dm-list">
                                    <div class="form-check form-switch zone-dm" v-for="m in deliveryMethodChoices"
                                        :key="m.value" :class="{ 'is-locked': isLastDeliveryMethod(m.value) }"
                                        :title="isLastDeliveryMethod(m.value) ? __('at_least_one_delivery_method_required') : ''">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            :id="'zone-dm-' + m.value"
                                            :checked="form.ecommerce.delivery_methods.includes(m.value)"
                                            :disabled="isLastDeliveryMethod(m.value)"
                                            @change="toggleDeliveryMethod(m.value)">
                                        <label class="form-check-label" :for="'zone-dm-' + m.value">
                                            <!-- The carrier's own logo, so the row reads like the
                                                 courier the admin bought rather than a category. -->
                                            <img v-if="m.icon" :src="m.icon" alt="" class="zone-dm-icon" />
                                            <span>{{ m.text }}</span>
                                        </label>
                                    </div>
                                </div>
                                <small class="text-muted d-block mt-1">
                                    {{ courierOnlyZone ? __('ecommerce_delivery_methods_courier_only_hint')
                                                       : __('ecommerce_delivery_methods_hint') }}
                                </small>
                            </div>
                        </div>

                        <div class="row mb-4">
                            <div class="col-md-6">
                                <label class="form-label">{{ __('pricing_strategy') }}</label>
                                <AppSelect class="form-select" v-model="form.ecommerce.pricing_strategy" :options="pricing_strategyOptions" :searchable="false" />
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('ecommerce_delivery_days') }}</label>
                                <div class="input-group">
                                    <input type="number" min="0" step="1" class="form-control"
                                        v-model.number="form.ecommerce.delivery_days" placeholder="0">
                                    <span class="input-group-text">{{ __('days') }}</span>
                                </div>
                                <small class="text-muted">{{ __('ecommerce_delivery_days_hint') }}</small>
                            </div>
                        </div>

                        <!-- Global fallback (all strategies) -->
                        <div class="border rounded p-3 mb-4">
                            <h6>{{ __('global_fallback') }}</h6>
                            <small class="text-muted d-block mb-2">
                                {{ __('used_when_no_matching_city_rule_applies_or_as_baseline') }}
                            </small>
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('default_delivery_charge') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="form.ecommerce.default_delivery_charge"
                                        min="0" step="0.01">
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('free_delivery_threshold') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="form.ecommerce.free_delivery_threshold"
                                        min="0" step="0.01">
                                    <small class="text-muted">{{ __('basket_ge_this_zero_on_fallback_path') }}</small>
                                </div>
                            </div>
                        </div>

                        <!-- Courier: the rate comes from the installed shipping plugin,
                             and the flat card below is what applies when it cannot. -->
                        <div v-if="form.ecommerce.pricing_strategy === 'courier'" class="alert alert-info">
                            {{ __('courier_pricing_hint') }}
                        </div>

                        <!-- What the zone adds to the carrier's own rate. Without this a
                             carrier's repricing walks straight into the client's margin. -->
                        <div v-if="form.ecommerce.pricing_strategy === 'courier'" class="border rounded p-3 mb-2">
                            <h6>{{ __('courier_markup') }}</h6>
                            <small class="text-muted d-block mb-2">{{ __('courier_markup_hint') }}</small>
                            <div class="row g-3">
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('courier_markup_type') }}</label>
                                    <AppSelect class="form-select" v-model="form.ecommerce.courier_markup_type"
                                        :options="courier_markup_typeOptions" :searchable="false" />
                                </div>
                                <div class="col-md-3" v-if="form.ecommerce.courier_markup_type !== 'none'">
                                    <label class="form-label">
                                        {{ __('courier_markup_value') }}
                                        ({{ form.ecommerce.courier_markup_type === 'percent' ? '%' : zoneCurrency }})
                                    </label>
                                    <input type="number" class="form-control" min="0" step="0.01"
                                        v-model="form.ecommerce.courier_markup_value">
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('courier_round_to') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" min="0" step="0.01"
                                        v-model="form.ecommerce.courier_round_to">
                                    <small class="text-muted">{{ __('courier_round_to_hint') }}</small>
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('courier_min_charge') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" min="0" step="0.01"
                                        v-model="form.ecommerce.courier_min_charge">
                                    <small class="text-muted">{{ __('courier_min_charge_hint') }}</small>
                                </div>
                            </div>
                        </div>

                        <!-- Flat (also the fallback for courier pricing) -->
                        <div v-if="['flat', 'courier'].includes(form.ecommerce.pricing_strategy)" class="border rounded p-3 mb-2">
                            <h6>{{ form.ecommerce.pricing_strategy === 'courier' ? __('fallback_flat_pricing') : __('flat_pricing') }}</h6>
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('delivery_charge') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="form.ecommerce.flat_delivery_charge"
                                        min="0" step="0.01">
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('free_delivery_above') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="form.ecommerce.flat_free_delivery_above"
                                        min="0" step="0.01">
                                    <small class="text-muted">{{ __('zero_means_none') }}</small>
                                </div>
                            </div>
                        </div>

                        <!-- Slab -->
                        <div v-if="form.ecommerce.pricing_strategy === 'slab'" class="border rounded p-3 mb-2">
                            <h6>{{ __('slab_pricing') }}</h6>
                            <small class="text-muted d-block mb-2">
                                {{ __('first_matching_slab_wins_empty_max_no_upper_limit') }}
                            </small>
                            <div v-for="(s, i) in form.ecommerce.slab_pricing" :key="'slab-' + i"
                                class="row g-3 mb-2 align-items-end">
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('minimum') }}</label>
                                    <input type="number" class="form-control" v-model="s.min" min="0" step="0.01">
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('maximum') }}</label>
                                    <input type="number" class="form-control" v-model="s.max" min="0" step="0.01"
                                        placeholder="∞">
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('charge') }}</label>
                                    <input type="number" class="form-control" v-model="s.charge" min="0" step="0.01">
                                </div>
                                <div class="col-md-3">
                                    <button type="button" class="btn btn-danger w-100"
                                        @click="form.ecommerce.slab_pricing.splice(i, 1)">
                                        {{ __('remove') }}
                                    </button>
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm btn-primary"
                                @click="form.ecommerce.slab_pricing.push({ min: 0, max: '', charge: 0 })">
                                + {{ __('add_slab') }}
                            </button>
                        </div>

                        <!-- City -->
                        <div v-if="form.ecommerce.pricing_strategy === 'city'" class="border rounded p-3 mb-2">
                            <h6>{{ __('per_city_delivery') }}</h6>
                            <small class="text-muted d-block mb-2">
                                {{ __('each_row_one_master_city_and_its_fee') }}
                            </small>
                            <div v-for="(c, i) in form.ecommerce.city_pricing" :key="'cp-' + i"
                                class="row g-3 mb-3 align-items-end border-bottom pb-3">
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('city') }}</label>
                                    <select class="form-select" v-model="c.delivery_city_id"
                                        @change="onCitySelectInline($event, i, 'city')">
                                        <option value="">{{ __('select_city') }}</option>
                                        <option v-for="dc in deliveryCities" :key="dc.id" :value="dc.id"
                                            :disabled="isCityAlreadyPicked(dc.id, i)">{{ dc.name }}</option>
                                        <option value="__add_new__">+ {{ __('add_new_city') }}</option>
                                    </select>
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('delivery_charge') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="c.charge" min="0" step="0.01">
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('free_delivery_above') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="c.free_above" min="0" step="0.01">
                                </div>
                                <div class="col-md-2">
                                    <button type="button" class="btn btn-danger w-100"
                                        @click="form.ecommerce.city_pricing.splice(i, 1)">
                                        {{ __('remove') }}
                                    </button>
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm btn-primary"
                                @click="form.ecommerce.city_pricing.push({ delivery_city_id: '', charge: 0, free_above: 0 })">
                                + {{ __('add_city') }}
                            </button>
                        </div>

                        <!-- Area -->
                        <div v-if="form.ecommerce.pricing_strategy === 'area'" class="border rounded p-3 mb-2">
                            <h6>{{ __('per_area_delivery') }}</h6>
                            <small class="text-muted d-block mb-2">
                                {{ __('choose_city_to_load_its_areas') }}
                            </small>
                            <div v-for="(r, i) in form.ecommerce.area_pricing" :key="'ap-' + i"
                                class="row g-3 mb-3 align-items-end border-bottom pb-3">
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('city') }}</label>
                                    <select class="form-select" v-model="r.delivery_city_id"
                                        @change="onAreaRowCityChange(i)">
                                        <option value="">{{ __('choose_city') }}</option>
                                        <option v-for="dc in deliveryCities" :key="dc.id" :value="dc.id">{{ dc.name }}</option>
                                        <option value="__add_new__">+ {{ __('add_new_city') }}</option>
                                    </select>
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('area') }}</label>
                                    <select class="form-select" v-model="r.delivery_area_id"
                                        :disabled="!r.delivery_city_id || r.delivery_city_id === '__add_new__'"
                                        @change="onAreaSelectInline($event, i)">
                                        <option value="">{{ __('select_a_city_first') }}</option>
                                        <option v-for="a in areasForCity(r.delivery_city_id)" :key="a.id" :value="a.id"
                                            :disabled="isAreaAlreadyPicked(a.id, r.delivery_city_id, i)">{{ a.name }}</option>
                                        <option v-if="r.delivery_city_id && r.delivery_city_id !== '__add_new__'"
                                            value="__add_new_area__">+ {{ __('add_new_area') }}</option>
                                    </select>
                                </div>
                                <div class="col-md-2">
                                    <label class="form-label">{{ __('delivery_charge') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="r.charge" min="0" step="0.01">
                                </div>
                                <div class="col-md-2">
                                    <label class="form-label">{{ __('free_delivery_above') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="r.free_above" min="0" step="0.01">
                                </div>
                                <div class="col-md-2">
                                    <button type="button" class="btn btn-danger w-100"
                                        @click="form.ecommerce.area_pricing.splice(i, 1)">
                                        {{ __('remove') }}
                                    </button>
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm btn-primary"
                                @click="form.ecommerce.area_pricing.push({ delivery_city_id: '', delivery_area_id: '', charge: 0, free_above: 0 })">
                                + {{ __('add_area_row') }}
                            </button>
                        </div>

                        <!-- Language switcher (additional charge names) -->
                        <ul class="nav nav-tabs mb-3" v-if="languages.length > 1">
                            <li class="nav-item" v-for="(lang, idx) in languages" :key="'ec-lang-' + lang.id">
                                <a class="nav-link" :class="{ active: activeLanguageTab === idx }" href="#"
                                    @click.prevent="activeLanguageTab = idx">{{ lang.name }}</a>
                            </li>
                        </ul>

                        <!-- Additional charges -->
                        <div class="border rounded p-3 mb-2">
                            <h6>{{ __('additional_charges') }}
                                <span class="badge bg-secondary ms-2">{{ __('optional') }}</span>
                            </h6>
                            <small class="text-muted d-block mb-2">{{ __('charge_refundable_hint') }}</small>
                            <div v-for="(c, i) in form.ecommerce.additional_charges" :key="'ec-ac-' + i"
                                class="row g-3 mb-3 align-items-end">
                                <div class="col-12 col-sm-6 col-md-4 col-lg-3">
                                    <label class="form-label">{{ __('charge_name') }}</label>
                                    <input type="text" class="form-control"
                                        :value="chargeNameFor('ecommerce', i)"
                                        @input="setChargeName('ecommerce', i, $event.target.value)"
                                        :placeholder="__('charge_name')">
                                </div>
                                <div class="col-6 col-sm-4 col-md-3 col-lg-2">
                                    <label class="form-label">{{ __('amount') }} ({{ zoneCurrency }})</label>
                                    <input type="number" class="form-control" v-model="c.amount" min="0" step="0.01"
                                        :disabled="!isCurrentDefaultLang">
                                </div>
                                <!-- Which orders pay it: home delivery, self pickup, or both. -->
                                <div class="col-6 col-sm-4 col-md-3 col-lg-2">
                                    <label class="form-label">{{ __('applies_to') }}</label>
                                    <AppSelect class="form-select" v-model="c.applies_to" :options="appliesToOptions"
                                        :searchable="false" :disabled="!isCurrentDefaultLang" />
                                </div>
                                <div class="col-auto">
                                    <label class="form-label d-block">{{ __('refundable') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            v-model="c.is_refundable" :disabled="!isCurrentDefaultLang">
                                    </div>
                                </div>
                                <div class="col-auto">
                                    <label class="form-label d-block">{{ __('is_taxable') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            v-model="c.is_taxable" :disabled="!isCurrentDefaultLang">
                                    </div>
                                </div>
                                <div class="col-12 col-sm-6 col-md-4 col-lg-3" v-if="c.is_taxable">
                                    <label class="form-label">{{ __('tax_category') }}</label>
                                    <AppSelect class="form-select"
                                        v-model="c.tax_category_id" :options="taxCategoryOptions"
                                        :placeholder="__('tax_category')" :disabled="!isCurrentDefaultLang" />
                                </div>
                                <div class="col-auto" v-if="c.is_taxable">
                                    <label class="form-label d-block" :for="'ac-ecommerce-inc-' + i">{{ __('tax_included_in_amount') }}</label>
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch"
                                            v-model="c.is_tax_included" :id="'ac-ecommerce-inc-' + i"
                                            :disabled="!isCurrentDefaultLang">
                                    </div>
                                </div>
                                <!-- Remove sits at the far end of the row, away from the fields. -->
                                <div class="col-auto ms-auto">
                                    <button type="button" class="btn btn-outline-danger"
                                        :disabled="!isCurrentDefaultLang"
                                        @click="removeAdditionalCharge('ecommerce', i)">
                                        {{ __('remove') }}
                                    </button>
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm btn-primary"
                                :disabled="!isCurrentDefaultLang"
                                @click="addAdditionalCharge('ecommerce')">
                                + {{ __('add_additional_charge') }}
                            </button>
                        </div>

                    </div>
                </div>

                <!-- One save row for the whole form: with sales_channel = 'both' the two
                     cards above are siblings, so a per-card button would render twice. -->
                <div class="text-end mt-4">
                    <router-link to="/zones" class="btn btn-secondary me-2">{{ __('cancel') }}</router-link>
                    <button type="submit" class="btn btn-primary" :disabled="saving">
                        <b-spinner small v-if="saving"></b-spinner>
                        {{ isEdit ? __('update') : __('save') }}
                    </button>
                </div>

                </div><!-- /delivery pane -->

            </form>
        </div>

        <!-- Inline Add City Modal — reuses the DeliveryCities create form -->
        <b-modal v-model="cityModal.show" :title="__('add_new_city')" :no-footer="true" size="lg" centered>
            <DeliveryCities v-if="cityModal.show" embedded @saved="onInlineCitySaved" />
        </b-modal>

        <!-- Inline Add Area Modal — reuses the DeliveryAreas create form -->
        <b-modal v-model="areaModal.show" :title="__('add_new_area')" :no-footer="true" size="lg" centered>
            <DeliveryAreas v-if="areaModal.show" embedded :locked-city-id="areaModal.delivery_city_id"
                @saved="onInlineAreaSaved" />
        </b-modal>
    </div>
</template>

<script>
import axios from 'axios';
import BoundaryMap from '../../components/BoundaryMap.vue';
import DeliveryCities from './DeliveryCities.vue';
import DeliveryAreas from './DeliveryAreas.vue';
import { ArrowLeft, Zap, ShoppingBag } from 'lucide-vue-next';
import TimePicker from '../../components/TimePicker.vue';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';

export default {
    name: 'EditZone',
    mixins: [TranslationHelper, UnsavedChanges],
    components: { TimePicker, BoundaryMap, DeliveryCities, DeliveryAreas, ArrowLeft, Zap, ShoppingBag },
    data() {
        return {
            isEdit: false,
            saving: false,
            languages: [],
            defaultLanguageId: 0,
            activeLanguageTab: 0,
            // Installed couriers, so the delivery-method row can name them.
            courierProviders: [],
            countries: [],
            regions: [],
            taxCategories: [],
            form: this.emptyForm(),
            deliveryCities: [],
            deliveryAreasByCity: {},
            mapKey: 0,
            activeChannelTab: 'quick',
            // Areas other zones already cover, per channel — shown greyed on the map.
            reservedAreas: { quick: [], ecommerce: [] },
            cityModal: {
                show: false,
                rowIndex: null,
                target: 'city',
            },
            areaModal: {
                show: false,
                rowIndex: null,
                delivery_city_id: null,
            },
        };
    },
    watch: {
        /* Unticking the courier — or moving the zone to a country it does not serve — takes
           courier pricing off the table, so the strategy falls back to the zone's own rule
           rather than pointing at a carrier that will never be asked. */
        courierPricingAvailable(available) {
            if (!available && this.form.ecommerce.pricing_strategy === 'courier') {
                this.form.ecommerce.pricing_strategy = 'flat';
            }
        },
        // Keep the open tab on a channel this zone actually serves. Without this an
        // ecommerce-only zone keeps the default 'quick' tab, so neither card renders.
        servedChannels: {
            immediate: true,
            handler(list) {
                if (list.length && !list.includes(this.activeChannelTab)) {
                    this.activeChannelTab = list[0];
                }
            },
        },
    },
    async created() {
        this.isEdit = !!this.$route.params.id;
        await this.loadLanguages();
        this.loadDeliveryCities();
        this.loadReservedAreas();
        if (this.isEdit) {
            await this.loadZone(this.$route.params.id);
        }
        this.loadCountries();
        this.loadTaxCategories();
        this.loadCourierProviders();
        await this.loadRegions();
        // Snapshot the loaded form as the "clean" baseline for the unsaved-changes guard.
        this.captureFormBaseline();
    },
    computed: {
        // Which orders a zone additional charge is billed on.
        appliesToOptions() {
            return [
                { id: 'delivery', name: __('applies_to_delivery') },
                { id: 'pickup', name: __('applies_to_pickup') },
                { id: 'both', name: __('applies_to_both') },
            ];
        },
        regionOptions() {
            return this.regions.map(r => ({ id: r.id, name: r.name }));
        },
        taxCategoryOptions() {
            return this.taxCategories.map(c => ({ id: c.id, name: c.name }));
        },
        // The label carries the currency, which a plain option list can't express.
        countryOptions() {
            return (this.countries || []).map(c => ({
                id: c.id,
                name: `${c.name} (${c.currency || c.currency_code})`,
            }));
        },
        // Fixed option set — no search box needed.
        distance_unitOptions() {
            return [
                { id: 'km', name: (__('kilometers_km')) },
                { id: 'mi', name: (__('miles_mi')) },
            ];
        },
        // Fixed option set — no search box needed.
        // Fixed option set — no search box needed.
        deliveryMethodChoices() {
            const rows = [
                { value: 'delivery_boy', text: __('delivery_boy') },
                { value: 'manual_tracking', text: __('manual_tracking') },
            ];

            /* The courier row appears only where a courier could really carry the parcel —
               one is installed and it serves this country. Nothing is said when it cannot;
               an option that would never work is simply not offered. Whatever the zone has
               stored stays stored, so hiding the row never rewrites an earlier choice. */
            const usable = this.usableCourierProviders;
            if (!usable.length) {
                return rows;
            }

            const icons = usable.map(p => p.icon).filter(Boolean);

            return [
                {
                    value: 'courier',
                    text: usable.map(p => p.label).filter(Boolean).join(', ') || __('courier'),
                    icon: usable.length === 1 ? (icons[0] || null) : null,
                },
                ...rows,
            ];
        },
        /** The doors on screen, and the ones of those that are ticked. */
        visibleDeliveryMethods() {
            return this.deliveryMethodChoices.map(m => m.value);
        },
        selectedVisibleDeliveryMethods() {
            const chosen = this.form.ecommerce.delivery_methods || [];
            return this.visibleDeliveryMethods.filter(m => chosen.includes(m));
        },
        /**
         * Couriers that can serve this zone. With no country picked yet, anything installed
         * and configured counts — the country narrows it as soon as one is chosen.
         */
        usableCourierProviders() {
            return this.courierProviders.filter(p => (this.form.country_id ? p.usable : p.configured));
        },
        /** A courier on its own is the one case that also refuses unserviceable pincodes. */
        courierOnlyZone() {
            const m = this.form.ecommerce.delivery_methods;
            return m.length === 1 && m[0] === 'courier';
        },
        courier_markup_typeOptions() {
            return [
                { id: 'none', name: (__('no_markup')) },
                { id: 'percent', name: (__('percent_of_rate')) },
                { id: 'fixed', name: (__('fixed_amount')) },
            ];
        },
        pricing_strategyOptions() {
            const options = [
                { id: 'flat', name: (__('flat_one_fee_plus_optional_free_above')) },
                { id: 'slab', name: (__('slab_by_order_value_bands')) },
                { id: 'city', name: (__('city_one_row_per_master_city')) },
                { id: 'area', name: (__('area_pick_city_then_area_only_area_rows_apply')) },
            ];

            /* Pricing from a carrier's live quote is only on offer where the zone actually
               hands parcels to one — the door above decides, not this list. */
            if (this.courierPricingAvailable) {
                options.push({ id: 'courier', name: (__('courier_live_rates_from_the_shipping_plugin')) });
            }

            return options;
        },
        /** A usable courier, ticked as one of this zone's ways to deliver. */
        courierPricingAvailable() {
            return this.usableCourierProviders.length > 0
                && (this.form.ecommerce.delivery_methods || []).includes('courier');
        },
        // The translatable text here is ARRAYS (one label per surge slot / charge), which
        // the flat field model can't express — so flatten to one synthetic field per index
        // (`surge_label_0`, `charge_name_1`, ...) and map back in applyTranslated().
        translatableFields() {
            const fields = [];
            (this.form.quick.surge_slots || []).forEach((sl, i) => {
                if (sl && String(sl.label || '').trim() !== '') fields.push('surge_label_' + i);
            });
            ['quick', 'ecommerce'].forEach(ns => {
                (this.form[ns].additional_charges || []).forEach((c, i) => {
                    if (c && String(c.name || '').trim() !== '') fields.push(ns + '_charge_name_' + i);
                });
            });
            return fields;
        },
        currentLanguage() {
            return this.languages[this.activeLanguageTab] || null;
        },
        // 'both' zones show BOTH pricing cards; single-channel zones show just theirs.
        servesQuick() {
            return this.form.sales_channel === 'quick' || this.form.sales_channel === 'both';
        },
        servesEcommerce() {
            return this.form.sales_channel === 'ecommerce' || this.form.sales_channel === 'both';
        },
        servedChannels() {
            const out = [];
            if (this.servesQuick) out.push('quick');
            if (this.servesEcommerce) out.push('ecommerce');
            return out;
        },
        isCurrentDefaultLang() {
            return !!(this.currentLanguage && Number(this.currentLanguage.id) === Number(this.defaultLanguageId));
        },
        // Short unit label (km/mi) for distance-based field labels.
        distanceUnitShort() {
            return this.form.quick.distance_unit === 'mi' ? 'mi' : 'km';
        },
        // The selected country (source of currency now).
        selectedCountry() {
            return this.countries.find(c => Number(c.id) === Number(this.form.country_id)) || null;
        },
        // Currency symbol from the selected country; falls back to global $currency.
        zoneCurrency() {
            return (this.selectedCountry && this.selectedCountry.currency) || this.$currency || '';
        },
    },
    methods: {
        /**
         * Tick or untick a fulfilment door, never leaving none: a zone with no way out
         * could not ship at all, so the last one stays put.
         */
        /**
         * Which couriers this install has, for the delivery-method labels. A failure is
         * silent: the row then says "Courier", which is still true.
         */
        loadCourierProviders() {
            const params = this.form.country_id ? { country_id: this.form.country_id } : {};
            return axios.get(this.$apiUrl + '/zones/courier_providers', { params })
                .then(res => {
                    if (res.data.status === 1) this.courierProviders = res.data.data.providers || [];
                })
                .catch(() => { this.courierProviders = []; });
        },
        /**
         * The only ticked box on screen, which is therefore the one that cannot be cleared.
         * Counted on screen rather than in the stored value: a courier kept from an earlier
         * edit is invisible here, and it must not stand in for a door the admin can use.
         */
        isLastDeliveryMethod(method) {
            const selected = this.selectedVisibleDeliveryMethods;
            return selected.length === 1 && selected[0] === method;
        },
        toggleDeliveryMethod(method) {
            const current = this.form.ecommerce.delivery_methods || [];
            if (current.includes(method)) {
                // Never leave the zone with no way out.
                if (this.isLastDeliveryMethod(method)) return;
                this.form.ecommerce.delivery_methods = current.filter(m => m !== method);
                return;
            }
            this.form.ecommerce.delivery_methods = ['courier', 'delivery_boy', 'manual_tracking']
                .filter(m => current.includes(m) || m === method);
        },
        // Tracked state for the UnsavedChanges guard (warn before leaving with edits).
        formState() {
            return this.form;
        },
        async loadLanguages() {
            try {
                const res = await axios.get(this.$apiUrl + '/active_languages');
                this.languages = res.data?.data || [];
                const def = this.languages.find(l => l.is_default === 1) || this.languages[0];
                this.defaultLanguageId = def?.id ?? 1;
                const idx = this.languages.findIndex(l => Number(l.id) === Number(this.defaultLanguageId));
                this.activeLanguageTab = idx >= 0 ? idx : 0;
            } catch {
                this.languages = [];
                this.defaultLanguageId = 1;
            }
        },
        // Source text = the DEFAULT language's labels, which live on the slots/charges
        // themselves (not in `translations`).
        getTranslateSource() {
            const source = {};
            (this.form.quick.surge_slots || []).forEach((sl, i) => {
                if (sl && String(sl.label || '').trim() !== '') source['surge_label_' + i] = sl.label;
            });
            ['quick', 'ecommerce'].forEach(ns => {
                (this.form[ns].additional_charges || []).forEach((c, i) => {
                    if (c && String(c.name || '').trim() !== '') source[ns + '_charge_name_' + i] = c.name;
                });
            });
            return source;
        },
        applyTranslated(lang, translated) {
            if (Number(lang.id) === Number(this.defaultLanguageId)) return;
            Object.keys(translated).forEach((key) => {
                const surge = key.match(/^surge_label_(\d+)$/);
                if (surge) {
                    this.ensureTranslationArrays('quick', lang.id);
                    this.form.quick.translations[lang.id].surge_labels[Number(surge[1])] = translated[key];
                    return;
                }
                const charge = key.match(/^(quick|ecommerce)_charge_name_(\d+)$/);
                if (charge) {
                    const ns = charge[1];
                    this.ensureTranslationArrays(ns, lang.id);
                    this.form[ns].translations[lang.id].additional_charge_names[Number(charge[2])] = translated[key];
                }
            });
        },
        // Labels live alongside the config that owns the charges, so they're per channel.
        ensureTranslationArrays(ns, langId) {
            if (!this.form[ns].translations) this.form[ns].translations = {};
            if (!this.form[ns].translations[langId]) {
                this.form[ns].translations[langId] = { surge_labels: [], additional_charge_names: [] };
            }
            const t = this.form[ns].translations[langId];
            if (!Array.isArray(t.surge_labels)) t.surge_labels = [];
            if (!Array.isArray(t.additional_charge_names)) t.additional_charge_names = [];
        },
        // Surge slots exist on the quick config only.
        surgeLabelFor(i) {
            if (this.isCurrentDefaultLang) return this.form.quick.surge_slots[i]?.label ?? '';
            const id = this.currentLanguage?.id;
            return this.form.quick.translations?.[id]?.surge_labels?.[i] ?? '';
        },
        setSurgeLabel(i, val) {
            if (this.isCurrentDefaultLang) {
                if (this.form.quick.surge_slots[i]) this.form.quick.surge_slots[i].label = val;
                return;
            }
            const id = this.currentLanguage?.id;
            if (!id) return;
            this.ensureTranslationArrays('quick', id);
            this.form.quick.translations[id].surge_labels[i] = val;
        },
        // Additional charges exist on BOTH configs, so every accessor takes the channel.
        chargeNameFor(ns, i) {
            if (this.isCurrentDefaultLang) return this.form[ns].additional_charges[i]?.name ?? '';
            const id = this.currentLanguage?.id;
            return this.form[ns].translations?.[id]?.additional_charge_names?.[i] ?? '';
        },
        setChargeName(ns, i, val) {
            if (this.isCurrentDefaultLang) {
                if (this.form[ns].additional_charges[i]) this.form[ns].additional_charges[i].name = val;
                return;
            }
            const id = this.currentLanguage?.id;
            if (!id) return;
            this.ensureTranslationArrays(ns, id);
            this.form[ns].translations[id].additional_charge_names[i] = val;
        },
        addSurgeSlot() {
            this.form.quick.surge_slots.push({ label: '', start: '', end: '', charge: 0, is_refundable: false, is_taxable: false, is_tax_included: false, tax_category_id: null });
            for (const lang of this.languages) {
                if (Number(lang.id) === Number(this.defaultLanguageId)) continue;
                this.ensureTranslationArrays('quick', lang.id);
                this.form.quick.translations[lang.id].surge_labels.push('');
            }
        },
        removeSurgeSlot(i) {
            this.form.quick.surge_slots.splice(i, 1);
            for (const id of Object.keys(this.form.quick.translations || {})) {
                const arr = this.form.quick.translations[id]?.surge_labels;
                if (Array.isArray(arr)) arr.splice(i, 1);
            }
        },
        addAdditionalCharge(ns) {
            this.form[ns].additional_charges.push({ name: '', amount: 0, applies_to: 'delivery', is_refundable: false, is_taxable: false, is_tax_included: false, tax_category_id: null });
            for (const lang of this.languages) {
                if (Number(lang.id) === Number(this.defaultLanguageId)) continue;
                this.ensureTranslationArrays(ns, lang.id);
                this.form[ns].translations[lang.id].additional_charge_names.push('');
            }
        },
        removeAdditionalCharge(ns, i) {
            this.form[ns].additional_charges.splice(i, 1);
            for (const id of Object.keys(this.form[ns].translations || {})) {
                const arr = this.form[ns].translations[id]?.additional_charge_names;
                if (Array.isArray(arr)) arr.splice(i, 1);
            }
        },

        emptyForm() {
            return {
                id: null,
                name: '',
                city: '',
                state: '',
                region_id: null,
                delivery_charge_is_taxable: false,
                delivery_charge_tax_included: false,
                delivery_charge_tax_category_id: null,
                country_id: '',
                status: 1,
                sales_channel: 'quick',
                // One catchment per channel — quick delivery range is usually tighter
                // than the ecommerce shipping range.
                polygon_boundary_quick: [],
                polygon_boundary_ecommerce: [],

                translations: {},

                // Delivery pricing is per channel: a 'both' zone edits both blocks and
                // posts them as quick_* / ecommerce_*.
                quick: this.emptyQuickConfig(),
                ecommerce: this.emptyEcommerceConfig(),
            };
        },

        emptyQuickConfig() {
            return {
                distance_unit: 'km',
                base_delivery_charge: 0,
                base_distance: 0,
                charge_per_km: 0,
                travel_time_per_km: 0,
                minimum_order_amount: 0,
                free_delivery_above: 0,
                surge_slots: [],
                additional_charges: [],
                translations: {},
            };
        },

        emptyEcommerceConfig() {
            return {
                pricing_strategy: 'flat',
                courier_markup_type: 'none',
                courier_markup_value: 0,
                courier_round_to: 0,
                courier_min_charge: 0,
                delivery_methods: ['courier', 'delivery_boy', 'manual_tracking'],
                delivery_days: 0,
                default_delivery_charge: 0,
                free_delivery_threshold: 0,
                flat_delivery_charge: 0,
                flat_free_delivery_above: 0,
                slab_pricing: [],
                city_pricing: [],
                area_pricing: [],
                additional_charges: [],
                translations: {},
            };
        },

        // Overlap is rejected per channel at save time; drawing these on the map makes
        // that visible while the admin draws instead of only failing on submit.
        loadReservedAreas() {
            const excludeId = this.$route.params.id || '';
            for (const ch of ['quick', 'ecommerce']) {
                axios.get(this.$apiUrl + '/zones/taken_boundaries', {
                    params: { sales_channel: ch, exclude_id: excludeId },
                }).then(res => {
                    this.reservedAreas[ch] = res.data?.data?.zones || [];
                }).catch(() => { this.reservedAreas[ch] = []; });
            }
        },

        // BoundaryMap owns the search box; it pans itself and hands us the details.
        // The map pans itself; we only keep the parts a zone actually branches.
        onPlaceSelected(place) {
            if (place.city) this.form.city = place.city;
            if (place.state) this.form.state = place.state;
        },

        loadDeliveryCities() {
            return axios.get(this.$apiUrl + '/delivery_cities')
                .then(res => {
                    this.deliveryCities = res.data?.data?.cities || [];
                });
        },
        async loadAreasForCity(cityId) {
            if (!cityId || this.deliveryAreasByCity[cityId]) return;
            const res = await axios.get(this.$apiUrl + '/delivery_areas', { params: { delivery_city_id: cityId } });
            this.deliveryAreasByCity = {
                ...this.deliveryAreasByCity,
                [cityId]: res.data?.data?.areas || [],
            };
        },
        areasForCity(cityId) {
            return this.deliveryAreasByCity[cityId] || [];
        },
        onAreaRowCityChange(i) {
            const row = this.form.ecommerce.area_pricing[i];
            if (row.delivery_city_id === '__add_new__') {
                row.delivery_city_id = '';
                this.openCityModal(i, 'area');
                return;
            }
            row.delivery_area_id = '';
            if (row.delivery_city_id) {
                this.loadAreasForCity(row.delivery_city_id);
            }
        },
        onCitySelectInline(e, i, target) {
            const val = e.target.value;
            if (val === '__add_new__') {
                if (target === 'city') {
                    this.form.ecommerce.city_pricing[i].delivery_city_id = '';
                }
                this.openCityModal(i, target);
            }
        },
        onAreaSelectInline(e, i) {
            const val = e.target.value;
            if (val === '__add_new_area__') {
                this.form.ecommerce.area_pricing[i].delivery_area_id = '';
                this.openAreaModal(i, this.form.ecommerce.area_pricing[i].delivery_city_id);
            }
        },
        isCityAlreadyPicked(cityId, currentIndex) {
            return this.form.ecommerce.city_pricing.some((row, i) => i !== currentIndex && Number(row.delivery_city_id) === Number(cityId));
        },
        isAreaAlreadyPicked(areaId, cityId, currentIndex) {
            return this.form.ecommerce.area_pricing.some((row, i) =>
                i !== currentIndex
                && Number(row.delivery_city_id) === Number(cityId)
                && Number(row.delivery_area_id) === Number(areaId)
            );
        },

        openCityModal(rowIndex, target) {
            this.cityModal = { show: true, rowIndex, target };
        },
        // DeliveryCities (embedded) emits the saved city; apply it to the triggering row.
        async onInlineCitySaved(newCity) {
            if (newCity) {
                this.deliveryCities = [...this.deliveryCities, newCity];
                const idx = this.cityModal.rowIndex;
                if (this.cityModal.target === 'city' && this.form.ecommerce.city_pricing[idx]) {
                    this.form.ecommerce.city_pricing[idx].delivery_city_id = newCity.id;
                } else if (this.cityModal.target === 'area' && this.form.ecommerce.area_pricing[idx]) {
                    this.form.ecommerce.area_pricing[idx].delivery_city_id = newCity.id;
                    await this.loadAreasForCity(newCity.id);
                }
            }
            this.cityModal.show = false;
        },
        openAreaModal(rowIndex, cityId) {
            this.areaModal = { show: true, rowIndex, delivery_city_id: cityId };
        },
        // DeliveryAreas (embedded) emits the saved area; apply it to the triggering row.
        onInlineAreaSaved(newArea) {
            if (newArea) {
                const cityId = this.areaModal.delivery_city_id;
                const list = this.deliveryAreasByCity[cityId] || [];
                this.deliveryAreasByCity = { ...this.deliveryAreasByCity, [cityId]: [...list, newArea] };
                const idx = this.areaModal.rowIndex;
                if (this.form.ecommerce.area_pricing[idx]) {
                    this.form.ecommerce.area_pricing[idx].delivery_area_id = newArea.id;
                }
            }
            this.areaModal.show = false;
        },

        cityNameById(id) {
            const c = this.deliveryCities.find(c => Number(c.id) === Number(id));
            return c?.name || '';
        },

        async loadZone(id) {
            try {
                const res = await axios.get(this.$apiUrl + '/zones/edit/' + id);
                const data = res.data?.data;
                if (!data) {
                    this.showError(__('zone_not_found'));
                    return;
                }
                // Configs arrive as one row per channel; fold each into its form block.
                const form = this.emptyForm();
                form.id = data.id;
                form.name = data.name || '';
                form.city = data.city || '';
                form.state = data.state || '';
                form.region_id = data.region_id ? Number(data.region_id) : null;
                form.country_id = data.country_id || '';
                form.delivery_charge_is_taxable = !!Number(data.delivery_charge_is_taxable);
                form.delivery_charge_tax_included = !!Number(data.delivery_charge_tax_included);
                form.delivery_charge_tax_category_id = data.delivery_charge_tax_category_id
                    ? Number(data.delivery_charge_tax_category_id) : null;
                form.status = data.status ?? 1;
                form.sales_channel = data.sales_channel || 'quick';
                form.polygon_boundary_quick = this.parseArr(data.polygon_boundary_quick);
                form.polygon_boundary_ecommerce = this.parseArr(data.polygon_boundary_ecommerce);

                const translationsMap = {};
                for (const t of (data.translations || [])) {
                    translationsMap[t.language_id] = {
                        surge_labels: this.parseArr(t.surge_labels),
                        additional_charge_names_quick: this.parseArr(t.additional_charge_names_quick),
                        additional_charge_names_ecommerce: this.parseArr(t.additional_charge_names_ecommerce),
                    };
                }
                const perChannelTranslations = (nameKey) => {
                    const out = {};
                    for (const [langId, t] of Object.entries(translationsMap)) {
                        out[langId] = {
                            surge_labels: t.surge_labels,
                            additional_charge_names: t[nameKey],
                        };
                    }
                    return out;
                };

                form.quick = {
                    distance_unit: data.distance_unit || 'km',
                    base_delivery_charge: data.base_delivery_charge ?? 0,
                    base_distance: data.base_distance ?? 0,
                    charge_per_km: data.charge_per_km ?? 0,
                    travel_time_per_km: data.travel_time_per_km ?? 0,
                    minimum_order_amount: data.minimum_order_amount ?? 0,
                    free_delivery_above: data.free_delivery_above ?? 0,
                    surge_slots: this.parseArr(data.surge_slots),
                    additional_charges: this.parseArr(data.additional_charges_quick).map(c => ({ applies_to: 'delivery', ...c })),
                    translations: perChannelTranslations('additional_charge_names_quick'),
                };

                form.ecommerce = {
                    pricing_strategy: data.pricing_strategy || 'flat',
                    courier_markup_type: data.courier_markup_type || 'none',
                    courier_markup_value: data.courier_markup_value ?? 0,
                    courier_round_to: data.courier_round_to ?? 0,
                    courier_min_charge: data.courier_min_charge ?? 0,
                    delivery_methods: Array.isArray(data.ecommerce_delivery_methods) && data.ecommerce_delivery_methods.length
                        ? data.ecommerce_delivery_methods
                        : ['courier', 'delivery_boy', 'manual_tracking'],
                    delivery_days: Number(data.ecommerce_delivery_days) || 0,
                    default_delivery_charge: data.default_delivery_charge ?? 0,
                    free_delivery_threshold: data.free_delivery_threshold ?? 0,
                    flat_delivery_charge: data.flat_delivery_charge ?? 0,
                    flat_free_delivery_above: data.flat_free_delivery_above ?? 0,
                    slab_pricing: this.parseArr(data.slab_pricing),
                    city_pricing: this.parseArr(data.city_pricing),
                    area_pricing: this.parseArr(data.area_pricing),
                    additional_charges: this.parseArr(data.additional_charges_ecommerce).map(c => ({ applies_to: 'delivery', ...c })),
                    translations: perChannelTranslations('additional_charge_names_ecommerce'),
                };

                Object.assign(this.form, form);

                // Remount the map so it renders the loaded zone's polygon.
                this.mapKey++;
                for (const row of this.form.ecommerce.area_pricing) {
                    if (row.delivery_city_id) {
                        await this.loadAreasForCity(row.delivery_city_id);
                    }
                }
            } catch (e) {
                this.showError(e.response?.data?.message || __('something_went_wrong'));
            }
        },
        parseArr(v) {
            if (Array.isArray(v)) return v;
            if (v && typeof v === 'object') return v;
            if (typeof v === 'string' && v.length) {
                try { return JSON.parse(v); } catch { return []; }
            }
            return [];
        },
        parseObj(v) {
            if (v && typeof v === 'object' && !Array.isArray(v)) return v;
            if (typeof v === 'string' && v.length) {
                try { const p = JSON.parse(v); return (p && typeof p === 'object' && !Array.isArray(p)) ? p : {}; } catch { return {}; }
            }
            return {};
        },
        async loadCountries() {
            try {
                const res = await axios.get(this.$apiUrl + '/countries/active');
                this.countries = res.data?.data || [];
                // New zone: default to the default country (else the first).
                if (!this.isEdit && !this.form.country_id) {
                    const def = this.countries.find(c => Number(c.is_default) === 1) || this.countries[0];
                    if (def) {
                        this.form.country_id = Number(def.id);
                        this.onCountryChange();
                    }
                }
            } catch {
                this.countries = [];
            }
        },
        onCountryChange() {
            // A courier serves some countries and not others, so the named carrier follows
            // the selection just as the regions do.
            this.loadCourierProviders();
            // Regions belong to a country, so the list has to follow the selection.
            const previous = this.form.region_id;
            this.loadRegions().then(() => {
                if (previous && !this.regions.some(r => Number(r.id) === Number(previous))) {
                    this.form.region_id = null;
                }
            });
        },
        /** Subdivisions of the selected country. Empty list keeps the free-text field. */
        loadRegions() {
            if (!this.form.country_id) { this.regions = []; return Promise.resolve(); }
            return axios.get(this.$apiUrl + '/countries/regions', { params: { country_id: this.form.country_id, status: 1 } })
                .then(res => { this.regions = res.data.data || []; })
                .catch(() => { this.regions = []; });
        },
        loadTaxCategories() {
            return axios.get(this.$apiUrl + '/products/tax_categories', { params: { status: 1 } })
                .then(res => { this.taxCategories = res.data.data || []; })
                .catch(() => { this.taxCategories = []; });
        },

        async saveZone() {
            if (!this.form.name?.trim()) {
                this.showError(__('zone_name') + ' ' + __('is_required'));
                return;
            }
            // Each served channel needs its own catchment drawn.
            for (const ns of this.servedChannels) {
                const poly = ns === 'quick' ? this.form.polygon_boundary_quick : this.form.polygon_boundary_ecommerce;
                if (!poly || poly.length < 3) {
                    this.activeChannelTab = ns;
                    this.showError(__('polygon_boundary') + ' ' + __('is_required'));
                    return;
                }
            }
            if (!this.form.country_id) {
                this.showError(__('country_is_required_for_the_zone'));
                return;
            }
            /* A zone with no way to deliver cannot ship at all. Reachable only when the
               stored choice was a courier this zone's country has since lost. */
            if (this.servesEcommerce && !this.selectedVisibleDeliveryMethods.length) {
                this.activeChannelTab = 'ecommerce';
                this.showError(__('select_at_least_one_delivery_method'));
                return;
            }

            if (this.servesQuick) {
                const slots = this.form.quick.surge_slots || [];
                for (let i = 0; i < slots.length; i++) {
                    const s = slots[i] || {};
                    const label = (s.label ?? '').toString().trim();
                    const start = (s.start ?? '').toString().trim();
                    const end = (s.end ?? '').toString().trim();
                    const charge = Number(s.charge);
                    if (!label || !start || !end || !Number.isFinite(charge) || charge <= 0) {
                        this.showError(__('surge_slot_row_incomplete') + ' (#' + (i + 1) + ')');
                        return;
                    }
                }
            }

            // Additional charges are per channel, so validate each served one.
            for (const ns of this.servedChannels) {
                const charges = this.form[ns].additional_charges || [];
                for (let i = 0; i < charges.length; i++) {
                    const c = charges[i] || {};
                    const name = (c.name ?? '').toString().trim();
                    const amount = Number(c.amount);
                    if (!name || !Number.isFinite(amount) || amount <= 0) {
                        this.showError(__('additional_charge_row_incomplete') + ' (#' + (i + 1) + ')');
                        return;
                    }
                }
            }

            this.saving = true;
            try {
                if (!this.languages.length) await this.loadLanguages();
                const defLang = this.languages.find(l => Number(l.id) === Number(this.defaultLanguageId)) || this.languages[0];
                if (!defLang) {
                    this.showError(__('something_went_wrong'));
                    return;
                }
                const otherLangs = this.languages.filter(l => Number(l.id) !== Number(defLang.id));


                // Default language: full payload
                const fd = new FormData();
                if (this.form.id) fd.append('id', this.form.id);
                fd.append('language_id', defLang.id);
                fd.append('name', this.form.name);
                fd.append('city', this.form.city || '');
                fd.append('state', this.form.state || '');
                fd.append('region_id', this.form.region_id || '');
                fd.append('country_id', this.form.country_id || '');
                fd.append('delivery_charge_is_taxable', this.form.delivery_charge_is_taxable ? 1 : 0);
                fd.append('delivery_charge_tax_included', this.form.delivery_charge_tax_included ? 1 : 0);
                fd.append('delivery_charge_tax_category_id', this.form.delivery_charge_tax_category_id || '');
                fd.append('status', this.form.status);
                fd.append('sales_channel', this.form.sales_channel);
                fd.append('polygon_boundary_quick', JSON.stringify(this.form.polygon_boundary_quick || []));
                fd.append('polygon_boundary_ecommerce', JSON.stringify(this.form.polygon_boundary_ecommerce || []));

                // Each served channel posts its own prefixed block, so a 'both' zone
                // sends two independent pricing sets in one request.
                if (this.servesQuick) {
                    const q = this.form.quick;
                    fd.append('quick_distance_unit', q.distance_unit);
                    fd.append('quick_base_delivery_charge', q.base_delivery_charge || 0);
                    fd.append('quick_base_distance', q.base_distance || 0);
                    fd.append('quick_charge_per_km', q.charge_per_km || 0);
                    fd.append('quick_travel_time_per_km', q.travel_time_per_km || 0);
                    fd.append('quick_minimum_order_amount', q.minimum_order_amount || 0);
                    fd.append('quick_free_delivery_above', q.free_delivery_above || 0);
                    fd.append('quick_surge_slots', JSON.stringify(q.surge_slots || []));
                    fd.append('quick_additional_charges', JSON.stringify(q.additional_charges || []));
                    fd.append('quick_surge_labels', JSON.stringify((q.surge_slots || []).map(x => x.label ?? '')));
                    fd.append('quick_additional_charge_names', JSON.stringify((q.additional_charges || []).map(c => c.name ?? '')));
                }

                if (this.servesEcommerce) {
                    const e = this.form.ecommerce;
                    fd.append('ecommerce_pricing_strategy', e.pricing_strategy);
                    fd.append('ecommerce_courier_markup_type', e.courier_markup_type || 'none');
                    fd.append('ecommerce_courier_markup_value', e.courier_markup_value || 0);
                    fd.append('ecommerce_courier_round_to', e.courier_round_to || 0);
                    fd.append('ecommerce_courier_min_charge', e.courier_min_charge || 0);
                    (e.delivery_methods || []).forEach(m => fd.append('ecommerce_delivery_methods[]', m));
                    fd.append('ecommerce_delivery_days', Math.max(0, Number(e.delivery_days) || 0));
                    fd.append('ecommerce_default_delivery_charge', e.default_delivery_charge || 0);
                    fd.append('ecommerce_free_delivery_threshold', e.free_delivery_threshold || 0);
                    fd.append('ecommerce_flat_delivery_charge', e.flat_delivery_charge || 0);
                    fd.append('ecommerce_flat_free_delivery_above', e.flat_free_delivery_above || 0);
                    fd.append('ecommerce_slab_pricing', JSON.stringify(e.slab_pricing || []));
                    fd.append('ecommerce_city_pricing', JSON.stringify(e.city_pricing || []));
                    fd.append('ecommerce_area_pricing', JSON.stringify(e.area_pricing || []));
                    fd.append('ecommerce_additional_charges', JSON.stringify(e.additional_charges || []));
                    fd.append('ecommerce_additional_charge_names', JSON.stringify((e.additional_charges || []).map(c => c.name ?? '')));
                }

                const res = await axios.post(this.$apiUrl + '/zones/save', fd);
                if (res.data?.status === 0 || res.data?.error === true) {
                    this.showError(res.data?.message || __('something_went_wrong'));
                    return;
                }
                if (!this.form.id) {
                    this.form.id = res.data?.data?.id;
                }

                // Other languages: translation-only payload
                for (const lang of otherLangs) {
                    const tfd = new FormData();
                    if (this.form.id) tfd.append('id', this.form.id);
                    tfd.append('language_id', lang.id);

                    // Labels are per channel now, matching where the charges live.
                    for (const ns of this.servedChannels) {
                        const t = this.form[ns].translations?.[lang.id] || {};
                        const labels = Array.isArray(t.surge_labels) ? t.surge_labels : [];
                        const names = Array.isArray(t.additional_charge_names) ? t.additional_charge_names : [];
                        if (ns === 'quick') {
                            tfd.append('quick_surge_labels', JSON.stringify((this.form.quick.surge_slots || []).map((_, i) => labels[i] ?? '')));
                        }
                        tfd.append(ns + '_additional_charge_names', JSON.stringify((this.form[ns].additional_charges || []).map((_, i) => names[i] ?? '')));
                    }

                    const tRes = await axios.post(this.$apiUrl + '/zones/save', tfd);
                    if (tRes.data?.status === 0 || tRes.data?.error === true) {
                        this.showError(tRes.data?.message || __('something_went_wrong'));
                        return;
                    }
                }

                // Mark clean so the post-save redirect doesn't trip the unsaved-changes guard.
                this.captureFormBaseline();
                this.showMessage('success', __('zone_saved_successfully'));
                setTimeout(() => this.$router.push({ path: '/zones' }), 800);
            } catch (e) {
                this.showError(e.response?.data?.message || __('something_went_wrong'));
            } finally {
                this.saving = false;
            }
        },
        async getDefaultLanguageId() {
            try {
                const res = await axios.get(this.$apiUrl + '/active_languages');
                const langs = res.data?.data || [];
                const def = langs.find(l => l.is_default === 1) || langs[0];
                return def?.id ?? 1;
            } catch {
                return 1;
            }
        },
    },
};
</script>

<style scoped>
.zone-dm-list {
    display: flex;
    flex-wrap: wrap;
    gap: .5rem 1.25rem;
}

.zone-dm {
    display: inline-flex;
    align-items: center;
    gap: .55rem;
    min-height: 2rem;
    padding-left: 0;
    margin-bottom: 0;
}

.zone-dm .form-check-input {
    float: none;
    flex: 0 0 auto;
    margin: 0;
}

.zone-dm .form-check-label {
    display: inline-flex;
    align-items: center;
    gap: .4rem;
    margin: 0;
    cursor: pointer;
    white-space: nowrap;
}

/* The last method left on cannot be turned off — a zone with no way out could not ship
   at all — so it reads as fixed rather than broken. */
.zone-dm.is-locked .form-check-input,
.zone-dm.is-locked .form-check-label {
    opacity: .75;
}

.zone-dm.is-locked .form-check-label {
    cursor: not-allowed;
}

.zone-dm-icon {
    width: 16px;
    height: 16px;
    object-fit: contain;
    vertical-align: -2px;
    margin-right: 4px;
}

.zone-form .row.g-3 {
    justify-content: flex-start;
}

.zone-form .row > [class*="col-12"][class*="col-sm-4"],
.zone-form .row > [class*="col-12"][class*="col-sm-6"] {
    display: block;
}

.delivery-tax-row .form-check {
    margin-left: 0;
}
.zone-form .row > .col-auto > .form-check.form-switch {
    display: flex;
    align-items: center;
    min-height: calc(1.5em + 0.75rem + 2px);
    margin-top: 0;
    margin-bottom: 0;
}
</style>
