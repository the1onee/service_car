import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/app_snackbar.dart';
import 'package:barrr/core/app_sound.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/core/user_error.dart';
import 'package:barrr/features/auth/add_phone_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/services/profile_photo_upload.dart';

/// بطاقة إحصائية موحدة لصفحات الحساب.
class AccountStatCard extends StatelessWidget {
  const AccountStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.outline.withValues(alpha: 0.5),
        ),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.amberDeep),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: isDark ? const Color(0xFFF1F5F9) : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة حاوية للقوائم والإعدادات في صفحات الحساب.
class AccountMenuCard extends StatelessWidget {
  const AccountMenuCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 1,
      shadowColor: isDark ? Colors.black38 : AppColors.slate.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// عنصر قائمة موحد في صفحات الحساب.
class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : AppColors.recessed,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.amber : AppColors.slate,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFF1F5F9) : AppColors.ink,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.inkSoft,
                ),
              ),
        trailing: Icon(
          Icons.chevron_left,
          color: isDark ? const Color(0xFF64748B) : AppColors.inkSoft,
        ),
      ),
    );
  }
}

/// عنصر تبديل الوضع الليلي (Dark Mode) في قوائم الحساب.
class AccountThemeTile extends StatelessWidget {
  const AccountThemeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkNow = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system && isDarkNow);
        return SwitchListTile(
          value: isDark,
          onChanged: (_) => AppTheme.toggleTheme(),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : AppColors.recessed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 20,
              color: isDark ? AppColors.amber : AppColors.slate,
            ),
          ),
          title: Text(
            'الوضع الليلي (Dark Mode)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isDark ? const Color(0xFFF1F5F9) : AppColors.ink,
            ),
          ),
          subtitle: Text(
            isDark ? 'مفعّل حالياً (Industrial Night)' : 'معطّل (الوضع النهاري)',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.inkSoft,
            ),
          ),
        );
      },
    );
  }
}

/// عنصر التحكم بالمؤثرات الصوتية وتجربتها في قوائم الحساب.
class AccountSoundTile extends StatefulWidget {
  const AccountSoundTile({super.key});

  @override
  State<AccountSoundTile> createState() => _AccountSoundTileState();
}

class _AccountSoundTileState extends State<AccountSoundTile> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        SwitchListTile(
          value: AppSoundService.isEnabled,
          onChanged: (val) {
            setState(() => AppSoundService.isEnabled = val);
            if (val) AppSoundService.playOfferPenguin();
          },
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : AppColors.recessed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.volume_up_rounded,
              size: 20,
              color: isDark ? AppColors.amber : AppColors.slate,
            ),
          ),
          title: Text(
            'المؤثرات الصوتية (نغمات الطلبات)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isDark ? const Color(0xFFF1F5F9) : AppColors.ink,
            ),
          ),
          subtitle: Text(
            AppSoundService.isEnabled
                ? 'مفعلة (صوت البطريق وقبول الطلب)'
                : 'مكتومة',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.inkSoft,
            ),
          ),
        ),
        if (AppSoundService.isEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () => AppSoundService.playOfferPenguin(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('نغمة العرض',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () => AppSoundService.playAcceptClient(),
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16),
                    label: const Text('نغمة القبول',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// حوار موحد لتعديل حقل نصي (الاسم، العنوان، إلخ).
class AccountPromptDialog extends StatefulWidget {
  const AccountPromptDialog({
    super.key,
    required this.title,
    required this.initial,
    this.maxLines = 1,
  });

  final String title;
  final String initial;
  final int maxLines;

  @override
  State<AccountPromptDialog> createState() => _AccountPromptDialogState();
}

class _AccountPromptDialogState extends State<AccountPromptDialog> {
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

/// مساعد موحد لإجراءات تحديث البروفايل (الاسم، الصورة، العنوان، رقم الهاتف).
class AccountActions {
  AccountActions._();

  /// تغيير ورفع صورة البروفايل
  static Future<String?> changePhoto(
    BuildContext context, {
    required String uid,
  }) async {
    final users = AppScope.of(context).users;
    try {
      final url = await ProfilePhotoUpload().pickAndUpload();
      if (url.isEmpty) return null;
      await users.updateProfile(uid, photoUrl: url);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'تم حفظ الصورة الشخصية بنجاح');
      }
      return url;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('Canceled')) return null;
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          userFacingError(e, prefix: 'تعذر رفع الصورة.'),
        );
      }
      return null;
    }
  }

  /// تعديل الاسم وحفظه في Firestore و FirebaseAuth
  static Future<bool> editName(
    BuildContext context, {
    required String uid,
    required String currentName,
  }) async {
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AccountPromptDialog(
        title: 'تعديل الاسم',
        initial: currentName,
      ),
    );
    if (next == null || !context.mounted) return false;
    if (next.isEmpty || next == currentName) return false;

    final users = AppScope.of(context).users;
    try {
      await users.updateProfile(uid, name: next);
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        try {
          await authUser.updateDisplayName(next);
        } catch (_) {}
      }
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'تم تحديث الاسم بنجاح');
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          userFacingError(e, prefix: 'تعذر حفظ الاسم.'),
        );
      }
      return false;
    }
  }

  /// تعديل العنوان عبر الخريطة
  static Future<bool> editAddress(
    BuildContext context, {
    required String uid,
    required LatLng? currentGeo,
    required String currentAddress,
    String title = 'تحديد عنوانك',
  }) async {
    final picked = await pickAddressOnMap(
      context,
      initial: currentGeo,
      title: title,
    );
    if (picked == null || !context.mounted) return false;

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AccountPromptDialog(
        title: 'تأكيد العنوان',
        initial: picked.label.isNotEmpty
            ? picked.label
            : (currentAddress.trim().isEmpty ? '' : currentAddress),
        maxLines: 3,
      ),
    );
    if (confirmed == null || !context.mounted) return false;
    if (confirmed.isEmpty) {
      AppSnackBar.showError(context, 'اكتب العنوان قبل الحفظ');
      return false;
    }

    try {
      await AppScope.of(context).users.setAddressAndGeo(
        uid,
        address: confirmed,
        geo: GeoPoint(picked.latLng.latitude, picked.latLng.longitude),
      );
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'تم تحديث العنوان بنجاح');
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          userFacingError(e, prefix: 'تعذر حفظ العنوان.'),
        );
      }
      return false;
    }
  }

  /// تعديل رقم الهاتف
  static Future<bool> editPhone(
    BuildContext context, {
    required String uid,
    required String currentPhone,
  }) async {
    final saved = await showPhoneEditor(
      context,
      uid: uid,
      currentPhone: currentPhone,
    );
    if (!saved || !context.mounted) return false;
    AppSnackBar.showSuccess(context, 'تم حفظ رقم الهاتف بنجاح');
    return true;
  }

  /// حذف حساب العميل نهائياً بعد تأكيد صريح.
  static Future<void> deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب نهائياً'),
        content: const Text(
          'سيُحذف حسابك وبياناتك الشخصية ورصيد محفظتك، ولا يمكن التراجع. '
          'نحتفظ فقط بسجل الطلبات السابقة للالتزامات القانونية والمالية.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'حذف',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await AppScope.of(context).auth.deleteOwnAccount();
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          userFacingError(e, fallback: 'تعذّر حذف الحساب. حاول لاحقاً.'),
        );
      }
    }
  }
}
