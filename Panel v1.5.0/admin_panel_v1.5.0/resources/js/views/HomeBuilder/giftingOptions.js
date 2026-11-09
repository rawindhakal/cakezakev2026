import axios from 'axios';
import { resolveImageUrl } from './homeBuilderHelpers.js';

// Occasions and relationships a showcase section can pick from, loaded once per page.
let cache = null;

export function loadGiftingOptions() {
    if (!cache) {
        const get = (type) => axios.get(`${window.baseUrl}/api/gifting/${type}`)
            .then(r => (r.data.data || []).filter(x => Number(x.status) !== 0)
                .map(x => ({ id: Number(x.id), name: x.name, slug: x.slug, image_url: resolveImageUrl(x.image) })))
            .catch(() => []);
        cache = Promise.all([get('occasions'), get('relationships')])
            .then(([occasions, relationships]) => ({ occasions, relationships }));
    }
    return cache;
}
