import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/bootstrap/firebase_bootstrap.dart';
import '../app/theme/app_theme.dart';
import '../features/auth/application/auth_rate_limiter.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/application/registration_validators.dart';
import '../features/auth/data/auth_repository.dart';
import '../shared/widgets/brand_logo.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static const routePath = '/login';
  static const routeName = 'login';

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailConfirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  bool _isCreatingAccount = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirmation = true;
  String? _emailAvailabilityError;
  String? _emailAvailabilityErrorEmail;
  String? _submissionError;

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _emailConfirmationController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(firebaseBootstrapProvider);
    final authState = ref.watch(authStateProvider);
    final rateLimit = ref.watch(authRateLimitProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCheckingSession = authState.isLoading;
    final canInteract =
        bootstrap.isReady && !_isSubmitting && !isCheckingSession;
    final isCurrentModeBlocked = _isCreatingAccount
        ? rateLimit.isSignupBlocked
        : rateLimit.isLoginBlocked;
    final canSubmit = canInteract && !isCurrentModeBlocked;
    final canSendPasswordReset =
        canInteract && !rateLimit.isPasswordResetCoolingDown;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final intro = _LoginIntro(isWide: isWide);
            final loginCard = Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isCreatingAccount ? 'Criar conta' : 'Entrar',
                          style: textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isCreatingAccount
                              ? 'Informe seus dados para criar o acesso.'
                              : 'Use seu Gmail e senha para acessar o estoque.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 18),
                        if (!bootstrap.isReady) ...[
                          _LoginNotice(
                            icon: Icons.cloud_off_outlined,
                            title: bootstrap.message,
                            message:
                                'Configure o Firebase antes de entrar no app.',
                            color: AppTheme.warning,
                          ),
                          const SizedBox(height: 16),
                        ] else if (authState.hasError) ...[
                          const _LoginNotice(
                            icon: Icons.warning_amber_outlined,
                            title: 'Sessão indisponível',
                            message:
                                'Não foi possível verificar seu usuário agora.',
                            color: AppTheme.warning,
                          ),
                          const SizedBox(height: 16),
                        ] else if (isCheckingSession) ...[
                          const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 16),
                        ],
                        if (!_isCreatingAccount &&
                            rateLimit.isLoginBlocked) ...[
                          _LoginNotice(
                            icon: Icons.timer_outlined,
                            title: 'Login temporariamente bloqueado',
                            message:
                                'Muitas tentativas de login. Aguarde ${rateLimit.loginSecondsRemaining} segundos para tentar novamente.',
                            color: AppTheme.warning,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_isCreatingAccount &&
                            rateLimit.isSignupBlocked) ...[
                          _LoginNotice(
                            icon: Icons.timer_outlined,
                            title: 'Cadastros temporariamente bloqueados',
                            message:
                                'Muitas tentativas de cadastro. Tente novamente em ${_formatRemainingTime(rateLimit.signupSecondsRemaining)}.',
                            color: AppTheme.warning,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (!_isCreatingAccount &&
                            rateLimit.isPasswordResetCoolingDown) ...[
                          _LoginNotice(
                            icon: Icons.mark_email_read_outlined,
                            title: 'Recuperação solicitada',
                            message:
                                'Você poderá solicitar outro e-mail em ${rateLimit.passwordResetSecondsRemaining}s.',
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_submissionError != null) ...[
                          _LoginNotice(
                            icon: Icons.error_outline,
                            title: 'Não foi possível criar a conta',
                            message: _submissionError!,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_isCreatingAccount) ...[
                          TextFormField(
                            controller: _nameController,
                            enabled: canInteract,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Nome completo',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: _validateName,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cpfController,
                            enabled: canInteract,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: const [_CpfInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'CPF',
                              hintText: '000.000.000-00',
                              prefixIcon: Icon(Icons.assignment_ind_outlined),
                            ),
                            validator: _validateCpf,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _birthDateController,
                            enabled: canInteract,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: const [_BirthDateInputFormatter()],
                            decoration: InputDecoration(
                              labelText: 'Data de nascimento',
                              hintText: 'dd/mm/aaaa',
                              prefixIcon: const Icon(Icons.cake_outlined),
                              suffixIcon: IconButton(
                                tooltip: 'Selecionar data',
                                onPressed: canInteract ? _pickBirthDate : null,
                                icon: const Icon(Icons.calendar_month_outlined),
                              ),
                            ),
                            validator: _validateBirthDate,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          enabled: canInteract,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          onChanged: (_) => _clearEmailAvailabilityError(),
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            hintText: 'seunome@gmail.com',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: _validateEmail,
                        ),
                        if (_isCreatingAccount) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailConfirmationController,
                            enabled: canInteract,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Confirmar e-mail',
                              hintText: 'seunome@gmail.com',
                              prefixIcon: Icon(Icons.mark_email_read_outlined),
                            ),
                            validator: _validateEmailConfirmation,
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          enabled: canInteract,
                          obscureText: _obscurePassword,
                          textInputAction: _isCreatingAccount
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autofillHints: [
                            _isCreatingAccount
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            helperText: _isCreatingAccount
                                ? 'Mínimo 6 caracteres, 1 maiúscula e 1 minúscula.'
                                : null,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: canInteract
                                  ? () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    }
                                  : null,
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: _validatePassword,
                          onFieldSubmitted: (_) =>
                              canSubmit && !_isCreatingAccount
                              ? _submit()
                              : null,
                        ),
                        if (_isCreatingAccount) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordConfirmationController,
                            enabled: canInteract,
                            obscureText: _obscurePasswordConfirmation,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Confirmar senha',
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                              suffixIcon: IconButton(
                                tooltip: _obscurePasswordConfirmation
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                onPressed: canInteract
                                    ? () {
                                        setState(() {
                                          _obscurePasswordConfirmation =
                                              !_obscurePasswordConfirmation;
                                        });
                                      }
                                    : null,
                                icon: Icon(
                                  _obscurePasswordConfirmation
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: _validatePasswordConfirmation,
                            onFieldSubmitted: (_) =>
                                canSubmit ? _submit() : null,
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (!_isCreatingAccount)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: canSendPasswordReset
                                  ? _sendPasswordReset
                                  : null,
                              child: Text(
                                rateLimit.isPasswordResetCoolingDown
                                    ? 'Solicitar novamente em ${rateLimit.passwordResetSecondsRemaining}s'
                                    : 'Esqueci minha senha',
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: canSubmit ? _submit : null,
                          icon: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _isCreatingAccount
                                      ? Icons.person_add_alt_1_outlined
                                      : Icons.login,
                                ),
                          label: Text(_submitButtonLabel(rateLimit)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: canInteract ? _toggleMode : null,
                          icon: Icon(
                            _isCreatingAccount
                                ? Icons.login
                                : Icons.person_add_alt_1_outlined,
                          ),
                          label: Text(
                            _isCreatingAccount
                                ? 'Já tenho conta'
                                : 'Criar nova conta',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 5, child: intro),
                            const SizedBox(width: 28),
                            Expanded(flex: 4, child: loginCard),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            intro,
                            const SizedBox(height: 22),
                            loginCard,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Informe seu nome.';
    }

    if (name.length < 3) {
      return 'Informe um nome válido.';
    }

    return null;
  }

  String? _validateCpf(String? value) {
    final cpf = value?.trim() ?? '';

    if (cpf.isEmpty) {
      return 'Informe seu CPF.';
    }

    if (!isValidCpf(cpf)) {
      return 'Informe um CPF válido.';
    }

    return null;
  }

  String? _validateBirthDate(String? value) {
    final birthDate = value?.trim() ?? '';

    if (birthDate.isEmpty) {
      return 'Informe sua data de nascimento.';
    }

    if (parseBrazilianBirthDate(birthDate) == null) {
      return 'Informe uma data válida.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Informe seu e-mail.';
    }

    if (!isGmailAddress(email)) {
      return 'Use um e-mail que termine com @gmail.com.';
    }

    final normalizedEmail = email.toLowerCase();
    if (_isCreatingAccount &&
        _emailAvailabilityError != null &&
        _emailAvailabilityErrorEmail == normalizedEmail) {
      return _emailAvailabilityError;
    }

    return null;
  }

  String? _validateEmailConfirmation(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Confirme seu e-mail.';
    }

    if (!isGmailAddress(email)) {
      return 'Use um e-mail que termine com @gmail.com.';
    }

    if (email.toLowerCase() != _emailController.text.trim().toLowerCase()) {
      return 'Os e-mails não conferem.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Informe sua senha.';
    }

    if (_isCreatingAccount && !hasRequiredPasswordStrength(password)) {
      return 'Use 6 caracteres, 1 maiúscula e 1 minúscula.';
    }

    return null;
  }

  String? _validatePasswordConfirmation(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Confirme sua senha.';
    }

    if (password != _passwordController.text) {
      return 'As senhas não conferem.';
    }

    return null;
  }

  Future<void> _submit() async {
    if (_isCreatingAccount) {
      _clearStaleEmailAvailabilityError();
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final isCreatingAccount = _isCreatingAccount;
    final rateLimitController = ref.read(authRateLimitProvider.notifier);

    if (isCreatingAccount) {
      if (!rateLimitController.tryStartSignupAttempt()) {
        final seconds = ref.read(authRateLimitProvider).signupSecondsRemaining;
        _showSnackBar(
          'Muitas tentativas de cadastro. Tente novamente em ${_formatRemainingTime(seconds)}.',
        );
        return;
      }
    } else if (!rateLimitController.canAttemptLogin()) {
      final seconds = ref.read(authRateLimitProvider).loginSecondsRemaining;
      _showSnackBar(
        'Muitas tentativas de login. Aguarde $seconds segundos para tentar novamente.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final authFlowController = ref.read(authFlowProvider.notifier);

    try {
      final repository = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      if (isCreatingAccount) {
        final cpf = digitsOnly(_cpfController.text);
        authFlowController.set(AuthFlow.creatingAccount);

        await repository.createUserWithEmailAndPassword(
          displayName: _nameController.text.trim(),
          cpf: cpf,
          birthDate: parseBrazilianBirthDate(_birthDateController.text)!,
          email: email,
          password: password,
        );
        await repository.signOut();
        authFlowController.set(AuthFlow.awaitingLoginAfterSignup);

        if (mounted) {
          setState(() {
            _isCreatingAccount = false;
            _passwordController.clear();
            _passwordConfirmationController.clear();
            _emailConfirmationController.clear();
            _obscurePassword = true;
            _obscurePasswordConfirmation = true;
          });
          _showSnackBar('Conta criada. Agora entre com seu e-mail e senha.');
        }
      } else {
        authFlowController.set(AuthFlow.idle);
        await repository.signInWithEmailAndPassword(email, password);
        rateLimitController.resetLoginAttempts();
      }

      TextInput.finishAutofillContext();
    } on UserProfileCreationException catch (error) {
      _resetAuthFlowAfterFailure(authFlowController);
      _showSnackBar(_userProfileCreationErrorMessage(error));
    } on MissingUserProfileException {
      _resetAuthFlowAfterFailure(authFlowController);
      if (!isCreatingAccount) {
        rateLimitController.resetLoginAttempts();
      }
      _showSnackBar(
        'Este usuário está sem cadastro completo no Firestore. Apague o teste e cadastre novamente pelo app.',
      );
    } on UserProfileReadException catch (error) {
      _resetAuthFlowAfterFailure(authFlowController);
      if (!isCreatingAccount) {
        rateLimitController.resetLoginAttempts();
      }
      _showSnackBar(_userProfileReadErrorMessage(error));
    } on FirebaseAuthException catch (error) {
      _resetAuthFlowAfterFailure(authFlowController);
      if (isCreatingAccount && _isEmailAlreadyInUse(error)) {
        _markEmailAsAlreadyRegistered(
          _emailController.text.trim().toLowerCase(),
        );
      } else if (!isCreatingAccount && _isInvalidLoginCredential(error)) {
        final isBlocked = rateLimitController.recordInvalidLoginAttempt();
        if (isBlocked) {
          final seconds = ref.read(authRateLimitProvider).loginSecondsRemaining;
          _showSnackBar(
            'Muitas tentativas de login. Aguarde $seconds segundos para tentar novamente.',
          );
        } else {
          _showSnackBar(_authErrorMessage(error));
        }
      } else {
        _showSnackBar(_authErrorMessage(error));
      }
    } on FirebaseException catch (error) {
      _resetAuthFlowAfterFailure(authFlowController);
      _showSnackBar(_firebaseErrorMessage(error));
    } catch (_) {
      _resetAuthFlowAfterFailure(authFlowController);
      _showSnackBar('Não foi possível autenticar agora.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetAuthFlowAfterFailure(AuthFlowController authFlowController) {
    authFlowController.set(AuthFlow.idle);
  }

  Future<void> _sendPasswordReset() async {
    final emailError = _validateEmail(_emailController.text);

    if (emailError != null) {
      _showSnackBar(emailError);
      return;
    }

    final rateLimitController = ref.read(authRateLimitProvider.notifier);
    if (!rateLimitController.canSendPasswordReset()) {
      final seconds = ref
          .read(authRateLimitProvider)
          .passwordResetSecondsRemaining;
      _showSnackBar('Você poderá solicitar outro e-mail em ${seconds}s.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailController.text.trim().toLowerCase());
      rateLimitController.startPasswordResetCooldown();
      _showSnackBar(
        'Se houver uma conta para este e-mail, enviaremos as instruções de recuperação.',
      );
    } on FirebaseAuthException catch (error) {
      _showSnackBar(_passwordResetErrorMessage(error));
    } catch (_) {
      _showSnackBar('Não foi possível enviar a recuperação de senha.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final fallback = DateTime(now.year - 18, now.month, now.day);
    final current = parseBrazilianBirthDate(_birthDateController.text);
    final initialDate = current == null || current.isAfter(now)
        ? fallback
        : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (picked != null) {
      setState(() {
        _birthDateController.text = formatBrazilianDate(picked);
      });
    }
  }

  void _toggleMode() {
    setState(() {
      _isCreatingAccount = !_isCreatingAccount;
      _emailAvailabilityError = null;
      _emailAvailabilityErrorEmail = null;
      _submissionError = null;
      _formKey.currentState?.reset();
    });
    ref.read(authFlowProvider.notifier).set(AuthFlow.idle);
  }

  void _clearEmailAvailabilityError() {
    if (_emailAvailabilityError == null && _submissionError == null) {
      return;
    }

    setState(() {
      _emailAvailabilityError = null;
      _emailAvailabilityErrorEmail = null;
      _submissionError = null;
    });
  }

  void _clearStaleEmailAvailabilityError() {
    final currentEmail = _emailController.text.trim().toLowerCase();

    if (_emailAvailabilityErrorEmail == null ||
        _emailAvailabilityErrorEmail == currentEmail) {
      return;
    }

    setState(() {
      _emailAvailabilityError = null;
      _emailAvailabilityErrorEmail = null;
      _submissionError = null;
    });
  }

  void _markEmailAsAlreadyRegistered(String email) {
    if (mounted) {
      setState(() {
        _emailAvailabilityError = 'Este e-mail já está cadastrado.';
        _emailAvailabilityErrorEmail = email;
        _submissionError =
            'Já existe uma conta usando este e-mail. Informe outro e-mail ou volte para entrar.';
      });
      _formKey.currentState?.validate();
    }

    _showSnackBar('Este e-mail já está cadastrado.');
  }

  bool _isEmailAlreadyInUse(FirebaseAuthException error) {
    final code = error.code
        .toLowerCase()
        .replaceFirst('auth/', '')
        .replaceAll('_', '-');

    return code == 'email-already-in-use';
  }

  bool _isInvalidLoginCredential(FirebaseAuthException error) {
    final code = error.code.toLowerCase().replaceAll('_', '-');

    return code == 'invalid-credential' ||
        code == 'invalid-login-credentials' ||
        code == 'wrong-password' ||
        code == 'user-not-found';
  }

  String _submitButtonLabel(AuthRateLimitState rateLimit) {
    if (_isCreatingAccount && rateLimit.isSignupBlocked) {
      return 'Tente novamente em ${_formatRemainingTime(rateLimit.signupSecondsRemaining)}';
    }

    if (!_isCreatingAccount && rateLimit.isLoginBlocked) {
      return 'Tente novamente em ${rateLimit.loginSecondsRemaining}s';
    }

    return _isCreatingAccount ? 'Criar conta' : 'Entrar';
  }

  String _formatRemainingTime(int totalSeconds) {
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return seconds == 0 ? '${minutes}min' : '${minutes}min ${seconds}s';
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _authErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'Esse e-mail já está cadastrado.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'E-mail ou senha inválidos.',
      'invalid-email' => 'Informe um Gmail válido.',
      'operation-not-allowed' =>
        'Ative Email/Password no Firebase Authentication.',
      'too-many-requests' => 'Muitas tentativas. Tente novamente em instantes.',
      'weak-password' => 'Use uma senha mais forte.',
      'network-request-failed' => 'Sem conexão com o Firebase.',
      _ => 'Não foi possível autenticar agora.',
    };
  }

  String _passwordResetErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'too-many-requests' => 'Muitas tentativas. Tente novamente em instantes.',
      'network-request-failed' => 'Sem conexão com o Firebase.',
      'invalid-email' => 'Informe um Gmail válido.',
      _ =>
        'Não foi possível solicitar a recuperação agora. Tente novamente em instantes.',
    };
  }

  String _firebaseErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => 'Operação bloqueada pelas regras do Firestore.',
      'unavailable' => 'Firebase indisponível no momento.',
      _ => 'Erro Firebase: ${error.code}.',
    };
  }

  String _userProfileCreationErrorMessage(UserProfileCreationException error) {
    final cause = error.error;

    if (cause is FirebaseException && cause.code == 'permission-denied') {
      return 'Cadastro bloqueado pelo Firestore. Publique as regras do banco e tente novamente.';
    }

    return 'Não foi possível salvar o usuário no Firestore.';
  }

  String _userProfileReadErrorMessage(UserProfileReadException error) {
    final cause = error.error;

    if (cause is FirebaseException && cause.code == 'permission-denied') {
      return 'Não foi possível verificar seu usuário no Firestore. Confira as regras do banco.';
    }

    return 'Não foi possível carregar seu usuário no Firestore.';
  }
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.deepBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(isWide ? 28 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(
              size: 62,
              showName: true,
              nameStyle: textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Controle de estoque com visão de negócio.',
              style: textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Produtos, movimentações, contagens e preços em uma base preparada para crescer.',
              style: textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _IntroPill(icon: Icons.inventory_2_outlined, label: 'Estoque'),
                _IntroPill(icon: Icons.fact_check_outlined, label: 'Contagens'),
                _IntroPill(icon: Icons.calculate_outlined, label: 'Preços'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPill extends StatelessWidget {
  const _IntroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginNotice extends StatelessWidget {
  const _LoginNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CpfInputFormatter extends TextInputFormatter {
  const _CpfInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatCpf(newValue.text);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _BirthDateInputFormatter extends TextInputFormatter {
  const _BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatBrazilianDateInput(newValue.text);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
