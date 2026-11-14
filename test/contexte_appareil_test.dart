import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:records416/core/contexte_appareil.dart';
import 'package:records416/core/identifiant_appareil.dart';
import 'package:records416/data/depot_social_http.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences?> _prefs() => SharedPreferences.getInstance();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('contexteAppareil', () {
    test('Android natif : apk', () {
      expect(contexteAppareil(estWeb: false, plateforme: TargetPlatform.android), 'apk');
    });
    test('iPhone natif : ios', () {
      expect(contexteAppareil(estWeb: false, plateforme: TargetPlatform.iOS), 'ios');
    });
    test('navigateur : web', () {
      expect(contexteAppareil(estWeb: true, installe: () => false), 'web');
    });
    test('site ajouté à l\'écran d\'accueil : pwa', () {
      expect(contexteAppareil(estWeb: true, installe: () => true), 'pwa');
    });
    test('le web ignore la plateforme (Android Chrome reste web sans installation)', () {
      expect(
        contexteAppareil(estWeb: true, plateforme: TargetPlatform.android, installe: () => false),
        'web',
      );
    });
  });

  group('envoi au serveur', () {
    http.Response _ok() => http.Response(
          jsonEncode({'data': {'jeton': 't', 'secret': 's', 'lien': 'https://t.me/x?start=t', 'expire_dans': 600}}),
          201,
          headers: {'content-type': 'application/json'},
        );

    test('Telegram : le contexte part dans X-Contexte', () async {
      final vus = <String?>[];
      final client = MockClient((r) async {
        vus.add(r.headers['X-Contexte']);
        return _ok();
      });
      final depot = DepotSocialHttp(
        client: client,
        baseUrl: 'https://x.test/api/',
        appareil: IdentifiantAppareil(preferences: _prefs),
        contexte: () => 'apk',
      );
      await depot.demarrerTelegram();
      expect(vus, ['apk']);
    });

    test('contexte illisible : la connexion part quand même, sans en-tête', () async {
      final vus = <String?>[];
      final client = MockClient((r) async {
        vus.add(r.headers['X-Contexte']);
        return _ok();
      });
      final depot = DepotSocialHttp(
        client: client,
        baseUrl: 'https://x.test/api/',
        appareil: IdentifiantAppareil(preferences: _prefs),
        contexte: () => throw StateError('boom'),
      );
      final demande = await depot.demarrerTelegram();
      expect(demande.jeton, 't');
      expect(vus, [null]);
    });

    test('l\'en-tête n\'est envoyé que pour la demande Telegram', () async {
      final vus = <String?>[];
      final client = MockClient((r) async {
        vus.add(r.headers['X-Contexte']);
        return http.Response(jsonEncode({'data': {'google': true, 'telegram': true}}), 200,
            headers: {'content-type': 'application/json'});
      });
      final depot = DepotSocialHttp(
        client: client,
        baseUrl: 'https://x.test/api/',
        appareil: IdentifiantAppareil(preferences: _prefs),
        contexte: () => 'apk',
      );
      await depot.fournisseurs();
      expect(vus, [null]);
    });
  });
}
