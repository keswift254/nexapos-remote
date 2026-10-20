import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../data/support/support_gateway.dart';
import '../../domain/entities/paystack_credentials.dart';

const _maxPhotos = 4;
const _maxPhotoBytes = 2 * 1024 * 1024;
const _maxTotalPhotoBytes = 4 * 1024 * 1024;

/// The photos attached to the message being written, shared by the "+" button,
/// Ctrl+V and the thumbnails. One controller per message box.
class SupportPhotoController extends ChangeNotifier {
  SupportPhotoController({Future<Uint8List?> Function()? clipboardImage})
    : _clipboardImage = clipboardImage ?? (() => Pasteboard.image);

  final Future<Uint8List?> Function() _clipboardImage;
  final _photos = <Uint8List>[];
  bool _busy = false;
  String? _error;

  /// A copy, so the caller can keep it while the controller is cleared.
  List<Uint8List> get photos => List.of(_photos);
  bool get isEmpty => _photos.isEmpty;
  bool get busy => _busy;
  String? get error => _error;

  void clear() {
    _photos.clear();
    _error = null;
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _photos.length) return;
    _photos.removeAt(index);
    _error = null;
    notifyListeners();
  }

  /// Opens the file chooser and attaches the chosen pictures.
  Future<void> pickFiles() async {
    if (_busy) return;
    _begin();
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (result.isEmpty) return;
      if (_photos.length + result.length > _maxPhotos) {
        throw const _PhotoProblem('Attach up to 4 photos per message.');
      }
      final lengths = await Future.wait(result.map((file) => file.length()));
      if (lengths.any((length) => length == 0 || length > _maxPhotoBytes)) {
        throw const _PhotoProblem('Each photo must be 2 MB or smaller.');
      }
      final images = await Future.wait(
        result.map((file) async {
          final buffer = BytesBuilder(copy: false);
          await for (final chunk in file.readAsByteStream()) {
            if (buffer.length + chunk.length > _maxPhotoBytes) {
              throw const _PhotoProblem('Each photo must be 2 MB or smaller.');
            }
            buffer.add(chunk);
          }
          return buffer.takeBytes();
        }),
      );
      _accept(images);
    } catch (e) {
      _fail(e, 'Could not add this photo.');
    } finally {
      _end();
    }
  }

  /// Attaches the picture on the clipboard, if there is one. Returns true when
  /// the clipboard held a picture (attached, or refused with a message) - the
  /// caller must then NOT also paste text. Returns false when there was no
  /// picture, or the clipboard could not be read, so ordinary text pasting goes on.
  Future<bool> pasteImage() async {
    if (_busy) return false;
    Uint8List? image;
    try {
      image = await _clipboardImage();
    } catch (_) {
      return false;
    }
    if (image == null) return false;
    _begin();
    try {
      _accept([image]);
    } catch (e) {
      _fail(e, 'Could not paste this picture.');
    } finally {
      _end();
    }
    return true;
  }

  /// A picture handed over by the keyboard (Android/iOS "paste image").
  void addFromKeyboard(Uint8List? bytes) {
    if (bytes == null || _busy) return;
    _begin();
    try {
      _accept([bytes]);
    } catch (e) {
      _fail(e, 'Could not add this picture.');
    } finally {
      _end();
    }
  }

  void _begin() {
    _busy = true;
    _error = null;
    notifyListeners();
  }

  void _end() {
    _busy = false;
    notifyListeners();
  }

  void _fail(Object error, String fallback) {
    _error = error is _PhotoProblem ? error.message : fallback;
  }

  void _accept(List<Uint8List> images) {
    if (_photos.length + images.length > _maxPhotos) {
      throw const _PhotoProblem('Attach up to 4 photos per message.');
    }
    if (images.any((i) => i.isEmpty || i.length > _maxPhotoBytes)) {
      throw const _PhotoProblem('Each photo must be 2 MB or smaller.');
    }
    final total = [
      ..._photos,
      ...images,
    ].fold<int>(0, (sum, image) => sum + image.length);
    if (total > _maxTotalPhotoBytes) {
      throw const _PhotoProblem('Photos must total 4 MB or less.');
    }
    _photos.addAll(images);
  }
}

