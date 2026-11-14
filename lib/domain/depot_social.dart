import 'models/compte.dart';

/// Ce que le serveur sait proposer comme connexion par un tiers.
///
/// Les boutons ne s'affichent que si le fournisseur est configuré côté serveur :
/// inutile de montrer « Continuer avec Google » sur une installation qui n'a pas
/// d'identifiant Google.
class FournisseursConnexion {
  const FournisseursConnexion({this.google = false, this.telegram = false});

  final bool google;
  final bool telegram;

  bool get aucun => !google && !telegram;

  factory FournisseursConnexion.depuisJson(Map<String, dynamic> json) {
    return FournisseursConnexion(
      google: json['google'] == true,
      telegram: json['telegram'] == true,
    );
  }
}

/// Demande de connexion Telegram en cours : le lien à ouvrir et le jeton à
/// interroger jusqu'à ce que la personne ait appuyé sur « Démarrer ».
class DemandeTelegram {
  const DemandeTelegram({required this.jeton, required this.lien});

  final String jeton;
  final String lien;

  factory DemandeTelegram.depuisJson(Map<String, dynamic> json) {
    return DemandeTelegram(
      jeton: '${json['jeton'] ?? ''}',
      lien: '${json['lien'] ?? ''}',
    );
  }
}

/// Contrat de la connexion par un tiers. Séparé de [DepotComptes] pour que le
/// mot de passe et les fournisseurs restent deux sujets distincts.
abstract class DepotSocial {
  Future<FournisseursConnexion> fournisseurs();

  /// Échange le jeton d'identité Google contre une session 416.
  Future<SessionCompte> google(String jetonIdentite);

  Future<DemandeTelegram> demarrerTelegram();

  /// Renvoie la session dès que Telegram a confirmé, sinon `null` (en attente).
  Future<SessionCompte?> etatTelegram(String jeton);
}
