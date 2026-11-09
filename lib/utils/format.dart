import 'package:intl/intl.dart';

final _fcfa = NumberFormat.decimalPattern('fr_FR');

/// 75000 -> "75 000 FCFA"
String formatFcfa(int amount) => '${_fcfa.format(amount)} FCFA';

/// Date et heure lisibles : "sam. 15 nov. à 10:30"
String formatDateTime(DateTime d) =>
    DateFormat("EEE d MMM 'à' HH:mm", 'fr_FR').format(d.toLocal());

/// Heure seule pour le chat : "14:05"
String formatTime(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d.toLocal());

/// Transforme "6 90 00 00 00", "690000000" ou "+237690000000" en "+237690000000".
/// Retourne null si le numéro n'est pas un numéro camerounais valide.
String? normalizeCameroonPhone(String input) {
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00237')) digits = digits.substring(5);
  if (digits.startsWith('237') && digits.length == 12) digits = digits.substring(3);
  if (digits.length != 9) return null;
  if (!(digits.startsWith('6') || digits.startsWith('2'))) return null;
  return '+237$digits';
}

/// Grandes villes du Cameroun proposées dans les listes.
const cameroonCities = <String>[
  'Yaoundé', 'Douala', 'Bafoussam', 'Bamenda', 'Garoua', 'Maroua',
  'Ngaoundéré', 'Bertoua', 'Ebolowa', 'Buea', 'Limbé', 'Kribi',
  'Kumba', 'Dschang', 'Nkongsamba', 'Edéa', 'Mbalmayo', 'Foumban',
];
