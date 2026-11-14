import 'package:flutter_test/flutter_test.dart';
import 'package:records416/domain/models/panier.dart';
import 'package:records416/domain/models/produit.dart';

Produit _produit({
  int id = 1,
  String nom = 'T-Shirt 416',
  double prix = 25,
  int stock = 10,
  String devise = 'USD',
}) {
  return Produit(
    id: id,
    nom: nom,
    prix: prix,
    devise: devise,
    stock: stock,
    enStock: stock > 0,
    tailles: const ['S', 'M'],
  );
}

void main() {
  group('Panier — ajout et cumul', () {
    test('le panier démarre vide', () {
      const panier = Panier.vide;
      expect(panier.estVide, isTrue);
      expect(panier.nombreArticles, 0);
      expect(panier.total, 0);
      expect(panier.devise, 'USD');
    });

    test('ajouter deux fois le même produit et la même taille cumule la quantité', () {
      final produit = _produit();
      var panier = Panier.vide;

      panier = panier.ajouter(LignePanier.depuisProduit(produit, taille: 'M'));
      panier = panier.ajouter(LignePanier.depuisProduit(produit, taille: 'M'));

      expect(panier.lignes.length, 1);
      expect(panier.nombreArticles, 2);
      expect(panier.total, 50);
      expect(panier.totalLisible, '50,00 \$US');
      expect(panier.lignes.single.taille, 'M');
      expect(panier.lignes.single.descriptionTaille, 'Taille M');
    });

    test('le même produit dans deux tailles fait deux lignes distinctes', () {
      final produit = _produit();
      var panier = Panier.vide;
      panier = panier.ajouter(LignePanier.depuisProduit(produit, taille: 'S'));
      panier = panier.ajouter(LignePanier.depuisProduit(produit, taille: 'L'));

      expect(panier.lignes.length, 2);
      expect(panier.nombreArticles, 2);
      expect(panier.total, 50);
    });

    test('la quantité est bornée par le stock disponible', () {
      final produit = _produit(stock: 2);
      var panier = Panier.vide;
      panier = panier.ajouter(LignePanier.depuisProduit(produit, taille: 'M', quantite: 5));

      expect(panier.nombreArticles, 2, reason: 'stock = 2, la quantité est plafonnée');
      expect(panier.lignes.single.peutAugmenter, isFalse);

      final sature = panier.ajouter(LignePanier.depuisProduit(produit, taille: 'M'));
      expect(sature.nombreArticles, 2, reason: 'un ajout de plus ne dépasse pas le stock');
    });

    test('définir une quantité à zéro retire la ligne', () {
      final produit = _produit();
      var panier = Panier.vide.ajouter(LignePanier.depuisProduit(produit, taille: 'S', quantite: 3));
      expect(panier.nombreArticles, 3);

      panier = panier.definirQuantite(produit.id, 'S', 0);
      expect(panier.estVide, isTrue);
    });

    test('retirer et vider fonctionnent', () {
      final a = _produit(id: 1);
      final b = _produit(id: 2, nom: 'Hoodie', prix: 45);
      var panier = Panier.vide
          .ajouter(LignePanier.depuisProduit(a, taille: 'M'))
          .ajouter(LignePanier.depuisProduit(b, taille: 'L'));

      expect(panier.nombreArticles, 2);
      panier = panier.retirer(a.id, taille: 'M');
      expect(panier.lignes.length, 1);
      expect(panier.lignes.single.nom, 'Hoodie');
      expect(panier.total, 45);

      panier = panier.vider();
      expect(panier.estVide, isTrue);
    });

    test('le total additionne plusieurs articles et devises', () {
      final a = _produit(id: 1, prix: 25);
      final b = _produit(id: 2, nom: 'Casquette', prix: 20);
      final panier = Panier.vide
          .ajouter(LignePanier.depuisProduit(a, taille: 'S', quantite: 2))
          .ajouter(LignePanier.depuisProduit(b, taille: 'Unique', quantite: 1));

      expect(panier.nombreArticles, 3);
      expect(panier.total, 70);
      expect(panier.deviseHomogene, isTrue);
      expect(panier.devises, {'USD'});
    });

    test('le panier survit à un aller-retour JSON', () {
      final produit = _produit(id: 9, prix: 35.5);
      final panier = Panier.vide.ajouter(
        LignePanier.depuisProduit(produit, taille: 'M', quantite: 2),
      );

      final restaure = Panier.depuisJson(panier.versJson());

      expect(restaure, equals(panier));
      expect(restaure.nombreArticles, 2);
      expect(restaure.total, 71);
    });

    test('un JSON corrompu ou vide donne un panier vide, pas une exception', () {
      expect(Panier.depuisJson(null).estVide, isTrue);
      expect(Panier.depuisJson('pas une liste').estVide, isTrue);
      expect(Panier.depuisJson(const []).estVide, isTrue);
    });
  });
}
