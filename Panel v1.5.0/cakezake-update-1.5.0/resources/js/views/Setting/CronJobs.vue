<template>
    <div>
        <div class="page-heading">
            <div class="page-head">
                <h3 class="page-head-title">{{ __('cron_jobs') }}</h3>
                <button class="btn btn-outline-secondary ms-auto d-inline-flex align-items-center gap-1" @click="load">
                    <RefreshCw :size="16" :class="{ 'is-spinning': loading }" /> {{ __('refresh') }}
                </button>
                <router-link to="/settings" class="btn btn-outline-secondary ms-2 d-inline-flex align-items-center gap-1">
                    <ArrowLeft :size="16" /> {{ __('back') }}
                </router-link>
            </div>

            <!-- Status -->
            <div class="row">
                <div class="col-md-3 col-6 mb-3">
                    <div class="card h-100 mb-0">
                        <div class="card-body">
                            <div class="text-muted small">{{ __('cron_status') }}</div>
                            <div class="mt-1">
                                <span class="badge fs-6" :class="info.cron_active ? 'bg-success' : 'bg-danger'">
                                    {{ info.cron_active ? __('active') : __('not_running') }}
                                </span>
                            </div>
                            <div class="text-muted small mt-1" v-if="info.last_heartbeat">
                                {{ __('last_heartbeat') }}: {{ info.last_heartbeat }}
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3 col-6 mb-3">
                    <div class="card h-100 mb-0">
                        <div class="card-body">
                            <div class="text-muted small">{{ __('queue_driver') }}</div>
                            <div class="fs-5 fw-bold">{{ info.queue?.driver || '-' }}</div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3 col-6 mb-3">
                    <div class="card h-100 mb-0">
                        <div class="card-body">
                            <div class="text-muted small">{{ __('pending_jobs') }}</div>
                            <div class="fs-5 fw-bold">{{ info.queue?.pending_jobs ?? '-' }}</div>
                            <div class="text-muted small" v-if="info.queue?.oldest_pending_at">
                                {{ __('oldest') }}: {{ info.queue.oldest_pending_at }}
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3 col-6 mb-3">
                    <div class="card h-100 mb-0">
                        <div class="card-body">
                            <div class="text-muted small">{{ __('failed_jobs') }}</div>
                            <div class="fs-5 fw-bold" :class="{ 'text-danger': (info.queue?.failed_jobs || 0) > 0 }">
                                {{ info.queue?.failed_jobs ?? '-' }}
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Setup guide -->
            <div class="card">
                <div class="card-header"><h4 class="mb-0">{{ __('cron_setup_guide') }}</h4></div>
                <div class="card-body">
                    <div class="alert alert-danger" v-if="loaded && !info.cron_active">
                        {{ __('cron_not_running_warning') }}
                    </div>
                    <p class="mb-3">{{ __('cron_setup_guide_intro') }}</p>

                    <!-- Pick the variant that matches how the server/panel asks for crons. -->
                    <ul class="nav nav-tabs mb-3">
                        <li class="nav-item" v-for="t in guideTabs" :key="t.key">
                            <a href="#" class="nav-link" :class="{ active: guideTab === t.key }"
                                @click.prevent="guideTab = t.key">{{ t.label }}</a>
                        </li>
                    </ul>

                    <!-- SSH / crontab -->
                    <div v-if="guideTab === 'ssh'">
                        <ol class="mb-3">
                            <li>{{ __('cron_setup_step_ssh') }} — <code>crontab -e</code></li>
                            <li>{{ __('cron_setup_step_add_line') }}</li>
                            <li>{{ __('cron_setup_step_verify') }}</li>
                        </ol>
                        <label class="fw-bold">{{ __('crontab_entry') }}</label>
                        <div class="input-group mb-2">
                            <input type="text" class="form-control font-monospace" :value="info.crontab_line" readonly>
                            <button class="btn btn-outline-primary mb-0" @click="copy(info.crontab_line)">
                                <Copy :size="15" /> {{ __('copy') }}
                            </button>
                        </div>
                        <p class="text-muted small mb-0">{{ __('cron_guide_ssh_note') }}</p>
                    </div>

                    <!-- Hosting panel: custom command + interval picker -->
                    <div v-if="guideTab === 'custom'">
                        <ol class="mb-3">
                            <li>{{ __('cron_guide_custom_step_open') }}</li>
                            <li>{{ __('cron_guide_custom_step_interval') }}</li>
                            <li>{{ __('cron_guide_custom_step_paste') }}</li>
                            <li>{{ __('cron_setup_step_verify') }}</li>
                        </ol>
                        <label class="fw-bold">{{ __('command') }}</label>
                        <div class="input-group mb-2">
                            <input type="text" class="form-control font-monospace" :value="info.command_custom" readonly>
                            <button class="btn btn-outline-primary mb-0" @click="copy(info.command_custom)">
                                <Copy :size="15" /> {{ __('copy') }}
                            </button>
                        </div>
                        <p class="text-muted small mb-0">{{ __('cron_guide_custom_note') }}</p>
                    </div>

                    <!-- Hosting panel: "PHP script" type -->
                    <div v-if="guideTab === 'php'">
                        <ol class="mb-3">
                            <li>{{ __('cron_guide_php_step_type') }}</li>
                            <li>{{ __('cron_guide_php_step_fields') }}</li>
                            <li>{{ __('cron_guide_custom_step_interval') }}</li>
                            <li>{{ __('cron_setup_step_verify') }}</li>
                        </ol>
                        <label class="fw-bold">{{ __('full_command') }}</label>
                        <div class="input-group mb-3">
                            <input type="text" class="form-control font-monospace" :value="info.command_php" readonly>
                            <button class="btn btn-outline-primary mb-0" @click="copy(info.command_php)">
                                <Copy :size="15" /> {{ __('copy') }}
                            </button>
                        </div>
                        <div class="row g-2 mb-2">
                            <div class="col-md-6">
                                <label class="fw-bold small">{{ __('script_path') }}</label>
                                <div class="input-group input-group-sm">
                                    <input type="text" class="form-control font-monospace" :value="info.artisan_path" readonly>
                                    <button class="btn btn-outline-primary" @click="copy(info.artisan_path)"><Copy :size="13" /></button>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <label class="fw-bold small">{{ __('argument') }}</label>
                                <div class="input-group input-group-sm">
                                    <input type="text" class="form-control font-monospace" value="schedule:run" readonly>
                                    <button class="btn btn-outline-primary" @click="copy('schedule:run')"><Copy :size="13" /></button>
                                </div>
                            </div>
                        </div>
                        <p class="text-muted small mb-0">{{ __('cron_guide_php_note') }}</p>
                    </div>

                    <div class="row text-muted small mt-3">
                        <div class="col-md-6"><strong>{{ __('php_binary') }}:</strong> <code>{{ info.php_binary }}</code></div>
                        <div class="col-md-6"><strong>{{ __('project_path') }}:</strong> <code>{{ info.project_path }}</code></div>
                    </div>
                </div>
            </div>

            <!-- Queue worker: a daemon, not a cron entry -->
            <div class="card">
                <div class="card-header"><h4 class="mb-0">{{ __('queue_worker') }}</h4></div>
                <div class="card-body">
                    <div class="alert alert-danger" v-if="loaded && info.worker?.stalled">
                        {{ __('queue_worker_stalled_warning') }}
                    </div>
                    <p class="mb-3">{{ __('queue_worker_intro') }}</p>

                    <div v-if="info.worker?.mode === 'scheduler'" class="alert alert-warning">
                        {{ __('queue_worker_fallback_active') }}
                    </div>

                    <ol class="mb-3">
                        <li>{{ __('queue_worker_step_open') }}</li>
                        <li>{{ __('queue_worker_step_paste') }}</li>
                        <li>{{ __('queue_worker_step_start') }}</li>
                    </ol>

                    <label class="fw-bold">{{ __('worker_command') }}</label>
                    <div class="input-group mb-3">
                        <input type="text" class="form-control font-monospace" :value="info.worker?.command" readonly>
                        <button class="btn btn-outline-primary mb-0" @click="copy(info.worker?.command)">
                            <Copy :size="15" /> {{ __('copy') }}
                        </button>
                    </div>

                    <label class="fw-bold">{{ __('supervisor_config') }}</label>
                    <div class="mb-1">
                        <pre class="bg-light border rounded p-2 mb-0 small" style="max-height: 260px; overflow:auto;">{{ info.worker?.supervisor_config }}</pre>
                    </div>
                    <button class="btn btn-sm btn-outline-primary mb-3" @click="copy(info.worker?.supervisor_config)">
                        <Copy :size="14" /> {{ __('copy') }}
                    </button>
                    <p class="text-muted small">{{ __('supervisor_config_note') }}</p>

                    <label class="fw-bold">{{ __('after_every_update') }}</label>
                    <div class="input-group mb-2">
                        <input type="text" class="form-control font-monospace" :value="info.worker?.restart_command" readonly>
                        <button class="btn btn-outline-primary mb-0" @click="copy(info.worker?.restart_command)">
                            <Copy :size="15" /> {{ __('copy') }}
                        </button>
                    </div>
                    <p class="text-muted small mb-0">{{ __('queue_restart_note') }}</p>
                </div>
            </div>

            <!-- Scheduled tasks: run manually -->
            <div class="card">
                <div class="card-header"><h4 class="mb-0">{{ __('scheduled_tasks') }}</h4></div>
                <div class="card-body">
                    <p class="text-muted">{{ __('scheduled_tasks_intro') }}</p>
                    <div class="table-responsive">
                        <table class="table align-middle">
                            <thead>
                                <tr>
                                    <th>{{ __('task') }}</th>
                                    <th>{{ __('command') }}</th>
                                    <th>{{ __('schedule') }}</th>
                                    <th class="text-end">{{ __('actions') }}</th>
                                </tr>
                            </thead>
                            <tbody>
                                <template v-for="t in info.scheduled_tasks || []" :key="t.key">
                                    <tr>
                                        <td>
                                            <div class="fw-bold">{{ t.name }}</div>
                                            <div class="text-muted small">{{ t.description }}</div>
                                        </td>
                                        <td><code>{{ t.command }}</code></td>
                                        <td>{{ t.schedule }}</td>
                                        <td class="text-end">
                                            <button class="btn btn-sm btn-primary" :disabled="running === t.key" @click="runTask(t.key)">
                                                <b-spinner small v-if="running === t.key" />
                                                <Play :size="14" v-else />
                                                {{ __('run_now') }}
                                            </button>
                                        </td>
                                    </tr>
                                    <tr v-if="outputs[t.key]">
                                        <td colspan="4">
                                            <pre class="bg-light border rounded p-2 mb-0 small" style="max-height: 200px; overflow:auto; white-space: pre-wrap;">{{ outputs[t.key] }}</pre>
                                        </td>
                                    </tr>
                                </template>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- Background jobs (informational) -->
            <div class="card">
                <div class="card-header"><h4 class="mb-0">{{ __('background_jobs') }}</h4></div>
                <div class="card-body">
                    <p class="text-muted">{{ __('background_jobs_intro') }}</p>
                    <ul class="list-group list-group-flush">
                        <li v-for="(j, i) in info.background_jobs || []" :key="i" class="list-group-item px-0">
                            <strong>{{ j.name }}</strong>
                            <div class="text-muted small">{{ j.description }}</div>
                        </li>
                    </ul>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import { ArrowLeft, RefreshCw, Copy, Play } from 'lucide-vue-next';

