import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/features/lecteur/lecteur_morceau_screen.dart';
import 'package:records416/features/lecteur/lecteur_screen.dart' show QualiteAudio;
import 'package:records416/state/controleur_lecture.dart';

/// Moteur lent : le saut n'est confirmé qu'après [retard] (comme le vrai lecteur).
class MoteurLentEcran implements MoteurLecture {
  Duration _pos = Duration.zero, _vers = Duration.zero, _arrive = Duration.zero;
  bool _saut = false, _lit = false;
  Duration horloge = Duration.zero;
  VoidCallback? _rappel;

  void avancer(Duration dt) {
    horloge += dt;
    if (_saut && horloge >= _arrive) {
      _pos = _vers;
      _saut = false;
    } else if (!_saut && _lit) {
      _pos += dt;
    }
    _rappel?.call();
  }

  @override
  Future<void> aller(Duration p) async {
    _vers = p;
    _saut = true;
    _arrive = horloge + const Duration(milliseconds: 400);
  }

  @override
  Duration get position => _pos;
  @override
  Duration get duree => const Duration(minutes: 4);
  @override
  bool get enLecture => _lit;
  @override
  bool get enErreur => false;
  @override
  String? get messageErreur => null;
  @override
  Future<void> ouvrir(Uri s) async {}
  @override
  Future<void> lire() async => _lit = true;
  @override
  Future<void> pause() async => _lit = false;
  @override
  Future<void> volume(double v) async {}
  @override
  Future<void> fermer() async {}
  @override
  void ecouter(VoidCallback r) => _rappel = r;
}

const _lrc = '''
[00:05.00] Premiere ligne
[00:15.00] Deuxieme ligne
[00:25.00] Troisieme ligne
[00:35.00] Quatrieme ligne
[00:45.00] Cinquieme ligne
[00:55.00] Sixieme ligne
[01:05.00] Septieme ligne
[01:15.00] Huitieme ligne
''';

void main() {
  testWidgets('barre avant/arriere : la ligne en gras suit toujours la barre, jamais une ancienne cible', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final m = MoteurLentEcran();
    await tester.pumpWidget(MaterialApp(
      home: LecteurMorceauScreen(
        titre: 'T',
        artiste: 'A',
        qualites: const [QualiteAudio('Standard', 'https://exemple.test/a.mp3')],
        paroles: _lrc,
        moteur: m,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Afficher les paroles'));
    await tester.pump(const Duration(milliseconds: 100));

    final barre = find.byType(Slider).first;
    final r = tester.getRect(barre);
    // Aller vers 60 % puis revenir vers 10 % AVANT que le premier saut ne soit confirmé.
    await tester.tapAt(Offset(r.left + r.width * 0.30, r.center.dy)); // 72 s
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(Offset(r.left + r.width * 0.06, r.center.dy)); // ~14 s
    for (var i = 0; i < 20; i++) {
      m.avancer(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 14 s + lecture ~ 2 s -> ligne 'Deuxieme' (15 s) doit être la ligne active, pas 'Septieme'.
    final deux = tester.getRect(find.text('Deuxieme ligne'));
    final sept = tester.getRect(find.text('Septieme ligne'));
    expect(deux.center.dy, lessThan(sept.center.dy));
    expect(deux.center.dy, inInclusiveRange(200, 500), reason: 'la ligne active est centrée à l\'écran');
    expect(tester.takeException(), isNull);
  });

  testWidgets('toucher une ligne : la vue se recentre sur elle et y reste', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final m = MoteurLentEcran();
    await tester.pumpWidget(MaterialApp(
      home: LecteurMorceauScreen(
        titre: 'T',
        artiste: 'A',
        qualites: const [QualiteAudio('Standard', 'https://exemple.test/a.mp3')],
        paroles: _lrc,
        moteur: m,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Afficher les paroles'));
    await tester.pump(const Duration(milliseconds: 100));
    final avant = tester.getRect(find.text('Troisieme ligne'));
    await tester.tapAt(avant.center);
    await tester.pump();
    expect(m._vers, const Duration(seconds: 25), reason: 'le toucher doit demander le saut');
    for (var i = 0; i < 25; i++) {
      m.avancer(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final r = tester.getRect(find.text('Troisieme ligne'));
    expect(r.center.dy, inInclusiveRange(200, 500));
    expect(tester.takeException(), isNull);
  });
}
