import 'package:flutter_test/flutter_test.dart';
import 'package:records416/domain/classement.dart';
import 'package:records416/domain/models/candidat.dart';

Candidat _candidat(
  String id, {
  int streams = 0,
  int votes = 0,
  Map<CritereJury, double> notes = const {},
  bool elimine = false,
}) {
  return Candidat(
    id: id,
    nom: 'Candidat $id',
    ville: 'Kinshasa',
    photoUrl: '',
    videoUrl: '',
    streams: streams,
    votes: votes,
    notesJury: notes,
    elimine: elimine,
  );
}

void main() {
  const moteur = MoteurClassement();

  group('Normalisation du score public', () {
    test('le meilleur engagement public vaut toujours 100', () {
      final lignes = moteur.classer([
        _candidat('a', streams: 1000, votes: 100),
        _candidat('b', streams: 250, votes: 25),
      ]);

      final premier = lignes.firstWhere((l) => l.candidat.id == 'a');
      expect(premier.scorePublic, 100.0);
      expect(lignes.firstWhere((l) => l.candidat.id == 'b').scorePublic, 25.0);
    });

    test('écoutes et votes pèsent chacun la moitié de l engagement', () {
      // a : 1000 écoutes seulement · b : 200 votes seulement
      final lignes = moteur.classer([
        _candidat('a', streams: 1000),
        _candidat('b', votes: 1000),
      ]);

      expect(lignes.length, 2);
      // Les deux ont le même engagement brut (500) : égalité parfaite.
      expect(lignes[0].scoreFinal, lignes[1].scoreFinal);
      expect(lignes[0].rang, 1);
      expect(lignes[1].rang, 1);
    });

    test('un engagement public nul donne 0 sans division par zéro', () {
      final lignes = moteur.classer([_candidat('a'), _candidat('b')]);
      expect(lignes.every((l) => l.scorePublic == 0.0), isTrue);
    });
  });

  group('Pondération 60 / 40', () {
    test('un candidat sans note du jury ne reçoit que la part publique', () {
      final lignes = moteur.classer([
        _candidat('a', streams: 1000),
        _candidat('b', streams: 500),
      ]);

      final premier = lignes.first;
      expect(premier.candidat.id, 'a');
      expect(premier.juryEnAttente, isTrue);
      expect(premier.scoreJury, isNull);
      expect(premier.scoreFinal, 60.0); // 100 × 0,6 + 0
      expect(premier.apportJury, 0.0);
    });

    test('le jury peut faire gagner un candidat moins populaire', () {
      final lignes = moteur.classer([
        _candidat('populaire', streams: 10000, votes: 1000),
        _candidat(
          'jure',
          streams: 5000,
          votes: 500,
          notes: {
            CritereJury.voix: 10,
            CritereJury.presence: 10,
            CritereJury.originalite: 10,
            CritereJury.interpretation: 10,
          },
        ),
      ]);

      // populaire : 60 pts public + 0 jury = 60
      // jure : 30 pts public + 40 jury = 70
      expect(lignes.first.candidat.id, 'jure');
      expect(lignes.first.scoreFinal, 70.0);
      expect(lignes.last.scoreFinal, 60.0);
      expect(lignes.first.rang, 1);
      expect(lignes.last.rang, 2);
    });

    test('les notes du jury sont normalisées avant pondération', () {
      final lignes = moteur.classer([
        _candidat('fort', streams: 1000, notes: {
          CritereJury.voix: 8,
          CritereJury.presence: 8,
        }),
        _candidat('faible', streams: 1000, notes: {
          CritereJury.voix: 4,
          CritereJury.presence: 4,
        }),
      ]);

      final fort = lignes.firstWhere((l) => l.candidat.id == 'fort');
      final faible = lignes.firstWhere((l) => l.candidat.id == 'faible');
      expect(fort.scoreJury, 100.0);
      expect(faible.scoreJury, 50.0);
      expect(fort.scoreFinal, 100.0); // 60 + 40
      expect(faible.scoreFinal, 80.0); // 60 + 20
    });
  });

  group('Cas limites', () {
    test('liste vide ne produit aucune ligne', () {
      expect(moteur.classer(const []), isEmpty);
    });

    test('les candidats éliminés ne sont pas classés', () {
      final lignes = moteur.classer([
        _candidat('actif', streams: 100),
        _candidat('sorti', streams: 9000, elimine: true),
      ]);
      expect(lignes.length, 1);
      expect(lignes.single.candidat.id, 'actif');
    });

    test('un seul candidat est mécaniquement à 100 sur le public', () {
      // Comportement assumé de la formule (valeur / maximum) : documenté ici
      // pour que l'interface ajoute une mention « édition en cours ».
      final lignes = moteur.classer([_candidat('seul', streams: 10)]);
      expect(lignes.single.scorePublic, 100.0);
    });

    test('ex æquo : même rang, puis saut de rang', () {
      final lignes = moteur.classer([
        _candidat('a', streams: 1000),
        _candidat('b', streams: 1000),
        _candidat('c', streams: 100),
      ]);
      expect(lignes.map((l) => l.rang).toList(), [1, 1, 3]);
    });
  });
}
