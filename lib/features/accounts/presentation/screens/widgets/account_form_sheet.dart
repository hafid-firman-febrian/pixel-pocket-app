import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_pocket/core/error/failure.dart';
import 'package:pixel_pocket/core/theme/app_spacing.dart';
import 'package:pixel_pocket/core/theme/app_text_style.dart';
import 'package:pixel_pocket/core/utils/currency_formatter.dart';
import 'package:pixel_pocket/core/utils/thousands_input_formatter.dart';
import 'package:pixel_pocket/core/widgets/pixel_bottom_sheet.dart';
import 'package:pixel_pocket/core/widgets/pixel_button.dart';
import 'package:pixel_pocket/core/widgets/pixel_color_picker.dart';
import 'package:pixel_pocket/core/widgets/pixel_field_label.dart';
import 'package:pixel_pocket/core/widgets/pixel_snack_bar.dart';
import 'package:pixel_pocket/features/accounts/domain/models/account_model.dart';
import 'package:pixel_pocket/features/accounts/presentation/controllers/account_controller.dart';

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.existing});

  final AccountModel? existing;

  bool get isEditing => existing != null;

  static Future<bool?> show(BuildContext context, {AccountModel? existing}) {
    return showPixelBottomSheet<bool>(
      context: context,
      builder: (_) => AccountFormSheet(existing: existing),
    );
  }

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final TextEditingController _openingController;

  late String _color;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController.text = existing?.name ?? '';
    _color = existing?.color ?? pixelColorPalette.first;
    final opening = existing?.openingBalance ?? 0;
    _openingController = TextEditingController(
      text: opening > 0 ? CurrencyFormatter.input(opening) : '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(accountControllerProvider);
    final name = _nameController.text.trim();
    final opening = CurrencyFormatter.parse(_openingController.text);
    try {
      final existing = widget.existing;
      if (existing != null) {
        await controller.update(
          id: existing.id,
          name: name,
          color: _color,
          openingBalance: opening,
        );
      } else {
        await controller.create(
          name: name,
          color: _color,
          openingBalance: opening,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = e is Failure ? e.message : 'Failed to save account';
      messenger.showPixelSnackBar(message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PixelBottomSheetFrame(
      title: widget.isEditing ? 'EDIT ACCOUNT' : 'NEW ACCOUNT',
      child: SingleChildScrollView(
        padding: AppSpacing.form,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PixelFieldLabel('NAME'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: AppSpacing.section),
              const PixelFieldLabel('OPENING BALANCE'),
              TextFormField(
                controller: _openingController,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsInputFormatter()],
                style: AppTextStyles.numericMd,
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const PixelFieldLabel('COLOR'),
              PixelColorPicker(
                selected: _color,
                onChanged: (hex) => setState(() => _color = hex),
              ),
              const SizedBox(height: AppSpacing.s24),
              PixelButton(
                label: widget.isEditing ? 'SAVE CHANGES' : 'SAVE ACCOUNT',
                isFullWidth: true,
                isLoading: _saving,
                onPressed: _saving ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.s12),
              PixelButton(
                label: 'CANCEL',
                variant: PixelButtonVariant.secondary,
                isFullWidth: true,
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
