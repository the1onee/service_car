part of 'technician_home.dart';

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.me,
    required this.onOpenOrders,
    required this.onOpenWallet,
    this.city,
    this.isActive = true,
  });

  final AppUser me;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenWallet;
  final String? city;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ProviderAccountView(
      me: me,
      city: city,
      isActive: isActive,
      caption: 'حسابي',
      roleBadge: 'فني',
      addressPickerTitle: 'تحديد عنوانك',
      onOpenOrders: onOpenOrders,
      onOpenWallet: onOpenWallet,
      midMenuTiles: [
        ProviderServicesTile(me: me),
        const Divider(height: 1),
        ProviderVehiclesTile(me: me),
      ],
    );
  }
}
