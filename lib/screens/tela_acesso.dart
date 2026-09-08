import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/bootstrap/firebase_bootstrap.dart';
import '../app/theme/app_theme.dart';
import '../core/firebase/firebase_providers.dart';
import '../core/firebase/firestore_paths.dart';
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
  String? _cpfAvailabilityError;
  String? _cpfAvailabilityErrorCpf;

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCheckingSession = authState.isLoading;
    final canSubmit = bootstrap.isReady && !_isSubmitting && !isCheckingSession;

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
                        if (_isCreatingAccount) ...[
                          TextFormField(
                            controller: _nameController,
                            enabled: canSubmit,
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
                            enabled: canSubmit,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: const [_CpfInputFormatter()],
                            onChanged: (_) => _clearCpfAvailabilityError(),
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
                            enabled: canSubmit,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: const [_BirthDateInputFormatter()],
                            decoration: InputDecoration(
                              labelText: 'Data de nascimento',
                              hintText: 'dd/mm/aaaa',
                              prefixIcon: const Icon(Icons.cake_outlined),
                              suffixIcon: IconButton(
                                tooltip: 'Selecionar data',
                                onPressed: canSubmit ? _pickBirthDate : null,
                                icon: const Icon(Icons.calendar_month_outlined),
                              ),
                            ),
                            validator: _validateBirthDate,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          enabled: canSubmit,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
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
                            enabled: canSubmit,
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
                          enabled: canSubmit,
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
                              onPressed: canSubmit
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
                            enabled: canSubmit,
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
                                onPressed: canSubmit
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
                              onPressed: canSubmit ? _sendPasswordReset : null,
                              child: const Text('Esqueci minha senha'),
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
                          label: Text(
                            _isCreatingAccount ? 'Criar conta' : 'Entrar',
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: canSubmit ? _toggleMode : null,
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

    final normalizedCpf = digitsOnly(cpf);
    if (_cpfAvailabilityError != null &&
        _cpfAvailabilityErrorCpf == normalizedCpf) {
      return _cpfAvailabilityError;
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

    return null;
  }

  String? _validateEmailConfirmation(String? value) {
    final emailError = _validateEmail(value);

    if (emailError != null) {
      return emailError;
    }

    if (value!.trim().toLowerCase() !=
        _emailController.text.trim().toLowerCase()) {
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

  Future<bool> _cpfJaEstaReservadoNoBanco(String cpf) async {
    final firestore = ref.read(firebaseFirestoreProvider);

    for (final path in _cpfRegistryLookupPaths(cpf)) {
      final cpfDocument = await firestore
          .doc(path)
          .get(const GetOptions(source: Source.server));

      if (cpfDocument.exists) {
        return true;
      }
    }

    return false;
  }

  Set<String> _cpfRegistryLookupPaths(String cpf) {
    final formattedCpf = _formatCpfForLookup(cpf);

    return {
      FirestorePaths.cpfRegistry(cpf),
      if (formattedCpf != cpf) FirestorePaths.cpfRegistry(formattedCpf),
    };
  }

  String _formatCpfForLookup(String cpf) {
    if (cpf.length != 11) {
      return cpf;
    }

    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.'
        '${cpf.substring(6, 9)}-${cpf.substring(9)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final authFlowController = ref.read(authFlowProvider.notifier);

    try {
      final repository = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      if (_isCreatingAccount) {
        final cpf = digitsOnly(_cpfController.text);
        authFlowController.set(AuthFlow.creatingAccount);

        if (await _cpfJaEstaReservadoNoBanco(cpf)) {
          authFlowController.set(AuthFlow.idle);
          _markCpfAsAlreadyRegistered(cpf);
          return;
        }

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
      }

      TextInput.finishAutofillContext();
    } on DuplicateCpfException {
      _resetAuthFlowAfterFailure(authFlowController);
      _markCpfAsAlreadyRegistered(digitsOnly(_cpfController.text));
    } on UserProfileCreationException catch (error) {
      _resetAuthFlowAfterFailure(authFlowController);
      _showSnackBar(_userProfileCreationErrorMessage(error));
    } on MissingUserProfileException {
      _resetAuthFlowAfterFailure(authFlowController);
      _showSnackBar(
        'Este usuário está sem cadastro completo no Firestore. Apague o teste e cadastre novamente pelo app.',
      );
    } on UserProfileReadException catch (error) {
      _resetAuthFlowAfterFailure(authFlowController);
      _showSnackBar(_userProfileReadErrorMessage(error));
    } on FirebaseAuthException catch (error) {
      _resetAuthFlowAfterFailure(authFlowController);
      _showSnackBar(_authErrorMessage(error));
    } on FirebaseException catch (error) {
      _resetAuthFlowAfterFailure(authFlowController);
      if (_isCreatingAccount && error.code == 'permission-denied') {
        _markCpfLookupUnavailable(digitsOnly(_cpfController.text));
      } else {
        _showSnackBar(_firebaseErrorMessage(error));
      }
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailController.text.trim().toLowerCase());
      _showSnackBar('Enviamos um e-mail para redefinir sua senha.');
    } on FirebaseAuthException catch (error) {
      _showSnackBar(_authErrorMessage(error));
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
      _cpfAvailabilityError = null;
      _cpfAvailabilityErrorCpf = null;
      _formKey.currentState?.reset();
    });
    ref.read(authFlowProvider.notifier).set(AuthFlow.idle);
  }

  void _clearCpfAvailabilityError() {
    if (_cpfAvailabilityError == null) {
      return;
    }

    setState(() {
      _cpfAvailabilityError = null;
      _cpfAvailabilityErrorCpf = null;
    });
  }

  void _markCpfAsAlreadyRegistered(String cpf) {
    if (mounted) {
      setState(() {
        _cpfAvailabilityError = 'Este CPF já está vinculado a outra conta.';
        _cpfAvailabilityErrorCpf = cpf;
      });
      _formKey.currentState?.validate();
    }

    _showSnackBar('Este CPF já está vinculado a outra conta.');
  }

  void _markCpfLookupUnavailable(String cpf) {
    if (mounted) {
      setState(() {
        _cpfAvailabilityError = 'Não foi possível consultar este CPF no banco.';
        _cpfAvailabilityErrorCpf = cpf;
      });
      _formKey.currentState?.validate();
    }

    _showSnackBar(
      'Não foi possível consultar o CPF no banco. Confira as regras do Firestore.',
    );
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
      _ => 'Erro de autenticação: ${error.code}.',
    };
  }

  String _firebaseErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'Não foi possível consultar o CPF no banco. Confira as regras do Firestore.',
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
