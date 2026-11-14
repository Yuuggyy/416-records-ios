import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../domain/paiement_en_ligne.dart';

/// Paiement Mobile Money en ligne, branché sur l'API 416 (PawaPay côté serveur).
///
/// L'application n'envoie jamais de montant : le serveur le déduit de l'offre
/// ou de la commande. Elle n'a pas non plus le pouvoir de déclarer qu'un
/// paiement est réussi : elle ne fait que demander l'état au serveur, qui le
/// relit lui-même chez l'opérateur.
class ServicePaiementHttp implements ServicePaiementEnLigne {
  ServicePaiementHttp({this.cle, http.Client? client, String? baseUrl, Duration? delai})
      : _client = client ?? http.Client(),
        _baseUrl = ApiConfig.normaliser(baseUrl ?? ApiConfig.base),
        _delai = delai ?? ApiConfig.delai;

  final String? cle;
  final http.Client _client;
  final String _baseUrl;
  final Duration _delai;

  Map<String, String> get _entetes => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (cle != null && cle!.trim().isNotEmpty) 'X-Abonnement-Key': cle!.trim(),
      };

  Future<Map<String, dynamic>> _appel(String chemin, {Map<String, dynamic>? corps}) async {
    final uri = ApiConfig.uri(_baseUrl, 'abonnements/paiement-en-ligne/$chemin');
    late http.Response r;
    try {
      r = corps == null
          ? await _client.get(uri, headers: _entetes).timeout(_delai)
          : await _client.post(uri, headers: _entetes, body: jsonEncode(corps)).timeout(_delai);
    } on TimeoutException {
      throw const ErreurPaiement('Le serveur met trop de temps à répondre. Réessayez dans un instant.');
    } catch (_) {
      throw const ErreurPaiement('Serveur injoignable. Vérifiez votre connexion.');
    }
    Map<String, dynamic> enveloppe = const {};
    try {
      final decode = jsonDecode(utf8.decode(r.bodyBytes));
      if (decode is Map) enveloppe = Map<String, dynamic>.from(decode);
    } catch (_) {}
    final message = (enveloppe['error'] as String?)?.trim();
    if (r.statusCode < 200 || r.statusCode >= 300 || (message != null && message.isNotEmpty)) {
      if (r.statusCode == 401) {
        throw const ErreurPaiement('Connectez-vous à votre compte 416 pour payer en ligne.', statut: 401);
      }
      throw ErreurPaiement(message ?? 'Paiement impossible (erreur ${r.statusCode}).', statut: r.statusCode);
    }
    final data = enveloppe['data'];
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  DepotLance _depot(Map<String, dynamic> d) {
    final id = '${d['deposit_id'] ?? ''}';
    if (id.isEmpty) throw const ErreurPaiement('Réponse du serveur illisible.');
    return DepotLance(
      identifiant: id,
      montant: '${d['montant'] ?? ''}',
      devise: '${d['devise'] ?? ''}',
      operateur: '${d['operateur'] ?? ''}',
      message: '${d['message'] ?? 'Validez le paiement sur votre téléphone.'}',
      sandbox: d['mode'] == 'sandbox',
    );
  }

  @override
  Future<({bool disponible, bool sandbox, List<OperateurEnLigne> operateurs})> operateurs() async {
    try {
      final d = await _appel('operateurs/');
      final liste = <OperateurEnLigne>[];
      final brut = d['operateurs'];
      if (brut is List) {
        for (final o in brut) {
          if (o is Map) {
            final op = OperateurEnLigne.depuisCode('${o['code']}');
            if (op != null) liste.add(op);
          }
        }
      }
      return (disponible: d['disponible'] == true && liste.isNotEmpty, sandbox: d['mode'] == 'sandbox', operateurs: liste);
    } on ErreurPaiement {
      return (disponible: false, sandbox: false, operateurs: const <OperateurEnLigne>[]);
    }
  }

  @override
  Future<DepotLance> payerAbonnement({
    required String codeOffre,
    required String numero,
    required OperateurEnLigne operateur,
  }) async =>
      _depot(await _appel('abonnement/', corps: {
        'offre': codeOffre,
        'numero': numero,
        'operateur': operateur.code,
      }));

  @override
  Future<DepotLance> payerCommande({
    required String reference,
    required String whatsapp,
    required String numero,
    required OperateurEnLigne operateur,
  }) async =>
      _depot(await _appel('commande/', corps: {
        'reference': reference,
        'whatsapp': whatsapp,
        'numero': numero,
        'operateur': operateur.code,
      }));

  @override
  Future<SuiviDepot> etat(String identifiant) async {
    final d = await _appel('etat/${Uri.encodeComponent(identifiant)}/');
    final etat = switch ('${d['statut']}') {
      'paye' => EtatDepot.paye,
      'echoue' => EtatDepot.echoue,
      'en_attente' => EtatDepot.enAttente,
      _ => EtatDepot.inconnu,
    };
    return SuiviDepot(etat: etat, motif: '${d['motif'] ?? ''}');
  }
}
