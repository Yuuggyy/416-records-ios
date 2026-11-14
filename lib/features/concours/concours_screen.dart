import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/local/candidats_demo.dart';
import '../../domain/classement.dart';

/// Écran du concours : classement vivant, calculé par le moteur 60 / 40.
class ConcoursScreen extends StatefulWidget {
  const ConcoursScreen({super.key});

  @override
  State<ConcoursScreen> createState() => _ConcoursScreenState();
}

class _ConcoursScreenState extends State<ConcoursScreen> {
  static const _moteur = MoteurClassement();

  late List<LigneClassement> _lignes;
  final Set<String> _votesDuJour = {};

  @override
  void initState() {
    super.initState();
    _lignes = _moteur.classer(candidatsDemo);
  }

  void _voter(String id) {
    if (_votesDuJour.contains(id)) return;
    final misAJour = candidatsDemo
        .map((c) => c.id == id ? c.copieAvec(votes: c.votes + 1) : c)
        .toList();
    setState(() {
      _votesDuJour.add(id);
      _lignes = _moteur.classer(misAJour);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vote enregistré. Un seul vote par candidat.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final juryEnAttente = _lignes.any((l) => l.juryEnAttente);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Concours 2026'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Espace.m),
            child: Center(
              child: Text(
                '${_lignes.length} en lice',
                style: const TextStyle(color: Pal.texteDoux, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Espace.m, Espace.s, Espace.m, Espace.xl),
        itemCount: _lignes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: Espace.s),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Espace.s),
              child: _BandeauRegle(juryEnAttente: juryEnAttente),
            );
          }
          final ligne = _lignes[index - 1];
          return _CarteCandidat(
            ligne: ligne,
            dejaVote: _votesDuJour.contains(ligne.candidat.id),
            onVoter: () => _voter(ligne.candidat.id),
          );
        },
      ),
    );
  }
}

class _BandeauRegle extends StatelessWidget {
  const _BandeauRegle({required this.juryEnAttente});

  final bool juryEnAttente;

  @override
  Widget build(BuildContext context) {
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
          const Text('60 % public · 40 % jury', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: Espace.xs),
          const Text(
            'Le public compte pour 60 % (moitié écoutes, moitié votes), le jury pour 40 %. '
            'Chaque note est ramenée sur 100 avant pondération.',
            style: TextStyle(color: Pal.texteDoux, fontSize: 12, height: 1.45),
          ),
          if (juryEnAttente) ...[
            const SizedBox(height: Espace.s),
            const Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Pal.alerte),
                SizedBox(width: 6),
                Text(
                  'Jury en attente : seuls les points du public comptent.',
                  style: TextStyle(color: Pal.alerte, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CarteCandidat extends StatelessWidget {
  const _CarteCandidat({
    required this.ligne,
    required this.dejaVote,
    required this.onVoter,
  });

  final LigneClassement ligne;
  final bool dejaVote;
  final VoidCallback onVoter;

  @override
  Widget build(BuildContext context) {
    final c = ligne.candidat;
    return Container(
      padding: const EdgeInsets.all(Espace.m),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: ligne.rang == 1 ? Pal.primaire : Pal.bordure),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Rang(rang: ligne.rang),
          const SizedBox(width: Espace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(c.ville, style: const TextStyle(color: Pal.texteDoux, fontSize: 12)),
                const SizedBox(height: Espace.s),
                _DetailScore(ligne: ligne),
                const SizedBox(height: Espace.s),
                Row(
                  children: [
                    Text(
                      '${ligne.scoreFinal.toStringAsFixed(1)} pts',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(width: Espace.m),
                    Text(
                      'public ${ligne.scorePublic.toStringAsFixed(0)} · jury ${ligne.scoreJury?.toStringAsFixed(0) ?? '—'}',
                      style: const TextStyle(color: Pal.texteDoux, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Espace.s),
          IconButton(
            onPressed: dejaVote ? null : onVoter,
            icon: Icon(dejaVote ? Icons.favorite : Icons.favorite_border, size: 20),
            color: Pal.primaireClaire,
            tooltip: dejaVote ? 'Vote déjà enregistré' : 'Voter pour ${c.nom}',
          ),
        ],
      ),
    );
  }
}

class _Rang extends StatelessWidget {
  const _Rang({required this.rang});

  final int rang;

  @override
  Widget build(BuildContext context) {
    final premier = rang == 1;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: premier ? Pal.primaire : Pal.surfaceHaute,
        borderRadius: BorderRadius.circular(Rayons.champ),
        border: Border.all(color: premier ? Pal.primaire : Pal.bordure),
      ),
      child: Text(
        '$rang',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: premier ? Colors.white : Pal.texteDoux,
        ),
      ),
    );
  }
}

class _DetailScore extends StatelessWidget {
  const _DetailScore({required this.ligne});

  final LigneClassement ligne;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Rayons.pilule),
      child: SizedBox(
        height: 5,
        child: Row(
          children: [
            Expanded(
              flex: (ligne.apportPublic * 10).round().clamp(0, 1000),
              child: const ColoredBox(color: Pal.primaire),
            ),
            Expanded(
              flex: (ligne.apportJury * 10).round().clamp(0, 1000),
              child: const ColoredBox(color: Pal.primaireClaire),
            ),
            Expanded(
              flex: (1000 - ((ligne.apportPublic + ligne.apportJury) * 10).round()).clamp(0, 1000),
              child: const ColoredBox(color: Pal.surfaceHaute),
            ),
          ],
        ),
      ),
    );
  }
}
