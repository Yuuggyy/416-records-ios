import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:records416/data/service_paiement_http.dart';
import 'package:records416/domain/paiement_en_ligne.dart';
import 'package:records416/features/paiement/paiement_en_ligne_screen.dart';
import 'package:records416/state/controleur_paiement.dart';

/// Service en mémoire : l'état du dépôt se règle depuis le test.
class ServiceFaux implements ServicePaiementEnLigne {
  ServiceFaux({this.disponible = true});

  bool disponible;
  EtatDepot etatServeur = EtatDepot.enAttente;
  String motif = '';
  String? refus;
  int lancements = 0;
  int lectures = 0;
  String? dernierNumero;
  OperateurEnLigne? dernierOperateur;

  @override
  Future<({bool disponible, bool sandbox, List<OperateurEnLigne> operateurs})> operateurs() async =>
      (disponible: disponible, sandbox: true, operateurs: OperateurEnLigne.values);

  DepotLance _depot() => const DepotLance(
      identifiant: 'dep-1', montant: '5.00', devise: 'USD', operateur: 'M-Pesa', message: 'ok', sandbox: true);

  @override
  Future<DepotLance> payerAbonnement({
    required String codeOffre,
    required String numero,
    required OperateurEnLigne operateur,
  }) async {
    lancements++;
    dernierNumero = numero;
    dernierOperateur = operateur;
    if (refus != null) throw ErreurPaiement(refus!);
    return _depot();
  }

  @override
  Future<DepotLance> payerCommande({
    required String reference,
    required String whatsapp,
    required String numero,
    required OperateurEnLigne operateur,
  }) async =>
      payerAbonnement(codeOffre: reference, numero: numero, operateur: operateur);

  @override
  Future<SuiviDepot> etat(String identifiant) async {
    lectures++;
    return SuiviDepot(etat: etatServeur, motif: motif);
  }
}

