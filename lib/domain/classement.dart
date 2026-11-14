import 'dart:math' as math;

import 'models/candidat.dart';

/// Ligne de classement calculée, avec le détail qui explique la position.
class LigneClassement {
  const LigneClassement({
    required this.candidat,
    required this.scorePublic,
    required this.scoreJury,
    required this.scoreFinal,
    required this.rang,
  });

  final Candidat candidat;

  /// Score public normalisé sur 100 : (engagement / meilleur engagement) × 100.
  final double scorePublic;

  /// Score jury sur 100. Null si le jury n'a pas encore noté.
  final double? scoreJury;

  /// 60 % public + 40 % jury. Si le jury n'a pas noté, vaut le score public,
  /// et [juryEnAttente] permet à l'interface de le dire clairement.
  final double scoreFinal;

  final int rang;

  bool get juryEnAttente => scoreJury == null;

  /// Part du score final apportée par le public, en points.
  double get apportPublic => scorePublic * 0.6;

  /// Part apportée par le jury, en points (0 tant qu'il n'a pas noté).
  double get apportJury => (scoreJury ?? 0) * 0.4;
}

/// Moteur de classement du concours 416 Records.
///
/// Règle du brief : 60 % engagement public (50 % écoutes, 50 % votes),
/// 40 % jury. Chaque famille de notes est d'abord ramenée sur 100 par
/// la formule (valeur ÷ maximum de l'édition) × 100, afin qu'un critère
/// exprimé en millions d'écoutes ne mange pas un critère exprimé en votes.
///
/// Limite assumée et documentée : avec un seul candidat en lice, la
/// formule le place mécaniquement à 100 sur 100. L'écran de classement
/// doit donc afficher une mention « édition en cours » tant que l'effectif
/// est inférieur à deux.
class MoteurClassement {
  const MoteurClassement({this.poidsPublic = 0.6, this.poidsJury = 0.4});

  final double poidsPublic;
  final double poidsJury;

  List<LigneClassement> classer(List<Candidat> candidats) {
    final enLice = candidats.where((c) => !c.elimine).toList(growable: false);
    if (enLice.isEmpty) return const [];

    final meilleurEngagement = enLice.map((c) => c.engagementBrut).reduce(math.max);
    final meilleuresNotes = enLice
        .map((c) => c.noteJurySur100)
        .whereType<double>()
        .fold<double>(0, math.max);

    final lignes = enLice.map((c) {
      final scorePublic = meilleurEngagement <= 0
          ? 0.0
          : (c.engagementBrut / meilleurEngagement) * 100;
      final jury = c.noteJurySur100;
      final scoreJuryNormalise = jury == null
          ? null
          : (meilleuresNotes <= 0 ? 0.0 : (jury / meilleuresNotes) * 100);

      final scoreFinal = _arrondi(
        (scorePublic * poidsPublic) + ((scoreJuryNormalise ?? 0) * poidsJury),
      );

      return LigneClassement(
        candidat: c,
        scorePublic: _arrondi(scorePublic),
        scoreJury: scoreJuryNormalise == null ? null : _arrondi(scoreJuryNormalise),
        scoreFinal: scoreFinal,
        rang: 0,
      );
    }).toList();

    lignes.sort((a, b) {
      final parScore = b.scoreFinal.compareTo(a.scoreFinal);
      if (parScore != 0) return parScore;
      return b.scorePublic.compareTo(a.scorePublic);
    });

    return _attribuerRangs(lignes);
  }

  /// Rang de compétition : 1, 1, 3 (deux ex æquo partagent la même place).
  List<LigneClassement> _attribuerRangs(List<LigneClassement> triees) {
    final resultat = <LigneClassement>[];
    var rangCourant = 0;
    double? scorePrecedent;

    for (var i = 0; i < triees.length; i++) {
      final ligne = triees[i];
      if (scorePrecedent == null || ligne.scoreFinal != scorePrecedent) {
        rangCourant = i + 1;
        scorePrecedent = ligne.scoreFinal;
      }
      resultat.add(LigneClassement(
        candidat: ligne.candidat,
        scorePublic: ligne.scorePublic,
        scoreJury: ligne.scoreJury,
        scoreFinal: ligne.scoreFinal,
        rang: rangCourant,
      ));
    }
    return resultat;
  }

  double _arrondi(double v) => (v * 100).roundToDouble() / 100;
}
