import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../data/support/support_gateway.dart';
import '../../domain/entities/paystack_credentials.dart';

class SupportPhotoPicker extends StatefulWidget {
  const SupportPhotoPicker({super.key, required this.onChanged, this.enabled = true});
  final ValueChanged<List<Uint8List>> onChanged;
  final bool enabled;
  @override
  State<SupportPhotoPicker> createState() => SupportPhotoPickerState();
}

class SupportPhotoPickerState extends State<SupportPhotoPicker> {
  final _photos = <Uint8List>[];
  bool _busy = false;
  String? _error;
  void clear() {
    setState(() { _photos.clear(); _error = null; });
    widget.onChanged(List.of(_photos));
  }

  Future<void> _add(bool paste) async {
    if (_busy || !widget.enabled) return;
    setState(() { _busy = true; _error = null; });
    try {
      final images = <Uint8List>[];
      if (paste) {
        final image = await Pasteboard.image;
        if (image == null) throw Exception('Copy a photo first, or use Add photos.');
        images.add(image);
      } else {
        final result = await FilePicker.platform.pickFiles(type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'], allowMultiple: true, withData: true);
        if (result == null) return;
        for (final file in result.files) {
          if (file.bytes != null) images.add(file.bytes!);
        }
      }
      if (!mounted) return;
      if (_photos.length + images.length > 4) throw Exception('Attach up to 4 photos per message.');
      if (images.any((image) => image.isEmpty || image.length > 2 * 1024 * 1024)) {
        throw Exception('Each photo must be 2 MB or smaller.');
      }
      if ([..._photos, ...images].fold<int>(0, (sum, image) => sum + image.length) > 4 * 1024 * 1024) {
        throw Exception('Photos must total 4 MB or less.');
      }
      setState(() => _photos.addAll(images));
      widget.onChanged(List.of(_photos));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().startsWith('Exception: ')
          ? e.toString().substring(11)
          : 'Could not paste this image. Allow clipboard access or use Add photos.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_photos.isNotEmpty) SizedBox(height: 84, child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: _photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_photos[i],
            width: 84, height: 84, fit: BoxFit.cover, cacheWidth: 168,
            errorBuilder: (_, _, _) => const SizedBox(width: 84, child: Icon(Icons.broken_image)))),
          Positioned(right: 0, top: 0, child: IconButton.filledTonal(
            tooltip: 'Remove photo', icon: const Icon(Icons.close, size: 16),
            onPressed: !widget.enabled || _busy ? null : () {
              setState(() => _photos.removeAt(i)); widget.onChanged(List.of(_photos));
            })),
        ]),
      )),
      Wrap(spacing: 8, children: [
        TextButton.icon(onPressed: !widget.enabled || _busy ? null : () => _add(false),
          icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add photos')),
        TextButton.icon(onPressed: !widget.enabled || _busy ? null : () => _add(true),
          icon: const Icon(Icons.content_paste), label: const Text('Paste photo')),
        if (_busy) const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ]),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]),
  );
}

class SupportPhoto extends ConsumerStatefulWidget {
  const SupportPhoto({super.key, required this.id, required this.credentials});
  final int id;
  final PaystackCredentials credentials;
  @override
  ConsumerState<SupportPhoto> createState() => _SupportPhotoState();
}
class _SupportPhotoState extends ConsumerState<SupportPhoto> {
  late Future<Uint8List> _bytes;
  Future<Uint8List> _load() => ref.read(supportGatewayProvider).photo(
      baseUrl: widget.credentials.baseUrl, apiKey: widget.credentials.apiKey, id: widget.id);
  @override
  void initState() { super.initState(); _bytes = _load(); }
  @override
  void didUpdateWidget(covariant SupportPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.credentials.apiKey != widget.credentials.apiKey || oldWidget.credentials.baseUrl != widget.credentials.baseUrl) _bytes = _load();
  }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 8),
    child: FutureBuilder<Uint8List>(future: _bytes, builder: (context, snapshot) {
      if (snapshot.hasError) return TextButton.icon(onPressed: () => setState(() => _bytes = _load()),
        icon: const Icon(Icons.refresh), label: const Text('Retry photo'));
      final bytes = snapshot.data;
      if (bytes == null) return const SizedBox(height: 100, width: 160, child: Center(child: CircularProgressIndicator()));
      return InkWell(onTap: () => showDialog<void>(context: context, builder: (context) => Dialog(
        child: Stack(children: [
          InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
          Positioned(right: 4, top: 4, child: IconButton.filledTonal(tooltip: 'Close photo',
            onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))),
        ]))),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(bytes,
          height: 160, width: 240, fit: BoxFit.contain, cacheWidth: 480,
          errorBuilder: (_, _, _) => const Text('Photo could not be displayed.'))));
    }),
  );
}
