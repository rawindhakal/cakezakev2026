<template>
    <div class="auth">
        <div class="login-wrapper inst-wrapper">
            <div class="inst-shell">
                <aside class="inst-rail">
                    <div class="inst-rail-brand">
                        <img :src="$baseUrl + '/images/favicon.png'" alt="" class="inst-rail-logo" />
                        <div class="inst-rail-brand-text">
                            <span class="inst-rail-name">CakeZake</span>
                            <span class="inst-rail-tag">Setup Wizard</span>
                        </div>
                    </div>

                    <ol class="inst-steps">
                        <li v-for="(s, i) in steps" :key="s.title" class="inst-step"
                            :class="{ 'is-done': i < currentStep, 'is-active': i === currentStep }">
                            <span class="inst-step-dot">
                                <Check v-if="i < currentStep" :size="13" />
                                <template v-else>{{ i + 1 }}</template>
                            </span>
                            <span class="inst-step-text">
                                <span class="inst-step-title">{{ s.title }}</span>
                                <span class="inst-step-sub">{{ s.sub }}</span>
                            </span>
                        </li>
                    </ol>

                    <div class="inst-rail-foot">Powered by CakeZake</div>
                </aside>

                <section class="inst-pane">
                    <div class="inst-pane-head">
                        <span class="inst-eyebrow">Step {{ currentStep + 1 }} of {{ steps.length }}</span>
                        <h4 class="inst-pane-title">{{ steps[currentStep].heading }}</h4>
                        <p class="inst-pane-blurb">{{ steps[currentStep].blurb }}</p>
                        <div class="inst-progress"><span :style="{ width: progressPct + '%' }"></span></div>
                    </div>

                    <div class="inst-pane-body">

                        <!-- 1. Welcome -->
                        <div v-if="currentStep === 0">
                            <ul class="inst-checklist">
                                <li v-for="(s, i) in steps.slice(1, 4)" :key="i">
                                    <span class="inst-checklist-icon">
                                        <component :is="s.icon" :size="16" />
                                    </span>
                                    <span>
                                        <strong>{{ s.title }}</strong>
                                        <small class="text-muted d-block">{{ s.blurb }}</small>
                                    </span>
                                </li>
                            </ul>
                            <p class="text-muted mb-0">
                                Thank you for choosing CakeZake. The whole setup takes about 3-5 minutes.
                            </p>
                        </div>

                        <!-- 2. Requirements -->
                        <div v-else-if="currentStep === 1">
                            <div v-if="checking" class="inst-state">
                                <LoaderCircle :size="20" class="is-spinning" />
                                <span>Checking your server...</span>
                            </div>

                            <div v-else-if="checkFailed" class="inst-state is-bad">
                                <TriangleAlert :size="20" />
                                <span>Could not read your server details.</span>
                                <button type="button" class="btn btn-sm btn-outline-primary inst-retry"
                                    @click="getRequirements()">Try again</button>
                            </div>

                            <template v-else>
                                <div class="inst-panel">
                                    <div class="inst-panel-head">
                                        <span>PHP Version</span>
                                        <span class="inst-chip"
                                            :class="phpSupportInfo.supported ? 'is-ok' : 'is-bad'">
                                            <component :is="phpSupportInfo.supported ? 'Check' : 'X'" :size="12" />
                                            {{ phpSupportInfo.current }}
                                        </span>
                                    </div>
                                    <p class="inst-panel-note">PHP {{ phpSupportInfo.minimum }} or higher is required.</p>
                                </div>

                                <div class="inst-panel">
                                    <div class="inst-panel-head">
                                        <span>PHP Extensions</span>
                                        <span class="inst-chip" :class="extensionsOk ? 'is-ok' : 'is-bad'">
                                            {{ okExtensionCount }} / {{ extensionList.length }}
                                        </span>
                                    </div>
                                    <div class="inst-grid">
                                        <div v-for="ext in extensionList" :key="ext.name" class="inst-req"
                                            :class="ext.enabled ? 'is-ok' : 'is-bad'">
                                            <component :is="ext.enabled ? 'Check' : 'X'" :size="13" />
                                            <span>{{ ext.name }}</span>
                                        </div>
                                    </div>
                                </div>

                                <div class="inst-panel">
                                    <div class="inst-panel-head"><span>Folder Permissions</span></div>
                                    <div v-for="(row, i) in permissionList" :key="i" class="inst-perm"
                                        :class="row.ok ? 'is-ok' : 'is-bad'">
                                        <code>{{ row.folder }}</code>
                                        <span class="inst-perm-right">
                                            <span class="inst-perm-value">{{ row.value }}</span>
                                            <component :is="row.ok ? 'Check' : 'X'" :size="13" />
                                        </span>
                                    </div>
                                </div>
                            </template>
                        </div>

                        <!-- 3. Purchase code -->
                        <div v-else-if="currentStep === 2">
                            <label class="form-label" for="purchase_code">Purchase Code<span
                                    class="text-danger text-xs">*</span></label>
                            <input type="text" v-model="purchase_code" id="purchase_code" class="form-control"
                                placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" />
                            <small class="text-muted d-block">You can find this on your CakeZake downloads page,
                                under the license certificate of your purchase.</small>
                        </div>

                        <!-- 4. Database + admin account -->
                        <div v-else-if="currentStep === 3">
                            <div class="row g-3 justify-content-start">
                                <div class="col-md-8">
                                    <label class="form-label" for="database_host">Database Host<span
                                            class="text-danger text-xs">*</span></label>
                                    <input type="text" placeholder="127.0.0.1" v-model="database.database_host"
                                        id="database_host" class="form-control" />
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label" for="database_port">Port<span
                                            class="text-danger text-xs">*</span></label>
                                    <input type="text" placeholder="3306" v-model="database.database_port"
                                        id="database_port" class="form-control" />
                                </div>
                                <div class="col-md-12">
                                    <label class="form-label" for="database_name">Database Name<span
                                            class="text-danger text-xs">*</span></label>
                                    <input type="text" placeholder="Database Name" v-model="database.database_name"
                                        id="database_name" class="form-control" />
                                    <small class="text-muted d-block">The database must already exist and be
                                        empty.</small>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label" for="database_username">Database Username<span
                                            class="text-danger text-xs">*</span></label>
                                    <input type="text" placeholder="root" v-model="database.database_username"
                                        id="database_username" class="form-control" />
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label" for="database_password">Database Password</label>
                                    <input type="password" placeholder="Database Password"
                                        v-model="database.database_password" id="database_password" class="form-control"
                                        autocomplete="off" />
                                    <small class="text-muted d-block">Leave empty if your database has no
                                        password.</small>
                                </div>
                            </div>

                            <div class="inst-divider"><span>Admin Account</span></div>

                            <div class="row g-3 justify-content-start">
                                <div class="col-md-6">
                                    <label class="form-label" for="admin_email">Admin Email<span
                                            class="text-danger text-xs">*</span></label>
                                    <input type="email" placeholder="you@example.com" v-model="database.admin_email"
                                        id="admin_email" class="form-control" />
                                    <small class="text-muted d-block">You will sign in with this email.</small>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label" for="admin_password">Admin Password<span
                                            class="text-danger text-xs">*</span></label>
                                    <div class="input-group">
                                        <input :type="showAdminPassword ? 'text' : 'password'"
                                            placeholder="Admin Password" v-model="database.admin_password"
                                            name="admin_password" id="admin_password" class="form-control"
                                            autocomplete="off">
                                        <button type="button" @click="showAdminPassword = !showAdminPassword"
                                            class="btn btn-outline-primary inst-eye-btn">
                                            <Eye v-if="showAdminPassword" :size="16" />
                                            <EyeOff v-else :size="16" />
                                        </button>
                                    </div>
                                    <small class="text-muted d-block">Keep this safe, you need it to log in.</small>
                                </div>
                            </div>
                        </div>

                        <!-- 5. Finish -->
                        <div v-else class="inst-done">
                            <span class="inst-done-icon"><PartyPopper :size="30" /></span>
                            <h4 class="inst-done-title">Your branch is ready</h4>
                            <p class="text-muted mb-3">
                                Log in to your admin dashboard to make changes and modify any of the default content to
                                suit your needs.
                            </p>
                            <div class="inst-creds">
                                <div class="inst-creds-head">
                                    <KeyRound :size="15" /> <span>Your login details</span>
                                </div>
                                <div class="inst-creds-row">
                                    <span class="inst-creds-label">Email</span>
                                    <code class="inst-creds-value">{{ database.admin_email }}</code>
                                    <button type="button" class="inst-creds-copy"
                                        @click="copyCred(database.admin_email, 'email')">
                                        <Check v-if="copied === 'email'" :size="14" />
                                        <Copy v-else :size="14" />
                                    </button>
                                </div>
                                <div class="inst-creds-row">
                                    <span class="inst-creds-label">Password</span>
                                    <code class="inst-creds-value">
                                        {{ showDonePassword ? database.admin_password : '•'.repeat(database.admin_password.length || 8) }}
                                    </code>
                                    <button type="button" class="inst-creds-copy"
                                        @click="showDonePassword = !showDonePassword">
                                        <Eye v-if="showDonePassword" :size="14" />
                                        <EyeOff v-else :size="14" />
                                    </button>
                                    <button type="button" class="inst-creds-copy"
                                        @click="copyCred(database.admin_password, 'password')">
                                        <Check v-if="copied === 'password'" :size="14" />
                                        <Copy v-else :size="14" />
                                    </button>
                                </div>
                                <small class="inst-creds-note">
                                    Save these now — they are not shown again after you leave this screen.
                                </small>
                            </div>

                            <p class="text-muted mb-3">
                                Please come back and
                                <a href="https://www.cakezake.com/products/cakezake-hyperlocal-quick-commerce-ecommerce-platform"
                                    target="_blank">leave a 5-star rating</a>
                                if you are happy with this script.
                            </p>
                            <small class="text-muted d-block">For security reasons, the system removes the install link
                                automatically.</small>
                        </div>

                    </div>

                    <div v-if="errorMsg" class="inst-error">
                        <TriangleAlert :size="15" />
                        <span>{{ errorMsg }}</span>
                    </div>

                    <div class="inst-pane-foot">
                        <button v-if="currentStep > 0 && currentStep < steps.length - 1" type="button"
                            class="btn btn-light inst-btn" :disabled="loading" @click="back">
                            <ArrowLeft :size="15" /> Back
                        </button>
                        <button type="button" class="btn btn-primary inst-btn ms-auto" :disabled="loading"
                            @click="next">
                            <LoaderCircle v-if="loading" :size="15" class="is-spinning" />
                            {{ nextLabel }}
                            <ArrowRight v-if="!loading && currentStep < steps.length - 1" :size="15" />
                        </button>
                    </div>
                </section>

            </div>
        </div>
    </div>
