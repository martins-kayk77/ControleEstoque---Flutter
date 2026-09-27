import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthRateLimitConfig {
  const AuthRateLimitConfig({
    this.maxInvalidLoginAttempts = 5,
    this.loginLockDuration = const Duration(seconds: 30),
    this.passwordResetCooldown = const Duration(seconds: 60),
    this.maxSignupAttempts = 3,
    this.signupWindow = const Duration(minutes: 5),
  });

  final int maxInvalidLoginAttempts;
  final Duration loginLockDuration;
  final Duration passwordResetCooldown;
  final int maxSignupAttempts;
  final Duration signupWindow;
}

class AuthRateLimitState {
  const AuthRateLimitState({
    this.invalidLoginAttempts = 0,
    this.loginSecondsRemaining = 0,
    this.passwordResetSecondsRemaining = 0,
    this.signupAttemptsInWindow = 0,
    this.signupSecondsRemaining = 0,
  });

  final int invalidLoginAttempts;
  final int loginSecondsRemaining;
  final int passwordResetSecondsRemaining;
  final int signupAttemptsInWindow;
  final int signupSecondsRemaining;

  bool get isLoginBlocked => loginSecondsRemaining > 0;
  bool get isPasswordResetCoolingDown => passwordResetSecondsRemaining > 0;
  bool get isSignupBlocked => signupSecondsRemaining > 0;
}

typedef AuthRateLimitClock = DateTime Function();

final authRateLimitConfigProvider = Provider<AuthRateLimitConfig>((ref) {
  return const AuthRateLimitConfig();
});

final authRateLimitClockProvider = Provider<AuthRateLimitClock>((ref) {
  return DateTime.now;
});

final authRateLimitProvider =
    NotifierProvider<AuthRateLimitController, AuthRateLimitState>(
      AuthRateLimitController.new,
    );

class AuthRateLimitController extends Notifier<AuthRateLimitState> {
  late AuthRateLimitConfig _config;
  late AuthRateLimitClock _clock;

  int _invalidLoginAttempts = 0;
  DateTime? _loginBlockedUntil;
  DateTime? _passwordResetBlockedUntil;
  final List<DateTime> _signupAttempts = [];
  Timer? _ticker;

  @override
  AuthRateLimitState build() {
    _config = ref.watch(authRateLimitConfigProvider);
    _clock = ref.watch(authRateLimitClockProvider);
    ref.onDispose(() => _ticker?.cancel());

    return const AuthRateLimitState();
  }

  bool canAttemptLogin() {
    _publish(_clock());
    return _loginBlockedUntil == null;
  }

  bool recordInvalidLoginAttempt() {
    final now = _clock();
    _clearExpiredLimits(now);

    if (_loginBlockedUntil != null) {
      _publish(now);
      return true;
    }

    _invalidLoginAttempts++;
    if (_invalidLoginAttempts >= _config.maxInvalidLoginAttempts) {
      _invalidLoginAttempts = 0;
      _loginBlockedUntil = now.add(_config.loginLockDuration);
    }

    _publish(now);
    return _loginBlockedUntil != null;
  }

  void resetLoginAttempts() {
    _invalidLoginAttempts = 0;
    _loginBlockedUntil = null;
    _publish(_clock());
  }

  bool canSendPasswordReset() {
    _publish(_clock());
    return _passwordResetBlockedUntil == null;
  }

  void startPasswordResetCooldown() {
    final now = _clock();
    _passwordResetBlockedUntil = now.add(_config.passwordResetCooldown);
    _publish(now);
  }

  bool tryStartSignupAttempt() {
    final now = _clock();
    _clearExpiredLimits(now);

    if (_signupAttempts.length >= _config.maxSignupAttempts) {
      _publish(now);
      return false;
    }

    _signupAttempts.add(now);
    _publish(now);
    return true;
  }

  void refresh() {
    _publish(_clock());
  }

  void _publish(DateTime now) {
    _clearExpiredLimits(now);

    final signupBlockedUntil =
        _signupAttempts.length >= _config.maxSignupAttempts
        ? _signupAttempts.first.add(_config.signupWindow)
        : null;

    state = AuthRateLimitState(
      invalidLoginAttempts: _invalidLoginAttempts,
      loginSecondsRemaining: _secondsUntil(_loginBlockedUntil, now),
      passwordResetSecondsRemaining: _secondsUntil(
        _passwordResetBlockedUntil,
        now,
      ),
      signupAttemptsInWindow: _signupAttempts.length,
      signupSecondsRemaining: _secondsUntil(signupBlockedUntil, now),
    );

    _updateTicker(
      _loginBlockedUntil != null ||
          _passwordResetBlockedUntil != null ||
          signupBlockedUntil != null,
    );
  }

  void _clearExpiredLimits(DateTime now) {
    final loginBlockedUntil = _loginBlockedUntil;
    if (loginBlockedUntil != null && !now.isBefore(loginBlockedUntil)) {
      _loginBlockedUntil = null;
      _invalidLoginAttempts = 0;
    }

    final passwordResetBlockedUntil = _passwordResetBlockedUntil;
    if (passwordResetBlockedUntil != null &&
        !now.isBefore(passwordResetBlockedUntil)) {
      _passwordResetBlockedUntil = null;
    }

    _signupAttempts.removeWhere(
      (attempt) => !now.isBefore(attempt.add(_config.signupWindow)),
    );
  }

  int _secondsUntil(DateTime? end, DateTime now) {
    if (end == null) {
      return 0;
    }

    final remainingMicroseconds = end.difference(now).inMicroseconds;
    if (remainingMicroseconds <= 0) {
      return 0;
    }

    return (remainingMicroseconds + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  void _updateTicker(bool shouldRun) {
    if (!shouldRun) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }

    _ticker ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _publish(_clock()),
    );
  }
}
