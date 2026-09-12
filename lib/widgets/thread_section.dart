import 'package:flutter/material.dart';

import '../models/open_thread.dart';
import '../theme.dart';

/// 记忆面板顶部的「未决之事」区块。
///
/// 这些是来访者自己提起过、还没有下文的牵挂。放在记忆面板里而不是聊天界面上，
/// 是因为它属于"她记得什么"，不属于对话本身——避难所不该长出一张待办清单。
class ThreadSection extends StatelessWidget {
  const ThreadSection({super.key, required this.threads});

  final List<OpenThread> threads;

  @override
  Widget build(BuildContext context) {
    if (threads.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '还悬着的事',
          style: TextStyle(
            color: kWhite,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '她记得你提过、但还没有下文的事。下次推门时，她可能会问起其中一件。',
          style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 12),
        for (final thread in threads) ...[
          _ThreadRow(thread: thread),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        const Divider(height: 1, color: Color(0x44FFFFFF)),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread});

  final OpenThread thread;

  @override
  Widget build(BuildContext context) {
    final settled = !thread.isOpen;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: settled ? const Color(0x55FFFFFF) : const Color(0xAAFFFFFF),
        ),
      ),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  thread.topic,
                  style: TextStyle(
                    color: settled ? const Color(0x99FFFFFF) : kWhite,
                    fontSize: 14,
                    decoration: settled ? TextDecoration.lineThrough : null,
                    decorationColor: const Color(0x88FFFFFF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                settled ? '已有下文' : '还没下文',
                style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
              ),
            ],
          ),
          if (thread.detail.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              thread.detail,
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
