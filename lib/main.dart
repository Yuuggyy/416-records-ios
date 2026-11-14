import 'dart:async';

import 'package:flutter/material.dart';
import 'features/pubs/bandeau_pub.dart';
import 'data/service_levelplay.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/config.dart';
import 'core/scope.dart';
import 'core/theme.dart';
import 'data/depot_abonnement_http.dart';
import 'data/depot_comptes_http.dart';
import 'data/depot_http.dart';
import 'data/depot_social_http.dart';
import 'data/local/cache_catalogue.dart';
import 'domain/depot_catalogue.dart';
import 'features/accueil/accueil_screen.dart';
import 'features/compte/compte_screen.dart';
import 'features/artistes/artistes_screen.dart';
import 'features/films/films_screen.dart';
import 'features/merch/merch_screen.dart';
import 'features/profil/profil_screen.dart';
import 'state/controleur_abonnement.dart';
import 'state/controleur_compte.dart';
import 'state/controleur_panier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cache = CachePreferences(preferences: await _preferencesSure());
  final depot = DepotHttp(cache: cache);
  final panier = ControleurPanier();
  await panier.initialiser();

  final abonnement = ControleurAbonnement(
    stockage: StockageClePreferences(preferences: await _preferencesSure()),
    creerDepot: (cle) => DepotAbonnementHttp(cle: cle),
  );
  // Chargement en arrière-plan : l'application s'ouvre sans attendre le réseau.
  final compte = ControleurCompte(
    depot: DepotComptesHttp(),
    abonnement: abonnement,
    social: DepotSocialHttp(),
  );
  // La clé enregistrée est relue d'abord, puis le compte qui lui correspond.
  unawaited(abonnement.initialiser().then((_) => compte.initialiser()));

  // Pubs : démarrage en arrière-plan, sans jamais bloquer l'ouverture.
  unawaited(ServiceLevelPlay.instance.initialiser());

  runApp(Records416App(depot: depot, panier: panier, abonnement: abonnement, compte: compte));
}

/// `SharedPreferences` peut échouer (stockage restreint). L'application doit
/// démarrer quand même : on retombe alors sur un cache mémoire.
Future<SharedPreferences?> _preferencesSure() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (_) {
    return null;
  }
}

class Records416App extends StatelessWidget {
  const Records416App({
    super.key,
    required this.depot,
    required this.panier,
    required this.abonnement,
    required this.compte,
  });

  final DepotCatalogue depot;
  final ControleurPanier panier;
  final ControleurAbonnement abonnement;
  final ControleurCompte compte;

  @override
  Widget build(BuildContext context) {
    return CatalogueScope(
      depot: depot,
      panier: panier,
      abonnement: abonnement,
      compte: compte,
      child: MaterialApp(
        title: '416 Records',
        debugShowCheckedModeBanner: false,
        theme: construireTheme(),
        home: const Shell(),
      ),
    );
  }
}

/// Barre de navigation principale du catalogue.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  /// Onglet choisi par la personne. `null` = choix automatique : la boutique
  /// pour un visiteur, l'accueil pour un membre connecté.
  int? _onglet;

  /// Écrans qui demandent un compte. Seule la boutique (merch, panier, commande)
  /// reste ouverte sans connexion : c'est la seule chose qu'un visiteur peut
  /// faire, et elle doit rester possible sans compte.
  static const Set<int> _prives = {0, 1, 2, 4};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Retour au premier plan : si le démarrage n'a pas pu joindre le serveur
  /// (réseau coupé, serveur en veille), on retrouve le compte sans que la
  /// personne ait à se reconnecter.
  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat != AppLifecycleState.resumed) return;
    final scope = CatalogueScope.lire(context);
    scope.compte.verifierTelegramMaintenant();
    if (scope.compte.connecte || !scope.abonnement.aUneCle) return;
    unawaited(scope.compte.reverifier());
  }

  static const List<Widget> _ecrans = [
    AccueilScreen(),
    FilmsScreen(),
    ArtistesScreen(),
    MerchScreen(),
    ProfilScreen(),
  ];

  Future<void> _ouvrir(int index, ControleurCompte compte) async {
    if (_prives.contains(index) && !compte.connecte) {
      // L'onglet reste visible, mais son contenu demande une connexion.
      final ouvert = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const CompteScreen()),
      );
      if (!mounted) return;
      if (ouvert != true) return;
    }
    setState(() => _onglet = index);
  }

  @override
  Widget build(BuildContext context) {
    final scope = CatalogueScope.of(context);
    final panier = scope.panier;
    final compte = scope.compte;

    return AnimatedBuilder(
      animation: compte,
      builder: (context, _) {
        final index = _onglet ?? (compte.connecte ? 0 : 3);
        return Scaffold(
          body: IndexedStack(index: index, children: _ecrans),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BandeauPub(),
              AnimatedBuilder(
                animation: panier,
                builder: (context, _) {
                  return BarreOnglets(
                    index: index,
                    onChanger: (i) => _ouvrir(i, compte),
                    badge: panier.nombreArticles > 0 ? panier.badge : null,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Barre d'onglets du label : filet, étiquettes en mono, accent sur l'actif.
class BarreOnglets extends StatelessWidget {
  const BarreOnglets({super.key, required this.index, required this.onChanger, this.badge});

  final int index;
  final ValueChanged<int> onChanger;
  final String? badge;

  static const _onglets = [
    ('ACCUEIL', Icons.home_outlined),
    ('FILMS', Icons.movie_outlined),
    ('ARTISTES', Icons.people_outline),
    ('BOUTIQUE', Icons.shopping_bag_outlined),
    ('PROFIL', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Pal.fond,
        border: Border(top: BorderSide(color: Pal.filet)),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _onglets.length; i++)
            GestureDetector(
              onTap: () => onChanger(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: i == 3 && badge != null,
                    label: Text(badge ?? '', style: const TextStyle(fontSize: 9)),
                    backgroundColor: Pal.primaire,
                    child: Icon(
                      _onglets[i].$2,
                      size: 20,
                      color: i == index ? Pal.texte : Pal.texteDoux,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _onglets[i].$1,
                    style: Typo.etiquette.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      color: i == index ? Pal.primaire : Pal.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Rappel de l'adresse de l'API pour les builds de mise au point.
String get adresseApi => ApiConfig.base;