</template>
<script>
import axios from 'axios';
import { markRaw } from 'vue';
import {
    Check, X, Eye, EyeOff, Copy, KeyRound, ArrowLeft, ArrowRight, LoaderCircle, TriangleAlert,
    ServerCog, Database, BadgeCheck, PartyPopper,
} from 'lucide-vue-next';

export default {
    components: {
        Check, X, Eye, EyeOff, Copy, KeyRound, ArrowLeft, ArrowRight, LoaderCircle, TriangleAlert, PartyPopper,
    },
    data: function () {
        return {
            loading: false,
            errorMsg: null,
            currentStep: 0,

            steps: [
                {
                    title: 'Welcome', sub: 'Start here',
                    heading: 'Welcome to CakeZake', blurb: 'This wizard sets up your branch in a few short steps.',
                },
                {
                    // Icons render through <component :is>, so keep them out of the reactive proxy.
                    title: 'Requirements', sub: 'Server check', icon: markRaw(ServerCog),
                    heading: 'Server requirements', blurb: 'We check that your server can run CakeZake.',
                },
                {
                    title: 'Purchase Code', sub: 'License', icon: markRaw(BadgeCheck),
                    heading: 'Verify your purchase', blurb: 'Confirm the purchase code that came with your order.',
                },
                {
                    title: 'Database', sub: 'Connection & admin', icon: markRaw(Database),
                    heading: 'Database and admin account', blurb: 'Connect your database and create your admin login.',
                },
                {
                    title: 'Finish', sub: 'All done',
                    heading: 'Setup complete', blurb: 'Everything is installed and ready to use.',
                },
            ],

            checking: true,
            checkFailed: false,
            phpSupportInfo: {},
            requirements: {},
            permissions: {},

            database: {
                database_host: '127.0.0.1',
                database_port: 3306,
                database_name: '',
                database_username: 'root',
                database_password: '',
                admin_email: '',
                admin_password: '',
            },
            showAdminPassword: false,
            showDonePassword: false,
            copied: null,
            purchase_code: ''
        };
    },
    computed: {
        progressPct() {
            return ((this.currentStep + 1) / this.steps.length) * 100;
        },
        nextLabel() {
            return ['Get Started', 'Continue', 'Verify', 'Install Now', 'Go to Login'][this.currentStep];
        },
        // The API nests extensions by type ({ php: { curl: true } }); the grid wants one flat list.
        extensionList() {
            const groups = (this.requirements && this.requirements.requirements) || {};
            const list = [];
            Object.keys(groups).forEach(type => {
                Object.keys(groups[type]).forEach(name => list.push({ name, enabled: !!groups[type][name] }));
            });
            return list;
        },
        okExtensionCount() {
            return this.extensionList.filter(e => e.enabled).length;
        },
        extensionsOk() {
            return this.extensionList.length > 0 && this.okExtensionCount === this.extensionList.length;
        },
        permissionList() {
            const rows = (this.permissions && this.permissions.permissions) || [];
            return rows.map(row => {
                // `.env` reports writability under `permission`; folders report it under `isSet`.
                const isEnv = row.folder === '.env';
                return {
                    folder: row.folder,
                    ok: isEnv ? !!row.permission : !!row.isSet,
                    value: isEnv ? (row.permission ? 'Writable' : 'Not writable') : row.permission,
                };
            });
        },
    },
    mounted() {
        if (this.loggedUser) {
            this.$router.push('/dashboard');
        }
    },
    created: function () {
        this.getRequirements();
    },
    methods: {
        getRequirements: function () {
            this.checking = true;
            this.checkFailed = false;
            axios.get(this.$apiUrl + '/install/requirements').then((response) => {
                const data = response.data.data;
                this.phpSupportInfo = data.phpSupportInfo || {};
                this.requirements = data.requirements || {};
                this.permissions = data.permissions || {};
                this.checking = false;
            }).catch(error => {
                this.checking = false;
                this.checkFailed = true;
                if (error?.request?.statusText) {
                    this.showError(error.request.statusText);
                } else if (error.message) {
                    this.showError(error.message);
                } else {
                    this.showError("Something went wrong!");
                }
            });
        },

        back() {
            if (this.currentStep === 0) return;
            this.errorMsg = null;
            this.currentStep--;
        },

        next() {
            if (this.currentStep === this.steps.length - 1) {
                this.finish();
                return;
            }

            const validators = [null, this.validateAsync, this.purchaseCode, this.onCreateDatabase];
            const validate = validators[this.currentStep];

            if (!validate) {
                this.errorMsg = null;
                this.currentStep++;
                return;
            }

            this.errorMsg = null;
            this.loading = true;
            validate().then(() => {
                this.loading = false;
                this.currentStep++;
            }).catch(message => {
                this.loading = false;
                this.errorMsg = message;
            });
        },

        validateAsync: function () {
            return new Promise((resolve, reject) => {
                if (this.checking || this.checkFailed) {
                    reject('Still checking your server. Please wait a moment and try again.');
                } else if (this.requirements['errors'] === true || !this.phpSupportInfo['supported'] || this.permissions['errors'] === true || !this.permissionList.every(row => row.ok)) {
                    reject('Please Check the requirements and Try again after fixing it.')
                } else {
                    resolve(true)
                }
            });
        },

        onCreateDatabase: function () {
            return new Promise((resolve, reject) => {
                axios.post(this.$apiUrl + '/install/database', this.database).then((response) => {
                    var data = response.data;
                    if (data.status) {
                        resolve(true)
                    } else {
                        reject(data.message);
                    }
                }).catch(error => {
                    reject(error.toString())
                });
            });
        },

        purchaseCode: function () {
            return new Promise((resolve, reject) => {
                let data = { 'purchase_code': this.purchase_code };
                axios.post(this.$apiUrl + '/install/purchase_code', data).then((response) => {
                    var data = response.data;
                    if (data.status) {
                        resolve(true)
                    } else {
                        reject(data.message);
                    }
                }).catch(error => {
                    reject(error.toString())
                });
            });
        },

        copyCred(value, which) {
            const done = () => {
                this.copied = which;
                setTimeout(() => { this.copied = null; }, 1500);
            };
            navigator.clipboard.writeText(String(value || '')).then(done).catch(() => {
                // http / older browsers have no clipboard API
                const ta = document.createElement('textarea');
                ta.value = String(value || '');
                document.body.appendChild(ta);
                ta.select();
                document.execCommand('copy');
                ta.remove();
                done();
            });
        },

        finish: function () {
            window.location.reload();
            this.$router.push({ path: '/login' });
        },
    }
}
</script>

