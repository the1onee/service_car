part of 'workshop_home.dart';

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.me,
    required this.onOpenOrders,
    required this.onOpenWallet,
    this.jobs,
  });

  final AppUser me;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenWallet;
  final Stream<List<Job>>? jobs;

  @override
  Widget build(BuildContext context) {
    return ProviderAccountView(
      me: me,
      caption: 'حسابي',
      roleBadge: 'ورشة قطع',
      addressPickerTitle: 'تحديد عنوان الورشة',
      onOpenOrders: onOpenOrders,
      onOpenWallet: onOpenWallet,
      midMenuTiles: [
        AccountTile(
          icon: Icons.category_outlined,
          title: 'التخصص',
          subtitle:
              me.specialtyAr.isEmpty ? 'ورشة قطع غيار' : me.specialtyAr,
          onTap: () {},
        ),
        if (me.workshopOps.trim().isNotEmpty) ...[
          const Divider(height: 1),
          AccountTile(
            icon: Icons.schedule_outlined,
            title: 'أوقات العمل',
            subtitle: me.workshopOps,
            onTap: () {},
          ),
        ],
      ],
    );
  }
}
