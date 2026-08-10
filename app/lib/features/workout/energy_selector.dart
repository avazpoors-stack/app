import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';

/// انتخاب سطح انرژی روز — گام اول چرخهٔ طلایی (مسترپلن ۲.۱ و ۲.۳).
class EnergySelector extends StatelessWidget {
  const EnergySelector({super.key, required this.onSelect});

  final ValueChanged<EnergyLevel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'حال و هوای امروزت چطوره؟',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'بدون قضاوت؛ بر اساسش برنامهٔ امروزت رو می‌چینیم.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textMutedLight),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final level in EnergyLevel.values) ...[
              Expanded(
                child: _EnergyCard(level: level, onTap: () => onSelect(level)),
              ),
              if (level != EnergyLevel.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.level, required this.onTap});

  final EnergyLevel level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Text(level.labelFa, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                level.descFa,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMutedLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
