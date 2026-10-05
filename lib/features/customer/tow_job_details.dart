import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/shared/osm_map.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';

/// بطاقة تفاصيل طلب السطحة — من / إلى + خريطة نقطتين دقيقتين.
class TowJobDetailsCard extends StatelessWidget {
  const TowJobDetailsCard({
    super.key,
    this.pickupLabel = '',
    this.dropoffLabel = '',
    this.pickupLocation,
    this.dropoffLocation,
    this.vehicleTypeTitle,
    this.landmark = '',
    this.customerPhone = '',
    this.partNote = '',
    this.distanceKm,
    this.compact = false,
    this.showPhone = false,
    this.showExactCoords = false,
  });

  factory TowJobDetailsCard.fromJob(
    Job job, {
    bool compact = false,
    bool showPhone = false,
  }) {
    final revealed = job.locationRevealed;
    // الخريطة دائماً بالإحداثيات الدقيقة للتحميل/التنزيل عند توفرها.
    final pickupExact = job.exactLocation ??
        (revealed ? job.displayLocation : null);
    return TowJobDetailsCard(
      pickupLabel: job.pickupLabel,
      dropoffLabel: job.dropoffLabel,
      pickupLocation: pickupExact ?? job.displayLocation,
      dropoffLocation: job.dropoffLocation,
      vehicleTypeTitle: job.vehicleTypeTitle,
      landmark: job.landmark,
      customerPhone: job.customerPhone,
      partNote: job.partNote,
      compact: compact,
      showPhone: showPhone,
      showExactCoords: revealed,
    );
  }

  factory TowJobDetailsCard.fromOffer(
    JobOffer offer, {
    bool compact = false,
  }) {
    return TowJobDetailsCard(
      pickupLabel: offer.pickupLabel,
      dropoffLabel: offer.dropoffLabel,
      pickupLocation: offer.pickupLocation ?? offer.approxLocation,
      dropoffLocation: offer.dropoffLocation,
      vehicleTypeTitle: offer.vehicleTypeTitle,
      landmark: offer.landmark,
      partNote: offer.partNote,
      distanceKm: offer.distanceKm,
      compact: compact,
      // النص منطقة مقربة؛ النقاط على الخريطة دقيقة.
      showExactCoords: false,
    );
  }

  final String pickupLabel;
  final String dropoffLabel;
  final GeoPoint? pickupLocation;
  final GeoPoint? dropoffLocation;
  final String? vehicleTypeTitle;
  final String landmark;
  final String customerPhone;
  final String partNote;
  final double? distanceKm;
  final bool compact;
  final bool showPhone;
  final bool showExactCoords;

  /// عنوان مقرب كمنطقة (بدون إحداثيات دقيقة في النص).
  static String regionLabel(String raw, {required String fallback}) {
    var t = raw.trim();
    if (t.isEmpty) return fallback;
    final paren = t.indexOf('(');
    if (paren > 0) t = t.substring(0, paren).trim();
    if (RegExp(r'^[\d.\s,\-]+$').hasMatch(t)) return fallback;
    return t.isEmpty ? fallback : t;
  }

  String get _fromText {
    final region = regionLabel(pickupLabel, fallback: 'منطقة التحميل');
    if (showExactCoords && pickupLocation != null) {
      return '$region\n${pickupLocation!.latitude.toStringAsFixed(5)}, ${pickupLocation!.longitude.toStringAsFixed(5)}';
    }
    return region;
  }

  String get _toText {
    final region = regionLabel(dropoffLabel, fallback: 'منطقة التنزيل');
    if (showExactCoords && dropoffLocation != null) {
      return '$region\n${dropoffLocation!.latitude.toStringAsFixed(5)}, ${dropoffLocation!.longitude.toStringAsFixed(5)}';
    }
    return region;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(_Row(label: label, value: value));
    }

    addRow('من (التحميل)', _fromText);
    addRow('إلى (التنزيل)', _toText);
    addRow('نوع المركبة', vehicleTypeTitle ?? '');
    addRow('علامة دالة', landmark);
    addRow('ملاحظة', partNote);
    if (distanceKm != null) {
      addRow('المسافة التقريبية', '${distanceKm!.toStringAsFixed(1)} كم');
    }
    if (showPhone) addRow('هاتف العميل', customerPhone);

    final map = _routeMap();

    if (rows.isEmpty && map == null) return const SizedBox.shrink();

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          const Text(
            'تفاصيل السطحة',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
        if (map != null) ...[
          map,
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );

    if (compact) return body;
    return FieldCard(child: body);
  }

  Widget? _routeMap() {
    final from = pickupLocation;
    final to = dropoffLocation;
    if (from == null && to == null) return null;

    final fromLl =
        from == null ? null : LatLng(from.latitude, from.longitude);
    final toLl = to == null ? null : LatLng(to.latitude, to.longitude);

    final center = _mapCenter(fromLl, toLl);
    final zoom = _mapZoom(fromLl, toLl);
    final markers = <Marker>[
      if (fromLl != null)
        Marker(
          point: fromLl,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.trip_origin,
            color: AppColors.amberDeep,
            size: 32,
          ),
        ),
      if (toLl != null)
        Marker(
          point: toLl,
          width: 40,
          height: 40,
          child: const Icon(Icons.flag, color: AppColors.slate, size: 32),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: compact ? 160 : 200,
        child: Stack(
          children: [
            OsmMap(
              center: center,
              zoom: zoom,
              showMyLocation: false,
              interactive: true,
              markers: markers,
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  _MapLegend(color: AppColors.amberDeep, label: 'تحميل'),
                  const SizedBox(width: 8),
                  _MapLegend(color: AppColors.slate, label: 'تنزيل'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static LatLng _mapCenter(LatLng? from, LatLng? to) {
    if (from != null && to != null) {
      return LatLng(
        (from.latitude + to.latitude) / 2,
        (from.longitude + to.longitude) / 2,
      );
    }
    return from ?? to!;
  }

  static double _mapZoom(LatLng? from, LatLng? to) {
    if (from == null || to == null) return 14;
    final dLat = (from.latitude - to.latitude).abs();
    final dLng = (from.longitude - to.longitude).abs();
    final span = dLat > dLng ? dLat : dLng;
    if (span < 0.005) return 15;
    if (span < 0.02) return 13;
    if (span < 0.05) return 12;
    if (span < 0.1) return 11;
    return 10;
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: RegExp(r'^\+?\d').hasMatch(value.trim())
                ? TextDirection.ltr
                : TextDirection.rtl,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
