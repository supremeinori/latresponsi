import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.compact = true,
  });

  final String status;
  final bool compact;

  String get _displayLabel {
    if (status.isEmpty) return 'Unknown';
    final lower = status.toLowerCase();
    if (lower == 'alive') return 'Alive';
    if (lower == 'dead') return 'Dead';
    if (lower == 'unknown') return 'Unknown';
    return '${status[0].toUpperCase()}${status.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorForStatus(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _displayLabel,
            style: TextStyle(
              color: color,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
