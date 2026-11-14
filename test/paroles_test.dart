import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/paroles.dart';
import 'package:records416/features/lecteur/lecteur_morceau_screen.dart';
import 'package:records416/features/lecteur/lecteur_screen.dart' show QualiteAudio;

import 'lecture_test.dart' show MoteurFaux;

void main() {
  group('Paroles.analyser', () {
    test('lit un texte horodaté et le trie', () {
      final p = Paroles.analyser('[00:10.50] Deux\n[00:01.00] Un\n[01:02.25] Trois');
      expect(p.synchronisees, isTrue);
      expect(p.lignes.map((l) => l.texte), ['Un', 'Deux', 'Trois']);
      expect(p.lignes.last.debut, const Duration(minutes: 1, seconds: 2, milliseconds: 250));
    });

    test('un texte simple reste sans défilement', () {
      final p = Paroles.analyser('Une ligne\n\nUne autre');
      expect(p.synchronisees, isFalse);
      expect(p.lignes.length, 2);
      expect(p.indiceA(const Duration(seconds: 5)), -1);
    });

    test('un mélange horodaté et non horodaté n\'est pas synchronisé', () {
      final p = Paroles.analyser('[00:01.00] Un\nSans temps');
      expect(p.synchronisees, isFalse);
    });

    test('ignore les balises LRC de métadonnées et le vide', () {
      final p = Paroles.analyser('[ar:Yuggy]\n[ti:Titre]\n[00:02.00] Bonjour\n[00:05.00]   ');
      expect(p.synchronisees, isTrue);
      expect(p.lignes.length, 1);
      expect(Paroles.analyser(null).vide, isTrue);
      expect(Paroles.analyser('   ').vide, isTrue);
    });

    test('trouve la ligne en cours à chaque instant', () {
      final p = Paroles.analyser('[00:05.00] A\n[00:10.00] B\n[00:20.00] C');
      expect(p.indiceA(const Duration(seconds: 1)), -1);
      expect(p.indiceA(const Duration(seconds: 5)), 0);
      expect(p.indiceA(const Duration(seconds: 12)), 1);
      expect(p.indiceA(const Duration(minutes: 5)), 2);
    });
  });

  group('LecteurMorceauScreen', () {
    Future<void> monter(WidgetTester t, MoteurFaux m, {String? paroles}) async {
      await t.pumpWidget(MaterialApp(
        home: LecteurMorceauScreen(
          titre: 'Mon titre',
          artiste: 'Yuggy',
          paroles: paroles,
          qualites: const [QualiteAudio('Super fan', 'https://x.test/a.wav'), QualiteAudio('Compressée', 'https://x.test/a.mp3')],
          moteur: m,
        ),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('se lance seul et montre titre, artiste et qualités', (t) async {
      final m = MoteurFaux();
      await monter(t, m);
      expect(m.lectures, 1);
      expect(find.text('Mon titre'), findsOneWidget);
      expect(find.text('Yuggy'), findsOneWidget);
      expect(find.text('Super fan'), findsOneWidget);
      expect(find.text('Compressée'), findsOneWidget);
      expect(m.ouverte.toString(), 'https://x.test/a.wav');
    });

    testWidgets('changer de qualité rouvre le bon fichier', (t) async {
      final m = MoteurFaux();
      await monter(t, m);
      await t.tap(find.text('Compressée'));
      await t.pumpAndSettle();
      expect(m.ouverte.toString(), 'https://x.test/a.mp3');
    });

    testWidgets('affiche les paroles et surligne la ligne en cours', (t) async {
      final m = MoteurFaux();
      await monter(t, m, paroles: '[00:00.00] Première\n[00:30.00] Seconde');
      await t.tap(find.byTooltip('Afficher les paroles'));
      await t.pumpAndSettle();
      expect(find.text('Première'), findsOneWidget);
      expect(find.text('Seconde'), findsOneWidget);
    });

    testWidgets('sans paroles, le dit clairement', (t) async {
      final m = MoteurFaux();
      await monter(t, m);
      await t.tap(find.byTooltip('Afficher les paroles'));
      await t.pumpAndSettle();
      expect(find.text('Pas de paroles pour ce morceau.'), findsOneWidget);
    });
  });
}
