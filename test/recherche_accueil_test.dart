import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/scope.dart';
import 'package:records416/core/theme.dart';
import 'package:records416/data/depot_local.dart';
import 'package:records416/features/accueil/accueil_screen.dart';
import 'package:records416/features/artistes/artiste_screen.dart';
import 'package:records416/features/recherche/recherche_screen.dart';
import 'package:records416/state/controleur_abonnement.dart';
import 'package:records416/state/controleur_compte.dart';
import 'package:records416/state/controleur_panier.dart';

import 'compte_test.dart' show DepotComptesFaux;
import 'controleur_abonnement_test.dart' show DepotAbonnementFaux, StockageMemoire;

/// Accueil réel monté sur le catalogue embarqué : aucune donnée inventée pour
/// le test, c'est ce que voit l'application hors ligne.
Widget _appli() {
  final abonnement = ControleurAbonnement(
    stockage: StockageMemoire(),
    creerDepot: (_) => DepotAbonnementFaux(),
  );
  return CatalogueScope(
    depot: DepotLocal(),
    panier: ControleurPanier(),
    abonnement: abonnement,
    compte: ControleurCompte(depot: DepotComptesFaux(), abonnement: abonnement),
    child: MaterialApp(theme: construireTheme(), home: const AccueilScreen()),
  );
}

Future<void> _ouvrirRecherche(WidgetTester t) async {
  await t.pumpWidget(_appli());
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('barre-recherche')));
  await t.pumpAndSettle();
}

Future<void> _saisir(WidgetTester t, String texte) async {
  await t.enterText(find.byKey(const ValueKey('champ-recherche')), texte);
  await t.pump(const Duration(milliseconds: 200));
  await t.pump(const Duration(milliseconds: 100));
}

/// Les tests ne doivent jamais dépendre du réseau : toutes les images distantes
/// du catalogue embarqué reçoivent un pixel transparent.
class _SansReseau extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? contexte) => _ClientImage();
}

const _pixel = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

class _ClientImage implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #getUrl || i.memberName == #openUrl) {
      return Future<HttpClientRequest>.value(_Requete());
    }
    return null;
  }
}

class _Requete implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #close) return Future<HttpClientResponse>.value(_Reponse());
    if (i.memberName == #headers) return _Entetes();
    return null;
  }
}

class _Entetes implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Reponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _pixel.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_pixel)
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  setUpAll(() => HttpOverrides.global = _SansReseau());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('la barre est visible sur l\'accueil, avant les rayons', (t) async {
    await t.pumpWidget(_appli());
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('barre-recherche')), findsOneWidget);
    expect(find.text('Artiste, morceau, film, merch…'), findsOneWidget);
  });

  testWidgets('toucher la barre ouvre la recherche, clavier prêt', (t) async {
    await _ouvrirRecherche(t);
    expect(find.byType(RechercheScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('champ-recherche')), findsOneWidget);
    final champ = t.widget<TextField>(find.byKey(const ValueKey('champ-recherche')));
    expect(champ.autofocus, isTrue);
  });

  testWidgets('le catalogue embarqué est bien indexé (artistes, films, merch, morceaux)', (t) async {
    await _ouvrirRecherche(t);
    final ecran = t.widget<RechercheScreen>(find.byType(RechercheScreen));
    expect(ecran, isNotNull);
    // L'invitation affiche le décompte réel de l'index chargé.
    expect(find.textContaining('ARTISTES'), findsOneWidget);
    expect(find.textContaining('FILMS'), findsOneWidget);
    expect(find.textContaining('MORCEAUX'), findsOneWidget);
  });

  testWidgets('chercher un artiste du catalogue', (t) async {
    await _ouvrirRecherche(t);
    await _saisir(t, 'dreko');
    expect(find.byKey(const ValueKey('resultat-artiste-Dreko')), findsOneWidget);
  });

  testWidgets('chercher par type : « rap »', (t) async {
    await _ouvrirRecherche(t);
    await _saisir(t, 'rap');
    expect(find.byKey(const ValueKey('resultat-artiste-Dreko')), findsOneWidget);
    expect(find.byKey(const ValueKey('resultat-artiste-Yuggy')), findsOneWidget);
  });

  testWidgets('chercher un film du catalogue sans tenir compte de la casse', (t) async {
    await _ouvrirRecherche(t);
    await _saisir(t, 'KINSHASA NIGHTS');
    expect(find.byKey(const ValueKey('resultat-film-Kinshasa Nights')), findsOneWidget);
  });

  testWidgets('ouvrir un résultat artiste affiche sa fiche', (t) async {
    await _ouvrirRecherche(t);
    await _saisir(t, 'dreko');
    await t.tap(find.byKey(const ValueKey('resultat-artiste-Dreko')));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(ArtisteScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('retour depuis une fiche : la recherche est conservée', (t) async {
    await _ouvrirRecherche(t);
    await _saisir(t, 'dreko');
    await t.tap(find.byKey(const ValueKey('resultat-artiste-Dreko')));
    await t.pump(const Duration(milliseconds: 600));
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('resultat-artiste-Dreko')), findsOneWidget);
  });
}
