import 'package:flutter/material.dart';

import '../models/creation_note.dart';
import '../theme.dart';

/// 记忆面板顶部的「你写下的东西」区块。
///
/// 放在这里而不是做成新的侧栏入口，是因为它和「还悬着的事」同类：都属于
/// "她替你留着什么"，不属于对话本身。避难所不该在工具栏上多长出一个按钮。
///
/// 刻意做成只读：来访者的字不该被一个手滑的删除键带走。
class CreationSection extends StatelessWidget {
  const CreationSection({super.key, required this.creations});

  final List<CreationNote> creations;

  @override
  Widget build(BuildContext context) {
    if (creations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '你写下的东西',
          style: TextStyle(
            color: kWhite,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '你自己的设定、名字与片段。她只替你留着，不会替你改，也不会替你写下去。',
          style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 12),
        for (final note in creations) ...[
          _CreationRow(note),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        const Divider(height: 1, color: Color(0x44FFFFFF)),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _CreationRow extends StatelessWidget {
  const _CreationRow(this.note);

  final CreationNote note;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xAAFFFFFF)),
      ),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '「${note.title}」',
                  style: const TextStyle(color: kWhite, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                note.kind,
                style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
              ),
            ],
          ),
          if (note.content.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note.content,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
