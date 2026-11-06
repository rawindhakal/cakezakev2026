<template>
    <div class="list-page">
        <!-- Title + back button outside the card. -->
        <div class="page-head">
            <h3 class="page-head-title">{{ deliveryBoys.id ? __('edit_delivery_boy') : __('delivery_boy') }}</h3>
            <router-link to="/delivery_boys"
                v-if="this.$roleDeliveryBoy !== this.login_user.role.name"
                class="btn btn-outline-secondary list-add-btn d-inline-flex align-items-center gap-2 text-nowrap ms-auto">
                <ArrowLeft :size="16" /> {{ __('back') }}
            </router-link>
        </div>

        <div>
            <div>
                <div>
                    <div class="card">
                        <form ref="my-form" @submit.prevent="saveRecord">
                            <div class="card-body">

                                <!-- Language Tabs for Translatable Fields -->
                                <b-tabs v-model="activeLanguageTab" v-if="languages.length > 0"
                                    :key="'lang-tabs-' + languagesKey" content-class="mt-3" :nav-class="languages.length <= 1 ? 'd-none' : null">
                                    <!-- Default Language Tab (All main form fields) -->
                                    <template v-for="(lang, index) in languages" :key="'lang-tab-' + lang.id">
                                    <b-tab lazy :id="'db-lang-tab-' + lang.id"
                                        v-if="lang.is_default">
                                        <template #title>
                                            <span :class="{ 'text-primary': lang.is_default }">
                                                {{ lang.name }}
                                            </span>
                                        </template>

                                    </b-tab>
                                    </template>

                                    <!-- Other Language Tabs (ONLY Translatable Fields - No other fields) -->
                                    <template v-for="(lang, index) in languages" :key="'lang-tab-' + lang.id">
                                    <b-tab lazy :id="'db-lang-tab-' + lang.id"
                                        v-if="!lang.is_default">
                                        <template #title>
                                            <span>
                                                {{ lang.name }}
                                            </span>
                                        </template>

                                        <div class="row">
                                            <!-- Name (Translatable) -->
                                            <div class="col-md-12">
                                                <div class="form-group">
                                                    <label for="name">{{ __('name') }}</label>
                                                    <input type="text" name="name" :id="'name_' + lang.id"
                                                        v-model="translations[lang.id].name" class="form-control"
                                                        :placeholder="__('name')">
                                                </div>
                                            </div>

                                            <!-- Address (Translatable) -->
                                            <div class="col-md-6">
                                                <div class="form-group">
                                                    <label for="address">{{ __('address') }}</label>
                                                    <textarea name="address" :id="'address_' + lang.id"
                                                        v-model="translations[lang.id].address" rows='3'
                                                        class="form-control" :placeholder="__('address')"></textarea>
                                                </div>
                                            </div>

                                            <!-- Other Payment Information (Translatable) -->
                                            <div class="col-md-6">
                                                <div class="form-group">
                                                    <label for="other_payment_info">{{ __('other_payment_information')
                                                        }}</label>
                                                    <textarea name="other_payment_info"
                                                        :id="'other_payment_info_' + lang.id"
                                                        v-model="translations[lang.id].other_payment_information"
                                                        rows='3' class="form-control"
                                                        :placeholder="__('other_payment_information')"></textarea>
                                                </div>
                                            </div>
                                        </div>
                                    </b-tab>
                                    </template>

                                    <!-- Translate control, inline with the language tabs. -->
                                    <template #tabs-end>
                                        <li class="nav-item ms-auto d-flex align-items-center">
                                            <TranslateLanguages :languages="languages"
                                                :default-language-id="defaultLanguageId" :busy="translating"
                                                :progress="translateProgress" @translate="runTranslate" />
                                        </li>
                                    </template>
                                </b-tabs>

                                <!-- Main Form Fields (Only show when default language tab is active or no tabs) -->
                                <div
                                    v-if="!languages.length || (defaultLanguage && getCurrentLanguage() && getCurrentLanguage().is_default)">
                                    <!-- Personal Information Section -->
                                    <div class="row mt-3">
                                        <!-- Name (Default Language) -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label for="name">{{ __('name') }}<span
                                                        class="text-danger text-xs">*</span></label>
                                                <input type="text" name="name" id="name" v-if="defaultLanguage"
                                                    v-model="translations[defaultLanguage.id].name" class="form-control"
                                                    :placeholder="__('name')">
                                            </div>
                                        </div>

                                        <!-- Country (fixed after creation) -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label>{{ __('country') }} <span class="text-danger text-xs">*</span></label>
                                                <AppSelect class="form-control form-select"
                                                    v-model="deliveryBoys.country_id" :options="countries"
                                                    :placeholder="__('select_country')"
                                                    :disabled="!!deliveryBoys.id" />
                                            </div>
                                        </div>

                                        <!-- Zone: assignment matches this against the order's zone -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label>{{ __('zone') }} <span class="text-danger text-xs">*</span></label>
                                                <AppSelect class="form-control form-select"
                                                    v-model="deliveryBoys.zone_id" :options="zones"
                                                    :placeholder="__('select_zone')"
                                                    :disabled="!deliveryBoys.country_id" />
                                                <small class="text-muted">{{ __('delivery_boy_zone_hint') }}</small>
                                            </div>
                                        </div>

                                        <!-- Date Of Birth -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label for="dob">{{ __('date_of_birth') }} <span
                                                        class="text-danger text-xs">*</span></label>
                                                <date-picker v-model="deliveryBoys.dob" :placeholder="__('date_of_birth')"
                                                    @update:modelValue="validateDateOfBirth" />
                                                <span v-if="dobvalidationError" class="error">{{ dobvalidationError
                                                    }}</span>
                                            </div>
                                        </div>

                                        <!-- Mobile -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label for="mobile">{{ __('mobile') }}<span
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
                                                    <input type="number" name="mobile" id="mobile"
                                                        v-model="deliveryBoys.mobile" class="form-control"
                                                        :placeholder="__('mobile_no')" @input="validateMobileNumber">
                                                </div>
                                                <span v-if="mobilevalidationError" class="error">{{
                                                    mobilevalidationError }}</span>
                                                <small v-else-if="mobileLengthHint" class="text-muted d-block mt-1">{{ mobileLengthHint }}</small>
                                            </div>
                                        </div>

                                        <!-- Email -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label for="email">{{ __('email') }}<span
                                                        class="text-danger text-xs">*</span></label>
                                                <input type="text" name="email" id="email" v-model="deliveryBoys.email"
                                                    :readonly="this.$roleDeliveryBoy === this.login_user.role.name"
                                                    class="form-control" :placeholder="__('email')">
                                            </div>
                                        </div>

                                        <!-- Password (only for admin) -->
                                        <div class="col-md-4"
                                            v-if="this.$roleDeliveryBoy !== this.login_user.role.name">
                                            <div class="form-group">
                                                <label for="password">{{ __('password') }}<span
                                                        class="text-danger text-xs">*</span></label>
                                                <div class="input-group">
                                                    <input :type="showPassword ? 'text' : 'password'" name="password"
                                                        id="password" v-model="deliveryBoys.password"
                                                        class="form-control" :placeholder="__('password')">
                                                    <button type="button" v-on:click="showPassword = !showPassword"
                                                        class="btn btn-outline-primary mb-0">
                                                        <Eye v-if="showPassword" :size="16" />
                                                        <EyeOff v-else :size="16" />
                                                    </button>
                                                </div>
                                                <small v-if="passwordError" class="text-danger d-block mt-1">{{ passwordError }}</small>
                                            </div>
                                        </div>

                                        <!-- Confirm Password (only for admin) -->
                                        <div class="col-md-4"
                                            v-if="this.$roleDeliveryBoy !== this.login_user.role.name">
                                            <div class="form-group">
                                                <label for="confirm_password">{{ __('confirm_password') }}<span
                                                        class="text-danger text-xs"
                                                        v-if="!deliveryBoys.id || deliveryBoys.password">*</span></label>
                                                <div class="input-group">
                                                    <input :type="showConfirmPassword ? 'text' : 'password'"
                                                        name="confirm_password" id="confirm_password"
                                                        v-model="deliveryBoys.confirm_password" class="form-control"
                                                        :placeholder="__('confirm_password')">
                                                    <button type="button"
                                                        v-on:click="showConfirmPassword = !showConfirmPassword"
                                                        class="btn btn-outline-primary mb-0">
                                                        <Eye v-if="showConfirmPassword" :size="16" />
                                                        <EyeOff v-else :size="16" />
                                                    </button>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Bank Details Section -->
                                    <div class="row">
                                        <!-- Bank Name -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label for="bank_name">{{ __('bank_name') }}<span
                                                        class="text-danger text-xs">*</span></label>
                                                <input type="text" name="bank_name" id="bank_name"
                                                    v-model="deliveryBoys.bank_name" required
                                                    :readonly="this.$roleDeliveryBoy === this.login_user.role.name"
                                                    class="form-control" :placeholder="__('bank_name')">
                                            </div>
                                        </div>

                                        <!-- Bank Account Name -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label for="account_name">{{ __('bank_account_name') }}<span
                                                        class="text-danger text-xs">*</span></label>
                                                <input type="text" name="account_name" id="account_name"
                                                    v-model="deliveryBoys.account_name" required
                                                    :readonly="this.$roleDeliveryBoy === this.login_user.role.name"
                                                    class="form-control" :placeholder="__('bank_account_name')">
                                            </div>
                                        </div>

                                        <!-- Account Number -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label for="account_number">{{ __('account_number') }}<span
                                                        class="text-danger text-xs">*</span></label>
                                                <input type="number" name="account_number" id="account_number"
                                                    v-model="deliveryBoys.bank_account_number" required
                                                    :readonly="this.$roleDeliveryBoy === this.login_user.role.name"
                                                    class="form-control" :placeholder="__('account_number')"
                                                    @input="validateAccountNumber">
                                                <span v-if="account_numbervalidationError" class="error">{{
                                                    account_numbervalidationError }}</span>
                                            </div>
                                        </div>

                                        <!-- Bank's IFSC Code -->
                                        <div class="col-md-4">
                                            <div class="form-group">
                                                <label for="ifsc_code">{{ __('bank_ifsc_code') }}<span
                                                        class="text-danger text-xs">*</span></label>
                                                <input type="text" name="ifsc_code" id="ifsc_code"
                                                    v-model="deliveryBoys.ifsc_code" required
                                                    :readonly="this.$roleDeliveryBoy === this.login_user.role.name"
                                                    class="form-control" :placeholder="__('bank_ifsc_code')">
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Address and Other Payment Information Section (Default Language) -->
                                    <div class="row" v-if="defaultLanguage">
                                        <!-- Address (Default Language) -->
                                        <div class="col-md-6">
                                            <div class="form-group">
                                                <label for="address">{{ __('address') }}<span
                                                        class="text-danger text-xs">*</span></label>
                                                <textarea name="address" id="address"
                                                    v-model="translations[defaultLanguage.id].address" rows='3'
                                                    class="form-control" :placeholder="__('address')"></textarea>
                                            </div>
                                        </div>

                                        <!-- Other Payment Information (Default Language) -->
                                        <div class="col-md-6">
                                            <div class="form-group">
                                                <label for="other_payment_info">{{ __('other_payment_information')
                                                    }}</label>
                                                <textarea name="other_payment_info" id="other_payment_info"
                                                    v-model="translations[defaultLanguage.id].other_payment_information"
                                                    rows='3' class="form-control"
                                                    :placeholder="__('other_payment_information')"></textarea>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Document Upload Section -->
                                    <div class="row">
                                        <!-- Profile image -->
                                        <div class="col-md-4">
                                            <FileUpload v-model="deliveryBoys.profile" :label="__('profile_image')"
                                                :required="true" accept="image/*" recommended-size="512x512px"
                                                :preview-url="deliveryBoys.profile_url" />
                                        </div>

                                        <!-- Driving License -->
                                        <div class="col-md-4">
                                            <FileUpload v-if="this.$roleDeliveryBoy !== this.login_user.role.name"
                                                v-model="deliveryBoys.driving_license" :label="__('driving_licence')"
                                                required accept="image/*,application/pdf,.doc,.docx" :max-size-mb="2"
                                                :preview-url="isImage(deliveryBoys.driving_license_url) ? deliveryBoys.driving_license_url : ''" />
                                            <template v-else>
                                                <label>{{ __('driving_licence') }}</label>
                                                <div class="row mt-2"
                                                    v-if="deliveryBoys.driving_license_url && isImage(deliveryBoys.driving_license_url)">
                                                    <div class="col-md-2">
                                                        <img class="custom-image"
                                                            :src="deliveryBoys.driving_license_url"
                                                            title='Driving License' alt='Driving License' />
                                                    </div>
                                                </div>
                                            </template>
                                            <div class="row mt-2"
                                                v-if="deliveryBoys.driving_license_url && !isImage(deliveryBoys.driving_license_url)">
                                                <div class="col-md-2 mt-2">
                                                    <a target="_blank" :href="deliveryBoys.driving_license_url"
                                                        class="badge bg-success">
                                                        <Eye :size="15" /> {{ __('identity_card') }}
                                                    </a>
                                                </div>
                                            </div>
                                        </div>

                                        <!-- National Identity Card -->
                                        <div class="col-md-4">
                                            <FileUpload v-if="this.$roleDeliveryBoy !== this.login_user.role.name"
                                                v-model="deliveryBoys.national_identity_card"
                                                :label="__('national_identity_card')" required
                                                accept="image/*,application/pdf,.doc,.docx" :max-size-mb="2"
                                                :preview-url="isImage(deliveryBoys.national_identity_card_url) ? deliveryBoys.national_identity_card_url : ''" />
                                            <template v-else>
                                                <label>{{ __('national_identity_card') }}</label>
                                                <div class="row mt-2"
                                                    v-if="deliveryBoys.national_identity_card_url && isImage(deliveryBoys.national_identity_card_url)">
                                                    <div class="col-md-2">
                                                        <img class="custom-image"
                                                            :src="deliveryBoys.national_identity_card_url"
                                                            title='National Identity Card'
                                                            alt='National Identity Card' />
                                                    </div>
                                                </div>
                                            </template>
                                            <div class="row mt-2"
                                                v-if="deliveryBoys.national_identity_card_url && !isImage(deliveryBoys.national_identity_card_url)">
                                                <div class="col-md-2 mt-2">
                                                    <a target="_blank" :href="deliveryBoys.national_identity_card_url"
                                                        class="badge bg-success">
                                                        <Eye :size="15" /> {{ __('identity_card') }}
                                                    </a>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="list-group-item m-2">
                                        <div class="d-flex justify-content-between align-content-center">
                                            <h6>{{ __('order_commission_details') }}</h6>
                                            <b-button-group v-if="this.$roleDeliveryBoy !== this.login_user.role.name">
                                                <b-button @click="getBonusSettings"
                                                    v-if="$deliveryBoyBonusSettings == 1" type="button"
                                                    variant="primary" size="sm">
                                                    {{ __('add_default_bonus') }}
                                                </b-button>
                                                <b-button @click="resetBonus" v-if="deliveryBoys.id" type="button"
                                                    size="sm">
                                                    {{ __('reset_bonus') }}
                                                </b-button>
                                            </b-button-group>
                                        </div>
                                        <p class="text text-muted font-size-13 mb-0">
                                            {{ __('order_commission_hint') }}
                                        </p>
                                        <div class="row mt-2">
                                            <div class="col-md-3">
                                                <div class="form-group">
                                                    <label for="bonus_type">{{ __('bonus_type') }}<span
                                                            class="text-danger text-xs">*</span></label>
                                                    <AppSelect class="form-control form-select" v-model="deliveryBoys.bonus_type" :options="bonus_typeOptions" :searchable="false" @update:model-value="changeBonusType" :disabled="this.$roleDeliveryBoy === this.login_user.role.name" />
                                                </div>
                                            </div>
                                            <div v-if="deliveryBoys.bonus_type == 1" class="col-md-3">
                                                <div class="form-group">
                                                    <label for="bonus_percentage">{{ __('bonus_percentage') }}<span
                                                            class="text-danger text-xs">*</span></label>
                                                    <input type="number" min="0.1" max="100" step="0.1"
                                                        name="bonus_percentage" id="bonus_percentage"
                                                        v-model="deliveryBoys.bonus_percentage" class="form-control"
                                                        :placeholder="__('bonus_percentage')"
                                                        :readonly="this.$roleDeliveryBoy === this.login_user.role.name">
                                                </div>
                                            </div>
                                            <div v-if="deliveryBoys.bonus_type == 1" class="col-md-3">
                                                <div class="form-group">
                                                    <label for="bonus_min_amount">{{ __('minimum_bonus_amount')
                                                        }}</label>
                                                    <input type="number" min="0" step="0.1" required
                                                        class="form-control" name="bonus_min_amount"
                                                        id="bonus_min_amount" v-model="deliveryBoys.bonus_min_amount"
                                                        placeholder='Minimum bonus amount'
                                                        :readonly="this.$roleDeliveryBoy === this.login_user.role.name"
                                                        @input="validateBonusMinAmount" />
                                                    <span class="text text-primary font-size-13"
                                                        v-if="this.$roleDeliveryBoy !== this.login_user.role.name">{{
                                                        __('set_0_if_you_want_to_remove_limit') }}</span>
                                                    <span v-if="bonusMinAmountValidationError" class="error">{{
                                                        bonusMinAmountValidationError }}</span>
                                                </div>
                                            </div>
                                            <div v-if="deliveryBoys.bonus_type == 1" class="col-md-3">
                                                <div class="form-group">
                                                    <label for="bonus_max_amount">{{ __('maximum_bonus_amount')
                                                        }}</label>
                                                    <input type="number" min="0" step="0.1" required
                                                        class="form-control" name="bonus_max_amount"
                                                        id="bonus_max_amount" v-model="deliveryBoys.bonus_max_amount"
                                                        :placeholder="__('maximum_bonus_amount')"
                                                        :readonly="this.$roleDeliveryBoy === this.login_user.role.name"
                                                        @input="validateBonusMaxAmount" />
                                                    <span class="text text-primary font-size-13"
                                                        v-if="this.$roleDeliveryBoy !== this.login_user.role.name">{{
                                                        __('set_0_if_you_want_to_remove_limit') }}</span>
                                                    <span v-if="bonusMaxAmountValidationError" class="error">{{
                                                        bonusMaxAmountValidationError }}</span>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Return Commission Section -->
                                    <div class="list-group-item m-2">
                                        <div class="d-flex justify-content-between align-content-center">
                                            <h6>{{ __('return_commission_details') }}</h6>
                                        </div>
                                        <p class="text text-muted font-size-13 mb-0">
                                            {{ __('return_commission_hint') }}
                                        </p>
                                        <div class="row mt-2">
                                            <div class="col-md-3">
                                                <div class="form-group">
                                                    <label for="return_bonus_type">{{ __('bonus_type') }}<span
                                                            class="text-danger text-xs">*</span></label>
                                                    <AppSelect class="form-control form-select" v-model="deliveryBoys.return_bonus_type" :options="return_bonus_typeOptions" :searchable="false" :disabled="this.$roleDeliveryBoy === this.login_user.role.name" />
                                                </div>
                                            </div>
                                            <div v-if="deliveryBoys.return_bonus_type == 1" class="col-md-3">
                                                <div class="form-group">
                                                    <label for="return_bonus_percentage">{{ __('bonus_percentage') }}<span
                                                            class="text-danger text-xs">*</span></label>
                                                    <input type="number" min="0.1" max="100" step="0.1"
                                                        name="return_bonus_percentage" id="return_bonus_percentage"
                                                        v-model="deliveryBoys.return_bonus_percentage" class="form-control"
                                                        :placeholder="__('bonus_percentage')"
                                                        :readonly="this.$roleDeliveryBoy === this.login_user.role.name">
                                                </div>
                                            </div>
                                            <div v-if="deliveryBoys.return_bonus_type == 1" class="col-md-3">
                                                <div class="form-group">
                                                    <label for="return_bonus_min_amount">{{ __('minimum_bonus_amount') }}</label>
                                                    <input type="number" min="0" step="0.1" class="form-control"
                                                        name="return_bonus_min_amount" id="return_bonus_min_amount"
                                                        v-model="deliveryBoys.return_bonus_min_amount"
                                                        :placeholder="__('minimum_bonus_amount')"
                                                        :readonly="this.$roleDeliveryBoy === this.login_user.role.name" />
                                                    <span class="text text-primary font-size-13"
                                                        v-if="this.$roleDeliveryBoy !== this.login_user.role.name">{{
                                                        __('set_0_if_you_want_to_remove_limit') }}</span>
                                                </div>
                                            </div>
                                            <div v-if="deliveryBoys.return_bonus_type == 1" class="col-md-3">
                                                <div class="form-group">
                                                    <label for="return_bonus_max_amount">{{ __('maximum_bonus_amount') }}</label>
                                                    <input type="number" min="0" step="0.1" class="form-control"
                                                        name="return_bonus_max_amount" id="return_bonus_max_amount"
                                                        v-model="deliveryBoys.return_bonus_max_amount"
                                                        :placeholder="__('maximum_bonus_amount')"
                                                        :readonly="this.$roleDeliveryBoy === this.login_user.role.name" />
                                                    <span class="text text-primary font-size-13"
                                                        v-if="this.$roleDeliveryBoy !== this.login_user.role.name">{{
                                                        __('set_0_if_you_want_to_remove_limit') }}</span>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Status Section (only for edit mode) -->
                                    <div class="row"
                                        v-if="deliveryBoys.id && this.$roleDeliveryBoy !== this.login_user.role.name">
                                        <div class="col-md-8">
                                            <div class="form-group">
                                                <label>{{ __('status') }}<span
                                                        class="text-danger text-xs">*</span></label><br>
                                                <div class="btn-group btn-group-toggle d-flex flex-wrap flex-md-nowrap" role="group">
                                                    <label class="btn btn-outline-primary" :class="{ active: deliveryBoys.status == 0 }">
                                                        <input type="radio" :value="0" v-model.number="deliveryBoys.status" autocomplete="off"> {{ __('registered') }}
                                                    </label>
                                                    <label class="btn btn-outline-primary" :class="{ active: deliveryBoys.status == 1 }">
                                                        <input type="radio" :value="1" v-model.number="deliveryBoys.status" autocomplete="off"> {{ __('active') }}
                                                    </label>
                                                    <label class="btn btn-outline-primary" :class="{ active: deliveryBoys.status == 2 }">
                                                        <input type="radio" :value="2" v-model.number="deliveryBoys.status" autocomplete="off"> {{ __('not_approved') }}
                                                    </label>
                                                    <label class="btn btn-outline-primary" :class="{ active: deliveryBoys.status == 3 }">
                                                        <input type="radio" :value="3" v-model.number="deliveryBoys.status" autocomplete="off"> {{ __('deactive') }}
                                                    </label>
                                                    <label class="btn btn-outline-primary" :class="{ active: deliveryBoys.status == 4 }">
                                                        <input type="radio" :value="4" v-model.number="deliveryBoys.status" autocomplete="off"> {{ __('block') }}
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="col-md-4" v-if="[2, 3, 4].includes(deliveryBoys.status)">
                                            <div class="form-group">
                                                <label for="remark">{{ __('remark') }}<span
                                                        class="text-danger text-xs">*</span></label>
                                                <textarea class="form-control" name="remark" id="remark" required
                                                    v-model="deliveryBoys.remark"
                                                    :placeholder="__('remark')"></textarea>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <!-- End of Main Form Fields (only visible on default language tab) -->

                            <!-- Action Buttons -->
                            <div class="card-footer d-flex justify-content-end gap-2">
                                <template v-if="deliveryBoys.id">
                                    <b-button type="submit" variant="primary" :disabled="isLoading">
                                        {{ __('update') }}
                                        <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                                    </b-button>
                                </template>
                                <template v-else>
                                    <button v-if="this.$roleDeliveryBoy !== this.login_user.role.name" type="reset"
                                        class="btn btn-danger">{{ __('clear') }}</button>
                                    <button v-else type="button" class="btn btn-danger" @click="$router.go(-1)">{{
                                        __('back') }}</button>
                                    <b-button type="submit" variant="primary" :disabled="isLoading">
                                        {{ __('save') }}
                                        <b-spinner v-if="isLoading" small label="Spinning"></b-spinner>
                                    </b-button>
                                </template>
                            </div>
                        </form>
                    </div>

                </div>
            </div>
        </div>
    </div>
