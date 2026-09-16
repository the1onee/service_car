import 'dart:async';

import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/models/job_offer.dart';

class OfferOverlay extends StatefulWidget {
  const OfferOverlay({
    super.key,
    required this.offer,
    required this.technicianName,
    required this.onDone,
  });

  final JobOffer offer;
  final String technicianName;
  final VoidCallback onDone;

  @override
  State<OfferOverlay> createState() => _OfferOverlayState();
}

class _OfferOverlayState extends State<OfferOverlay> {
  late int _left;
  Timer? _timer;
  final _price = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _left = widget.offer.remainingSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = widget.offer.remainingSeconds();
      if (n <= 0) {
        _timer?.cancel();
        widget.onDone();
      }
      if (mounted) setState(() => _left = n);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _price.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final value = double.tryParse(_price.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = 'أدخل سعراً مبدئياً صحيحاً');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final scope = AppScope.of(context);
    final ok = await scope.dispatch.acceptOffer(
      offerId: widget.offer.id,
      technicianId: widget.offer.technicianId,
      technicianName: widget.technicianName,
      initialPrice: value,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'فاتك الطلب أو انتهت المهلة.';
      });
      widget.onDone();
      return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('طلب جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(widget.offer.serviceTitle ?? 'خدمة'),
                const SizedBox(height: 8),
                const Text('الموقع تقريبي ورقم الهاتف مخفي حتى يقبل العميل'),
                const SizedBox(height: 12),
                CircleAvatar(
                  radius: 28,
                  child: Text('$_left', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: AppStrings.initialPrice),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _accept,
                  child: const Text(AppStrings.accept),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await AppScope.of(context).jobs.rejectOffer(widget.offer.id);
                          widget.onDone();
                        },
                  child: const Text(AppStrings.reject),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
