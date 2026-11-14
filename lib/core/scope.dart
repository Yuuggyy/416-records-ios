import 'package:flutter/widgets.dart';

import '../domain/depot_catalogue.dart';
import '../state/controleur_abonnement.dart';
import '../state/controleur_compte.dart';
import '../state/controleur_panier.dart';

/// Accès au dépôt et au panier depuis n'importe quel écran.
///
/// Un `InheritedWidget` suffit ici : deux dépendances, aucune reconstruction
/// globale, et les tests peuvent monter un écran avec un dépôt simulé.
class CatalogueScope extends InheritedWidget {
  const CatalogueScope({
    super.key,
    required this.depot,
    required this.panier,
    required this.abonnement,
    required this.compte,
    required super.child,
  });

  final DepotCatalogue depot;
  final ControleurPanier panier;
  final ControleurAbonnement abonnement;
  final ControleurCompte compte;

  static CatalogueScope of(BuildContext context) {
    final portee = context.dependOnInheritedWidgetOfExactType<CatalogueScope>();
    assert(portee != null, 'CatalogueScope absent de l\'arbre de widgets.');
    return portee!;
  }

  /// Lecture sans abonnement : pour les rappels (`onPressed`).
  static CatalogueScope lire(BuildContext context) {
    final portee = context.getInheritedWidgetOfExactType<CatalogueScope>();
    assert(portee != null, 'CatalogueScope absent de l\'arbre de widgets.');
    return portee!;
  }

  @override
  bool updateShouldNotify(CatalogueScope oldWidget) =>
      oldWidget.depot != depot ||
      oldWidget.panier != panier ||
      oldWidget.abonnement != abonnement ||
      oldWidget.compte != compte;
}
