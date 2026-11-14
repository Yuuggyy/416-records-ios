import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../domain/depot_abonnement.dart';
import '../domain/models/abonnement.dart';
import '../domain/models/offre.dart';

/// Dépôt des abonnements branché sur l'API Django 416.
///
/// Deux règles tenues ici :
///   * la clé du compte voyage dans l'en-tête `X-Abonnement-Key`, jamais dans
///     l'URL (elle ne doit pas finir dans des journaux d'accès) ;
///   * les refus sont traduits en objet métier : 402 → [AccesRefuse] avec le
///     message du serveur, 401 → clé absente ou invalide, le reste →
///     [ErreurAbonnement]. Aucun code HTTP ne remonte à l'interface.
class DepotAbonnementHttp implements DepotAbonnement {
  DepotAbonnementHttp({
    required this.cle,
    http.Client? client,
    String? baseUrl,
    Duration? delai,
  })  : _client = client ?? http.Client(),
        _baseUrl = ApiConfig.normaliser(baseUrl ?? ApiConfig.base),
        _delai = delai ?? ApiConfig.delai;

  @override
  final String? cle;

  final http.Client _client;
  final String _baseUrl;
  final Duration _delai;

  Map<String, String> get _entetes => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (cle != null && cle!.trim().isNotEmpty) 'X-Abonnement-Key': cle!.trim(),
      };

  Future<Map<String, dynamic>> _demander(
    String chemin, {
    String methode = 'GET',
    Map<String, dynamic>? corps,
  }) async {
    final uri = ApiConfig.uri(_baseUrl, chemin);

    late http.Response reponse;
    try {
      if (methode == 'POST') {
        reponse = await _client
            .post(uri, headers: _entetes, body: corps == null ? null : jsonEncode(corps))
            .timeout(_delai);
      } else {
        reponse = await _client.get(uri, headers: _entetes).timeout(_delai);
      }
    } on TimeoutException {
      throw const ErreurAbonnement('Le serveur met trop de temps à répondre. Réessayez dans un instant.');
    } catch (_) {
      throw const ErreurAbonnement('Serveur d\'abonnement injoignable. Vérifiez votre connexion.');
    }

    Map<String, dynamic> enveloppe = const {};
    try {
      // Certains serveurs répondent en Latin-1 : on décode alors sans casser
      // les accents du message au lieu de perdre le texte de l'erreur.
      String texte;
      try {
        texte = utf8.decode(reponse.bodyBytes);
      } on FormatException {
        texte = latin1.decode(reponse.bodyBytes);
      }
      final decode = jsonDecode(texte);
      if (decode is Map) enveloppe = Map<String, dynamic>.from(decode);
    } catch (_) {
      // Réponse non JSON (page d'erreur HTML) : traitée comme un échec lisible.
    }

    final message = (enveloppe['error'] as String?)?.trim();
    final statut = reponse.statusCode;
    final meta = enveloppe['meta'];
    final code = meta is Map && meta['code'] is String ? meta['code'] as String : null;

    if (statut == 402) {
      throw AccesRefuse(message ?? 'Ce contenu est réservé aux abonnés 416.', statut: statut);
    }
    if (statut == 401) {
      throw ErreurAbonnement(
        message ?? 'Compte non identifié : renseignez votre clé d\'abonnement 416.',
        statut: statut,
        code: code,
      );
    }
    if (statut < 200 || statut >= 300) {
      throw ErreurAbonnement(
        message ?? 'Erreur du service d\'abonnement (HTTP $statut).',
        statut: statut,
      );
    }
    if (message != null && message.isNotEmpty) {
      throw ErreurAbonnement(message, statut: statut);
    }
    return enveloppe;
  }

  @override
  Future<List<Offre>> offres() async {
    final enveloppe = await _demander('abonnements/offres/');
    final data = enveloppe['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Offre.depuisJson)
        .where((offre) => offre.actif)
        .toList(growable: false);
  }

  @override
  Future<EtatAbonnement> monAbonnement() async {
    final enveloppe = await _demander('abonnements/mon-abonnement/');
    final data = enveloppe['data'];
    if (data is! Map) {
      throw const ErreurAbonnement('Réponse d\'abonnement illisible.');
    }
    return EtatAbonnement.depuisJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<({Abonnement abonnement, Paiement paiement})> souscrire({
    required String codeOffre,
    required OperateurMobileMoney operateur,
    required String numeroTransaction,
    String preuve = '',
  }) async {
    final enveloppe = await _demander(
      'abonnements/souscriptions/',
      methode: 'POST',
      corps: {
        'offre': codeOffre,
        'operateur': operateur.cle,
        'numero_transaction': numeroTransaction,
        if (preuve.trim().isNotEmpty) 'preuve': preuve.trim(),
      },
    );

    final data = enveloppe['data'];
    if (data is! Map) {
      throw const ErreurAbonnement('Souscription enregistrée mais réponse illisible.');
    }
    final carte = Map<String, dynamic>.from(data);

    final abonnementJson = carte['abonnement'];
    final paiementJson = carte['paiement'];
    if (abonnementJson is! Map || paiementJson is! Map) {
      throw const ErreurAbonnement('Souscription enregistrée mais réponse incomplète.');
    }

    return (
      abonnement: Abonnement.depuisJson(Map<String, dynamic>.from(abonnementJson)),
      paiement: Paiement.depuisJson(Map<String, dynamic>.from(paiementJson)),
    );
  }

  @override
  Future<LectureAutorisee> lectureFilm(String slug) async {
    final enveloppe = await _demander('films/$slug/lecture/');
    final data = enveloppe['data'];
    if (data is! Map) {
      throw const ErreurAbonnement('Réponse de lecture illisible.');
    }
    return LectureAutorisee.depuisJson(Map<String, dynamic>.from(data));
  }
}
