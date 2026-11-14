import 'dart:js_interop';

@JS('window.open')
external JSObject? _ouvrir(JSString url, JSString nom);

extension type _Fenetre(JSObject _) implements JSObject {
  external set location(JSString valeur);
  external void close();
}

/// Navigateur : un onglet ouvert APRÈS une attente réseau est bloqué comme
/// pop-up. On l'ouvre donc tout de suite, au clic de l'utilisateur, puis on le
/// redirige vers le lien du robot dès que le serveur l'a fourni.
class FenetreExterne {
  FenetreExterne._(this._f);

  final _Fenetre _f;

  static FenetreExterne? ouvrirVide() {
    final f = _ouvrir('about:blank'.toJS, '_blank'.toJS);
    if (f == null) return null;
    return FenetreExterne._(_Fenetre(f));
  }

  void aller(String url) => _f.location = url.toJS;

  void fermer() => _f.close();
}
