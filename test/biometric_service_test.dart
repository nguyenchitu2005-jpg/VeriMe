import 'package:faceid/services/biometric_service.dart';
import 'package:faceid/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Giả lập phần native `BiometricLock.java` qua MethodChannel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('faceid/biometric_lock');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late StorageService storage;
  late BiometricService biometric;
  late List<MethodCall> calls;

  /// Đặt phản hồi của phần native cho từng phương thức.
  void native(Map<String, Object? Function(MethodCall)> handlers) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final handler = handlers[call.method];
      if (handler == null) return null;
      return handler(call);
    });
  }

  PlatformException error(String code) => PlatformException(code: code);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = StorageService();
    biometric = BiometricService();
    calls = [];
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Bật: lưu IV + bản mã + hash của mã bí mật, không lưu mã gốc', () async {
    native({
      'enable': (_) => {'token': 'secret', 'iv': 'IV', 'ciphertext': 'CT'},
    });

    final result = await biometric.enable(storage);

    expect(result.success, isTrue);
    expect(await storage.isBiometricEnabled(), isTrue);
    final lock = (await storage.getBiometricLock())!;
    expect(lock.iv, 'IV');
    expect(lock.ciphertext, 'CT');
    expect(lock.tokenHash, isNot('secret'));
    final raw = await const FlutterSecureStorage().readAll();
    expect(raw.values, isNot(contains('secret')));
  });

  test('Mở khoá: gửi đúng IV/bản mã và chấp nhận khi mã bí mật khớp', () async {
    native({
      'enable': (_) => {'token': 'secret', 'iv': 'IV', 'ciphertext': 'CT'},
      'unlock': (_) => 'secret',
    });
    await biometric.enable(storage);

    final result = await biometric.unlock(storage);

    expect(result.success, isTrue);
    final unlockCall = calls.last;
    expect(unlockCall.arguments['iv'], 'IV');
    expect(unlockCall.arguments['ciphertext'], 'CT');
  });

  test('Mở khoá: mã bí mật giải ra không khớp thì từ chối', () async {
    native({
      'enable': (_) => {'token': 'secret', 'iv': 'IV', 'ciphertext': 'CT'},
      'unlock': (_) => 'other',
    });
    await biometric.enable(storage);

    final result = await biometric.unlock(storage);

    expect(result.success, isFalse);
  });

  test('Có vân tay mới trên máy: khoá bị huỷ, tự tắt và báo lý do', () async {
    native({
      'enable': (_) => {'token': 'secret', 'iv': 'IV', 'ciphertext': 'CT'},
      'unlock': (_) => throw error('KEY_INVALIDATED'),
    });
    await biometric.enable(storage);

    final result = await biometric.unlock(storage);

    expect(result.success, isFalse);
    expect(result.message, contains('đã thay đổi'));
    expect(await storage.isBiometricEnabled(), isFalse);
    expect(await storage.getBiometricLock(), isNull);
  });

  test('Người dùng bấm Huỷ: không báo lỗi, vẫn giữ khoá', () async {
    native({
      'enable': (_) => {'token': 'secret', 'iv': 'IV', 'ciphertext': 'CT'},
      'unlock': (_) => throw error('CANCELED'),
    });
    await biometric.enable(storage);

    final result = await biometric.unlock(storage);

    expect(result.success, isFalse);
    expect(result.message, isNull);
    expect(await storage.isBiometricEnabled(), isTrue);
  });

  test('Bật thất bại (huỷ) thì không lưu gì', () async {
    native({'enable': (_) => throw error('CANCELED')});

    final result = await biometric.enable(storage);

    expect(result.success, isFalse);
    expect(await storage.isBiometricEnabled(), isFalse);
  });

  test('checkLock khi mở Trang chủ phát hiện vân tay đã thay đổi', () async {
    native({
      'enable': (_) => {'token': 'secret', 'iv': 'IV', 'ciphertext': 'CT'},
      'keyState': (_) => 'invalidated',
    });
    await biometric.enable(storage);

    expect(await biometric.checkLock(storage), BiometricLockState.invalidated);
    expect(await storage.isBiometricEnabled(), isFalse);
    expect(await biometric.checkLock(storage), BiometricLockState.notEnabled);
  });

  test('checkLock giữ nguyên khi khoá còn hợp lệ', () async {
    native({
      'enable': (_) => {'token': 'secret', 'iv': 'IV', 'ciphertext': 'CT'},
      'keyState': (_) => 'valid',
    });
    await biometric.enable(storage);

    expect(await biometric.checkLock(storage), BiometricLockState.valid);
    expect(await storage.isBiometricEnabled(), isTrue);
  });

  test('Tắt: xoá khoá trong Keystore và dữ liệu đã lưu', () async {
    native({
      'enable': (_) => {'token': 'secret', 'iv': 'IV', 'ciphertext': 'CT'},
    });
    await biometric.enable(storage);

    await biometric.disable(storage);

    expect(calls.last.method, 'disable');
    expect(await storage.isBiometricEnabled(), isFalse);
  });

  test(
    'Bản cũ chỉ có cờ biometric_enabled (không có khoá) coi như chưa bật',
    () async {
      FlutterSecureStorage.setMockInitialValues({'biometric_enabled': 'true'});

      expect(await StorageService().isBiometricEnabled(), isFalse);
    },
  );
}