void main() {
  group('validation du numéro', () {
    test('formats acceptés', () {
      for (final n in ['81 234 5678', '0812345678', '+243 81 234 5678', '243812345678', '00243812345678']) {
        expect(ControleurPaiement.verifierNumero(n), isNull, reason: n);
      }
    });
    test('formats refusés', () {
      for (final n in ['', '123', 'abc', '8123456789012']) {
        expect(ControleurPaiement.verifierNumero(n), isNotNull, reason: n);
      }
    });
  });

  group('contrôleur', () {
    test('numéro invalide ou opérateur absent : rien n\'est envoyé', () async {
      final s = ServiceFaux();
      final c = ControleurPaiement(service: s);
      await c.payerAbonnement(codeOffre: 'mensuel', numero: '12', operateur: OperateurEnLigne.mpesa);
      expect(c.erreur, contains('invalide'));
      await c.payerAbonnement(codeOffre: 'mensuel', numero: '0812345678', operateur: null);
      expect(c.erreur, contains('opérateur'));
      expect(s.lancements, 0);
      expect(c.phase, PhasePaiement.saisie);
      c.dispose();
    });

    test('paiement réussi : attente puis succès, minuteur arrêté', () async {
      final s = ServiceFaux();
      final c = ControleurPaiement(service: s, intervalle: const Duration(milliseconds: 20));
      await c.payerAbonnement(codeOffre: 'mensuel', numero: '0812345678', operateur: OperateurEnLigne.orange);
      expect(c.phase, PhasePaiement.attente);
      expect(s.dernierOperateur, OperateurEnLigne.orange);
      s.etatServeur = EtatDepot.paye;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.phase, PhasePaiement.reussi);
      final lectures = s.lectures;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(s.lectures, lectures, reason: 'plus d\'interrogation après le résultat');
      c.dispose();
    });

    test('refus du client : message lisible en français', () async {
      final s = ServiceFaux();
      final c = ControleurPaiement(service: s, intervalle: const Duration(milliseconds: 20));
      await c.payerAbonnement(codeOffre: 'mensuel', numero: '0812345678', operateur: OperateurEnLigne.mpesa);
      s.etatServeur = EtatDepot.echoue;
      s.motif = 'The customer did not approve the payment';
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.phase, PhasePaiement.echec);
      expect(c.erreur, contains('pas validé'));
      c.dispose();
    });

    test('solde insuffisant traduit', () async {
      final s = ServiceFaux();
      final c = ControleurPaiement(service: s, intervalle: const Duration(milliseconds: 20));
      await c.payerAbonnement(codeOffre: 'mensuel', numero: '0812345678', operateur: OperateurEnLigne.mpesa);
      s.etatServeur = EtatDepot.echoue;
      s.motif = 'INSUFFICIENT_BALANCE';
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.erreur, contains('Solde insuffisant'));
      c.dispose();
    });

    test('serveur qui refuse la demande : échec avec son message', () async {
      final s = ServiceFaux()..refus = 'le depot a ete refuse';
      final c = ControleurPaiement(service: s);
      await c.payerAbonnement(codeOffre: 'mensuel', numero: '0812345678', operateur: OperateurEnLigne.airtel);
      expect(c.phase, PhasePaiement.echec);
      expect(c.erreur, 'le depot a ete refuse');
      c.recommencer();
      expect(c.phase, PhasePaiement.saisie);
      c.dispose();
    });

    test('délai dépassé : on cesse d\'interroger sans conclure à un échec', () async {
      final s = ServiceFaux();
      final c = ControleurPaiement(
          service: s, intervalle: const Duration(milliseconds: 10), delaiMax: const Duration(milliseconds: 40));
      await c.payerAbonnement(codeOffre: 'mensuel', numero: '0812345678', operateur: OperateurEnLigne.mpesa);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(c.delaiDepasse, isTrue);
      expect(c.phase, PhasePaiement.attente);
      await c.verifier(); // vérification manuelle toujours possible
      s.etatServeur = EtatDepot.paye;
      await c.verifier();
      expect(c.phase, PhasePaiement.reussi);
      c.dispose();
    });

    test('double appui : un seul paiement lancé', () async {
      final s = ServiceFaux();
      final c = ControleurPaiement(service: s, intervalle: const Duration(seconds: 5));
      final a = c.payerAbonnement(codeOffre: 'mensuel', numero: '0812345678', operateur: OperateurEnLigne.mpesa);
      final b = c.payerAbonnement(codeOffre: 'mensuel', numero: '0812345678', operateur: OperateurEnLigne.mpesa);
      await Future.wait([a, b]);
      expect(s.lancements, 1);
      c.dispose();
    });
  });

  group('service HTTP', () {
    test('abonnement : bon chemin, clé en en-tête, jamais de montant envoyé', () async {
      late http.Request vue;
      final client = MockClient((r) async {
        vue = r;
        return http.Response(
            jsonEncode({
              'data': {'deposit_id': 'abc', 'montant': '5.00', 'devise': 'USD', 'operateur': 'M-Pesa', 'mode': 'sandbox'},
              'error': null
            }),
            201);
      });
      final s = ServicePaiementHttp(cle: 'k', client: client, baseUrl: 'https://api.test/api/');
      final d = await s.payerAbonnement(codeOffre: 'mensuel', numero: '0812345678', operateur: OperateurEnLigne.mpesa);
      expect(vue.url.path, '/api/abonnements/paiement-en-ligne/abonnement/');
      expect(vue.headers['X-Abonnement-Key'], 'k');
      final corps = jsonDecode(vue.body) as Map;
      expect(corps.keys, containsAll(['offre', 'numero', 'operateur']));
      expect(corps.containsKey('montant'), isFalse);
      expect(corps['operateur'], 'VODACOM_MPESA_COD');
      expect(d.identifiant, 'abc');
      expect(d.sandbox, isTrue);
    });

    test('erreurs : 401 invite à se connecter, message serveur repris, panne réseau lisible', () async {
      Future<Object?> essai(MockClient c) async {
        try {
          await ServicePaiementHttp(client: c, baseUrl: 'https://api.test/api/')
              .payerAbonnement(codeOffre: 'm', numero: '1', operateur: OperateurEnLigne.mpesa);
          return null;
        } on ErreurPaiement catch (e) {
          return e;
        }
      }

      final e401 = await essai(MockClient((_) async => http.Response(jsonEncode({'error': 'authentification requise'}), 401)));
      expect((e401 as ErreurPaiement).message, contains('Connectez-vous'));
      final e400 = await essai(MockClient((_) async => http.Response(jsonEncode({'error': 'numero invalide'}), 400)));
      expect((e400 as ErreurPaiement).message, 'numero invalide');
      final ereseau = await essai(MockClient((_) async => throw http.ClientException('x')));
      expect((ereseau as ErreurPaiement).message, contains('injoignable'));
    });

    test('état : traduit paye / echoue / en_attente', () async {
      for (final (brut, attendu) in [
        ('paye', EtatDepot.paye),
        ('echoue', EtatDepot.echoue),
        ('en_attente', EtatDepot.enAttente),
        ('autre', EtatDepot.inconnu),
      ]) {
        final s = ServicePaiementHttp(
            client: MockClient((_) async => http.Response(jsonEncode({'data': {'statut': brut}}), 200)),
            baseUrl: 'https://api.test/api/');
        expect((await s.etat('abc')).etat, attendu, reason: brut);
      }
    });

    test('opérateurs : indisponible si le serveur ne répond pas', () async {
      final s = ServicePaiementHttp(client: MockClient((_) async => http.Response('boom', 500)), baseUrl: 'https://api.test/api/');
      expect((await s.operateurs()).disponible, isFalse);
    });
  });

  group('écran', () {
    Future<void> monter(WidgetTester t, ServiceFaux s) async {
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: PaiementEnLigneScreen(
          titre: 'Mensuel',
          resume: '5.00 USD · 30 jours',
          service: s,
          intervalle: const Duration(milliseconds: 30),
          lancer: (c, numero, op) => c.payerAbonnement(codeOffre: 'mensuel', numero: numero, operateur: op),
        ),
      ));
      await t.pump();
      await t.pump();
    }

    testWidgets('mode test annoncé, numéros de test visibles', (t) async {
      await monter(t, ServiceFaux());
      expect(find.textContaining('MODE TEST'), findsOneWidget);
      expect(find.textContaining('81 345 6789'), findsOneWidget);
    });

    testWidgets('sans opérateur choisi : message, rien n\'est envoyé', (t) async {
      final s = ServiceFaux();
      await monter(t, s);
      await t.enterText(find.byKey(const ValueKey('numero')), '0813456789');
      await t.tap(find.byKey(const ValueKey('payer')));
      await t.pump();
      expect(find.textContaining('Choisissez votre opérateur'), findsOneWidget);
      expect(s.lancements, 0);
    });

    testWidgets('parcours complet : saisie, attente, succès, écran fermé', (t) async {
      final s = ServiceFaux();
      await monter(t, s);
      await t.tap(find.byKey(const ValueKey('op-VODACOM_MPESA_COD')));
      await t.enterText(find.byKey(const ValueKey('numero')), '0813456789');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('payer')));
      await t.pump();
      await t.pump();
      expect(find.text('Validez sur votre téléphone'), findsOneWidget);
      s.etatServeur = EtatDepot.paye;
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Paiement reçu'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('échec : message et bouton Réessayer', (t) async {
      final s = ServiceFaux()..refus = 'refusé par l\'opérateur';
      await monter(t, s);
      await t.tap(find.byKey(const ValueKey('op-ORANGE_COD')));
      await t.enterText(find.byKey(const ValueKey('numero')), '0893456789');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('payer')));
      await t.pump();
      await t.pump();
      expect(find.text('Paiement non abouti'), findsOneWidget);
      expect(find.text('refusé par l\'opérateur'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('reessayer')));
      await t.pump();
      expect(find.byKey(const ValueKey('payer')), findsOneWidget);
    });

    testWidgets('paiement indisponible : bouton désactivé', (t) async {
      await monter(t, ServiceFaux(disponible: false));
      final bouton = t.widget<FilledButton>(find.byKey(const ValueKey('payer')));
      expect(bouton.onPressed, isNull);
      expect(find.textContaining('indisponible'), findsOneWidget);
    });
  });
}
