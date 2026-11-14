import 'models/abonnement.dart';
import 'models/offre.dart';

/// Refus d'accès à un contenu premium (HTTP 402 du backend).
///
/// Le message vient du serveur : l'application ne décide jamais elle-même
/// qu'un contenu est réservé, elle affiche seulement le refus reçu.
class AccesRefuse implements Exception {
  const AccesRefuse(this.message, {this.statut = 402});

  final String message;
  final int statut;

  @override
  String toString() => message;
}

/// Erreur d'abonnement déjà rédigée pour la personne qui lit l'écran.
class ErreurAbonnement implements Exception {
  const ErreurAbonnement(this.message, {this.statut, this.code});

  final String message;
  final int? statut;

  /// Motif précis d'un refus de clé, donné par le serveur dans `meta.code` :
  /// `remplacee`, `desactivee` ou `expiree`. Absent = incident non confirmé.
  final String? code;

  @override
  String toString() => message;
}

/// Contrat des abonnements, indépendant du transport.
///
/// Les tests injectent une implémentation mémoire ; l'application utilise
/// [DepotAbonnementHttp]. Aucune méthode ne doit laisser fuir une exception
/// réseau brute : elle renvoie [ErreurAbonnement] avec un message lisible.
abstract class DepotAbonnement {
  /// Offres actives, de la moins chère à la plus chère.
  Future<List<Offre>> offres();

  /// État de l'abonnement du compte identifié par [cle].
  Future<EtatAbonnement> monAbonnement();

  /// Envoie une preuve de paiement Mobile Money. Renvoie l'abonnement créé
  /// (statut « en_attente ») et le paiement associé.
  Future<({Abonnement abonnement, Paiement paiement})> souscrire({
    required String codeOffre,
    required OperateurMobileMoney operateur,
    required String numeroTransaction,
    String preuve = '',
  });

  /// Demande au serveur l'autorisation de lire un film.
  ///
  /// Lève [AccesRefuse] si le serveur répond 402 (pas d'abonnement en cours)
  /// et [ErreurAbonnement] pour tout autre échec.
  Future<LectureAutorisee> lectureFilm(String slug);

  /// Clé d'identification du compte, si une est configurée.
  String? get cle;
}
