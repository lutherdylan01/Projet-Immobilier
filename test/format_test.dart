import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logement_cm/utils/format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('normalizeCameroonPhone', () {
    test('accepte les formats courants', () {
      expect(normalizeCameroonPhone('690123456'), '+237690123456');
      expect(normalizeCameroonPhone('6 90 12 34 56'), '+237690123456');
      expect(normalizeCameroonPhone('+237 690 12 34 56'), '+237690123456');
      expect(normalizeCameroonPhone('00237690123456'), '+237690123456');
      expect(normalizeCameroonPhone('222123456'), '+237222123456');
    });

    test('refuse les numéros invalides', () {
      expect(normalizeCameroonPhone('12345'), isNull);
      expect(normalizeCameroonPhone('790123456'), isNull);
      expect(normalizeCameroonPhone(''), isNull);
    });
  });

  test('formatFcfa sépare les milliers', () {
    expect(formatFcfa(75000).replaceAll(RegExp(r'\s'), ' '), '75 000 FCFA');
  });
}
