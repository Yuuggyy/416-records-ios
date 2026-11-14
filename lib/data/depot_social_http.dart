import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/contexte_appareil.dart';
import '../core/identifiant_appareil.dart';
import '../domain/depot_social.dart';
import '../domain/models/compte.dart';

/// Connexion par un tiers branchée sur `/api/comptes/` (Google, Telegram).
class DepotSocialHttp implements DepotSocial {
  DepotSocialHttp({
    http.Client? client,
    String? baseUrl,
    Duration? delai,
    IdentifiantAppareil? appareil,
    String Function()? contexte,
  })
      : _client = client ?? http.Client(),
        _appareil = appareil ?? IdentifiantAppareil(),
        _contexte = contexte ?? contexteAppareil,
        _baseUrl = ApiConfig.normaliser(baseUrl ?? ApiConfig.base),
        _delai = delai ?? ApiConfig.delai;

  final http.Client _client;
  final IdentifiantAppareil _appareil;
  final String Function() _contexte;
  final String _baseUrl;
  final Duration _delai;

  final Map<String, String> _secrets = {};

  Future<Map<String, dynamic>?> _appeler(
    String chemin, {
    String methode = 'GET',
    Map<String, dynamic>? corps,
    Map<String, String>? entetesPlus,
  }) async {
    final uri = ApiConfig.uri(_baseUrl, 'comptes/$chemin');
    final entetes = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Appareil': await _appareil.lire(),
      ...?entetesPlus,
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
      // Corps inattendu : traité selon le code HTTP.
    }

    final statut = reponse.statusCode;
    if (statut >= 200 && statut < 300) {
      final data = enveloppe['data'];
      return data is Map<String, dynamic> ? data : null;
    }
    final message = enveloppe['error'];
    if (message is String && message.trim().isNotEmpty) {
      throw ErreurCompte(message, statut: statut);
    }
    throw ErreurCompte('Connexion impossible pour le moment ($statut).', statut: statut);
  }

  SessionCompte _session(Map<String, dynamic> data) {
    final cle = data['cle'];
    if (cle is! String || cle.isEmpty) {
      throw const ErreurCompte('Réponse inattendue du serveur.');
    }
    return SessionCompte(compte: Compte.depuisJson(data), cle: cle);
  }

  @override
  Future<FournisseursConnexion> fournisseurs() async {
    final data = await _appeler('fournisseurs/');
    return FournisseursConnexion.depuisJson(data ?? const {});
  }

  @override
  Future<SessionCompte> google(String jetonIdentite) async {
    final data = await _appeler('google/', methode: 'POST', corps: {'id_token': jetonIdentite});
    return _session(data ?? const {});
  }

  @override
  Future<DemandeTelegram> demarrerTelegram() async {
    String contexte = '';
    try {
      contexte = _contexte();
    } catch (_) {
      // Simple indication d'affichage : jamais une raison d'échouer.
    }
    final data = await _appeler(
      'telegram/demarrer/',
      methode: 'POST',
      entetesPlus: contexte.isEmpty ? null : {'X-Contexte': contexte},
    );
    final demande = DemandeTelegram.depuisJson(data ?? const {});
    // Le secret reste dans cet appareil : il n'est jamais mis dans le lien
    // Telegram, donc un lien transmis à un tiers ne permet pas de voler la session.
    final secret = '${(data ?? const {})['secret'] ?? ''}';
    if (secret.isNotEmpty) _secrets[demande.jeton] = secret;
    return demande;
  }

  @override
  Future<SessionCompte?> etatTelegram(String jeton) async {
    final secret = _secrets[jeton];
    final data = await _appeler(
      'telegram/etat/$jeton/',
      entetesPlus: secret == null ? null : {'X-Telegram-Secret': secret},
    );
    if (data != null) _secrets.remove(jeton);
    if (data == null) return null;
    return _session(data);
  }
}
