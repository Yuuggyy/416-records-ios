import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/web/bouton_google.dart';
import '../../core/web/fenetre.dart';
import '../../design/primitives.dart';

/// Connexion et inscription sur un seul écran, deux onglets.
///
/// Se ferme tout seul (`pop(true)`) dès que le compte est ouvert, pour que
/// l'écran appelant, par exemple « Regarder » sur un film premium, reprenne
/// là où l'utilisateur s'était arrêté.
class CompteScreen extends StatefulWidget {
  const CompteScreen({super.key, this.inscription = false});

  /// Ouvre directement l'onglet d'inscription.
  final bool inscription;

  @override
  State<CompteScreen> createState() => _CompteScreenState();
}

class _CompteScreenState extends State<CompteScreen> {
  final _formulaire = GlobalKey<FormState>();
  final _identifiant = TextEditingController();
  final _motDePasse = TextEditingController();
  final _nom = TextEditingController();
  late bool _inscription = widget.inscription;
  bool _masque = true;
  bool _attenteTelegram = false;
  String? _lienTelegram;
  StreamSubscription<GoogleSignInAccount?>? _abonnementGoogle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Les boutons de connexion n'apparaissent que si le serveur les annonce
    // comme configurés (Google est de plus masqué par ApiConfig.googleVisible).
    CatalogueScope.lire(context).compte.chargerFournisseurs();
    _ecouterGoogleWeb();
  }

  /// Web : le bouton officiel de Google rend l'identité par ce flux.
  void _ecouterGoogleWeb() {
    if (!ApiConfig.googleVisible || !kIsWeb || _abonnementGoogle != null || ApiConfig.identifiantGoogle.isEmpty) return;
    final google = GoogleSignIn(
      clientId: ApiConfig.identifiantGoogle,
      scopes: const ['email'],
    );
    _abonnementGoogle = google.onCurrentUserChanged.listen((utilisateur) async {
      if (utilisateur == null || !mounted) return;
      final compte = CatalogueScope.lire(context).compte;
      try {
        final identite = await utilisateur.authentication;
        final jeton = identite.idToken;
        if (jeton == null || jeton.isEmpty) {
          _avertir('Connexion Google interrompue. Réessayez.');
          return;
        }
        final ok = await compte.connecterGoogle(jeton);
        if (ok && mounted) Navigator.of(context).pop(true);
      } catch (_) {
        _avertir('Connexion Google impossible pour le moment. Réessayez dans un instant.');
      }
    });
    // Reconnaît une session Google déjà ouverte dans le navigateur.
    google.signInSilently();
  }

  void _avertir(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Connexion Google : Google rend un jeton d'identité, le serveur le vérifie.
  Future<void> _google() async {
    final compte = CatalogueScope.lire(context).compte;
    if (ApiConfig.identifiantGoogle.isEmpty) return;
    // Sur Android, c'est serverClientId qui fait renvoyer un jeton d'identité.
    // Sur le web, google_sign_in attend clientId : sans lui, la fenêtre
    // Google s'ouvre mais ne rend aucun jeton.
    final google = GoogleSignIn(
      clientId: kIsWeb ? ApiConfig.identifiantGoogle : null,
      serverClientId: ApiConfig.identifiantGoogle,
      scopes: const ['email'],
    );
    try {
      final utilisateur = await google.signIn();
      final identite = await utilisateur?.authentication;
      final jeton = identite?.idToken;
      if (jeton == null || jeton.isEmpty) {
        await google.signOut();
        compte.effacerErreur();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connexion Google interrompue. Réessayez.')),
          );
        }
        return;
      }
      final ok = await compte.connecterGoogle(jeton);
      if (ok && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion Google impossible pour le moment. Réessayez dans un instant.')),
        );
      }
    }
  }

  /// Connexion Telegram : on ouvre le robot, la personne appuie sur Démarrer,
  /// l'application attend la confirmation puis se ferme d'elle-même.
  Future<void> _telegram() async {
    final compte = CatalogueScope.lire(context).compte;
    // Sur le web, l'onglet doit s'ouvrir pendant le clic, avant l'appel réseau.
    final fenetre = kIsWeb ? FenetreExterne.ouvrirVide() : null;
    final demande = await compte.demarrerTelegram();
    if (demande == null) {
      fenetre?.fermer();
      return;
    }
    setState(() => _attenteTelegram = true);
    if (fenetre != null) {
      fenetre.aller(demande.lien);
    } else {
      var ouvert = false;
      try {
        ouvert = await launchUrl(Uri.parse(demande.lien), mode: LaunchMode.externalApplication);
      } catch (_) {
        ouvert = false;
      }
      // Telegram ne s'est pas ouvert : on garde le lien à portée de main.
      if (!ouvert && mounted) setState(() => _lienTelegram = demande.lien);
    }
    if (kIsWeb && mounted) setState(() => _lienTelegram = demande.lien);
    final ok = await compte.attendreTelegram(demande.jeton);
    if (!mounted) return;
    setState(() {
      _attenteTelegram = false;
      _lienTelegram = null;
    });
    if (ok) {
      Navigator.of(context).pop(true);
    } else if (compte.erreur == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmation Telegram non reçue. Réessayez.')),
      );
    }
  }

  @override
  void dispose() {
    _abonnementGoogle?.cancel();
    _identifiant.dispose();
    _motDePasse.dispose();
    _nom.dispose();
    super.dispose();
  }

  String? _validerIdentifiant(String? v) {
    final texte = (v ?? '').trim();
    if (texte.isEmpty) return 'Saisissez votre e-mail ou votre téléphone.';
    if (texte.contains('@')) {
      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texte);
      return ok ? null : 'Adresse e-mail invalide.';
    }
    final chiffres = texte.replaceAll(RegExp(r'[^\d]'), '');
    return chiffres.length >= 9 ? null : 'Numéro de téléphone invalide.';
  }

  String? _validerMotDePasse(String? v) {
    final texte = v ?? '';
    if (texte.isEmpty) return 'Saisissez votre mot de passe.';
    if (_inscription && texte.length < 8) return '8 caractères minimum.';
    return null;
  }

  Future<void> _envoyer() async {
    if (!(_formulaire.currentState?.validate() ?? false)) return;
    final compte = CatalogueScope.lire(context).compte;
    final ok = _inscription
        ? await compte.inscrire(
            identifiant: _identifiant.text,
            motDePasse: _motDePasse.text,
            nom: _nom.text,
          )
        : await compte.connecter(identifiant: _identifiant.text, motDePasse: _motDePasse.text);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _basculer(bool inscription) {
    CatalogueScope.lire(context).compte.effacerErreur();
    setState(() => _inscription = inscription);
  }

  @override
  Widget build(BuildContext context) {
    final compte = CatalogueScope.of(context).compte;

    return Scaffold(
      appBar: AppBar(title: Text(_inscription ? 'Créer un compte' : 'Connexion')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([compte, CatalogueScope.of(context).abonnement]),
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(Espace.m),
              children: [
                Row(
                  children: [
                    Expanded(child: _Onglet(libelle: 'Connexion', actif: !_inscription, onTap: () => _basculer(false))),
                    const SizedBox(width: Espace.m),
                    Expanded(child: _Onglet(libelle: 'Inscription', actif: _inscription, onTap: () => _basculer(true))),
                  ],
                ),
                const Filet(),
                const SizedBox(height: Espace.l),
                Form(
                  key: _formulaire,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_inscription) ...[
                        TextFormField(
                          controller: _nom,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(labelText: 'Nom (facultatif)'),
                        ),
                        const SizedBox(height: Espace.m),
                      ],
                      TextFormField(
                        controller: _identifiant,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        validator: _validerIdentifiant,
                        decoration: const InputDecoration(
                          labelText: 'E-mail ou téléphone',
                          hintText: 'ex. 0970 000 000',
                        ),
                      ),
                      const SizedBox(height: Espace.m),
                      TextFormField(
                        controller: _motDePasse,
                        obscureText: _masque,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _envoyer(),
                        autofillHints: [
                          _inscription ? AutofillHints.newPassword : AutofillHints.password,
                        ],
                        validator: _validerMotDePasse,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          helperText: _inscription ? '8 caractères minimum' : null,
                          suffixIcon: IconButton(
                            tooltip: _masque ? 'Afficher' : 'Masquer',
                            icon: Icon(_masque ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                            onPressed: () => setState(() => _masque = !_masque),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (CatalogueScope.of(context).abonnement.motifDeconnexion != null && compte.erreur == null) ...[
                  const SizedBox(height: Espace.m),
                  Container(
                    key: const Key('motif-deconnexion'),
                    padding: const EdgeInsets.all(Espace.m),
                    decoration: BoxDecoration(
                      border: Border.all(color: Pal.primaire),
                      borderRadius: BorderRadius.circular(Rayons.carte),
                    ),
                    child: Text(
                      CatalogueScope.of(context).abonnement.motifDeconnexion!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                if (compte.erreur != null) ...[
                  const SizedBox(height: Espace.m),
                  Container(
                    padding: const EdgeInsets.all(Espace.m),
                    decoration: BoxDecoration(
                      border: Border.all(color: Pal.danger),
                      borderRadius: BorderRadius.circular(Rayons.carte),
                    ),
                    child: Text(compte.erreur!, style: const TextStyle(fontSize: 13, color: Pal.danger)),
                  ),
                ],
                const SizedBox(height: Espace.l),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: compte.occupe ? null : _envoyer,
                    child: compte.occupe
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_inscription ? 'CRÉER MON COMPTE' : 'ME CONNECTER'),
                  ),
                ),
                if (compte.fournisseurs.telegram || (ApiConfig.googleVisible && compte.fournisseurs.google) || _attenteTelegram) ...[
                  const SizedBox(height: Espace.l),
                  const Row(
                    children: [
                      Expanded(child: Filet()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: Espace.m),
                        child: Text('OU', style: Typo.meta),
                      ),
                      Expanded(child: Filet()),
                    ],
                  ),
                  const SizedBox(height: Espace.l),
                ],
                if (ApiConfig.googleVisible && compte.fournisseurs.google && ApiConfig.identifiantGoogle.isNotEmpty) ...[
                  if (kIsWeb)
                    Center(child: boutonGoogleOfficiel())
                  else
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton.icon(
                      onPressed: compte.occupe ? null : _google,
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('CONTINUER AVEC GOOGLE', textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(height: Espace.m),
                ],
                if (compte.fournisseurs.telegram) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton.icon(
                      onPressed: (compte.occupe || _attenteTelegram) ? null : _telegram,
                      icon: _attenteTelegram
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(
                        _attenteTelegram
                            ? 'EN ATTENTE DANS TELEGRAM…'
                            : 'CONTINUER AVEC TELEGRAM',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (_attenteTelegram) ...[
                    const SizedBox(height: Espace.s),
                    const Text(
                      'Appuyez sur « Démarrer » dans Telegram, puis revenez ici. Cet écran se ferme tout seul.',
                      style: Typo.meta,
                    ),
                    if (_lienTelegram != null) ...[
                      const SizedBox(height: Espace.s),
                      Wrap(
                        spacing: Espace.s,
                        children: [
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(_lienTelegram!),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Text('ROUVRIR TELEGRAM'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: _lienTelegram!));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Lien copié. Collez-le dans Telegram.')),
                              );
                            },
                            child: const Text('COPIER LE LIEN'),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: Espace.m),
                ],
                const SizedBox(height: Espace.m),
                Text(
                  _inscription
                      ? 'Votre numéro ou e-mail sert uniquement à ouvrir votre compte et à retrouver votre abonnement.'
                      : 'Pas encore de compte ? Ouvrez l\'onglet Inscription.',
                  style: Typo.meta,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({required this.libelle, required this.actif, required this.onTap});

  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Espace.m),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: actif ? Pal.primaire : Colors.transparent, width: 2),
          ),
        ),
        child: Text(
          libelle.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Typo.etiquette.copyWith(color: actif ? Pal.texte : Pal.texteDoux),
        ),
      ),
    );
  }
}
