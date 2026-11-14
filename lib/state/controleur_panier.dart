import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/panier.dart';
import '../domain/models/produit.dart';

/// Panier local persistant.
///
/// Il vit au-dessus des écrans ([ChangeNotifier]) et écrit dans
/// `shared_preferences` à chaque modification : fermer l'application ne perd
/// pas la commande. Les quantités sont bornées par le stock connu.
class ControleurPanier extends ChangeNotifier {
  ControleurPanier({SharedPreferences? preferences, String cle = 'panier416'})
      : _preferences = preferences,
        _cle = cle;

  final String _cle;
  SharedPreferences? _preferences;

  Panier _panier = Panier.vide;
  bool _charge = false;

  Panier get panier => _panier;

  /// Vrai quand le panier a été relu depuis le disque. L'interface attend ce
  /// drapeau avant d'afficher « panier vide », pour ne pas mentir une seconde.
  bool get charge => _charge;

  bool get estVide => _panier.estVide;

  int get nombreArticles => _panier.nombreArticles;

  String get totalLisible => _panier.totalLisible;

  /// Vide clignotant pour le badge de la barre de navigation.
  String get badge => nombreArticles > 99 ? '99+' : '$nombreArticles';

  Future<void> initialiser() async {
    if (_charge) return;
    try {
      _preferences ??= await SharedPreferences.getInstance();
      final brut = _preferences?.getString(_cle);
      if (brut != null && brut.isNotEmpty) {
        _panier = Panier.depuisJson(jsonDecode(brut));
      }
    } catch (_) {
      // Panier illisible : on repart d'un panier vide plutôt que de planter.
      _panier = Panier.vide;
    }
    _charge = true;
    notifyListeners();
  }

  /// Ajoute [quantite] unités d'un produit dans une taille donnée.
  void ajouter(Produit produit, {String taille = '', int quantite = 1}) {
    _panier = _panier.ajouter(
      LignePanier.depuisProduit(produit, taille: taille, quantite: quantite),
    );
    _persister();
  }

  void ajouterLigne(LignePanier ligne) {
    _panier = _panier.ajouter(ligne);
    _persister();
  }

  void definirQuantite(int produitId, String taille, int quantite) {
    _panier = _panier.definirQuantite(produitId, taille, quantite);
    _persister();
  }

  void incrementer(LignePanier ligne) {
    definirQuantite(ligne.produitId, ligne.taille, ligne.quantite + 1);
  }

  void decrementer(LignePanier ligne) {
    definirQuantite(ligne.produitId, ligne.taille, ligne.quantite - 1);
  }

  void retirer(LignePanier ligne) {
    _panier = _panier.retirer(ligne.produitId, taille: ligne.taille);
    _persister();
  }

  void vider() {
    _panier = _panier.vider();
    _persister();
  }

  void _persister() {
    notifyListeners();
    final prefs = _preferences;
    if (prefs == null) {
      // Première utilisation avant `initialiser()` : on enchaîne la sauvegarde
      // dès que le stockage est disponible.
      SharedPreferences.getInstance()
          .then((prefs) {
            _preferences = prefs;
            return prefs.setString(_cle, jsonEncode(_panier.versJson()));
          })
          .catchError((Object _) => false);
      return;
    }
    prefs.setString(_cle, jsonEncode(_panier.versJson())).catchError((Object _) => false);
  }
}
