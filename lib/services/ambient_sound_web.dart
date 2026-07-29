// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

class AmbientSoundService {
  html.AudioElement? _audio;
  String _currentTrack = '';
  bool _playing = false;
  double _volume = 0.5;

  bool get isPlaying => _playing;
  String get currentTrack => _currentTrack;

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (_audio != null) {
      _audio!.volume = _volume;
    }
  }

  void stop() {
    _audio?.pause();
    _audio = null;
    _currentTrack = '';
    _playing = false;
  }

  void startRain() {
    _play('assets/assets/sounds/heavy-rain.ogg', 'rain');
  }

  void startFire() {
    _play('assets/assets/sounds/fireplace.ogg', 'fire');
  }

  void startWind() {
    _play('assets/assets/sounds/wind.ogg', 'wind');
  }

  void _play(String path, String track) {
    stop();
    _audio = html.AudioElement(path);
    _audio!.loop = true;
    _audio!.volume = _volume;
    _audio!.play().then((_) {
      _playing = true;
    }).catchError((_) {
      _playing = false;
    });
    _currentTrack = track;
  }
}
