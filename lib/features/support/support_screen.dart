import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/core/user_error.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/support_ticket.dart';
import 'package:barrr/services/support_repository.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.profile});

  final AppUser profile;

  static void open(BuildContext context, AppUser profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportScreen(profile: profile),
      ),
    );
  }

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _support = SupportRepository();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _support.createTicket(
        user: widget.profile,
        subject: _subject.text,
        body: _body.text,
      );
      if (!mounted) return;
      _subject.clear();
      _body.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب الدعم.')),
      );
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, prefix: 'تعذّر الإرسال.'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsStream = AppScope.of(context).settings.watchSettings();
    return Scaffold(
      appBar: AppBar(title: const Text('الدعم')),
      body: StreamBuilder(
        stream: settingsStream,
        builder: (context, settingsSnap) {
          final supportPhone =
              settingsSnap.data?.resolvedSupportPhone.trim() ?? '';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'اتصل بنا',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        supportPhone.isEmpty ? 'جاري التحميل…' : supportPhone,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: supportPhone.isEmpty
                            ? null
                            : () => _call(supportPhone),
                        icon: const Icon(Icons.phone_outlined),
                        label: const Text('اتصال بالدعم'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'أرسل تعليقاً أو شكوى',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _subject,
                        decoration: const InputDecoration(
                          labelText: 'الموضوع',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _body,
                        decoration: const InputDecoration(
                          labelText: 'التفاصيل',
                          alignLabelWithHint: true,
                        ),
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('إرسال'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'طلباتك السابقة',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<SupportTicket>>(
                stream: _support.watchMine(widget.profile.id),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text(
                      userFacingError(snap.error!),
                      style: const TextStyle(color: AppColors.danger),
                    );
                  }
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final rows = snap.data!;
                  if (rows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'لا توجد طلبات دعم بعد.',
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final t in rows) ...[
                        _TicketCard(
                          ticket: t,
                          onReply: (text) => _support.appendUserMessage(
                            ticketId: t.id,
                            uid: widget.profile.id,
                            body: text,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatefulWidget {
  const _TicketCard({required this.ticket, required this.onReply});

  final SupportTicket ticket;
  final Future<void> Function(String text) onReply;

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  final _reply = TextEditingController();
  var _busy = false;
  var _expanded = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onReply(_reply.text);
      if (!mounted) return;
      _reply.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final statusLabel = t.isOpen ? 'مفتوحة' : 'مغلقة';
    final statusColor = t.isOpen ? AppColors.emerald : AppColors.inkSoft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.subject,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.body,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.inkSoft, height: 1.4),
            ),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'إخفاء المحادثة' : 'عرض المحادثة'),
            ),
            if (_expanded) ...[
              const Divider(),
              for (final m in t.messages) ...[
                Align(
                  alignment:
                      m.isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: m.isAdmin
                          ? AppColors.azureTint
                          : AppColors.petrolTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.isAdmin ? 'الدعم' : 'أنت',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(m.body),
                      ],
                    ),
                  ),
                ),
              ],
              if (t.isOpen) ...[
                TextField(
                  controller: _reply,
                  decoration: const InputDecoration(
                    labelText: 'ردك',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _busy ? null : _send,
                    child: const Text('إرسال الرد'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
