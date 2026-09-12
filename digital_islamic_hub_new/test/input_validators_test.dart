import 'package:flutter_test/flutter_test.dart';
import 'package:digital_islamic_hub_new/utils/input_validators.dart';

void main() {
  group('InputValidators.email', () {
    test('rejects empty and malformed emails', () {
      expect(InputValidators.email(null), isNotNull);
      expect(InputValidators.email(''), isNotNull);
      expect(InputValidators.email('not-an-email'), isNotNull);
      expect(InputValidators.email('user@'), isNotNull);
    });

    test('accepts and sanitizes valid emails', () {
      expect(InputValidators.email('  User@Example.COM  '), isNull);
      expect(InputValidators.sanitizeEmail('  User@Example.COM  '),
          'user@example.com');
    });
  });

  group('InputValidators.password', () {
    test('enforces length and character rules', () {
      expect(InputValidators.password(''), isNotNull);
      expect(InputValidators.password('short'), isNotNull);
      expect(InputValidators.password('password', requireStrength: true),
          isNotNull);
      expect(InputValidators.password('12345678', requireStrength: true),
          isNotNull);
      expect(InputValidators.password('pass1234', requireStrength: true),
          isNull);
    });
  });

  group('InputValidators.requiredName', () {
    test('sanitizes and validates names', () {
      expect(InputValidators.requiredName('  '), isNotNull);
      expect(InputValidators.requiredName('A'), isNotNull);
      expect(InputValidators.requiredName('Ali<script>'), isNotNull);
      expect(InputValidators.requiredName('  Ahmed Ali  '), isNull);
    });
  });
}
