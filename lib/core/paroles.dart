/// Une ligne de paroles. `debut` est null pour un texte non synchronisé.
class LigneParoles {
  const LigneParoles(this.texte, [this.debut]);

  final String texte;
  final Duration? debut;
}

/// Paroles d'un morceau, au format LRC (`[mm:ss.cc] phrase`) ou en texte simple.
class Paroles {
  const Paroles(this.lignes, {required this.synchronisees});

  final List<LigneParoles> lignes;

  /// Vrai si toutes les lignes portent un horodatage : le défilement est alors automatique.
  final bool synchronisees;

  bool get vide => lignes.isEmpty;

  static const Paroles aucune = Paroles([], synchronisees: false);

  static final RegExp _ligne = RegExp(r'^\s*\[(\d{1,3}):(\d{1,2}(?:[.,]\d{1,3})?)\]\s*(.*)$');

  factory Paroles.analyser(String? brut) {
    if (brut == null || brut.trim().isEmpty) return aucune;
    final lignes = <LigneParoles>[];
    var avecTemps = 0;
    for (final l in brut.replaceAll('\r', '').split('\n')) {
      final m = _ligne.firstMatch(l);
      if (m != null) {
        final minutes = int.parse(m.group(1)!);
        final sec = double.parse(m.group(2)!.replaceAll(',', '.'));
        final texte = m.group(3)!.trim();
        if (texte.isEmpty) continue;
        lignes.add(LigneParoles(texte, Duration(milliseconds: ((minutes * 60 + sec) * 1000).round())));
        avecTemps++;
      } else if (l.trim().isNotEmpty && !RegExp(r'^\s*\[[a-zA-Z]+:.*\]\s*$').hasMatch(l)) {
        lignes.add(LigneParoles(l.trim()));
      }
    }
    final sync = lignes.isNotEmpty && avecTemps == lignes.length;
    if (sync) lignes.sort((a, b) => a.debut!.compareTo(b.debut!));
    return Paroles(List.unmodifiable(lignes), synchronisees: sync);
  }

  /// Indice de la ligne en cours à cet instant (-1 avant la première).
  int indiceA(Duration position) {
    if (!synchronisees) return -1;
    var bas = 0, haut = lignes.length - 1, trouve = -1;
    while (bas <= haut) {
      final milieu = (bas + haut) >> 1;
      if (lignes[milieu].debut! <= position) {
        trouve = milieu;
        bas = milieu + 1;
      } else {
        haut = milieu - 1;
      }
    }
    return trouve;
  }
}
