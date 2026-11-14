/// Petites lectures tolérantes du JSON renvoyé par l'API du catalogue.
///
/// Le backend peut renvoyer `null` sur les champs facultatifs (année, durée,
/// image…). Ces fonctions évitent de répéter des `as` fragiles dans chaque
/// modèle et garantissent qu'un champ absent ne fait jamais planter l'écran.
library;

String texte(Object? valeur) {
  if (valeur == null) return '';
  if (valeur is String) return valeur;
  return valeur.toString();
}

String? texteOuNull(Object? valeur) {
  final valeurTexte = texte(valeur).trim();
  return valeurTexte.isEmpty ? null : valeurTexte;
}

int? entierOuNull(Object? valeur) {
  if (valeur == null) return null;
  if (valeur is int) return valeur;
  if (valeur is num) return valeur.toInt();
  return int.tryParse(valeur.toString().trim());
}

int entier(Object? valeur, {int defaut = 0}) => entierOuNull(valeur) ?? defaut;

bool booleen(Object? valeur, {bool defaut = false}) {
  if (valeur == null) return defaut;
  if (valeur is bool) return valeur;
  if (valeur is num) return valeur != 0;
  final valeurTexte = valeur.toString().trim().toLowerCase();
  if (valeurTexte == 'true' || valeurTexte == '1' || valeurTexte == 'oui') return true;
  if (valeurTexte == 'false' || valeurTexte == '0' || valeurTexte == 'non') return false;
  return defaut;
}

/// Les prix arrivent en chaîne décimale (`"25.00"`) depuis Django.
double decimal(Object? valeur, {double defaut = 0}) {
  if (valeur == null) return defaut;
  if (valeur is num) return valeur.toDouble();
  return double.tryParse(valeur.toString().trim().replaceAll(',', '.')) ?? defaut;
}

List<String> listeTextes(Object? valeur) {
  if (valeur is! List) return const [];
  return List<String>.unmodifiable(
    valeur.where((element) => element != null).map((element) => texte(element)),
  );
}

/// Liste de cartes JSON, en ignorant les entrées qui ne sont pas des objets.
List<Map<String, dynamic>> listeObjets(Object? valeur) {
  if (valeur is! List) return const [];
  return List<Map<String, dynamic>>.unmodifiable(
    valeur.whereType<Map>().map((element) => Map<String, dynamic>.from(element)),
  );
}

Map<String, dynamic> objet(Object? valeur) {
  if (valeur is Map) return Map<String, dynamic>.from(valeur);
  return const {};
}
