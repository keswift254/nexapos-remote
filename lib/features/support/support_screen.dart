import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/payments/paystack_gateway.dart' show PaystackException;
import '../../data/payments/platform_http_client.dart'
    show PaystackOfflineException;
import '../../data/support/support_gateway.dart';
import '../../data/repositories/business_settings_repository_impl.dart';
import '../../domain/entities/paystack_credentials.dart';
import 'support_chat.dart';
import 'support_photos.dart';
import 'support_sound.dart';
import '../../domain/services/paystack_credentials_service.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key, this.initialTicketId});

  final int? initialTicketId;

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  bool _loading = true;
  String? _error;
  List<SupportTicket> _tickets = const [];
  PaystackCredentials? _credentials;
  bool _openedInitialTicket = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _error = null;
      });
    }
    try {
      final credentials = await ref
          .read(paystackCredentialsServiceProvider)
          .load();
      if (!credentials.isConfigured) {
        throw const PaystackException(
          'This device is not connected to the shop sync service yet. '
          'Open Settings > Sync & Invites while online, then try again.',
        );
      }
      final cached = ref
          .read(supportGatewayProvider)
          .cachedList(credentials.baseUrl, credentials.apiKey);
      if (mounted) {
        setState(() {
          _credentials = credentials;
          if (cached != null) {
            _tickets = cached;
            _loading = false;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _openInitialTicketIfAvailable(),
            );
          }
        });
      }
      final tickets = await ref
          .read(supportGatewayProvider)
          .list(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey);
      if (!mounted) return;
      setState(() {
        _credentials = credentials;
        _tickets = tickets;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openInitialTicketIfAvailable(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is PaystackException
            ? e.message
            : e is PaystackOfflineException
            ? e.timedOut
                  ? 'The support server did not answer in time. Try again.'
                  : 'Could not connect to the support server. Check your connection and try again.'
            : 'Could not read the support response. Try again or contact NexaPOS support.';
      });
    }
  }

  Future<void> _openInitialTicketIfAvailable() async {
    final ticketId = widget.initialTicketId;
    if (_openedInitialTicket || ticketId == null || !mounted) return;

    SupportTicket? target;
    for (final ticket in _tickets) {
      if (ticket.id == ticketId) {
        target = ticket;
        break;
      }
    }
    if (target == null) return;

    _openedInitialTicket = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportThreadScreen(ticket: target!),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _newTicket() async {
    final credentials = _credentials;
    if (credentials == null) return;
    final draft = await showDialog<_TicketDraft>(
      context: context,
      builder: (_) => const _NewTicketDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      final id = await ref
          .read(supportGatewayProvider)
          .open(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
            subject: draft.subject,
            message: draft.message,
            email: draft.email,
            photos: draft.photos,
          );
      if (!mounted) return;
      final opened = SupportTicket(
        id: id,
        subject: draft.subject,
        status: 'open',
        createdAt: '',
        updatedAt: '',
        customerEmail: draft.email,
      );
      setState(
        () =>
            _tickets = [opened, ..._tickets.where((ticket) => ticket.id != id)],
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SupportThreadScreen(ticket: opened),
        ),
      );
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is PaystackException ? e.message : 'Could not open the ticket.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Support'),
      actions: [
        IconButton(
          tooltip: 'Refresh tickets',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: _credentials == null || _loading
        ? null
        : FloatingActionButton.extended(
            onPressed: _newTicket,
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('New ticket'),
          ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.support_agent, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        : _tickets.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.support_agent, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    'Need help?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Open a support ticket and describe the issue. '
                    'Your shop can return here to follow the conversation.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _newTicket,
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Open a ticket'),
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: _tickets.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final replies = _tickets
                      .where((t) => t.status == 'pending')
                      .length;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your conversations',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          replies == 0
                              ? 'Follow your requests and messages from NexaPOS Support.'
                              : '${replies == 1 ? '1 reply' : '$replies replies'} waiting for your shop.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }
                final ticket = _tickets[index - 1];
                final scheme = Theme.of(context).colorScheme;
                final hasReply = ticket.status == 'pending';
                return Card(
                  color: hasReply ? scheme.secondaryContainer : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: hasReply
                          ? scheme.secondary
                          : scheme.surfaceContainerHighest,
                      foregroundColor: hasReply
                          ? scheme.onSecondary
                          : scheme.onSurface,
                      child: Icon(
                        hasReply
                            ? Icons.mark_chat_unread_outlined
                            : ticket.status == 'closed'
                            ? Icons.task_alt
                            : Icons.support_agent_outlined,
                      ),
                    ),
                    title: Text(
                      ticket.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: hasReply
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '#${ticket.id}  •  ${_ticketStatusLabel(ticket.status)}'
                        '${ticket.updatedAt.isEmpty ? '' : '  •  ${ticket.updatedAt}'}',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SupportThreadScreen(ticket: ticket),
                        ),
                      );
                      await _load();
                    },
                  ),
                );
              },
            ),
          ),
  );
}

