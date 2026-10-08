import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'validators.dart';

/// Thông tin tài khoản đang đăng nhập.
typedef AuthUser = ({
  String uid,
  String? email,
  bool emailVerified,
  String? displayName,
});

/// Lỗi xác thực, [message] là thông báo tiếng Việt để hiển thị.
class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AuthFailure($code): $message';
}

/// Tài khoản lưu trên máy chủ (Firebase Authentication): đăng ký, đăng nhập bằng email +
/// mật khẩu, gửi email xác minh, gửi email đặt lại mật khẩu, đổi mật khẩu.
/// Firebase Authentication chỉ biết email, nên tên đăng nhập được lưu thêm trong
/// bảng tra cứu "tên đăng nhập → email" trên Cloud Firestore.
///
/// Màn hình chỉ phụ thuộc lớp trừu tượng này nên kiểm thử được bằng bản giả.
abstract class AuthService {
  AuthUser? get currentUser;

  bool get isSignedIn => currentUser != null;

  /// Email của tài khoản mang tên đăng nhập [username] (không phân biệt hoa thường),
  /// null nếu chưa ai dùng tên đó.
  Future<String?> emailForUsername(String username);

  /// Tạo tài khoản bằng email + mật khẩu, giữ tên đăng nhập [username] trên máy chủ
  /// (báo lỗi nếu tên đã có người dùng) và đăng nhập luôn.
  /// Email xác minh gửi riêng bằng [sendEmailVerification], để lỗi gửi thư
  /// (ví dụ bị Firebase giới hạn) không làm hỏng việc tạo tài khoản.
  Future<void> register({
    required String username,
    required String email,
    required String password,
  });

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Firebase gửi email chứa đường dẫn đặt lại mật khẩu.
  Future<void> sendPasswordResetEmail(String email);

  Future<void> sendEmailVerification();

  /// Tải lại thông tin (ví dụ sau khi người dùng bấm đường dẫn xác minh email).
  Future<void> reloadUser();

  /// Đổi mật khẩu: xác thực lại bằng [currentPassword] (Firebase yêu cầu đăng nhập gần đây)
  /// rồi đặt [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();
}

/// Cài đặt bằng Firebase Authentication + Cloud Firestore (bảng tên đăng nhập).
class FirebaseAuthService extends AuthService {
  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// usernames/{tên viết thường} = {uid, email, username, createdAt}.
  /// Quyền truy cập: xem firestore.rules ở thư mục gốc của project.
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  @override
  AuthUser? get currentUser {
    final u = _auth.currentUser;
    if (u == null) return null;
    return (
      uid: u.uid,
      email: u.email,
      emailVerified: u.emailVerified,
      displayName: u.displayName,
    );
  }

  User get _user {
    final u = _auth.currentUser;
    if (u == null) {
      throw const AuthFailure(
        'no-current-user',
        'Phiên đăng nhập đã hết. Hãy đăng nhập lại.',
      );
    }
    return u;
  }