<style scoped>
/* The login shell pins its card to the right with a 200px gutter — the wizard is
   a wide two-pane sheet, so it centres instead. */
.inst-wrapper {
    justify-content: center;
    padding: 40px 16px;
}

.inst-shell {
    display: flex;
    width: 100%;
    max-width: 1080px;
    background-color: var(--app-card-bg);
    border-radius: 16px;
    box-shadow: 0 20px 45px rgba(0, 0, 0, .45);
    overflow: hidden;
}

/* ---- Left rail ---- */
.inst-rail {
    flex: 0 0 280px;
    display: flex;
    flex-direction: column;
    padding: 1.75rem 1.4rem;
    background:
        radial-gradient(circle at 100% 0%, rgba(255, 255, 255, .18), transparent 55%),
        linear-gradient(160deg, var(--bs-primary), rgba(var(--bs-primary-rgb), .78));
    color: #fff;
}

.inst-rail-brand {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    padding-bottom: 1.75rem;
}

.inst-rail-logo {
    width: 36px;
    height: 36px;
    object-fit: contain;
    background: #fff;
    border-radius: 9px;
    padding: 5px;
}

.inst-rail-brand-text {
    display: flex;
    flex-direction: column;
    line-height: 1.15;
}

.inst-rail-name {
    font-size: 1rem;
    font-weight: 700;
}

