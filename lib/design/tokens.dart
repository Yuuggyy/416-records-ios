import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Échelle de conception inspirée de Tailwind : valeurs en multiples de 4 px,
/// nommées comme dans une feuille d'utilitaires (`space-1` … `space-16`).
///
/// Un seul endroit décide des espacements, rayons et durées : aucun écran
/// n'invente ses propres nombres.
class Echelle {
  const Echelle._();

  static const double un = 4;
  static const double deux = 8;
  static const double trois = 12;
  static const double quatre = 16;
  static const double six = 24;
  static const double huit = 32;
  static const double douze = 48;
  static const double seize = 64;

  static const double rayonSm = 12;
  static const double rayonMd = 20;
  static const double rayonLg = 28;
  static const double rayonPilule = 999;

  static const Duration rapide = Duration(milliseconds: 180);
  static const Duration moyen = Duration(milliseconds: 320);
  static const Duration lent = Duration(milliseconds: 900);

  static const Curve sortieDouce = Curves.easeOutCubic;
}

/// Couleurs propres aux effets modernes : aurore, verre, arête lumineuse.
class Aurore {
  const Aurore._();

  static const violet = Color(0xFF734AC3);
  static const magenta = Color(0xFFB14AC3);
  static const bleu = Color(0xFF3C5BD6);
  static const cyan = Color(0xFF3FB6C9);

  static const verreClair = Color(0x14FFFFFF);
  static const verreFonce = Color(0x0AFFFFFF);
  static const bordureVerre = Color(0x22FFFFFF);

  static const degradePrimaire = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, magenta],
  );

  static const degradeAurore = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, bleu, cyan],
  );
}

/// Rythme typographique : peu de tailles, très contrastées, à la manière des
/// interfaces de Linear ou de Vercel.
class Typo {
  const Typo._();

  static const TextStyle affiche = TextStyle(
    fontSize: 34,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
  );

  static const TextStyle titreSection = TextStyle(
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle micro = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
  );

  static const TextStyle chiffre = TextStyle(
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Calculs de dégradés partagés par les primitives.
class Degrades {
  const Degrades._();

  /// Halo radial doux, utilisé pour l'aurore et les lueurs de fond.
  static RadialGradient halo(Color couleur, {double opacite = 0.45}) {
    return RadialGradient(
      colors: [
        couleur.withAlpha((255 * opacite).round()),
        couleur.withAlpha((255 * opacite * 0.35).round()),
        couleur.withAlpha(0),
      ],
      stops: const [0, 0.45, 1],
    );
  }

  /// Fait tourner une teinte dans la palette : sert à faire respirer l'aurore.
  static Color teinteTournante(double t, List<Color> teintes) {
    final position = (t % 1) * teintes.length;
    final index = position.floor() % teintes.length;
    final suivant = (index + 1) % teintes.length;
    final melange = position - position.floorToDouble();
    return Color.lerp(teintes[index], teintes[suivant], _adoucir(melange))!;
  }

  static double _adoucir(double x) => 0.5 - math.cos(x * math.pi) / 2;
}
