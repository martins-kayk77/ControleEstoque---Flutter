import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_theme.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/data/auth_repository.dart';
import '../data/stock_count_repository.dart';
import '../domain/stock_count.dart';

String countDate(DateTime date) =>
    DateFormat('dd/MM/yyyy • HH:mm').format(date.toLocal());
String countTitle(StockCount count) {
  final date = countDate(count.completedAt ?? count.startedAt);
  return count.code == null ? date : '${count.code} · $date';
}

String signedQuantity(int value) => value > 0 ? '+$value' : '$value';

class CountDifferenceBadge extends StatelessWidget {
  const CountDifferenceBadge(this.difference, {super.key});
  final int? difference;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = difference == null
        ? colors.onSurfaceVariant
        : difference! < 0
        ? colors.error
        : difference! > 0
        ? AppTheme.success
        : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difference == null
            ? 'Pendente'
            : difference == 0
            ? 'Conferido'
            : '${signedQuantity(difference!)} ${difference! < 0 ? 'falta' : 'sobra'}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

Future<void> showStockCountReport(
  BuildContext context,
  StockCount count,
) async {
  final compare = await showDialog<bool>(
    context: context,
    builder: (context) => _StockCountReportDialog(initialCount: count),
  );
  if (compare != true || !context.mounted) return;
  await context.push('/counts/${Uri.encodeComponent(count.id)}/compare');
}

class _StockCountReportDialog extends ConsumerStatefulWidget {
  const _StockCountReportDialog({required this.initialCount});
  final StockCount initialCount;
  @override
  ConsumerState<_StockCountReportDialog> createState() =>
      _StockCountReportDialogState();
}

class _StockCountReportDialogState
    extends ConsumerState<_StockCountReportDialog> {
  bool _busy = false;
  bool _adjustmentConfirmed = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialCount;
    final reports = ref
        .watch(stockCountsProvider(initial.companyId))
        .asData
        ?.value;
    final count =
        reports?.firstWhere(
          (report) => report.id == initial.id,
          orElse: () => initial,
        ) ??
        initial;
    final user = ref.watch(authStateProvider).asData?.value;
    final adjusted = count.stockAdjusted || _adjustmentConfirmed;
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        count.code == null
                            ? 'Relatório de contagem'
                            : 'Relatório de contagem ${count.code}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(countDate(count.completedAt ?? count.startedAt)),
                Text('Responsável: ${count.responsibleName}'),
                if (count.note.isNotEmpty) Text(count.note),
                if (count.operationId != null)
                  Text('Operação de ajuste: ${count.operationId}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('${count.items.length} produtos'),
                    Text('${count.totalUnits} unidades'),
                    Text('${count.missingUnits} faltas'),
                    Text('${count.surplusUnits} sobras'),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Quantidades e nomes preservados no momento da conferência.',
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final item in count.items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productName),
                            subtitle: Text(
                              'Esperado: ${item.expectedQuantity} ${item.unit} • Encontrado: ${item.countedQuantity ?? '—'} ${item.unit}'
                              '${item.reason.isEmpty ? '' : '\n${item.reason}'}',
                            ),
                            trailing: CountDifferenceBadge(
                              item.isCounted ? item.difference : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 28),
                if (adjusted) ...[
                  const Text(
                    'Estoque ajustado',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (count.adjustedAt != null)
                    Text(
                      'Aplicado em ${countDate(count.adjustedAt!)}'
                      '${count.adjustedByName.isEmpty ? '' : ' por ${count.adjustedByName}'}.',
                    ),
                ] else if (count.divergentItems == 0)
                  const Text(
                    'Sem divergências. Nenhum ajuste de estoque é necessário.',
                  )
                else ...[
                  const Text(
                    'Este relatório ainda não alterou o estoque. Você pode aplicar as diferenças após revisar a conferência.',
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _busy ||
                                user == null ||
                                count.status != StockCountStatus.completed
                            ? null
                            : () => Navigator.pop(context, true),
                        icon: const Icon(Icons.compare_arrows),
                        label: const Text('Comparar'),
                      ),
                      if (!adjusted && count.divergentItems > 0)
                        FilledButton.icon(
                          onPressed: _busy || user == null
                              ? null
                              : () => _applyAdjustment(count),
                          icon: const Icon(Icons.sync_alt),
                          label: const Text('Ajustar estoque'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyAdjustment(StockCount count) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajustar estoque?'),
        content: Text(
          'Tem certeza de que deseja aplicar esta contagem? '
          'O estoque de ${count.divergentItems} produtos será ajustado para a quantidade encontrada. '
          'Os ajustes serão registrados nas movimentações, preservando este relatório. '
          'Se houver alterações de estoque desde a contagem, nenhum ajuste será aplicado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final applied = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _CountAdjustmentPasswordDialog(
          countCode: count.code,
          onConfirm: (password) async {
            await ref
                .read(authRepositoryProvider)
                .reauthenticateWithPassword(password);
            if (!mounted) return;
            final currentUser = ref.read(authStateProvider).asData?.value;
            if (currentUser == null || currentUser.id != user.id) {
              throw StateError(
                'Sua sessão mudou. Entre novamente e reabra o relatório para ajustar o estoque.',
              );
            }
            final name = currentUser.displayName?.trim() ?? '';
            await ref
                .read(stockCountRepositoryProvider)
                .applyAdjustment(
                  count: count,
                  userId: currentUser.id,
                  userEmail: currentUser.email,
                  responsibleName: name.isEmpty ? currentUser.email : name,
                );
          },
        ),
      );
      if (applied == true && mounted) {
        setState(() => _adjustmentConfirmed = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _adjustmentErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CountAdjustmentPasswordDialog extends StatefulWidget {
  const _CountAdjustmentPasswordDialog({
    required this.countCode,
    required this.onConfirm,
  });

  final String? countCode;
  final Future<void> Function(String password) onConfirm;

  @override
  State<_CountAdjustmentPasswordDialog> createState() =>
      _CountAdjustmentPasswordDialogState();
}

class _CountAdjustmentPasswordDialogState
    extends State<_CountAdjustmentPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final countLabel = widget.countCode == null
        ? 'esta contagem'
        : 'a contagem ${widget.countCode}';
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        icon: Icon(Icons.lock_outline, color: colors.primary),
        title: const Text('Confirme sua senha'),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Digite sua senha de acesso para aplicar $countLabel e atualizar o estoque.',
                ),
                const SizedBox(height: 18),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _passwordController,
                  autofocus: true,
                  obscureText: _obscurePassword,
                  enabled: !_submitting,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                      onPressed: _submitting
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Informe sua senha.' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_alt),
            label: Text(_submitting ? 'Ajustando estoque…' : 'Aplicar ajuste'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onConfirm(_passwordController.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = _adjustmentErrorMessage(error);
        });
      }
    }
  }
}

String _adjustmentErrorMessage(Object error) {
  if (error is StateError) return error.message;
  if (error is ArgumentError) return '${error.message}';
  if (error is FirebaseException) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Senha incorreta. Confira e tente novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
      case 'network-request-failed':
      case 'unavailable':
        return 'Sem conexão com o Firebase. Verifique sua internet e tente novamente.';
      case 'permission-denied':
        return 'Sua conta não tem permissão para ajustar o estoque.';
      case 'user-disabled':
      case 'user-not-found':
      case 'invalid-user-token':
      case 'user-token-expired':
        return 'Não foi possível confirmar a conta atual. Entre novamente no sistema.';
    }
  }
  return 'Não foi possível ajustar o estoque. Verifique sua conexão e permissão, e tente novamente.';
}
