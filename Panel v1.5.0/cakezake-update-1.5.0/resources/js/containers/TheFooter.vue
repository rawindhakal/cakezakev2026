<template>
    <footer class="app-footer">
        <div class="app-footer-card">
            <!-- Copyright only, right-aligned. Rendered as plain text rather than the
                 old dead `javascript:void(0)` anchor, so it takes the default body
                 colour instead of the primary link colour. -->
            <span class="app-footer-copyright" v-html="copyrightDetails"></span>
        </div>
    </footer>
</template>

<script>
export default {
    name: 'TheFooter',
    data() {
        return {
            copyrightDetails: window.copyrightDetails,
        };
    }
}
</script>
