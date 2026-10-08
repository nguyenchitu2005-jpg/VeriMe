/// Kiểm tra dữ liệu nhập (thuần Dart, kiểm thử được).
library;

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

/// Che bớt email để hiển thị: `alice.nguyen@gmail.com` → `al***@gmail.com`.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final name = email.substring(0, at);
  final visible = name.length <= 2
      ? name.substring(0, 1)
      : name.substring(0, 2);
  return '$visible***${email.substring(at)}';
}

String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Nhập email';
  return isValidEmail(v) ? null : 'Email không hợp lệ';
}

String? validateNewPassword(String? v) =>
    (v == null || v.length < 6) ? 'Mật khẩu tối thiểu 6 ký tự' : null;

final _usernamePattern = RegExp(r'^[a-zA-Z0-9._-]{3,30}$');

/// Tên đăng nhập: 3–30 ký tự gồm chữ không dấu, số, dấu chấm, gạch dưới,
/// gạch ngang (cũng là mã tài liệu hợp lệ trong Cloud Firestore).
String? validateUsername(String? v) {
  final value = v?.trim() ?? '';
  if (value.length < 3) return 'Tên đăng nhập tối thiểu 3 ký tự';
  if (value.length > 30) return 'Tên đăng nhập tối đa 30 ký tự';
  if (!_usernamePattern.hasMatch(value) ||
      (value.startsWith('__') && value.endsWith('__'))) {
    return 'Chỉ dùng chữ không dấu, số và các dấu . _ -';
  }
  return null;
}

/// Khoá tra cứu tên đăng nhập: không phân biệt hoa thường ("ChiTu" = "chitu").
String normalizeUsername(String username) => username.trim().toLowerCase();
