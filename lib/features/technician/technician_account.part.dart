part of 'technician_home.dart';

class _AccountPage extends StatelessWidget {
  const _AccountPage({required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final status = switch (me.verificationStatus) {
      VerificationStatus.approved => (
          'معتمد',
          AppColors.emeraldDeep,
          AppColors.emeraldTint
        ),
      VerificationStatus.rejected => (
          'مرفوض',
          AppColors.danger,
          AppColors.dangerTint
        ),
      VerificationStatus.pending => (
          'قيد التدقيق',
          const Color(0xFF92400E),
          AppColors.amberTint
        ),
    };
    return Column(
      children: [
        FieldTopBar(trailing: NotificationsBellButton(uid: me.id)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              AccountHeader(
                name: me.name,
                subtitle: me.phone,
                trailing: StatusPill(
                    label: status.$1, color: status.$2, background: status.$3),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      title: 'التقييم',
                      value: me.ratingAvg.toStringAsFixed(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _Stat(
                          title: 'عدد التقييمات', value: '${me.ratingCount}')),
                ],
              ),
              const SizedBox(height: 16),
              const SectionLabel('الخدمات المفعّلة'),
              _Services(me: me),
              const SizedBox(height: 16),
              const SectionLabel('أنواع السيارات'),
              _VehicleTypes(me: me),
              if (me.address.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                FieldCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('العنوان',
                          style: TextStyle(
                              color: AppColors.inkSoft, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(me.address),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => signOutFrom(context),
                icon: const Icon(Icons.logout, color: AppColors.danger),
                label: const Text('تسجيل الخروج',
                    style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Services extends StatelessWidget {
  const _Services({required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceItem>>(
      stream: AppScope.of(context).users.watchServices(),
      builder: (context, snap) {
        final items = (snap.data == null || snap.data!.isEmpty)
            ? seedServices
            : snap.data!;
        return FieldCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final s in items)
                SwitchListTile(
                  title: Text(s.titleAr),
                  subtitle: Text(s.category),
                  value: me.serviceIds.contains(s.id),
                  onChanged: (on) {
                    final next = {...me.serviceIds};
                    if (on) {
                      next.add(s.id);
                    } else {
                      next.remove(s.id);
                    }
                    AppScope.of(context)
                        .users
                        .setServiceIds(me.id, next.toList());
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VehicleTypes extends StatelessWidget {
  const _VehicleTypes({required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VehicleType>>(
      stream: AppScope.of(context).users.watchVehicleTypes(),
      builder: (context, snap) {
        final items = (snap.data == null || snap.data!.isEmpty)
            ? seedVehicleTypes
            : snap.data!;
        return FieldCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final t in items)
                SwitchListTile(
                  title: Text(t.nameAr),
                  value: me.vehicleTypeIds.contains(t.id),
                  onChanged: (on) {
                    final next = {...me.vehicleTypeIds};
                    if (on) {
                      next.add(t.id);
                    } else {
                      next.remove(t.id);
                    }
                    AppScope.of(context)
                        .users
                        .setVehicleTypeIds(me.id, next.toList());
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
