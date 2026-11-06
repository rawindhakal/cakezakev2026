// Dynamic Google Maps JS SDK loader.
// Loads the script once per page; concurrent callers share the same promise.
let loaderPromise = null;

export function loadGoogleMaps(apiKey, libraries = ['drawing', 'geometry']) {
    if (window.google && window.google.maps) {
        return Promise.resolve(window.google);
    }
    if (loaderPromise) {
        return loaderPromise;
    }

    loaderPromise = new Promise((resolve, reject) => {
        if (!apiKey) {
            loaderPromise = null;
            reject(new Error('Google Maps API key missing'));
            return;
        }
        const cb = '__googleMapsInitCb';
        window[cb] = () => {
            resolve(window.google);
            delete window[cb];
        };
        const script = document.createElement('script');
        const libs = libraries.length ? '&libraries=' + libraries.join(',') : '';
        script.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(apiKey)
            + libs + '&callback=' + cb;
        script.async = true;
        script.defer = true;
        script.onerror = () => {
            loaderPromise = null;
            reject(new Error('Failed to load Google Maps SDK'));
        };
        document.head.appendChild(script);
    });
    return loaderPromise;
}
