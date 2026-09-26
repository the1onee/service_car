import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/models/service_item.dart';

Future<ServiceItem?> openServiceDetail(
  BuildContext context,
  ServiceItem service,
) {
  return Navigator.of(context).push<ServiceItem>(
    MaterialPageRoute(
      builder: (_) => ServiceDetailScreen(service: service),
    ),
  );
}

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.service});

  final ServiceItem service;

  @override
  Widget build(BuildContext context) {
    final highlights = service.highlightsAr;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(service.titleAr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outline),
              boxShadow: AppTheme.cardShadow(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.recessed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _iconFor(service.id),
                        color: AppColors.amberDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.titleAr,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service.category.isEmpty
                                ? 'خدمة'
                                : service.category,
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.petrolTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    service.providerKind.labelAr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                    ),
                  ),
                ),
                if (service.descriptionAr.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    service.descriptionAr.trim(),
                    style: const TextStyle(
                      height: 1.55,
                      fontSize: 14.5,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'ما الذي تشمله الخدمة؟',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),
            for (final point in highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: AppColors.emeraldDeep,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(height: 1.45, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(service),
            child: const Text('اطلب هذه الخدمة'),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String id) {
    switch (id) {
      case 'technician':
        return Icons.handyman_outlined;
      case 'oil':
        return Icons.opacity_outlined;
      case 'wash':
        return Icons.local_car_wash_outlined;
      case 'parts':
        return Icons.settings_suggest_outlined;
      case 'paint':
        return Icons.format_paint_outlined;
      case 'battery':
        return Icons.battery_charging_full;
      case 'tires':
        return Icons.tire_repair;
      case 'towing':
        return Icons.rv_hookup;
      case 'fuel':
        return Icons.local_gas_station;
      case 'locks':
        return Icons.lock_open;
      case 'ac':
        return Icons.ac_unit;
      default:
        return Icons.build_outlined;
    }
  }
}
