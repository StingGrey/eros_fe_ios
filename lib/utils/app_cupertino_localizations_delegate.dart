import 'package:cupertino_ui/cupertino_ui.dart';


import 'app_cupertino_localizations.dart';

class AppGlobalCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const AppGlobalCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.isSupported(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    final localizations =
        await GlobalCupertinoLocalizations.delegate.load(locale);
    return AppCupertinoLocalizations(localizations);
  }

  @override
  bool shouldReload(LocalizationsDelegate<CupertinoLocalizations> old) => false;

  @override
  String toString() => 'AppGlobalCupertinoLocalizationsDelegate';
}
