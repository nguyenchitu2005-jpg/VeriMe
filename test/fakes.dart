import 'package:faceid/services/app_services.dart';
import 'package:faceid/services/auth_service.dart';
import 'package:faceid/services/biometric_service.dart';
import 'package:faceid/services/cloud_data_service.dart';
import 'package:faceid/services/storage_service.dart';
import 'package:faceid/services/validators.dart';
import 'package:faceid/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

/// Giả lập thiết bị có vân tay để dựng giao diện mà không cần plugin thật.
class FakeBiometricService extends BiometricService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => const [
    BiometricType.strong,
    BiometricType.weak,
  ];

  @override
  Future<BiometricResult> unlock(StorageService storage) async =>
      (success: false, message: null);

  @override
  Future<BiometricLockState> checkLock(StorageService storage) async =>
      await storage.isBiometricEnabled()
      ? BiometricLockState.valid
      : BiometricLockState.notEnabled;

  @override
  Future<void> disable(StorageService storage) => storage.clearBiometricLock();
}

/// Dữ liệu giả của một khoá vân tay đã bật.
const fakeBiometricLock = {
  'biometric_enabled': 'true',
  'biometric_iv': 'aXY=',
  'biometric_ciphertext': 'Y3Q=',
  'biometric_token_hash': 'hash',
};

/// Hồ sơ tài khoản "alice" đã lưu trên máy.
const fakeProfile = {'username': 'alice', 'email': 'alice@example.com'};

class _FakeAccount {
  _FakeAccount(this.username, this.email, this.password);

  final String username;
  final String email;
  String password;
  bool emailVerified = false;
}

/// Firebase Auth giả trong bộ nhớ.
class FakeAuthService extends AuthService {
  final List<_FakeAccount> _accounts = [];
  _FakeAccount? _current;

  /// Ghi lại các thao tác để kiểm tra trong test.
  final List<String> log = [];

  /// Đặt khác null để giả lập Firebase không gửi được email xác minh.
  AuthFailure? verificationError;

  /// Đặt khác null để giả lập không tra được bảng tên đăng nhập (mất mạng…).
  AuthFailure? lookupError;

  _FakeAccount? _byUsername(String username) => _accounts
      .where(
        (a) => normalizeUsername(a.username) == normalizeUsername(username),
      )
      .firstOrNull;

  @override
  Future<String?> emailForUsername(String username) async {
    if (lookupError != null) throw lookupError!;
    log.add('lookup ${normalizeUsername(username)}');
    return _byUsername(username)?.email;
  }

  /// Tạo sẵn tài khoản trên "máy chủ" (không đăng nhập).
  void seed({
    required String username,
    required String email,
    required String password,
    bool signedIn = false,
  }) {
    final a = _FakeAccount(username, email, password);
    _accounts.add(a);
    if (signedIn) _current = a;
  }

  @override
  AuthUser? get currentUser {
    final a = _current;
    if (a == null) return null;
    return (
      uid: a.email,
      email: a.email,
      emailVerified: a.emailVerified,
      displayName: a.username,
    );
  }

  @override
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    if (_byUsername(username) != null) {
      throw const AuthFailure(
        'username-already-in-use',
        'Tên đăng nhập này đã có người dùng. Hãy chọn tên khác.',
      );
    }
    if (_accounts.any((a) => a.email == email)) {
      throw const AuthFailure('email-already-in-use', 'Email đã được dùng.');
    }
    final a = _FakeAccount(username, email, password);
    _accounts.add(a);
    _current = a;
    log.add('register $email');
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    log.add('signIn $email');
    final a = _accounts.where((a) => a.email == email).firstOrNull;
    if (a == null || a.password != password) {
      throw const AuthFailure(
        'invalid-credential',
        'Sai email/tên đăng nhập hoặc mật khẩu.',
      );
    }
    _current = a;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async =>
      log.add('reset $email');

  @override
  Future<void> sendEmailVerification() async {
    if (verificationError != null) throw verificationError!;
    log.add('verifyEmail');
  }

  @override
  Future<void> reloadUser() async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final a = _current!;
    if (currentPassword != a.password) {
      throw const AuthFailure('invalid-credential', 'Sai mật khẩu hiện tại.');
    }
    a.password = newPassword;
    log.add('changePassword');
  }

  @override
  Future<void> signOut() async {
    _current = null;
    log.add('signOut');
  }

  String? passwordOf(String email) =>
      _accounts.where((a) => a.email == email).firstOrNull?.password;
}

/// Firestore giả: vector khuôn mặt theo uid (uid giả = email).
class FakeCloudDataService extends CloudDataService {
  final Map<String, List<double>> faces = {};

  @override
  Future<List<double>?> loadFaceEmbedding(String uid) async => faces[uid];

  @override
  Future<void> saveFaceEmbedding(String uid, List<double> embedding) async =>
      faces[uid] = embedding;

  @override
  Future<void> deleteFaceEmbedding(String uid) async => faces.remove(uid);
}

AppServices makeServices({
  BiometricService? biometric,
  AuthService? auth,
  CloudDataService? cloud,
}) => AppServices(
  storage: StorageService(),
  biometric: biometric ?? FakeBiometricService(),
  auth: auth ?? FakeAuthService(),
  cloud: cloud ?? FakeCloudDataService(),
);

/// Dựng một màn hình ở kích thước điện thoại nhỏ (360 x 690 dp).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}
