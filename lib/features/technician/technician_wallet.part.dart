part of 'technician_home.dart';

enum _LedgerFilter { movements, payouts }

class _WalletPage extends StatefulWidget {
  const _WalletPage({
    required this.me,
    required this.online,
    required this.onToggle,
    required this.onAccount,
    this.dutyHint,
    this.city,
  });

  final AppUser me;
  final bool online;
  final String? dutyHint;
  final String? city;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAccount;

  @override
  State<_WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<_WalletPage> {
  var _filter = _LedgerFilter.movements;

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final scope = AppScope.of(context);
    return Column(
      children: [
        FieldTopBar(
          city: widget.city,
          caption: 'المحفظة',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NotificationsBellButton(uid: me.id),
              Material(
                color: AppColors.slate,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onAccount,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: scope.settings.watchSettings(),
            builder: (context, settingsSnap) {
              final min = settingsSnap.data?.minWalletBalance ??
                  AppConstants.minWalletBalance;
              return StreamBuilder<List<Job>>(
                stream: scope.jobs.watchRecentForTechnician(me.id),
                builder: (context, jobSnap) {
                  final jobs = jobSnap.data ?? const <Job>[];
                  final jobsById = {for (final job in jobs) job.id: job};
                  return StreamBuilder<List<WalletEntry>>(
                    stream: scope.users.watchWalletEntries(me.id),
                    builder: (context, entrySnap) {
                      final entries = entrySnap.data ?? const <WalletEntry>[];
                      final waiting = entrySnap.connectionState ==
                              ConnectionState.waiting &&
                          entries.isEmpty;
                      final shown = entries.where((entry) {
                        if (_filter == _LedgerFilter.movements) return true;
                        return entry.type != WalletEntryType.commission;
                      }).toList();
                      final locked = me.isWalletLocked(min);
                      final required = me.requiredTopUp(min);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _BalanceCard(
                            balance: me.walletBalance,
                            minBalance: min,
                            locked: locked,
                            online: widget.online,
                            dutyHint: widget.dutyHint,
                            city: widget.city,
                            onToggle: widget.onToggle,
                          ),
                          if (required > 0) ...[
                            const SizedBox(height: 10),
                            FieldCard(
                              child: Text(
                                'رصيد مطلوب للشحن: ${formatIqd(required)} لتفعيل استقبال الطلبات.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _WalletRechargePanel(technicianId: me.id),
                          const SizedBox(height: 12),
                          _MetricRow(jobs: jobs),
                          const SizedBox(height: 12),
                          _FilterBar(
                            filter: _filter,
                            onChanged: (value) =>
                                setState(() => _filter = value),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'الحركات الأخيرة',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Text(
                                'تحديث فوري',
                                style: TextStyle(
                                  color:
                                      AppColors.inkSoft.withValues(alpha: 0.9),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (waiting)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (shown.isEmpty)
                            FieldCard(
                              child: Text(
                                _filter == _LedgerFilter.payouts
                                    ? 'لا توجد دفعات من الإدارة بعد.'
                                    : 'لا توجد حركات بعد.',
                              ),
                            )
                          else
                            for (final entry in shown) ...[
                              _LedgerRow(
                                entry: entry,
                                job: entry.jobId == null
                                    ? null
                                    : jobsById[entry.jobId],
                              ),
                              const SizedBox(height: 8),
                            ],
                          if (locked) ...[
                            const SizedBox(height: 4),
                            _LowBalanceNote(minBalance: min),
                          ],
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.minBalance,
    required this.locked,
    required this.online,
    required this.onToggle,
    this.dutyHint,
    this.city,
  });

  final double balance;
  final double minBalance;
  final bool locked;
  final bool online;
  final String? dutyHint;
  final String? city;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final place = (city == null || city!.isEmpty) ? 'البصرة' : city!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            color: Color(0xFF7C839B), size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'رصيد محفظة الفني',
                            style: const TextStyle(
                              color: Color(0xFF7C839B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatIqd(balance, withUnit: false),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'د.ع',
                          style: TextStyle(
                            color: Color(0xFFFFB95F),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: locked
                          ? const Color(0xFFFFDAD6)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      locked ? 'مقفل' : 'نشط',
                      style: TextStyle(
                        color: locked
                            ? const Color(0xFF93000A)
                            : const Color(0xFF6FFBBE),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'الحد: ${formatIqd(minBalance)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF213145).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF002113),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sensors,
                      color: Color(0xFF4EDEA3), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online
                            ? 'متصل — جاهز لاستقبال الطلبات'
                            : 'غير متصل',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        online
                            ? 'جاهز للبلاغات الفورية في $place'
                            : 'لن تصلك بلاغات حتى تعيد الاتصال',
                        style: const TextStyle(
                          color: Color(0xFF7C839B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _DutySwitch(online: online, onToggle: onToggle),
              ],
            ),
          ),
          if (dutyHint != null) ...[
            const SizedBox(height: 8),
            Text(
              dutyHint!,
              style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _DutySwitch extends StatelessWidget {
  const _DutySwitch({required this.online, required this.onToggle});

  final bool online;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!online),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(2),
        alignment: online
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
          color: online ? const Color(0xFF002113) : const Color(0xFFD3E4FE),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: online ? const Color(0xFF6FFBBE) : const Color(0xFF76777D),
            shape: BoxShape.circle,
          ),
          child: Icon(
            online ? Icons.check : Icons.close,
            size: 14,
            color: online ? const Color(0xFF002113) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _WalletRechargePanel extends StatefulWidget {
  const _WalletRechargePanel({required this.technicianId});

  final String technicianId;

  @override
  State<_WalletRechargePanel> createState() => _WalletRechargePanelState();
}

class _WalletRechargePanelState extends State<_WalletRechargePanel> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _uploader = WalletTopUpUpload();
  XFile? _receipt;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyCard(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رقم البطاقة')),
    );
  }

  Future<void> _pickReceipt() async {
    setState(() => _error = null);
    try {
      final file = await _uploader.pickReceipt();
      if (file == null) return;
      setState(() => _receipt = file);
    } catch (e) {
      setState(() => _error = 'تعذّر اختيار الصورة.');
    }
  }

  Future<void> _submit(AppSettings settings) async {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغ التحويل بشكل صحيح.');
      return;
    }
    if (_receipt == null) {
      setState(() => _error = 'أضف صورة فاتورة التحويل أولاً.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final users = AppScope.of(context).users;
    try {
      final url = await _uploader.uploadReceipt(_receipt!);
      await users.createWalletTopUp(
            technicianId: widget.technicianId,
            amount: amount,
            receiptUrl: url,
            transferNote: _noteCtrl.text,
          );
      if (!mounted) return;
      _amountCtrl.clear();
      _noteCtrl.clear();
      setState(() => _receipt = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الطلب — بانتظار موافقة الإدارة لإضافة المبلغ'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _error = msg.contains('cancelled')
            ? null
            : _topUpErrorMessage(msg);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _topUpErrorMessage(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('permission-denied') ||
        lower.contains('permission_denied')) {
      return 'غير مسموح بإرسال طلب الشحن لهذا الحساب. حدّث التطبيق أو تواصل مع الدعم.';
    }
    if (lower.contains('cloudinary')) {
      return msg
          .replaceFirst(RegExp(r'^Exception:\s*'), '')
          .replaceFirst(RegExp(r'^Bad state:\s*'), '');
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('failed host')) {
      return 'تعذّر الاتصال. تحقق من الإنترنت وأعد المحاولة.';
    }
    if (msg.contains('الصورة') || msg.contains('كبيرة')) {
      return msg.replaceFirst(RegExp(r'^Bad state:\s*'), '');
    }
    return 'تعذّر الإرسال. تحقق من الاتصال وأعد المحاولة.';
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return StreamBuilder<AppSettings>(
      stream: scope.settings.watchSettings(),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data ?? const AppSettings();
        final card = settings.topUpCardNumber.trim().isEmpty
            ? AppSettings.defaultTopUpCardNumber
            : settings.topUpCardNumber.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB7D0F5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.topUpCardLabel.trim().isEmpty
                        ? AppSettings.defaultTopUpCardLabel
                        : settings.topUpCardLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF0B3A75),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.topUpInstructions.trim().isEmpty
                        ? AppSettings.defaultTopUpInstructions
                        : settings.topUpInstructions,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: Color(0xFF163A66),
                    ),
                  ),
                  if (settings.topUpAccountName.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'الاسم على البطاقة: ${settings.topUpAccountName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF163A66),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'رقم البطاقة للتحويل',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF5A6B82),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                card,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF0B3A75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _copyCard(card),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('نسخ'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الذي حوّلته (د.ع)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة (اختياري)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickReceipt,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.receipt_long),
                      label: Text(
                        _receipt == null
                            ? 'إضافة فاتورة التحويل'
                            : 'تم اختيار الفاتورة — تغيير',
                      ),
                    ),
                  ),
                  if (_receipt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _receipt!.name,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF5A6B82)),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : () => _submit(settings),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(
                        _busy ? 'جارٍ الإرسال…' : 'إرسال للموافقة وإضافة الرصيد',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<WalletTopUp>>(
              stream: scope.users.watchWalletTopUps(widget.technicianId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(
                    'تعذّر تحميل طلبات الشحن.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                  );
                }
                final rows = snap.data ?? const <WalletTopUp>[];
                if (rows.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'طلبات الشحن',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    for (final row in rows) ...[
                      FieldCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatIqd(row.amount),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    row.statusLabelAr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: row.status == WalletTopUpStatus.approved
                                          ? const Color(0xFF0F6B3A)
                                          : row.status == WalletTopUpStatus.rejected
                                              ? const Color(0xFFB3261E)
                                              : const Color(0xFF8A5A00),
                                    ),
                                  ),
                                  if (row.rejectReason.isNotEmpty)
                                    Text(
                                      row.rejectReason,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              formatWhen(row.createdAt),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF5A6B82)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.jobs});

  final List<Job> jobs;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final done = jobs.where((job) =>
        job.status == JobStatus.completed || job.status == JobStatus.rated);
    final today = done.where((job) {
      final date = job.createdAt;
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
    final collected = done.fold<double>(
      0,
      (total, job) => total + (job.receivedAmount ?? 0),
    );
    final rates =
        done.map((job) => job.commissionRate).whereType<double>().toSet();
    final rate = rates.length == 1 ? rates.first : AppConstants.commissionRate;
    final rateHint = rates.length > 1 ? 'حسب الخدمة' : 'ثابتة لكل طلب';
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'نسبة العمولة',
            value: '${(rate * 100).toStringAsFixed(0)}%',
            hint: rateHint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'المستحقات',
            value: formatIqd(collected, withUnit: false),
            unit: 'د.ع',
            hint: 'تم استلامها',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'طلبات اليوم',
            value: '$today',
            hint: 'مكتملة بنجاح',
            valueColor: const Color(0xFF855300),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.hint,
    this.unit,
    this.valueColor = AppColors.ink,
  });

  final String label;
  final String value;
  final String hint;
  final String? unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF45464D), fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(unit!,
                    style: const TextStyle(
                        color: Color(0xFF76777D), fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF76777D), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final _LedgerFilter filter;
  final ValueChanged<_LedgerFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE9FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              label: 'سجل الحركات المالية',
              selected: filter == _LedgerFilter.movements,
              onTap: () => onChanged(_LedgerFilter.movements),
            ),
          ),
          Expanded(
            child: _FilterChip(
              label: 'دفعات الإدارة',
              selected: filter == _LedgerFilter.payouts,
              onTap: () => onChanged(_LedgerFilter.payouts),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? AppTheme.cardShadow() : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.ink : const Color(0xFF45464D),
          ),
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, this.job});

  final WalletEntry entry;
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final credit = entry.signedAmount >= 0;
    final title = _title();
    final code = _code();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(
                icon:
                    credit ? Icons.add_card_outlined : _jobIcon(job?.serviceId),
                background:
                    credit ? const Color(0xFF002113) : const Color(0xFFDCE9FF),
                foreground: credit ? const Color(0xFF4EDEA3) : AppColors.ink,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (code != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5EEFF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF45464D),
                              ),
                            ),
                          ),
                        Text(
                          _walletWhen(entry.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF76777D),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatIqd(entry.signedAmount, signed: true),
                style: TextStyle(
                  color: credit ? const Color(0xFF005236) : AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: _footerLead(credit)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'الرصيد بعدها: ${formatIqd(entry.balanceAfter)}',
                    textAlign: TextAlign.end,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF45464D)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _title() {
    if (entry.type == WalletEntryType.commission) {
      final service = job?.serviceTitle;
      if (service != null && service.isNotEmpty) return 'خصم عمولة $service';
      return entry.note.isEmpty ? 'خصم عمولة الطلب' : entry.note;
    }
    if (entry.type == WalletEntryType.credit) {
      return entry.note.isEmpty ? 'شحن رصيد نقدي عبر الإدارة' : entry.note;
    }
    return entry.note.isEmpty ? entry.typeLabel : entry.note;
  }

  String? _code() {
    final id = job?.id ?? entry.jobId ?? entry.id;
    if (id.isEmpty) return null;
    final short = id.length > 8 ? id.substring(0, 8) : id;
    return '#$short';
  }

  Widget _footerLead(bool credit) {
    final received = job?.receivedAmount;
    if (!credit && received != null) {
      return Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFF45464D)),
          children: [
            const TextSpan(text: 'المستلم نقداً: '),
            TextSpan(
              text: formatIqd(received),
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      credit
          ? 'شحن عبر الإدارة'
          : (entry.note.isEmpty ? entry.typeLabel : entry.note),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: Color(0xFF45464D)),
    );
  }
}

class _LowBalanceNote extends StatelessWidget {
  const _LowBalanceNote({required this.minBalance});

  final double minBalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE9FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFFFDAD6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFF93000A), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تنبيه إيقاف استقبال الطلبات',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إذا انخفض الرصيد عن ${formatIqd(minBalance)} تتحول حالتك تلقائياً إلى غير متصل حتى تعيد الشحن وترفع فاتورة التحويل للموافقة.',
                  style: const TextStyle(
                    color: Color(0xFF45464D),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: foreground),
    );
  }
}

String _walletWhen(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour < 12 ? 'ص' : 'م';
  final clock = '$hour12:$minute $suffix';
  if (day == today) return 'اليوم $clock';
  if (day == today.subtract(const Duration(days: 1))) return 'أمس $clock';
  return formatWhen(local);
}

IconData _jobIcon(String? serviceId) {
  switch (serviceId) {
    case 'battery':
      return Icons.battery_charging_full;
    case 'towing':
      return Icons.local_shipping_outlined;
    case 'fuel':
      return Icons.local_gas_station_outlined;
    default:
      return Icons.build_outlined;
  }
}

