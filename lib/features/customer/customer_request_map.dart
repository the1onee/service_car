import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/customer/job_status_panel.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/models/vehicle_type.dart';

/// خريطة الطلب وورقة التكوين. الحالة تبقى في الصفحة الرئيسية.
class CustomerRequestMap extends StatelessWidget {
  const CustomerRequestMap({
    super.key,
    required this.profile,
    required this.job,
    required this.zone,
    required this.ready,
    required this.mapController,
    required this.pin,
    required this.zoom,
    required this.showBack,
    required this.inZone,
    required this.addressLabel,
    required this.selected,
    required this.entryId,
    required this.vehicleType,
    required this.services,
    required this.vehicleTypes,
    required this.busy,
    required this.onBack,
    required this.onSelect,
    required this.onSelectVehicle,
    required this.onPickLocation,
    required this.onSubmit,
    required this.onLocated,
    required this.onRecenter,
    required this.onShown,
    this.onMapTap,
    this.onPositionChanged,
  });

  final AppUser profile;
  final Job? job;
  final CityZone? zone;
  final bool ready;
  final MapController mapController;
  final LatLng pin;
  final double zoom;
  final bool showBack;
  final bool inZone;
  final String addressLabel;
  final ServiceItem? selected;
  final String? entryId;
  final VehicleType? vehicleType;
  final Stream<List<ServiceItem>> services;
  final Stream<List<VehicleType>> vehicleTypes;
  final bool busy;
  final VoidCallback onBack;
  final ValueChanged<ServiceItem> onSelect;
  final ValueChanged<VehicleType> onSelectVehicle;
  final VoidCallback onPickLocation;
  final VoidCallback onSubmit;
  final ValueChanged<LatLng> onLocated;
  final VoidCallback onRecenter;
  final VoidCallback onShown;
  final void Function(LatLng point)? onMapTap;
  final void Function(LatLng center)? onPositionChanged;

  @override
  Widget build(BuildContext context) {
    if (ready) onShown();
    final markers = <Marker>[
      if (job != null)
        pinMarker(
          LatLng(job!.displayLocation.latitude, job!.displayLocation.longitude),
          color: AppColors.amber,
        ),
    ];
    final circles = <CircleMarker>[
      if (zone != null)
        coverageCircle(
          centerLat: zone!.centerLat,
          centerLng: zone!.centerLng,
          radiusKm: zone!.radiusKm,
        ),
    ];
    final map = Stack(
      children: [
        if (!ready)
          const Center(child: CircularProgressIndicator())
        else
          OsmMap(
            mapController: mapController,
            center: pin,
            zoom: zoom,
            circles: circles,
            markers: markers,
            onTap: onMapTap,
            onPositionChanged: onPositionChanged,
            onLocated: onLocated,
          ),
        if (ready && job == null)
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_on,
                    color: AppColors.amberDeep, size: 42),
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: FieldTopBar(
            city: zone?.nameAr,
            caption: showBack ? 'تحديد الموقع والطلب' : 'خدمة ميدانية',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBack)
                  IconButton(
                    tooltip: 'رجوع',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  ),
                NotificationsBellButton(uid: profile.id),
              ],
            ),
          ),
        ),
        if (ready && job != null)
          Positioned(
            top: 108,
            left: 16,
            right: 16,
            child: Material(
              color: AppColors.surface,
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  AppStrings.locationLockedDuringJob,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        if (ready && job == null)
          Positioned(
            top: 108,
            left: 16,
            child: _MapButton(icon: Icons.my_location, onTap: onRecenter),
          ),
      ],
    );
    return Column(
      children: [
        Expanded(child: map),
        job == null
            ? _RequestComposer(
                zone: zone,
                inZone: inZone,
                addressLabel: addressLabel,
                selected: selected,
                vehicleType: vehicleType,
                vehicleTypes: vehicleTypes,
                busy: busy,
                onSelectVehicle: onSelectVehicle,
                onPickLocation: onPickLocation,
                onSubmit: onSubmit,
              )
            : CustomerJobPanel(job: job!, me: profile),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.slate.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
            width: 44, height: 44, child: Icon(icon, color: AppColors.ink)),
      ),
    );
  }
}

