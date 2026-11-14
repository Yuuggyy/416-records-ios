import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/film.dart';

/// Un film mis de côté : juste de quoi l'afficher et rouvrir sa fiche.
class FilmEnListe {
  const FilmEnListe({required this.identifiant, required this.titre, this.affiche});

  final String identifiant;
  final String titre;
  final String? affiche;

  Map<String, dynamic> versJson() => {'id': identifiant, 'titre': titre, 'affiche': affiche};

  factory FilmEnListe.depuisJson(Map<String, dynamic> j) => FilmEnListe(
        identifiant: '${j['id']}',
        titre: '${j['titre'] ?? ''}',
        affiche: j['affiche'] as String?,
      );
}

/// « Ma liste » : les films que l'utilisateur veut voir plus tard.
/// Stockée sur l'appareil (aucun compte requis), relue au démarrage.
class MaListe extends ChangeNotifier {
  MaListe._();

  static final MaListe instance = MaListe._();

  /// Pour les tests : une liste neuve, branchée sur des préférences simulées.
  @visibleForTesting
  factory MaListe.pourTest() => MaListe._();

  static const _cle = 'ma_liste416';

  final List<FilmEnListe> _films = [];
  bool _charge = false;

  List<FilmEnListe> get films => List.unmodifiable(_films);
  bool get charge => _charge;

  bool contient(String identifiant) => _films.any((f) => f.identifiant == identifiant);

  Future<void> initialiser() async {
    if (_charge) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut != null && brut.isNotEmpty) {
        final liste = jsonDecode(brut) as List<dynamic>;
        _films
          ..clear()
          ..addAll(liste.map((e) => FilmEnListe.depuisJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {
      _films.clear(); // liste illisible : on repart d'une liste vide
    }
    _charge = true;
    notifyListeners();
  }

  Future<void> retirer(String identifiant) async {
    _films.removeWhere((f) => f.identifiant == identifiant);
    notifyListeners();
    await _ecrire();
  }

  Future<void> _ecrire() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, jsonEncode(_films.map((f) => f.versJson()).toList()));
    } catch (_) {}
  }

  /// Ajoute le film s'il n'y est pas, le retire sinon. Renvoie vrai s'il est
  /// désormais dans la liste.
  Future<bool> basculer(Film film) async {
    await initialiser();
    final id = film.identifiant;
    final present = contient(id);
    if (present) {
      _films.removeWhere((f) => f.identifiant == id);
    } else {
      _films.insert(0, FilmEnListe(identifiant: id, titre: film.titre, affiche: film.afficheUrl));
    }
    notifyListeners();
    await _ecrire();
    return !present;
  }
}