  @override
  Future<String?> emailForUsername(String username) => _guard(() async {
    final doc = await _usernames
        .doc(normalizeUsername(username))
        .get()
        // Mạng chập chờn thì Firestore có thể chờ rất lâu; quá hạn thì báo lỗi để
        // màn đăng nhập dùng hồ sơ trên máy.
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          ),
        );
    return doc.data()?['email'] as String?;
  });

  @override
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) => _guard(() async {
    final name = username.trim();
    // Hỏi thẳng máy chủ (không dùng bộ nhớ đệm) trước khi tạo tài khoản.
    final existing = await _usernames
        .doc(normalizeUsername(name))
        .get(const GetOptions(source: Source.server));
    if (existing.exists) {
      throw const AuthFailure(
        'username-already-in-use',
        'Tên đăng nhập này đã có người dùng. Hãy chọn tên khác.',
      );
    }
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    try {
      await _claimUsername(user, name);
    } catch (_) {
      // Không giữ được tên (vừa bị người khác lấy, lỗi mạng…): xoá tài khoản vừa tạo
      // để có thể đăng ký lại bằng email này.
      await user.delete();
      rethrow;
    }
    await user.updateDisplayName(name);
    await user.reload();
  });

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) => _guard(() async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    unawaited(_ensureUsername(cred.user));
  });

  /// Ghi tên đăng nhập vào bảng tra cứu. Luật Firestore chỉ cho tạo mới,
  /// nên tên đã có người dùng thì báo permission-denied.
  Future<void> _claimUsername(User user, String username) =>
      _usernames.doc(normalizeUsername(username)).set({
        'uid': user.uid,
        'email': user.email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Tài khoản tạo trước khi có bảng tra cứu: thêm tên hiển thị vào bảng để lần sau
  /// đăng nhập bằng tên được. Chạy nền, lỗi chỉ ghi log – không làm hỏng việc đăng nhập.
  Future<void> _ensureUsername(User? user) async {
    final name = user?.displayName?.trim();
    if (user == null || name == null || validateUsername(name) != null) return;
    try {
      final doc = await _usernames.doc(normalizeUsername(name)).get();
      if (!doc.exists) {
        await _claimUsername(user, name);
        debugPrint('Đã thêm tên đăng nhập "$name" lên Firestore');
      }
    } catch (e) {
      debugPrint('Chưa thêm được tên đăng nhập "$name" lên Firestore: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) => _guard(() async {
    await _auth.sendPasswordResetEmail(email: email.trim());
    debugPrint(
      'Firebase đã nhận yêu cầu gửi email đặt lại mật khẩu tới ${email.trim()}',
    );
  });

  @override
  Future<void> sendEmailVerification() => _guard(() async {
    final user = _user;
    await user.sendEmailVerification();
    debugPrint('Firebase đã nhận yêu cầu gửi email xác minh tới ${user.email}');
  });

  @override
  Future<void> reloadUser() => _guard(() async {
    await _auth.currentUser?.reload();
    unawaited(_ensureUsername(_auth.currentUser));
  });

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _guard(() async {
    final user = _user;
    final email = user.email;
    if (email == null) {
      throw const AuthFailure('no-email', 'Tài khoản chưa có email.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    await user.updatePassword(newPassword);
  });

  @override
  Future<void> signOut() => _auth.signOut();

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      // Ghi ra logcat (tag "flutter") để chẩn đoán: adb logcat | findstr AuthFailure
      debugPrint('AuthFailure ${e.code}: ${e.message}');
      throw AuthFailure(e.code, messageFor(e.code, e.message));
    } on FirebaseException catch (e) {
      // Lỗi từ Cloud Firestore (bảng tên đăng nhập).
      debugPrint('AuthFailure firestore/${e.code}: ${e.message}');
      throw AuthFailure(e.code, firestoreMessageFor(e.code, e.message));
    }
  }

  /// Thông báo tiếng Việt cho mã lỗi Cloud Firestore.
  static String firestoreMessageFor(String code, [String? fallback]) {
    // Chưa tạo Firestore Database thì máy chủ cũng trả permission-denied/not-found,
    // kèm câu "Cloud Firestore API has not been used…" hoặc "database … does not exist".
    final detail = fallback ?? '';
    if (detail.contains('has not been used') ||
        detail.contains('SERVICE_DISABLED') ||
        detail.contains('does not exist')) {
      code = 'not-found';
    }
    switch (code) {
      case 'permission-denied':
        return 'Firestore từ chối truy cập bảng tên đăng nhập. Hãy dán nội dung file '
            'firestore.rules vào Firebase Console → Firestore Database → Rules '
            '(README mục 4.8).';
      case 'not-found':
        return 'Chưa tạo Cloud Firestore. Vào Firebase Console → Firestore Database → '
            'Create database (README mục 4.8).';
      case 'unavailable':
        return 'Không kết nối được Firestore. Kiểm tra Internet, hoặc kiểm tra đã tạo '
            'Firestore Database chưa (README mục 4.8).';
      default:
        return 'Lỗi Firestore ($code)${fallback == null ? '' : ': $fallback'}';
    }
  }

  /// Thông báo tiếng Việt cho mã lỗi Firebase Auth.
  static String messageFor(String code, [String? fallback]) {
    switch (code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hoá.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Sai email/tên đăng nhập hoặc mật khẩu.';
      case 'email-already-in-use':
        return 'Email này đã được dùng cho tài khoản khác.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'too-many-requests':
        return 'Firebase tạm chặn vì thao tác quá nhiều lần (nhập sai mật khẩu '
            'hoặc gửi email liên tục). Hãy đợi vài phút rồi thử lại.';
      case 'network-request-failed':
        return 'Không có kết nối Internet.';
      case 'requires-recent-login':
        return 'Vì an toàn, hãy đăng nhập lại rồi thực hiện thao tác này.';
      case 'operation-not-allowed':
        return 'Đăng nhập bằng Email/Password chưa được bật trong Firebase Console.';
      default:
        return 'Lỗi xác thực ($code)${fallback == null ? '' : ': $fallback'}';
    }
  }
}
