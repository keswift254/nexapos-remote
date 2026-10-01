import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/payments/paystack_gateway.dart' show PaystackException;
import '../../data/payments/platform_http_client.dart' show PaystackOfflineException;
import '../../data/support/support_gateway.dart';
import '../../domain/entities/paystack_credentials.dart';
import '../../domain/services/paystack_credentials_service.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  bool _loading = true;
  String? _error;
  List<SupportTicket> _tickets = const [];
  PaystackCredentials? _credentials;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final credentials =
          await ref.read(paystackCredentialsServiceProvider).load();
      if (!credentials.isConfigured) {
        throw const PaystackException(
          'This device is not connected to the shop sync service yet. '
          'Open Settings > Device Sync while online, then try again.',
        );
      }
      final tickets = await ref.read(supportGatewayProvider).list(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
          );
      if (!mounted) return;
      setState(() {
        _credentials = credentials;
        _tickets = tickets;
        _loading = false;
      });
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

  Future<void> _newTicket() async {
    final credentials = _credentials;
    if (credentials == null) return;
    final draft = await showDialog<_TicketDraft>(
      context: context,
      builder: (_) => const _NewTicketDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      final id = await ref.read(supportGatewayProvider).open(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
            subject: draft.subject,
            message: draft.message,
          );
      await _load();
      if (!mounted) return;
      SupportTicket? opened;
      for (final ticket in _tickets) {
        if (ticket.id == id) { opened = ticket; break; }
      }
      if (opened != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _SupportThreadScreen(ticket: opened!),
          ),
        );
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is PaystackException ? e.message : 'Could not open the ticket.',
        )),
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
    floatingActionButton: _credentials == null ? null : FloatingActionButton.extended(
      onPressed: _newTicket,
      icon: const Icon(Icons.add_comment_outlined),
      label: const Text('New ticket'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.support_agent, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ]),
              ))
            : _tickets.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.support_agent, size: 56),
                      const SizedBox(height: 12),
                      Text('Need help?', style: Theme.of(context).textTheme.titleLarge),
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
                    ]),
                  ))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tickets.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ticket = _tickets[index];
                        return Card(child: ListTile(
                          leading: const Icon(Icons.confirmation_number_outlined),
                          title: Text(ticket.subject),
                          subtitle: Text('#${ticket.id} • ${ticket.status.toUpperCase()}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _SupportThreadScreen(ticket: ticket),
                              ),
                            );
                            await _load();
                          },
                        ));
                      },
                    ),
                  ),
  );
}

class _TicketDraft {
  const _TicketDraft(this.subject, this.message);
  final String subject;
  final String message;
}

class _NewTicketDialog extends StatefulWidget {
  const _NewTicketDialog();
  @override
  State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
  final _subject = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.length < 3 || message.isEmpty) return;
    Navigator.pop(context, _TicketDraft(subject, message));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Open support ticket'),
    content: SizedBox(
      width: 460,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _subject,
          maxLength: 160,
          decoration: const InputDecoration(
            labelText: 'Subject',
            hintText: 'What do you need help with?',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          maxLength: 8000,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Describe the issue',
            alignLabelWithHint: true,
          ),
        ),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _submit, child: const Text('Send ticket')),
    ],
  );
}

class _SupportThreadScreen extends ConsumerStatefulWidget {
  const _SupportThreadScreen({required this.ticket});
  final SupportTicket ticket;
  @override
  ConsumerState<_SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends ConsumerState<_SupportThreadScreen> {
  final _reply = TextEditingController();
  SupportThread? _thread;
  PaystackCredentials? _credentials;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final credentials = await ref.read(paystackCredentialsServiceProvider).load();
      final thread = await ref.read(supportGatewayProvider).thread(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        ticketId: widget.ticket.id,
      );
      if (!mounted) return;
      setState(() {
        _credentials = credentials;
        _thread = thread;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is PaystackException ? e.message : 'Could not load this ticket.';
      });
    }
  }

  Future<void> _send() async {
    final credentials = _credentials;
    final message = _reply.text.trim();
    if (credentials == null || message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportGatewayProvider).reply(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        ticketId: widget.ticket.id,
        message: message,
      );
      _reply.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is PaystackException ? e.message : 'Could not send the message.',
        )),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = _thread;
    return Scaffold(
      appBar: AppBar(
        title: Text('#${widget.ticket.id} ${widget.ticket.subject}'),
        actions: [
          if (thread != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text(thread.ticket.status.toUpperCase())),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: thread!.messages.length,
                      itemBuilder: (context, index) {
                        final message = thread.messages[index];
                        final support = message.sender == 'support';
                        return Align(
                          alignment: support ? Alignment.centerLeft : Alignment.centerRight,
                          child: Card(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      support ? 'NexaPOS Support' : 'Your shop',
                                      style: Theme.of(context).textTheme.labelMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(message.body),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 8000,
                            decoration: const InputDecoration(hintText: 'Reply to this ticket…'),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send',
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                        ),
                      ]),
                    ),
                  ),
                ]),
    );
  }
}
