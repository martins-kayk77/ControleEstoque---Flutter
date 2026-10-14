import 'package:controle_estoque/app/bootstrap/firebase_bootstrap.dart';
import 'package:controle_estoque/features/auth/application/auth_rate_limiter.dart';
import 'package:controle_estoque/features/auth/data/auth_repository.dart';
import 'package:controle_estoque/features/auth/domain/app_user.dart';
import 'package:controle_estoque/screens/tela_acesso.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('avisa quando o e-mail já está cadastrado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _TestAuthRepository(
      createErrorCode: 'email-already-in-use',
    );
    final container = ProviderContainer(
      overrides: [
        firebaseBootstrapProvider.overrideWithValue(
          const FirebaseBootstrapResult.initialized(),
        ),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar nova conta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar conta').last);
    await tester.pumpAndSettle();

    expect(repository.createAttempts, 0);
    expect(container.read(authRateLimitProvider).signupAttemptsInWindow, 0);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Usuário de teste');
    await tester.enterText(fields.at(1), '52998224725');
    await tester.enterText(fields.at(2), '01/01/2000');
    await tester.enterText(fields.at(3), 'existente@gmail.com');
    await tester.enterText(fields.at(4), 'existente@gmail.com');
    await tester.enterText(fields.at(5), 'Teste1');
    await tester.enterText(fields.at(6), 'Teste1');

    await tester.tap(find.text('Criar conta').last);
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível criar a conta'), findsOneWidget);
    expect(
      find.text(
        'Já existe uma conta usando este e-mail. Informe outro e-mail ou volte para entrar.',
      ),
      findsOneWidget,
    );
    expect(find.text('Este e-mail já está cadastrado.'), findsWidgets);
    expect(repository.createAttempts, 1);
    expect(container.read(authRateLimitProvider).signupAttemptsInWindow, 1);

    repository.createErrorCode = null;
    await tester.enterText(fields.at(3), 'novo.usuario@gmail.com');
    await tester.enterText(fields.at(4), 'novo.usuario@gmail.com');
    await tester.tap(find.text('Criar conta').last);
    await tester.pumpAndSettle();

    expect(repository.createAttempts, 2);
    expect(find.text('Não foi possível criar a conta'), findsNothing);
    expect(find.text('Este e-mail já está cadastrado.'), findsNothing);
    expect(find.text('Entrar'), findsWidgets);
  });

  testWidgets('bloqueia apenas o login depois de 5 credenciais inválidas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var now = DateTime(2026, 9, 12, 12);
    final repository = _TestAuthRepository(
      loginErrorCode: 'network-request-failed',
    );
    final container = ProviderContainer(
      overrides: [
        firebaseBootstrapProvider.overrideWithValue(
          const FirebaseBootstrapResult.initialized(),
        ),
        authRepositoryProvider.overrideWithValue(repository),
        authRateLimitClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'usuario@gmail.com');
    await tester.enterText(fields.at(1), 'Senha1');

    await tester.tap(find.text('Entrar').last);
    await tester.pumpAndSettle();
    expect(repository.loginAttempts, 1);
    expect(container.read(authRateLimitProvider).invalidLoginAttempts, 0);

    repository.loginErrorCode = 'invalid-credential';

    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.tap(find.text('Entrar').last);
      await tester.pumpAndSettle();
    }

    expect(repository.loginAttempts, 6);
    expect(find.text('Login temporariamente bloqueado'), findsOneWidget);
    expect(find.text('Tente novamente em 30s'), findsOneWidget);

    await tester.tap(find.text('Criar nova conta'));
    await tester.pumpAndSettle();
    expect(find.text('Criar conta'), findsWidgets);

    now = now.add(const Duration(seconds: 30));
    container.read(authRateLimitProvider.notifier).refresh();
    await tester.pump();
    expect(container.read(authRateLimitProvider).isLoginBlocked, isFalse);
  });

  testWidgets('mostra o cooldown da recuperação de senha', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var now = DateTime(2026, 9, 12, 12);
    final repository = _TestAuthRepository(
      passwordResetErrorCode: 'network-request-failed',
    );
    final container = ProviderContainer(
      overrides: [
        firebaseBootstrapProvider.overrideWithValue(
          const FirebaseBootstrapResult.initialized(),
        ),
        authRepositoryProvider.overrideWithValue(repository),
        authRateLimitClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'usuario@gmail.com',
    );
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(repository.passwordResetAttempts, 1);
    expect(
      container.read(authRateLimitProvider).isPasswordResetCoolingDown,
      isFalse,
    );
    expect(find.text('Esqueci minha senha'), findsOneWidget);

    repository.passwordResetErrorCode = null;
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(repository.passwordResetAttempts, 2);
    expect(find.text('Recuperação solicitada'), findsOneWidget);
    expect(find.text('Solicitar novamente em 60s'), findsOneWidget);

    now = now.add(const Duration(seconds: 60));
    container.read(authRateLimitProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Esqueci minha senha'), findsOneWidget);
  });
}

class _TestAuthRepository implements AuthRepository {
  _TestAuthRepository({
    this.createErrorCode,
    this.loginErrorCode,
    this.passwordResetErrorCode,
  });

  String? createErrorCode;
  String? loginErrorCode;
  String? passwordResetErrorCode;
  int createAttempts = 0;
  int loginAttempts = 0;
  int passwordResetAttempts = 0;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String displayName,
    required String cpf,
    required DateTime birthDate,
    required String email,
    required String password,
  }) {
    createAttempts++;
    final errorCode = createErrorCode;
    if (errorCode != null) {
      throw FirebaseAuthException(code: errorCode);
    }

    return Future.value(
      AppUser(id: 'new-user', email: email, companyIds: const []),
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    passwordResetAttempts++;
    final errorCode = passwordResetErrorCode;
    if (errorCode != null) {
      throw FirebaseAuthException(code: errorCode);
    }
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {}

  @override
  Future<AppUser> signInWithEmailAndPassword(String email, String password) {
    loginAttempts++;
    final errorCode = loginErrorCode;
    if (errorCode != null) {
      throw FirebaseAuthException(code: errorCode);
    }

    return Future.value(
      AppUser(id: 'user', email: email, companyIds: const []),
    );
  }

  @override
  Future<void> signOut() async {}
}
