import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';
import Components from 'unplugin-vue-components/vite';
import { BootstrapVueNextResolver } from 'bootstrap-vue-next';
import { VitePWA } from 'vite-plugin-pwa';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
    resolve: {
        alias: {
            '@': path.resolve(__dirname, 'resources/js'),
        },
    },
    plugins: [
        laravel({
            input: [
                'resources/sass/app.scss',
                'resources/js/app.js',
            ],
            refresh: true,
        }),
        vue({
            template: {
                transformAssetUrls: {
                    base: null,
                    includeAbsolute: false,
                },
            },
        }),
        Components({
            resolvers: [BootstrapVueNextResolver()],
            dts: false,
        }),
        // injectManifest, not generateSW: the worker must also carry Firebase background
        // messaging, and only one worker can own a scope.
        VitePWA({
            strategies: 'injectManifest',
            srcDir: 'resources/js',
            filename: 'sw.js',
            outDir: 'public',
            injectRegister: false,      // registered by hand, with the Firebase config
            registerType: 'prompt',     // the user decides when to reload
            // The manifest is served by Laravel (PwaController) so the name, theme
            manifest: false,
            injectManifest: {
                rollupFormat: 'iife',
                maximumFileSizeToCacheInBytes: 6 * 1024 * 1024,
                globDirectory: 'public',
                globPatterns: ['build/assets/app-*.{js,css}', 'build/assets/*.{woff,woff2}'],
            },
            devOptions: { enabled: false },
        }),
    ],
    build: {
        chunkSizeWarningLimit: 2500,
        rollupOptions: {
            output: {
                // One request instead of ~80: every lucide icon used to be its own tiny chunk, so a
                // page like Orders waited on a waterfall of icon files before it could render.
                manualChunks(id) {
                    if (id.includes('node_modules/lucide-vue-next')) return 'icons';
                    if (/node_modules\/(vue|@vue|vue-router|axios|pinia)\//.test(id)) return 'vendor';
                    if (id.includes('node_modules/bootstrap-vue-next')) return 'bootstrap-vue';
                },
            },
            onwarn(warning, warn) {
                const msg = (warning.message || '') + ' ' + (warning.id || '');
                if (msg.includes('bootstrap-vue-next') && msg.includes('annotation')) {
                    return;
                }
                warn(warning);
            },
        },
    },
});
