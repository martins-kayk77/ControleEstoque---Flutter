String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

String formatCpf(String value) {
  final digits = digitsOnly(value);
  final limited = digits.length > 11 ? digits.substring(0, 11) : digits;

  if (limited.length <= 3) {
    return limited;
  }

  if (limited.length <= 6) {
    return '${limited.substring(0, 3)}.${limited.substring(3)}';
  }

  if (limited.length <= 9) {
    return '${limited.substring(0, 3)}.${limited.substring(3, 6)}.${limited.substring(6)}';
  }

  return '${limited.substring(0, 3)}.${limited.substring(3, 6)}.${limited.substring(6, 9)}-${limited.substring(9)}';
}

String formatBrazilianDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String formatBrazilianDateInput(String value) {
  final digits = digitsOnly(value);
  final limited = digits.length > 8 ? digits.substring(0, 8) : digits;

  if (limited.length <= 2) {
    return limited;
  }

  if (limited.length <= 4) {
    return '${limited.substring(0, 2)}/${limited.substring(2)}';
  }

  return '${limited.substring(0, 2)}/${limited.substring(2, 4)}/${limited.substring(4)}';
}

DateTime? parseBrazilianBirthDate(String value) {
  final digits = digitsOnly(value);

  if (digits.length != 8) {
    return null;
  }

  final day = int.tryParse(digits.substring(0, 2));
  final month = int.tryParse(digits.substring(2, 4));
  final year = int.tryParse(digits.substring(4, 8));

  if (day == null || month == null || year == null || year < 1900) {
    return null;
  }

  final date = DateTime(year, month, day);

  if (date.day != day || date.month != month || date.year != year) {
    return null;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (date.isAfter(today)) {
    return null;
  }

  return date;
}

bool isGmailAddress(String value) {
  final email = value.trim().toLowerCase();

  return RegExp(r'^[a-z0-9._%+-]+@gmail\.com$').hasMatch(email);
}

bool hasRequiredPasswordStrength(String value) {
  return value.length >= 6 &&
      RegExp(r'[A-Z]').hasMatch(value) &&
      RegExp(r'[a-z]').hasMatch(value);
}

bool isValidCpf(String value) {
  final cpf = digitsOnly(value);

  if (cpf.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
    return false;
  }

  int calculateDigit(int length) {
    var sum = 0;

    for (var index = 0; index < length; index++) {
      sum += int.parse(cpf[index]) * (length + 1 - index);
    }

    final remainder = sum % 11;

    return remainder < 2 ? 0 : 11 - remainder;
  }

  final firstDigit = calculateDigit(9);
  final secondDigit = calculateDigit(10);

  return cpf[9] == firstDigit.toString() && cpf[10] == secondDigit.toString();
}
