<template>
    <!-- Multiple root nodes (Vue 3 fragment) so these drop straight into a
         .card-grid as grid items — same shape as a real .entity-card, so the
         grid doesn't jump when data arrives. Reusable across every card listing. -->
    <div v-for="n in shown" :key="'sk-' + n" class="entity-card is-skeleton">
        <div class="entity-card-media skel"></div>
        <div class="entity-card-body">
            <div class="skel skel-line skel-title"></div>
            <div class="skel skel-line" style="width:60%"></div>
            <div class="skel skel-line" style="width:40%"></div>
            <div class="entity-card-foot">
                <div class="skel skel-line skel-actions"></div>
            </div>
        </div>
    </div>
</template>
<script>
export default {
    name: 'EntityCardSkeleton',
    props: {
        // How many placeholder cards to paint (usually the page size). Capped so a
        // large per-page value doesn't render a huge skeleton grid.
        count: { type: Number, default: 8 },
    },
    computed: {
        shown() {
            return Math.min(Math.max(this.count || 8, 1), 12);
        },
    },
};
</script>