.inst-rail-tag {
    font-size: 0.7rem;
    opacity: .75;
}

.inst-steps {
    list-style: none;
    margin: 0;
    padding: 0;
    flex: 1;
}

.inst-step {
    position: relative;
    display: flex;
    align-items: flex-start;
    gap: 0.7rem;
    padding-bottom: 1.35rem;
}

/* Connector line, so the rail reads as one sequence rather than five chips. */
.inst-step:not(:last-child)::before {
    content: '';
    position: absolute;
    inset-block-start: 26px;
    inset-block-end: 6px;
    inset-inline-start: 12px;
    width: 1px;
    background: rgba(255, 255, 255, .3);
}

.inst-step-dot {
    position: relative;
    z-index: 1;
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 25px;
    height: 25px;
    border-radius: 50%;
    border: 1px solid rgba(255, 255, 255, .5);
    background: rgba(255, 255, 255, .12);
    font-size: 0.7rem;
    font-weight: 700;
    transition: all .2s var(--app-ease);
}

.inst-step-text {
    display: flex;
    flex-direction: column;
    line-height: 1.25;
    min-width: 0;
}

.inst-step-title {
    font-size: 0.82rem;
    font-weight: 600;
    opacity: .8;
}

.inst-step-sub {
    font-size: 0.68rem;
    opacity: .55;
}