class _TicketDraft {
  const _TicketDraft(this.subject, this.message, this.email, this.photos);
  final String subject;
  final String message;
  final String? email;
  final List<Uint8List> photos;
}

String _ticketStatusLabel(String status) => switch (status) {
  'pending' => 'Reply from support',
  'closed' => 'Closed',
  _ => 'Waiting for support',
};

class _NewTicketDialog extends StatefulWidget {
  const _NewTicketDialog();
  @override
  State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _email = TextEditingController();
  String? _emailError;
  final _photos = SupportPhotoController();

  @override
  void dispose() {
    _photos.dispose();
    _subject.dispose();
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    final email = _email.text.trim();
    if (subject.length < 3 || (message.isEmpty && _photos.isEmpty)) return;
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address.');
      return;
    }
    Navigator.pop(
      context,
      _TicketDraft(
        subject,
        message,
        email.isEmpty ? null : email,
        _photos.photos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Open support ticket'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tell us what happened. Your shop can follow this conversation in NexaPOS.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _subject,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'What do you need help with?',
              ),
            ),
            const SizedBox(height: 8),
            SupportPasteImageShortcut(
              controller: _photos,
              child: TextField(
                controller: _message,
                maxLength: 8000,
                minLines: 4,
                maxLines: 8,
                contentInsertionConfiguration: supportContentInsertion(_photos),
                decoration: InputDecoration(
                  labelText: 'Describe the issue',
                  alignLabelWithHint: true,
                  prefixIcon: Align(
                    widthFactor: 1,
                    heightFactor: 1,
                    alignment: Alignment.topCenter,
                    child: SupportAttachButton(controller: _photos),
                  ),
                ),
              ),
            ),
            SupportPhotoStrip(controller: _photos),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              maxLength: 254,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
              decoration: InputDecoration(
                labelText: 'Email for ticket updates (optional)',
                hintText: 'you@example.com',
                helperText: 'We can email you when support replies.',
                errorText: _emailError,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Send ticket')),
    ],
  );
}

class SupportThreadScreen extends ConsumerStatefulWidget {
  const SupportThreadScreen({super.key, required this.ticket});
  final SupportTicket ticket;
  @override
  ConsumerState<SupportThreadScreen> createState() =>
      _SupportThreadScreenState();
}

/// What the shop typed, kept so a message that could not be delivered can be tried again.
class _Draft {
  const _Draft(this.message, this.photos, this.replyTo);
  final String message;
  final List<Uint8List> photos;
  final SupportMessage? replyTo;
}

