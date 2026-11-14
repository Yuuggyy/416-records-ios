import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/identifiant_appareil.dart';
import '../domain/depot_comptes.dart';
import '../domain/models/compte.dart';

/// Dépôt des comptes branché sur `/api/comptes/` (backend Django 416).
///
/// Ces routes n'existent que sur le vrai backend. Sur le pont temporaire
/// Base44 elles répondent 404 : on le dit clairement à l'utilisateur au lieu
/// d'afficher une erreur technique.
class DepotComptesHttp implements DepotComptes {
  DepotComptesHttp({http.Client? client, String? baseUrl, Duration? delai, IdentifiantAppareil? appareil})
      : _client = client ?? http.Client(),
        _appareil = appareil ?? IdentifiantAppareil(),
        _baseUrl = ApiConfig.normaliser(baseUrl ?? ApiConfig.base),
        _delai = delai ?? ApiConfig.delai;

  final http.Client _client;
  final IdentifiantAppareil _appareil;
  final String _baseUrl;
  final Duration _delai;

  Future<Map<String, dynamic>> _appeler(
    String chemin, {
    String methode = 'POST',
    Map<String, dynamic>? corps,
    String? cle,
  }) async {
    final uri = ApiConfig.uri(_baseUrl, 'comptes/$chemin');
    final entetes = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Appareil': await _appareil.lire(),
      if (cle != null && cle.trim().isNotEmpty) 'X-Abonnement-Key': cle.trim(),
    };

    late http.Response reponse;
    try {
      reponse = methode == 'GET'
          ? await _client.get(uri, headers: entetes).timeout(_delai)
          : await _client.post(uri, headers: entetes, body: jsonEncode(corps ?? {})).timeout(_delai);
    } on TimeoutException {
      throw const ErreurCompte('Le serveur met trop de temps à répondre. Réessayez dans un instant.');
    } catch (_) {
      throw const ErreurCompte('Serveur injoignable. Vérifiez votre connexion.');
    }

    Map<String, dynamic> enveloppe = const {};
    try {
      final decode = jsonDecode(utf8.decode(reponse.bodyBytes, allowMalformed: true));
      if (decode is Map<String, dynamic>) enveloppe = decode;
    } catch (_) {
      // Corps non JSON : traité plus bas selon le code HTTP.
    }

    final statut = reponse.statusCode;
    if (statut >= 200 && statut < 300) {
      final data = enveloppe['data'];
      if (data is Map<String, dynamic>) return data;
      throw const ErreurCompte('Réponse inattendue du serveur.');
    }

    final meta = enveloppe['meta'];
    final code = meta is Map && meta['code'] is String ? meta['code'] as String : null;
    final message = enveloppe['error'];
    if (message is String && message.trim().isNotEmpty) {
      throw ErreurCompte(message, statut: statut, code: code);
    }
    if (statut == 404) {
      throw ErreurCompte(
        'Les comptes ne sont pas encore disponibles sur ce serveur.',
        statut: statut,
      );
    }
    if (statut == 429) {
      throw ErreurCompte('Trop d\'essais. Réessayez dans quelques minutes.', statut: statut);
    }
    throw ErreurCompte('Le service est momentanément indisponible ($statut).', statut: statut);
  }

  SessionCompte _session(Map<String, dynamic> data) {
    final cle = data['cle'];
    if (cle is! String || cle.isEmpty) {
      throw const ErreurCompte('Réponse inattendue du serveur.');
    }
    return SessionCompte(compte: Compte.depuisJson(data), cle: cle);
  }

  @override
  Future<SessionCompte> inscrire({
    required String identifiant,
    required String motDePasse,
    String nom = '',
  }) async {
    final data = await _appeler('inscription/', corps: {
      'identifiant': identifiant.trim(),
      'mot_de_passe': motDePasse,
      'nom': nom.trim(),
    });
    return _session(data);
  }

  @override
  Future<SessionCompte> connecter({
    required String identifiant,
    required String motDePasse,
  }) async {
    final data = await _appeler('connexion/', corps: {
      'identifiant': identifiant.trim(),
      'mot_de_passe': motDePasse,
    });
    return _session(data);
  }

  @override
  Future<Compte> moi(String cle) async {
    final data = await _appeler('moi/', methode: 'GET', cle: cle);
    return Compte.depuisJson(data);
  }

  @override
  Future<void> supprimer({required String cle, required String motDePasse}) async {
    await _appeler('supprimer/', cle: cle, corps: {'mot_de_passe': motDePasse});
  }
}
