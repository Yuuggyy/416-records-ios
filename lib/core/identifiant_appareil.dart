import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identifiant aléatoire propre à cette installation, envoyé au serveur dans
/// l'en-tête `X-Appareil` à la connexion. Le serveur s'en sert pour n'autoriser
/// qu'un appareil actif par compte (anti-partage).
///
/// Il ne contient aucune donnée personnelle : c'est un nombre tiré au hasard,
/// créé une fois, puis conservé. Réinstaller l'application en crée un nouveau,
/// ce que le serveur compte comme un changement d'appareil.
class IdentifiantAppareil {
  IdentifiantAppareil({Future<SharedPreferences?> Function()? preferences})
      : _preferences = preferences ?? _parDefaut;

  static const cle = 'appareil416.id';
  static Future<SharedPreferences?> _parDefaut() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  final Future<SharedPreferences?> Function() _preferences;
  String? _memoire;

  Future<String> lire() async {
    final memoire = _memoire;
    if (memoire != null) return memoire;
    final prefs = await _preferences();
    var id = prefs?.getString(cle);
    if (id == null || id.length < 16) {
      id = _nouveau();
      try {
        await prefs?.setString(cle, id);
      } catch (_) {
        // Stockage refusé : l'identifiant reste valable pour cette session.
      }
    }
    return _memoire = id;
  }

  static String _nouveau() {
    final hasard = Random.secure();
    final octets = List<int>.generate(24, (_) => hasard.nextInt(256));
    return octets.map((o) => o.toRadixString(16).padLeft(2, '0')).join();
  }
}
