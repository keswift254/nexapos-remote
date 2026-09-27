import 'package:flutter/material.dart';

import '../../core/web_update_stub.dart'
    if (dart.library.js_interop) '../../core/web_update_web.dart';

class WebUpdateButton extends StatefulWidget {
  const WebUpdateButton({super.key});

  @override
  State<WebUpdateButton> createState() => _WebUpdateButtonState();
}

class _WebUpdateButtonState extends State<WebUpdateButton> {
  bool _busy = false;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await refreshWebApplication();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not download the update. Check your connection and try again. Your shop data is safe.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FilledButton.icon(
        onPressed: _busy ? null : _install,
        icon: const Icon(Icons.system_update_alt),
        label: Text(_busy ? 'Downloading update…' : 'Download & Install'),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
