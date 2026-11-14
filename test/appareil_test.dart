import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:records416/core/identifiant_appareil.dart';
import 'package:records416/data/depot_comptes_http.dart';
import 'package:records416/data/depot_social_http.dart';
import 'package:records416/domain/models/compte.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences?> _prefs() => SharedPreferences.getInstance();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('identifiant : créé une fois, stable, sans donnée personnelle', () async {
    final a = await IdentifiantAppareil(preferences: _prefs).lire();
    final b = await IdentifiantAppareil(preferences: _prefs).lire();
    expect(a.length, greaterThanOrEqualTo(32));
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(a), isTrue);
    expect(b, a); // relu depuis le stockage
  });

  test('identifiant : deux installations différentes ont deux identifiants', () async {
    final a = await IdentifiantAppareil(preferences: _prefs).lire();
    SharedPreferences.setMockInitialValues({});
    final b = await IdentifiantAppareil(preferences: _prefs).lire();
    expect(b, isNot(a));
  });

  test('identifiant : stockage indisponible, l\'app fonctionne quand même', () async {
    final id = IdentifiantAppareil(preferences: () async => null);
    final a = await id.lire();
    expect(a, isNotEmpty);
    expect(await id.lire(), a);
  });

  test('connexion par mot de passe : X-Appareil est envoyé', () async {
    String? vu;
    final client = MockClient((r) async {
      vu = r.headers['X-Appareil'];
      return http.Response(
          jsonEncode({'data': {'id': 1, 'identifiant': 'a@x.cd', 'email': 'a@x.cd', 'nom': 'A', 'cle': 'k'}}), 200,
          headers: {'content-type': 'application/json'});
    });
    final depot = DepotComptesHttp(client: client, baseUrl: 'https://x.test/api/',
        appareil: IdentifiantAppareil(preferences: _prefs));
    await depot.connecter(identifiant: 'a@x.cd', motDePasse: 'Motdepasse-416!');
    expect(vu, isNotNull);
    expect(vu, await IdentifiantAppareil(preferences: _prefs).lire());
  });

  test('connexion Google et Telegram : X-Appareil envoyé aussi', () async {
    final vus = <String?>[];
    final client = MockClient((r) async {
      vus.add(r.headers['X-Appareil']);
      return http.Response(
          jsonEncode({'data': {'id': 1, 'identifiant': 'a@x.cd', 'email': 'a@x.cd', 'nom': 'A', 'cle': 'k',
                                'jeton': 't', 'secret': 's', 'lien': 'https://t.me/x?start=t', 'expire_dans': 600}}), 200,
          headers: {'content-type': 'application/json'});
    });
    final depot = DepotSocialHttp(client: client, baseUrl: 'https://x.test/api/',
        appareil: IdentifiantAppareil(preferences: _prefs));
    await depot.google('jeton-google');
    await depot.demarrerTelegram();
    expect(vus.length, 2);
    expect(vus.every((v) => v != null && v.length >= 32), isTrue);
  });

  test('limite atteinte : le message du serveur est montré tel quel', () async {
    final client = MockClient((r) async => http.Response(
        jsonEncode({'data': null, 'error': 'ce compte est déjà utilisé sur un autre téléphone. Contactez-nous sur WhatsApp.'}),
        403, headers: {'content-type': 'application/json'}));
    final depot = DepotComptesHttp(client: client, baseUrl: 'https://x.test/api/',
        appareil: IdentifiantAppareil(preferences: _prefs));
    expect(
      () => depot.connecter(identifiant: 'a@x.cd', motDePasse: 'x'),
      throwsA(isA<ErreurCompte>().having((e) => e.message, 'message', contains('WhatsApp'))),
    );
  });
}
