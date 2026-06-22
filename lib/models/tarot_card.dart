class TarotCard {
  const TarotCard(this.name, this.arcana);

  final String name;
  final String arcana;
}

class TarotSpreadCard {
  const TarotSpreadCard({
    required this.position,
    required this.card,
    required this.isReversed,
  });

  final String position;
  final TarotCard card;
  final bool isReversed;

  String get orientation => isReversed ? '逆位' : '正位';
}

const List<TarotCard> kTarotDeck = [
  TarotCard('愚者', '大阿尔卡那'),
  TarotCard('魔术师', '大阿尔卡那'),
  TarotCard('女祭司', '大阿尔卡那'),
  TarotCard('皇后', '大阿尔卡那'),
  TarotCard('皇帝', '大阿尔卡那'),
  TarotCard('教皇', '大阿尔卡那'),
  TarotCard('恋人', '大阿尔卡那'),
  TarotCard('战车', '大阿尔卡那'),
  TarotCard('力量', '大阿尔卡那'),
  TarotCard('隐士', '大阿尔卡那'),
  TarotCard('命运之轮', '大阿尔卡那'),
  TarotCard('正义', '大阿尔卡那'),
  TarotCard('倒吊人', '大阿尔卡那'),
  TarotCard('死神', '大阿尔卡那'),
  TarotCard('节制', '大阿尔卡那'),
  TarotCard('恶魔', '大阿尔卡那'),
  TarotCard('高塔', '大阿尔卡那'),
  TarotCard('星星', '大阿尔卡那'),
  TarotCard('月亮', '大阿尔卡那'),
  TarotCard('太阳', '大阿尔卡那'),
  TarotCard('审判', '大阿尔卡那'),
  TarotCard('世界', '大阿尔卡那'),
  TarotCard('权杖王牌', '小阿尔卡那·权杖'),
  TarotCard('权杖二', '小阿尔卡那·权杖'),
  TarotCard('权杖三', '小阿尔卡那·权杖'),
  TarotCard('权杖四', '小阿尔卡那·权杖'),
  TarotCard('权杖五', '小阿尔卡那·权杖'),
  TarotCard('权杖六', '小阿尔卡那·权杖'),
  TarotCard('权杖七', '小阿尔卡那·权杖'),
  TarotCard('权杖八', '小阿尔卡那·权杖'),
  TarotCard('权杖九', '小阿尔卡那·权杖'),
  TarotCard('权杖十', '小阿尔卡那·权杖'),
  TarotCard('权杖侍从', '小阿尔卡那·权杖'),
  TarotCard('权杖骑士', '小阿尔卡那·权杖'),
  TarotCard('权杖皇后', '小阿尔卡那·权杖'),
  TarotCard('权杖国王', '小阿尔卡那·权杖'),
  TarotCard('圣杯王牌', '小阿尔卡那·圣杯'),
  TarotCard('圣杯二', '小阿尔卡那·圣杯'),
  TarotCard('圣杯三', '小阿尔卡那·圣杯'),
  TarotCard('圣杯四', '小阿尔卡那·圣杯'),
  TarotCard('圣杯五', '小阿尔卡那·圣杯'),
  TarotCard('圣杯六', '小阿尔卡那·圣杯'),
  TarotCard('圣杯七', '小阿尔卡那·圣杯'),
  TarotCard('圣杯八', '小阿尔卡那·圣杯'),
  TarotCard('圣杯九', '小阿尔卡那·圣杯'),
  TarotCard('圣杯十', '小阿尔卡那·圣杯'),
  TarotCard('圣杯侍从', '小阿尔卡那·圣杯'),
  TarotCard('圣杯骑士', '小阿尔卡那·圣杯'),
  TarotCard('圣杯皇后', '小阿尔卡那·圣杯'),
  TarotCard('圣杯国王', '小阿尔卡那·圣杯'),
  TarotCard('宝剑王牌', '小阿尔卡那·宝剑'),
  TarotCard('宝剑二', '小阿尔卡那·宝剑'),
  TarotCard('宝剑三', '小阿尔卡那·宝剑'),
  TarotCard('宝剑四', '小阿尔卡那·宝剑'),
  TarotCard('宝剑五', '小阿尔卡那·宝剑'),
  TarotCard('宝剑六', '小阿尔卡那·宝剑'),
  TarotCard('宝剑七', '小阿尔卡那·宝剑'),
  TarotCard('宝剑八', '小阿尔卡那·宝剑'),
  TarotCard('宝剑九', '小阿尔卡那·宝剑'),
  TarotCard('宝剑十', '小阿尔卡那·宝剑'),
  TarotCard('宝剑侍从', '小阿尔卡那·宝剑'),
  TarotCard('宝剑骑士', '小阿尔卡那·宝剑'),
  TarotCard('宝剑皇后', '小阿尔卡那·宝剑'),
  TarotCard('宝剑国王', '小阿尔卡那·宝剑'),
  TarotCard('星币王牌', '小阿尔卡那·星币'),
  TarotCard('星币二', '小阿尔卡那·星币'),
  TarotCard('星币三', '小阿尔卡那·星币'),
  TarotCard('星币四', '小阿尔卡那·星币'),
  TarotCard('星币五', '小阿尔卡那·星币'),
  TarotCard('星币六', '小阿尔卡那·星币'),
  TarotCard('星币七', '小阿尔卡那·星币'),
  TarotCard('星币八', '小阿尔卡那·星币'),
  TarotCard('星币九', '小阿尔卡那·星币'),
  TarotCard('星币十', '小阿尔卡那·星币'),
  TarotCard('星币侍从', '小阿尔卡那·星币'),
  TarotCard('星币骑士', '小阿尔卡那·星币'),
  TarotCard('星币皇后', '小阿尔卡那·星币'),
  TarotCard('星币国王', '小阿尔卡那·星币'),
];
