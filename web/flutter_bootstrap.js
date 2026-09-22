{{flutter_js}}
{{flutter_build_config}}

// Keep the renderer on this origin. A CDN-only CanvasKit dependency prevents
// the application shell from starting when the device is offline.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
