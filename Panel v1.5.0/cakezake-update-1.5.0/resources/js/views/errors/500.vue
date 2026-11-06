<template>
    <div class="err-page">
        <div class="err-card">
            <span class="err-icon is-danger"><ServerCrash :size="46" /></span>
            <div class="err-code">500</div>
            <h1 class="err-title">{{ __('system_error') }}</h1>
            <p class="err-text">{{ __('system_error_hint') }}</p>
            <div class="err-actions">
                <button type="button" class="btn btn-outline-secondary err-btn" @click="$router.go(-1)">
                    <ArrowLeft :size="16" /> {{ __('go_back') }}
                </button>
                <button type="button" class="btn btn-primary err-btn" @click="reload">
                    <RefreshCw :size="16" /> {{ __('try_again') }}
                </button>
            </div>
        </div>
    </div>
</template>
<script>
import { ServerCrash, ArrowLeft, RefreshCw } from 'lucide-vue-next';

export default {
    name: 'Error500',
    components: { ServerCrash, ArrowLeft, RefreshCw },
    methods: {
        reload() { window.location.reload(); },
    },
};
</script>
