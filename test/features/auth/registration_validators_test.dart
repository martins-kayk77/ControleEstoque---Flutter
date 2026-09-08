import 'package:controle_estoque/features/auth/application/registration_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('registration validators', () {
    test('aceita somente e-mail gmail', () {
      expect(isGmailAddress('usuario@gmail.com'), isTrue);
      expect(isGmailAddress('USUARIO@GMAIL.COM'), isTrue);
      expect(isGmailAddress('usuario@hotmail.com'), isFalse);
      expect(isGmailAddress('usuario@gmail.com.br'), isFalse);
    });

    test('exige senha com tamanho, maiúscula e minúscula', () {
      expect(hasRequiredPasswordStrength('Abc123'), isTrue);
      expect(hasRequiredPasswordStrength('abcdef'), isFalse);
      expect(hasRequiredPasswordStrength('ABCDEF'), isFalse);
      expect(hasRequiredPasswordStrength('Abc12'), isFalse);
    });

    test('valida e formata CPF', () {
      expect(formatCpf('52998224725'), '529.982.247-25');
      expect(isValidCpf('529.982.247-25'), isTrue);
      expect(isValidCpf('111.111.111-11'), isFalse);
      expect(isValidCpf('123'), isFalse);
    });

    test('valida e formata data brasileira', () {
      expect(formatBrazilianDateInput('01022000'), '01/02/2000');
      expect(parseBrazilianBirthDate('01/02/2000'), DateTime(2000, 2, 1));
      expect(parseBrazilianBirthDate('31/02/2000'), isNull);
      expect(parseBrazilianBirthDate('01/01/1800'), isNull);
    });
  });
}