.inst-step.is-active .inst-step-dot {
    background: #fff;
    border-color: #fff;
    color: var(--bs-primary);
    box-shadow: 0 0 0 4px rgba(255, 255, 255, .2);
}

.inst-step.is-active .inst-step-title {
    opacity: 1;
}

.inst-step.is-done .inst-step-dot {
    background: rgba(255, 255, 255, .9);
    border-color: rgba(255, 255, 255, .9);
    color: var(--bs-primary);
}

.inst-rail-foot {
    font-size: 0.68rem;
    opacity: .6;
}

/* ---- Right pane ---- */
.inst-pane {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-width: 0;
    padding: 1.75rem 2rem;
}

.inst-eyebrow {
    font-size: 0.68rem;
    font-weight: 700;
    letter-spacing: .06em;
    text-transform: uppercase;
    color: var(--bs-primary);
}

.inst-pane-title {
    margin: 0.3rem 0 0.2rem;
    font-weight: 700;
    color: var(--app-ink);
}

.inst-pane-blurb {
    margin: 0;
    font-size: 0.82rem;
    color: var(--app-muted);
}

.inst-progress {
    height: 3px;
    margin-top: 1rem;
    border-radius: 999px;
    background: var(--app-hover);
    overflow: hidden;
}

.inst-progress span {
    display: block;
    height: 100%;
    border-radius: 999px;
    background: var(--bs-primary);
    transition: width .3s var(--app-ease);
}

