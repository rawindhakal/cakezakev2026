<template>
    <div class="err-page">
        <div class="err-card">
            <span class="err-icon is-warn"><ShieldAlert :size="46" /></span>
            <div class="err-code">403</div>
            <h1 class="err-title">{{ __('forbidden') }}</h1>
            <p class="err-text">{{ __('forbidden_hint') }}</p>
            <p class="err-redirect text-muted"><b-spinner small /> {{ __('redirecting') }}</p>
        </div>
    </div>
</template>
<script>
import { ShieldAlert } from 'lucide-vue-next';
import router from '../../router/index.js';
import Auth from '../../Auth.js';

export default {
    name: 'Error403',
    components: { ShieldAlert },
    created() {
        setTimeout(function () {
            if (!UserPermissions || !Auth.check()) {
                router.push('/login');
            } else {
                router.push('/dashboard');
            }
        }, 2000);
    },
};
</script>