class _SupportThreadScreenState extends ConsumerState<SupportThreadScreen>
    with WidgetsBindingObserver {
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();
  final _scroll = ScrollController();
  SupportThread? _thread;
  PaystackCredentials? _credentials;
  bool _loading = true;
  bool _sending = false;
  bool _closing = false;
  final _photos = SupportPhotoController();
  String? _error;
  String? _shopName;
  SupportMessage? _replyingTo;
  SupportPendingMessage? _pending;
  _Draft? _failedDraft;
  Timer? _refreshTimer;
  int _readThrough = 0;
  bool _markingRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _loadShopName();
    // New replies and reactions from support show up without having to leave and come back.
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_sending && _credentials != null) _load(quiet: true);
    });
  }

  Future<void> _loadShopName() async {
    try {
      final settings = await ref.read(businessSettingsRepositoryProvider).get();
      if (mounted) setState(() => _shopName = settings.businessName.trim());
    } catch (_) {
      // A local settings error must not prevent the ticket from loading.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _photos.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _credentials != null) {
      _load(quiet: true);
    }
  }

  void _markVisibleRepliesRead(
    SupportThread thread,
    PaystackCredentials credentials,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          _markingRead ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      var through = 0;
      for (final message in thread.messages) {
        if (message.sender == 'support' && message.id > through) {
          through = message.id;
        }
      }
      if (through <= _readThrough) return;
      _markingRead = true;
      try {
        await ref
            .read(supportGatewayProvider)
            .markRead(
              baseUrl: credentials.baseUrl,
              apiKey: credentials.apiKey,
              ticketId: widget.ticket.id,
              throughMessageId: through,
            );
        _readThrough = through;
      } catch (_) {
        // A transient failure is retried on the next visible refresh.
      } finally {
        _markingRead = false;
      }
    });
  }

  bool get _nearBottom =>
      !_scroll.hasClients ||
      _scroll.position.maxScrollExtent - _scroll.position.pixels < 120;

  /// A long conversation only knows its real length once the messages near the end have been
  /// built, so the first jump may fall short: jump again on the next two frames.
  void _scrollToEnd() {
    var passes = 0;
    void jump(Duration _) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      if (++passes < 3) WidgetsBinding.instance.addPostFrameCallback(jump);
    }

    WidgetsBinding.instance.addPostFrameCallback(jump);
  }

  /// [quiet]: a background refresh - it never replaces what is on screen with an error.
  Future<void> _load({bool quiet = false}) async {
    try {
      final credentials = await ref
          .read(paystackCredentialsServiceProvider)
          .load();
      final cached = ref
          .read(supportGatewayProvider)
          .cachedThread(
            credentials.baseUrl,
            credentials.apiKey,
            widget.ticket.id,
          );
      if (cached != null && mounted && _thread == null) {
        setState(() {
          _thread = cached;
          _credentials = credentials;
          _loading = false;
        });
        _scrollToEnd();
      }
      final thread = await ref
          .read(supportGatewayProvider)
          .thread(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
            ticketId: widget.ticket.id,
          );
      if (!mounted) return;
      final stay = _thread == null || _nearBottom;
      final grew =
          _thread == null || thread.messages.length > _thread!.messages.length;
      setState(() {
        _credentials = credentials;
        _thread = thread;
        _loading = false;
        _error = null;
      });
      if (stay && grew) _scrollToEnd();
      _markVisibleRepliesRead(thread, credentials);
    } catch (e) {
      if (!mounted) return;
      if (quiet && _thread != null) return;
      setState(() {
        _loading = false;
        _error = e is PaystackException
            ? e.message
            : 'Could not load this ticket.';
      });
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _send() {
    final message = _reply.text.trim();
    if (_credentials == null ||
        (message.isEmpty && _photos.isEmpty) ||
        _sending ||
        _closing) {
      return;
    }
    final draft = _Draft(message, _photos.photos, _replyingTo);
    _reply.clear();
    _photos.clear();
    // Browsers only permit audible playback from a user gesture. The reply
    // request completes too late to retain that gesture; native platforms
    // still play on acknowledgement below.
    if (kIsWeb) unawaited(ref.read(supportSoundProvider).playSent());
    _deliver(draft);
  }

  /// Shows the message at once as "Sending…", then as delivered (with the send sound) once
  /// the server has it, or as "Not delivered" to tap and try again.
  Future<void> _deliver(_Draft draft) async {
    final credentials = _credentials;
    if (credentials == null) return;
    setState(() {
      _sending = true;
      _failedDraft = null;
      _replyingTo = null;
      _pending = SupportPendingMessage(
        body: draft.message,
        photoCount: draft.photos.length,
      );
    });
    _scrollToEnd();
    try {
      await ref
          .read(supportGatewayProvider)
          .reply(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
            ticketId: widget.ticket.id,
            message: draft.message,
            photos: draft.photos,
            replyToId: draft.replyTo?.id,
          );
      if (!mounted) return;
      if (!kIsWeb) unawaited(ref.read(supportSoundProvider).playSent());
      await _load(quiet: true);
      if (!mounted) return;
      setState(() => _pending = null);
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failedDraft = draft;
        _pending = SupportPendingMessage(
          body: draft.message,
          photoCount: draft.photos.length,
          failed: true,
        );
      });
      _toast(
        e is PaystackException ? e.message : 'Could not send the message.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _retry() {
    final draft = _failedDraft;
    if (draft != null && !_sending) {
      if (kIsWeb) unawaited(ref.read(supportSoundProvider).playSent());
      _deliver(draft);
    }
  }

  void _startReply(SupportMessage message) {
    setState(() => _replyingTo = message);
    _replyFocus.requestFocus();
  }

  Future<void> _copy(SupportMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.body));
    if (mounted) _toast('Copied');
  }

  /// Shows the reaction at once; puts things back if the server does not take it.
  Future<void> _react(SupportMessage message, String? emoji) async {
    final credentials = _credentials;
    final before = _thread;
    if (credentials == null || before == null) return;
    setState(
      () => _thread = SupportThread(
        ticket: before.ticket,
        messages: [
          for (final m in before.messages)
            m.id == message.id ? m.withMyReaction(emoji) : m,
        ],
      ),
    );
    try {
      await ref
          .read(supportGatewayProvider)
          .react(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
            ticketId: widget.ticket.id,
            messageId: message.id,
            emoji: emoji,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _thread = before);
      _toast(
        e is PaystackException ? e.message : 'Could not save your reaction.',
      );
    }
  }

  Future<void> _close() async {
    final credentials = _credentials;
    if (credentials == null || _closing || _sending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this ticket?'),
        content: const Text(
          'You can reopen it later by sending another reply.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close ticket'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _closing = true);
    try {
      await ref
          .read(supportGatewayProvider)
          .close(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
            ticketId: widget.ticket.id,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(
        e is PaystackException ? e.message : 'Could not close the ticket.',
      );
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Widget _header(SupportThread thread) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        thread.ticket.subject,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Chip(
        avatar: Icon(
          thread.ticket.status == 'pending'
              ? Icons.mark_chat_unread_outlined
              : thread.ticket.status == 'closed'
              ? Icons.task_alt
              : Icons.schedule_outlined,
          size: 18,
        ),
        label: Text(_ticketStatusLabel(thread.ticket.status)),
      ),
      if (thread.ticket.customerEmail?.isNotEmpty == true)
        Text(
          'Email updates: ${thread.ticket.customerEmail}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final thread = _thread;
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket #${widget.ticket.id}'),
        actions: [
          if (thread != null && thread.ticket.status != 'closed')
            TextButton.icon(
              onPressed: _closing || _sending ? null : _close,
              icon: const Icon(Icons.task_alt),
              label: const Text('Close'),
            ),
          IconButton(
            tooltip: 'Refresh conversation',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                Expanded(
                  child: SupportConversation(
                    controller: _scroll,
                    header: _header(thread!),
                    messages: thread.messages,
                    credentials: _credentials!,
                    shopName: _shopName ?? '',
                    pending: _pending,
                    onRetryPending: _retry,
                    onReply: _startReply,
                    onReact: _react,
                    onCopy: _copy,
                  ),
                ),
                if (_replyingTo != null)
                  SupportReplyPreview(
                    message: _replyingTo!,
                    shopName: _shopName ?? '',
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                SupportPhotoStrip(
                  controller: _photos,
                  enabled: !_sending && !_closing,
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: SupportPasteImageShortcut(
                            controller: _photos,
                            enabled: !_sending && !_closing,
                            child: TextField(
                              controller: _reply,
                              focusNode: _replyFocus,
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 8000,
                              contentInsertionConfiguration:
                                  supportContentInsertion(_photos),
                              decoration: InputDecoration(
                                hintText: thread.ticket.status == 'closed'
                                    ? 'Reply to reopen this ticket…'
                                    : 'Reply to this ticket…',
                                border: const OutlineInputBorder(),
                                prefixIcon: SupportAttachButton(
                                  controller: _photos,
                                  enabled: !_sending && !_closing,
                                ),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send',
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
