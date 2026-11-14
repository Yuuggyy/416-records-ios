import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache local du catalogue (dernier état connu de l'API).
///
/// Il est volontairement indépendant du dépôt : les tests peuvent injecter un
/// cache mémoire, et l'application utilise `shared_preferences` (localStorage
/// sur le web, SharedPreferences sur Android).
abstract class CacheCatalogue {
  /// Lit une entrée. Retourne `null` si absente ou illisible.
  Future<Object?> lire(String cle);

  /// Enregistre une entrée JSON.
  Future<void> ecrire(String cle, Object? valeur);

  /// Vide tout le cache du catalogue.
  Future<void> vider();
}

/// Cache mémoire : utilisé par les tests et comme dernier recours si le
/// stockage du système refuse d'écrire.
class CacheMemoire implements CacheCatalogue {
  CacheMemoire([Map<String, Object?>? entrees]) : _entrees = entrees ?? {};

  final Map<String, Object?> _entrees;

  @override
  Future<Object?> lire(String cle) async => _entrees[cle];

  @override
  Future<void> ecrire(String cle, Object? valeur) async => _entrees[cle] = valeur;

  @override
  Future<void> vider() async => _entrees.clear();
}

/// Cache persistant basé sur `shared_preferences`.
///
/// Toutes les écritures sont préfixées pour ne pas marcher sur les autres
/// préférences de l'application (profil, concours…).
class CachePreferences implements CacheCatalogue {
  CachePreferences({SharedPreferences? preferences, this.prefixe = 'catalogue416.'})
      : _preferences = preferences;

  static const _prefixeParDefaut = 'catalogue416.';

  final String prefixe;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<Object?> lire(String cle) async {
    try {
      final brut = (await _prefs).getString('$prefixe$cle');
      if (brut == null || brut.isEmpty) return null;
      return jsonDecode(brut);
    } catch (_) {
      // Une entrée corrompue ne doit jamais bloquer l'application : on
      // l'ignore et le dépôt retombera sur le repli local.
      return null;
    }
  }

  @override
  Future<void> ecrire(String cle, Object? valeur) async {
    try {
      await (await _prefs).setString('$prefixe$cle', jsonEncode(valeur));
    } catch (_) {
      // Stockage plein ou indisponible : le cache est un confort, pas une
      // condition de fonctionnement.
    }
  }

  @override
  Future<void> vider() async {
    try {
      final prefs = await _prefs;
      for (final cle in prefs.getKeys().where((cle) => cle.startsWith(prefixe)).toList()) {
        await prefs.remove(cle);
      }
    } catch (_) {
      // Idem : rien d'essentiel.
    }
  }

  static String get prefixeDefaut => _prefixeParDefaut;
}
