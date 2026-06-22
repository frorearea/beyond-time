import 'package:flutter/material.dart';

import '../theme.dart';

class ArchivePanel extends StatelessWidget {
  const ArchivePanel({
    super.key,
    required this.messageCount,
    required this.memoryCount,
    required this.onExport,
    required this.onImport,
    required this.onClearAll,
  });

  final int messageCount;
  final int memoryCount;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBlack,
      child: Container(
        width: 460,
        height: double.infinity,
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: kWhite)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '图书馆存档',
                  style: TextStyle(color: kWhite, fontSize: 18),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '保存这段来访、书签与记忆。API Key 不会写进存档。',
              style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
            ),
            const SizedBox(height: 22),
            _ArchiveStat(label: '对话记录', value: '$messageCount 条'),
            const SizedBox(height: 10),
            _ArchiveStat(label: '图书馆记忆', value: '$memoryCount 条'),
            const SizedBox(height: 26),
            _ArchiveAction(
              title: '导出图书馆存档',
              description: '生成一个可以带走的 JSON 文件。',
              onTap: onExport,
            ),
            const SizedBox(height: 12),
            _ArchiveAction(
              title: '导入图书馆存档',
              description: '用旧存档恢复对话、记忆与心声进度。',
              onTap: onImport,
            ),
            const Spacer(),
            _ArchiveAction(
              title: '清空图书馆',
              description: '删除本机保存的对话、记忆与心声进度。',
              onTap: onClearAll,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveStat extends StatelessWidget {
  const _ArchiveStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: const Color(0x88FFFFFF))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 13)),
          Text(value, style: const TextStyle(color: kWhite, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ArchiveAction extends StatelessWidget {
  const _ArchiveAction({
    required this.title,
    required this.description,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final String description;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFFB8B8) : kWhite;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: color)),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
