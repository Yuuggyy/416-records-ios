import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/paroles.dart';
import 'package:records416/features/lecteur/vue_paroles.dart';

const _lrc = '''
[00:01.00] Court
[00:04.00] Une phrase très très longue qui doit passer sur plusieurs lignes sans jamais chevaucher la suivante ni être tronquée par des points de suspension
[00:09.00] Encore une ligne moyenne pour voir l'espacement entre deux phrases
[00:13.00] Et une dernière phrase vraiment interminable, avec des virgules, des mots, des mots, des mots, pour forcer trois ou quatre lignes sur un petit écran de téléphone
[00:20.00] Fin
''';

Widget _app(Paroles p, int active, Size taille, {ValueChanged<Duration>? onChercher}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: taille),
        child: Scaffold(
          body: SizedBox(
            width: taille.width,
            height: taille.height,
            child: VueParoles(paroles: p, ligneActive: active, onChercher: onChercher ?? (_) {}),
          ),
        ),
      ),
    );

void main() {
  final p = Paroles.analyser(_lrc);

  for (final t in const [Size(320, 600), Size(390, 800), Size(820, 1100), Size(1280, 800)]) {
    testWidgets('sans debordement ni chevauchement a ${t.width.toInt()}px', (tester) async {
      tester.view.physicalSize = t;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(p, 1, t));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      // Les lignes sont rangées les unes sous les autres sans se recouvrir.
      final boites = [
        for (final l in p.lignes) tester.getRect(find.text(l.texte)),
      ];
      for (var i = 1; i < boites.length; i++) {
        expect(boites[i].top, greaterThanOrEqualTo(boites[i - 1].bottom - 0.5),
            reason: 'la ligne $i chevauche la précédente');
      }
      // Aucune ellipse : le texte complet est présent.
      expect(find.textContaining('interminable'), findsOneWidget);
    });
  }

  testWidgets('la ligne active est centree dans la vue', (tester) async {
    const t = Size(390, 800);
    tester.view.physicalSize = t;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(p, 0, t));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_app(p, 3, t));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1200));
    final r = tester.getRect(find.textContaining('interminable'));
    expect(r.center.dy, inInclusiveRange(t.height * 0.2, t.height * 0.6));
  });

  testWidgets('toucher une ligne synchronisee renvoie son debut', (tester) async {
    const t = Size(390, 800);
    tester.view.physicalSize = t;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Duration? vu;
    await tester.pumpWidget(_app(p, 0, t, onChercher: (d) => vu = d));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Court'));
    expect(vu, const Duration(seconds: 1));
  });

  testWidgets('texte simple : toutes les lignes visibles, rien de cliquable', (tester) async {
    const t = Size(390, 800);
    tester.view.physicalSize = t;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final simple = Paroles.analyser('Premier vers\nDeuxième vers\nTroisième vers');
    await tester.pumpWidget(_app(simple, -1, t));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Deuxième vers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
