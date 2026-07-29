import 'package:flutter/material.dart';

import '../theme.dart';

class QuickOptions extends StatelessWidget {
  const QuickOptions({
    super.key,
    required this.options,
    required this.disabled,
    required this.onTap,
    required this.onRefresh,
  });

  final List<String> options;
  final bool disabled;
  final ValueChanged<String> onTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xCCFFFFFF))),
      ),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 650) {
            return GridView.count(
              crossAxisCount: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final option in options)
                  QuickOptionButton(
                    label: option,
                    disabled: disabled,
                    onTap: () => onTap(option),
                  ),
                RefreshOptionsButton(disabled: disabled, onTap: onRefresh),
              ],
            );
          }

          return SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in options) ...[
                  Expanded(
                    child: QuickOptionButton(
                      label: option,
                      disabled: disabled,
                      onTap: () => onTap(option),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                SizedBox(
                  width: 78,
                  child: RefreshOptionsButton(
                    disabled: disabled,
                    onTap: onRefresh,
                  ),
                ),
              ],
            ),
          );
        },
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
  });

  final String label;
  final bool disabled;
  final VoidCallback onTap;

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
        style: const TextStyle(fontSize: 14, height: 1.35),
      ),
    );
  }
}

class RefreshOptionsButton extends StatelessWidget {
  const RefreshOptionsButton({
    super.key,
    required this.disabled,
    required this.onTap,
  });

  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: disabled ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kWhite,
        side: const BorderSide(color: Color(0x99FFFFFF)),
        shape: const RoundedRectangleBorder(),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      child: const Text(
        '换一组',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, height: 1.15),
      ),
    );
  }
}