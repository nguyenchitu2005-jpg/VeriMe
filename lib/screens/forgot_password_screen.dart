import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../services/validators.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Quên mật khẩu: Firebase gửi email chứa đường dẫn để đặt mật khẩu mới.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.services,
    this.initialEmail,
  });

  final AppServices services;
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  bool _busy = false;
  String? _sentTo;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    // "Gửi lại email" (form đã ẩn) thì dùng lại email vừa gửi.
    final resend = _sentTo != null;
    if (!resend && !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final email = resend ? _sentTo! : _emailController.text.trim();
    try {
      await widget.services.auth.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _sentTo = email);
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
      title: 'Quên mật khẩu',
      showBack: true,
      child: _sentTo == null ? _buildForm() : _buildSent(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Email đã đăng ký'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'ten@gmail.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: validateEmail,
            onFieldSubmitted: (_) => _sendEmail(),
          ),
          const SizedBox(height: 20),
          BusyButton(
            label: 'Gửi email đặt lại mật khẩu',
            busy: _busy,
            onPressed: _sendEmail,
          ),
        ],
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(
          icon: Icons.mark_email_read_outlined,
          color: AppTheme.success,
          message: 'Đã gửi email tới ${maskEmail(_sentTo!)} (xem cả mục Spam)',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Quay lại đăng nhập'),
        ),
        TextButton(
          onPressed: _busy ? null : _sendEmail,
          child: const Text('Gửi lại email'),
        ),
      ],
    );
  }
}
