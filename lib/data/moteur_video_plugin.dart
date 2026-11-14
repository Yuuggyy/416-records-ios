import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../state/controleur_lecture.dart';

/// Moteur réel branché sur le plugin `video_player` (Android, iOS, web).
/// Lit aussi bien la vidéo que l'audio seul.
class MoteurVideoPlugin implements MoteurLecture {
  VideoPlayerController? _controleur;
  VoidCallback? _rappel;

  /// Exposé pour que l'écran puisse dessiner l'image vidéo.
  VideoPlayerController? get controleur => _controleur;

  @override
  Future<void> ouvrir(Uri source) async {
    await _liberer();
    final c = VideoPlayerController.networkUrl(source);
    _controleur = c;
    if (_rappel != null) c.addListener(_rappel!);
    await c.initialize();
  }

  @override
  Future<void> lire() async => _controleur?.play();

  @override
  Future<void> pause() async => _controleur?.pause();

  @override
  Future<void> aller(Duration position) async => _controleur?.seekTo(position);

  @override
  Future<void> volume(double valeur) async => _controleur?.setVolume(valeur);

  @override
  Duration get position => _controleur?.value.position ?? Duration.zero;

  @override
  Duration get duree => _controleur?.value.duration ?? Duration.zero;

  @override
  bool get enLecture => _controleur?.value.isPlaying ?? false;

  @override
  bool get enErreur => _controleur?.value.hasError ?? false;

  @override
  String? get messageErreur =>
      enErreur ? 'La lecture a échoué. Vérifiez votre connexion et réessayez.' : null;

  @override
  void ecouter(VoidCallback rappel) {
    _rappel = rappel;
    _controleur?.addListener(rappel);
  }

  Future<void> _liberer() async {
    final ancien = _controleur;
    if (ancien == null) return;
    if (_rappel != null) ancien.removeListener(_rappel!);
    await ancien.dispose();
    _controleur = null;
  }

  @override
  Future<void> fermer() => _liberer();
}
