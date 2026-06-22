import 'dart:math' as math;

import '../models/library_memory_item.dart';
import '../models/tarot_card.dart';

class TarotReadingService {
  const TarotReadingService();

  List<TarotSpreadCard> drawSpread() {
    final random = math.Random();
    final deck = [...kTarotDeck]..shuffle(random);
    const positions = ['第一张：当前处境', '第二张：隐藏阻碍', '第三张：可选择的道路'];
    return [
      for (var index = 0; index < positions.length; index += 1)
        TarotSpreadCard(
          position: positions[index],
          card: deck[index],
          isReversed: random.nextBool(),
        ),
    ];
  }

  String buildReadingInstruction({
    required List<TarotSpreadCard> spread,
    required List<LibraryMemoryItem> memories,
  }) {
    final cardLines = spread
        .map((item) =>
            '- ${item.position}：${item.card.name}（${item.card.arcana}，${item.orientation}）')
        .join('\n');
    final memoryLines = memories.reversed
        .take(10)
        .toList()
        .reversed
        .map((memory) => '- [${memory.category}] ${memory.content}')
        .join('\n');

    return '''
这是一次“万象图书馆塔罗占卜”。本次占卜已经完成洗牌、切牌与抽牌。你必须严格按照以下抽到的三张牌解读，不得更换牌、增补牌、虚构第四张牌，也不得忽略正位/逆位。

牌阵规则：
1. 第一张代表来访者此刻的处境。
2. 第二张代表来访者尚未完全看见的阻碍或阴影。
3. 第三张代表来访者可以选择靠近的道路。

本次抽牌：
$cardLines

可参考的图书馆记忆：
$memoryLines

解读要求：
1. 先列出三张牌与正逆位。
2. 每张牌都要按照传统塔罗牌义解读，并明确说明正位或逆位如何改变含义。
3. 结合图书馆记忆，但不能为了安慰来访者而扭曲牌义。
4. 目的不是预测命运，而是借由牌面认识自己；不要做医疗、法律、金融或绝对未来判断。
5. 语气仍然是艾蕾塔：优雅、温柔、锋利，可以有一点小恶魔式亲昵。
6. 回复长度可以比普通对话更充分，约 500 到 800 个中文字符。不要用括号动作描写，不要输出 HTML。
''';
  }
}
