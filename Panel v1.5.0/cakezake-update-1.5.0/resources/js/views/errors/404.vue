<template>
    <div class="err-page">
        <div class="err-card">
            <span class="err-icon"><SearchX :size="46" /></span>
            <div class="err-code">404</div>
            <h1 class="err-title">{{ __('page_not_found') }}</h1>
            <p class="err-text">{{ __('page_not_found_hint') }}</p>
            <div class="err-actions">
                <button type="button" class="btn btn-outline-secondary err-btn" @click="$router.go(-1)">
                    <ArrowLeft :size="16" /> {{ __('go_back') }}
                </button>
                <router-link to="/dashboard" class="btn btn-primary err-btn">
                    <LayoutDashboard :size="16" /> {{ __('go_to_dashboard') }}
                </router-link>
            </div>
        </div>
    </div>
</template>
<script>
import { SearchX, ArrowLeft, LayoutDashboard } from 'lucide-vue-next';

export default {
    name: 'Error404',
    components: { SearchX, ArrowLeft, LayoutDashboard },
};
</script>
