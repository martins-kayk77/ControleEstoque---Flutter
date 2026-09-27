import 'package:controle_estoque/features/auth/application/auth_rate_limiter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late ProviderContainer container;
  late AuthRateLimitController controller;

  setUp(() {
    now = DateTime(2026, 9, 12, 12);
    container = ProviderContainer(
      overrides: [authRateLimitClockProvider.overrideWithValue(() => now)],
    );
    controller = container.read(authRateLimitProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  test('bloqueia o login após 5 credenciais inválidas por 30 segundos', () {
    for (var attempt = 1; attempt < 5; attempt++) {
      expect(controller.recordInvalidLoginAttempt(), isFalse);
      expect(
        container.read(authRateLimitProvider).invalidLoginAttempts,
        attempt,
      );
    }

    expect(controller.recordInvalidLoginAttempt(), isTrue);
    expect(container.read(authRateLimitProvider).loginSecondsRemaining, 30);
    expect(controller.canAttemptLogin(), isFalse);

    now = now.add(const Duration(seconds: 29));
    controller.refresh();
    expect(container.read(authRateLimitProvider).loginSecondsRemaining, 1);

    now = now.add(const Duration(seconds: 1));
    controller.refresh();
    expect(container.read(authRateLimitProvider).isLoginBlocked, isFalse);
    expect(controller.canAttemptLogin(), isTrue);
  });

  test('login aceito zera as falhas de credencial', () {
    controller.recordInvalidLoginAttempt();
    controller.recordInvalidLoginAttempt();

    controller.resetLoginAttempts();

    final state = container.read(authRateLimitProvider);
    expect(state.invalidLoginAttempts, 0);
    expect(state.isLoginBlocked, isFalse);
  });

  test('libera nova recuperação de senha depois de 60 segundos', () {
    expect(controller.canSendPasswordReset(), isTrue);

    controller.startPasswordResetCooldown();
    expect(
      container.read(authRateLimitProvider).passwordResetSecondsRemaining,
      60,
    );
    expect(controller.canSendPasswordReset(), isFalse);

    now = now.add(const Duration(seconds: 60));
    controller.refresh();
    expect(controller.canSendPasswordReset(), isTrue);
  });

  test('permite 3 cadastros em 5 minutos e bloqueia o quarto', () {
    expect(controller.tryStartSignupAttempt(), isTrue);
    expect(controller.tryStartSignupAttempt(), isTrue);
    expect(controller.tryStartSignupAttempt(), isTrue);
    expect(container.read(authRateLimitProvider).signupAttemptsInWindow, 3);
    expect(container.read(authRateLimitProvider).signupSecondsRemaining, 300);

    expect(controller.tryStartSignupAttempt(), isFalse);

    now = now.add(const Duration(minutes: 5));
    controller.refresh();
    expect(container.read(authRateLimitProvider).isSignupBlocked, isFalse);
    expect(controller.tryStartSignupAttempt(), isTrue);
  });
}
