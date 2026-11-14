import 'package:equatable/equatable.dart';

/// Offre d'abonnement vendue par 416 Records.
///
/// Reflète exactement `Offre` côté backend Django (`/api/abonnements/offres/`).
class Offre extends Equatable {
  const Offre({
    required this.id,
    required this.nom,
    required this.code,
    required this.prix,
    this.devise = 'USD',
    this.dureeJours = 30,
    this.essaiJours = 0,
    this.prixParJour,
    this.actif = true,
  });

  final int id;
  final String nom;
  final String code;

  /// Prix déjà formaté en texte : le backend renvoie un `Decimal` sérialisé.
  final String prix;
  final String devise;
  final int dureeJours;
  final int essaiJours;
  final String? prixParJour;
  final bool actif;

  /// « 10.00 USD » — sans zéros inutiles à droite.
  String get prixAffiche {
    final nombre = double.tryParse(prix);
    final valeur = nombre == null ? prix : _sansZero(nombre.toStringAsFixed(2));
    return '$valeur $devise';
  }

  /// « 30 jours », « 365 jours ».
  String get dureeAffichee => '$dureeJours jours';

  /// Vrai pour l'offre d'essai (durée payante offerte au départ).
  bool get avecEssai => essaiJours > 0;

  static String _sansZero(String valeur) {
    if (!valeur.contains('.')) return valeur;
    return valeur.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  factory Offre.depuisJson(Map<String, dynamic> json) {
    return Offre(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nom: (json['nom'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      prix: '${json['prix'] ?? ''}',
      devise: (json['devise'] as String?) ?? 'USD',
      dureeJours: (json['duree_jours'] as num?)?.toInt() ?? 30,
      essaiJours: (json['essai_jours'] as num?)?.toInt() ?? 0,
      prixParJour: json['prix_par_jour'] == null ? null : '${json['prix_par_jour']}',
      actif: json['actif'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, nom, code, prix, devise, dureeJours, essaiJours, prixParJour, actif];
}