export default {
    components: { ArrowLeft, RefreshCw, Copy, Play },
    data() {
        return {
            info: {},
            loaded: false,
            loading: false,
            running: null,
            outputs: {},
            guideTab: 'ssh',
        };
    },
    computed: {
        guideTabs() {
            return [
                { key: 'ssh', label: __('cron_guide_tab_ssh') },
                { key: 'custom', label: __('cron_guide_tab_custom') },
                { key: 'php', label: __('cron_guide_tab_php') },
            ];
        },
    },
    created() {
        this.load();
    },
    methods: {
        load() {
            this.loading = true;
            axios.get(this.$apiUrl + '/cron')
                .then(r => { this.info = r.data.data || {}; this.loaded = true; })
                .catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.loading = false; });
        },
        runTask(key) {
            this.running = key;
            this.outputs = { ...this.outputs, [key]: '' };
            axios.post(this.$apiUrl + '/cron/run', { task: key })
                .then(r => {
                    const d = r.data;
                    if (d.status === 1) {
                        this.outputs = { ...this.outputs, [key]: (d.data?.output || __('task_executed_successfully')) };
                        this.showMessage('success', d.message);
                        this.load();
                    } else {
                        this.showError(d.message || __('something_went_wrong'));
                    }
                })
                .catch(() => this.showError(__('something_went_wrong')))
                .finally(() => { this.running = null; });
        },
        copy(text) {
            navigator.clipboard.writeText(text || '').then(() => this.showMessage('success', __('copied')));
        },
    },
};
</script>
