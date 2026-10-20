import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/support/support_gateway.dart';
import '../../domain/entities/paystack_credentials.dart';
import 'support_photos.dart';

/// rgb(0, 120, 254): the colour of the shop's own messages.
const supportBlue = Color.fromRGBO(0, 120, 254, 1);

/// What a message can be reacted with (like iMessage's tapbacks). The server only accepts these.
const supportReactionChoices = [
  '❤️',
  '\u{1F44D}',
  '\u{1F44E}',
  '\u{1F602}',
  '‼️',
  '❓',
];

/// How far the conversation slides to show each message's time, in logical pixels.
const _revealWidth = 64.0;

/// The server's timestamps ("2026-10-06 13:00:21") are UTC; this is the device's local time.
DateTime? parseSupportTime(String createdAt) {
  final text = createdAt.trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(
    text.contains('T') ? text : '${text.replaceFirst(' ', 'T')}Z',
  );
  return parsed?.toLocal();
}

/// "Today", "Yesterday", or "Tue 6 Oct" - the little heading above each day's messages.
String supportDayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(day.year, day.month, day.day);
  final difference = today.difference(that).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return DateFormat('EEE d MMM').format(day);
}

/// A message that has been typed but that the server has not confirmed yet.
class SupportPendingMessage {
  const SupportPendingMessage({
    required this.body,
    required this.photoCount,
    this.failed = false,
  });
  final String body;
  final int photoCount;
  final bool failed;
}

/// What the person chose from a message's menu.
sealed class SupportMenuChoice {
  const SupportMenuChoice();
}

/// A reaction to set ([emoji]) or, when null, the shop's reaction to take off.
class SupportReactChoice extends SupportMenuChoice {
  const SupportReactChoice(this.emoji);
  final String? emoji;
}

class SupportReplyChoice extends SupportMenuChoice {
  const SupportReplyChoice();
}

class SupportCopyChoice extends SupportMenuChoice {
  const SupportCopyChoice();
}

/// The conversation of one ticket: the shop's messages in blue on the right, support's in grey
/// on the left. Double-tap (or long-press) a message for reactions, Reply and Copy; drag the
/// conversation sideways to see when each message was sent; "Delivered" sits under the last
/// message the shop sent.
class SupportConversation extends StatefulWidget {
  const SupportConversation({
    super.key,
    required this.header,
    required this.messages,
    required this.credentials,
    required this.shopName,
    required this.onReply,
    required this.onReact,
    required this.onCopy,
    this.pending,
    this.onRetryPending,
    this.controller,
    this.now = DateTime.now,
  });

  /// Subject, status and so on, shown above the first message.
  final Widget header;
  final List<SupportMessage> messages;
  final PaystackCredentials credentials;
  final String shopName;
  final SupportPendingMessage? pending;
  final VoidCallback? onRetryPending;
  final void Function(SupportMessage message) onReply;

  /// [emoji] null removes the shop's reaction.
  final void Function(SupportMessage message, String? emoji) onReact;
  final void Function(SupportMessage message) onCopy;
  final ScrollController? controller;
  final DateTime Function() now;

  @override
  State<SupportConversation> createState() => _SupportConversationState();
}

