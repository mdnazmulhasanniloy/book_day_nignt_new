import 'package:get/get.dart';
import 'arabic_lan.dart';
import 'dutch_lan.dart';
import 'english_lan.dart';
import 'french_lan.dart';
import 'german_lan.dart';
import 'italian_lan.dart';
import 'portuguese_lan.dart';
import 'spanish_lan.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': EnglishLan.keys,
        'es': SpanishLan.keys,
        'fr': FrenchLan.keys,
        'de': GermanLan.keys,
        'ar': ArabicLan.keys,
        'it': ItalianLan.keys,
        'pt': PortugueseLan.keys,
        'nl': DutchLan.keys,
      };
}
