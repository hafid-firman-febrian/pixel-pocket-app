import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/core/theme/app_color.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/theme/app_text_style.dart';
import 'package:pixel_pocket/core/utils/currency_formatter.dart';
import 'package:pixel_pocket/core/utils/thousands_input_formatter.dart';
import 'package:pixel_pocket/core/widgets/pixel_bottom_sheet.dart';
import 'package:pixel_pocket/core/widgets/pixel_button.dart';
import 'package:pixel_pocket/core/widgets/pixel_field_label.dart';
import 'package:pixel_pocket/core/widgets/pixel_select_chip.dart';
import 'package:pixel_pocket/core/widgets/pixel_snack_bar.dart';
import 'package:pixelarticons/pixel.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';
import 'package:pixel_pocket/features/accounts/presentation/states/account_state.dart';
import 'package:pixel_pocket/features/categories/domain/models/category_model.dart';
import 'package:pixel_pocket/features/categories/presentation/states/category_state.dart';
import 'package:pixel_pocket/features/transactions/domain/models/transaction_model.dart';
import 'package:pixel_pocket/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:pixel_pocket/features/transactions/presentation/states/transaction_state.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({super.key, this.existing, this.initialDate});

  final TransactionModel? existing;

  final DateTime? initialDate;

  bool get isEditing => existing != null;

  static Future<bool?> show(
    BuildContext context, {
    TransactionModel? existing,
    DateTime? initialDate,
  }) {
    return showPixelBottomSheet<bool>(
      context: context,
      builder: (_) =>
          TransactionFormSheet(existing: existing, initialDate: initialDate),
    );
  }

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  late final TextEditingController _amountController;
  late final TextEditingController _feeController;
  late final TextEditingController _descriptionController;

  late String _type;
  late DateTime _date;
  int? _categoryId;
  int? _accountId;
  int? _toAccountId;
  late final bool _allowNoAccount;

  bool get _isTransfer => _type == 'transfer';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.transactionType ?? 'expense';
    _date = existing != null
        ? (DateTime.tryParse(existing.transactionDate) ?? _todayFloor())
        : (widget.initialDate ?? ref.read(rangeFilterProvider).defaultEntryDate);
    _categoryId = existing?.categoryId;
    _accountId = existing?.accountId;
    _toAccountId = existing?.toAccountId;
    _allowNoAccount =
        existing != null && !existing.isTransfer && existing.accountId == null;
    _amountController = TextEditingController(
      text: existing != null ? CurrencyFormatter.input(existing.amount) : '0',
    );
    final fee = existing?.feeAmount ?? 0;
    _feeController = TextEditingController(
      text: fee > 0 ? CurrencyFormatter.input(fee) : '0',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    if (existing == null) unawaited(_applyDefaultAccount());
  }

  DateTime _todayFloor() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _applyDefaultAccount() async {
    final transfer = _isTransfer;
    final int? id;
    try {
      id = await ref.read(lastUsedAccountIdProvider(transfer).future);
    } catch (_) {
      return;
    }
    if (!mounted || _isTransfer != transfer || _accountId != null) return;
    setState(() => _accountId = id);
  }

  List<AccountModel> _accountOptions(List<AccountModel> all) {
    final keep = {widget.existing?.accountId, widget.existing?.toAccountId};
    return all.where((a) => !a.isArchived || keep.contains(a.id)).toList();
  }

  bool get _accountRequired {
    final all = ref.read(accountsProvider).valueOrNull ?? const <AccountModel>[];
    return _accountOptions(all).isNotEmpty && !_allowNoAccount;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: RangeFilter.entryDateMin,
      lastDate: RangeFilter.entryDateMax,
    );
    if (picked != null) setState(() => _date = picked);
  }

  List<CategoryModel> _categoriesForType(List<CategoryModel> all) =>
      all.where((c) => c.type == _type).toList();

  static const _quickAmounts = <(String, int)>[
    ('+5K', 5000),
    ('+10K', 10000),
    ('+50K', 50000),
    ('+100K', 100000),
  ];

  int _currentAmount() =>
      CurrencyFormatter.parse(_amountController.text).toInt();

  void _setAmount(int value) {
    final clamped = value < 0 ? 0 : value;
    final text = clamped == 0
        ? '0'
        : CurrencyFormatter.input(clamped.toDouble());
    _amountController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _bumpAmount(int delta) => _setAmount(_currentAmount() + delta);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = CurrencyFormatter.parse(_amountController.text);
    final description = _descriptionController.text.trim();
    final note = description.isEmpty ? null : description;
    final date = _dateFormat.format(_date);
    final controller = ref.read(transactionsControllerProvider.notifier);
    final existing = widget.existing;

    final bool ok;
    if (_isTransfer) {
      final fee = CurrencyFormatter.parse(_feeController.text);
      ok = existing != null
          ? await controller.editTransfer(
              id: existing.id,
              transactionDate: date,
              amount: amount,
              fromAccountId: _accountId,
              toAccountId: _toAccountId,
              fee: fee,
              description: note,
            )
          : await controller.createTransfer(
              transactionDate: date,
              amount: amount,
              fromAccountId: _accountId,
              toAccountId: _toAccountId,
              fee: fee,
              description: note,
            );
    } else {
      if (_categoryId == null) {
        _showSnack('Please select a category first', isError: true);
        return;
      }
      if (_accountRequired && _accountId == null) {
        _showSnack('Please select an account first', isError: true);
        return;
      }
      ok = existing != null
          ? await controller.edit(
              id: existing.id,
              transactionDate: date,
              transactionType: _type,
              amount: amount,
              categoryId: _categoryId,
              accountId: _accountId,
              description: note,
            )
          : await controller.create(
              transactionDate: date,
              transactionType: _type,
              amount: amount,
              categoryId: _categoryId,
              accountId: _accountId,
              description: note,
            );
    }

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      final error = ref.read(transactionsControllerProvider).error;
      _showSnack(
        error is Failure ? error.message : 'Failed to save transaction',
        isError: true,
      );
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showPixelSnackBar(message, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <AccountModel>[];
    final options = _accountOptions(accounts);
    final isSubmitting = ref.watch(transactionsControllerProvider).isLoading;
    final existing = widget.existing;
    final showIncomeExpense = existing == null || !existing.isTransfer;
    final showTransfer = existing == null
        ? accounts.where((a) => !a.isArchived).length >= 2
        : existing.isTransfer;

    return PixelBottomSheetFrame(
      title: widget.isEditing ? 'EDIT TRANSACTION' : 'NEW TRANSACTION',
      child: SingleChildScrollView(
        padding: AppSpacing.form,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (showIncomeExpense) ...[
                    _typeButton(
                      'expense',
                      'EXPENSE',
                      PixelButtonVariant.expense,
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    _typeButton('income', 'INCOME', PixelButtonVariant.income),
                  ],
                  if (showIncomeExpense && showTransfer)
                    const SizedBox(width: AppSpacing.s12),
                  if (showTransfer)
                    _typeButton(
                      'transfer',
                      'TRANSFER',
                      PixelButtonVariant.primary,
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.section),

              const PixelFieldLabel('DATE'),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Pixel.calendar, size: 18),
                  ),
                  child: Text(_dateFormat.format(_date)),
                ),
              ),

              const SizedBox(height: AppSpacing.section),

              const PixelFieldLabel('AMOUNT'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  PixelIconButton(
                    icon: Pixel.minus,
                    variant: PixelButtonVariant.primary,
                    onPressed: () => _bumpAmount(-1000),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [ThousandsInputFormatter()],
                      style: AppTextStyles.numericMd,
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                          vertical: AppSpacing.s12,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _amountController,
                          builder: (context, value, _) {
                            if (CurrencyFormatter.parse(value.text) <= 0) {
                              return const SizedBox.shrink();
                            }
                            return GestureDetector(
                              onTap: () => _setAmount(0),
                              behavior: HitTestBehavior.opaque,
                              child: const Icon(
                                Pixel.close,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            );
                          },
                        ),
                      ),
                      validator: (v) {
                        if (CurrencyFormatter.parse(v ?? '') <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  PixelIconButton(
                    icon: Pixel.plus,
                    variant: PixelButtonVariant.primary,
                    onPressed: () => _bumpAmount(1000),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Wrap(
                spacing: AppSpacing.s6,
                runSpacing: AppSpacing.s6,
                children: [
                  for (final (label, value) in _quickAmounts)
                    PixelButton(
                      label: label,
                      variant: PixelButtonVariant.surface,
                      size: PixelButtonSize.sm,
                      onPressed: () => _bumpAmount(value),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.section),

              if (_isTransfer)
                ..._transferFields(options)
              else
                ..._entryFields(categoriesAsync, options),

              const PixelFieldLabel('DESCRIPTION (OPTIONAL)'),
              TextFormField(controller: _descriptionController, maxLines: 2),
              const SizedBox(height: AppSpacing.s24),

              PixelButton(
                label: widget.isEditing ? 'SAVE CHANGES' : 'SAVE TRANSACTION',
                isFullWidth: true,
                isLoading: isSubmitting,
                onPressed: isSubmitting ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.s12),
              PixelButton(
                label: 'CANCEL',
                variant: PixelButtonVariant.secondary,
                isFullWidth: true,
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _entryFields(
    AsyncValue<List<CategoryModel>> categoriesAsync,
    List<AccountModel> options,
  ) {
    return [
      if (options.isNotEmpty) ...[
        const PixelFieldLabel('ACCOUNT'),
        _AccountChips(
          accounts: options,
          selectedId: _accountId,
          noAccountLabel: _allowNoAccount ? 'No account' : null,
          onSelected: (id) => setState(() => _accountId = id),
        ),
        const SizedBox(height: AppSpacing.section),
      ],
      const PixelFieldLabel('CATEGORY'),
      categoriesAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(
          'Failed to load categories: $e',
          style: const TextStyle(color: AppColors.expense),
        ),
        data: (all) {
          final categories = _categoriesForType(all);
          final validIds = categories.map((c) => c.id).toSet();
          final value = validIds.contains(_categoryId) ? _categoryId : null;
          return DropdownButtonFormField<int>(
            initialValue: value,
            isExpanded: true,
            items: categories
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          color: AppColors.fromHex(c.color),
                        ),
                        const SizedBox(width: 10),
                        Text(c.name),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) => setState(() => _categoryId = id),
          );
        },
      ),
      const SizedBox(height: AppSpacing.section),
    ];
  }

  List<Widget> _transferFields(List<AccountModel> options) {
    return [
      const PixelFieldLabel('FROM'),
      _AccountChips(
        accounts: options,
        selectedId: _accountId,
        onSelected: (id) => setState(() {
          _accountId = id;
          if (_toAccountId == id) _toAccountId = null;
        }),
      ),
      const SizedBox(height: AppSpacing.section),
      const PixelFieldLabel('TO'),
      _AccountChips(
        accounts: options.where((a) => a.id != _accountId).toList(),
        selectedId: _toAccountId,
        onSelected: (id) => setState(() => _toAccountId = id),
      ),
      const SizedBox(height: AppSpacing.section),
      const PixelFieldLabel('ADMIN FEE (OPTIONAL)'),
      TextFormField(
        controller: _feeController,
        keyboardType: TextInputType.number,
        inputFormatters: const [ThousandsInputFormatter()],
        style: AppTextStyles.numericMd,
        decoration: const InputDecoration(
          prefixText: 'Rp ',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s12,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.section),
    ];
  }

  Widget _typeButton(String value, String label, PixelButtonVariant variant) {
    final selected = _type == value;
    return Expanded(
      child: PixelButton(
        label: label,
        isFullWidth: true,
        variant: selected ? variant : PixelButtonVariant.surface,
        pressed: selected,
        onPressed: () => _setType(value),
      ),
    );
  }

  void _setType(String type) {
    if (_type == type) return;
    final crossesTransfer = type == 'transfer' || _isTransfer;
    setState(() {
      _type = type;
      _categoryId = null;
      if (crossesTransfer) {
        _accountId = null;
        _toAccountId = null;
      }
    });
    if (crossesTransfer) unawaited(_applyDefaultAccount());
  }
}

class _AccountChips extends StatelessWidget {
  const _AccountChips({
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
    this.noAccountLabel,
  });

  final List<AccountModel> accounts;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final String? noAccountLabel;

  @override
  Widget build(BuildContext context) {
    final noAccount = noAccountLabel;
    return Wrap(
      spacing: AppSpacing.s6,
      runSpacing: AppSpacing.s6,
      children: [
        if (noAccount != null)
          PixelSelectChip(
            label: noAccount,
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
        for (final a in accounts)
          PixelSelectChip(
            label: a.name,
            selected: a.id == selectedId,
            onTap: () => onSelected(a.id),
          ),
      ],
    );
  }
}