class _SupportConversationState extends State<SupportConversation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  final _keys = <int, GlobalKey>{};
  ScrollController? _ownController;
  Timer? _wheelRelease;
  int? _flash;

  ScrollController get _scroll =>
      widget.controller ?? (_ownController ??= ScrollController());

  @override
  void dispose() {
    _wheelRelease?.cancel();
    _ownController?.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _drag(double dx) =>
      _reveal.value = (_reveal.value - dx / _revealWidth).clamp(0.0, 1.0);

  void _release() => _reveal.animateTo(0, curve: Curves.easeOut);

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dx.abs() < event.scrollDelta.dy.abs()) {
      return;
    }
    _drag(-event.scrollDelta.dx);
    _wheelRelease?.cancel();
    _wheelRelease = Timer(const Duration(milliseconds: 700), _release);
  }

  Future<void> _jumpTo(int messageId) async {
    // A long conversation only builds the messages near the screen. A quote always points at an
    // earlier message, so scroll up a screenful at a time until the one it quotes exists.
    for (var step = 0; _keys[messageId]?.currentContext == null; step++) {
      final controller = _scroll;
      if (!controller.hasClients || controller.offset <= 0 || step > 400) {
        return;
      }
      controller.jumpTo(
        (controller.offset - controller.position.viewportDimension * 0.8).clamp(
          0.0,
          controller.position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final target = _keys[messageId]?.currentContext;
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0.3,
      duration: const Duration(milliseconds: 250),
    );
    if (!mounted) return;
    setState(() => _flash = messageId);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _flash = null);
  }

  Future<void> _menu(SupportMessage message, BuildContext bubbleContext) async {
    final box = bubbleContext.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final choice = await showSupportMessageMenu(
      context,
      anchor: anchor,
      alignEnd: message.sender != 'support',
      chosenEmoji: message.myReaction?.emoji,
      canCopy: message.body.isNotEmpty,
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case SupportReactChoice(:final emoji):
        widget.onReact(message, emoji);
      case SupportReplyChoice():
        widget.onReply(message);
      case SupportCopyChoice():
        widget.onCopy(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now();
    final rows = <Widget>[];
    DateTime? previousDay;
    for (var i = 0; i < widget.messages.length; i++) {
      final message = widget.messages[i];
      final sent = parseSupportTime(message.createdAt);
      if (sent != null &&
          (previousDay == null || DateUtils.dateOnly(sent) != previousDay)) {
        previousDay = DateUtils.dateOnly(sent);
        rows.add(
          _Slide(
            reveal: _reveal,
            child: _DayHeading(label: supportDayLabel(sent, now)),
          ),
        );
      }
      final last = i == widget.messages.length - 1 && widget.pending == null;
      rows.add(
        _Slide(
          reveal: _reveal,
          timeLabel: sent == null ? null : DateFormat.jm().format(sent),
          child: _MessageRow(
            key: _keys.putIfAbsent(message.id, GlobalKey.new),
            message: message,
            shopName: widget.shopName,
            credentials: widget.credentials,
            highlighted: _flash == message.id,
            status: last && message.sender != 'support'
                ? const _Status('Delivered')
                : null,
            onMenu: (bubbleContext) => _menu(message, bubbleContext),
            onQuoteTap: message.replyTo == null
                ? null
                : () => _jumpTo(message.replyTo!.id),
            onReactionTap: (emoji) => widget.onReact(message, emoji),
          ),
        ),
      );
    }
    final pending = widget.pending;
    if (pending != null) {
      rows.add(
        _Slide(
          reveal: _reveal,
          child: _PendingRow(
            pending: pending,
            shopName: widget.shopName,
            onRetry: widget.onRetryPending,
          ),
        ),
      );
    }

    return Listener(
      onPointerSignal: _wheel,
      onPointerPanZoomUpdate: (event) => _drag(event.panDelta.dx),
      onPointerPanZoomEnd: (_) => _release(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Count the finger's whole movement, not only what comes after the touch slop, so the
        // conversation follows it from the first pixel.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragUpdate: (details) => _drag(details.delta.dx),
        onHorizontalDragEnd: (_) => _release(),
        onHorizontalDragCancel: _release,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
          children: [
            _Slide(
              reveal: _reveal,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: widget.header,
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}

/// A row that slides left with the drag. Its [timeLabel] waits just beyond the right edge and
/// comes into view as the row moves.
class _Slide extends StatelessWidget {
  const _Slide({required this.reveal, required this.child, this.timeLabel});
  final Animation<double> reveal;
  final Widget child;
  final String? timeLabel;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: reveal,
    builder: (context, child) => Transform.translate(
      offset: Offset(-reveal.value * _revealWidth, 0),
      child: child,
    ),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (timeLabel != null)
          Positioned(
            right: -_revealWidth,
            top: 0,
            bottom: 0,
            width: _revealWidth - 8,
            child: AnimatedBuilder(
              animation: reveal,
              builder: (context, child) =>
                  Opacity(opacity: reveal.value, child: child),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  timeLabel!,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _Status {
  const _Status(this.text);
  final String text;
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    super.key,
    required this.message,
    required this.shopName,
    required this.credentials,
    required this.highlighted,
    required this.status,
    required this.onMenu,
    required this.onQuoteTap,
    required this.onReactionTap,
  });

  final SupportMessage message;
  final String shopName;
  final PaystackCredentials credentials;
  final bool highlighted;
  final _Status? status;
  final void Function(BuildContext bubbleContext) onMenu;
  final VoidCallback? onQuoteTap;
  final void Function(String? emoji) onReactionTap;

  @override
  Widget build(BuildContext context) {
    final mine = message.sender != 'support';
    final scheme = Theme.of(context).colorScheme;
    final maxWidth = (MediaQuery.sizeOf(context).width * 0.78).clamp(
      0.0,
      520.0,
    );
    final mineReaction = message.myReaction;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (bubbleContext) => GestureDetector(
                  onDoubleTap: () => onMenu(bubbleContext),
                  onLongPress: () => onMenu(bubbleContext),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: mine
                          ? supportBlue
                          : scheme.surfaceContainerHighest,
                      borderRadius: _bubbleShape(mine),
                      border: highlighted
                          ? Border.all(color: supportBlue, width: 2)
                          : null,
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.replyTo != null)
                          _QuoteBlock(
                            quote: message.replyTo!,
                            mine: mine,
                            shopName: shopName,
                            onTap: onQuoteTap,
                          ),
                        Text(
                          mine
                              ? (shopName.isNotEmpty ? shopName : 'Your shop')
                              : 'NexaPOS Support',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: mine
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : scheme.onSurfaceVariant,
                              ),
                        ),
                        if (message.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            message.body,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: mine ? Colors.white : scheme.onSurface,
                                ),
                          ),
                        ],
                        for (final id in message.attachments)
                          SupportPhoto(
                            id: id,
                            credentials: credentials,
                            onDoubleTap: () => onMenu(bubbleContext),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (message.reactions.isNotEmpty)
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: _ReactionChips(
                    reactions: message.reactions,
                    // Tapping the shop's own reaction takes it off; tapping the other side's copies it.
                    onTap: (reaction) => onReactionTap(
                      reaction.sender == 'customer' ? null : reaction.emoji,
                    ),
                    mineEmoji: mineReaction?.emoji,
                  ),
                ),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4),
                  child: Text(
                    status!.text,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

BorderRadius _bubbleShape(bool mine) => BorderRadius.only(
  topLeft: const Radius.circular(18),
  topRight: const Radius.circular(18),
  bottomLeft: Radius.circular(mine ? 18 : 4),
  bottomRight: Radius.circular(mine ? 4 : 18),
);

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({
    required this.quote,
    required this.mine,
    required this.shopName,
    required this.onTap,
  });
  final SupportQuote quote;
  final bool mine;
  final String shopName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = mine ? Colors.white : scheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: (mine ? Colors.white : scheme.onSurface).withValues(
            alpha: 0.14,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: mine ? Colors.white70 : supportBlue,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              quote.sender == 'support'
                  ? 'NexaPOS Support'
                  : (shopName.isNotEmpty ? shopName : 'Your shop'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor.withValues(alpha: 0.85),
              ),
            ),
            Text(
              quote.snippet.isEmpty ? 'Photo' : quote.snippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: textColor.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionChips extends StatelessWidget {
  const _ReactionChips({
    required this.reactions,
    required this.onTap,
    required this.mineEmoji,
  });
  final List<SupportReaction> reactions;
  final void Function(SupportReaction reaction) onTap;
  final String? mineEmoji;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 4,
        children: [
          for (final reaction in reactions)
            GestureDetector(
              onTap: () => onTap(reaction),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: reaction.sender == 'customer'
                      ? Color.alphaBlend(
                          supportBlue.withValues(alpha: 0.16),
                          scheme.surface,
                        )
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: reaction.sender == 'customer'
                        ? supportBlue
                        : scheme.outlineVariant,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  reaction.emoji,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The shop's message while it is on its way: dimmed, with "Sending…" under it, or - if it
/// could not be sent - "Not delivered. Tap to try again".
class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.pending,
    required this.shopName,
    required this.onRetry,
  });
  final SupportPendingMessage pending;
  final String shopName;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxWidth = (MediaQuery.sizeOf(context).width * 0.78).clamp(
      0.0,
      520.0,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: GestureDetector(
            onTap: pending.failed ? onRetry : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Opacity(
                  opacity: pending.failed ? 1 : 0.65,
                  child: Container(
                    decoration: BoxDecoration(
                      color: pending.failed ? scheme.error : supportBlue,
                      borderRadius: _bubbleShape(true),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pending.body.isNotEmpty)
                          Text(
                            pending.body,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.white),
                          ),
                        if (pending.photoCount > 0)
                          Text(
                            pending.photoCount == 1
                                ? '1 photo'
                                : '${pending.photoCount} photos',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4),
                  child: Text(
                    pending.failed
                        ? 'Not delivered. Tap to try again'
                        : 'Sending…',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: pending.failed
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The menu that opens on a message: six emoji along the top, then Reply and Copy. [anchor] is
/// the message's rectangle on screen; [chosenEmoji] is the one the shop already left (tapping it
/// takes it off again).
Future<SupportMenuChoice?> showSupportMessageMenu(
  BuildContext context, {
  required Rect anchor,
  required bool alignEnd,
  required String? chosenEmoji,
  required bool canCopy,
}) => showGeneralDialog<SupportMenuChoice>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close menu',
  barrierColor: Colors.black38,
  transitionDuration: const Duration(milliseconds: 140),
  transitionBuilder: (context, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
  pageBuilder: (dialogContext, _, _) => _SupportMessageMenu(
    anchor: anchor,
    alignEnd: alignEnd,
    chosenEmoji: chosenEmoji,
    canCopy: canCopy,
  ),
);

class _SupportMessageMenu extends StatelessWidget {
  const _SupportMessageMenu({
    required this.anchor,
    required this.alignEnd,
    required this.chosenEmoji,
    required this.canCopy,
  });
  final Rect anchor;
  final bool alignEnd;
  final String? chosenEmoji;
  final bool canCopy;

  static const _pillHeight = 52.0;
  static const _actionsHeight = 104.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final pillWidth = (supportReactionChoices.length * 44.0 + 16).clamp(
      0.0,
      size.width - 16,
    );
    double leftFor(double width) => alignEnd
        ? (anchor.right - width).clamp(8.0, size.width - width - 8)
        : anchor.left.clamp(8.0, size.width - width - 8);
    final pillTop = (anchor.top - _pillHeight - 8).clamp(
      media.padding.top + 8,
      size.height - media.padding.bottom - _pillHeight - 8,
    );
    final actionsTop = (anchor.bottom + 8).clamp(
      media.padding.top + 8,
      size.height - media.padding.bottom - _actionsHeight - 8,
    );
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          top: pillTop,
          left: leftFor(pillWidth),
          width: pillWidth,
          height: _pillHeight,
          child: Material(
            elevation: 6,
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji in supportReactionChoices)
                  InkResponse(
                    key: ValueKey('react-$emoji'),
                    radius: 22,
                    onTap: () => Navigator.pop(
                      context,
                      SupportReactChoice(emoji == chosenEmoji ? null : emoji),
                    ),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: emoji == chosenEmoji
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              color: supportBlue.withValues(alpha: 0.2),
                            )
                          : null,
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          top: actionsTop,
          left: leftFor(200),
          width: 200,
          child: Material(
            elevation: 6,
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const ValueKey('menu-reply'),
                  dense: true,
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  onTap: () =>
                      Navigator.pop(context, const SupportReplyChoice()),
                ),
                ListTile(
                  key: const ValueKey('menu-copy'),
                  dense: true,
                  enabled: canCopy,
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy text'),
                  onTap: () =>
                      Navigator.pop(context, const SupportCopyChoice()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Replying to …" above the message box, with a cross to cancel.
class SupportReplyPreview extends StatelessWidget {
  const SupportReplyPreview({
    super.key,
    required this.message,
    required this.shopName,
    required this.onCancel,
  });
  final SupportMessage message;
  final String shopName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snippet = message.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: supportBlue, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${message.sender == 'support' ? 'NexaPOS Support' : (shopName.isNotEmpty ? shopName : 'yourself')}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: supportBlue,
                  ),
                ),
                Text(
                  snippet.isEmpty ? 'Photo' : snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}
