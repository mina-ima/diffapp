import 'package:diffapp/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings', () {
    test('initial defaults: all ON, precision = 3', () {
      final s = Settings.initial();
      expect(s.detectColor, isTrue);
      expect(s.detectShape, isTrue);
      expect(s.detectPosition, isTrue);
      expect(s.detectSize, isTrue);
      expect(s.detectText, isTrue);
      expect(s.precision, equals(Settings.defaultPrecision));
    });

    test('copyWith toggles and precision update', () {
      final s = Settings.initial().copyWith(
        detectText: false,
        precision: Settings.maxPrecision,
      );
      expect(s.detectText, isFalse);
      expect(s.precision, Settings.maxPrecision);
    });

    test('copyWith validates precision range', () {
      final s = Settings.initial();
      expect(() => s.copyWith(precision: 0), throwsArgumentError);
      expect(() => s.copyWith(precision: Settings.maxPrecision + 1), throwsArgumentError);
    });

    test('toJson/fromJson roundtrip', () {
      final s = Settings.initial().copyWith(
        detectColor: false,
        detectSize: false,
        precision: Settings.maxPrecision,
      );
      final json = s.toJson();
      final back = Settings.fromJson(json);
      expect(back, equals(s));
    });

    test('fromMap merges with defaults and validates precision', () {
      final base = Settings.initial();
      final s = Settings.fromMap({'detectColor': false});
      expect(s.detectColor, isFalse);
      expect(s.detectShape, base.detectShape);
      expect(s.precision, base.precision);

      expect(() => Settings.fromMap({'precision': 10}), throwsArgumentError);
      expect(() => Settings.fromMap({'detectText': 1}), throwsFormatException);
    });

    test('equality/hashCode stable for identical values', () {
      final a = Settings.initial();
      final b = Settings.initial();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
