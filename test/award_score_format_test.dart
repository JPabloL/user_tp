import 'package:flutter_test/flutter_test.dart';
import 'package:user_tp/utils/award_score_format.dart';

void main() {
  group('formatAwardDisplayScore', () {
    test('entero sin decimal', () {
      expect(formatAwardDisplayScore(12), '12');
      expect(formatAwardDisplayScore(12.0), '12');
    });

    test('un decimal', () {
      expect(formatAwardDisplayScore(10.2), '10.2');
      expect(formatAwardDisplayScore(28.6), '28.6');
    });

    test('dos decimales cuando es necesario', () {
      expect(formatAwardDisplayScore(28.65), '28.65');
    });

    test('bono cero sin prefijo +', () {
      expect(formatAwardBonus(0), '0');
    });

    test('no muestra ceros innecesarios', () {
      expect(formatAwardDisplayScore(12.00), '12');
    });
  });
}
