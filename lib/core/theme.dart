import 'package:flutter/material.dart';

/// Identité 416 Records — direction « dossier de label ».
///
/// Encre et papier, un seul accent violet, filets d'un pixel. Aucun dégradé
/// décoratif, aucune ombre portée : la hiérarchie vient de la typographie et
/// du blanc tournant, pas des effets.
class Pal {
  const Pal._();

  static const fond = Color(0xFF0A0A0B);
  static const surface = Color(0xFF111113);
  static const surfaceHaute = Color(0xFF17171A);
  static const bordure = Color(0xFF26262B);
  static const filet = Color(0xFF1D1D21);

  /// Accent unique : violet de la maison 416.
  static const primaire = Color(0xFF8C52FF);
  static const primaireClaire = Color(0xFFB08CFF);

  static const texte = Color(0xFFF2EDE6);
  static const texteDoux = Color(0xFF8C877F);

  static const succes = Color(0xFF4FB477);
  static const alerte = Color(0xFFE0A21B);
  static const danger = Color(0xFFE2453C);
}

/// Rayons : l'angle droit est la règle, l'arrondi l'exception.
class Rayons {
  const Rayons._();
  static const double champ = 3;
  static const double carte = 4;
  static const double pilule = 999;
}

class Espace {
  const Espace._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Échelle typographique : Archivo Black pour les titres, Inter pour la lecture,
/// JetBrains Mono pour les étiquettes et les chiffres.
class Typo {
  const Typo._();

  static const String affiche = 'ArchivoBlack';
  static const String texte = 'Inter';
  static const String mono = 'Mono416';

  static const TextStyle titre = TextStyle(
    fontFamily: affiche,
    fontSize: 34,
    height: 0.98,
    letterSpacing: -0.6,
    color: Pal.texte,
  );

  static const TextStyle sousTitre = TextStyle(
    fontFamily: affiche,
    fontSize: 20,
    height: 1.05,
    letterSpacing: -0.2,
    color: Pal.texte,
  );

  static const TextStyle corps = TextStyle(
    fontFamily: texte,
    fontSize: 14.5,
    height: 1.5,
    color: Pal.texteDoux,
  );

  /// Étiquette de section : « 01 / FILMS ».
  static const TextStyle etiquette = TextStyle(
    fontFamily: mono,
    fontSize: 10.5,
    height: 1.2,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w600,
    color: Pal.texteDoux,
  );

  static const TextStyle meta = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    height: 1.35,
    letterSpacing: 0.4,
    color: Pal.texteDoux,
  );

  static const TextStyle chiffre = TextStyle(
    fontFamily: affiche,
    fontSize: 40,
    height: 1,
    letterSpacing: -1.5,
    color: Pal.texte,
  );
}

ThemeData construireTheme() {
  const base = ColorScheme.dark(
    primary: Pal.primaire,
    onPrimary: Pal.texte,
    secondary: Pal.primaireClaire,
    onSecondary: Pal.fond,
    surface: Pal.surface,
    onSurface: Pal.texte,
    error: Pal.danger,
    onError: Pal.texte,
    outline: Pal.bordure,
  );

  const textes = TextTheme(
    displaySmall: Typo.titre,
    headlineMedium: Typo.sousTitre,
    titleMedium: TextStyle(fontFamily: Typo.texte, fontSize: 16, fontWeight: FontWeight.w600, color: Pal.texte),
    bodyMedium: Typo.corps,
    bodySmall: Typo.meta,
    labelSmall: Typo.etiquette,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base,
    scaffoldBackgroundColor: Pal.fond,
    fontFamily: Typo.texte,
    textTheme: textes,
    dividerTheme: const DividerThemeData(color: Pal.filet, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Pal.fond,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: Typo.affiche,
        fontSize: 18,
        letterSpacing: -0.2,
        color: Pal.texte,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Pal.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: Espace.m, vertical: Espace.m),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rayons.champ),
        borderSide: const BorderSide(color: Pal.bordure),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rayons.champ),
        borderSide: const BorderSide(color: Pal.bordure),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rayons.champ),
        borderSide: const BorderSide(color: Pal.primaire),
      ),
      hintStyle: const TextStyle(color: Pal.texteDoux, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Pal.primaire,
        foregroundColor: Pal.texte,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rayons.champ)),
        padding: const EdgeInsets.symmetric(horizontal: Espace.l, vertical: Espace.m),
        textStyle: const TextStyle(fontFamily: Typo.mono, fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Pal.texte,
        side: const BorderSide(color: Pal.bordure),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rayons.champ)),
        padding: const EdgeInsets.symmetric(horizontal: Espace.l, vertical: Espace.m),
        textStyle: const TextStyle(fontFamily: Typo.mono, fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Pal.surface,
      side: BorderSide(color: Pal.bordure),
      labelStyle: TextStyle(fontFamily: Typo.mono, fontSize: 11, letterSpacing: 0.6, color: Pal.texteDoux),
      shape: StadiumBorder(),
    ),
  );
}
