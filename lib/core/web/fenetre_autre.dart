/// Hors navigateur (Android, iOS) : rien à préparer, le lien s'ouvre
/// directement avec url_launcher.
class FenetreExterne {
  FenetreExterne._();

  static FenetreExterne? ouvrirVide() => null;

  void aller(String url) {}

  void fermer() {}
}
