import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/paroles.dart';
import 'package:records416/state/controleur_lecture.dart';

/// Moteur qui imite le vrai lecteur : après un saut, la position reste
/// l'ANCIENNE pendant un court instant, puis rejoint la cible.
class MoteurLent implements MoteurLecture {
  MoteurLent({this.retard = const Duration(milliseconds: 300)});

  final Duration retard;
  Duration _pos = Duration.zero;
  Duration? _vers;
  bool _lit = false;
  VoidCallback? _rappel;

  /// Fait avancer l'horloge simulée.
  Duration maintenant = Duration.zero;

  @override
  Future<void> aller(Duration position) async {
    _vers = position;
    _arrive = maintenant + retard;
  }

  Duration _arrive = Duration.zero;

  /// Avance le temps simulé de [dt].
  void avancer(Duration dt) {
    maintenant += dt;
    if (_vers != null && maintenant >= _arrive) {
      _pos = _vers!;
      _vers = null;
    } else if (_vers == null && _lit) {
      _pos += dt;
    }
    _rappel?.call();
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
  Future<void> ouvrir(Uri source) async {}
  @override
  Future<void> lire() async => _lit = true;
  @override
  Future<void> pause() async => _lit = false;
  @override
  Future<void> volume(double valeur) async {}
  @override
  Future<void> fermer() async {}
  @override
  void ecouter(VoidCallback rappel) => _rappel = rappel;
}

const _lrc = '''
[00:10.00] A
[00:20.00] B
[00:30.00] C
[00:40.00] D
[00:50.00] E
''';

void main() {
  final p = Paroles.analyser(_lrc);

  Future<(ControleurLecture, MoteurLent)> pret() async {
    final m = MoteurLent();
    final c = ControleurLecture(moteur: m);
    await c.preparer('https://exemple.test/a.mp3');
    await c.lancer();
    return (c, m);
  }

  test('apres un saut, la position montree est la cible tout de suite (pas l\'ancienne)', () async {
    final (c, m) = await pret();
    await c.chercher(0.2); // 48 s
    // Le moteur n'a pas encore bougé : sans correctif, on lirait 0 s -> ligne -1.
    expect(m.position, Duration.zero);
    expect(c.position, const Duration(seconds: 48));
    expect(p.indiceA(c.position), 3); // D (40 s), pas -1
    c.dispose();
  });

  test('aller en avant puis en arriere ne revient jamais sur une ancienne ligne', () async {
    final (c, m) = await pret();
    await c.chercher(0.2); // 48 s -> D
    await c.chercher(0.05); // 12 s -> A, avant que le premier saut soit confirmé
    expect(p.indiceA(c.position), 0);
    // Le moteur confirme les sauts en retard : la ligne reste A.
    for (var i = 0; i < 12; i++) {
      m.avancer(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(p.indiceA(c.position), 0, reason: 'étape $i : la ligne a sauté sur une ancienne cible');
    }
    c.dispose();
  });

  test('plusieurs appuis +15 s s\'additionnent au lieu de se chevaucher', () async {
    final (c, m) = await pret();
    await c.sauter(15);
    await c.sauter(15);
    await c.sauter(15);
    expect(c.position, const Duration(seconds: 45));
    expect(m.position, Duration.zero);
    c.dispose();
  });

  test('un glisse rapide sur la barre finit sur le DERNIER point', () async {
    final (c, m) = await pret();
    for (final f in [0.1, 0.3, 0.5, 0.2, 0.7, 0.4]) {
      await c.chercher(f);
    }
    final fin = Duration(milliseconds: (const Duration(minutes: 4).inMilliseconds * 0.4).round());
    expect(c.position, fin);
    for (var i = 0; i < 40; i++) {
      m.avancer(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    // Une fois le moteur rattrapé, on lui rend la main : même endroit (± lecture).
    expect((c.position - fin).inMilliseconds.abs() < 6000, isTrue);
    expect(c.enSaut, isFalse);
    c.dispose();
  });

  test('si le moteur ne confirme jamais, on lui rend la main apres 2,5 s', () async {
    final m = MoteurLent(retard: const Duration(hours: 1));
    final c = ControleurLecture(moteur: m);
    await c.preparer('https://exemple.test/a.mp3');
    await c.chercher(0.5);
    expect(c.enSaut, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 2700));
    expect(c.enSaut, isFalse);
    c.dispose();
  });
}
