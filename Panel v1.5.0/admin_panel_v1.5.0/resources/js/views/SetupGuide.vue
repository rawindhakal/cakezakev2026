<template>
    <div class="list-page">
        <div class="page-head">
            <h3 class="page-head-title">{{ __('setup_guide') }}</h3>
            <div class="page-head-actions ms-auto">
                <button class="list-icon-btn" v-b-tooltip.hover :title="__('refresh')" @click="load()">
                    <RefreshCw :class="{ 'is-spinning': isLoading }" />
                </button>
            </div>
        </div>

        <div class="list-surface">
            <div class="sg-head">
                <div class="sg-head-text">
                    <p class="sg-intro">{{ __('setup_guide_intro') }}</p>
                    <div class="sg-count">
                        <strong>{{ completed }}</strong> / {{ total }} {{ __('steps_completed') }}
                    </div>
                </div>
                <div class="sg-ring" :style="{ '--pct': percent }">
                    <span>{{ percent }}%</span>
                </div>
            </div>

            <div class="sg-progress"><span :style="{ width: percent + '%' }"></span></div>

            <div v-if="isComplete" class="sg-done">
                <span class="sg-done-icon"><PartyPopper :size="26" /></span>
                <h5 class="mb-1">{{ __('setup_complete_title') }}</h5>
                <p class="text-muted mb-0">{{ __('setup_complete_text') }}</p>
            </div>

            <ul class="sg-list">
                <li v-for="(step, i) in steps" :key="step.key" class="sg-item" :class="{ 'is-done': step.done }">
                    <span class="sg-dot">
                        <Check v-if="step.done" :size="14" />
                        <template v-else>{{ i + 1 }}</template>
                    </span>

                    <div class="sg-body">
                        <div class="sg-title">{{ step.label }}</div>
                        <small class="text-muted d-block">{{ step.hint }}</small>
                    </div>

                    <router-link :to="step.route" class="btn btn-sm sg-go"
                        :class="step.done ? 'btn-outline-secondary' : 'btn-primary'">
                        {{ step.done ? __('view') : __('setup') }}
                        <ArrowRight :size="14" />
                    </router-link>
                </li>
            </ul>
        </div>
    </div>
</template>

<script>
import axios from 'axios';
import { Check, ArrowRight, RefreshCw, PartyPopper } from 'lucide-vue-next';

export default {
    name: 'SetupGuide',
    components: { Check, ArrowRight, RefreshCw, PartyPopper },
    data() {
        return {
            isLoading: false,
            steps: [],
            total: 0,
            completed: 0,
            percent: 0,
            isComplete: false,
        };
    },
    created() {
        this._onUpdated = (e) => this.apply(e.detail || {});
        window.addEventListener('setup-guide:updated', this._onUpdated);
        this.load();
    },
    beforeUnmount() {
        window.removeEventListener('setup-guide:updated', this._onUpdated);
    },
    methods: {
        apply(d) {
            this.steps = d.steps || [];
            this.total = d.total || 0;
            this.completed = d.completed || 0;
            this.percent = d.percent || 0;
            this.isComplete = !!d.is_complete;
            this.isLoading = false;
        },
        load() {
            this.isLoading = true;
            axios.get(this.$apiUrl + '/setup_guide')
                .then(res => {
                    this.apply(res.data?.data || {});
                    // Push the fresh numbers to the popup too.
                    window.dispatchEvent(new Event('setup-guide:refresh'));
                })
                .catch(() => { this.isLoading = false; });
        },
    },
};
</script>

<style scoped>
.sg-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    padding: 1.1rem 1rem;
}
.sg-intro {
    margin: 0 0 0.35rem;
    font-size: 0.85rem;
    color: var(--app-muted);
    max-width: 60ch;
}
.sg-count {
    font-size: 0.85rem;
    color: var(--app-ink);
}
.sg-count strong {
    color: var(--bs-primary);
    font-size: 1.05rem;
}

/* Conic-gradient ring — the fraction reads at a glance without a chart lib. */
.sg-ring {
    flex-shrink: 0;
    width: 66px;
    height: 66px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    background: conic-gradient(var(--bs-primary) calc(var(--pct) * 1%), var(--app-hover) 0);
}
.sg-ring span {
    display: grid;
    place-items: center;
    width: 52px;
    height: 52px;
    border-radius: 50%;
    background: var(--app-card-bg);
    font-size: 0.8rem;
    font-weight: 700;
    color: var(--app-ink);
}

.sg-progress {
    height: 4px;
    background: var(--app-hover);
}
.sg-progress span {
    display: block;
    height: 100%;
    background: var(--bs-primary);
    transition: width .3s var(--app-ease);
}

.sg-done {
    text-align: center;
    padding: 1.5rem 1rem 0.5rem;
}
.sg-done-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 56px;
    height: 56px;
    border-radius: 16px;
    background: rgba(var(--bs-primary-rgb), .12);
    color: var(--bs-primary);
    margin-bottom: 0.6rem;
}

.sg-list {
    list-style: none;
    margin: 0;
    padding: 0;
}
.sg-item {
    display: flex;
    align-items: center;
    gap: 0.85rem;
    padding: 0.85rem 1rem;
    border-top: 1px solid var(--app-card-border);
}
.sg-dot {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    border: 1px solid var(--app-card-border);
    font-size: 0.75rem;
    font-weight: 700;
    color: var(--app-muted);
}
.sg-item.is-done .sg-dot {
    background: rgba(22, 163, 74, .12);
    border-color: #16a34a;
    color: #16a34a;
}
.sg-body {
    flex: 1;
    min-width: 0;
}
.sg-title {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--app-ink);
}
.sg-item.is-done .sg-title {
    text-decoration: line-through;
    color: var(--app-muted);
}
.sg-go {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    margin-bottom: 0;
    border-radius: 8px;
}

@media (max-width: 575.98px) {
    .sg-item {
        flex-wrap: wrap;
    }
    .sg-go {
        margin-inline-start: auto;
    }
}
</style>
