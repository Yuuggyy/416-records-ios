import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/theme.dart';
import 'package:records416/domain/models/artiste.dart';
import 'package:records416/domain/models/film.dart';
import 'package:records416/domain/models/morceau.dart';
import 'package:records416/domain/models/produit.dart';
import 'package:records416/domain/recherche.dart';
import 'package:records416/features/recherche/recherche_screen.dart';

const _dreko = Artiste(
    id: 2, nom: 'Dreko', slug: 'dreko', genre: 'Rap', ville: 'Kinshasa', bio: 'Flow lent, lyrics lourds.');
const _yuggy = Artiste(
    id: 1, nom: 'Yuggy', slug: 'yuggy', genre: 'Rap / Trap', ville: 'Lubumbashi', bio: 'Fondateur du 416.');
const _zouk = Artiste(id: 3, nom: 'Maëlys', slug: 'maelys', genre: 'Zouk', ville: 'Goma');

final _index = IndexRecherche(
  artistes: const [_dreko, _yuggy, _zouk],
  morceaux: const [
    Morceau(id: 10, titre: 'Étoile du matin', artisteNom: 'Dreko', artisteSlug: 'dreko', dureeSecondes: 185, annee: 2025),
    Morceau(id: 11, titre: 'Nuit blanche', artisteNom: 'Yuggy', artisteSlug: 'yuggy', annee: 2024),
  ],
  films: [
    Film.depuisJson({
      'id': 1,
      'titre': 'Kinshasa Nights',
      'slug': 'kinshasa-nights',
      'genre': 'Thriller',
      'categorie': 'films',
      'categorie_libelle': 'Films',
      'annee': 2025,
    }),
    Film.depuisJson({
      'id': 2,
      'titre': 'Battles 416 - Episode 1',
      'slug': 'battles-1',
      'genre': 'Reality',
      'categorie': 'competition',
      'categorie_libelle': 'Compétition',
    }),
  ],
  produits: const [
    Produit(id: 1, nom: 'T-shirt 416 noir', categorie: 'Vêtements', prix: 25, tailles: ['S', 'M', 'L'], enStock: true),
    Produit(id: 2, nom: 'Casquette violette', categorie: 'Accessoires', prix: 15, enStock: true),
  ],
);

List<String> titres(List<ResultatRecherche> r) => r.map((e) => e.titre).toList();

