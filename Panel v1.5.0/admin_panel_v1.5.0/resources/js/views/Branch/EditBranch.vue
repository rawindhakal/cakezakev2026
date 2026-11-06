<template>
    <div class="list-page">
        <!-- Title + back button outside the cards. -->
        <div class="page-head">
            <h3 class="page-head-title">{{ profileMode ? __('my_profile') : (isEdit ? __('edit_branch') : __('add_branch')) }}</h3>
            <router-link v-if="!profileMode" to="/branches"
                class="btn btn-outline-secondary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap">
                <ArrowLeft :size="16" /> {{ __('back_to_branches') }}
            </router-link>
        </div>

        <div>
            <form @submit.prevent="saveBranch" novalidate>

                <!-- Basic Details -->
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title text-uppercase mb-0">{{ __('basic_details') }}</h5>
                        <small class="text-muted">{{ __('branch_identity_and_supplier_information') }}</small>
                    </div>
                    <div class="card-body">
                        <!-- Shared language tabs for name + provider. -->
                        <ul class="nav nav-tabs lang-tabs mb-3 align-items-center" v-if="languages.length > 1">
                            <li class="nav-item" v-for="lang in languages" :key="'basic-tab-' + lang.id">
                                <a class="nav-link" :class="{ active: activeLangTab === lang.id }" href="#"
                                    @click.prevent="activeLangTab = lang.id">
                                    {{ lang.display_name || lang.name }}
                                    <span v-if="lang.is_default == 1" class="text-danger">*</span>
                                </a>
                            </li>
                            <!-- Translate control, inline with the language tabs. -->
                            <li class="nav-item ms-auto d-flex align-items-center">
                                <TranslateLanguages :languages="languages" :default-language-id="defaultLanguageId"
                                    :busy="translating" :progress="translateProgress" @translate="runTranslate" />
                            </li>
                        </ul>
                        <div class="row g-3">
                            <div class="col-md-4">
                                <label class="form-label">{{ __('branch_name') }} <span class="text-danger">*</span></label>
                                <template v-for="lang in languages" :key="'nm-in-' + lang.id">
                                    <input v-show="activeLangTab === lang.id" type="text" class="form-control"
                                        v-model="nameByLang[lang.id]"
                                        :placeholder="__('branch_name')">
                                </template>
                                <small class="text-muted">{{ __('display_name_used_across_admin_and_customer_apps') }}</small>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">{{ __('provider_vendor') }}</label>
                                <template v-for="lang in languages" :key="'pv-in-' + lang.id">
                                    <input v-if="lang.id == defaultLangId" v-show="activeLangTab === lang.id" type="text"
                                        class="form-control" v-model="form.provider"
                                        :placeholder="__('provider_vendor') + ' (' + (lang.display_name || lang.name) + ')'">
                                    <input v-else v-show="activeLangTab === lang.id" type="text" class="form-control"
                                        v-model="providerByLang[lang.id]"
                                        :placeholder="__('provider_vendor')">
                                </template>
                                <small class="text-muted">{{ __('owner_or_operator_of_this_branch') }}</small>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">{{ __('contact_number') }} <span class="text-danger">*</span></label>
                                <input type="text" class="form-control" v-model="form.contact_number"
                                    placeholder="+91 98765 43210">
                                <small class="text-muted">{{ __('contact_details_for_branch_operations_team') }}</small>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">{{ __('email') }} <span class="text-danger">*</span></label>
                                <input type="email" class="form-control" v-model="form.email"
                                    placeholder="branch@example.com" :disabled="profileMode" :readonly="profileMode">
                                <small class="text-muted d-block">{{ profileMode ? __('email_cannot_be_changed_hint') : __('branch_login_email_hint') }}</small>
                            </div>
                            <template v-if="!profileMode">
                            <div class="col-md-4">
                                <label class="form-label">{{ __('password') }}
                                    <span v-if="!form.id" class="text-danger">*</span></label>
                                <div class="input-group">
                                    <input :type="showPassword ? 'text' : 'password'" class="form-control"
                                        v-model="form.password" autocomplete="new-password"
                                        :placeholder="form.id ? __('leave_blank_to_keep_current') : __('enter_password')">
                                    <button type="button" class="btn btn-outline-primary mb-0" @click="showPassword = !showPassword">
                                        <Eye v-if="showPassword" :size="16" />
                                        <EyeOff v-else :size="16" />
                                    </button>
                                </div>
                                <small v-if="passwordError" class="text-danger d-block mt-1">{{ passwordError }}</small>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">{{ __('confirm_password') }}
                                    <span v-if="!form.id" class="text-danger">*</span></label>
                                <div class="input-group">
                                    <input :type="showConfirmPassword ? 'text' : 'password'" class="form-control"
                                        v-model="form.confirm_password" autocomplete="new-password"
                                        :placeholder="__('confirm_password')">
                                    <button type="button" class="btn btn-outline-primary mb-0" @click="showConfirmPassword = !showConfirmPassword">
                                        <Eye v-if="showConfirmPassword" :size="16" />
                                        <EyeOff v-else :size="16" />
                                    </button>
                                </div>
                            </div>
                            </template>
                            <div class="col-12">
                                <label class="form-label d-block">{{ __('status') }}</label>
                                <div class="btn-group btn-group-toggle" role="group">
                                    <label class="btn btn-outline-primary" :class="{ active: form.status == 0 }">
                                        <input type="radio" :value="0" v-model.number="form.status" autocomplete="off"> {{ __('inactive') }}
                                    </label>
                                    <label class="btn btn-outline-primary" :class="{ active: form.status == 1 }">
                                        <input type="radio" :value="1" v-model.number="form.status" autocomplete="off"> {{ __('active') }}
                                    </label>
                                </div>
                                <small class="text-muted d-block mt-1">{{ __('inactive_branches_wont_show_up_for_new_orders') }}</small>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Type -->
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title text-uppercase mb-0">{{ __('type') }}</h5>
                        <small class="text-muted">{{ __('defines_how_orders_are_fulfilled_from_this_branch') }}</small>
                    </div>
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <label class="form-label">{{ __('fulfillment_type') }} <span class="text-danger">*</span></label>
                                <AppSelect class="form-select" v-model="form.fulfillment_type" :options="fulfillment_typeOptions" :searchable="false" :disabled="profileMode" @update:model-value="onFulfillmentChange" />
                                <small class="text-muted">{{ __('quick_rapid_delivery_ecommerce_scheduled_shipment') }}</small>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('zone') }} <span class="text-danger">*</span></label>
                                <!-- Every option already matches the chosen fulfillment
                                     type, so no channel suffix is needed. -->
                                <AppSelect class="form-select" v-model="form.zone_id" :options="zones"
                                    :placeholder="__('select_zone')" :disabled="profileMode" />
                                <small class="text-muted">{{ profileMode ? __('zone_cannot_be_changed_hint') : zoneHint }}</small>
                            </div>

                            <!-- Self pickup: what the branch offers, and (for a branch on both
                                 channels) on which of them a customer may collect. -->
                            <div class="col-md-6">
                                <label class="form-label">{{ __('service_modes') }} <span class="text-danger">*</span></label>
                                <AppSelect class="form-select" v-model="form.service_modes" :options="serviceModeOptions"
                                    :searchable="false" :disabled="profileMode" />
                                <small class="text-muted">{{ __('pickup_orders_are_collected_at_the_branch_address') }}</small>
                            </div>
                            <div class="col-md-6" v-if="form.service_modes !== 'delivery' && form.fulfillment_type === 'both'">
                                <label class="form-label">{{ __('pickup_channels') }}</label>
                                <AppSelect class="form-select" v-model="form.pickup_channels" :options="pickupChannelOptions"
                                    :searchable="false" :disabled="profileMode" />
                                <small class="text-muted">{{ __('pickup_channels_hint') }}</small>
                            </div>

                            <div class="col-md-6" v-if="zoneRegionName">
                                <label class="form-label">{{ __('state_region') }}</label>
                                <input type="text" class="form-control" :value="zoneRegionName" disabled>
                                <small class="text-muted">{{ __('inherited_from_zone') }}</small>
                            </div>

                            <div class="col-md-6" v-if="form.zone_id">
                                <label class="form-label">{{ __('tax_registration_number') }}</label>
                                <div class="d-flex gap-2">
                                    <input type="text" class="form-control" v-model="form.tax_number"
                                        :placeholder="taxNumberPlaceholder" :disabled="profileMode">
                                    <input type="text" class="form-control tax-type-input" v-model="form.tax_registration_type"
                                        :placeholder="__('label')" :disabled="profileMode">
                                </div>
                                <small class="text-muted">{{ __('tax_registration_hint') }}</small>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Location -->
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title text-uppercase mb-0">{{ __('location') }}</h5>
                        <small class="text-muted">{{ __('search_a_place_on_google_maps_fields_auto_filled') }}</small>
                    </div>
                    <div class="card-body">
                        <div class="border rounded p-3 mb-3 position-relative">
                            <!-- The language strip switches the address translations, so it
                                 spans the box rather than sitting in a column of its own. -->
                            <ul class="nav nav-tabs lang-tabs mb-2" v-if="languages.length > 1">
                                <li class="nav-item" v-for="lang in languages" :key="'ad-tab-' + lang.id">
                                    <a class="nav-link" :class="{ active: activeLangTab === lang.id }" href="#"
                                        @click.prevent="activeLangTab = lang.id">
                                        {{ lang.display_name || lang.name }}
                                    </a>
                                </li>
                            </ul>

                            <!-- Address and pincode read as one thing — where the parcel is
                                 collected from — so they share a row on a wide screen and
                                 stack on a narrow one. -->
                            <div class="row g-3">
                            <div class="col-lg-8">
                            <label class="form-label">{{ __('address') }}</label>
                            <template v-for="lang in languages" :key="'ad-in-' + lang.id">
                                <!-- Default language drives the place autocomplete + map; others are plain translations. -->
                                <input v-if="lang.id == defaultLangId" v-show="activeLangTab === lang.id" type="text"
                                    class="form-control" v-model="form.address"
                                    :placeholder="__('search_branch_location_on_google_maps')"
                                    @input="onAddressInput" autocomplete="off">
                                <input v-else v-show="activeLangTab === lang.id" type="text" class="form-control"
                                    v-model="addressByLang[lang.id]"
                                    :placeholder="__('address')">
                            </template>
                            <small class="text-muted">{{ __('street_address_used_for_pickup_and_driver_routing') }}</small>

                            <ul class="list-group place-suggestions" v-if="placeSuggestions.length">
                                <li class="list-group-item list-group-item-action" v-for="s in placeSuggestions"
                                    :key="s.placeId" @mousedown.prevent="selectPlace(s)">
                                    {{ s.text }}
                                </li>
                            </ul>
                            <div class="text-muted small mt-1" v-if="placeLoading">
                                <b-spinner small></b-spinner> {{ __('loading') }}
                            </div>
                            </div>

                            <!-- A courier collects from a pincode, and this is the only postal
                                 part the branch has no home for: city and state come from its
                                 zone, the contact from the number above. -->
                            <div class="col-lg-4">
                                <div>
                                    <label class="form-label">{{ __('pincode') }}</label>
                                    <div class="input-group branch-pincode">
                                        <input type="text" class="form-control" v-model="form.pincode" maxlength="16">
                                        <!-- Only when a shipping plugin is installed: it is the
                                             courier that answers whether it collects here. -->
                                        <button v-if="courierProvider" class="btn btn-outline-secondary mb-0" type="button"
                                            :disabled="pickupChecking || !form.pincode" @click="checkPickup">
                                            <b-spinner v-if="pickupChecking" small></b-spinner>
                                            {{ __('check_pickup') }}
                                        </button>
                                    </div>
                                    <small class="text-muted">{{ __('branch_pincode_hint') }}</small>

                                    <div v-if="pickupResult" class="small mt-2"
                                        :class="pickupResult.ok ? 'text-success' : 'text-danger'">
                                        <!-- One sentence, built in script: a ready address has no
                                             message of its own, and pasting a courier count after an
                                             empty string leaves a dangling dash. -->
                                        {{ pickupSummary }}
                                        <div v-if="pickupResult.nickname" class="text-muted">
                                            {{ courierProvider.label }}: {{ pickupResult.nickname }}
                                        </div>

                                        <!-- Collected from, but not known to the courier yet: one
                                             click registers this branch's own address, so the handle
                                             on both sides can never drift. -->
                                        <button v-if="pickupResult.can_register"
                                            class="btn btn-sm btn-outline-primary mt-2" type="button"
                                            :disabled="pickupRegistering || !isEdit" @click="registerPickup">
                                            <b-spinner v-if="pickupRegistering" small></b-spinner>
                                            {{ __('register_with') }} {{ courierProvider.label }}
                                        </button>
                                        <div v-if="pickupResult.can_register && !isEdit" class="text-muted">
                                            {{ __('save_the_branch_first_to_register_pickup') }}
                                        </div>
                                    </div>
                                </div>
                            </div>
                            </div>
                        </div>

                        <div class="mb-3">
                            <label class="form-label">{{ __('pin_branch_location_on_map') }}</label>
                            <div ref="mapContainer" class="branch-map"></div>
                            <small class="text-muted d-block mt-1">{{ __('click_or_drag_marker_to_set_coordinates') }}</small>
                        </div>

                        <div class="row g-3">
                            <div class="col-md-6">
                                <label class="form-label">{{ __('latitude') }} <span class="text-danger">*</span></label>
                                <input type="text" class="form-control" v-model="form.latitude" disabled readonly>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">{{ __('longitude') }} <span class="text-danger">*</span></label>
                                <input type="text" class="form-control" v-model="form.longitude" disabled readonly>
                            </div>
                        </div>
                    </div>
                </div>


                <!-- Owner permissions — the ceiling the branch owner can delegate to sub-users. -->
                <div class="card" v-if="!profileMode">
                    <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2">
                        <div>
                            <h5 class="card-title text-uppercase mb-0">{{ __('owner_permissions') }}</h5>
                            <small class="text-muted">{{ __('owner_permissions_hint') }}</small>
                        </div>
                        <button type="button" class="btn btn-primary mb-0" @click="openPermModal">
                            <ShieldCheck :size="16" class="me-1" />
                            {{ __('give_permission') }}
                            <span class="badge bg-light text-dark ms-1">{{ ownerPermissionIds.length }}</span>
                        </button>
                    </div>
                </div>

                <!-- Owner permission picker modal (mirrors the Edit Role modal). -->
                <b-modal ref="perm-modal" size="xl" scrollable no-close-on-backdrop no-fade static
                    @hidden="onPermModalHidden">
                    <template #modal-header="{ close }">
                        <h5 class="modal-title">{{ __('owner_permissions') }}</h5>
                        <button type="button" aria-label="Close" class="close" @click="close()">×</button>
                    </template>
                    <div class="d-flex justify-content-end mb-2">
                        <div class="btn-group btn-group-sm">
                            <button type="button" class="btn btn-outline-primary mb-0" @click="setAllPermissions(true)">{{ __('select_all') }}</button>
                            <button type="button" class="btn btn-outline-secondary mb-0" @click="setAllPermissions(false)">{{ __('deselect_all') }}</button>
                        </div>
                    </div>
                    <div class="table-responsive">
                        <table class="table table-lg table-striped">
                            <tbody>
                                <tr v-for="cat in permCategories" :key="cat.id">
                                    <th class="table-active">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" :id="'catall_' + cat.id"
                                                :checked="isCategoryAllChecked(cat)"
                                                @change="toggleCategory(cat, $event.target.checked)">
                                            <label class="form-check-label fw-bold" :for="'catall_' + cat.id">{{ formattedName(cat.name) }}</label>
                                        </div>
                                    </th>
                                    <td>
                                        <div class="row">
                                            <div class="col-12 col-md-6 col-lg-4 mb-2" v-for="perm in cat.permissions" :key="perm.id">
                                                <div class="form-check form-switch">
                                                    <input class="form-check-input" type="checkbox" :id="'perm_' + perm.id"
                                                        :value="perm.id" v-model="ownerPermissionIds" @change="onOwnerPermToggle(perm)">
                                                    <label class="form-check-label" style="margin-left: 5px" :for="'perm_' + perm.id">{{ formattedName(perm.name) }}</label>
                                                </div>
                                            </div>
                                        </div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    <template #footer>
                        <b-button variant="primary" @click="applyPermModal">{{ __('done') }}</b-button>
                        <b-button variant="secondary" @click="cancelPermModal">{{ __('cancel') }}</b-button>
                    </template>
                </b-modal>

                <!-- Operations — only relevant for quick-commerce fulfillment. -->
                <div class="card" v-if="form.fulfillment_type === 'quick' || form.fulfillment_type === 'both'">
                    <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2">
                        <div>
                            <h5 class="card-title text-uppercase mb-0">{{ __('operations') }}</h5>
                            <small class="text-muted">{{ __('set_opening_closing_break_time_per_day') }}</small>
                        </div>
                        <div class="text-muted small d-inline-flex align-items-center gap-2">
                            <Info :size="15" /> {{ __('operating_hours_apply_to_quick_orders_only') }}
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="row mb-4">
                            <div class="col-md-4">
                                <label class="form-label">{{ __('preparation_time') }}</label>
                                <div class="input-group">
                                    <input type="number" min="0" step="1" class="form-control"
                                        v-model.number="form.preparation_time" placeholder="0">
                                    <span class="input-group-text">{{ __('minutes') }}</span>
                                </div>
                                <small class="text-muted">{{ __('preparation_time_hint') }}</small>
                            </div>
                        </div>
                        <div class="text-muted small d-inline-flex align-items-center gap-2 mb-3">
                            <Info :size="15" /> {{ __('leave_time_empty_to_keep_branch_open') }}
                        </div>
                        <div v-for="day in days" :key="day.key" class="border rounded p-3 mb-3">
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <h6 class="mb-0">{{ __(day.key) }}</h6>
                                <div class="d-flex align-items-center gap-3">
                                    <!-- Only on Monday: it is the source row, so the copy
                                         direction is unambiguous. -->
                                    <button v-if="day.key === 'monday'" type="button"
                                        class="btn btn-sm btn-outline-primary py-0"
                                        @click="applyMondayToAllDays">
                                        <Copy :size="14" class="me-1" />{{ __('apply_to_all_days') }}
                                    </button>
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" :id="'closed_' + day.key"
                                            v-model="form.operating_hours[day.key].closed">
                                        <label class="form-check-label" :for="'closed_' + day.key">{{ __('closed') }}</label>
                                    </div>
                                </div>
                            </div>
                            <div class="row g-3" v-if="!form.operating_hours[day.key].closed">
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('opening') }}</label>
                                    <TimePicker v-model="form.operating_hours[day.key].open" />
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('closing') }}</label>
                                    <TimePicker v-model="form.operating_hours[day.key].close" />
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('break_time') }} <small class="text-muted">({{ __('optional') }})</small></label>
                                    <div class="d-flex align-items-center gap-1">
                                        <TimePicker class="flex-grow-1" :model-value="breakPart(day.key, 0)"
                                            @update:model-value="setBreak(day.key, 0, $event)" :aria-label="__('break_start')" />
                                        <span class="text-muted">–</span>
                                        <TimePicker class="flex-grow-1" :model-value="breakPart(day.key, 1)"
                                            @update:model-value="setBreak(day.key, 1, $event)" :aria-label="__('break_end')" />
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Actions -->
                <div class="card">
                    <div class="card-body">
                        <div class="text-end">
                            <router-link to="/branches" class="btn btn-secondary me-2">{{ __('cancel') }}</router-link>
                            <button type="submit" class="btn btn-primary" :disabled="saving">
                                <b-spinner small v-if="saving"></b-spinner>
                                {{ isEdit ? __('update_branch') : __('save_branch') }}
                            </button>
                        </div>
                    </div>
                </div>
            </form>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import L from 'leaflet';
