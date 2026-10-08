import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../face/face_math.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';
import '../services/validators.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'change_password_screen.dart';
import 'face_scan_screen.dart';
import 'login_screen.dart';

/// Màn hình sau khi đăng nhập: thông tin tài khoản (email, đổi mật khẩu)
/// và bật/tắt đăng nhập nhanh bằng vân tay/khuôn mặt.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.services,
    required this.username,
    this.verificationJustSent = false,
  });

  final AppServices services;
  final String username;

  /// Vừa gửi email xác minh (ngay sau đăng ký): chờ một lúc mới cho gửi lại.
  final bool verificationJustSent;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppServices get _s => widget.services;

  AuthUser? _user;
  AccountProfile? _profile;
  bool _loading = true;
  bool _available = false;
  bool _enabled = false;
  bool _faceEnrolled = false;
  FaceSecurityLevel _faceLevel = kDefaultFaceSecurityLevel;
  List<BiometricType> _types = const [];

  /// Firebase chặn (too-many-requests) nếu gửi email xác minh liên tục,
  /// nên sau mỗi lần gửi phải đợi [_resendDelay] mới bấm "Gửi lại email" được.
  static const _resendDelay = Duration(minutes: 1);
  bool _sending = false;
  bool _resendCooling = false;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    if (widget.verificationJustSent) _startResendCooldown();
    _load();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendCooling = true;
    _resendTimer = Timer(_resendDelay, () {
      if (mounted) setState(() => _resendCooling = false);
    });
  }

  Future<void> _load() async {
    final available = await _s.biometric.isAvailable();
    final types = await _s.biometric.getAvailableBiometrics();
    // Kiểm tra khoá vân tay: nếu vân tay trên máy đã thay đổi thì tính năng tự tắt.
    final lockState = await _s.biometric.checkLock(_s.storage);
    final localFace = await _s.storage.getFaceEmbedding();
    final faceLevel = await _s.storage.getFaceSecurityLevel();
    // Lấy trạng thái mới nhất (email đã xác minh chưa…); lỗi mạng thì dùng thông tin đã có.
    try {
      await _s.auth.reloadUser();
    } on AuthFailure {
      // Bỏ qua.
    }
    final profile = await _s.storage.getProfile();
    if (!mounted) return;
    setState(() {
      _user = _s.auth.currentUser;
      _profile = profile;
      _available = available;
      _types = types;
      _enabled = lockState == BiometricLockState.valid;
      _faceEnrolled = localFace != null;
      _faceLevel = faceLevel;
      _loading = false;
    });
    if (lockState == BiometricLockState.invalidated) {
      _showMessage(BiometricService.invalidatedMessage);
    }
    unawaited(_syncFace(localFace));
  }

  /// Đồng bộ khuôn mặt với tài khoản Firebase (chạy nền, lỗi mạng thì bỏ qua):
  /// - máy này chưa có (máy mới / vừa xoá khỏi máy) mà tài khoản có → tải về;
  /// - máy này có mà tài khoản chưa có (đăng ký từ bản cũ) → đưa lên.
  Future<void> _syncFace(List<double>? localFace) async {
    final uid = _s.auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final cloudFace = await _s.cloud.loadFaceEmbedding(uid);
      if (localFace == null && cloudFace != null) {
        await _s.storage.saveFaceEmbedding(cloudFace);
        if (!mounted) return;
        setState(() => _faceEnrolled = true);
        _showMessage('Đã tải khuôn mặt từ tài khoản');
      } else if (localFace != null && cloudFace == null) {
        await _s.cloud.saveFaceEmbedding(uid, localFace);
      }
    } catch (e) {
      debugPrint('Chưa đồng bộ được khuôn mặt với Firebase: $e');
    }
  }

  /// Ghi/xoá khuôn mặt trên Firebase ở chế độ nền: mất mạng thì Firestore tự gửi sau.
  void _updateCloudFace(List<double>? embedding) {
    final uid = _s.auth.currentUser?.uid;
    if (uid == null) return;
    final Future<void> task = embedding == null
        ? _s.cloud.deleteFaceEmbedding(uid)
        : _s.cloud.saveFaceEmbedding(uid, embedding);
    unawaited(
      task.catchError(
        (Object e) => debugPrint('Chưa lưu được khuôn mặt lên Firebase: $e'),
      ),
    );
  }

  Future<void> _enrollFace() async {
    // Chụp 5 ảnh và lấy vector trung bình để nhận diện ổn định hơn.
    final samples = await Navigator.of(context).push<List<List<double>>>(
      MaterialPageRoute(
        builder: (_) =>
            const FaceScanScreen(title: 'Đăng ký khuôn mặt', shots: 5),
      ),
    );
    if (samples == null) return;
    final embedding = averageEmbeddings(samples);
    await _s.storage.saveFaceEmbedding(embedding);
    _updateCloudFace(embedding);
    if (!mounted) return;
    setState(() => _faceEnrolled = true);
    _showMessage('Đã đăng ký khuôn mặt');
  }

  /// Quét thử và hiện khoảng cách tới khuôn mặt đã đăng ký (không đăng nhập),
  /// giúp kiểm tra độ ổn định và chọn mức an toàn phù hợp.
  Future<void> _testFace() async {
    final reference = await _s.storage.getFaceEmbedding();
    if (reference == null || !mounted) return;
    final samples = await Navigator.of(context).push<List<List<double>>>(
      MaterialPageRoute(
        builder: (_) => const FaceScanScreen(title: 'Thử nhận diện', shots: 2),
      ),
    );
    if (samples == null || !mounted) return;
    if (reference.length != samples.first.length) {
      _showMessage('Mẫu khuôn mặt là của model cũ – hãy bấm Đăng ký lại.');
      return;
    }
    final level = _faceLevel;
    final distances = distancesTo(reference, samples);
    final distance = matchDistance(reference, samples);
    final match = distance < level.threshold;
    final shown = distances.map((d) => d.toStringAsFixed(3)).join(' và ');
    debugPrint(
      'Thử khuôn mặt: khoảng cách $shown – mức ${level.label} '
      '(ngưỡng ${level.threshold}) → ${match ? 'khớp' : 'không khớp'}',
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          match ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: match
              ? const Color(0xFF16A34A)
              : Theme.of(context).colorScheme.error,
          size: 40,
        ),
        title: Text(match ? 'Khớp' : 'Không khớp'),
        content: Text(
          'Khoảng cách: $shown\n'
          'Ngưỡng (mức ${level.label}): ${level.threshold}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFace() async {
    await _s.storage.deleteFaceEmbedding();
    _updateCloudFace(null);
    if (!mounted) return;
    setState(() => _faceEnrolled = false);
    _showMessage('Đã xoá khuôn mặt');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Quét vân tay để tạo khoá gắn với tập vân tay hiện có trên máy.
      final result = await _s.biometric.enable(_s.storage);
      if (!mounted) return;
      if (!result.success) {
        if (result.message != null) _showMessage(result.message!);
        return;
      }
    } else {
      await _s.biometric.disable(_s.storage);
      if (!mounted) return;
    }
    setState(() => _enabled = value);
    _showMessage(
      value ? 'Đã bật đăng nhập bằng vân tay' : 'Đã tắt đăng nhập bằng vân tay',
    );
  }

  /// Đăng xuất: về màn đăng nhập, giữ phiên và cài đặt trên máy để lần sau chọn
  /// mật khẩu, vân tay hoặc khuôn mặt đều được.
  void _signOut() => _goLogin();

  /// Xoá tài khoản khỏi máy: thoát Firebase và xoá hồ sơ, khoá vân tay, khuôn mặt
  /// trên máy. Tài khoản và khuôn mặt lưu trên Firebase vẫn còn.
  Future<void> _removeFromDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.phonelink_erase_rounded),
        title: const Text('Xoá tài khoản khỏi máy này?'),
        content: const Text('Lần sau phải đăng nhập lại bằng mật khẩu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá khỏi máy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _s.biometric.disable(_s.storage);
    await _s.storage.clearAll();
    await _s.auth.signOut();
    _goLogin();
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(services: _s)),
    );
  }

  Future<void> _resendVerification() async {
    setState(() => _sending = true);
    try {
      await _s.auth.sendEmailVerification();
      if (!mounted) return;
      setState(_startResendCooldown);
      _showMessage(
        'Đã gửi email xác minh tới ${maskEmail(_email)} (xem cả mục Spam)',
      );
    } on AuthFailure catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerified() async {
    try {
      await _s.auth.reloadUser();
    } on AuthFailure catch (e) {
      _showMessage(e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _user = _s.auth.currentUser);
    _showMessage(
      (_user?.emailVerified ?? false)
          ? 'Email đã được xác minh'
          : 'Email chưa được xác minh. Hãy bấm đường dẫn trong email.',
    );
  }

  Future<void> _changePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChangePasswordScreen(services: _s)),
    );
    if (changed == true) _showMessage('Đã đổi mật khẩu');
  }

  String get _email => _user?.email ?? _profile?.email ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final methodCount =
        (_enabled && _available ? 1 : 0) + (_faceEnrolled ? 1 : 0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                ),
                children: [
                  BrandBanner(
                    title: 'Xin chào, ${widget.username}',
                    subtitle: methodCount == 0
                        ? 'Chưa bật đăng nhập nhanh'
                        : 'Đã bật $methodCount cách đăng nhập nhanh',
                    bottomPadding: 28,
                    trailing: IconButton(
                      tooltip: 'Đăng xuất',
                      onPressed: _signOut,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionTitle('Tài khoản'),
                            _buildAccountCard(theme),
                            const SizedBox(height: 24),
                            const SectionTitle('Phương thức đăng nhập'),
                            _buildMethodsCard(theme),
                            const SizedBox(height: 24),
                            const SectionTitle('Thiết bị'),
                            _buildDeviceCard(theme),
                            const SizedBox(height: 24),
                            const SectionTitle('Bảo mật dữ liệu'),
                            const Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  _InfoTile(
                                    icon: Icons.password_rounded,
                                    title: 'Mật khẩu',
                                    subtitle: 'Firebase Authentication',
                                  ),
                                  Divider(indent: 72),
                                  _InfoTile(
                                    icon: Icons.key_rounded,
                                    title: 'Vân tay',
                                    subtitle: 'Android Keystore, chỉ trên máy này',
                                  ),
                                  Divider(indent: 72),
                                  _InfoTile(
                                    icon: Icons.memory_rounded,
                                    title: 'Khuôn mặt',
                                    subtitle: 'Vector đặc trưng, không lưu ảnh',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Đăng xuất'),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _removeFromDevice,
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.error,
                              ),
                              icon: const Icon(Icons.phonelink_erase_rounded),
                              label: const Text('Xoá tài khoản khỏi máy này'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAccountCard(ThemeData theme) {
    final verified = _user?.emailVerified ?? false;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            leading: const IconCircle(icon: Icons.mail_outline_rounded),
            title: const Text('Email'),
            // Nhãn trạng thái nằm dưới email để email dài không bị cắt.
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_email),
                const SizedBox(height: 6),
                StatusPill(
                  label: verified ? 'Đã xác minh' : 'Chưa xác minh',
                  active: verified,
                ),
              ],
            ),
          ),
          if (!verified) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: _sending || _resendCooling
                          ? null
                          : _resendVerification,
                      child: Text(
                        _resendCooling ? 'Đã gửi, đợi 1 phút' : 'Gửi lại email',
                      ),
                    ),
                    TextButton(
                      onPressed: _checkVerified,
                      child: const Text('Tôi đã xác minh'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(indent: 72),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            leading: const IconCircle(icon: Icons.password_rounded),
            title: const Text('Đổi mật khẩu'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _changePassword,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodsCard(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            secondary: const IconCircle(icon: Icons.fingerprint_rounded),
            title: const Text('Vân tay'),
            subtitle: _available ? null : const Text('Máy chưa có vân tay'),
            value: _enabled && _available,
            onChanged: _available ? _toggleBiometric : null,
          ),
          const Divider(indent: 72),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            leading: const IconCircle(
              icon: Icons.face_retouching_natural_rounded,
            ),
            title: const Text('Khuôn mặt'),
            trailing: StatusPill(
              label: _faceEnrolled ? 'Đã đăng ký' : 'Chưa đăng ký',
              active: _faceEnrolled,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (_faceEnrolled) ...[
                    IconButton(
                      tooltip: 'Xoá khuôn mặt đã đăng ký',
                      onPressed: _deleteFace,
                      color: scheme.error,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    TextButton.icon(
                      onPressed: _testFace,
                      icon: const Icon(Icons.science_outlined, size: 20),
                      label: const Text('Thử'),
                    ),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: _enrollFace,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 42),
                    ),
                    icon: Icon(
                      _faceEnrolled ? Icons.refresh_rounded : Icons.add_rounded,
                      size: 20,
                    ),
                    label: Text(_faceEnrolled ? 'Đăng ký lại' : 'Đăng ký'),
                  ),
                ],
              ),
            ),
          ),
          if (_faceEnrolled) ...[
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Mức an toàn', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  SegmentedButton<FaceSecurityLevel>(
                    segments: [
                      for (final level in FaceSecurityLevel.values)
                        ButtonSegment(value: level, label: Text(level.label)),
                    ],
                    selected: {_faceLevel},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        _setFaceLevel(selection.first),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setFaceLevel(FaceSecurityLevel level) async {
    setState(() => _faceLevel = level);
    await _s.storage.saveFaceSecurityLevel(level);
    if (!mounted) return;
    _showMessage('Mức an toàn: ${level.label}');
  }

  Widget _buildDeviceCard(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconCircle(icon: Icons.smartphone_rounded),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Sinh trắc học hệ thống hỗ trợ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_types.isEmpty)
              Text(
                'Không có',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _types)
                    Chip(
                      avatar: Icon(
                        _iconFor(t),
                        size: 18,
                        color: scheme.onSecondaryContainer,
                      ),
                      label: Text(BiometricService.label(t)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(BiometricType type) {
    switch (type) {
      case BiometricType.fingerprint:
        return Icons.fingerprint_rounded;
      case BiometricType.face:
        return Icons.face_rounded;
      case BiometricType.iris:
        return Icons.remove_red_eye_outlined;
      case BiometricType.strong:
        return Icons.verified_user_rounded;
      case BiometricType.weak:
        return Icons.shield_outlined;
    }
  }
}

/// Một dòng thông tin trong nhóm "Bảo mật dữ liệu".
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      leading: IconCircle(icon: icon, color: AppTheme.success),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
