import 'package:flutter_test/flutter_test.dart';
import 'package:records416/domain/depot_social.dart';
import 'package:records416/domain/models/compte.dart';
import 'package:records416/state/controleur_abonnement.dart';
import 'package:records416/state/controleur_compte.dart';

import 'compte_test.dart' show DepotComptesFaux;
import 'controleur_abonnement_test.dart' show DepotAbonnementFaux, StockageMemoire;

/// Telegram qui ne confirme qu'au N-ième interrogatoire.
class _SocialLent implements DepotSocial {
  _SocialLent(this.confirmeAuAppel);
  final int confirmeAuAppel;
  int appels = 0;
  ErreurCompte? refus;

  @override
  Future<FournisseursConnexion> fournisseurs() async => const FournisseursConnexion(telegram: true);
  @override
  Future<SessionCompte> google(String j) => throw UnimplementedError();
  @override
  Future<DemandeTelegram> demarrerTelegram() async =>
      const DemandeTelegram(jeton: 'j', lien: 'https://t.me/x?start=j');
  @override
  Future<SessionCompte?> etatTelegram(String jeton) async {
    appels++;
    if (refus != null) throw refus!;
    if (appels < confirmeAuAppel) return null;
    return const SessionCompte(
      compte: Compte(id: 1, identifiant: 'tg', nom: 'Guy'),
      cle: 'cle-test',
    );
  }
}

ControleurCompte _compte(_SocialLent social) {
  final abo = ControleurAbonnement(
    stockage: StockageMemoire(null),
    creerDepot: (_) => DepotAbonnementFaux(),
  );
  return ControleurCompte(depot: DepotComptesFaux(), abonnement: abo, social: social);
}

void main() {
  test('Telegram : la première vérification est immédiate (pas d\'attente avant le 1er essai)', () async {
    final social = _SocialLent(1);
    final compte = _compte(social);
    final sw = Stopwatch()..start();
    final ok = await compte.attendreTelegram('j', intervalle: const Duration(seconds: 30));
    expect(ok, isTrue);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    expect(compte.connecte, isTrue);
  });

  test('Telegram : le retour au premier plan déclenche une vérification immédiate', () async {
    final social = _SocialLent(3);
    final compte = _compte(social);
    final attente = compte.attendreTelegram('j', intervalle: const Duration(seconds: 30));
    // 1er essai immédiat (appel 1), puis l'app « revient au premier plan » deux fois.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    compte.verifierTelegramMaintenant();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    compte.verifierTelegramMaintenant();
    final sw = Stopwatch()..start();
    final ok = await attente.timeout(const Duration(seconds: 5));
    expect(ok, isTrue);
    expect(social.appels, 3);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
  });

  for (final statut in [403, 426, 410]) {
    test('Telegram : un refus $statut arrête l\'attente et affiche le message', () async {
      final social = _SocialLent(1)..refus = ErreurCompte('message $statut', statut: statut);
      final compte = _compte(social);
      final ok = await compte.attendreTelegram('j', intervalle: const Duration(milliseconds: 10));
      expect(ok, isFalse);
      expect(compte.erreur, 'message $statut');
      expect(social.appels, 1);
    });
  }

  test('Telegram : une erreur réseau passagère ne casse pas l\'attente', () async {
    final social = _SocialLent(3)..refus = const ErreurCompte('Serveur injoignable.');
    final compte = _compte(social);
    final attente = compte.attendreTelegram('j', intervalle: const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    social.refus = null;
    expect(await attente.timeout(const Duration(seconds: 5)), isTrue);
  });
}
