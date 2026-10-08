import 'package:flutter/material.dart';

import '../face/face_math.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/validators.dart';
import '../widgets/common.dart';
import 'face_scan_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';

/// Đăng nhập bằng email/tên đăng nhập + mật khẩu, hoặc mở khoá nhanh bằng
/// vân tay/khuôn mặt khi phiên đăng nhập còn trên máy.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  // Mỗi lần thử, người khác vẫn có một xác suất nhỏ lọt qua (xem FaceSecurityLevel)
  // => giới hạn 3 lần.
  static const _maxFaceFailures = 3;

  AppServices get _s => widget.services;

  /// Hồ sơ tài khoản đã đăng nhập trên máy này (null nếu chưa có).
  AccountProfile? _profile;

  /// Còn phiên đăng nhập Firebase trên máy (đã đăng nhập bằng mật khẩu ít nhất một lần
  /// và chưa "Xoá tài khoản khỏi máy"). Vân tay/khuôn mặt chỉ mở khoá được khi còn phiên.
  bool _hasSession = false;

  /// Máy có vân tay loại mạnh đã đăng ký trong Cài đặt.
  bool _deviceHasBiometric = false;

  /// Đã bật vân tay cho tài khoản trên máy này và còn phiên → dùng được ngay.
  bool _canUseBiometric = false;
  List<double>? _faceEmbedding;
  int _faceFailures = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Gõ sang tài khoản khác thì nút vân tay chuyển màu nhạt (xem _inputMatchesDeviceAccount).
    _identifierController.addListener(_onIdentifierChanged);
    _init();
  }

  void _onIdentifierChanged() => setState(() {});

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final profile = await _s.storage.getProfile();
    final hasSession = _s.auth.isSignedIn && profile != null;
    final deviceHasBiometric = await _s.biometric.isAvailable();
    final available =
        hasSession &&
        deviceHasBiometric &&
        await _s.storage.isBiometricEnabled();
    final faceEmbedding = hasSession
        ? await _s.storage.getFaceEmbedding()
        : null;
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _identifierController.text = profile?.username ?? '';
      _hasSession = hasSession;
      _deviceHasBiometric = deviceHasBiometric;
      _canUseBiometric = available;
      _faceEmbedding = faceEmbedding;
    });
    // Tự bật hộp thoại vân tay khi vào màn hình đăng nhập.
    if (available) _loginWithBiometric();
  }

  /// Nhập email thì dùng luôn; nhập tên đăng nhập thì tra email trên Firebase
  /// (bảng tên đăng nhập trên Firestore). Không tra được (mất mạng…) thì dùng hồ sơ
  /// đã lưu trên máy nếu trùng tên; vẫn không có thì ném lỗi tra cứu.
  Future<String?> _resolveEmail(String input) async {
    final value = input.trim();
    if (value.contains('@')) return value;
    AuthFailure? lookupError;
    try {
      final email = await _s.auth.emailForUsername(value);
      if (email != null) return email;
    } on AuthFailure catch (e) {
      lookupError = e;
    }
    final p = _profile;
    if (p != null &&
        normalizeUsername(p.username) == normalizeUsername(value)) {
      return p.email;
    }
    if (lookupError != null) throw lookupError;
    return null;
  }

  Future<void> _loginWithPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final email = await _resolveEmail(_identifierController.text);
      if (email == null) {
        _showMessage(
          'Không có tài khoản nào tên "${_identifierController.text.trim()}". '
          'Hãy kiểm tra lại, hoặc đăng nhập bằng email.',
        );
        return;
      }
      await _s.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );
      await _finishSignIn();
    } on AuthFailure catch (e) {
      _passwordController.clear();
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordScreen(services: _s, initialEmail: _profile?.email),
      ),
    );
  }

  /// Sau khi đăng nhập bằng mật khẩu: lưu hồ sơ và vào Trang chủ.
  Future<void> _finishSignIn() async {
    final user = _s.auth.currentUser;
    if (user == null) return;
    final email = user.email ?? '';
    final old = _profile;
    final sameAccount =
        old != null && old.email.toLowerCase() == email.toLowerCase();
    if (old != null && !sameAccount) {
      // Tài khoản khác: không dùng lại vân tay/khuôn mặt của tài khoản trước.
      await _s.biometric.disable(_s.storage);
      await _s.storage.deleteFaceEmbedding();
    }
    final username = sameAccount
        ? old.username
        : ((user.displayName?.isNotEmpty ?? false)
              ? user.displayName!
              : email.split('@').first);
    await _s.storage.saveProfile((username: username, email: email));
    _goHome(username);
  }

  /// Vân tay/khuôn mặt trên máy chỉ mở được tài khoản đã đăng ký chúng trên máy này
  /// ([_profile]). Ô tên đăng nhập phải đúng tên/email của tài khoản đó (hoặc để trống):
  /// gõ tài khoản khác – ví dụ "huy" trong khi khuôn mặt trên máy là của "chitu" – thì
  /// báo sai, không được tự vào tài khoản đang lưu trên máy.
  bool get _inputMatchesDeviceAccount {
    final p = _profile;
    if (p == null) return false;
    final value = _identifierController.text.trim().toLowerCase();
    return value.isEmpty ||
        value == p.username.toLowerCase() ||
        value == p.email.toLowerCase();
  }

  /// Kiểm tra trước khi dùng vân tay/khuôn mặt; sai tài khoản thì báo và trả về false.
  Future<bool> _checkQuickLoginAccount(String method) async {
    if (_inputMatchesDeviceAccount) return true;
    final name = _identifierController.text.trim();
    await _showAlert(
      icon: Icons.person_off_outlined,
      title: 'Sai tài khoản',
      message:
          '$method trên máy này không thuộc tài khoản "$name".',
    );
    return false;
  }

  Future<void> _showAlert({
    required IconData icon,
    required String title,
    required String message,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon, size: 40, color: Theme.of(context).colorScheme.error),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  Future<void> _loginWithBiometric() async {
    if (_busy || !await _checkQuickLoginAccount('Vân tay')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final result = await _s.biometric.unlock(_s.storage);
    // Nếu vân tay trên máy đã thay đổi, unlock() đã tự tắt tính năng: nút vân tay chuyển
    // sang màu nhạt, bấm vào sẽ hướng dẫn đăng nhập bằng mật khẩu rồi bật lại.
    final stillEnabled = await _s.storage.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _canUseBiometric = _canUseBiometric && stillEnabled;
    });
    if (result.success) {
      _goHome(_profile!.username);
    } else {
      _showMessage(result.message);
    }
  }

  Future<void> _loginWithFace() async {
    final reference = _faceEmbedding;
    if (reference == null || _busy) return;
    if (!await _checkQuickLoginAccount('Khuôn mặt') || !mounted) return;
    if (_faceFailures >= _maxFaceFailures) {
      _showMessage('Sai khuôn mặt quá nhiều lần. Hãy đăng nhập bằng mật khẩu.');
      return;
    }
    // Chụp 2 ảnh, lấy ảnh khớp nhất so với ngưỡng của mức an toàn (xem matchDistance).
    final samples = await Navigator.of(context).push<List<List<double>>>(
      MaterialPageRoute(
        builder: (_) =>
            const FaceScanScreen(title: 'Đăng nhập bằng khuôn mặt', shots: 2),
      ),
    );
    if (samples == null || !mounted) return;
    if (reference.length != samples.first.length) {
      // Mẫu của model cũ (khác số chiều): không so được.
      _showMessage(
        'Ứng dụng đã đổi sang model nhận diện mới. Hãy đăng nhập bằng mật khẩu '
        'rồi đăng ký lại khuôn mặt ở Trang chủ.',
      );
      return;
    }

    final level = await _s.storage.getFaceSecurityLevel();
    final distance = matchDistance(reference, samples);
    final match = distance < level.threshold;
    debugPrint(
      'Đăng nhập khuôn mặt: khoảng cách '
      '${distancesTo(reference, samples).map((d) => d.toStringAsFixed(3)).join(', ')} '
      '– mức ${level.label} (ngưỡng ${level.threshold}) → ${match ? 'khớp' : 'không khớp'}',
    );
    if (!mounted) return;
    if (match) {
      _goHome(_profile!.username);
    } else {
      setState(() => _faceFailures++);
      final left = _maxFaceFailures - _faceFailures;
      await _showAlert(
        icon: Icons.no_accounts_outlined,
        title: 'Gương mặt không khớp',
        message: left > 0
            ? 'Còn $left lần thử.'
            : 'Hãy đăng nhập bằng mật khẩu.',
      );
    }
  }

  /// Nút vân tay luôn hiện cạnh ô mật khẩu; chưa dùng được thì bấm vào để xem lý do.
  void _explainBiometric() => _showMessage(
    !_hasSession
        ? 'Lần đầu trên máy này, hãy đăng nhập bằng mật khẩu.'
        : !_deviceHasBiometric
        ? 'Máy chưa có vân tay.'
        : 'Chưa bật đăng nhập bằng vân tay.',
  );

  void _explainFace() => _showMessage(
    !_hasSession
        ? 'Lần đầu trên máy này, hãy đăng nhập bằng mật khẩu.'
        : 'Chưa đăng ký khuôn mặt.',
  );

  void _goHome(String username) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(services: _s, username: username),
      ),
    );
  }

  void _goRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RegisterScreen(services: _s)),
    );
  }

  void _showMessage(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final faceLocked = _faceFailures >= _maxFaceFailures;
    return AuthLayout(
      title: 'Chào mừng trở lại',
      footer: FooterLink(
        text: 'Chưa có tài khoản?',
        action: 'Đăng ký',
        onPressed: _busy ? null : _goRegister,
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Email hoặc tên đăng nhập'),
              TextFormField(
                controller: _identifierController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nhập email hoặc tên đăng nhập'
                    : null,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Mật khẩu'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PasswordField(
                      controller: _passwordController,
                      label: 'Nhập mật khẩu',
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                      onSubmitted: (_) => _loginWithPassword(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FingerprintButton(
                    dimmed: !_canUseBiometric || !_inputMatchesDeviceAccount,
                    onPressed: _busy
                        ? null
                        : (_canUseBiometric
                              ? _loginWithBiometric
                              : _explainBiometric),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
              const SizedBox(height: 4),
              BusyButton(
                label: 'Đăng nhập',
                busy: _busy,
                onPressed: _loginWithPassword,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy || faceLocked
                    ? null
                    : (_faceEmbedding != null ? _loginWithFace : _explainFace),
                icon: const Icon(Icons.face_retouching_natural_rounded),
                label: Text(
                  faceLocked
                      ? 'Khuôn mặt tạm khoá – dùng mật khẩu'
                      : 'Đăng nhập bằng khuôn mặt',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
