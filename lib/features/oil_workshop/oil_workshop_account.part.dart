part of 'oil_workshop_home.dart';

class _AccountPage extends StatefulWidget {
  const _AccountPage({
    required this.me,
    required this.onOpenOrders,
    required this.onOpenWallet,
  });

  final AppUser me;
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
    final users = AppScope.of(context).users;
    try {
      final url = await ProfilePhotoUpload().pickAndUpload();
      await users.updateProfile(widget.me.id, photoUrl: url);
      if (!mounted) return;
      setState(() => _photoSaved = true);
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _photoSaved = false);
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('Canceled')) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع الصورة: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editName() async {
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => _PromptDialog(
        title: 'تعديل الاسم',
        initial: widget.me.name,
      ),
    );
    if (next == null || !mounted) return;
    if (next.isEmpty || next == widget.me.name) return;

    final users = AppScope.of(context).users;
    setState(() => _savingName = true);
    try {
      await users.updateProfile(widget.me.id, name: next);
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        await authUser.updateDisplayName(next);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الاسم')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الاسم: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _editAddress() async {
    if (_savingAddress) return;
    final me = widget.me;
    final LatLng? initial = me.geo != null
        ? LatLng(me.geo!.latitude, me.geo!.longitude)
        : null;
    final picked = await pickAddressOnMap(
      context,
      initial: initial,
      title: 'تحديد عنوان ورشة الزيوت',
    );
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => _PromptDialog(
        title: 'تأكيد العنوان',
        initial: picked.label.isNotEmpty
            ? picked.label
            : (me.address.trim().isEmpty ? '' : me.address),
        maxLines: 3,
      ),
    );
    if (confirmed == null || !mounted) return;
    if (confirmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب العنوان قبل الحفظ')),
      );
      return;
    }

    setState(() => _savingAddress = true);
    try {
      await AppScope.of(context).users.setAddressAndGeo(
            me.id,
            address: confirmed,
            geo: GeoPoint(picked.latLng.latitude, picked.latLng.longitude),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث العنوان')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ العنوان: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  Future<void> _editPhone() async {
    final saved = await showPhoneEditor(
      context,
      uid: widget.me.id,
      currentPhone: widget.me.phone,
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الرقم')),
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
      color: const Color(0xFFF8F9FF),
      child: Column(
        children: [
          FieldTopBar(
            caption: 'حساب ورشة الزيوت',
            trailing: NotificationsBellButton(uid: me.id),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _OilProfileHero(
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
                      child: _OilStatCard(
                        icon: Icons.star_outline_rounded,
                        title: 'التقييم',
                        value: me.ratingAvg.toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OilStatCard(
                        icon: Icons.reviews_outlined,
                        title: 'عدد التقييمات',
                        value: '${me.ratingCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _OilMenuCard(
                  children: [
                    _OilMenuTile(
                      icon: Icons.assignment_outlined,
                      title: 'الطلبات',
                      onTap: widget.onOpenOrders,
                    ),
                    const Divider(height: 1),
                    _OilMenuTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'المحفظة',
                      onTap: widget.onOpenWallet,
                    ),
                    const Divider(height: 1),
                    _OilMenuTile(
                      icon: Icons.verified_outlined,
                      title: 'تصنيف الورشة',
                      subtitle: me.oilWorkshopTierLabel,
                      onTap: () {},
                    ),
                    if (me.workshopOps.trim().isNotEmpty) ...[
                      const Divider(height: 1),
                      _OilMenuTile(
                        icon: Icons.schedule_outlined,
                        title: 'أوقات العمل',
                        subtitle: me.workshopOps,
                        onTap: () {},
                      ),
                    ],
                    const Divider(height: 1),
                    _OilMenuTile(
                      icon: Icons.phone_outlined,
                      title: AppStrings.phone,
                      subtitle: profilePhoneLabel(me.phone),
                      onTap: _editPhone,
                    ),
                    const Divider(height: 1),
                    _OilMenuTile(
                      icon: Icons.location_on_outlined,
                      title: 'العنوان',
                      subtitle: _savingAddress
                          ? 'جاري الحفظ…'
                          : (me.address.trim().isEmpty
                              ? 'لا يوجد عنوان'
                              : me.address),
                      onTap: _savingAddress ? () {} : _editAddress,
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

class _OilProfileHero extends StatelessWidget {
  const _OilProfileHero({
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
      child: Column(
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
                          : Image.network(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
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
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _Chip(label: 'ورشة زيوت', accent: const Color(0xFFFFDDB8)),
              _Chip(label: profile.oilWorkshopTierLabel, accent: AppColors.amber),
              _Chip(label: statusLabel, accent: const Color(0xFFBEC6E0)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OilStatCard extends StatelessWidget {
  const _OilStatCard({
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

class _OilMenuCard extends StatelessWidget {
  const _OilMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: Column(children: children),
      ),
    );
  }
}

class _OilMenuTile extends StatelessWidget {
  const _OilMenuTile({
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
    return ListTile(
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
    );
  }
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    this.maxLines = 1,
  });

  final String title;
  final String initial;
  final int maxLines;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        textInputAction:
            widget.maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
        decoration: InputDecoration(
          hintText: widget.maxLines == 1 ? 'الاسم' : 'العنوان',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: widget.maxLines == 1 ? (_) => _save() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.slate),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
