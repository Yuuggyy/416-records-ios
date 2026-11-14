import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:records416/data/depot_pubs.dart';
import 'package:records416/features/pubs/bandeau_pub.dart';

String _json(Object o) => jsonEncode(o);

void main() {
  test('annonce reçue : champs lus, clé envoyée en en-tête', () async {
    late http.BaseRequest vue;
    final client = MockClient((r) async {
      vue = r;
      return http.Response(
          _json({
            'data': {
              'pub': {'id': 7, 'titre': 'Brasimba', 'image_url': 'https://x/y.png', 'lien': 'https://x', 'duree_secondes': 20},
              'raison': 'ok'
            },
            'error': null
          }),
          200);
    });
    final depot = DepotPubs(client: client, baseUrl: 'https://api.test/api/', cle: 'abc');
    final a = await depot.suivante('bandeau');
    expect(a, isNotNull);
    expect(a!.id, 7);
    expect(a.titre, 'Brasimba');
    expect(a.dureeSecondes, 20);
    expect(vue.url.path, '/api/abonnements/pubs/bandeau/');
    expect(vue.headers['X-Abonnement-Key'], 'abc');
  });

  test('premium (pub null), erreur serveur, panne réseau et JSON cassé : aucune pub, aucune exception', () async {
    final cas = <MockClient>[
      MockClient((_) async => http.Response(_json({'data': {'pub': null, 'raison': 'premium'}}), 200)),
      MockClient((_) async => http.Response('boom', 500)),
      MockClient((_) async => throw http.ClientException('hors ligne')),
      MockClient((_) async => http.Response('pas du json', 200)),
    ];
    for (final c in cas) {
      expect(await DepotPubs(client: c, baseUrl: 'https://api.test/api/').suivante('bandeau'), isNull);
    }
  });

  test('comptage vu/clic : bonne route, panne silencieuse', () async {
    final routes = <String>[];
    final client = MockClient((r) async {
      routes.add('${r.method} ${r.url.path}');
      return http.Response('{}', 200);
    });
    final depot = DepotPubs(client: client, baseUrl: 'https://api.test/api/');
    await depot.signaler(7, 'vu');
    await depot.signaler(7, 'clic');
    expect(routes, ['POST /api/abonnements/pubs/7/vu/', 'POST /api/abonnements/pubs/7/clic/']);
    await DepotPubs(client: MockClient((_) async => throw Exception('x')), baseUrl: 'https://api.test/api/')
        .signaler(1, 'vu');
  });

  Future<void> monter(WidgetTester tester, DepotPubs depot) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: const SizedBox.expand(), bottomNavigationBar: BandeauPub(depot: depot)),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('sans annonce (premium) : le bandeau n\'occupe aucune place', (tester) async {
    final client = MockClient((_) async => http.Response(_json({'data': {'pub': null, 'raison': 'premium'}}), 200));
    await monter(tester, DepotPubs(client: client, baseUrl: 'https://api.test/api/'));
    expect(find.text('PUB'), findsNothing);
    expect(tester.getSize(find.byType(BandeauPub)).height, 0);
  });

  testWidgets('panne réseau : aucun bandeau, aucune exception', (tester) async {
    final client = MockClient((_) async => throw http.ClientException('hors ligne'));
    await monter(tester, DepotPubs(client: client, baseUrl: 'https://api.test/api/'));
    expect(find.text('PUB'), findsNothing);
  });

  testWidgets('avec annonce : étiquette PUB, titre, affichage compté, bandeau en bas', (tester) async {
    final routes = <String>[];
    final client = MockClient((r) async {
      routes.add('${r.method} ${r.url.path}');
      if (r.method == 'GET') {
        return http.Response(
            _json({
              'data': {
                'pub': {'id': 3, 'titre': 'Brasimba', 'image_url': '', 'lien': 'https://x', 'duree_secondes': 600},
                'raison': 'ok'
              }
            }),
            200);
      }
      return http.Response('{}', 200);
    });
    await monter(tester, DepotPubs(client: client, baseUrl: 'https://api.test/api/'));
    expect(find.text('PUB'), findsOneWidget);
    expect(find.text('Brasimba'), findsOneWidget);
    expect(routes, contains('POST /api/abonnements/pubs/3/vu/'));
    expect(routes, contains('GET /api/abonnements/pubs/bandeau/'));
    expect(tester.getSize(find.byType(BandeauPub)).height, 56);
    final ecran = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getBottomLeft(find.byType(BandeauPub)).dy, ecran);
  });
}
