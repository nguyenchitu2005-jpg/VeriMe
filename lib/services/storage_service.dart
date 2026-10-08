import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../face/face_math.dart';

/// Dữ liệu khoá vân tay: IV + bản mã (Base64) và SHA-256 của mã bí mật.
typedef BiometricLockData = ({String iv, String ciphertext, String tokenHash});

/// Hồ sơ tài khoản lưu trên máy. Mật khẩu KHÔNG lưu ở đây – Firebase kiểm tra mật khẩu.
/// Dùng để đổi tên đăng nhập → email khi đăng nhập và điền sẵn email khi quên mật khẩu.
typedef AccountProfile = ({String username, String email});

/// Lưu hồ sơ tài khoản và cài đặt sinh trắc trong bộ nhớ an toàn
/// (trên Android dữ liệu được mã hoá bằng khoá trong Android Keystore).
///
/// Mật khẩu không lưu trên máy: tài khoản nằm trên Firebase Authentication.
class StorageService {
  StorageService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyUsername = 'username';
  static const _keyEmail = 'email';
  // Bản cũ lưu hash mật khẩu trên máy; nay mật khẩu do Firebase kiểm tra nên bỏ.
  // Bản trước có lưu SĐT; nay chỉ dùng email.
  static const _legacyKeys = ['password_salt', 'password_hash', 'phone'];
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyBioIv = 'biometric_iv';
  static const _keyBioCiphertext = 'biometric_ciphertext';
  static const _keyBioTokenHash = 'biometric_token_hash';
  // v3: vector 512 chiều của FaceNet-512. Vector cũ (v1: chưa căn thẳng; v2: MobileFaceNet
  // 192 chiều) không so sánh được với vector mới nên bị bỏ, người dùng cần đăng ký lại.
  static const _keyFaceEmbedding = 'face_embedding_v3';
  static const _legacyFaceKeys = ['face_embedding', 'face_embedding_v2'];
  static const _keyFaceSecurityLevel = 'face_security_level';

  /// Hồ sơ tài khoản trên máy; null nếu chưa đăng ký/đăng nhập lần nào
  /// (hoặc là dữ liệu bản cũ chưa có email).
  Future<AccountProfile?> getProfile() async {
    final username = await _storage.read(key: _keyUsername);
    final email = await _storage.read(key: _keyEmail);
    if (username == null || email == null) return null;
    return (username: username, email: email);
  }

  Future<void> saveProfile(AccountProfile profile) async {
    await _storage.write(key: _keyUsername, value: profile.username);
    await _storage.write(key: _keyEmail, value: profile.email);
    for (final key in _legacyKeys) {
      await _storage.delete(key: key);
    }
  }

  /// Đã bật đăng nhập bằng vân tay và có khoá vân tay đi kèm.
  /// (Bản cũ chỉ lưu cờ, không có khoá, nên được coi là chưa bật và phải bật lại.)
  Future<bool> isBiometricEnabled() async =>
      await _storage.read(key: _keyBiometricEnabled) == 'true' &&
      await getBiometricLock() != null;

  /// Bản mã của mã bí mật đã được mã hoá bằng khoá vân tay trong Android Keystore,
  /// cùng hash của mã bí mật để kiểm tra sau khi giải mã. Không lưu mã bí mật gốc.
  Future<BiometricLockData?> getBiometricLock() async {
    final iv = await _storage.read(key: _keyBioIv);
    final ciphertext = await _storage.read(key: _keyBioCiphertext);
    final tokenHash = await _storage.read(key: _keyBioTokenHash);
    if (iv == null || ciphertext == null || tokenHash == null) return null;
    return (iv: iv, ciphertext: ciphertext, tokenHash: tokenHash);
  }

  Future<void> saveBiometricLock(BiometricLockData lock) async {
    await _storage.write(key: _keyBioIv, value: lock.iv);
    await _storage.write(key: _keyBioCiphertext, value: lock.ciphertext);
    await _storage.write(key: _keyBioTokenHash, value: lock.tokenHash);
    await _storage.write(key: _keyBiometricEnabled, value: 'true');
  }

  Future<void> clearBiometricLock() async {
    await _storage.delete(key: _keyBioIv);
    await _storage.delete(key: _keyBioCiphertext);
    await _storage.delete(key: _keyBioTokenHash);
    await _storage.write(key: _keyBiometricEnabled, value: 'false');
  }

  /// Vector đặc trưng khuôn mặt (512 số) đã đăng ký; null nếu chưa đăng ký.
  /// Chỉ lưu vector, không lưu ảnh khuôn mặt.
  Future<List<double>?> getFaceEmbedding() async {
    for (final key in _legacyFaceKeys) {
      if (await _storage.containsKey(key: key)) await _storage.delete(key: key);
    }
    final json = await _storage.read(key: _keyFaceEmbedding);
    if (json == null) return null;
    return (jsonDecode(json) as List)
        .map((e) => (e as num).toDouble())
        .toList();
  }

  Future<void> saveFaceEmbedding(List<double> embedding) =>
      _storage.write(key: _keyFaceEmbedding, value: jsonEncode(embedding));

  Future<void> deleteFaceEmbedding() => _storage.delete(key: _keyFaceEmbedding);

  /// Mức an toàn khi so khớp khuôn mặt (chưa chọn thì dùng mặc định).
  Future<FaceSecurityLevel> getFaceSecurityLevel() async =>
      FaceSecurityLevel.fromName(
        await _storage.read(key: _keyFaceSecurityLevel),
      );

  Future<void> saveFaceSecurityLevel(FaceSecurityLevel level) =>
      _storage.write(key: _keyFaceSecurityLevel, value: level.name);

  /// Xoá mọi dữ liệu trên máy (hồ sơ, khoá vân tay, khuôn mặt) – dùng khi đăng xuất tài khoản.
  Future<void> clearAll() => _storage.deleteAll();
}
