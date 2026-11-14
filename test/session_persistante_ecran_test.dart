import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/scope.dart';
import 'package:records416/core/theme.dart';
import 'package:records416/data/depot_local.dart';
import 'package:records416/domain/depot_abonnement.dart';
import 'package:records416/domain/depot_social.dart';
import 'package:records416/domain/models/compte.dart';
import 'package:records416/features/compte/compte_screen.dart';
import 'package:records416/main.dart' show Shell;
import 'package:records416/state/controleur_abonnement.dart';
import 'package:records416/state/controleur_compte.dart';
import 'package:records416/state/controleur_panier.dart';

import 'compte_test.dart' show DepotComptesFaux;
import 'controleur_abonnement_test.dart' show DepotAbonnementFaux, StockageMemoire;

({Widget app, ControleurAbonnement abo, ControleurCompte compte, DepotComptesFaux depot, StockageMemoire stock})
    monter(Widget ecran, {String? cle, ErreurAbonnement? echecEtat}) {
  final stock = StockageMemoire(cle);
  final abo = ControleurAbonnement(
    stockage: stock,
    creerDepot: (_) => DepotAbonnementFaux()..echecEtat = echecEtat,
  );
  final depot = DepotComptesFaux();
  final compte = ControleurCompte(depot: depot, abonnement: abo, social: _SocialFaux());
  return (
    app: CatalogueScope(
      depot: DepotLocal(),
      panier: ControleurPanier(),
      abonnement: abo,
      compte: compte,
      child: MaterialApp(theme: construireTheme(), home: ecran),
    ),
    abo: abo,
    compte: compte,
    depot: depot,
    stock: stock,
  );
}

class _SocialFaux implements DepotSocial {
  @override
  Future<FournisseursConnexion> fournisseurs() async =>
      const FournisseursConnexion(google: true, telegram: true);
  @override
  Future<SessionCompte> google(String jetonIdentite) => throw UnimplementedError();
  @override
  Future<DemandeTelegram> demarrerTelegram() => throw UnimplementedError();
  @override
  Future<SessionCompte?> etatTelegram(String jeton) => throw UnimplementedError();
}

void main() {
  testWidgets('révocation confirmée : l\'écran de connexion explique pourquoi', (tester) async {
    final m = monter(const CompteScreen(),
        cle: 'k', echecEtat: const ErreurAbonnement('refusée', statut: 401, code: 'remplacee'));
    await tester.pumpWidget(m.app);
    await m.abo.initialiser();
    await tester.pump();
    expect(find.byKey(const Key('motif-deconnexion')), findsOneWidget);
    expect(find.textContaining('autre téléphone'), findsOneWidget);
  });

  testWidgets('simple incident (401 sans motif) : aucun message et la clé reste', (tester) async {
    final m = monter(const CompteScreen(),
        cle: 'k', echecEtat: const ErreurAbonnement('refusée', statut: 401));
    await tester.pumpWidget(m.app);
    await m.abo.initialiser();
    await tester.pump();
    expect(find.byKey(const Key('motif-deconnexion')), findsNothing);
    expect(m.stock.valeur, 'k');
  });

  testWidgets('retour au premier plan : le compte est retrouvé sans reconnexion', (tester) async {
    final m = monter(const Shell(), cle: 'k');
    await m.abo.initialiser();
    m.depot.horsLigne = true; // le démarrage a eu lieu sans réseau
    await m.compte.initialiser();
    expect(m.compte.connecte, isFalse);

    await tester.pumpWidget(m.app);
    m.depot.horsLigne = false; // le réseau est revenu
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(m.compte.connecte, isTrue);
    expect(m.stock.valeur, 'k');
  });

  testWidgets('connexion : Telegram est proposé, le bouton Google est masqué', (tester) async {
    final m = monter(const CompteScreen());
    await tester.pumpWidget(m.app);
    await m.compte.chargerFournisseurs();
    await tester.pumpAndSettle();
    expect(find.textContaining('TELEGRAM'), findsOneWidget);
    expect(find.textContaining('GOOGLE'), findsNothing);
    expect(find.textContaining('Google'), findsNothing);
  });
}