class _RequestComposer extends StatelessWidget {
  const _RequestComposer({
    required this.zone,
    required this.inZone,
    required this.addressLabel,
    required this.selected,
    required this.vehicleType,
    required this.vehicleTypes,
    required this.busy,
    required this.onSelectVehicle,
    required this.onPickLocation,
    required this.onSubmit,
  });

  final CityZone? zone;
  final bool inZone;
  final String addressLabel;
  final ServiceItem? selected;
  final VehicleType? vehicleType;
  final Stream<List<VehicleType>> vehicleTypes;
  final bool busy;
  final ValueChanged<VehicleType> onSelectVehicle;
  final VoidCallback onPickLocation;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final emergency = selected?.isEmergency ?? false;
    return Material(
      color: AppColors.surface,
      elevation: 16,
      shadowColor: AppColors.slate.withValues(alpha: 0.18),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.58),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: emergency ? AppColors.amberTint : AppColors.recessed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emergency ? 'استجابة طوارئ الطريق' : 'طلب خدمة ميدانية',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          zone == null
                              ? 'حرّك الخريطة أو حدد الموقع من الزر'
                              : 'تغطية ${zone!.nameAr}',
                          style: const TextStyle(
                              color: AppColors.inkSoft, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: emergency ? AppColors.amber : AppColors.slate,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      emergency ? Icons.bolt : Icons.build_outlined,
                      color: emergency ? AppColors.ink : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FieldCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: onPickLocation,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, color: AppColors.inkSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'العنوان',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.inkSoft),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              inZone ? addressLabel : AppStrings.outsideCoverage,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: inZone ? AppColors.ink : AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        AppStrings.pickLocationOnMap,
                        style: TextStyle(
                          color: AppColors.amberDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (selected != null) ...[
              FieldCard(
                child: Row(
                  children: [
                    Icon(_serviceIcon(selected!.id), color: AppColors.amberDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selected!.titleAr,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            const SectionLabel(AppStrings.pickVehicleType),
            StreamBuilder<List<VehicleType>>(
              stream: vehicleTypes,
              builder: (context, snap) {
                final items = snap.data ?? seedVehicleTypes;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in items)
                      FilterChip(
                        label: Text(t.nameAr),
                        selected: vehicleType?.id == t.id,
                        onSelected: (_) => onSelectVehicle(t),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'السعر يحدده الفني بعد الفحص، والدفع نقداً عند انتهاء العمل.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy || selected == null || vehicleType == null
                  ? null
                  : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: emergency ? AppColors.amber : AppColors.slate,
                foregroundColor: emergency ? AppColors.ink : Colors.white,
                disabledBackgroundColor: AppColors.outline,
              ),
              icon: Icon(emergency ? Icons.bolt : Icons.arrow_back),
              label: Text(
                busy
                    ? 'جارٍ إرسال الطلب...'
                    : emergency
                        ? 'طلب فني طوارئ فوري'
                        : 'اطلب الفني',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _serviceIcon(String id) {
  switch (id) {
    case 'technician':
      return Icons.handyman_outlined;
    case 'battery':
      return Icons.battery_charging_full;
    case 'towing':
      return Icons.local_shipping_outlined;
    case 'tires':
      return Icons.album_outlined;
    case 'fuel':
      return Icons.local_gas_station_outlined;
    case 'locks':
      return Icons.key_outlined;
    case 'oil':
      return Icons.oil_barrel_outlined;
    case 'wash':
      return Icons.local_car_wash_outlined;
    case 'parts':
      return Icons.settings_suggest_outlined;
    case 'paint':
      return Icons.format_paint_outlined;
    case 'ac':
      return Icons.ac_unit;
    default:
      return Icons.build_outlined;
  }
}
