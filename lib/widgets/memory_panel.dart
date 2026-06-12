import 'package:flutter/material.dart';

import '../models/library_memory_item.dart';
import '../theme.dart';

class MemoryPanel extends StatelessWidget {
  const MemoryPanel({super.key, required this.memories});

  final List<LibraryMemoryItem> memories;

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
                  '图书馆记忆',
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
              '艾蕾塔只记录足够重要的喜好、压力、热爱与困扰。',
              style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: memories.isEmpty
                  ? const Center(
                      child: Text(
                        '书页还是空的。',
                        style: TextStyle(color: Color(0x99FFFFFF)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: memories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final memory = memories[memories.length - 1 - index];
                        return MemoryCard(memory: memory);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.memory});

  final LibraryMemoryItem memory;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xCCFFFFFF)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                memory.category,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                memory.source,
                style: const TextStyle(
                  color: Color(0x88FFFFFF),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            memory.content,
            style: const TextStyle(color: kWhite, fontSize: 14, height: 1.42),
          ),
          if (memory.evidence.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '依据：${memory.evidence}',
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
