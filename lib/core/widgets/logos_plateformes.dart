import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../liens_ecoute.dart';

/// Couleurs de marque, utilisées pour les boutons d'écoute.
const Color vertSpotify = Color(0xFF1DB954);
const Color rougeYoutube = Color(0xFFFF0000);
const Color rougeAppleMusic = Color(0xFFFA243C);
const Color violetDeezer = Color(0xFFA238FF);
const Color jauneAudiomack = Color(0xFFFFA200);

/// Couleur d'un bouton pour chaque plateforme.
Color couleurPlateforme(Plateforme p) => switch (p) {
      Plateforme.spotify => vertSpotify,
      Plateforme.youtube => rougeYoutube,
      Plateforme.appleMusic => rougeAppleMusic,
      Plateforme.deezer => violetDeezer,
      Plateforme.audiomack => jauneAudiomack,
    };

/// Couleur du texte et du logo posés sur le fond de marque.
/// Audiomack est jaune et noir : son texte est noir.
Color texteSurPlateforme(Plateforme p) => p == Plateforme.audiomack ? Colors.black : Colors.white;

/// Logo vectoriel de la plateforme, dessiné sans dépendance.
class LogoPlateforme extends StatelessWidget {
  const LogoPlateforme(this.plateforme, {super.key, this.taille = 20, this.couleur = Colors.white});

  final Plateforme plateforme;
  final double taille;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    switch (plateforme) {
      case Plateforme.spotify:
        return CustomPaint(size: Size.square(taille), painter: _PeintreSpotify(couleur));
      case Plateforme.youtube:
        return CustomPaint(size: Size(taille * 1.4, taille), painter: _PeintreYoutube(couleur));
      case Plateforme.appleMusic:
        return CustomPaint(size: Size.square(taille), painter: _PeintreNote(couleur));
      case Plateforme.deezer:
        return CustomPaint(size: Size.square(taille), painter: _PeintreDeezer(couleur));
      case Plateforme.audiomack:
        return CustomPaint(size: Size.square(taille), painter: _PeintreAudiomack(couleur));
    }
  }
}

/// Rond plein, trois arcs de largeur décroissante découpés dedans.
class _PeintreSpotify extends CustomPainter {
  _PeintreSpotify(this.fond);

  final Color fond;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(c, r, Paint()..color = fond);
    final trait = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.clear;
    final largeurs = [size.width * 0.115, size.width * 0.09, size.width * 0.07];
    final rayons = [r * 0.62, r * 0.50, r * 0.38];
    final hauteurs = [-r * 0.20, -r * 0.01, r * 0.17];
    for (var i = 0; i < 3; i++) {
      trait.strokeWidth = largeurs[i];
      final rect = Rect.fromCircle(center: c.translate(0, hauteurs[i] + r * 0.30), radius: rayons[i]);
      canvas.drawArc(rect, math.pi * 1.18, math.pi * 0.64, false, trait);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PeintreSpotify old) => old.fond != fond;
}

/// Rectangle arrondi plein avec un triangle « lecture » découpé.
class _PeintreYoutube extends CustomPainter {
  _PeintreYoutube(this.fond);

  final Color fond;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height * 0.28)),
      Paint()..color = fond,
    );
    final c = size.center(Offset.zero);
    final h = size.height * 0.46;
    final triangle = Path()
      ..moveTo(c.dx - h * 0.42, c.dy - h * 0.5)
      ..lineTo(c.dx + h * 0.62, c.dy)
      ..lineTo(c.dx - h * 0.42, c.dy + h * 0.5)
      ..close();
    canvas.drawPath(triangle, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PeintreYoutube old) => old.fond != fond;
}

/// Note de musique double croche (Apple Music).
class _PeintreNote extends CustomPainter {
  _PeintreNote(this.c);
  final Color c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()..color = c;
    final hampe = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    // deux têtes de note
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.27, h * 0.80), width: w * 0.32, height: h * 0.24), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.75, h * 0.70), width: w * 0.32, height: h * 0.24), p);
    // hampes
    canvas.drawLine(Offset(w * 0.40, h * 0.78), Offset(w * 0.40, h * 0.18), hampe);
    canvas.drawLine(Offset(w * 0.88, h * 0.68), Offset(w * 0.88, h * 0.08), hampe);
    // barre qui relie les deux hampes
    final barre = Path()
      ..moveTo(w * 0.40, h * 0.18)
      ..lineTo(w * 0.88, h * 0.08)
      ..lineTo(w * 0.88, h * 0.26)
      ..lineTo(w * 0.40, h * 0.36)
      ..close();
    canvas.drawPath(barre, p);
  }

  @override
  bool shouldRepaint(_PeintreNote old) => old.c != c;
}

/// Barres de Deezer : cinq colonnes de hauteurs croissantes en escalier.
class _PeintreDeezer extends CustomPainter {
  _PeintreDeezer(this.c);
  final Color c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()..color = c;
    final colonne = w * 0.16, ecart = w * 0.04;
    final hauteurs = [0.24, 0.40, 0.56, 0.40, 0.72];
    final bas = [1.0, 1.0, 1.0, 1.0, 1.0];
    for (var i = 0; i < 5; i++) {
      final x = i * (colonne + ecart);
      final hh = h * hauteurs[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h * bas[i] - hh, colonne, hh), const Radius.circular(1.5)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_PeintreDeezer old) => old.c != c;
}

/// Audiomack : quatre barres d'onde sonore de hauteurs variées, centrées.
class _PeintreAudiomack extends CustomPainter {
  _PeintreAudiomack(this.c);
  final Color c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.14;
    final hauteurs = [0.38, 0.80, 0.56, 0.92, 0.30];
    for (var i = 0; i < hauteurs.length; i++) {
      final x = w * (0.10 + i * 0.20);
      final demi = h * hauteurs[i] / 2;
      canvas.drawLine(Offset(x, h / 2 - demi), Offset(x, h / 2 + demi), p);
    }
  }

  @override
  bool shouldRepaint(_PeintreAudiomack old) => old.c != c;
}
