import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'storage_service.dart';

/// Kết quả của một lần xác thực sinh trắc.
/// [message] là thông báo lỗi tiếng Việt, null nếu thành công hoặc người dùng tự huỷ.
typedef BiometricResult = ({bool success, String? message});

/// Trạng thái khoá vân tay của app.
enum BiometricLockState {
  /// Chưa bật đăng nhập bằng vân tay.
  notEnabled,

  /// Đã bật và tập vân tay trên máy chưa thay đổi.
  valid,

  /// Đã bật nhưng sau đó có vân tay được thêm/xoá trên máy: khoá bị huỷ, đã tự tắt.
  invalidated,
}

/// Đăng nhập bằng vân tay gắn với **tập vân tay có trên máy lúc bật tính năng**.
///
/// Android không cho app đọc hay tự đăng ký vân tay. Thay vào đó, khi bật, phần native
/// (`android/.../BiometricLock.java`) tạo khoá AES trong Android Keystore với
/// `setInvalidatedByBiometricEnrollment(true)`, quét vân tay để mã hoá một mã bí mật
/// ngẫu nhiên. Khi đăng nhập phải quét vân tay để giải mã được mã này.
/// Nếu sau đó có ai thêm (hoặc xoá) vân tay trên máy, Android huỷ khoá vĩnh viễn và
/// app bắt đăng nhập lại bằng mật khẩu rồi bật lại.
class BiometricService {
  BiometricService({LocalAuthentication? auth, MethodChannel? channel})
    : _auth = auth ?? LocalAuthentication(),
      _channel = channel ?? const MethodChannel('faceid/biometric_lock');

  final LocalAuthentication _auth;
  final MethodChannel _channel;

  /// Thiết bị có vân tay (sinh trắc loại mạnh – Class 3) đã đăng ký và dùng được.
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<String>('status') == 'available';
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Các loại sinh trắc hệ thống báo về (chỉ để hiển thị thông tin).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  /// Quét vân tay để tạo khoá mới và lưu vào [storage]. Thay thế khoá cũ nếu có.
  Future<BiometricResult> enable(StorageService storage) async {
    try {
      final data = await _channel.invokeMapMethod<String, String>(
        'enable',
        _prompt('Xác thực để bật đăng nhập bằng vân tay'),
      );
      if (data == null) {
        return (success: false, message: 'Không tạo được khoá vân tay.');
      }
      await storage.saveBiometricLock((
        iv: data['iv']!,
        ciphertext: data['ciphertext']!,
        tokenHash: _hashToken(data['token']!),
      ));
      return (success: true, message: null);
    } on PlatformException catch (e) {
      return (success: false, message: messageFor(e.code));
    }
  }

  /// Quét vân tay để mở khoá. Nếu tập vân tay trên máy đã thay đổi, tự tắt tính năng.
  Future<BiometricResult> unlock(StorageService storage) async {
    final lock = await storage.getBiometricLock();
    if (lock == null) {
      return (success: false, message: 'Chưa bật đăng nhập bằng vân tay.');
    }
    try {
      final token = await _channel.invokeMethod<String>('unlock', {
        ..._prompt('Xác thực để đăng nhập vào ứng dụng'),
        'iv': lock.iv,
        'ciphertext': lock.ciphertext,
      });
      if (token == null || _hashToken(token) != lock.tokenHash) {
        return (success: false, message: messageFor('DECRYPT_FAILED'));
      }
      return (success: true, message: null);
    } on PlatformException catch (e) {
      if (e.code == 'KEY_INVALIDATED' || e.code == 'KEY_MISSING') {
        await storage.clearBiometricLock();
      }
      return (success: false, message: messageFor(e.code));
    }
  }

  /// Kiểm tra khoá mà không hiện hộp thoại (dùng khi mở Trang chủ).
  Future<BiometricLockState> checkLock(StorageService storage) async {
    if (!await storage.isBiometricEnabled()) {
      return BiometricLockState.notEnabled;
    }
    try {
      final state = await _channel.invokeMethod<String>('keyState');
      if (state == 'invalidated' || state == 'missing') {
        await storage.clearBiometricLock();
        return BiometricLockState.invalidated;
      }
    } on PlatformException {
      // Không kiểm tra được lúc này: giữ nguyên, lần mở khoá sau sẽ kiểm tra lại.
    } on MissingPluginException {
      // Như trên.
    }
    return BiometricLockState.valid;
  }

  /// Tắt đăng nhập bằng vân tay: xoá khoá trong Keystore và dữ liệu đã lưu.
  Future<void> disable(StorageService storage) async {
    try {
      await _channel.invokeMethod<void>('disable');
    } on PlatformException {
      // Khoá có thể đã không còn.
    } on MissingPluginException {
      // Như trên.
    }
    await storage.clearBiometricLock();
  }

  static Map<String, String> _prompt(String subtitle) => {
    'title': 'Xác thực vân tay',
    'subtitle': subtitle,
    'cancel': 'Huỷ',
  };

  static String _hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  static const invalidatedMessage =
      'Vân tay trên máy đã thay đổi (có vân tay được thêm hoặc xoá). '
      'Vì an toàn, đăng nhập bằng vân tay đã bị tắt. '
      'Hãy đăng nhập bằng mật khẩu rồi bật lại.';

  /// Thông báo tiếng Việt cho mã lỗi từ phần native; null nếu người dùng tự huỷ.
  static String? messageFor(String code) {
    switch (code) {
      case 'CANCELED':
        return null;
      case 'KEY_INVALIDATED':
        return invalidatedMessage;
      case 'KEY_MISSING':
        return 'Khoá vân tay không còn. Hãy đăng nhập bằng mật khẩu rồi bật lại.';
      case 'LOCKOUT':
        return 'Sai quá nhiều lần, vân tay bị khoá tạm thời. Hãy dùng mật khẩu.';
      case 'LOCKOUT_PERMANENT':
        return 'Vân tay bị khoá. Hãy mở khoá màn hình bằng PIN rồi thử lại.';
      case 'NOT_ENROLLED':
        return 'Chưa có vân tay nào trên máy. Hãy thêm trong Cài đặt > Bảo mật.';
      case 'NO_HARDWARE':
        return 'Thiết bị không có cảm biến vân tay dùng được.';
      case 'NO_CREDENTIAL':
        return 'Thiết bị chưa đặt khoá màn hình (PIN/mật khẩu/hình vẽ).';
      case 'TIMEOUT':
        return 'Hết thời gian xác thực.';
      case 'DECRYPT_FAILED':
        return 'Không xác minh được khoá vân tay. Hãy đăng nhập bằng mật khẩu.';
      default:
        return 'Không thể xác thực ($code).';
    }
  }

  static String label(BiometricType type) {
    switch (type) {
      case BiometricType.fingerprint:
        return 'Vân tay';
      case BiometricType.face:
        return 'Khuôn mặt';
      case BiometricType.iris:
        return 'Mống mắt';
      case BiometricType.strong:
        return 'Sinh trắc mạnh (Class 3)';
      case BiometricType.weak:
        return 'Sinh trắc yếu (Class 2)';
    }
  }
}
