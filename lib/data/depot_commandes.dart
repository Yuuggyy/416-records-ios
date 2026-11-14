import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../domain/models/panier.dart';

/// Résultat d'un envoi de commande.
class CommandeEnvoyee {
  const CommandeEnvoyee({
    required this.reference,
    required this.statutLibelle,
    required this.total,
    required this.devise,
    required this.fraisLivraison,
    required this.modeLivraison,
    required this.whatsapp,
    required this.lignes,
    this.instructionsPaiement = '',
    this.lienPaiement = '',
  });

  final String reference;
  final String statutLibelle;
  final String total;
  final String devise;
  final String fraisLivraison;
  final String modeLivraison;
  final String whatsapp;
  final int lignes;
  final String instructionsPaiement;
  final String lienPaiement;

  factory CommandeEnvoyee.depuisJson(Map<String, dynamic> d, Map<String, dynamic> meta) {
    final paiement = (meta['paiement'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CommandeEnvoyee(
      reference: (d['reference'] ?? '').toString(),
      statutLibelle: (d['statut_libelle'] ?? '').toString(),
      total: (d['total'] ?? '').toString(),
      devise: (d['devise'] ?? 'USD').toString(),
      fraisLivraison: (d['frais_livraison'] ?? '0').toString(),
      modeLivraison: (d['mode_livraison'] ?? '').toString(),
      whatsapp: (d['whatsapp'] ?? '').toString(),
      lignes: (d['lignes'] as List?)?.length ?? 0,
      instructionsPaiement: (paiement['instructions'] ?? '').toString(),
      lienPaiement: (paiement['url'] ?? '').toString(),
    );
  }
}

/// Erreur lisible renvoyée par le serveur (message en français, jamais une trace).
class ErreurCommande implements Exception {
  const ErreurCommande(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Envoi des commandes de merch au backend Django.
class DepotCommandes {
  DepotCommandes({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = ApiConfig.normaliser(baseUrl ?? ApiConfig.base);

  final http.Client _client;
  final String _baseUrl;

  /// Envoie le panier. Lève [ErreurCommande] avec un message affichable.
  Future<CommandeEnvoyee> envoyer({
    required Panier panier,
    required String nom,
    required String whatsapp,
    required String modeLivraison,
    String adresse = '',
    String quartier = '',
    String notes = '',
    Map<String, String> precisions = const {},
  }) async {
    final corps = {
      'nom': nom.trim(),
      'whatsapp': whatsapp.trim(),
      'mode_livraison': modeLivraison,
      if (adresse.trim().isNotEmpty) 'adresse': adresse.trim(),
      if (quartier.trim().isNotEmpty) 'quartier': quartier.trim(),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      'articles': panier.lignes
          .map((l) => {
                'produit_id': l.produitId,
                'quantite': l.quantite,
                if (l.taille.isNotEmpty) 'taille': l.taille,
                if ((precisions[l.cle] ?? '').trim().isNotEmpty)
                  'precision': precisions[l.cle]!.trim(),
              })
          .toList(),
    };

    http.Response reponse;
    try {
      reponse = await _client
          .post(
            ApiConfig.uri(_baseUrl, 'boutique/commandes/'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(corps),
          )
          .timeout(ApiConfig.delai);
    } on TimeoutException {
      throw const ErreurCommande(
        'Le serveur met trop de temps à répondre. Vérifiez votre connexion et réessayez.',
      );
    } catch (_) {
      throw const ErreurCommande(
        'Impossible de joindre le serveur. Vérifiez la connexion internet.',
      );
    }

    Map<String, dynamic> charge;
    try {
      charge = jsonDecode(utf8.decode(reponse.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const ErreurCommande('Réponse illisible du serveur. Réessayez dans un instant.');
    }

    if (reponse.statusCode != 201 || charge['data'] == null) {
      final message = (charge['error'] ?? '').toString();
      throw ErreurCommande(
        message.isEmpty ? 'La commande n\'a pas pu être enregistrée.' : message,
      );
    }

    return CommandeEnvoyee.depuisJson(
      (charge['data'] as Map).cast<String, dynamic>(),
      (charge['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Ouvre WhatsApp sur le numéro de la boutique, message déjà écrit.
  Future<bool> ecrireAuLabel(String whatsappBoutique, String message) async {
    final numero = whatsappBoutique.replaceAll(RegExp(r'[^\d+]'), '');
    final lien = Uri.parse(
      'https://wa.me/${numero.replaceFirst('+', '')}?text=${Uri.encodeComponent(message)}',
    );
    try {
      return await launchUrl(lien, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
