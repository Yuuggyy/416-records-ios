import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/scope.dart';
import 'package:records416/features/pubs/choix_super_fan.dart';
import 'package:records416/features/pubs/duree_pub.dart';
import 'package:records416/features/pubs/ecran_pub.dart';
import 'package:records416/features/pubs/mini_jeu_pub.dart';
import 'package:records416/state/controleur_abonnement.dart';
import 'package:records416/state/controleur_compte.dart';
import 'package:records416/state/controleur_panier.dart';

import 'abonnement_ecran_test.dart' show DepotCatalogueVide;
import 'compte_test.dart' show DepotComptesFaux;
import 'controleur_abonnement_test.dart' show DepotAbonnementFaux, StockageMemoire;

void main() {
  testsRegie();
  test('durées : son 15 s, clip 25 s, film 8 à 15 min 45 s, plus long 60 s', () {
    expect(dureePubSecondes(TypeContenu.son), 15);
    expect(dureePubSecondes(TypeContenu.video), 25);
    expect(dureePubSecondes(TypeContenu.video, dureeContenuMinutes: 4), 25);
    expect(dureePubSecondes(TypeContenu.video, dureeContenuMinutes: 8), 45);
    expect(dureePubSecondes(TypeContenu.video, dureeContenuMinutes: 15), 45);
    expect(dureePubSecondes(TypeContenu.video, dureeContenuMinutes: 16), 60);
    expect(dureePubSecondes(TypeContenu.video, dureeContenuMinutes: 90), 60);
  });

  testWidgets('la pub se ferme avec « vue » à la fin du compte à rebours', (tester) async {
    bool? resultat;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => resultat = await Navigator.of(c).push<bool>(
            MaterialPageRoute<bool>(builder: (_) => const EcranPub(dureeSecondes: 3, regie: RegieAbsente(), jeu: false)),
          ),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('3 s'), findsOneWidget);
    expect(find.text('PUB'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(resultat, isTrue);
  });

  testWidgets('quitter la pub avant la fin : pas de récompense', (tester) async {
    bool? resultat;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => resultat = await Navigator.of(c).push<bool>(
            MaterialPageRoute<bool>(builder: (_) => const EcranPub(dureeSecondes: 20, regie: RegieAbsente(), jeu: false)),
          ),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Quitter'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('QUITTER'));
    await tester.pumpAndSettle();
    expect(resultat, isFalse);
  });

  testWidgets('le mini-jeu : toucher une note ajoute un point', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(width: 300, height: 400, child: MiniJeuPub(graine: 1))),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Notes attrapées : 0'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.music_note).first);
    await tester.pump();
    expect(find.text('Notes attrapées : 1'), findsOneWidget);
    // Ôter le jeu arrête le minuteur (aucun minuteur en attente à la fin du test).
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });

  testWidgets('un non-abonné voit le choix : payer 1,25 \$ ou regarder une pub avec la durée annoncée',
      (tester) async {
    final controleur = ControleurAbonnement(
      stockage: StockageMemoire(),
      creerDepot: (_) => DepotAbonnementFaux(),
    );
    await controleur.initialiser();
    ChoixSuperFan? res;
    await tester.pumpWidget(CatalogueScope(
      depot: DepotCatalogueVide(),
      panier: ControleurPanier(),
      abonnement: controleur,
      compte: ControleurCompte(depot: DepotComptesFaux(), abonnement: controleur),
      child: MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => res = await demanderSuperFan(c, type: TypeContenu.video, dureeContenuMinutes: 12),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PAYER 1,25'), findsOneWidget);
    expect(find.textContaining('REGARDER UNE PUB (45 S)'), findsOneWidget);
    await tester.tap(find.text('PLUS TARD'));
    await tester.pumpAndSettle();
    expect(res, ChoixSuperFan.annule);
  });
}

class RegieFausse implements RegiePub {
  RegieFausse({this.pret = true, this.regardee = true});
  final bool pret;
  final bool regardee;
  int montrees = 0;
  @override
  bool get disponible => true;
  @override
  bool get prete => pret;
  @override
  void preparer() {}
  @override
  Future<bool> montrer(void Function(bool regardee) surFin) async {
    montrees++;
    Future<void>.delayed(const Duration(seconds: 2), () => surFin(regardee));
    return true;
  }
}

void testsRegie() {
  testWidgets('pub de la régie regardée en entier : contenu débloqué', (tester) async {
    final regie = RegieFausse();
    bool? res;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => res = await Navigator.of(c).push<bool>(MaterialPageRoute<bool>(
              builder: (_) => EcranPub(dureeSecondes: 5, regie: regie, jeu: false))),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(regie.montrees, 1);
    expect(res, isTrue);
  });

  testWidgets('pub de la régie fermée avant la fin : pas de récompense', (tester) async {
    final regie = RegieFausse(regardee: false);
    bool? res;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => res = await Navigator.of(c).push<bool>(MaterialPageRoute<bool>(
              builder: (_) => EcranPub(dureeSecondes: 5, regie: regie, jeu: false))),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(res, isFalse);
  });

  testWidgets('aucune pub prête : repli avec compte à rebours', (tester) async {
    final regie = RegieFausse(pret: false);
    bool? res;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => res = await Navigator.of(c).push<bool>(MaterialPageRoute<bool>(
              builder: (_) => EcranPub(
                  dureeSecondes: 10, regie: regie, attenteRegie: const Duration(seconds: 2), jeu: false))),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byKey(const ValueKey('reste')), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(regie.montrees, 0);
    expect(res, isTrue);
  });
}

class RegieAbsente implements RegiePub {
  const RegieAbsente();
  @override
  bool get disponible => false;
  @override
  bool get prete => false;
  @override
  void preparer() {}
  @override
  Future<bool> montrer(void Function(bool regardee) surFin) async => false;
}
