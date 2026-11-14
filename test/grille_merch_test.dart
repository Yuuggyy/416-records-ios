import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/theme.dart';
import 'package:records416/core/widgets/cartes.dart';
import 'package:records416/domain/models/produit.dart';

/// Reproduit exactement le calcul de colonnes de l'écran merch.
Widget grille(List<Produit> produits) => MaterialApp(
      home: Scaffold(
        body: LayoutBuilder(builder: (context, dim) {
          final largeur = dim.maxWidth;
          final colonnes = largeur < 600 ? 2 : (largeur < 1000 ? 3 : 4);
          final utile = largeur > 1100 ? 1100.0 : largeur;
          final marge = (largeur - utile) / 2 + Espace.m;
          final cote = (utile - 2 * Espace.m - (colonnes - 1) * Espace.m) / colonnes;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(marge, Espace.s, marge, Espace.xl),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colonnes,
              mainAxisSpacing: Espace.m,
              crossAxisSpacing: Espace.m,
              mainAxisExtent: cote + 108,
            ),
            itemCount: produits.length,
            itemBuilder: (_, i) => CarteProduit(produit: produits[i], onAjouter: () {}),
          );
        }),
      ),
    );

void main() {
  final produits = List.generate(
      8,
      (i) => Produit(
          id: i,
          nom: 'Veste brodée édition limitée « Kinshasa la belle » numéro $i',
          prix: 45,
          enStock: true,
          categorie: 'Vêtements'));

  for (final (largeur, attendu) in [(320.0, 2), (390.0, 2), (600.0, 3), (820.0, 3), (1280.0, 4)]) {
    testWidgets('largeur $largeur px : $attendu colonnes, aucun débordement', (t) async {
      t.view.physicalSize = Size(largeur, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(grille(produits));
      await t.pump();
      expect(tester_exception(t), isNull);
      final x = <double>{
        for (final e in t.widgetList(find.byType(CarteProduit)).toList().asMap().keys.take(attendu + 1))
          t.getTopLeft(find.byType(CarteProduit).at(e)).dx.roundToDouble()
      };
      expect(x.length, attendu, reason: 'positions horizontales distinctes');
      // Les cartes gardent la même largeur sur toute la ligne.
      final l0 = t.getSize(find.byType(CarteProduit).at(0)).width;
      final l1 = t.getSize(find.byType(CarteProduit).at(1)).width;
      expect((l0 - l1).abs(), lessThan(0.5));
      if (largeur >= 1280) expect(l0, lessThan(280), reason: 'les cartes ne s\'étirent pas');
    });
  }
}

Object? tester_exception(WidgetTester t) => t.takeException();
