import 'package:faceid/main.dart';
import 'package:faceid/screens/firebase_setup_screen.dart';
import 'package:faceid/screens/login_screen.dart';
import 'package:faceid/services/storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('Máy chưa có tài khoản thì hiện màn Đăng ký', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(FaceIdApp(services: makeServices()));
    await tester.pumpAndSettle();
    expect(find.text('Tạo tài khoản'), findsOneWidget);
  });

  testWidgets('Máy đã có hồ sơ thì hiện màn Đăng nhập', (tester) async {
    FlutterSecureStorage.setMockInitialValues({...fakeProfile});
    await tester.pumpWidget(FaceIdApp(services: makeServices()));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Chưa cấu hình Firebase thì hiện hướng dẫn', (tester) async {
    await tester.pumpWidget(const FirebaseSetupApp(error: 'no-app'));
    await tester.pumpAndSettle();
    expect(find.byType(FirebaseSetupScreen), findsOneWidget);
    expect(find.text('Cần cấu hình Firebase'), findsOneWidget);
  });

  test('Lưu hồ sơ: không lưu mật khẩu, xoá hash mật khẩu của bản cũ', () async {
    FlutterSecureStorage.setMockInitialValues({
      'username': 'alice',
      'password_salt': 'salt',
      'password_hash': 'hash',
    });
    final storage = StorageService();
    expect(await storage.getProfile(), isNull); // bản cũ chưa có email

    await storage.saveProfile((username: 'alice', email: 'alice@example.com'));

    final profile = (await storage.getProfile())!;
    expect(profile.email, 'alice@example.com');
    final raw = await const FlutterSecureStorage().readAll();
    expect(raw.keys, isNot(contains('password_hash')));
    expect(raw.keys, isNot(contains('password_salt')));
  });

  test('clearAll xoá hồ sơ, khoá vân tay và khuôn mặt', () async {
    FlutterSecureStorage.setMockInitialValues({
      ...fakeProfile,
      ...fakeBiometricLock,
      'face_embedding_v3': '[0.6, 0.8]',
    });
    final storage = StorageService();
    await storage.clearAll();
    expect(await storage.getProfile(), isNull);
    expect(await storage.isBiometricEnabled(), isFalse);
    expect(await storage.getFaceEmbedding(), isNull);
  });

  test('Lưu, đọc và xoá vector khuôn mặt', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = StorageService();

    expect(await storage.getFaceEmbedding(), isNull);
    await storage.saveFaceEmbedding([0.25, -0.5, 1]);
    expect(await storage.getFaceEmbedding(), [0.25, -0.5, 1.0]);
    await storage.deleteFaceEmbedding();
    expect(await storage.getFaceEmbedding(), isNull);
  });

  test('Vector khuôn mặt bản cũ (chưa căn thẳng / MobileFaceNet) bị bỏ, cần đăng ký lại', () async {
    FlutterSecureStorage.setMockInitialValues({
      'face_embedding': '[0.6, 0.8]',
      'face_embedding_v2': '[0.6, 0.8]',
    });
    final storage = StorageService();

    expect(await storage.getFaceEmbedding(), isNull);
    final raw = await const FlutterSecureStorage().readAll();
    expect(raw.containsKey('face_embedding'), isFalse);
    expect(raw.containsKey('face_embedding_v2'), isFalse);
  });
}
