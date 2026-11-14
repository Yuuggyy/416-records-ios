import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/scope.dart';
import 'package:records416/core/theme.dart';
import 'package:records416/data/depot_local.dart';
import 'package:records416/features/abonnement/offres_screen.dart';
import 'package:records416/features/accueil/accueil_screen.dart';
import 'package:records416/features/compte/compte_screen.dart';
import 'package:records416/features/merch/merch_screen.dart';
import 'package:records416/features/merch/panier_screen.dart';
import 'package:records416/features/paiement/paiement_en_ligne_screen.dart';
import 'package:records416/state/controleur_abonnement.dart';
import 'package:records416/state/controleur_compte.dart';
import 'package:records416/state/controleur_panier.dart';

import 'compte_test.dart' show DepotComptesFaux;
import 'controleur_abonnement_test.dart' show DepotAbonnementFaux, StockageMemoire;
import 'paiement_en_ligne_test.dart' show ServiceFaux;

/// Tailles réelles d'appareils (points logiques) : petit Android, iPhone SE,
/// téléphone courant, grand téléphone, tablette portrait, tablette paysage.
const _ecrans = <String, Size>{
  'petit-android 320x568': Size(320, 568),
  'iphone-se 375x667': Size(375, 667),
  'courant 393x852': Size(393, 852),
  'grand 430x932': Size(430, 932),
  'tablette 768x1024': Size(768, 1024),
  'tablette-paysage 1024x768': Size(1024, 768),
};

/// 1.0 normal, 1.3 « grand » courant, 2.0 accessibilité maximale.
const _textes = <double>[1.0, 1.3, 2.0];

Widget _appli(Widget ecran) {
  final abonnement = ControleurAbonnement(
    stockage: StockageMemoire(),
    creerDepot: (_) => DepotAbonnementFaux(),
  );
  return CatalogueScope(
    depot: DepotLocal(),
    panier: ControleurPanier(),
    abonnement: abonnement,
    compte: ControleurCompte(depot: DepotComptesFaux(), abonnement: abonnement),
    child: MaterialApp(theme: construireTheme(), home: ecran),
  );
}

final _ecransATester = <String, Widget Function()>{
  'accueil': () => const AccueilScreen(),
  'offres abonnement': () => const OffresScreen(),
  'compte': () => const CompteScreen(),
  'compte (inscription)': () => const CompteScreen(inscription: true),
  'boutique merch': () => const MerchScreen(),
  'panier': () => const PanierScreen(),
  'paiement mobile money': () => PaiementEnLigneScreen(
        titre: 'Abonnement mensuel 416',
        resume: '1.25 USD · 30 jours',
        service: ServiceFaux(),
        intervalle: const Duration(milliseconds: 30),
        lancer: (c, numero, op) => c.payerAbonnement(codeOffre: 'mensuel', numero: numero, operateur: op),
      ),
};

void main() {
  setUpAll(() => HttpOverrides.global = _SansReseau());
  tearDownAll(() => HttpOverrides.global = null);

  for (final ecran in _ecransATester.entries) {
    for (final taille in _ecrans.entries) {
      for (final echelle in _textes) {
        testWidgets('${ecran.key} · ${taille.key} · texte x$echelle : aucun débordement', (t) async {
          t.view.physicalSize = taille.value * 2.0;
          t.view.devicePixelRatio = 2.0;
          addTearDown(t.view.reset);
          await t.pumpWidget(MediaQuery(
            data: MediaQueryData(size: taille.value, textScaler: TextScaler.linear(echelle)),
            child: _appli(ecran.value()),
          ));
          // pas de pumpAndSettle : certains écrans animent en boucle.
          for (var i = 0; i < 6; i++) {
            await t.pump(const Duration(milliseconds: 120));
          }
          // Un débordement (RenderFlex overflowed) est enregistré comme exception.
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}

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
