import 'package:flutter/material.dart';

import '../services/ambient_sound.dart';
import '../theme.dart';

class SoundControl extends StatefulWidget {
  const SoundControl({super.key});

  @override
  State<SoundControl> createState() => _SoundControlState();
}

class _SoundControlState extends State<SoundControl> {
  final AmbientSoundService _sound = AmbientSoundService();
  int _cycle = 0;
  static const _tracks = ['rain', 'fire', 'wind'];
  static const _labels = ['音乐', '雨声', '炉火', '风声'];

  @override
  void dispose() {
    _sound.stop();
    super.dispose();
  }

  void _toggle() {
    _sound.stop();
    setState(() {
      _cycle = (_cycle + 1) % 4;
    });
    if (_cycle == 0) return;
    switch (_tracks[_cycle - 1]) {
      case 'rain':
        _sound.startRain();
      case 'fire':
        _sound.startFire();
      case 'wind':
        _sound.startWind();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _cycle > 0;
    return GestureDetector(
      onTap: _toggle,
      child: Text(
        isPlaying ? '♫ ${_labels[_cycle]}' : _labels[0],
        style: TextStyle(
          color: isPlaying ? const Color(0x99FFFFFF) : kWhite,
          fontSize: 14,
          height: 1,
        ),
      ),
    );
  }
}