import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/firebase_bootstrap.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

enum AuthFlow { idle, creatingAccount, awaitingLoginAfterSignup }

final authFlowProvider = NotifierProvider<AuthFlowController, AuthFlow>(
  AuthFlowController.new,
);

class AuthFlowController extends Notifier<AuthFlow> {
  @override
  AuthFlow build() => AuthFlow.idle;

  void set(AuthFlow flow) {
    state = flow;
  }
}

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapProvider);
  final authFlow = ref.watch(authFlowProvider);

  if (!bootstrap.isReady || authFlow != AuthFlow.idle) {
    return Stream<AppUser?>.value(null);
  }

  return ref.watch(authRepositoryProvider).authStateChanges();
});
