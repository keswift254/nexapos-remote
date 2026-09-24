import 'package:flutter/material.dart';

import '../../domain/region/regions.dart';
import '../../domain/services/region_settings_service.dart';

/// Two drop-downs: the country the shop is in, and - only for a country with
/// more than one time zone - which zone. Used by the setup screen and by
/// Settings > Region and Time.
class RegionPicker extends StatelessWidget {
  const RegionPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final RegionSettings selected;
  final ValueChanged<RegionSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final region = selected.region;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('region-country'),
          initialValue: region.code,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Country'),
          items: [
            for (final r in regions)
              DropdownMenuItem(value: r.code, child: Text(r.name)),
          ],
          onChanged: (code) {
            final next = regionByCode(code);
            if (next == null || next.code == region.code) return;
            onChanged(RegionSettings(region: next, zone: next.zones.first));
          },
        ),
        const SizedBox(height: 12),
        if (region.zones.length > 1)
          // Keyed by country so choosing another country starts a fresh
          // drop-down showing that country's first zone.
          KeyedSubtree(
            key: ValueKey(region.code),
            child: DropdownButtonFormField<String>(
              key: const Key('region-zone'),
              initialValue: selected.zone.ianaId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Time zone'),
              items: [
                for (final z in region.zones)
                  DropdownMenuItem(value: z.ianaId, child: Text(z.label)),
              ],
              onChanged: (id) {
                final zone = zoneOfRegion(region, id);
                if (zone == null) return;
                onChanged(RegionSettings(region: region, zone: zone));
              },
            ),
          )
        else
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Time zone'),
            child: Text(selected.zone.label, key: const Key('region-zone-fixed')),
          ),
      ],
    );
  }
}
