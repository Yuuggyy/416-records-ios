import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:records416/data/depot_abonnement_http.dart';
import 'package:records416/domain/depot_abonnement.dart';
import 'package:records416/domain/models/abonnement.dart';

void main() {
  const base = 'http://api.test/api/';

  test('les offres sont lues et triées par le serveur', () async {
    final client = MockClient((requete) async {
      expect(requete.url.toString(), '${base}abonnements/offres/');
      expect(requete.headers['X-Abonnement-Key'], 'cle-test');
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 1, 'nom': 'Mensuel', 'code': 'mensuel', 'prix': '4.00', 'actif': true},
            {'id': 2, 'nom': 'Annuel', 'code': 'annuel', 'prix': '40.00', 'actif': true},
            {'id': 3, 'nom': 'Retiré', 'code': 'vieux', 'prix': '1.00', 'actif': false},
          ],
          'error': null,
        }),
        200,
      );
    });

    final depot = DepotAbonnementHttp(cle: 'cle-test', client: client, baseUrl: base);
    final offres = await depot.offres();

    expect(offres.map((o) => o.code), ['mensuel', 'annuel']);
  });

  test('un film premium sans abonnement lève AccesRefuse avec le message du serveur', () async {
    final client = MockClient((requete) async {
      expect(requete.url.toString(), '${base}films/street-life/lecture/');
      return http.Response(
        jsonEncode({
          'data': null,
          'error': 'Cette vidéo est réservée aux abonnés 416. Souscrivez une offre pour y accéder.',
        }),
        402,
      );
    });

    final depot = DepotAbonnementHttp(cle: 'cle-test', client: client, baseUrl: base);

    await expectLater(
      depot.lectureFilm('street-life'),
      throwsA(
        isA<AccesRefuse>().having(
          (e) => e.message,
          'message',
          contains('réservée aux abonnés 416'),
        ),
      ),
    );
  });

  test('un film autorisé renvoie le flux vidéo', () async {
    final client = MockClient((requete) async {
      return http.Response(
        jsonEncode({
          'data': {
            'film': 'street-life',
            'titre': 'Street Life',
            'video_url': 'https://exemple.416/street-life.mp4',
            'abonnement_en_cours': true,
            'abonnement_reference': 'AB-2026-000001',
          },
          'error': null,
        }),
        200,
      );
    });

    final depot = DepotAbonnementHttp(cle: 'cle-test', client: client, baseUrl: base);
    final lecture = await depot.lectureFilm('street-life');

    expect(lecture.urlVideo, 'https://exemple.416/street-life.mp4');
    expect(lecture.referenceAbonnement, 'AB-2026-000001');
  });

  test('sans clé valide, le serveur répond 401 : erreur lisible, pas une exception brute', () async {
    final client = MockClient((requete) async {
      expect(requete.headers.containsKey('X-Abonnement-Key'), isFalse);
      return http.Response(
        jsonEncode({'data': null, 'error': 'authentification requise'}),
        401,
      );
    });

    final depot = DepotAbonnementHttp(cle: null, client: client, baseUrl: base);

    await expectLater(
      depot.monAbonnement(),
      throwsA(isA<ErreurAbonnement>().having((e) => e.statut, 'statut', 401)),
    );
  });

  test('la souscription envoie offre, opérateur et numéro de transaction', () async {
    Map<String, dynamic>? corps;
    final client = MockClient((requete) async {
      expect(requete.method, 'POST');
      expect(requete.url.toString(), '${base}abonnements/souscriptions/');
      corps = jsonDecode(requete.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'data': {
            'abonnement': {
              'id': 1,
              'reference': 'AB-2026-000001',
              'offre': {'id': 2, 'nom': 'Annuel', 'code': 'annuel', 'prix': '40.00'},
              'statut': 'en_attente',
              'statut_libelle': 'En attente',
              'actif': false,
            },
            'paiement': {
              'id': 5,
              'montant': '40.00',
              'devise': 'USD',
              'operateur': 'mpesa',
              'numero_transaction': 'MP2605112345',
              'statut': 'en_attente',
              'statut_libelle': 'En attente',
            },
          },
          'error': null,
        }),
        201,
      );
    });

    final depot = DepotAbonnementHttp(cle: 'cle-test', client: client, baseUrl: base);
    final resultat = await depot.souscrire(
      codeOffre: 'annuel',
      operateur: OperateurMobileMoney.mpesa,
      numeroTransaction: 'MP2605112345',
      preuve: 'SMS du 05/11',
    );

    expect(corps?['offre'], 'annuel');
    expect(corps?['operateur'], 'mpesa');
    expect(corps?['numero_transaction'], 'MP2605112345');
    expect(corps?['preuve'], 'SMS du 05/11');
    expect(resultat.abonnement.reference, 'AB-2026-000001');
    expect(resultat.paiement.enAttente, isTrue);
  });

  test('un refus de validation est remonté tel quel', () async {
    final client = MockClient((requete) async {
      return http.Response(
        jsonEncode({'data': null, 'error': 'opérateur inconnu : m-pesa'}),
        400,
      );
    });

    final depot = DepotAbonnementHttp(cle: 'cle-test', client: client, baseUrl: base);

    await expectLater(
      depot.souscrire(
        codeOffre: 'mensuel',
        operateur: OperateurMobileMoney.mpesa,
        numeroTransaction: 'MP-1',
      ),
      throwsA(isA<ErreurAbonnement>().having((e) => e.message, 'message', contains('opérateur inconnu'))),
    );
  });

  test('un serveur injoignable donne un message clair, jamais une exception réseau', () async {
    final client = MockClient((requete) async => throw const SocketExceptionSimulee());
    final depot = DepotAbonnementHttp(cle: 'cle-test', client: client, baseUrl: base);

    await expectLater(
      depot.offres(),
      throwsA(isA<ErreurAbonnement>().having((e) => e.message, 'message', contains('injoignable'))),
    );
  });

  test('un 401 avec motif expose le code ; sans motif, le code reste nul', () async {
    final avec = DepotAbonnementHttp(
      cle: 'k',
      baseUrl: base,
      client: MockClient((_) async => http.Response(
            jsonEncode({'data': null, 'error': 'authentification requise', 'meta': {'code': 'expiree'}}),
            401,
          )),
    );
    await expectLater(
      avec.monAbonnement(),
      throwsA(isA<ErreurAbonnement>().having((e) => e.code, 'code', 'expiree')),
    );
    final sans = DepotAbonnementHttp(
      cle: 'k',
      baseUrl: base,
      client: MockClient((_) async => http.Response('<html>502</html>', 401)),
    );
    await expectLater(
      sans.monAbonnement(),
      throwsA(isA<ErreurAbonnement>().having((e) => e.code, 'code', isNull)),
    );
  });
}

class SocketExceptionSimulee implements Exception {
  const SocketExceptionSimulee();
}