.inst-pane-body {
    flex: 1;
    max-height: 62vh;
    overflow-y: auto;
    padding: 1.4rem 0.75rem;
    margin-inline: -0.75rem;
}

/* ---- Welcome ---- */
.inst-checklist {
    list-style: none;
    padding: 0;
    margin: 0 0 1.1rem;
}

.inst-checklist li {
    display: flex;
    align-items: flex-start;
    gap: 0.7rem;
    padding: 0.5rem 0;
    font-size: 0.85rem;
    color: var(--app-ink);
}

.inst-checklist-icon {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 34px;
    height: 34px;
    border-radius: 10px;
    background: rgba(var(--bs-primary-rgb), .1);
    color: var(--bs-primary);
}

/* ---- Requirements ---- */
.inst-state {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 2rem 0;
    font-size: 0.85rem;
    color: var(--app-muted);
}

.inst-state.is-bad {
    color: #dc2626;
}

.inst-retry {
    margin-bottom: 0;
    margin-inline-start: 0.25rem;
}

.is-spinning {
    animation: inst-spin 1s linear infinite;
}

@keyframes inst-spin {
    to {
        transform: rotate(360deg);
    }
}

.inst-panel {
    border: 1px solid var(--app-card-border);
    border-radius: 10px;
    margin-bottom: 0.85rem;
    overflow: hidden;
}

.inst-panel-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.55rem 0.75rem;
    background: var(--app-thead-bg);
    font-size: 0.78rem;
    font-weight: 700;
    color: var(--app-ink);
}

.inst-panel-note {
    margin: 0;
    padding: 0.55rem 0.75rem;
    font-size: 0.75rem;
    color: var(--app-muted);
}

.inst-chip {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.1rem 0.45rem;
    border-radius: 999px;
    font-size: 0.68rem;
    font-weight: 600;
}

.inst-chip.is-ok {
    background: rgba(22, 163, 74, .12);
    color: #16a34a;
}

.inst-chip.is-bad {
    background: rgba(239, 68, 68, .12);
    color: #dc2626;
}

.inst-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
    gap: 0.3rem 0.75rem;
    padding: 0.7rem 0.75rem;
}

.inst-req {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.78rem;
    color: var(--app-ink);
}

.inst-req svg {
    flex-shrink: 0;
}

.inst-req.is-ok svg {
    color: #16a34a;
}

.inst-req.is-bad,
.inst-req.is-bad svg {
    color: #dc2626;
}

.inst-perm {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
    padding: 0.5rem 0.75rem;
    border-top: 1px solid var(--app-card-border);
    font-size: 0.78rem;
}

