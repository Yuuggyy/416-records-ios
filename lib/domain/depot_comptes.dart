import 'models/compte.dart';

/// Contrat des comptes clients. L'implémentation réelle parle à l'API Django ;
/// les tests utilisent une version simulée.
abstract class DepotComptes {
  Future<SessionCompte> inscrire({
    required String identifiant,
    required String motDePasse,
    String nom = '',
  });

  Future<SessionCompte> connecter({
    required String identifiant,
    required String motDePasse,
  });

  Future<Compte> moi(String cle);

  Future<void> supprimer({required String cle, required String motDePasse});
}