import { osmTileUrl, OSM_TILE_OPTIONS } from '../../utils/mapTiles.js';
import 'leaflet/dist/leaflet.css';
import { loadGoogleMaps } from '../../utils/googleMaps.js';
import { Info, ArrowLeft, Copy, Eye, EyeOff, ShieldCheck } from 'lucide-vue-next';
import TimePicker from '../../components/TimePicker.vue';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
import { fetchPasswordPolicy, passwordPolicyError } from '../../utils/passwordPolicy.js';
import { cascadePermission } from '../../utils/permissionCascade.js';

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
    iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
    shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

const DAY_KEYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

export default {
    name: 'EditBranch',
    mixins: [TranslationHelper, UnsavedChanges],
    components: { TimePicker, Info, ArrowLeft, Copy, Eye, EyeOff, ShieldCheck },
    data() {
        return {
            isEdit: false,
            profileMode: false,
            // Courier pickup check. `courierProvider` stays null with no shipping plugin
            // installed, which hides the button entirely.
            courierProvider: null,
            pickupChecking: false,
            pickupRegistering: false,
            pickupResult: null,
            saving: false,
            showPassword: false,
            showConfirmPassword: false,
            passwordPolicy: null,
            form: this.emptyForm(),
            permCategories: [],
            ownerPermissionIds: [],
            _permSnapshot: [],
            _permApplied: false,
            languages: [],
            nameByLang: {},
            providerByLang: {},
            addressByLang: {},
            activeLangTab: null,
            defaultLangId: null,
            translatableFields: ['name', 'provider', 'address'],
            zones: [],
            _zonesSeq: 0,
            days: DAY_KEYS.map(k => ({ key: k })),
            mapProvider: 'osm',
            googleMapKey: '',
            map: null,
            marker: null,
            gmap: null,
            gmarker: null,
            placeSuggestions: [],
            placeLoading: false,
            placeTimer: null,
            suppressAddressSearch: false,
            placeSessionToken: null,
            lastPlaceQuery: '',
            placeAbort: null,
        };
    },
    watch: {
    },
    computed: {
        /**
         * What the pickup check says, as one sentence.
         *
         * The carrier answers in two parts — a reason, which is empty when nothing is
         * wrong, and a courier count, which is absent when nothing serves the pincode.
         * Only this one place has to know how the combinations read together; pasting
         * the count onto an empty reason is what left a dangling dash on screen.
         */
        pickupSummary() {
            const r = this.pickupResult;
            if (!r) return '';

            const parts = [];
            if (r.message) parts.push(r.message);
            else if (r.ok) parts.push(this.__('the_courier_can_collect_from_here'));
            if (r.couriers) {
                parts.push(r.couriers === 1
                    ? this.__('one_courier_serves_this_pincode')
                    : this.__('couriers_serve_this_pincode', { count: r.couriers }));
            }

            return parts.join(' — ');
        },
        /** The zone's region — what this branch is taxed as. */
        zoneRegionName() {
            const zone = (this.zones || []).find(z => Number(z.id) === Number(this.form.zone_id));
            return zone && zone.region_name ? zone.region_name : '';
        },
        taxNumberPlaceholder() {
            return __('tax_registration_number');
        },
        // Inline password policy error (empty when valid or password left blank).
        passwordError() {
            if (!this.form.password) return '';
            return passwordPolicyError(this.form.password, this.passwordPolicy);
        },
        // Fixed option set — no search box needed.
        fulfillment_typeOptions() {
            return [
                { id: 'quick', name: (__('quick_commerce')) },
                { id: 'ecommerce', name: (__('ecommerce')) },
                { id: 'both', name: (__('both')) },
            ];
        },
        serviceModeOptions() {
            return [
                { id: 'delivery', name: __('home_delivery_only') },
                { id: 'pickup', name: __('self_pickup_only') },
                { id: 'both', name: __('delivery_and_pickup') },
            ];
        },
        pickupChannelOptions() {
            return [
                { id: 'both', name: __('both') },
                { id: 'quick', name: __('quick_commerce') },
                { id: 'ecommerce', name: __('ecommerce') },
            ];
        },
        // Type row: 2 fields (single channel) -> 50/50, 3 fields (both) -> thirds.
        // Tell the admin why the list is filtered the way it is.
        zoneHint() {
            return __('only_zones_matching_fulfillment_type_shown');
        },
        // The translate mixin/component expect `defaultLanguageId`; this form calls it `defaultLangId`.
        defaultLanguageId() {
            return this.defaultLangId;
        },
    },
    async created() {
        this.profileMode = !!(this.$route.meta && this.$route.meta.branchProfile);
        this.isEdit = this.profileMode || !!this.$route.params.id;
        await this.loadLanguages();
        // Branch owner editing its own profile can't fetch the admin permission catalog.
        if (!this.profileMode) {
            await this.loadPermissionCatalog();
        }
        // On edit, loadBranch() fires loadZones() once the real fulfillment_type is
        // known — requesting here first would race it with the default 'quick'.
        if (this.profileMode) {
            this.loadBranch(null, this.$apiUrl + '/branch_panel/profile');
        } else if (this.isEdit) {
            this.loadBranch(this.$route.params.id);
        } else {
            this.loadZones();
            // Empty create form — snapshot the clean baseline for the unsaved-changes guard.
            this.captureFormBaseline();
        }
    },
    async mounted() {
        fetchPasswordPolicy().then(p => { this.passwordPolicy = p; });
        this.loadCourierProvider();
        await this.loadMapProvider();
        this.$nextTick(() => this.initMap());
    },
    beforeUnmount() {
        if (this.map) {
            this.map.remove();
            this.map = null;
        }
        this.gmap = null;
        this.gmarker = null;
    },
    methods: {
        /** Is a courier installed that could collect from a branch? */
        loadCourierProvider() {
            axios.get(this.$apiUrl + '/orders/shipping/providers')
                .then(res => {
                    if (res.data.status !== 1) return;
                    const usable = (res.data.data.providers || []).filter(
                        p => p.configured && (p.channels || []).includes('ecommerce'));
                    this.courierProvider = usable.length ? usable[0] : null;
                })
                .catch(() => { /* no courier installed; the check is simply not offered */ });
        },
        /**
         * Register this branch's address with the courier, then re-check so the form
         * shows the handle it was given rather than claiming success on its own.
         */
        registerPickup() {
            this.pickupRegistering = true;
            axios.post(this.$apiUrl + '/branches/register_pickup', {
                branch_id: this.$route.params.id,
                pincode: this.form.pincode,
                address: this.form.address,
                branch_name: this.form.name,
                contact_number: this.form.contact_number || '',
                email: this.form.email || '',
            })
                .then(res => {
                    const d = res.data;
                    if (d.status !== 1) { this.showError(d.message); return; }
                    this.showMessage('success', d.message);
                    this.checkPickup();
                })
                .catch(err => {
                    this.showError(err?.response?.data?.message || __('something_went_wrong'));
                })
                .finally(() => { this.pickupRegistering = false; });
        },
        /**
         * Ask the courier whether it collects from this pincode, and whether this branch
         * is registered with it. A saved branch is checked by id so the plugin can also
         * resolve its pickup address; an unsaved one is checked by pincode alone.
         */
        checkPickup() {
            this.pickupChecking = true;
            this.pickupResult = null;

            const params = { pincode: this.form.pincode };
            if (this.isEdit && this.$route.params.id) {
                params.branch_id = this.$route.params.id;
            }

            axios.get(this.$apiUrl + '/branches/check_pickup', { params })
                .then(res => {
                    const d = res.data;
                    if (d.status !== 1) { this.showError(d.message); return; }
                    this.pickupResult = d.data.checked
                        ? d.data
                        : { ok: false, message: d.data.message, couriers: 0, nickname: null };
                })
                .catch(err => {
                    this.showError(err?.response?.data?.message || __('something_went_wrong'));
                })
                .finally(() => { this.pickupChecking = false; });
        },
        // Tracked state for the UnsavedChanges guard (warn before leaving with edits).
        formState() {
            return {
                form: this.form,
                nameByLang: this.nameByLang,
                providerByLang: this.providerByLang,
                addressByLang: this.addressByLang,
                ownerPermissionIds: this.ownerPermissionIds,
            };
        },
        // Three parallel per-language maps; the default language's provider/address live
        // on the main form object.
        getTranslateSource() {
            return {
                name: this.nameByLang[this.defaultLangId] || '',
                provider: this.form.provider || '',
                address: this.form.address || '',
            };
        },
        applyTranslated(lang, translated) {
            if (translated.name != null) this.nameByLang[lang.id] = translated.name;
            if (translated.provider != null) this.providerByLang[lang.id] = translated.provider;
            if (translated.address != null) this.addressByLang[lang.id] = translated.address;
        },
        // Load the branch-permission catalog (owner ceiling). On create, pre-check all.
        async loadPermissionCatalog() {
            try {
                const res = await axios.get(this.$apiUrl + '/branches/permission_catalog');
                this.permCategories = res.data?.data?.categories || [];
                if (!this.isEdit) this.setAllPermissions(true);
            } catch (e) {
                this.permCategories = [];
            }
        },
        onOwnerPermToggle(perm) {
            this.ownerPermissionIds = cascadePermission(this.ownerPermissionIds, this.permCategories, perm);
        },
        allPermissionIds() {
            return this.permCategories.flatMap(c => (c.permissions || []).map(p => p.id));
        },
        setAllPermissions(checked) {
            this.ownerPermissionIds = checked ? this.allPermissionIds() : [];
        },
        openPermModal() {
            this._permSnapshot = [...this.ownerPermissionIds];
            this._permApplied = false;
            const m = this.$refs['perm-modal'];
            if (m && typeof m.show === 'function') m.show();
        },
        applyPermModal() {
            this._permApplied = true;
            const m = this.$refs['perm-modal'];
            if (m && typeof m.hide === 'function') m.hide();
        },
        cancelPermModal() {
            const m = this.$refs['perm-modal'];
            if (m && typeof m.hide === 'function') m.hide();
        },
        // On any close, revert to snapshot unless the user pressed Done.
        onPermModalHidden() {
            if (!this._permApplied) this.ownerPermissionIds = [...this._permSnapshot];
        },
        isCategoryAllChecked(cat) {
            const ids = (cat.permissions || []).map(p => p.id);
            return ids.length > 0 && ids.every(id => this.ownerPermissionIds.includes(id));
        },
        toggleCategory(cat, checked) {
            const ids = (cat.permissions || []).map(p => p.id);
            if (checked) {
                this.ownerPermissionIds = Array.from(new Set([...this.ownerPermissionIds, ...ids]));
            } else {
                this.ownerPermissionIds = this.ownerPermissionIds.filter(id => !ids.includes(id));
            }
        },
        emptyForm() {
            const hours = {};
            DAY_KEYS.forEach(k => {
                // New branches default to 7 AM – 11 PM. Leaving a day's times blank means
                // the branch is treated as open all day (see the note in the Operations card).
                hours[k] = { open: '07:00', close: '23:00', break_time: '', closed: false };
            });
            return {
                id: null,
                name: '',
                code: '',
                provider: '',
                fulfillment_type: 'quick',
                service_modes: 'delivery',
                pickup_channels: 'both',
                zone_id: null,
                tax_number: '',
                tax_registration_type: '',
                address: '',
                latitude: '',
                longitude: '',
                formatted_address: '',
                place_id: '',
                contact_number: '',
                pincode: '',
                email: '',
                password: '',
                confirm_password: '',
                operating_hours: hours,
                preparation_time: 0,
                status: 1,
            };
        },
        // break_time is stored as "HH:MM-HH:MM"; idx 0 = start, 1 = end.
        // Copy Monday's timings onto every other day. Monday is always the source, so
        // the result doesn't depend on which card the admin happens to be looking at.
        applyMondayToAllDays() {
            const src = this.form.operating_hours.monday || {};
            DAY_KEYS.filter(k => k !== 'monday').forEach(k => {
                this.form.operating_hours[k] = {
                    ...this.form.operating_hours[k],
                    open: src.open || '',
                    close: src.close || '',
                    break_time: src.break_time || '',
                    closed: !!src.closed,
                };
            });
            this.showMessage('success', __('monday_timings_copied_to_all_days'));
        },
        breakPart(dayKey, idx) {
            const bt = this.form.operating_hours[dayKey].break_time || '';
            const parts = bt.split('-');
            return (parts[idx] || '').trim();
        },
        setBreak(dayKey, idx, val) {
            let start = this.breakPart(dayKey, 0);
            let end = this.breakPart(dayKey, 1);
            if (idx === 0) start = val; else end = val;
            this.form.operating_hours[dayKey].break_time = (start || end) ? `${start}-${end}` : '';
        },
        async loadMapProvider() {
            try {
                const res = await axios.get(this.$apiUrl + '/store_settings');
                const rows = res.data?.data?.store_settings || [];
                const get = v => (rows.find(r => r.variable === v) || {}).value || '';
                this.mapProvider = get('map_provider') === 'google' ? 'google' : 'osm';
                this.googleMapKey = get('googleMapApiKey');
            } catch {
                this.mapProvider = 'osm';
            }
        },
        initMap() {
            if (this.mapProvider === 'google') {
                this.initGoogleMap();
            } else {
                this.initLeafletMap();
            }
        },
        initLeafletMap() {
            if (!this.$refs.mapContainer || this.map) return;
            const lat = parseFloat(this.form.latitude) || 22.0;
            const lng = parseFloat(this.form.longitude) || 79.0;
            const hasCoords = this.form.latitude !== '' && this.form.longitude !== '';

            this.map = L.map(this.$refs.mapContainer).setView([lat, lng], hasCoords ? 14 : 5);
            L.tileLayer(osmTileUrl(), OSM_TILE_OPTIONS).addTo(this.map);

            this.map.on('click', e => this.setMarker(e.latlng.lat, e.latlng.lng, true));

            if (hasCoords) {
                this.setMarker(lat, lng, false);
            }
        },
        async initGoogleMap() {
            if (!this.$refs.mapContainer || this.gmap) return;
            try {
                await loadGoogleMaps(this.googleMapKey, []);
            } catch (e) {
                // Key missing/invalid — fall back to free Leaflet map.
                this.mapProvider = 'osm';
                this.initLeafletMap();
                return;
            }
            const lat = parseFloat(this.form.latitude) || 22.0;
            const lng = parseFloat(this.form.longitude) || 79.0;
            const hasCoords = this.form.latitude !== '' && this.form.longitude !== '';

            this.gmap = new google.maps.Map(this.$refs.mapContainer, {
                center: { lat, lng },
                zoom: hasCoords ? 14 : 5,
                streetViewControl: false,
                mapTypeControl: true,
                fullscreenControl: true,
            });
            this.gmap.addListener('click', e => this.setMarker(e.latLng.lat(), e.latLng.lng(), true));

            if (hasCoords) {
                this.setMarker(lat, lng, false);
            }
        },
        setMarker(lat, lng, syncForm) {
            if (this.mapProvider === 'google') {
                this.setGoogleMarker(lat, lng, syncForm);
            } else {
                this.setLeafletMarker(lat, lng, syncForm);
            }
        },
        setLeafletMarker(lat, lng, syncForm) {
            if (!this.map) return;
            if (this.marker) {
                this.marker.setLatLng([lat, lng]);
            } else {
                this.marker = L.marker([lat, lng], { draggable: true }).addTo(this.map);
                this.marker.on('dragend', () => {
                    const p = this.marker.getLatLng();
                    this.form.latitude = String(p.lat);
                    this.form.longitude = String(p.lng);
                });
            }
            if (syncForm) {
                this.form.latitude = String(lat);
                this.form.longitude = String(lng);
            }
            this.map.setView([lat, lng], Math.max(this.map.getZoom(), 14));
        },
        setGoogleMarker(lat, lng, syncForm) {
            if (!this.gmap) return;
            const pos = { lat, lng };
            if (this.gmarker) {
                this.gmarker.setPosition(pos);
            } else {
                this.gmarker = new google.maps.Marker({ position: pos, map: this.gmap, draggable: true });
                this.gmarker.addListener('dragend', () => {
                    const p = this.gmarker.getPosition();
                    this.form.latitude = String(p.lat());
                    this.form.longitude = String(p.lng());
                });
            }
            if (syncForm) {
                this.form.latitude = String(lat);
                this.form.longitude = String(lng);
            }
            this.gmap.setCenter(pos);
            this.gmap.setZoom(Math.max(this.gmap.getZoom(), 14));
        },
        // Fulfillment type decides which zones qualify, so reload the list.
        onFulfillmentChange() {
            this.loadZones();
        },
        // A branch has one zone. The server returns only zones that can back this
        // fulfillment type and that no other branch already owns.
        async loadZones() {
            // Responses can arrive out of order (switching type quickly, or the edit
            // page's initial load); only the newest request may write the list.
            const seq = ++this._zonesSeq;
            const wanted = this.form.fulfillment_type;

            const res = await axios.get(this.$apiUrl + '/branches/zones_for_type', {
                params: {
                    branch_id: this.$route.params.id || '',
                    fulfillment_type: wanted,
                },
            }).catch(() => null);

            if (seq !== this._zonesSeq) return; // superseded
            this.zones = res?.data?.data?.zones || [];

            // Drop a selection the new fulfillment type no longer allows.
            if (this.form.zone_id && !this.zones.some(z => Number(z.id) === Number(this.form.zone_id))) {
                this.form.zone_id = null;
            }
        },
        makeSessionToken() {
            return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, c => {
                const r = (Math.random() * 16) | 0;
                return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
            });
        },
        onAddressInput() {
            if (this.suppressAddressSearch) {
                this.suppressAddressSearch = false;
                return;
            }
            const q = (this.form.address || '').trim();
            clearTimeout(this.placeTimer);
            if (q.length < 3) {
                this.placeSuggestions = [];
                this.lastPlaceQuery = '';
                return;
            }
            if (q === this.lastPlaceQuery) {
                return;
            }
            this.placeTimer = setTimeout(() => this.fetchPlaceSuggestions(q), 500);
        },
        fetchPlaceSuggestions(input) {
            if (input === this.lastPlaceQuery) return;
            this.lastPlaceQuery = input;

            if (!this.placeSessionToken) {
                this.placeSessionToken = this.makeSessionToken();
            }
            if (this.placeAbort) {
                this.placeAbort.abort();
            }
            this.placeAbort = new AbortController();

            this.placeLoading = true;
            axios.get(this.$baseUrl + '/customer/places_autocomplete', {
                params: { input, source: 'web', sessiontoken: this.placeSessionToken },
                signal: this.placeAbort.signal,
            })
                .then(res => {
                    const list = res.data?.data?.suggestions || [];
                    this.placeSuggestions = list.map(s => ({
                        placeId: s.placePrediction?.placeId || '',
                        text: s.placePrediction?.text?.text || '',
                    })).filter(s => s.placeId);
                })
                .catch(err => {
                    if (!axios.isCancel(err) && err.name !== 'CanceledError') {
                        this.placeSuggestions = [];
                    }
                })
                .finally(() => { this.placeLoading = false; });
        },
        selectPlace(s) {
            this.placeSuggestions = [];
            this.lastPlaceQuery = s.text;
            this.placeLoading = true;
            axios.get(this.$baseUrl + '/customer/places_details', {
                params: { place_id: s.placeId, source: 'web', sessiontoken: this.placeSessionToken },
            })
                .then(res => {
                    const d = res.data?.data;
                    if (!d) return;
                    const lat = d.location?.latitude;
                    const lng = d.location?.longitude;
                    const comp = d.addressComponents || [];
                    const get = type => {
                        const c = comp.find(c => (c.types || []).includes(type));
                        return c?.longText || '';
                    };
                    this.suppressAddressSearch = true;
                    this.form.address = d.formattedAddress || s.text;
                    this.form.formatted_address = d.formattedAddress || '';
                    this.form.place_id = s.placeId;
                    if (lat != null && lng != null) {
                        this.form.latitude = String(lat);
                        this.form.longitude = String(lng);
                        this.setMarker(Number(lat), Number(lng), false);
                    }

                    const postal = get('postal_code') || get('postal_code_prefix');
                    if (postal) {
                        this.form.pincode = postal.trim().slice(0, 16);
                        this.pickupResult = null;
                    }
                })
                .catch(err => this.showError(err.response?.data?.message || __('something_went_wrong')))
                .finally(() => {
                    this.placeLoading = false;
                    // End billing session; next search starts a fresh token.
                    this.placeSessionToken = null;
                });
        },
        async loadBranch(id, url = null) {
            try {
                const res = await axios.get(url || (this.$apiUrl + '/branches/edit/' + id));
                const data = res.data?.data;
                if (!data) {
                    this.showError(__('branch_not_found'));
                    return;
                }
                Object.assign(this.form, this.emptyForm(), {
                    id: data.id,
                    name: data.name || '',
                    code: data.code || '',
                    provider: data.provider || '',
                    fulfillment_type: data.fulfillment_type || 'quick',
                    service_modes: data.service_modes || 'delivery',
                    pickup_channels: data.pickup_channels || 'both',
                    zone_id: data.zone_id ? Number(data.zone_id) : null,
                    tax_number: data.tax_number || '',
                    tax_registration_type: data.tax_registration_type || '',
                    address: data.address || '',
                    latitude: data.latitude || '',
                    longitude: data.longitude || '',
                    formatted_address: data.formatted_address || '',
                    place_id: data.place_id || '',
                    contact_number: data.contact_number || '',
                    pincode: data.pincode || '',
                    email: data.email || '',
                    operating_hours: this.normaliseHours(data.operating_hours),
                    preparation_time: Number(data.preparation_time) || 0,
                    status: Number(data.status ?? 1),
                });
                this.ownerPermissionIds = Array.isArray(data.owner_permission_ids)
                    ? data.owner_permission_ids.map(Number) : [];
                // Map per-language name/provider/address from translations.
                // Default language uses the base columns; others come from translations.
                this.languages.forEach(l => { this.nameByLang[l.id] = ''; this.providerByLang[l.id] = ''; this.addressByLang[l.id] = ''; });
                if (this.defaultLangId) this.nameByLang[this.defaultLangId] = data.name || '';
                const translations = Array.isArray(data.translations) ? data.translations : [];
                translations.forEach(t => {
                    if (t.language_id == null) return;
                    if ((t.name ?? '') !== '') this.nameByLang[t.language_id] = t.name;
                    if (t.language_id != this.defaultLangId) {
                        if ((t.provider ?? '') !== '') this.providerByLang[t.language_id] = t.provider;
                        if ((t.address ?? '') !== '') this.addressByLang[t.language_id] = t.address;
                    }
                });

                if (this.profileMode) {
                    this.zones = data.zone ? [{ id: Number(data.zone.id), name: data.zone.name }] : [];
                } else {
                    await this.loadZones();
                }
                if (this.form.latitude !== '' && this.form.longitude !== '') {
                    this.$nextTick(() => this.setMarker(parseFloat(this.form.latitude), parseFloat(this.form.longitude), false));
                }
                // Branch loaded — snapshot the clean baseline for the unsaved-changes guard.
                this.captureFormBaseline();
            } catch (e) {
                this.showError(e.response?.data?.message || __('something_went_wrong'));
            }
        },
        normaliseHours(raw) {
            const base = {};
            DAY_KEYS.forEach(k => {
                base[k] = { open: '', close: '', break_time: '', closed: false };
            });
            const parsed = this.parseArr(raw);
            if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
                DAY_KEYS.forEach(k => {
                    if (parsed[k]) Object.assign(base[k], parsed[k]);
                });
            }
            return base;
        },
        parseArr(v) {
            if (Array.isArray(v) || (v && typeof v === 'object')) return v;
            if (typeof v === 'string' && v.length) {
                try { return JSON.parse(v); } catch { return []; }
            }
            return [];
        },
        async loadLanguages() {
            try {
                const res = await axios.get(this.$apiUrl + '/active_languages');
                const langs = res.data?.data || [];
                // Default language first.
                this.languages = [...langs].sort((a, b) => (b.is_default == 1) - (a.is_default == 1));
                const def = this.languages.find(l => l.is_default == 1) || this.languages[0];
                this.defaultLangId = def?.id ?? 1;
                this.activeLangTab = this.defaultLangId;
                this.languages.forEach(l => {
                    if (this.nameByLang[l.id] === undefined) this.nameByLang[l.id] = '';
                    if (this.providerByLang[l.id] === undefined) this.providerByLang[l.id] = '';
                    if (this.addressByLang[l.id] === undefined) this.addressByLang[l.id] = '';
                });
            } catch {
                this.languages = [];
                this.defaultLangId = 1;
                this.activeLangTab = 1;
                this.nameByLang = { 1: '' };
                this.providerByLang = { 1: '' };
                this.addressByLang = { 1: '' };
            }
        },
        async saveBranch() {
            const defaultName = (this.nameByLang[this.defaultLangId] || '').trim();
            if (!defaultName) {
                this.showError(__('branch_name') + ' ' + __('is_required'));
                return;
            }
            if (this.form.latitude === '' || this.form.latitude === null || this.form.longitude === '' || this.form.longitude === null) {
                this.showError(__('please_select_branch_location_on_map'));
                return;
            }
            if (!this.form.zone_id) {
                this.showError(__('please_select_a_zone'));
                return;
            }
            if (!String(this.form.contact_number || '').trim()) {
                this.showError(__('contact_number') + ' ' + __('is_required'));
                return;
            }
            if (!this.form.id && !this.form.password) {
                this.showError(__('password') + ' ' + __('is_required'));
                return;
            }
            if (this.form.password && this.passwordError) {
                this.showError(this.passwordError);
                return;
            }
            if (this.form.password && this.form.password !== this.form.confirm_password) {
                this.showError(__('password_and_confirm_password_must_match'));
                return;
            }
            this.saving = true;
            // Profile mode posts to the self endpoint (own branch forced server-side).
            const saveUrl = this.profileMode
                ? (this.$apiUrl + '/branch_panel/profile')
                : (this.$apiUrl + '/branches/save');
            try {
                // 1) Default-language pass — saves all branch fields + default name.
                const fd = new FormData();
                if (this.form.id) fd.append('id', this.form.id);
                fd.append('language_id', this.defaultLangId);
                fd.append('name', defaultName);
                fd.append('provider', this.form.provider || '');
                fd.append('fulfillment_type', this.form.fulfillment_type);
                fd.append('service_modes', this.form.service_modes || 'delivery');
                // A single-channel branch can only offer pickup on that channel.
                fd.append('pickup_channels', this.form.fulfillment_type === 'both'
                    ? (this.form.pickup_channels || 'both')
                    : this.form.fulfillment_type);
                fd.append('zone_id', this.form.zone_id || '');
                fd.append('tax_number', this.form.tax_number || '');
                fd.append('tax_registration_type', this.form.tax_registration_type || '');
                fd.append('address', this.form.address || '');
                fd.append('latitude', this.form.latitude || '');
                fd.append('longitude', this.form.longitude || '');
                fd.append('formatted_address', this.form.formatted_address || '');
                fd.append('place_id', this.form.place_id || '');
                fd.append('contact_number', this.form.contact_number || '');
                fd.append('pincode', this.form.pincode || '');
                fd.append('email', this.form.email || '');
                if (this.form.password) {
                    fd.append('password', this.form.password);
                    fd.append('confirm_password', this.form.confirm_password || '');
                }
                fd.append('operating_hours', JSON.stringify(this.form.operating_hours));
                fd.append('preparation_time', Math.max(0, Number(this.form.preparation_time) || 0));
                fd.append('status', this.form.status);
                if (!this.profileMode) {
                    this.ownerPermissionIds.forEach(id => fd.append('permissions[]', id));
                }

                const res = await axios.post(saveUrl, fd);
                if (res.data?.status === 0) {
                    this.showError(res.data.message || __('something_went_wrong'));
                    return;
                }
                const branchId = res.data?.data?.id || this.form.id;
                this.form.id = branchId;

                // 2) Other languages — save translated name / provider / address.
                for (const lang of this.languages) {
                    if (lang.id == this.defaultLangId) continue;
                    const name = (this.nameByLang[lang.id] || '').trim();
                    const provider = (this.providerByLang[lang.id] || '').trim();
                    const address = (this.addressByLang[lang.id] || '').trim();
                    if (name === '' && provider === '' && address === '') continue;
                    const tfd = new FormData();
                    tfd.append('id', branchId);
                    tfd.append('language_id', lang.id);
                    tfd.append('name', name);
                    tfd.append('provider', provider);
                    tfd.append('address', address);
                    await axios.post(saveUrl, tfd);
                }

                // Mark clean so the post-save redirect doesn't trip the unsaved-changes guard.
                this.captureFormBaseline();
                this.showMessage('success', res.data?.data?.message || res.data?.message || __('branch_saved_successfully'));
                if (!this.profileMode) {
                    setTimeout(() => this.$router.push({ path: '/branches' }), 800);
                }
            } catch (e) {
                this.showError(e.response?.data?.message || __('something_went_wrong'));
            } finally {
                this.saving = false;
            }
        },
    },
};
</script>

<style scoped>
.tax-type-input { max-width: 110px; }
.branch-map {
    width: 100%;
    height: 360px;
    border: 1px solid #dee2e6;
    border-radius: 4px;
    position: relative;
    z-index: 0;
}

.place-suggestions {
    position: absolute;
    z-index: 1050;
    left: 1rem;
    right: 1rem;
    max-height: 260px;
    overflow-y: auto;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
}

.place-suggestions .list-group-item {
    cursor: pointer;
    font-size: 0.9rem;
}

/* The Check Pickup button's own padding makes the group taller than the address field
   beside it; letting the input set the height lines the two rows up. */
.branch-pincode .btn {
    padding-top: 0;
    padding-bottom: 0;
    line-height: 1.5;
}

</style>

<style>
/* Cards clip absolutely-positioned dropdowns; allow overflow on the branch form */
.page-heading .card,
.page-heading .card-body {
    overflow: visible !important;
}
</style>
