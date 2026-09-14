/// Web's real "print the receipt" affordance - the browser's own print
/// dialog, per the browser-POS plan's design ("render the receipt on-
/// screen, with a print button that calls window.print(), not a second
/// thermal-formatting path"). Native keeps its existing thermal-printer
/// button instead (see receipt_screen.dart); this is never called there.
library;

export 'browser_print_native.dart'
    if (dart.library.js_interop) 'browser_print_web.dart';