</template>
<script>
import axios from "axios";
import DatePicker from '../../components/DatePicker.vue';

import Auth from '../../Auth.js';
import TranslationHelper from '../../mixins/TranslationHelper.js';
import UnsavedChanges from '../../mixins/UnsavedChanges.js';
import { fetchPasswordPolicy, passwordPolicyError } from '../../utils/passwordPolicy.js';
import { Eye, EyeOff, ArrowLeft } from 'lucide-vue-next';

export default {
    mixins: [TranslationHelper, UnsavedChanges],
    components: {
        DatePicker,
        Eye, EyeOff, ArrowLeft,
    },
    data: function () {
        return {
            activeLanguageTab: null,
            languagesKey: 0,
            currentLanguage: null,
            languages: [],
            defaultLanguage: null,


            translations: {},
            login_user: Auth.user,
            isLoading: false,
            showPassword: false,
            showConfirmPassword: false,
            record: null,
            id: null,
            bonusSettings: null,
            deliveryBoys: {
                language_id: null,
                id: null,
                admin_id: "",
                country_id: "",
                zone_id: "",
                country_code: "",
                profile: "",
                profile_url: "",
                name: "",
                dob: "",
                mobile: "",
                email: "",
                password: "",
                confirm_password: "",
                ifsc_code: "",
                bank_name: "",
                bank_account_number: "",
                account_name: "",
                address: "",
                other_payment_information: "",

                driving_license: "",
                driving_license_url: "",

                national_identity_card: "",
                national_identity_card_url: "",

                status: 0,
                remark: "",

                bonus_type: "",
                bonus_percentage: "",
                bonus_min_amount: "",
                bonus_max_amount: "",
                return_bonus_type: "",
                return_bonus_percentage: "",
                return_bonus_min_amount: "",
                return_bonus_max_amount: "",
            },
            mobilevalidationError: null,
            dobvalidationError: null,
            account_numbervalidationError: null,
            bonusMinAmountValidationError: null,
            bonusMaxAmountValidationError: null,

            // Translate control (defaultLanguageId set when languages load)
            defaultLanguageId: null,
            translatableFields: ['name', 'address', 'other_payment_information'],
            countries: [],
            zones: [],
            passwordPolicy: null,
        };
    },
    created: function () {

        this.loadCountries();
        fetchPasswordPolicy().then(p => { this.passwordPolicy = p; });
        this.id = this.$route.params.id;
        if (this.$roleDeliveryBoy === this.login_user.role.name) {
            // Boy login stores the delivery_boy row flattened onto `user`, so its own id
            // is the fallback for sessions saved before `delivery_boy` was attached.
            this.id = this.login_user.delivery_boy?.id ?? this.login_user.id;
        }
        this.fetchLanguages().then(() => {
            if (this.id) {
                this.deliveryBoys.id = this.id;
                this.getDeliveryBoy();
            } else {
                // Empty create form — snapshot the clean baseline for the unsaved-changes guard.
                this.captureFormBaseline();
            }
        });
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
        // Inline password policy error (empty when valid or password left blank).
        passwordError() {
            if (!this.deliveryBoys.password) return '';
            return passwordPolicyError(this.deliveryBoys.password, this.passwordPolicy);
        },
    },
    watch: {
        // Keep the dial code in step with the chosen country (admin can still override).
        'deliveryBoys.country_id'(id) {
            this.loadZones(id);
            const c = this.countries.find(x => Number(x.id) === Number(id));
            if (c && c.dial_code) this.deliveryBoys.country_code = c.dial_code;
        },
        // Changing the dial code re-checks the mobile against the new country's bounds.
        'deliveryBoys.country_code'() {
            this.validateMobileNumber();
        },
    },
    methods: {
        // Tracked state for the UnsavedChanges guard (warn before leaving with edits).
        formState() {
            return {
                deliveryBoys: this.deliveryBoys,
                translations: this.translations,
            };
        },
        // Zones belong to a country, so the list follows the country dropdown.
        loadZones(countryId) {
            if (!countryId) { this.zones = []; this.deliveryBoys.zone_id = ''; return; }
            axios.get(this.$apiUrl + '/zones', { params: { country_id: countryId, limit: 200 } })
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
        loadCountries() {
            axios.get(this.$apiUrl + '/countries/active').then(res => {
                this.countries = res.data?.data || [];
                // New delivery boy: default to the default country (else the first).
                if (!this.deliveryBoys.id && !this.deliveryBoys.country_id) {
                    const def = this.countries.find(c => Number(c.is_default) === 1) || this.countries[0];
                    if (def) this.deliveryBoys.country_id = Number(def.id);
                }
                // Default the dial code from the selected country (else first country).
                if (!this.deliveryBoys.country_code && this.countries.length) {
                    const selected = this.countries.find(c => Number(c.id) === Number(this.deliveryBoys.country_id));
                    this.deliveryBoys.country_code = (selected || this.countries[0]).dial_code;
                }
            }).catch(() => { this.countries = []; });
        },
        // Get the currently active language based on activeLanguageTab (b-tabs v-model is tab id string)
        getCurrentLanguage() {
            if (!this.languages.length) return null;
            const idStr = String(this.activeLanguageTab || '');
            const match = idStr.match(/^db-lang-tab-(\d+)$/);
            if (match) {
                const langId = parseInt(match[1], 10);
                return this.languages.find(l => l.id === langId) || null;
            }
            return this.defaultLanguage || null;
        },
        fetchLanguages() {
            return axios.get(this.$apiUrl + '/active_languages')
                .then(res => {
                    const langs = res.data.data;

                    this.languages = [];
                    this.translations = {};

                    this.languages = langs;
                    this.languagesKey++;

                    const defaultLang = langs.find(l => l.is_default == 1);

                    if (!defaultLang) {
                        this.showError('No default language configured.');
                        return;
                    }


                    this.defaultLanguage = defaultLang;
                    this.defaultLanguageId = defaultLang ? defaultLang.id : null;
                    this.currentLanguage = defaultLang.id;
                    // bootstrap-vue-next b-tabs v-model uses tab id string
                    this.activeLanguageTab = 'db-lang-tab-' + defaultLang.id;
                    this.deliveryBoys.language_id = defaultLang.id;

                    langs.forEach(lang => {
                        this.translations[lang.id] = {
                            name: '',
                            address: '',
                            other_payment_information: '',
                        };
                    });
                });
        },

        validateDateOfBirth() {
            const selectedDate = new Date(this.deliveryBoys.dob);
            const currentDate = new Date();
            if (selectedDate > currentDate) {
                this.dobvalidationError = "Date of Birth cannot be in the future.";
                this.deliveryBoys.dob = null;
            } else {
                this.dobvalidationError = null;
            }
        },
        validateMobileNumber() {
            if (this.deliveryBoys.mobile < 0) {
                this.mobilevalidationError = "Mobile Number must be numeric value.";
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
        validateBonusMinAmount() {

            this.bonusMinAmountValidationError = null;

            const minAmount = parseFloat(this.deliveryBoys.bonus_min_amount);
            const maxAmount = parseFloat(this.deliveryBoys.bonus_max_amount);


            if (minAmount > 0 && maxAmount > 0 && minAmount > maxAmount) {
                this.bonusMinAmountValidationError = "Minimum bonus amount cannot be greater than maximum bonus amount.";
                return;
            }

            if (minAmount < 0) {
                this.bonusMinAmountValidationError = "Minimum bonus amount cannot be negative.";
                return;
            }
        },
        validateBonusMaxAmount() {

            this.bonusMaxAmountValidationError = null;

            const minAmount = parseFloat(this.deliveryBoys.bonus_min_amount);
            const maxAmount = parseFloat(this.deliveryBoys.bonus_max_amount);

            if (minAmount > 0 && maxAmount > 0 && maxAmount < minAmount) {
                this.bonusMaxAmountValidationError = "Maximum bonus amount cannot be less than minimum bonus amount.";
                return;
            }

            if (maxAmount < 0) {
                this.bonusMaxAmountValidationError = "Maximum bonus amount cannot be negative.";
                return;
            }
        },
        getBonusSettings() {
            axios.get(this.$apiUrl + '/delivery_boys/bonus_settings')
                .then((response) => {
                    let data = response.data;
                    this.bonusSettings = data.data

                    if (this.bonusSettings.delivery_boy_bonus_settings == 1) {
                        this.deliveryBoys.bonus_type = this.bonusSettings.delivery_boy_bonus_type;
                        this.deliveryBoys.bonus_percentage = this.bonusSettings.delivery_boy_bonus_percentage;
                        this.deliveryBoys.bonus_min_amount = this.bonusSettings.delivery_boy_bonus_min_amount;
                        this.deliveryBoys.bonus_max_amount = this.bonusSettings.delivery_boy_bonus_max_amount;
                    }
                });
        },
        resetBonus() {
            this.deliveryBoys.bonus_type = this.record ? this.record.bonus_type : 0;
            this.deliveryBoys.bonus_percentage = this.record ? this.record.bonus_percentage : 0;
            this.deliveryBoys.bonus_min_amount = this.record ? this.record.bonus_min_amount : 0;
            this.deliveryBoys.bonus_max_amount = this.record ? this.record.bonus_max_amount : 0;
            this.deliveryBoys.return_bonus_type = this.record ? this.record.return_bonus_type : 0;
            this.deliveryBoys.return_bonus_percentage = this.record ? this.record.return_bonus_percentage : 0;
            this.deliveryBoys.return_bonus_min_amount = this.record ? this.record.return_bonus_min_amount : 0;
            this.deliveryBoys.return_bonus_max_amount = this.record ? this.record.return_bonus_max_amount : 0;
        },
        changeBonusType() {
            if (this.deliveryBoys.bonus_type == 0) {
                this.deliveryBoys.bonus_percentage = 0;
                this.deliveryBoys.bonus_min_amount = 0;
                this.deliveryBoys.bonus_max_amount = 0;

                this.bonusMinAmountValidationError = null;
                this.bonusMaxAmountValidationError = null;
            } else {
                this.deliveryBoys.bonus_percentage = this.record ? this.record.bonus_percentage : "";
                this.deliveryBoys.bonus_min_amount = this.record ? this.record.bonus_min_amount : "";
                this.deliveryBoys.bonus_max_amount = this.record ? this.record.bonus_max_amount : "";
                // Trigger validation when switching to commission type
                this.validateBonusMinAmount();
                this.validateBonusMaxAmount();
            }
        },

        getDeliveryBoy() {
            axios.get(this.$apiUrl + '/delivery_boys/edit/' + this.id)
                .then((response) => {
                    this.isLoading = false
                    let data = response.data;
                    if (data.status === 1) {
                        this.record = data.data
                        this.translations = {};
                        if (!this.languages.length) return;

                        // Helper: show empty string when value is null, undefined, or string "null"
                        const emptyIfNull = (val) => (val != null && val !== "null") ? val : "";

                        this.translations = {};
                        this.languages.forEach(lang => {
                            let t = this.record.translations?.find(tr => tr.language_id === lang.id);

                            if (lang.is_default) {
                                this.translations[lang.id] = {
                                    name: emptyIfNull(t?.name) || emptyIfNull(this.record.name),
                                    address: emptyIfNull(t?.address) || emptyIfNull(this.record.address),
                                    other_payment_information: emptyIfNull(t?.other_payment_information) || emptyIfNull(this.record.other_payment_information),
                                };
                            } else {
                                this.translations[lang.id] = {
                                    name: emptyIfNull(t?.name),
                                    address: emptyIfNull(t?.address),
                                    other_payment_information: emptyIfNull(t?.other_payment_information),
                                };
                            }
                        });

                        this.deliveryBoys.id = this.record ? this.record.id : null;
                        this.deliveryBoys.admin_id = emptyIfNull(this.record?.admin_id);
                        this.deliveryBoys.country_id = this.record?.country_id || '';
                        this.deliveryBoys.zone_id = this.record?.zone_id || '';
                        this.deliveryBoys.name = emptyIfNull(this.record?.name);
                        this.deliveryBoys.dob = emptyIfNull(this.record?.dob);
                        this.deliveryBoys.mobile = emptyIfNull(this.record?.mobile);
                        this.deliveryBoys.country_code = emptyIfNull(this.record?.country_code) || this.deliveryBoys.country_code;
                        this.deliveryBoys.profile_url = this.record?.profile_url || '';
                        this.deliveryBoys.email = this.record?.email || this.record?.admin?.email || '';
                        this.deliveryBoys.password = "";
                        this.deliveryBoys.confirm_password = "";
                        this.deliveryBoys.ifsc_code = emptyIfNull(this.record?.ifsc_code);
                        this.deliveryBoys.bank_name = emptyIfNull(this.record?.bank_name);
                        this.deliveryBoys.bank_account_number = emptyIfNull(this.record?.bank_account_number);
                        this.deliveryBoys.account_name = emptyIfNull(this.record?.account_name);

                        this.deliveryBoys.address = emptyIfNull(this.record?.address);
                        this.deliveryBoys.other_payment_information = emptyIfNull(this.record?.other_payment_information);

                        this.deliveryBoys.driving_license = "";
                        this.deliveryBoys.driving_license_url = this.record ? this.$storageUrl + this.record.driving_license : "";
                        this.deliveryBoys.national_identity_card = "";
                        this.deliveryBoys.national_identity_card_url = this.record ? this.$storageUrl + this.record.national_identity_card : "";

                        this.deliveryBoys.status = this.record ? this.record.status : 0;
                        this.deliveryBoys.remark = this.record ? this.record.remark : "";

                        this.deliveryBoys.bonus_type = this.record ? this.record.bonus_type : 0;
                        this.deliveryBoys.bonus_percentage = this.record ? this.record.bonus_percentage : 0;
                        this.deliveryBoys.bonus_min_amount = this.record ? this.record.bonus_min_amount : 0;
                        this.deliveryBoys.bonus_max_amount = this.record ? this.record.bonus_max_amount : 0;

                        this.deliveryBoys.return_bonus_type = this.record ? this.record.return_bonus_type : 0;
                        this.deliveryBoys.return_bonus_percentage = this.record ? this.record.return_bonus_percentage : 0;
                        this.deliveryBoys.return_bonus_min_amount = this.record ? this.record.return_bonus_min_amount : 0;
                        this.deliveryBoys.return_bonus_max_amount = this.record ? this.record.return_bonus_max_amount : 0;

                        // Record loaded — snapshot the clean baseline for the unsaved-changes guard.
                        this.captureFormBaseline();

                    } else {
                        this.showError(data.message);
                        setTimeout(() => {
                            this.$router.back();
                        }, 1000);
                    }
                }).catch(error => {
                    this.isLoading = false;
                    if (error.request?.statusText) {
                        this.showError(error.request.statusText);
                    } else if (error.message) {
                        this.showError(error.message);
                    } else {
                        this.showError("Something went wrong!");
                    }
                });
        },

        async saveRecord() {
            // --- Client-side validation BEFORE setting isLoading ---
            if (!this.defaultLanguage) {
                this.showError(__('default_language_not_found') || 'Default language not loaded.');
                return;
            }

            const defaultLang = this.defaultLanguage;
            const defaultTrans = this.translations[defaultLang.id];

            const switchToDefault = () => {
                this.activeLanguageTab = 'db-lang-tab-' + defaultLang.id;
            };

            if (!defaultTrans?.name?.trim()) {
                this.showError(__('please_fill_name_in_default_language') || 'Please fill the name in the default language.');
                switchToDefault();
                return;
            }
            if (!this.deliveryBoys.dob) {
                this.showError(__('please_fill_date_of_birth') || 'Please fill the date of birth.');
                switchToDefault();
                return;
            }
            if (!this.deliveryBoys.mobile) {
                this.showError(__('please_fill_mobile') || 'Please fill the mobile number.');
                switchToDefault();
                return;
            }
            if (!this.deliveryBoys.email) {
                this.showError(__('please_fill_email') || 'Please fill the email.');
                switchToDefault();
                return;
            }

            if (this.$roleDeliveryBoy !== this.login_user.role.name) {
                if (this.deliveryBoys.bonus_type === "" || this.deliveryBoys.bonus_type === null) {
                    this.showError(__('please_select_bonus_type'));
                    switchToDefault();
                    return;
                }
                if (this.deliveryBoys.return_bonus_type === "" || this.deliveryBoys.return_bonus_type === null) {
                    this.showError(__('please_select_return_bonus_type'));
                    switchToDefault();
                    return;
                }
            }

            const isEdit = !!this.deliveryBoys.id;
            if (!isEdit && !this.deliveryBoys.driving_license) {
                this.showError(__('please_upload_driving_license') || 'Please upload driving license.');
                switchToDefault();
                return;
            }
            if (!isEdit && !this.deliveryBoys.national_identity_card) {
                this.showError(__('please_upload_national_identity_card') || 'Please upload national identity card.');
                switchToDefault();
                return;
            }

            // Password validation: on create required; on edit if filled then confirm must match
            if (!isEdit) {
                if (!this.deliveryBoys.password) {
                    this.showError(__('please_fill_password'));
                    switchToDefault();
                    return;
                }
                if (this.deliveryBoys.password !== this.deliveryBoys.confirm_password) {
                    this.showError(__('password_and_confirm_password_must_match'));
                    switchToDefault();
                    return;
                }
            } else if (this.deliveryBoys.password) {
                if (!this.deliveryBoys.confirm_password) {
                    this.showError(__('please_fill_confirm_password'));
                    switchToDefault();
                    return;
                }
                if (this.deliveryBoys.password !== this.deliveryBoys.confirm_password) {
                    this.showError(__('password_and_confirm_password_must_match'));
                    switchToDefault();
                    return;
                }
            }

            // Password must satisfy the configured policy (create, or edit when set).
            if (this.deliveryBoys.password && this.passwordError) {
                this.showError(this.passwordError);
                switchToDefault();
                return;
            }

            // All client-side checks passed — start loading
            this.isLoading = true;

            try {
                const isEdit = !!this.deliveryBoys.id;
                const fd = new FormData();

                if (isEdit) {
                    fd.append('id', this.deliveryBoys.id);
                } else {
                    // Country is fixed at creation (non-editable afterward).
                    fd.append('country_id', this.deliveryBoys.country_id || '');
                }

                // default language
                fd.append('zone_id', this.deliveryBoys.zone_id || '');
                fd.append('translations', JSON.stringify(this.translations));
                fd.append('name', defaultTrans.name);
                fd.append('address', defaultTrans.address ?? '');
                fd.append(
                    'other_payment_information',
                    defaultTrans.other_payment_information ?? ''
                );

                // main fields
                fd.append('dob', this.deliveryBoys.dob);
                fd.append('mobile', this.deliveryBoys.mobile);
                fd.append('country_code', this.deliveryBoys.country_code || '');
                if (this.deliveryBoys.profile instanceof File) {
                    fd.append('profile', this.deliveryBoys.profile);
                }
                fd.append('email', this.deliveryBoys.email);
                fd.append('ifsc_code', this.deliveryBoys.ifsc_code);
                fd.append('bank_name', this.deliveryBoys.bank_name);
                fd.append('bank_account_number', this.deliveryBoys.bank_account_number);
                fd.append('account_name', this.deliveryBoys.account_name);
                fd.append('status', this.deliveryBoys.status);
                fd.append('remark', this.deliveryBoys.remark ?? '');
                fd.append('bonus_type', this.deliveryBoys.bonus_type);
                fd.append('bonus_percentage', this.deliveryBoys.bonus_percentage ?? 0);
                fd.append('bonus_min_amount', this.deliveryBoys.bonus_min_amount ?? 0);
                fd.append('bonus_max_amount', this.deliveryBoys.bonus_max_amount ?? 0);
                fd.append('return_bonus_type', this.deliveryBoys.return_bonus_type ?? 0);
                fd.append('return_bonus_percentage', this.deliveryBoys.return_bonus_percentage ?? 0);
                fd.append('return_bonus_min_amount', this.deliveryBoys.return_bonus_min_amount ?? 0);
                fd.append('return_bonus_max_amount', this.deliveryBoys.return_bonus_max_amount ?? 0);

                // password: required on CREATE; on EDIT send only when filled
                if (!isEdit) {
                    fd.append('password', this.deliveryBoys.password ?? '');
                    fd.append('confirm_password', this.deliveryBoys.confirm_password ?? '');
                } else if (this.deliveryBoys.password) {
                    fd.append('password', this.deliveryBoys.password);
                    fd.append('confirm_password', this.deliveryBoys.confirm_password ?? '');
                }

                // files
                if (this.deliveryBoys.driving_license instanceof File) {
                    fd.append('driving_license', this.deliveryBoys.driving_license);
                }
                if (this.deliveryBoys.national_identity_card instanceof File) {
                    fd.append(
                        'national_identity_card',
                        this.deliveryBoys.national_identity_card
                    );
                }

                const url = isEdit
                    ? this.$apiUrl + '/delivery_boys/update'
                    : this.$apiUrl + '/delivery_boys/save';

                const response = await axios.post(url, fd);

                if (!response.data || response.data.status !== 1) {
                    throw new Error(response.data?.message || __('something_went_wrong'));
                }

                if (!isEdit) {
                    this.deliveryBoys.id = response.data.data?.id;
                }

                // Mark clean so the post-save redirect doesn't trip the unsaved-changes guard.
                this.captureFormBaseline();

                this.showMessage('success', isEdit
                    ? (__('delivery_boy_updated_successfully'))
                    : (__('delivery_boy_saved_successfully'))
                );

                if (!this.login_user || this.login_user.role_id !== 3) {
                    this.$router.push({ path: '/delivery_boys' });
                }

            } catch (error) {
                this.showError(
                    error.message || error?.response?.data?.message || __('something_went_wrong') || 'Something went wrong.'
                );
            } finally {
                this.isLoading = false;
            }
        }

    }
};
</script>
<style scoped>
</style>