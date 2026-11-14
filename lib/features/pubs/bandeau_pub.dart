import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../data/depot_pubs.dart';

/// Bandeau publicitaire discret, au-dessus de la barre d'onglets.
///
/// - Le serveur décide : un compte premium, l'absence de campagne ou une panne
///   réseau donnent « aucune annonce », et alors le bandeau n'occupe aucune place.
/// - L'étiquette « PUB » est toujours visible.
/// - Un appui ouvre le lien de l'annonceur et compte un clic.
class BandeauPub extends StatefulWidget {
  const BandeauPub({super.key, this.depot});

  /// Dépôt imposé (tests). Par défaut : le serveur, avec la clé du compte.
  final DepotPubs? depot;

  @override
  State<BandeauPub> createState() => _BandeauPubState();
}

class _BandeauPubState extends State<BandeauPub> {
  DepotPubs? _depot;
  Annonce? _annonce;
  Timer? _rotation;
  bool _demarre = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_demarre) return;
    _demarre = true;
    _depot = widget.depot ?? DepotPubs(cle: CatalogueScope.lire(context).abonnement.cle);
    _charger();
  }

  Future<void> _charger() async {
    Annonce? annonce;
    try {
      annonce = await _depot!.suivante('bandeau');
    } catch (_) {
      annonce = null;
    }
    if (!mounted) return;
    setState(() => _annonce = annonce);
    _rotation?.cancel();
    if (annonce != null) {
      unawaited(_depot!.signaler(annonce.id, 'vu'));
      _rotation = Timer(Duration(seconds: annonce.dureeSecondes.clamp(5, 60)), _charger);
    }
  }

  @override
  void dispose() {
    _rotation?.cancel();
    super.dispose();
  }

  Future<void> _ouvrir() async {
    final a = _annonce;
    if (a == null || a.lien.isEmpty) return;
    unawaited(_depot!.signaler(a.id, 'clic'));
    final uri = Uri.tryParse(a.lien);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _annonce;
    if (a == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Publicité : ${a.titre}',
      button: a.lien.isNotEmpty,
      child: GestureDetector(
        onTap: _ouvrir,
        child: Container(
          height: 56,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: Espace.m),
          decoration: const BoxDecoration(
            color: Pal.surface,
            border: Border(top: BorderSide(color: Pal.bordure)),
          ),
          child: Row(
            children: [
              if (a.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    a.imageUrl,
                    width: 72,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 40),
                  ),
                ),
                const SizedBox(width: Espace.s),
              ],
              const Text('PUB', style: TextStyle(fontSize: 9, letterSpacing: 1.2, color: Pal.texteDoux)),
              const SizedBox(width: Espace.s),
              Expanded(
                child: Text(a.titre,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ),
              if (a.lien.isNotEmpty) const Icon(Icons.chevron_right, size: 18, color: Pal.texteDoux),
            ],
          ),
        ),
      ),
    );
  }
}