.inst-perm code {
    color: var(--app-ink);
}

.inst-perm-right {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
}

.inst-perm-value {
    font-size: 0.75rem;
    color: var(--app-muted);
}

.inst-perm.is-ok svg {
    color: #16a34a;
}

.inst-perm.is-bad code,
.inst-perm.is-bad .inst-perm-value,
.inst-perm.is-bad svg {
    color: #dc2626;
}

/* ---- Database ---- */
.inst-divider {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    margin: 1.35rem 0 0.85rem;
    color: var(--app-muted);
    font-size: 0.72rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.inst-divider::before,
.inst-divider::after {
    content: '';
    flex: 1;
    height: 1px;
    background: var(--app-card-border);
}

/* .btn carries a global bottom margin that knocks it off the input-group line. */
.inst-eye-btn {
    margin-bottom: 0;
}

/* ---- Finish ---- */
.inst-creds {
    text-align: left;
    border: 1px solid var(--bs-border-color, #e5e7eb);
    border-radius: .6rem;
    padding: .85rem 1rem;
    margin: 0 auto 1.25rem;
    max-width: 420px;
    background: rgba(0, 0, 0, .015);
}

.inst-creds-head {
    display: flex;
    align-items: center;
    gap: .4rem;
    font-weight: 600;
    font-size: .85rem;
    margin-bottom: .6rem;
}

.inst-creds-row {
    display: flex;
    align-items: center;
    gap: .5rem;
    padding: .3rem 0;
}

.inst-creds-label {
    font-size: .78rem;
    color: var(--app-muted, #6b7280);
    width: 68px;
    flex: 0 0 68px;
}

.inst-creds-value {
    flex: 1 1 auto;
    word-break: break-all;
    font-size: .85rem;
}

.inst-creds-copy {
    border: 0;
    background: transparent;
    color: var(--app-muted, #6b7280);
    padding: .15rem .25rem;
    line-height: 1;
    cursor: pointer;
}

.inst-creds-copy:hover {
    color: var(--bs-primary, #2563eb);
}

.inst-creds-note {
    display: block;
    margin-top: .5rem;
    font-size: .74rem;
    color: var(--app-muted, #6b7280);
}

.inst-done {
    text-align: center;
    padding: 1rem 0;
}

.inst-done-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 62px;
    height: 62px;
    border-radius: 18px;
    background: rgba(var(--bs-primary-rgb), .12);
    color: var(--bs-primary);
    margin-bottom: 0.85rem;
}

.inst-done-title {
    font-weight: 700;
    color: var(--app-ink);
}

/* ---- Footer / errors ---- */
.inst-error {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    margin-bottom: 0.75rem;
    padding: 0.5rem 0.75rem;
    border-radius: 8px;
    background: rgba(239, 68, 68, .1);
    color: #dc2626;
    font-size: 0.8rem;
}

.inst-error svg {
    flex-shrink: 0;
}

.inst-pane-foot {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding-top: 1.1rem;
    border-top: 1px solid var(--app-card-border);
}

.inst-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    margin-bottom: 0;
    padding-inline: 1.1rem;
}

@media (max-width: 767.98px) {
    .inst-shell {
        flex-direction: column;
    }

    .inst-rail {
        flex: none;
        padding: 1.1rem 1.2rem;
    }

    .inst-rail-brand {
        padding-bottom: 1.1rem;
    }

    /* Stacked, the rail becomes a compact progress strip: dots only, laid out in a row. */
    .inst-steps {
        display: flex;
        align-items: center;
        justify-content: space-between;
    }

    .inst-step {
        padding-bottom: 0;
    }

    .inst-step:not(:last-child)::before {
        inset-block: 12px auto;
        inset-inline: 25px -100%;
        width: auto;
        height: 1px;
    }

    .inst-step-text,
    .inst-rail-foot {
        display: none;
    }

    .inst-pane {
        padding: 1.25rem;
    }

    .inst-pane-body {
        max-height: none;
    }
}
</style>
