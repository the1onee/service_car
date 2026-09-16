import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/models/service_item.dart';

Future<ServiceItem?> showServiceSheet(BuildContext context) {
  return showModalBottomSheet<ServiceItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ServicePickerSheet(),
  );
}

class ServicePickerSheet extends StatefulWidget {
  const ServicePickerSheet({super.key});

  @override
  State<ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<ServicePickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final users = AppScope.of(context).users;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return StreamBuilder(
          stream: users.watchServices(),
          builder: (context, snap) {
            final items = (snap.data ?? const <ServiceItem>[])
                .where((s) => s.titleAr.contains(_q) || s.category.contains(_q))
                .toList();
            final cats = <String>{for (final s in items) s.category};
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(AppStrings.pickService, style: Theme.of(context).textTheme.titleLarge),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن خدمة...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: [
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('لا توجد خدمات. سيتم إنشاء الكتالوج عند أول تشغيل.')),
                        ),
                      for (final cat in cats) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        for (final s in items.where((e) => e.category == cat))
                          ListTile(
                            leading: CircleAvatar(
                              child: Icon(s.isEmergency ? Icons.emergency_outlined : Icons.build_outlined),
                            ),
                            title: Text(s.titleAr),
                            subtitle: Text(s.isEmergency ? 'طوارئ: أقرب فني متاح' : 'عروض أسعار قصيرة ثم تختار'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => Navigator.pop(context, s),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
