part of 'oil_workshop_home.dart';

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.me,
    required this.onOpenOrders,
    required this.onOpenWallet,
  });

  final AppUser me;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenWallet;

  @override
  Widget build(BuildContext context) {
    return ProviderAccountView(
      me: me,
      caption: 'حساب ورشة الزيوت',
      roleBadge: 'ورشة زيوت',
      addressPickerTitle: 'تحديد عنوان ورشة الزيوت',
      onOpenOrders: onOpenOrders,
      onOpenWallet: onOpenWallet,
      midMenuTiles: [
        AccountTile(
          icon: Icons.verified_outlined,
          title: 'تصنيف الورشة',
          subtitle: me.oilWorkshopTierLabel,
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
