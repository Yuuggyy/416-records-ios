import 'package:equatable/equatable.dart';

/// Compte client tel que renvoyé par `/api/comptes/…`.
///
/// Le mot de passe n'apparaît jamais ici : le serveur ne le renvoie pas et
/// l'application ne le conserve pas.
class Compte extends Equatable {
  const Compte({
    required this.id,
    required this.identifiant,
    this.email = '',
    this.telephone = '',
    this.nom = '',
    this.staff = false,
  });

  factory Compte.depuisJson(Map<String, dynamic> json) {
    String texte(Object? v) => v is String ? v : '';
    final id = json['id'];
    return Compte(
      id: id is int ? id : int.tryParse('$id') ?? 0,
      identifiant: texte(json['identifiant']),
      email: texte(json['email']),
      telephone: texte(json['telephone']),
      nom: texte(json['nom']),
      staff: json['staff'] == true,
    );
  }

  final int id;
  final String identifiant;
  final String email;
  final String telephone;
  final String nom;
  final bool staff;

  /// Nom à afficher : le nom saisi, sinon l'identifiant.
  String get libelle => nom.isNotEmpty ? nom : identifiant;

  @override
  List<Object?> get props => [id, identifiant, email, telephone, nom, staff];
}

/// Réponse d'une inscription ou d'une connexion : le compte et sa clé d'accès.
class SessionCompte extends Equatable {
  const SessionCompte({required this.compte, required this.cle});

  final Compte compte;
  final String cle;

  @override
  List<Object?> get props => [compte, cle];
}

/// Erreur métier des comptes, avec un message déjà rédigé pour l'écran.
class ErreurCompte implements Exception {
  const ErreurCompte(this.message, {this.statut, this.code});

  final String message;
  final int? statut;

  /// Motif précis d'un refus de clé (`meta.code` du serveur), voir [ErreurAbonnement.code].
  final String? code;

  @override
  String toString() => message;
}
