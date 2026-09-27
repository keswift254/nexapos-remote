import 'package:flutter/material.dart';

/// Keep dashboard figures readable on small displays and at large text sizes.
class AdaptivePair extends StatelessWidget {
  const AdaptivePair({super.key, required this.child});
  final Row child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth >= 560 * MediaQuery.textScalerOf(context).scale(1)) {
        return IntrinsicHeight(child: child);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in child.children)
            if (item is Expanded) item.child else const SizedBox(height: 12),
        ],
      );
    },
  );
}
