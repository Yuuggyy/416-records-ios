import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/features/lecteur/lecteur_screen.dart';
import 'package:records416/state/controleur_lecture.dart';

/// Moteur simulé : reproduit ouverture, pause, fin de média et pannes.
class MoteurFaux implements MoteurLecture {
  MoteurFaux({this.echecOuverture = false, this.erreurMoteur = false, this.dureeTotale});

  bool echecOuverture;
  bool erreurMoteur;
  Duration? dureeTotale;

  Uri? ouverte;
  int ouvertures = 0;
  int lectures = 0;
  int pauses = 0;
  bool ferme = false;
  Duration _position = Duration.zero;
  bool _enLecture = false;
  VoidCallback? _rappel;

  @override
  Future<void> ouvrir(Uri source) async {
    ouvertures++;
    if (echecOuverture) throw Exception('réseau');
    ouverte = source;
  }

  @override
  Future<void> lire() async {
    lectures++;
    _enLecture = true;
  }

  @override
  Future<void> pause() async {
    pauses++;
    _enLecture = false;
  }

  @override
  Future<void> aller(Duration position) async => _position = position;

  @override
  Future<void> volume(double valeur) async => volumeRegle = valeur;

  double volumeRegle = 1;

  @override
  Future<void> fermer() async => ferme = true;

  @override
  Duration get position => _position;

  @override
  Duration get duree => dureeTotale ?? const Duration(minutes: 10);

  @override
  bool get enLecture => _enLecture;

  @override
  bool get enErreur => erreurMoteur;

  @override
  String? get messageErreur => erreurMoteur ? 'flux illisible' : null;

  @override
  void ecouter(VoidCallback rappel) => _rappel = rappel;

  /// Simule l'avancée de la lecture jusqu'à [p] et notifie le contrôleur.
  void avancerA(Duration p) {
    _position = p;
    // Comme le plugin réel : arrivé au bout, le média n'est plus « en lecture ».
    if (p >= duree) _enLecture = false;
    _rappel?.call();
  }

  void declencherErreur() {
    erreurMoteur = true;
    _rappel?.call();
  }
}

const _bonne = 'https://exemple.cd/video.mp4';

