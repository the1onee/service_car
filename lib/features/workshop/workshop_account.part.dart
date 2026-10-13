part of 'workshop_home.dart';

class _AccountPage extends StatefulWidget {
  const _AccountPage({
    required this.me,
    required this.jobs,
    required this.onOpenOrders,
    required this.onOpenWallet,
  });

  final AppUser me;
  final Stream<List<Job>> jobs;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenWallet;

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  var _uploadingPhoto = false;
  var _photoSaved = false;
  var _savingName = false;
  var _savingAddress = false;
  var _locationPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptLocation());
  }

  @override
  void didUpdateWidget(covariant _AccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.me.geo == null && widget.me.geo != null) {
      _locationPrompted = true;
    }
    if (!_locationPrompted && widget.me.geo == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptLocation());
    }
  }

  void _maybePromptLocation() {
    if (!mounted || _locationPrompted || _savingAddress) return;
    if (widget.me.geo != null) {
      _locationPrompted = true;
      return;
    }
    _locationPrompted = true;
    _editAddress();
  }

  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    final url = await AccountActions.changePhoto(context, uid: widget.me.id);
    if (!mounted) return;
    setState(() {
      _uploadingPhoto = false;
      if (url != null) _photoSaved = true;
    });
    if (url != null) {
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _photoSaved = false);
      });
    }
  }

  Future<void> _editName() async {
    if (_savingName) return;
    setState(() => _savingName = true);
    await AccountActions.editName(
      context,
      uid: widget.me.id,
      currentName: widget.me.name,
    );
    if (mounted) setState(() => _savingName = false);
  }

  Future<void> _editAddress() async {
    if (_savingAddress) return;
    final me = widget.me;
    final LatLng? initial = me.geo != null
        ? LatLng(me.geo!.latitude, me.geo!.longitude)
        : null;
    setState(() => _savingAddress = true);
    await AccountActions.editAddress(
      context,
      uid: me.id,
      currentGeo: initial,
      currentAddress: me.address,
      title: 'تحديد عنوان الورشة',
    );
    if (mounted) setState(() => _savingAddress = false);
  }

  Future<void> _editPhone() async {
    await AccountActions.editPhone(
      context,
      uid: widget.me.id,
      currentPhone: widget.me.phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final status = switch (me.verificationStatus) {
      VerificationStatus.approved => 'معتمد',
      VerificationStatus.rejected => 'مرفوض',
      VerificationStatus.pending => 'قيد التدقيق',
    };
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          FieldTopBar(
            caption: 'الملف',
            trailing: NotificationsBellButton(uid: me.id),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _WorkshopProfileHero(
                  profile: me,
                  statusLabel: status,
                  uploadingPhoto: _uploadingPhoto,
                  photoSaved: _photoSaved,
                  savingName: _savingName,
                  onChangePhoto: _changePhoto,
                  onEditName: _editName,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _WsStatCard(
                        icon: Icons.star_outline_rounded,
                        title: 'التقييم',
                        value: me.ratingAvg.toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WsStatCard(
                        icon: Icons.reviews_outlined,
                        title: 'عدد التقييمات',
                        value: '${me.ratingCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _WsMenuCard(
                  children: [
                    _WsMenuTile(
                      icon: Icons.assignment_outlined,
                      title: 'الطلبات',
                      onTap: widget.onOpenOrders,
                    ),
                    const Divider(height: 1),
                    _WsMenuTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'المحفظة',
                      onTap: widget.onOpenWallet,
                    ),
                    const Divider(height: 1),
                    _WsMenuTile(
                      icon: Icons.category_outlined,
                      title: 'التخصص',
                      subtitle: me.specialtyAr.isEmpty
                          ? 'ورشة قطع غيار'
                          : me.specialtyAr,
                      onTap: () {},
                    ),
                    if (me.workshopOps.trim().isNotEmpty) ...[
                      const Divider(height: 1),
                      _WsMenuTile(
                        icon: Icons.schedule_outlined,
                        title: 'أوقات العمل',
                        subtitle: me.workshopOps,
                        onTap: () {},
                      ),
                    ],
                    const Divider(height: 1),
                    _WsMenuTile(
                      icon: Icons.phone_outlined,
                      title: AppStrings.phone,
                      subtitle: profilePhoneLabel(me.phone),
                      onTap: _editPhone,
                    ),
                    const Divider(height: 1),
                    _WsMenuTile(
                      icon: Icons.location_on_outlined,
                      title: 'العنوان',
                      subtitle: _savingAddress
                          ? 'جاري الحفظ…'
                          : (me.address.trim().isEmpty
                              ? 'لا يوجد عنوان'
                              : me.address),
                      onTap: _savingAddress ? () {} : _editAddress,
                    ),
                    const Divider(height: 1),
                    const AccountThemeTile(),
                    const Divider(height: 1),
                    _WsMenuTile(
                      icon: Icons.description_outlined,
                      title: 'شروط الاستخدام',
                      onTap: () => TermsViewScreen.open(
                        context,
                        role: me.role,
                      ),
                    ),
                    const Divider(height: 1),
                    _WsMenuTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'سياسة الخصوصية',
                      onTap: () => PrivacyViewScreen.open(context),
                    ),
                    const Divider(height: 1),
                    _WsMenuTile(
                      icon: Icons.support_agent_outlined,
                      title: 'الدعم',
                      subtitle: 'اتصال أو إرسال تعليق',
                      onTap: () => SupportScreen.open(context, me),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => signOutFrom(context),
                    icon: const Icon(Icons.logout, color: AppColors.danger),
                    label: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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

class _WorkshopProfileHero extends StatelessWidget {
  const _WorkshopProfileHero({
    required this.profile,
    required this.statusLabel,
    required this.uploadingPhoto,
    required this.photoSaved,
    required this.savingName,
    required this.onChangePhoto,
    required this.onEditName,
  });

  final AppUser profile;
  final String statusLabel;
  final bool uploadingPhoto;
  final bool photoSaved;
  final bool savingName;
  final VoidCallback onChangePhoto;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final photo = profile.photoUrl.trim();
    final initial =
        profile.name.trim().isEmpty ? '؟' : profile.name.trim().substring(0, 1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow(opacity: 0.16),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            bottom: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: uploadingPhoto ? null : onChangePhoto,
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.amber, width: 2.5),
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: uploadingPhoto
                          ? const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: AppColors.amber,
                                ),
                              ),
                            )
                          : photo.isEmpty
                              ? Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: photo,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),

                                  errorWidget: (context, url, error) => Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: photoSaved ? AppColors.emerald : AppColors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.slate, width: 2),
                      ),
                      child: Icon(
                        photoSaved ? Icons.check_rounded : Icons.camera_alt,
                        size: photoSaved ? 18 : 15,
                        color: photoSaved ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      profile.name.trim().isEmpty ? 'بدون اسم' : profile.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: savingName ? null : onEditName,
                    visualDensity: VisualDensity.compact,
                    icon: savingName
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.amber,
                            ),
                          )
                        : const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.amber,
                  ),
                ],
              ),
              Text(
                profilePhoneLabel(profile.phone),
                textDirection: profile.phone.trim().isEmpty
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: const TextStyle(
                  color: Color(0xFFBEC6E0),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'ورشة قطع',
                      style: TextStyle(
                        color: Color(0xFFFFDDB8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Color(0xFFBEC6E0),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WsStatCard extends StatelessWidget {
  const _WsStatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.amberDeep),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _WsMenuCard extends StatelessWidget {
  const _WsMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: AppColors.slate.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _WsMenuTile extends StatelessWidget {
  const _WsMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.recessed,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.slate, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
        trailing: const Icon(Icons.chevron_left, color: AppColors.inkSoft),
      ),
    );
  }
}


