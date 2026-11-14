import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:records416/data/depot_comptes_http.dart';
import 'package:records416/domain/depot_abonnement.dart';
import 'package:records416/domain/depot_comptes.dart';
import 'package:records416/domain/models/abonnement.dart';
import 'package:records416/domain/models/compte.dart';
import 'package:records416/domain/models/offre.dart';
import 'package:records416/state/controleur_abonnement.dart';
import 'package:records416/state/controleur_compte.dart';

import 'controleur_abonnement_test.dart' show StockageMemoire;

class DepotAbonnementNeutre implements DepotAbonnement {
  DepotAbonnementNeutre(this.cle);

  @override
  final String? cle;

  @override
  Future<List<Offre>> offres() async => const [];

  @override
  Future<EtatAbonnement> monAbonnement() async => const EtatAbonnement();

  @override
  Future<({Abonnement abonnement, Paiement paiement})> souscrire({
    required String codeOffre,
    required OperateurMobileMoney operateur,
    required String numeroTransaction,
    String preuve = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<LectureAutorisee> lectureFilm(String slug) => throw UnimplementedError();
}

class DepotComptesFaux implements DepotComptes {
  String? erreurSuivante;
  int? statutErreur;
  String? codeErreur;
  bool horsLigne = false;
  String cleEmise = 'cle-emise-1';
  int connexions = 0;
  int suppressions = 0;

  void _verifier() {
    if (horsLigne) throw const ErreurCompte('Serveur injoignable.');
    if (erreurSuivante != null) {
      final m = erreurSuivante!;
      erreurSuivante = null;
      throw ErreurCompte(m, statut: statutErreur, code: codeErreur);
    }
  }

  SessionCompte _session(String id, String nom) => SessionCompte(
        compte: Compte(id: 7, identifiant: id, telephone: id, nom: nom),
        cle: cleEmise,
      );

  @override
  Future<SessionCompte> inscrire({
    required String identifiant,
    required String motDePasse,
    String nom = '',
  }) async {
    _verifier();
    return _session(identifiant, nom);
  }

  @override
  Future<SessionCompte> connecter({required String identifiant, required String motDePasse}) async {
    connexions++;
    _verifier();
    return _session(identifiant, 'Mireille');
  }

  @override
  Future<Compte> moi(String cle) async {
    _verifier();
    return const Compte(id: 7, identifiant: '+243970000001', nom: 'Mireille');
  }

  @override
  Future<void> supprimer({required String cle, required String motDePasse}) async {
    _verifier();
    suppressions++;
  }
}

({ControleurCompte compte, ControleurAbonnement abo, StockageMemoire stock, DepotComptesFaux depot})
    monter({String? cleStockee}) {
  final stock = StockageMemoire()..valeur = cleStockee;
  final abo = ControleurAbonnement(stockage: stock, creerDepot: DepotAbonnementNeutre.new);
  final depot = DepotComptesFaux();
  return (compte: ControleurCompte(depot: depot, abonnement: abo), abo: abo, stock: stock, depot: depot);
}

DepotComptesHttp depotHttp(http.Response Function(http.Request) repondre) {
  return DepotComptesHttp(
    client: MockClient((r) async => repondre(r)),
    baseUrl: 'https://api.test/api/',
  );
}

http.Response json(int statut, Object corps) => http.Response.bytes(
      utf8.encode(jsonEncode(corps)),
      statut,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('Compte (modèle)', () {
    test('lit le JSON du serveur', () {
      final c = Compte.depuisJson(const {
        'id': 3, 'identifiant': 'a@b.cd', 'email': 'a@b.cd', 'telephone': '', 'nom': 'Aline', 'staff': true,
      });
      expect(c.id, 3);
      expect(c.libelle, 'Aline');
      expect(c.staff, isTrue);
    });

    test('champs absents ou mal typés ne plantent pas', () {
      final c = Compte.depuisJson(const {'id': 'x', 'nom': 5, 'staff': 'oui'});
      expect(c.id, 0);
      expect(c.nom, '');
      expect(c.staff, isFalse);
    });

    test('libellé retombe sur l\'identifiant sans nom', () {
      expect(const Compte(id: 1, identifiant: '+243970000001').libelle, '+243970000001');
    });

    test('égalité par valeur (Equatable)', () {
      expect(const Compte(id: 1, identifiant: 'a'), const Compte(id: 1, identifiant: 'a'));
    });
  });

  group('DepotComptesHttp', () {
    test('inscription : envoie le bon corps et lit la clé', () async {
      late http.Request vue;
      final depot = depotHttp((r) {
        vue = r;
        return json(201, {
          'data': {'id': 1, 'identifiant': 'a@b.cd', 'email': 'a@b.cd', 'nom': 'A', 'cle': 'K1'},
          'error': null,
        });
      });
      final s = await depot.inscrire(identifiant: ' a@b.cd ', motDePasse: 'Secret123!', nom: ' A ');
      expect(vue.url.toString(), 'https://api.test/api/comptes/inscription/');
      expect(jsonDecode(vue.body), {'identifiant': 'a@b.cd', 'mot_de_passe': 'Secret123!', 'nom': 'A'});
      expect(s.cle, 'K1');
    });

    test('moi : la clé voyage dans l\'en-tête, jamais dans l\'URL', () async {
      late http.Request vue;
      final depot = depotHttp((r) {
        vue = r;
        return json(200, {'data': {'id': 1, 'identifiant': 'x'}, 'error': null});
      });
      await depot.moi('CLE-SECRETE');
      expect(vue.headers['X-Abonnement-Key'], 'CLE-SECRETE');
      expect(vue.url.toString().contains('CLE-SECRETE'), isFalse);
    });

    test('le message du serveur est remonté tel quel (409)', () async {
      final depot = depotHttp((_) => json(409, {'data': null, 'error': 'un compte existe déjà avec ce téléphone'}));
      expect(
        () => depot.inscrire(identifiant: '0970000001', motDePasse: 'Secret123!'),
        throwsA(isA<ErreurCompte>()
            .having((e) => e.message, 'message', 'un compte existe déjà avec ce téléphone')
            .having((e) => e.statut, 'statut', 409)),
      );
    });

    test('404 (pont Base44) : message clair, pas d\'erreur technique', () async {
      final depot = depotHttp((_) => http.Response('not found', 404));
      expect(
        () => depot.connecter(identifiant: 'a@b.cd', motDePasse: 'x'),
        throwsA(isA<ErreurCompte>().having((e) => e.message, 'message', contains('pas encore disponibles'))),
      );
    });

    test('429 : message d\'attente', () async {
      final depot = depotHttp((_) => http.Response('', 429));
      expect(
        () => depot.connecter(identifiant: 'a@b.cd', motDePasse: 'x'),
        throwsA(isA<ErreurCompte>().having((e) => e.message, 'message', contains('Trop d\'essais'))),
      );
    });

    test('500 HTML : jamais de HTML affiché', () async {
      final depot = depotHttp((_) => http.Response('<html>Server Error</html>', 500));
      expect(
        () => depot.connecter(identifiant: 'a@b.cd', motDePasse: 'x'),
        throwsA(isA<ErreurCompte>().having((e) => e.message.contains('<html'), 'html', isFalse)),
      );
    });

    test('réseau coupé : message lisible', () async {
      final depot = DepotComptesHttp(
        client: MockClient((_) async => throw http.ClientException('boom')),
        baseUrl: 'https://api.test/api/',
      );
      expect(
        () => depot.connecter(identifiant: 'a@b.cd', motDePasse: 'x'),
        throwsA(isA<ErreurCompte>().having((e) => e.message, 'message', contains('injoignable'))),
      );
    });

    test('succès sans clé : réponse refusée', () async {
      final depot = depotHttp((_) => json(200, {'data': {'id': 1, 'identifiant': 'x'}, 'error': null}));
      expect(() => depot.connecter(identifiant: 'a', motDePasse: 'b'), throwsA(isA<ErreurCompte>()));
    });
  });

  group('ControleurCompte', () {
    test('inscription : compte ouvert ET clé remise au contrôleur d\'abonnement', () async {
      final m = monter();
      final ok = await m.compte.inscrire(identifiant: '+243970000001', motDePasse: 'Secret123!', nom: 'Mireille');
      expect(ok, isTrue);
      expect(m.compte.connecte, isTrue);
      expect(m.abo.cle, 'cle-emise-1');
      expect(m.stock.valeur, 'cle-emise-1');
    });

    test('connexion refusée : message affiché, pas de clé, pas de compte', () async {
      final m = monter();
      m.depot
        ..erreurSuivante = 'identifiant ou mot de passe incorrect'
        ..statutErreur = 401;
      final ok = await m.compte.connecter(identifiant: 'a@b.cd', motDePasse: 'faux');
      expect(ok, isFalse);
      expect(m.compte.erreur, 'identifiant ou mot de passe incorrect');
      expect(m.compte.connecte, isFalse);
      expect(m.abo.aUneCle, isFalse);
    });

    test('déconnexion : compte et clé effacés', () async {
      final m = monter();
      await m.compte.connecter(identifiant: 'a@b.cd', motDePasse: 'x');
      await m.compte.deconnecter();
      expect(m.compte.connecte, isFalse);
      expect(m.stock.valeur, isNull);
      expect(m.abo.aUneCle, isFalse);
    });

    test('double appui : une seule connexion envoyée', () async {
      final m = monter();
      final a = m.compte.connecter(identifiant: 'a@b.cd', motDePasse: 'x');
      final b = m.compte.connecter(identifiant: 'a@b.cd', motDePasse: 'x');
      await Future.wait([a, b]);
      expect(m.depot.connexions, 1);
    });

    test('démarrage avec clé valide : retrouve le compte', () async {
      final m = monter(cleStockee: 'cle-ok');
      await m.abo.initialiser();
      await m.compte.initialiser();
      expect(m.compte.connecte, isTrue);
      expect(m.compte.compte!.nom, 'Mireille');
    });

    test('démarrage avec clé révoquée (motif confirmé) : clé effacée, visiteur, motif expliqué', () async {
      final m = monter(cleStockee: 'cle-perimee');
      await m.abo.initialiser();
      m.depot
        ..erreurSuivante = 'clé refusée'
        ..statutErreur = 401
        ..codeErreur = 'remplacee';
      await m.compte.initialiser();
      expect(m.compte.connecte, isFalse);
      expect(m.stock.valeur, isNull);
      expect(m.abo.motifDeconnexion, contains('autre téléphone'));
    });

    test('démarrage avec un 401 SANS motif : la clé est conservée (pas de déconnexion pour rien)', () async {
      final m = monter(cleStockee: 'cle-ok');
      await m.abo.initialiser();
      m.depot
        ..erreurSuivante = 'clé refusée'
        ..statutErreur = 401;
      await m.compte.initialiser();
      expect(m.compte.connecte, isFalse);
      expect(m.stock.valeur, 'cle-ok');
      expect(m.abo.aUneCle, isTrue);
      expect(m.abo.motifDeconnexion, isNull);
    });

    test('un 500 ou 503 au démarrage ne déconnecte pas', () async {
      for (final statut in [500, 502, 503, 429]) {
        final m = monter(cleStockee: 'cle-ok');
        await m.abo.initialiser();
        m.depot
          ..erreurSuivante = 'indisponible'
          ..statutErreur = statut;
        await m.compte.initialiser();
        expect(m.stock.valeur, 'cle-ok', reason: 'statut $statut');
      }
    });

    test('retour au premier plan : le compte est retrouvé après un démarrage raté', () async {
      final m = monter(cleStockee: 'cle-ok');
      await m.abo.initialiser();
      m.depot.horsLigne = true;
      await m.compte.initialiser();
      expect(m.compte.connecte, isFalse);
      m.depot.horsLigne = false;
      await m.compte.reverifier();
      expect(m.compte.connecte, isTrue);
      expect(m.stock.valeur, 'cle-ok');
    });

    test('retour au premier plan avec clé révoquée : déconnexion avec explication', () async {
      final m = monter(cleStockee: 'cle-ok');
      await m.abo.initialiser();
      m.depot
        ..erreurSuivante = 'clé refusée'
        ..statutErreur = 401
        ..codeErreur = 'desactivee';
      await m.compte.reverifier();
      expect(m.stock.valeur, isNull);
      expect(m.abo.motifDeconnexion, contains('désactivé'));
    });

    test('se reconnecter efface le message de déconnexion', () async {
      final m = monter(cleStockee: 'cle-ok');
      await m.abo.initialiser();
      await m.abo.oublierCleRevoquee('expiree');
      expect(m.abo.motifDeconnexion, contains('expiré'));
      await m.compte.connecter(identifiant: 'a@b.cd', motDePasse: 'x');
      expect(m.abo.motifDeconnexion, isNull);
    });

    test('le serveur lit le motif dans meta.code (comptes et abonnements)', () async {
      final depot = depotHttp((_) => json(401, {
            'data': null,
            'error': "clé d'accès absente ou refusée",
            'meta': {'code': 'remplacee'},
          }));
      await expectLater(
        depot.moi('x'),
        throwsA(isA<ErreurCompte>().having((e) => e.code, 'code', 'remplacee')),
      );
      final sans = depotHttp((_) => json(401, {'data': null, 'error': 'refusée'}));
      await expectLater(
        sans.moi('x'),
        throwsA(isA<ErreurCompte>().having((e) => e.code, 'code', isNull)),
      );
    });

    test('démarrage hors ligne : la clé est conservée', () async {
      final m = monter(cleStockee: 'cle-ok');
      await m.abo.initialiser();
      m.depot.horsLigne = true;
      await m.compte.initialiser();
      expect(m.compte.connecte, isFalse);
      expect(m.stock.valeur, 'cle-ok');
    });

    test('suppression : compte, clé et stockage effacés', () async {
      final m = monter();
      await m.compte.connecter(identifiant: 'a@b.cd', motDePasse: 'x');
      final ok = await m.compte.supprimer('x');
      expect(ok, isTrue);
      expect(m.depot.suppressions, 1);
      expect(m.stock.valeur, isNull);
      expect(m.compte.connecte, isFalse);
    });

    test('suppression refusée (mauvais mot de passe) : le compte reste', () async {
      final m = monter();
      await m.compte.connecter(identifiant: 'a@b.cd', motDePasse: 'x');
      m.depot
        ..erreurSuivante = 'mot de passe incorrect'
        ..statutErreur = 401;
      final ok = await m.compte.supprimer('faux');
      expect(ok, isFalse);
      expect(m.compte.connecte, isTrue);
      expect(m.compte.erreur, 'mot de passe incorrect');
    });
  });
}
