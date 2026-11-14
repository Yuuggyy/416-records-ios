import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../abonnement/offres_screen.dart';
import '../compte/compte_screen.dart';
import '../../state/ma_liste.dart';
import 'ma_liste_screen.dart';

/// Profil : compte client réel (connexion, déconnexion, suppression),
/// abonnement et informations de l'application.
class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(Espace.m),
        children: const [
          _CarteCompte(),
          SizedBox(height: Espace.m),
          _LigneAbonnement(),
          SizedBox(height: Espace.s),
          _LigneMaListe(),
          SizedBox(height: Espace.s),
          SizedBox(height: Espace.l),
          Center(
            child: Text('Inspire by YuuStore', style: TextStyle(fontSize: 11, color: Pal.texteDoux, letterSpacing: 0.5)),
          ),
          Center(
            child: Text('+243 977 555 768', style: TextStyle(fontSize: 11, color: Pal.texteDoux)),
          ),
        ],
      ),
    );
  }
}

/// Entrée « Ma liste » : ouvre les films mis de côté, avec leur nombre.
class _LigneMaListe extends StatelessWidget {
  const _LigneMaListe();

  @override
  Widget build(BuildContext context) {
    final liste = MaListe.instance..initialiser();
    return AnimatedBuilder(
      animation: liste,
      builder: (context, _) => InkWell(
        borderRadius: BorderRadius.circular(Rayons.carte),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MaListeScreen()),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: Espace.s),
          padding: const EdgeInsets.all(Espace.m),
          decoration: BoxDecoration(
            color: Pal.surface,
            borderRadius: BorderRadius.circular(Rayons.carte),
            border: Border.all(color: Pal.bordure),
          ),
          child: Row(
            children: [
              const Icon(Icons.bookmark_border, size: 18, color: Pal.texteDoux),
              const SizedBox(width: Espace.m),
              const Expanded(child: Text('Ma liste', style: TextStyle(fontSize: 14))),
              Text(
                liste.films.isEmpty ? 'Films à voir' : '${liste.films.length} film${liste.films.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: Pal.texteDoux),
              ),
              const SizedBox(width: Espace.s),
              const Icon(Icons.chevron_right, size: 18, color: Pal.texteDoux),
            ],
          ),
        ),
      ),
    );
  }
}


/// Entrée « Mon abonnement » : montre l'état réel renvoyé par le serveur.
class _LigneAbonnement extends StatelessWidget {
  const _LigneAbonnement();

  @override
  Widget build(BuildContext context) {
    final controleur = CatalogueScope.of(context).abonnement;

    return AnimatedBuilder(
      animation: controleur,
      builder: (context, _) {
        final abonnement = controleur.abonnement;
        final String detail;
        final Color couleur;
        if (controleur.chargement) {
          detail = 'Vérification…';
          couleur = Pal.texteDoux;
        } else if (controleur.abonne && abonnement != null) {
          detail = 'Actif · ${abonnement.joursAffiches}';
          couleur = Pal.succes;
        } else if (controleur.enAttenteValidation) {
          detail = 'Paiement en attente de validation';
          couleur = Pal.alerte;
        } else {
          detail = 'Aucun abonnement en cours';
          couleur = Pal.texteDoux;
        }

        return Container(
          decoration: BoxDecoration(
            color: Pal.surface,
            borderRadius: BorderRadius.circular(Rayons.carte),
            border: Border.all(color: Pal.bordure),
          ),
          child: ListTile(
            leading: Icon(
              controleur.abonne ? Icons.workspace_premium : Icons.lock_outline,
              color: controleur.abonne ? Pal.succes : Pal.texteDoux,
              size: 20,
            ),
            title: const Text('Mon abonnement 416', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(detail, style: TextStyle(fontSize: 11, color: couleur)),
            trailing: const Icon(Icons.chevron_right, size: 18, color: Pal.texteDoux),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OffresScreen()),
            ),
          ),
        );
      },
    );
  }
}


/// Carte d'identité : visiteur, ou compte connecté avec ses actions.
class _CarteCompte extends StatelessWidget {
  const _CarteCompte();

  Future<void> _supprimer(BuildContext context) async {
    final compte = CatalogueScope.lire(context).compte;
    final champ = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre compte, votre clé d\'accès et votre abonnement seront effacés. Cette action est définitive.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: Espace.m),
            TextField(
              controller: champ,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Pal.danger)),
          ),
        ],
      ),
    );
    final motDePasse = champ.text;
    champ.dispose();
    if (confirme != true || !context.mounted) return;
    final ok = await compte.supprimer(motDePasse);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Compte supprimé.' : (compte.erreur ?? 'Suppression impossible.')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compte = CatalogueScope.of(context).compte;

    return AnimatedBuilder(
      animation: Listenable.merge([compte, CatalogueScope.of(context).abonnement]),
      builder: (context, _) {
        final connecte = compte.connecte;
        final titre = connecte ? compte.compte!.libelle : 'Visiteur';
        final motif = CatalogueScope.of(context).abonnement.motifDeconnexion;
        final detail = connecte ? 'Compte connecté' : (motif ?? 'Non connecté');

        return Container(
          padding: const EdgeInsets.all(Espace.m),
          decoration: BoxDecoration(
            color: Pal.surface,
            borderRadius: BorderRadius.circular(Rayons.carte),
            border: Border.all(color: Pal.bordure),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Pal.surfaceHaute,
                    child: connecte
                        ? Text(
                            titre.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          )
                        : const Icon(Icons.person, color: Pal.texteDoux),
                  ),
                  const SizedBox(width: Espace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(detail, style: const TextStyle(fontSize: 12, color: Pal.texteDoux)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espace.m),
              if (!connecte)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<bool>(builder: (_) => const CompteScreen()),
                        ),
                        child: const Text('SE CONNECTER'),
                      ),
                    ),
                    const SizedBox(width: Espace.s),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<bool>(builder: (_) => const CompteScreen(inscription: true)),
                        ),
                        child: const Text('CRÉER UN COMPTE'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: compte.occupe ? null : compte.deconnecter,
                        child: const Text('SE DÉCONNECTER'),
                      ),
                    ),
                    const SizedBox(width: Espace.s),
                    TextButton(
                      onPressed: compte.occupe ? null : () => _supprimer(context),
                      child: const Text('Supprimer', style: TextStyle(color: Pal.danger, fontSize: 12)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