void main() {
  group('ControleurLecture : sources', () {
    for (final mauvaise in <String?>[null, '', '   ', 'pas une url', 'javascript:alert(1)', 'file:///etc/passwd', 'ftp://x.cd/a.mp4', 'https://']) {
      test('refuse la source « $mauvaise » sans appeler le moteur', () async {
        final moteur = MoteurFaux();
        final c = ControleurLecture(moteur: moteur);
        await c.preparer(mauvaise);
        expect(c.etat, EtatLecture.erreur);
        expect(c.erreur, contains('pas encore disponible'));
        expect(moteur.ouvertures, 0);
      });
    }

    test('source https valide : prête, moteur ouvert sur la bonne adresse', () async {
      final moteur = MoteurFaux();
      final c = ControleurLecture(moteur: moteur);
      await c.preparer(' $_bonne ');
      expect(c.etat, EtatLecture.prete);
      expect(moteur.ouverte.toString(), _bonne);
    });
  });

  group('ControleurLecture : pilotage', () {
    test('basculer : lecture puis pause', () async {
      final moteur = MoteurFaux();
      final c = ControleurLecture(moteur: moteur);
      await c.preparer(_bonne);
      await c.basculer();
      expect(c.etat, EtatLecture.enCours);
      expect(c.enLecture, isTrue);
      await c.basculer();
      expect(c.etat, EtatLecture.enPause);
      expect(moteur.pauses, 1);
    });

    test('basculer pendant la préparation ou après erreur ne fait rien', () async {
      final moteur = MoteurFaux();
      final c = ControleurLecture(moteur: moteur);
      await c.basculer();
      expect(moteur.lectures, 0);
      await c.preparer(null);
      await c.basculer();
      expect(moteur.lectures, 0);
    });

    test('fin du média : état terminé, puis relecture depuis le début', () async {
      final moteur = MoteurFaux(dureeTotale: const Duration(seconds: 30));
      final c = ControleurLecture(moteur: moteur);
      await c.preparer(_bonne);
      await c.basculer();
      moteur.avancerA(const Duration(seconds: 30));
      expect(c.etat, EtatLecture.terminee);
      await c.basculer();
      expect(moteur.position, Duration.zero);
      expect(c.etat, EtatLecture.enCours);
    });

    test('progression bornée entre 0 et 1, et 0 si durée inconnue', () async {
      final moteur = MoteurFaux(dureeTotale: const Duration(seconds: 100));
      final c = ControleurLecture(moteur: moteur);
      await c.preparer(_bonne);
      moteur.avancerA(const Duration(seconds: 25));
      expect(c.progression, closeTo(0.25, 0.001));
      moteur.avancerA(const Duration(seconds: 500));
      expect(c.progression, 1.0);

      final inconnu = MoteurFaux(dureeTotale: Duration.zero);
      final c2 = ControleurLecture(moteur: inconnu);
      await c2.preparer(_bonne);
      expect(c2.progression, 0);
    });

    test('chercher saute à la bonne position et borne la fraction', () async {
      final moteur = MoteurFaux(dureeTotale: const Duration(seconds: 200));
      final c = ControleurLecture(moteur: moteur);
      await c.preparer(_bonne);
      await c.chercher(0.5);
      expect(moteur.position, const Duration(seconds: 100));
      await c.chercher(9);
      expect(moteur.position, const Duration(seconds: 200));
      await c.chercher(-3);
      expect(moteur.position, Duration.zero);
    });
  });

  group('ControleurLecture : pannes', () {
    test('échec d\'ouverture : message lisible, jamais d\'exception', () async {
      final c = ControleurLecture(moteur: MoteurFaux(echecOuverture: true));
      await c.preparer(_bonne);
      expect(c.etat, EtatLecture.erreur);
      expect(c.erreur, contains('connexion'));
    });

    test('erreur du moteur pendant la lecture : passe en erreur', () async {
      final moteur = MoteurFaux();
      final c = ControleurLecture(moteur: moteur);
      await c.preparer(_bonne);
      await c.basculer();
      moteur.declencherErreur();
      expect(c.etat, EtatLecture.erreur);
      expect(c.erreur, 'flux illisible');
    });

    test('réessayer après un échec réseau relance l\'ouverture', () async {
      final moteur = MoteurFaux(echecOuverture: true);
      final c = ControleurLecture(moteur: moteur);
      await c.preparer(_bonne);
      expect(c.etat, EtatLecture.erreur);
      moteur.echecOuverture = false;
      await c.reessayer(_bonne);
      expect(c.etat, EtatLecture.prete);
      expect(moteur.ouvertures, 2);
    });

    test('libération : le moteur est fermé et plus aucune notification après', () async {
      final moteur = MoteurFaux();
      final c = ControleurLecture(moteur: moteur);
      await c.preparer(_bonne);
      var notifications = 0;
      c.addListener(() => notifications++);
      c.dispose();
      expect(moteur.ferme, isTrue);
      moteur.avancerA(const Duration(seconds: 5)); // ne doit pas lever d'exception
      expect(notifications, 0);
    });
  });

  group('LecteurScreen', () {
    testWidgets('source absente : message clair, bouton Réessayer, aucune URL affichée', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LecteurScreen(titre: 'Street Life', source: null, moteur: MoteurFaux()),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('pas encore disponible'), findsOneWidget);
      expect(find.text('RÉESSAYER'), findsOneWidget);
    });

    testWidgets('source valide : titre affiché, l\'adresse du flux ne l\'est jamais', (tester) async {
      final moteur = MoteurFaux();
      await tester.pumpWidget(MaterialApp(
        home: LecteurScreen(titre: 'Kinshasa Nights', source: _bonne, moteur: moteur),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Kinshasa Nights'), findsOneWidget);
      expect(find.textContaining('exemple.cd'), findsNothing);
      // La lecture démarre toute seule : le bouton central propose la pause.
      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
      expect(moteur.lectures, 1);
    });


    testWidgets('au repos : seulement la vidéo (ni titre, ni flèche, ni commandes)', (tester) async {
      final moteur = MoteurFaux();
      await tester.pumpWidget(MaterialApp(
        home: LecteurScreen(
          titre: 'Kinshasa Nights',
          sousTitre: 'FILM',
          source: _bonne,
          moteur: moteur,
          qualites: const [QualiteAudio('HD', _bonne), QualiteAudio('SD', _bonne)],
        ),
      ));
      await tester.pumpAndSettle();
      // Départ : commandes visibles quelques secondes.
      expect(find.text('Kinshasa Nights'), findsOneWidget);
      // Après le délai, en lecture, tout disparaît sauf l'image.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Kinshasa Nights'), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('FILM'), findsNothing);
      expect(find.text('QUALITÉ'), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('un toucher fait réapparaître titre, retour et commandes ; un second les retire', (tester) async {
      final moteur = MoteurFaux();
      await tester.pumpWidget(MaterialApp(
        home: LecteurScreen(titre: 'Kinshasa Nights', source: _bonne, moteur: moteur),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Kinshasa Nights'), findsNothing);
      await tester.tapAt(const Offset(60, 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Kinshasa Nights'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
      // Un second toucher, avant la disparition automatique, les retire tout de suite.
      await tester.tapAt(const Offset(60, 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Kinshasa Nights'), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      // Et la minuterie ne les rappelle pas.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Kinshasa Nights'), findsNothing);
    });

    testWidgets('en pause, titre et commandes restent affichés', (tester) async {
      final moteur = MoteurFaux();
      await tester.pumpWidget(MaterialApp(
        home: LecteurScreen(titre: 'Kinshasa Nights', source: _bonne, moteur: moteur),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.pause_circle_filled));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Kinshasa Nights'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    });

    testWidgets('la flèche de retour ferme le lecteur', (tester) async {
      final moteur = MoteurFaux();
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute(
              builder: (_) => LecteurScreen(titre: 'Film X', source: _bonne, moteur: moteur),
            )),
            child: const Text('ouvrir'),
          ),
        ),
      ));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Film X'), findsNothing);
      expect(find.text('ouvrir'), findsOneWidget);
    });

    testWidgets('toucher pause arrête la lecture ; quitter ferme le moteur', (tester) async {
      final moteur = MoteurFaux();
      await tester.pumpWidget(MaterialApp(
        home: LecteurScreen(titre: 'Film', source: _bonne, moteur: moteur),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.pause_circle_filled));
      await tester.pump();
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
      expect(moteur.pauses, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(moteur.ferme, isTrue);
    });

    testWidgets('boutons ±15 s : sautent de 15 secondes, bornés', (tester) async {
      final moteur = MoteurFaux();
      await tester.pumpWidget(MaterialApp(
        home: LecteurScreen(titre: 'Film', source: _bonne, moteur: moteur),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.fast_forward));
      await tester.pump();
      expect(moteur.position, const Duration(seconds: 15));
      await tester.tap(find.byIcon(Icons.replay));
      await tester.tap(find.byIcon(Icons.replay));
      await tester.pump();
      expect(moteur.position, Duration.zero);
    });

    testWidgets('le volume se règle ; un morceau à deux qualités propose le choix', (tester) async {
      final moteur = MoteurFaux();
      await tester.pumpWidget(MaterialApp(
        home: LecteurScreen(
          titre: 'Ndoki',
          source: _bonne,
          audioSeul: true,
          moteur: moteur,
          qualites: const [QualiteAudio('Super fan', _bonne), QualiteAudio('Compressée', _bonne)],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Super fan'), findsOneWidget);
      expect(find.text('Compressée'), findsOneWidget);
      await tester.tap(find.text('Compressée'));
      await tester.pumpAndSettle();
      expect(moteur.ouvertures, 2);
      // Audio seul : pas de bouton plein écran.
      expect(find.byIcon(Icons.fullscreen), findsNothing);
    });
  });
}
