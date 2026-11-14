import 'package:equatable/equatable.dart';

import '../../core/lecture_json.dart';
import 'produit.dart';

/// Ligne du panier : un produit, une taille choisie, une quantité.
///
/// La ligne fige le nom, le prix et la devise au moment de l'ajout : si le
/// catalogue change (prix, produit retiré), le panier reste cohérent avec ce
/// que la personne a vu.
class LignePanier extends Equatable {
  const LignePanier({
    required this.produitId,
    required this.nom,
    required this.prixUnitaire,
    required this.devise,
    this.taille = '',
    this.quantite = 1,
    this.imageUrl,
    this.stockMax = 0,
  });

  final int produitId;
  final String nom;
  final double prixUnitaire;
  final String devise;
  final String taille;
  final int quantite;
  final String? imageUrl;

  /// Stock connu au moment de l'ajout : 0 signifie « inconnu », pas « épuisé ».
  final int stockMax;

  /// Clé d'unicité : un même produit dans deux tailles = deux lignes.
  String get cle => '$produitId|$taille';

  double get sousTotal => prixUnitaire * quantite;

  String get descriptionTaille => taille.isEmpty ? 'Taille unique' : 'Taille $taille';

  /// Vrai si la quantité peut encore être augmentée.
  bool get peutAugmenter => stockMax <= 0 || quantite < stockMax;

  LignePanier copieAvec({int? quantite}) => LignePanier(
        produitId: produitId,
        nom: nom,
        prixUnitaire: prixUnitaire,
        devise: devise,
        taille: taille,
        quantite: quantite ?? this.quantite,
        imageUrl: imageUrl,
        stockMax: stockMax,
      );

  factory LignePanier.depuisProduit(Produit produit, {String taille = '', int quantite = 1}) {
    return LignePanier(
      produitId: produit.id,
      nom: produit.nom,
      prixUnitaire: produit.prix,
      devise: produit.devise,
      taille: taille,
      quantite: quantite,
      imageUrl: produit.imageUrl,
      stockMax: produit.stock,
    );
  }

  factory LignePanier.depuisJson(Map<String, dynamic> json) => LignePanier(
        produitId: entier(json['produit_id']),
        nom: texte(json['nom']),
        prixUnitaire: decimal(json['prix_unitaire']),
        devise: texte(json['devise']).isEmpty ? 'USD' : texte(json['devise']),
        taille: texte(json['taille']),
        quantite: entier(json['quantite'], defaut: 1),
        imageUrl: texteOuNull(json['image_url']),
        stockMax: entier(json['stock_max']),
      );

  Map<String, dynamic> versJson() => {
        'produit_id': produitId,
        'nom': nom,
        'prix_unitaire': prixUnitaire,
        'devise': devise,
        'taille': taille,
        'quantite': quantite,
        'image_url': imageUrl,
        'stock_max': stockMax,
      };

  @override
  List<Object?> get props =>
      [produitId, nom, prixUnitaire, devise, taille, quantite, imageUrl, stockMax];
}

/// Panier local, immuable : chaque modification produit un nouveau panier.
///
/// L'immuabilité rend les transitions d'état prévisibles et testables sans
/// monter d'interface.
class Panier extends Equatable {
  const Panier({this.lignes = const []});

  final List<LignePanier> lignes;

  static const Panier vide = Panier();

  bool get estVide => lignes.isEmpty;

  int get nombreArticles => lignes.fold(0, (total, ligne) => total + ligne.quantite);

  /// Total toutes lignes confondues. Le catalogue 416 ne vend qu'en USD ;
  /// [devises] permet de détecter une éventuelle incohérence d'affichage.
  double get total => lignes.fold(0.0, (somme, ligne) => somme + ligne.sousTotal);

  /// Devise du panier : celle de la première ligne, `USD` par défaut.
  String get devise => lignes.isEmpty ? 'USD' : lignes.first.devise;

  Set<String> get devises => lignes.map((ligne) => ligne.devise).toSet();

  /// Vrai quand toutes les lignes partagent la même devise : le total est
  /// alors affichable en une seule somme.
  bool get deviseHomogene => devises.length <= 1;

  String get totalLisible => formaterPrix(total, devise);

  LignePanier? lignePour(int produitId, {String taille = ''}) {
    final cle = '$produitId|$taille';
    for (final ligne in lignes) {
      if (ligne.cle == cle) return ligne;
    }
    return null;
  }

  /// Ajoute une unité, ou incrémente la ligne existante (même produit + taille).
  Panier ajouter(LignePanier ligne) {
    final existante = lignePour(ligne.produitId, taille: ligne.taille);
    if (existante == null) {
      // Premier ajout : la quantité est déjà bornée par le stock connu.
      final quantiteInitiale = _borneQuantite(ligne, ligne.quantite);
      return Panier(
        lignes: List<LignePanier>.unmodifiable([
          ...lignes,
          quantiteInitiale == ligne.quantite ? ligne : ligne.copieAvec(quantite: quantiteInitiale),
        ]),
      );
    }
    final quantite = _borneQuantite(existante, existante.quantite + ligne.quantite);
    return _remplacer(existante, existante.copieAvec(quantite: quantite));
  }

  /// Fixe la quantité d'une ligne. Zéro ou moins retire la ligne.
  Panier definirQuantite(int produitId, String taille, int quantite) {
    final existante = lignePour(produitId, taille: taille);
    if (existante == null) return this;
    if (quantite <= 0) return retirer(produitId, taille: taille);
    return _remplacer(existante, existante.copieAvec(quantite: _borneQuantite(existante, quantite)));
  }

  Panier retirer(int produitId, {String taille = ''}) {
    return Panier(
      lignes: List<LignePanier>.unmodifiable(
        lignes.where((ligne) => ligne.cle != '$produitId|$taille'),
      ),
    );
  }

  Panier vider() => Panier.vide;

  Panier _remplacer(LignePanier ancienne, LignePanier nouvelle) {
    return Panier(
      lignes: List<LignePanier>.unmodifiable(
        lignes.map((ligne) => ligne.cle == ancienne.cle ? nouvelle : ligne),
      ),
    );
  }

  int _borneQuantite(LignePanier ligne, int quantite) {
    if (ligne.stockMax > 0 && quantite > ligne.stockMax) return ligne.stockMax;
    return quantite < 1 ? 1 : quantite;
  }

  List<Map<String, dynamic>> versJson() => lignes.map((ligne) => ligne.versJson()).toList();

  factory Panier.depuisJson(Object? json) {
    if (json is! List) return Panier.vide;
    return Panier(lignes: List<LignePanier>.unmodifiable(json.whereType<Map>().map(
          (element) => LignePanier.depuisJson(Map<String, dynamic>.from(element)),
        )));
  }

  @override
  List<Object?> get props => [lignes];
}
