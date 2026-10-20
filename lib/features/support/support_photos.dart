import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../data/support/support_gateway.dart';
import '../../domain/entities/paystack_credentials.dart';
import 'support_photo_prepare.dart';

const _maxPhotos = 4;
const _maxTotalPhotoBytes = 4 * 1024 * 1024;

/// The most the app will read of a picture before it shrinks it (a 4K screenshot
/// copied from Windows is about 33 MB as a BMP).
const _maxSourceBytes = 64 * 1024 * 1024;

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
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
      );
      if (result.isEmpty) return;
      if (_photos.length + result.length > _maxPhotos) {
        throw const _PhotoProblem('Attach up to 4 photos per message.');
      }
      final lengths = await Future.wait(result.map((file) => file.length()));
      if (lengths.any((length) => length == 0 || length > _maxSourceBytes)) {
        throw const _PhotoProblem('That photo is too large to attach.');
      }
      final images = await Future.wait(
        result.map((file) async {
          final buffer = BytesBuilder(copy: false);
          await for (final chunk in file.readAsByteStream()) {
            if (buffer.length + chunk.length > _maxSourceBytes) {
              throw const _PhotoProblem('That photo is too large to attach.');
            }
            buffer.add(chunk);
          }
          return buffer.takeBytes();
        }),
      );
      await _accept(images);
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
    // A picture is still being prepared: swallow the key press rather than
    // pasting text over the top of it.
    if (_busy) return true;
    Uint8List? image;
    try {
      image = await _clipboardImage();
    } catch (_) {
      return false;
    }
    if (image == null) return false;
    _begin();
    try {
      await _accept([image]);
    } catch (e) {
      _fail(e, 'Could not paste this picture.');
    } finally {
      _end();
    }
    return true;
  }

  /// A picture handed over by the keyboard (Android/iOS "paste image").
  Future<void> addFromKeyboard(Uint8List? bytes) async {
    if (bytes == null || _busy) return;
    _begin();
    try {
      await _accept([bytes]);
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

  /// Turns each picture into something the server takes (PNG/JPEG/WebP, 2 MB,
  /// 16 megapixels - a Windows screenshot arrives as a BMP, which it refuses),
  /// then adds them all, or none.
  Future<void> _accept(List<Uint8List> sources) async {
    if (_photos.length + sources.length > _maxPhotos) {
      throw const _PhotoProblem('Attach up to 4 photos per message.');
    }
    if (sources.any((i) => i.length > _maxSourceBytes)) {
      throw const _PhotoProblem('That photo is too large to attach.');
    }
    final List<Uint8List> images;
    try {
      images = await Future.wait(sources.map(prepareSupportPhoto));
    } on SupportPhotoUnreadable {
      throw const _PhotoProblem(
        'This picture could not be read. Try a PNG or JPEG photo.',
      );
    } on SupportPhotoTooLarge {
      throw const _PhotoProblem(
        'This picture is too large to send, even when made smaller.',
      );
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

/// A thumbnail's square, plus room for the remove badge that sits on its corner.
const _thumbnailSize = 84.0;
const _thumbnailSlot = 92.0;
const _removeTarget = 36.0;

/// Shows [bytes] full size in a dialog, zoomable, with a close button.
Future<void> showSupportPhotoPreview(
  BuildContext context,
  Uint8List bytes,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    // Never smaller than its own close button, however small the picture is.
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, minHeight: 160),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
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
);

/// One photo waiting to be sent: tap it to see it full size, tap the round X on
/// its top-right corner to take it off the message.
class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.bytes, required this.onRemove});
  final Uint8List bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _thumbnailSlot,
      height: _thumbnailSlot,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Tooltip(
              message: 'Tap to preview',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showSupportPhotoPreview(context, bytes),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    width: _thumbnailSize,
                    height: _thumbnailSize,
                    fit: BoxFit.cover,
                    cacheWidth: 168,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: _thumbnailSize,
                      height: _thumbnailSize,
                      child: Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // A generous touch area around a small round badge, kept inside the
          // slot so the whole of it can be tapped.
          Positioned(
            right: 0,
            top: 0,
            child: Tooltip(
              message: 'Remove photo',
              child: InkResponse(
                onTap: onRemove,
                radius: _removeTarget / 2,
                child: SizedBox(
                  width: _removeTarget,
                  height: _removeTarget,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: onRemove == null
                            ? scheme.outline
                            : scheme.inverseSurface,
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The attached photos as thumbnails (tap to preview, a round X to remove), a
/// spinner while one is being added, and any problem in words. Shows nothing
/// when idle.
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
                height: _thumbnailSlot,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length + (controller.busy ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, i) {
                    if (i >= photos.length) {
                      return const SizedBox(
                        width: _thumbnailSlot,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    return _PhotoThumbnail(
                      bytes: photos[i],
                      onRemove: !enabled || controller.busy
                          ? null
                          : () => controller.removeAt(i),
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
          onTap: () => showSupportPhotoPreview(context, bytes),
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