class _PhotoProblem implements Exception {
  const _PhotoProblem(this.message);
  final String message;
}

/// The single "+" button that sits inside the message box and adds photos
/// from files. (Pictures on the clipboard go in with Ctrl+V, see
/// [SupportPasteImageShortcut].)
class SupportAttachButton extends StatelessWidget {
  const SupportAttachButton({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final SupportPhotoController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => IconButton(
      tooltip: 'Add photos (or copy a picture and press Ctrl+V)',
      onPressed: !enabled || controller.busy ? null : controller.pickFiles,
      icon: const Icon(Icons.add),
    ),
  );
}

class _PasteImageIntent extends Intent {
  const _PasteImageIntent();
}

/// Wraps a message box so that Ctrl+V (Cmd+V on a Mac) attaches a copied
/// picture, and - on phones - a picture inserted from the keyboard is attached
/// too. Anything that is not a picture pastes as text exactly as before.
class SupportPasteImageShortcut extends StatelessWidget {
  const SupportPasteImageShortcut({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
  });
  final SupportPhotoController controller;
  final Widget child;
  final bool enabled;

  Future<void> _paste() async {
    if (enabled && await controller.pasteImage()) return;
    // Not a picture: let the focused text field paste text the usual way.
    final focused = primaryFocus?.context;
    if (focused != null && focused.mounted) {
      Actions.maybeInvoke<PasteTextIntent>(
        focused,
        const PasteTextIntent(SelectionChangedCause.keyboard),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.keyV, control: true):
          _PasteImageIntent(),
      SingleActivator(LogicalKeyboardKey.keyV, meta: true): _PasteImageIntent(),
    },
    child: Actions(
      actions: {
        _PasteImageIntent: CallbackAction<_PasteImageIntent>(
          onInvoke: (_) {
            _paste();
            return null;
          },
        ),
      },
      child: child,
    ),
  );
}

/// What a text field needs so a picture inserted from a phone keyboard is attached.
ContentInsertionConfiguration supportContentInsertion(
  SupportPhotoController controller,
) => ContentInsertionConfiguration(
  allowedMimeTypes: const ['image/png', 'image/jpeg', 'image/webp'],
  onContentInserted: (content) => controller.addFromKeyboard(content.data),
);

/// The attached photos as thumbnails (each with a remove button), a spinner while
/// one is being added, and any problem in words. Shows nothing when idle.
class SupportPhotoStrip extends StatelessWidget {
  const SupportPhotoStrip({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final SupportPhotoController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final photos = controller.photos;
      final error = controller.error;
      if (photos.isEmpty && !controller.busy && error == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty || controller.busy)
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length + (controller.busy ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    if (i >= photos.length) {
                      return const SizedBox(
                        width: 84,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            photos[i],
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            cacheWidth: 168,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 84,
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton.filledTonal(
                            tooltip: 'Remove photo',
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: !enabled || controller.busy
                                ? null
                                : () => controller.removeAt(i),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      );
    },
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
  Future<Uint8List> _load() => ref
      .read(supportGatewayProvider)
      .photo(
        baseUrl: widget.credentials.baseUrl,
        apiKey: widget.credentials.apiKey,
        id: widget.id,
      );
  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  @override
  void didUpdateWidget(covariant SupportPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.credentials.apiKey != widget.credentials.apiKey ||
        oldWidget.credentials.baseUrl != widget.credentials.baseUrl) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton.icon(
            onPressed: () => setState(() => _bytes = _load()),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry photo'),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const SizedBox(
            height: 100,
            width: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Stack(
                children: [
                  InteractiveViewer(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton.filledTonal(
                      tooltip: 'Close photo',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              height: 160,
              width: 240,
              fit: BoxFit.contain,
              cacheWidth: 480,
              errorBuilder: (_, _, _) =>
                  const Text('Photo could not be displayed.'),
            ),
          ),
        );
      },
    ),
  );
}
