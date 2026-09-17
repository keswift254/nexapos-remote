import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'home_screen_install_state.dart';

const _dismissedKey = 'nexapos_add_to_home_dismissed';

/// Real Add to Home Screen support. Android Chrome/Edge fire
/// beforeinstallprompt and hand over an event whose (non-standard, hence
/// the js_interop_unsafe calls below - package:web has no typed binding
/// for it) .prompt() method can be replayed later, once the user actually
/// taps our own "Add to home screen" banner rather than whatever moment
/// Chrome itself chose to fire the event. iOS Safari has never
/// implemented beforeinstallprompt at all - there, this only ever
/// detects "is this iOS Safari" so the caller can show manual
/// Share > Add to Home Screen instructions instead.
class _WebHomeScreenInstallEngine implements HomeScreenInstallEngine {
  JSObject? _deferredPrompt;
  bool _isStandalone = true;
  bool _isIosSafari = false;
  bool _isDismissed = false;
  void Function(HomeScreenInstallState)? _onChange;

  @override
  HomeScreenInstallState start(
    void Function(HomeScreenInstallState) onChange,
  ) {
    _onChange = onChange;
    final navigator = web.window.navigator;
    _isIosSafari = RegExp(r'iPad|iPhone|iPod').hasMatch(navigator.userAgent);
    final isDisplayStandalone = web.window
        .matchMedia('(display-mode: standalone)')
        .matches;
    final isIosStandalone =
        navigator.has('standalone') &&
        navigator.getProperty<JSBoolean?>('standalone'.toJS)?.toDart == true;
    _isStandalone = isDisplayStandalone || isIosStandalone;
    _isDismissed = web.window.localStorage.getItem(_dismissedKey) != null;

    web.window.addEventListener(
      'beforeinstallprompt',
      (web.Event event) {
        event.preventDefault();
        _deferredPrompt = event;
        _emit(canPromptInstall: true);
      }.toJS,
    );
    web.window.addEventListener(
      'appinstalled',
      (web.Event event) {
        _deferredPrompt = null;
        _isStandalone = true;
        _emit(canPromptInstall: false);
      }.toJS,
    );

    return _snapshot(canPromptInstall: false);
  }

  HomeScreenInstallState _snapshot({required bool canPromptInstall}) {
    return HomeScreenInstallState(
      isStandalone: _isStandalone,
      isIosSafari: _isIosSafari,
      canPromptInstall: canPromptInstall,
      isDismissed: _isDismissed,
    );
  }

  void _emit({required bool canPromptInstall}) =>
      _onChange?.call(_snapshot(canPromptInstall: canPromptInstall));

  @override
  Future<void> promptInstall() async {
    final deferred = _deferredPrompt;
    if (deferred == null) return;
    deferred.callMethod('prompt'.toJS);
    _deferredPrompt = null;
    _emit(canPromptInstall: false);
  }

  @override
  void dismiss() {
    web.window.localStorage.setItem(_dismissedKey, '1');
    _isDismissed = true;
  }
}

HomeScreenInstallEngine createHomeScreenInstallEngine() =>
    _WebHomeScreenInstallEngine();