void main() {
  const moteur = MoteurRecherche();

  group('normaliser', () {
    test('retire accents, majuscules et ponctuation', () {
      expect(normaliser('  Étoile-DU  Matin! '), 'etoile du matin');
      expect(normaliser('Maëlys'), 'maelys');
      expect(normaliser('Compétition'), 'competition');
    });
  });

  group('moteur', () {
    test('requête vide : aucun résultat', () {
      expect(moteur.chercher(_index, ''), isEmpty);
      expect(moteur.chercher(_index, '   '), isEmpty);
    });

    test('trouve un artiste par son nom, sans tenir compte des accents', () {
      expect(titres(moteur.chercher(_index, 'maelys')), contains('Maëlys'));
      expect(titres(moteur.chercher(_index, 'MAËLYS')), contains('Maëlys'));
    });

    test('trouve par type : genre d\'un artiste', () {
      final r = moteur.chercher(_index, 'rap');
      expect(titres(r), containsAll(['Dreko', 'Yuggy']));
      expect(titres(r), isNot(contains('Maëlys')));
    });

    test('trouve par type : catégorie de film et de merch', () {
      expect(titres(moteur.chercher(_index, 'competition')), contains('Battles 416 - Episode 1'));
      expect(titres(moteur.chercher(_index, 'vetements')), contains('T-shirt 416 noir'));
      expect(titres(moteur.chercher(_index, 'thriller')), contains('Kinshasa Nights'));
    });

    test('trouve le titre d\'un morceau, avec son artiste en détail', () {
      final r = moteur.chercher(_index, 'etoile');
      final morceau = r.firstWhere((e) => e.type == TypeResultat.morceau);
      expect(morceau.titre, 'Étoile du matin');
      expect(morceau.detail, contains('Dreko'));
      expect(morceau.detail, contains('3:05'));
    });

    test('trouve un morceau par le nom de son artiste', () {
      final r = moteur.chercher(_index, 'yuggy');
      expect(r.any((e) => e.type == TypeResultat.morceau && e.titre == 'Nuit blanche'), isTrue);
      expect(r.first.type, TypeResultat.artiste, reason: 'l\'artiste passe avant ses morceaux');
    });

    test('trouve un article de merch par son nom, sa taille ou sa catégorie', () {
      expect(titres(moteur.chercher(_index, 'casquette')), ['Casquette violette']);
      expect(titres(moteur.chercher(_index, 'accessoires')), ['Casquette violette']);
      expect(titres(moteur.chercher(_index, 't-shirt')), contains('T-shirt 416 noir'));
    });

    test('plusieurs mots : tous doivent correspondre', () {
      expect(titres(moteur.chercher(_index, 'nuit blanche')), ['Nuit blanche']);
      expect(moteur.chercher(_index, 'nuit dreko'), isEmpty);
      expect(titres(moteur.chercher(_index, 'rap lubumbashi')), contains('Yuggy'));
      expect(titres(moteur.chercher(_index, 'rap lubumbashi')), isNot(contains('Dreko')));
    });

    test('un fragment au milieu d\'un mot suffit', () {
      expect(titres(moteur.chercher(_index, 'shirt')), contains('T-shirt 416 noir'));
    });

    test('le nom exact passe avant une simple mention', () {
      // « 416 » est dans le nom du T-shirt, dans un film, et dans la bio d'un artiste.
      final r = moteur.chercher(_index, 'dreko');
      expect(r.first.titre, 'Dreko');
      expect(r.first.type, TypeResultat.artiste);
    });

    test('aucune correspondance', () {
      expect(moteur.chercher(_index, 'zzzzzz'), isEmpty);
    });

    test('chaque résultat garde l\'objet d\'origine pour ouvrir la bonne fiche', () {
      final r = moteur.chercher(_index, 'dreko');
      expect(r.firstWhere((e) => e.type == TypeResultat.artiste).artiste, _dreko);
      final film = moteur.chercher(_index, 'kinshasa nights').first;
      expect(film.type, TypeResultat.film);
      expect(film.film?.slug, 'kinshasa-nights');
    });

    test('le nombre de résultats est plafonné', () {
      final gros = IndexRecherche(
        produits: [for (var i = 0; i < 200; i++) Produit(id: i, nom: 'Article $i')],
      );
      expect(moteur.chercher(gros, 'article').length, MoteurRecherche.limite);
    });
  });

  group('écran', () {
    Widget app() => MaterialApp(
          theme: construireTheme(),
          home: RechercheScreen(indexInitial: _index),
        );

    testWidgets('invitation avant toute saisie, avec le décompte du catalogue', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.textContaining('Trouve un nom'), findsOneWidget);
      expect(find.textContaining('3 ARTISTES'), findsOneWidget);
      expect(find.textContaining('2 MORCEAUX'), findsOneWidget);
    });

    testWidgets('la saisie affiche les résultats, avec leur type', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('champ-recherche')), 'etoile');
      await t.pump(const Duration(milliseconds: 200));
      await t.pumpAndSettle();
      expect(find.text('Étoile du matin'), findsOneWidget);
      expect(find.text('MORCEAU'), findsOneWidget);
      expect(find.text('Nuit blanche'), findsNothing);
    });

    testWidgets('les filtres par type restreignent la liste', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('champ-recherche')), 'yuggy');
      await t.pump(const Duration(milliseconds: 200));
      await t.pumpAndSettle();
      expect(find.text('Nuit blanche'), findsOneWidget);
      expect(find.byKey(const ValueKey('resultat-artiste-Yuggy')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('filtre-artiste')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('resultat-artiste-Yuggy')), findsOneWidget);
      expect(find.text('Nuit blanche'), findsNothing);

      await t.tap(find.byKey(const ValueKey('filtre-tout')));
      await t.pumpAndSettle();
      expect(find.text('Nuit blanche'), findsOneWidget);
    });

    testWidgets('message clair quand rien ne correspond', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('champ-recherche')), 'zzzzzz');
      await t.pump(const Duration(milliseconds: 200));
      await t.pumpAndSettle();
      expect(find.text('AUCUN RÉSULTAT'), findsOneWidget);
      expect(find.textContaining('zzzzzz'), findsWidgets);
    });

    testWidgets('la croix efface la saisie et revient à l\'invitation', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('champ-recherche')), 'dreko');
      await t.pump(const Duration(milliseconds: 200));
      await t.pumpAndSettle();
      expect(find.text('Dreko'), findsWidgets);

      await t.tap(find.byKey(const ValueKey('effacer-recherche')));
      await t.pumpAndSettle();
      expect(find.textContaining('Trouve un nom'), findsOneWidget);
    });

    testWidgets('aucun débordement sur un petit écran', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('champ-recherche')), 'rap');
      await t.pump(const Duration(milliseconds: 200));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });
}
