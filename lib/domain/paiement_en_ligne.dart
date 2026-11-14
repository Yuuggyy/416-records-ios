/// Opérateurs Mobile Money acceptés par le paiement en ligne (RDC).
enum OperateurEnLigne {
  mpesa('VODACOM_MPESA_COD', 'M-Pesa'),
  orange('ORANGE_COD', 'Orange Money'),
  airtel('AIRTEL_COD', 'Airtel Money');

  const OperateurEnLigne(this.code, this.libelle);

  final String code;
  final String libelle;

  static OperateurEnLigne? depuisCode(String? code) {
    for (final o in values) {
      if (o.code == code) return o;
    }
    return null;
  }
}

/// Un paiement lancé : l'identifiant sert à suivre son état.
class DepotLance {
  const DepotLance({
    required this.identifiant,
    required this.montant,
    required this.devise,
    required this.operateur,
    required this.message,
    required this.sandbox,
  });

  final String identifiant;
  final String montant;
  final String devise;
  final String operateur;
  final String message;
  final bool sandbox;

  String get montantLisible => '$montant $devise';
}

enum EtatDepot { enAttente, paye, echoue, inconnu }

class SuiviDepot {
  const SuiviDepot({required this.etat, this.motif = ''});

  final EtatDepot etat;
  final String motif;

  bool get final_ => etat == EtatDepot.paye || etat == EtatDepot.echoue;
}

class ErreurPaiement implements Exception {
  const ErreurPaiement(this.message, {this.statut});

  final String message;
  final int? statut;

  @override
  String toString() => message;
}

/// Contrat du service de paiement en ligne (remplaçable dans les tests).
abstract class ServicePaiementEnLigne {
  /// Opérateurs réellement ouverts côté serveur ; vide si le paiement en
  /// ligne n'est pas disponible.
  Future<({bool disponible, bool sandbox, List<OperateurEnLigne> operateurs})> operateurs();

  Future<DepotLance> payerAbonnement({
    required String codeOffre,
    required String numero,
    required OperateurEnLigne operateur,
  });

  Future<DepotLance> payerCommande({
    required String reference,
    required String whatsapp,
    required String numero,
    required OperateurEnLigne operateur,
  });

  Future<SuiviDepot> etat(String identifiant);
}
