import 'package:equatable/equatable.dart';

import '../../core/lecture_json.dart';

/// Produit du merch 416.
///
/// Le prix est un `double` (Django renvoie `"25.00"`) et la devise vient du
/// backend (`USD` par défaut) : la boutique affiche donc le total dans la
/// devise du produit, jamais dans une devise codée en dur.
class Produit extends Equatable {
  const Produit({
    required this.id,
    required this.nom,
    this.slug = '',
    this.description = '',
    this.categorie = '',
    this.prix = 0,
    this.devise = 'USD',
    this.imageUrl,
    this.tailles = const [],
    this.stock = 0,
    this.enStock = false,
    this.vedette = false,
    this.artisteSlug = '',
    this.artisteNom = '',
  });

  final int id;
  final String nom;
  final String slug;
  final String description;
  final String categorie;
  final double prix;
  final String devise;
  final String? imageUrl;
  final List<String> tailles;
  final int stock;
  final bool enStock;
  final bool vedette;
  final String artisteSlug;
  final String artisteNom;

  String get identifiant => slug.isNotEmpty ? slug : '$id';

  bool get aImage => imageUrl != null && imageUrl!.isNotEmpty;

  bool get aTailles => tailles.isNotEmpty;

  /// Prix lisible : « 25,00 $US » quand la devise est connue, sinon
  /// « 25,00 USD ». Le séparateur décimal suit l'usage francophone.
  String get prixLisible => formaterPrix(prix, devise);

  /// Vrai si [quantite] peut encore être ajoutée au panier.
  bool quantiteDisponible(int quantite) => quantite < stock;

  factory Produit.depuisJson(Map<String, dynamic> json) {
    final stock = entier(json['stock']);
    return Produit(
      id: entier(json['id']),
      nom: texte(json['nom']),
      slug: texte(json['slug']),
      description: texte(json['description']),
      categorie: texte(json['categorie']),
      prix: decimal(json['prix']),
      devise: texte(json['devise']).isEmpty ? 'USD' : texte(json['devise']),
      imageUrl: texteOuNull(json['image_url']),
      tailles: listeTextes(json['tailles']),
      stock: stock,
      // Le backend envoie `en_stock` ; on le recalcule si le champ manque.
      enStock: json.containsKey('en_stock') ? booleen(json['en_stock']) : stock > 0,
      vedette: booleen(json['vedette']),
      artisteSlug: texte(json['artiste_slug']),
      artisteNom: texte(json['artiste_nom']),
    );
  }

  Map<String, dynamic> versJson() => {
        'id': id,
        'nom': nom,
        'slug': slug,
        'description': description,
        'categorie': categorie,
        'prix': prix,
        'devise': devise,
        'image_url': imageUrl,
        'tailles': tailles,
        'stock': stock,
        'en_stock': enStock,
        'vedette': vedette,
        'artiste_slug': artisteSlug,
        'artiste_nom': artisteNom,
      };

  @override
  List<Object?> get props =>
      [id, nom, slug, description, categorie, prix, devise, imageUrl, tailles, stock, enStock, vedette, artisteSlug, artisteNom];
}

/// Symboles des devises rencontrées dans le catalogue 416.
const Map<String, String> _symbolesDevises = {
  'USD': '\$US',
  'CDF': 'FC',
  'EUR': '€',
};

/// Formate un montant : « 25,00 $US », « 1 250,00 FC ».
///
/// Les milliers sont séparés par une espace insécable fine, le décimal par une
/// virgule — convention française utilisée dans toute l'application.
String formaterPrix(double montant, String devise) {
  final negatif = montant < 0;
  final absolu = montant.abs();
  final entier = absolu.truncate();
  final centimes = ((absolu - entier) * 100).round();
  // 1,999 arrondi à 200 centimes doit faire passer l'entier à +1.
  final entierFinal = centimes == 100 ? entier + 1 : entier;
  final centimesFinaux = centimes == 100 ? 0 : centimes;

  final chiffres = entierFinal.toString();
  final tampon = StringBuffer();
  for (var i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write('\u202F');
    tampon.write(chiffres[i]);
  }

  final symbole = _symbolesDevises[devise.toUpperCase()] ?? devise.toUpperCase();
  final signe = negatif ? '-' : '';
  return '$signe$tampon,${centimesFinaux.toString().padLeft(2, '0')} $symbole';
}
