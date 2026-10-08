import 'auth_service.dart';
import 'biometric_service.dart';
import 'cloud_data_service.dart';
import 'storage_service.dart';

/// Các dịch vụ dùng chung, truyền qua các màn hình.
class AppServices {
  const AppServices({
    required this.storage,
    required this.biometric,
    required this.auth,
    required this.cloud,
  });

  /// Hồ sơ tài khoản, khoá vân tay, vector khuôn mặt (lưu trên máy).
  final StorageService storage;

  /// Khoá vân tay (Android Keystore).
  final BiometricService biometric;

  /// Tài khoản trên Firebase: mật khẩu, tên đăng nhập, email xác minh, email đặt lại mật khẩu.
  final AuthService auth;

  /// Dữ liệu tài khoản trên Firebase (vector khuôn mặt) để dùng lại trên máy khác.
  final CloudDataService cloud;
}
