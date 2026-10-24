{{flutter_js}}
{{flutter_build_config}}

// Offline caching is done by our own sw.js (registered in index.html), so
// Flutter's built-in service worker is not used.
_flutter.loader.load();
