import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/models/app_settings.dart';

/// هل النقطة ضمن نطاق المدينة؟
bool requestPointInZone(LatLng p, CityZone? zone) {
  if (zone == null) return true;
  return isWithinRadiusKm(
    pointLat: p.latitude,
    pointLng: p.longitude,
    centerLat: zone.centerLat,
    centerLng: zone.centerLng,
    radiusKm: zone.radiusKm,
  );
}

String requestAddressLabel(LatLng p, CityZone? zone) {
  final coords =
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
  final zoneName = zone?.nameAr ?? '';
  if (zoneName.isEmpty) return coords;
  return '$zoneName ($coords)';
}

/// شريط علوي موحّد لنماذج طلب العميل.
class RequestFormTopBar extends StatelessWidget {
  const RequestFormTopBar({
    super.key,
    required this.title,
    required this.city,
    required this.uid,
    required this.onBack,
  });

  final String title;
  final String city;
  final String uid;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FF).withValues(alpha: 0.92),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                ),
                const FieldMark(size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        city,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                NotificationsBellButton(uid: uid),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RequestFormCard extends StatelessWidget {
  const RequestFormCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: child,
    );
  }
}

class RequestFormLabel extends StatelessWidget {
  const RequestFormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.inkSoft,
      ),
    );
  }
}

class RequestIconField extends StatelessWidget {
  const RequestIconField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
        filled: true,
        fillColor: AppColors.recessed,
        prefixIcon: Icon(icon, size: 18, color: AppColors.inkSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

InputDecoration requestInputDecoration({required String hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
    filled: true,
    fillColor: AppColors.recessed,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

Widget requestStepHeader(
  int step,
  String title, {
  String? trailing,
  String? badge,
}) {
  return Row(
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.slate,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$step',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      if (badge != null && badge.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.amberTint,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.amberDeep,
            ),
          ),
        ),
      if (trailing != null && trailing.isNotEmpty)
        Text(
          trailing,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
    ],
  );
}

/// معاينة الموقع المصغّرة مع زر تعديل الدبوس.
class RequestLocationMapCard extends StatelessWidget {
  const RequestLocationMapCard({
    super.key,
    required this.mapController,
    required this.pin,
    required this.zone,
    required this.inZone,
    required this.addressLabel,
    required this.onEditPin,
    this.step = 3,
    this.title = 'الموقع',
  });

  final MapController mapController;
  final LatLng pin;
  final CityZone? zone;
  final bool inZone;
  final String addressLabel;
  final VoidCallback onEditPin;
  final int step;
  final String title;

  @override
  Widget build(BuildContext context) {
    return RequestFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: requestStepHeader(step, title)),
              TextButton.icon(
                onPressed: onEditPin,
                icon: const Icon(Icons.edit_location_alt, size: 16),
                label: const Text('تعديل الدبوس'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.amberDeep,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 140,
              child: Stack(
                children: [
                  OsmMap(
                    mapController: mapController,
                    center: pin,
                    zoom: 14,
                    showMyLocation: false,
                    interactive: false,
                    circles: [
                      if (zone != null)
                        coverageCircle(
                          centerLat: zone!.centerLat,
                          centerLng: zone!.centerLng,
                          radiusKm: zone!.radiusKm,
                        ),
                    ],
                  ),
                  const IgnorePointer(
                    child: Center(
                      child: Icon(
                        Icons.location_on,
                        color: AppColors.amberDeep,
                        size: 38,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.slate.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              inZone ? addressLabel : 'خارج التغطية',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RequestSubmitButton extends StatelessWidget {
  const RequestSubmitButton({
    super.key,
    required this.submitting,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool submitting;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: submitting || !enabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.slate,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// تقسيم نص المركبة إلى ماركة/موديل.
({String make, String model}) splitVehicleMakeModel(String raw) {
  final trimmed = raw.trim();
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return (make: parts.first, model: parts.sublist(1).join(' '));
  }
  return (make: trimmed, model: '');
}
