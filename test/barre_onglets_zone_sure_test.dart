import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/main.dart' show BarreOnglets;

Widget _monter(EdgeInsets zoneSure) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          padding: zoneSure,
          viewPadding: zoneSure,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: BarreOnglets(index: 0, onChanger: (_) {}),
        ),
      ),
    );

void main() {
  void ecran(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  testWidgets('iPhone : la barre d\'onglets laisse la place à l\'indicateur d\'accueil', (t) async {
    ecran(t);
    await t.pumpWidget(_monter(const EdgeInsets.only(bottom: 34)));
    final barre = t.getRect(find.byType(BarreOnglets));
    final etiquette = t.getRect(find.text('ACCUEIL'));
    // Le bas du texte doit rester au-dessus de la zone de l'indicateur (34 px).
    expect(844 - etiquette.bottom, greaterThanOrEqualTo(34));
    expect(barre.bottom, 844);
  });

  testWidgets('Android à boutons : aucune marge en trop', (t) async {
    ecran(t);
    await t.pumpWidget(_monter(EdgeInsets.zero));
    final etiquette = t.getRect(find.text('ACCUEIL'));
    expect(844 - etiquette.bottom, lessThan(30));
  });

  testWidgets('la zone sûre agrandit la barre de la bonne hauteur', (t) async {
    ecran(t);
    await t.pumpWidget(_monter(EdgeInsets.zero));
    final sans = t.getSize(find.byType(BarreOnglets)).height;
    ecran(t);
    await t.pumpWidget(_monter(const EdgeInsets.only(bottom: 34)));
    final avec = t.getSize(find.byType(BarreOnglets)).height;
    expect(avec - sans, closeTo(34, 0.5));
  });
}
