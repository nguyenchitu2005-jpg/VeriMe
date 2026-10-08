import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../services/validators.dart';
import '../widgets/common.dart';

/// Đổi mật khẩu tài khoản Firebase: nhập mật khẩu hiện tại và mật khẩu mới.
/// Đóng màn hình và trả về true khi đổi thành công.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.services.auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Đổi mật khẩu',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Mật khẩu hiện tại'),
            PasswordField(
              controller: _currentController,
              label: 'Nhập mật khẩu hiện tại',
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Nhập mật khẩu hiện tại' : null,
            ),
            const SizedBox(height: 16),
            const FieldLabel('Mật khẩu mới'),
            PasswordField(
              controller: _newController,
              label: 'Tối thiểu 6 ký tự',
              textInputAction: TextInputAction.next,
              validator: validateNewPassword,
            ),
            const SizedBox(height: 16),
            const FieldLabel('Nhập lại mật khẩu mới'),
            PasswordField(
              controller: _confirmController,
              label: 'Nhập lại mật khẩu mới',
              textInputAction: TextInputAction.done,
              validator: (v) => v != _newController.text
                  ? 'Mật khẩu nhập lại không khớp'
                  : null,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            BusyButton(label: 'Lưu mật khẩu', busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
