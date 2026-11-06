<template>
    <div class="auth" :style="$panelLoginBackgroundImg ? { backgroundImage: `url(${$panelLoginBackgroundImg})` } : null">
        <div class="login-wrapper">
            <div class="detail-card">
                <div class="auth-logo">
                    <a href="javascript:void(0)"
                        style="display: flex; align-items: center; justify-content: flex-start;">
                        <img v-if="$appLogo != ''" :src="$storageUrl + $appLogo" style="height: 70px; width: 70px;"
                            alt='Logo' />
                        <img v-else :src="$baseUrl + '/images/logo.png'" style="height: 70px; width: 70px;"
                            alt='Logo' />
                        <h2 style="margin: 10px;">{{ $appName }}</h2>
                    </a>
                </div>
                <h4>Delivery Boy Registration</h4>
                <p class="auth-subtitle">Please Complete the form to complete your registration</p>
                <form ref="my-form" @submit.prevent="saveRecord" novalidate>
                    <div class="content">
                        <div class="row">
                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="name">{{ __('name') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <input type="text" name="name" id="name" v-model="deliveryBoys.name"
                                        class="form-control" placeholder="Enter name.">
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="dob">{{ __('date_of_birth') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <date-picker v-model="deliveryBoys.dob" :placeholder="__('date_of_birth')"
                                        @update:modelValue="validateDateOfBirth" />
                                    <span v-if="dobvalidationError" class="error">{{ dobvalidationError }}</span>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-group mobile">
                                    <label for="mobile">{{ __('mobile') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <div class="input-group">
                                        <div class="dropdown">
                                            <button type="button"
                                                class="btn btn-outline-secondary dropdown-toggle d-flex align-items-center gap-1 h-100"
                                                data-bs-toggle="dropdown">
                                                <img v-if="selectedDialCountry && selectedDialCountry.logo_url"
                                                    :src="selectedDialCountry.logo_url" height="14"
                                                    onerror="this.style.display='none'">
                                                <span>{{ deliveryBoys.country_code || __('code') }}</span>
                                            </button>
                                            <ul class="dropdown-menu" style="max-height:300px; overflow:auto;">
                                                <li v-for="c in countries" :key="c.id">
                                                    <a class="dropdown-item d-flex align-items-center gap-2" href="#"
                                                        @click.prevent="deliveryBoys.country_code = c.dial_code">
                                                        <img v-if="c.logo_url" :src="c.logo_url" height="14"
                                                            onerror="this.style.display='none'">
                                                        <span>{{ c.dial_code }} <small class="text-muted">{{ c.name }}</small></span>
                                                    </a>
                                                </li>
                                            </ul>
                                        </div>
                                        <input type="number" name="mobile" id="mobile" v-model="deliveryBoys.mobile"
                                            class="form-control" placeholder="Enter mobile no."
                                            @input="validateMobileNumber">
                                    </div>
                                    <span v-if="mobilevalidationError" class="error">{{ mobilevalidationError }}</span>
                                    <small v-else-if="mobileLengthHint" class="text-muted d-block mt-1">{{ mobileLengthHint }}</small>
                                </div>
                            </div>

                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="email">{{ __('email') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <input type="email" name="email" id="email" v-model="deliveryBoys.email"
                                        class="form-control" placeholder="Enter email id.">
                                </div>
                            </div>

                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="password">{{ __('password') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <div class="input-group">
                                        <input :type="showPassword ? 'text' : 'password'" name="password" id="password"
                                            v-model="deliveryBoys.password" class="form-control"
                                            placeholder="Enter password.">
                                        <button type="button" v-on:click="showPassword = !showPassword"
                                            class="btn btn-outline-primary mb-0">
                                            <Eye v-if="showPassword" :size="16" />
                                            <EyeOff v-else :size="16" />
                                        </button>
                                    </div>
                                    <small v-if="passwordError" class="text-danger d-block">{{ passwordError }}</small>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="confirm_password">{{ __('confirm_password') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <div class="input-group">
                                        <input :type="showConfirmPassword ? 'text' : 'password'" name="confirm_password"
                                            id="confirm_password" v-model="deliveryBoys.confirm_password"
                                            class="form-control" placeholder="Enter again password.">
                                        <button type="button" v-on:click="showConfirmPassword = !showConfirmPassword"
                                            class="btn btn-outline-primary mb-0">
                                            <Eye v-if="showConfirmPassword" :size="16" />
                                            <EyeOff v-else :size="16" />
                                        </button>
                                    </div>
                                </div>
                            </div>

                            <div class="col-md-4">
                                <FileUpload v-model="deliveryBoys.profile" :label="__('profile_image')"
                                    accept="image/*" recommended-size="512x512px" />
                            </div>
                            <div class="col-md-4">
                                <FileUpload v-model="deliveryBoys.driving_license" :label="__('driving_license')"
                                    required accept="*/*" />
                            </div>
                            <div class="col-md-4">
                                <FileUpload v-model="deliveryBoys.national_identity_card"
                                    :label="__('national_identity_card')" required accept="*/*" />
                            </div>

                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="country_id">{{ __('country') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <AppSelect v-model="deliveryBoys.country_id" class="form-control form-select"
                                        :options="countries" :placeholder="__('select_country')" />
                                    <small class="text-muted">{{ __('country_cannot_be_changed_once_set') }}</small>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="zone_id">{{ __('zone') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <AppSelect v-model="deliveryBoys.zone_id" class="form-control form-select"
                                        :options="zones" :placeholder="__('select_zone')"
                                        :disabled="!deliveryBoys.country_id" />
                                    <small class="text-muted">{{ __('delivery_boy_zone_hint') }}</small>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="bonus_type">{{ __('bonus_type') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <AppSelect class="form-control form-select" v-model="deliveryBoys.bonus_type" :options="bonus_typeOptions" :searchable="false" @update:model-value="changeBonusType" />
                                </div>
                            </div>
                            <div v-if="deliveryBoys.bonus_type == 1" class="col-md-4">
                                <div class="form-group">
                                    <label for="bonus_percentage">{{ __('bonus_percentage') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <input type="number" min="0.1" max="100" step="0.1" @input="validateCommission"
                                        name="bonus_percentage" id="bonus_percentage"
                                        v-model="deliveryBoys.bonus_percentage" class="form-control"
                                        placeholder="Enter Bonus (%)">
                                    <span v-if="bonusValidationMessage" class="error">{{ bonusValidationMessage
                                        }}</span>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="return_bonus_type">{{ __('return_bonus_type') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <AppSelect class="form-control form-select" v-model="deliveryBoys.return_bonus_type" :options="return_bonus_typeOptions" :searchable="false" @update:model-value="changeReturnBonusType" />
                                </div>
                            </div>
                            <div v-if="deliveryBoys.return_bonus_type == 1" class="col-md-4">
                                <div class="form-group">
                                    <label for="return_bonus_percentage">{{ __('return_bonus_percentage') }} <span
                                            class="text-danger text-xs">*</span></label>
                                    <input type="number" min="0.1" max="100" step="0.1" @input="validateReturnCommission"
                                        name="return_bonus_percentage" id="return_bonus_percentage"
                                        v-model="deliveryBoys.return_bonus_percentage" class="form-control"
                                        placeholder="Enter Return Bonus (%)">
                                    <span v-if="returnBonusValidationMessage" class="error">{{ returnBonusValidationMessage
                                        }}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                    <button class="btn btn-primary btn-block btn-lg shadow-lg mt-3">
                        {{ __('register') }}
                        <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                    </button>
                </form>
                <div class="auth-copyright">{{ $copyrightDetails }}</div>
            </div>
        </div>
    </div>
</template>
<script>
import axios from 'axios';
import Auth from '../../Auth.js';
import DatePicker from '../../components/DatePicker.vue';
import { Eye, EyeOff } from 'lucide-vue-next';
import { fetchPasswordPolicy, passwordPolicyError } from '../../utils/passwordPolicy.js';
export default {
    components: {
        DatePicker,
        Eye,
        EyeOff
    },
    data: function () {
        return {
            isLoading: false,
            passwordPolicy: null,

            deliveryBoys: {
                profile: "",
                mobile: "",
                dob: "",

                driving_license: "",
                driving_license_url: "",
                national_identity_card: "",
                national_identity_card_url: "",
                bonus_type: "",
                bonus_percentage: "",
                return_bonus_type: "",
                return_bonus_percentage: "",
                country_id: "",
                zone_id: "",
                country_code: "",
                password: "",
                confirm_password: "",
            },
            countries: [],
            zones: [],
            mobilevalidationError: null,
            dobvalidationError: null,
            account_numbervalidationError: null,
            showPassword: false,
            showConfirmPassword: false,
            bonusValidationMessage: null,
            returnBonusValidationMessage: null,

        };
    },
    watch: {
        'deliveryBoys.country_id'(id) {
            this.loadZones(id);
        },
        // Changing the dial code re-checks the mobile against the new country's bounds.
        'deliveryBoys.country_code'() {
            this.validateMobileNumber();
        },
    },
    computed: {
        // Fixed option set — no search box needed.
        bonus_typeOptions() {
            return [
                { id: '', name: (__('select')) },
                { id: '1', name: (__('commission')) },
                { id: '0', name: (__('fixed_salaried')) },
            ];
        },
        // Fixed option set — no search box needed.
        return_bonus_typeOptions() {
            return [
                { id: '', name: (__('select')) },
                { id: '1', name: (__('commission')) },
                { id: '0', name: (__('fixed_salaried')) },
            ];
        },
        selectedDialCountry() {
            return this.countries.find(c => c.dial_code === this.deliveryBoys.country_code) || null;
        },
        // Country whose mobile-length bounds apply: the one matching the selected
        // dial code, falling back to the chosen country_id.
        mobileBoundsCountry() {
            return this.countries.find(c => c.dial_code === this.deliveryBoys.country_code)
                || this.countries.find(c => Number(c.id) === Number(this.deliveryBoys.country_id))
                || null;
        },
        mobileLengthHint() {
            const c = this.mobileBoundsCountry;
            if (!c) return '';
            const min = Number(c.min_mobile_length || 7), max = Number(c.max_mobile_length || 15);
            // Replace :country BEFORE :count — ':count' is a substring of ':country'.
            return min === max
                ? __('mobile_must_be_exact_digits').replace(':country', c.name).replace(':count', min)
                : __('mobile_must_be_between_digits').replace(':country', c.name).replace(':min', min).replace(':max', max);
        },
        passwordError() {
            if (!this.deliveryBoys.password) return '';
            return passwordPolicyError(this.deliveryBoys.password, this.passwordPolicy);
        },
    },
    mounted() {
        this.loadCountries();
        fetchPasswordPolicy().then(p => { this.passwordPolicy = p; });
    },
    methods: {
        loadCountries() {
            axios.get(this.$deliveryBoyApiUrl + '/countries')
                .then(res => {
                    this.countries = res.data?.data || [];
                    // Default the dial code to the first country.
                    if (!this.deliveryBoys.country_code && this.countries.length) {
                        this.deliveryBoys.country_code = this.countries[0].dial_code;
                    }
                })
                .catch(() => { this.countries = []; });
        },
        // Zones belong to a country, so the list follows the country dropdown.
        loadZones(countryId) {
            if (!countryId) { this.zones = []; this.deliveryBoys.zone_id = ''; return; }
            axios.get(this.$deliveryBoyApiUrl + '/zones', { params: { country_id: countryId, limit: 200 } })
                .then(res => {
                    this.zones = res.data?.data || [];
                    // Drop a selection that doesn't belong to the chosen country.
                    if (this.deliveryBoys.zone_id
                        && !this.zones.some(z => Number(z.id) === Number(this.deliveryBoys.zone_id))) {
                        this.deliveryBoys.zone_id = '';
                    }
                })
                .catch(() => { this.zones = []; });
        },
        validateDateOfBirth() {
            const selectedDate = new Date(this.deliveryBoys.dob);
            const currentDate = new Date();
            if (selectedDate > currentDate) {
                this.dobvalidationError = "Date of Birth cannot be in the future.";
                this.deliveryBoys.dob = "";
            } else {
                this.dobvalidationError = "";
            }
        },
        validateMobileNumber() {
            const mobileRegex = /^[0-9]{1,16}$/; // numeric, max 16 digits
            if (!mobileRegex.test(this.deliveryBoys.mobile)) {
                this.mobilevalidationError = "Mobile Number must be numeric and should not exceed 16 digits.";
                this.deliveryBoys.mobile = null;
                return;
            }
            // Enforce the selected country's mobile digit-count bounds.
            let digits = String(this.deliveryBoys.mobile ?? '').replace(/\D+/g, '');
            const c = this.mobileBoundsCountry;
            if (c) {
                const min = Number(c.min_mobile_length || 7), max = Number(c.max_mobile_length || 15);
                // Don't allow typing beyond the max: truncate the extra digits.
                if (digits.length > max) {
                    digits = digits.slice(0, max);
                    this.deliveryBoys.mobile = digits;
                }
                if (digits && digits.length < min) {
                    this.mobilevalidationError = this.mobileLengthHint;
                    return;
                }
            }
            this.mobilevalidationError = null;
        },
        validateAccountNumber() {
            if (this.deliveryBoys.bank_account_number < 1) {
                this.account_numbervalidationError = "Account Number must be numeric value.";
                this.deliveryBoys.bank_account_number = null;
            } else {
                this.account_numbervalidationError = null;
            }
        },
        changeBonusType() {
            if (this.deliveryBoys.bonus_type == 0) {
                this.deliveryBoys.bonus_percentage = 0;
                this.deliveryBoys.bonus_min_amount = 0;
                this.deliveryBoys.bonus_max_amount = 0;
            } else {
                this.deliveryBoys.bonus_percentage = this.record ? this.record.bonus_percentage : "";
                this.deliveryBoys.bonus_min_amount = this.record ? this.record.bonus_min_amount : "";
                this.deliveryBoys.bonus_max_amount = this.record ? this.record.bonus_max_amount : "";
            }
        },
        changeReturnBonusType() {
            if (this.deliveryBoys.return_bonus_type == 0) {
                this.deliveryBoys.return_bonus_percentage = 0;
            } else {
                this.deliveryBoys.return_bonus_percentage = "";
            }
        },
        validateReturnCommission() {
            if (this.deliveryBoys.return_bonus_percentage < 1 || this.deliveryBoys.return_bonus_percentage > 100) {
                this.returnBonusValidationMessage = "Percentage must be between 1 and 100.";
                this.deliveryBoys.return_bonus_percentage = "";
            } else {
                this.returnBonusValidationMessage = null;
            }
        },
        validateCommission() {
            if (this.deliveryBoys.bonus_percentage < 1 || this.deliveryBoys.bonus_percentage > 100) {
                this.bonusValidationMessage = "Percentage must be between 1 and 100.";
                this.deliveryBoys.bonus_percentage = "";
            } else {
                this.bonusValidationMessage = null;
            }
        },
        saveRecord: function () {
            if (this.passwordError) { this.showError(this.passwordError); return; }
            let vm = this;
            this.isLoading = true;
            let formObject = this.deliveryBoys;
            let formData = new FormData();
            for (let key in formObject) {
                formData.append(key, formObject[key]);
            }
            let url = this.$deliveryBoyApiUrl + '/register';
            axios.post(url, formData, {
                headers: {
                    'Content-Type': 'multipart/form-data'
                }
            }).then(res => {
                this.isLoading = false;
                let data = res.data;
                if (data.status === 1) {
                    this.showMessage("success", data.message);
                    setTimeout(
                        function () {
                            vm.$swal.close();
                            //Auth.logout();
                            vm.$router.push({ path: '/delivery_boy/login' })
                        }, 2000);
                } else {
                    vm.showError(data.message);
                    vm.isLoading = false;
                }
            }).catch(error => {
                vm.isLoading = false;
                if (error.request.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError("Something went wrong!");
                }
            });
        }
    }
}
</script>

<style scoped>
.auth {
    overflow-x: hidden !important;
}

.auth-logo {
    padding-bottom: 10px;
}

.auth .login-wrapper {
    justify-content: center;
    align-items: center;
    padding: 30px 20px;
}

.auth .detail-card {
    max-width: 95%;
    width: 100%;
    max-width: 1100px;
    margin: 0 auto;
}

.auth .content {
    max-height: 70vh;
    overflow-y: auto;
}
</style>
