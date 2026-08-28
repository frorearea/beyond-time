import 'package:flutter/material.dart';

import '../theme.dart';

class QuickOptions extends StatelessWidget {
  const QuickOptions({
    super.key,
    required this.options,
    required this.disabled,
    required this.collapsed,
    required this.onTap,
    required this.onRefresh,
    this.compact = false,
  });

  final List<String> options;
  final bool disabled;
  final bool collapsed;
  final ValueChanged<String> onTap;
  final VoidCallback onRefresh;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (collapsed) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xCCFFFFFF))),
      ),
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in options) ...[
              Expanded(
                child: QuickOptionButton(
                  label: option,
                  disabled: disabled,
                  compact: compact,
                  onTap: () => onTap(option),
                ),
              ),
              const SizedBox(width: 8),
            ],
            RefreshOptionsButton(
              disabled: disabled,
              compact: compact,
              onTap: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class QuickOptionButton extends StatelessWidget {
  const QuickOptionButton({
    super.key,
    required this.label,
    required this.disabled,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool disabled;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: disabled ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kWhite,
        side: const BorderSide(color: Color(0xCCFFFFFF)),
        shape: const RoundedRectangleBorder(),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      child: Text(
        label,
        textAlign: TextAlign.left,
        maxLines: compact ? 1 : null,
        overflow: compact ? TextOverflow.ellipsis : null,
        style: TextStyle(
          fontSize: compact ? 12 : 14,
          height: 1.35,
        ),
      ),
    );
  }
}

class RefreshOptionsButton extends StatelessWidget {
  const RefreshOptionsButton({
    super.key,
    required this.disabled,
    required this.onTap,
    this.compact = false,
  });

  final bool disabled;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: OutlinedButton(
        onPressed: disabled ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: kWhite,
          side: const BorderSide(color: Color(0x99FFFFFF)),
          shape: const RoundedRectangleBorder(),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        child: Text(
          '换一组',
          textAlign: TextAlign.center,
          maxLines: compact ? 1 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}