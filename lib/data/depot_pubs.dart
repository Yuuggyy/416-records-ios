import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Une annonce telle que le serveur la décrit.
class Annonce {
  const Annonce({
    required this.id,
    required this.titre,
    required this.imageUrl,
    required this.lien,
    required this.dureeSecondes,
  });

  final int id;
  final String titre;
  final String imageUrl;
  final String lien;
  final int dureeSecondes;

  static Annonce? depuisJson(Object? brut) {
    if (brut is! Map) return null;
    final id = brut['id'];
    if (id is! int) return null;
    return Annonce(
      id: id,
      titre: '${brut['titre'] ?? ''}',
      imageUrl: '${brut['image_url'] ?? ''}',
      lien: '${brut['lien'] ?? ''}',
      dureeSecondes: (brut['duree_secondes'] is int) ? brut['duree_secondes'] as int : 15,
    );
  }
}

/// Récupère l'annonce à montrer. Le SERVEUR décide : un compte premium reçoit
/// toujours « aucune pub ». Toute panne réseau donne aussi « aucune pub » :
/// une publicité ne doit jamais bloquer ni faire planter l'application.
class DepotPubs {
  DepotPubs({http.Client? client, String? baseUrl, this.cle})
      : _client = client ?? http.Client(),
        _baseUrl = ApiConfig.normaliser(baseUrl ?? ApiConfig.base);

  final http.Client _client;
  final String _baseUrl;
  final String? cle;

  Map<String, String> get _entetes => {
        'Accept': 'application/json',
        if (cle != null && cle!.trim().isNotEmpty) 'X-Abonnement-Key': cle!.trim(),
      };

  Future<Annonce?> suivante(String emplacement) async {
    try {
      final r = await _client
          .get(ApiConfig.uri(_baseUrl, 'abonnements/pubs/$emplacement/'), headers: _entetes)
          .timeout(ApiConfig.delai);
      if (r.statusCode != 200) return null;
      final corps = jsonDecode(utf8.decode(r.bodyBytes));
      if (corps is! Map) return null;
      final data = corps['data'];
      if (data is! Map) return null;
      return Annonce.depuisJson(data['pub']);
    } catch (_) {
      return null;
    }
  }

  /// Compte un affichage (`vu`) ou un clic (`clic`). Sans effet visible en cas d'échec.
  Future<void> signaler(int id, String evenement) async {
    try {
      await _client
          .post(ApiConfig.uri(_baseUrl, 'abonnements/pubs/$id/$evenement/'), headers: _entetes)
          .timeout(ApiConfig.delai);
    } catch (_) {}
  }
}
