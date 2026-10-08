import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../services/validators.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Tạo tài khoản: tên đăng nhập, email (để nhận email xác minh và email đặt lại
/// mật khẩu khi quên) và mật khẩu.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final services = widget.services;
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    try {
      await services.auth.register(
        username: username,
        email: email,
        password: _passwordController.text,
      );
      // Máy này có thể còn khoá vân tay / khuôn mặt của tài khoản trước: xoá đi.
      await services.biometric.disable(services.storage);
      await services.storage.deleteFaceEmbedding();
      await services.storage.saveProfile((username: username, email: email));
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(e.message);
      }
      return;
    }

    // Tài khoản đã tạo xong; gửi email xác minh là bước riêng, lỗi thì vẫn vào
    // Trang chủ và bấm "Gửi lại email" sau.
    String message;
    var sent = false;
    try {
      await services.auth.sendEmailVerification();
      sent = true;
      message =
          'Đã gửi email xác minh tới ${maskEmail(email)} (xem cả mục Spam)';
    } on AuthFailure catch (e) {
      message =
          'Đã tạo tài khoản nhưng chưa gửi được email xác minh: ${e.message}';
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          services: services,
          username: username,
          verificationJustSent: sent,
        ),
      ),
    );
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(services: widget.services)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Tạo tài khoản',
      footer: FooterLink(
        text: 'Đã có tài khoản?',
        action: 'Đăng nhập',
        onPressed: _saving ? null : _goLogin,
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Tên đăng nhập'),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.newUsername],
                decoration: const InputDecoration(
                  hintText: 'Chữ không dấu, số; tối thiểu 3 ký tự',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: validateUsername,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Email'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'ten@gmail.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Mật khẩu'),
              PasswordField(
                controller: _passwordController,
                label: 'Tối thiểu 6 ký tự',
                textInputAction: TextInputAction.next,
                validator: validateNewPassword,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Nhập lại mật khẩu'),
              PasswordField(
                controller: _confirmController,
                label: 'Nhập lại mật khẩu',
                textInputAction: TextInputAction.done,
                validator: (v) => v != _passwordController.text
                    ? 'Mật khẩu nhập lại không khớp'
                    : null,
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 24),
              BusyButton(label: 'Đăng ký', busy: _saving, onPressed: _register),
            ],
          ),
        ),
      ),
    );
  }
}
