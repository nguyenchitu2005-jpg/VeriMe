import 'package:faceid/face/face_math.dart';
import 'package:faceid/screens/face_scan_screen.dart';
import 'package:faceid/screens/forgot_password_screen.dart';
import 'package:faceid/screens/home_screen.dart';
import 'package:faceid/screens/login_screen.dart';
import 'package:faceid/screens/register_screen.dart';
import 'package:faceid/services/auth_service.dart';
import 'package:faceid/services/biometric_service.dart';
import 'package:faceid/services/storage_service.dart';
import 'package:faceid/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Finder field(int i) => find.byType(TextFormField).at(i);

/// Máy đã đăng nhập "alice", bật vân tay và đã đăng ký khuôn mặt.
void seedSignedInDevice(FakeAuthService auth) {
  FlutterSecureStorage.setMockInitialValues({
    ...fakeProfile,
    ...fakeBiometricLock,
    'face_embedding_v3': '[0.6, 0.8]',
  });
  auth.seed(
    username: 'alice',
    email: 'alice@example.com',
    password: 'secret123',
    signedIn: true,
  );
}

void main() {
  for (final brightness in Brightness.values) {
    group('${brightness.name}:', () {
      testWidgets('Đăng ký có ô email, không bị tràn', (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        await pumpScreen(
          tester,
          RegisterScreen(services: makeServices()),
          brightness: brightness,
        );
        expect(find.text('Tạo tài khoản'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(4));
      });

      testWidgets('Đăng nhập: nút vân tay nằm cạnh ô mật khẩu', (tester) async {
        final auth = FakeAuthService();
        seedSignedInDevice(auth);
        await pumpScreen(
          tester,
          LoginScreen(services: makeServices(auth: auth)),
          brightness: brightness,
        );
        expect(find.text('alice'), findsOneWidget);
        expect(find.text('Đăng nhập bằng khuôn mặt'), findsOneWidget);
        expect(find.textContaining('SMS'), findsNothing);

        final password = tester.getRect(find.byType(PasswordField));
        final fingerprint = tester.getRect(find.byType(FingerprintButton));
        expect(fingerprint.left, greaterThan(password.right)); // bên phải ô
        expect(fingerprint.top, closeTo(password.top, 1)); // cùng hàng
        expect(fingerprint.height, closeTo(password.height, 1)); // cao bằng ô
      });

      testWidgets('Trang chủ: tài khoản, phương thức đăng nhập', (
        tester,
      ) async {
        final auth = FakeAuthService();
        seedSignedInDevice(auth);
        await pumpScreen(
          tester,
          HomeScreen(
            services: makeServices(auth: auth),
            username: 'alice',
          ),
          brightness: brightness,
        );
        expect(find.text('alice@example.com'), findsOneWidget);
        expect(find.text('Chưa xác minh'), findsOneWidget); // email
        expect(find.text('Đã đăng ký'), findsOneWidget); // khuôn mặt
        expect(find.text('Đã bật 2 cách đăng nhập nhanh'), findsOneWidget);
      });
    });
  }

  testWidgets('Lần đầu trên máy: nút vân tay/khuôn mặt vẫn hiện, bấm thì hướng '
      'dẫn đăng nhập bằng mật khẩu', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await pumpScreen(tester, LoginScreen(services: makeServices()));

    // Nút vân tay vẫn nằm cạnh ô mật khẩu.
    final password = tester.getRect(find.byType(PasswordField));
    final fingerprint = tester.getRect(find.byType(FingerprintButton));
    expect(fingerprint.left, greaterThan(password.right));
    expect(fingerprint.top, closeTo(password.top, 1));

    await tester.tap(find.byType(FingerprintButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('hãy đăng nhập bằng mật khẩu'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.ensureVisible(find.text('Đăng nhập bằng khuôn mặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng nhập bằng khuôn mặt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('hãy đăng nhập bằng mật khẩu'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets(
    'Đã đăng nhập nhưng chưa bật vân tay: bấm nút thì hướng dẫn bật',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({...fakeProfile});
      final auth = FakeAuthService()
        ..seed(
          username: 'alice',
          email: 'alice@example.com',
          password: 'secret123',
          signedIn: true,
        );
      await pumpScreen(tester, LoginScreen(services: makeServices(auth: auth)));

      await tester.tap(find.byType(FingerprintButton));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Chưa bật đăng nhập bằng vân tay'),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets('Bấm nút vân tay cạnh ô mật khẩu thì vào Trang chủ', (
    tester,
  ) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    // Lần tự bật khi mở màn hình: người dùng huỷ. Lần bấm nút vân tay: thành công.
    final services = makeServices(
      auth: auth,
      biometric: _ScriptedBiometricService([false, true]),
    );
    await pumpScreen(tester, LoginScreen(services: services));

    await tester.tap(find.byType(FingerprintButton));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Xin chào, alice'), findsOneWidget);
  });

  testWidgets('Gõ tài khoản khác ("huy") rồi bấm vân tay: báo sai tài khoản, '
      'không tự vào tài khoản trên máy', (tester) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth); // máy lưu vân tay/khuôn mặt của "alice"
    // Chỉ cho 1 lần mở khoá (lần tự bật khi mở màn hình, người dùng huỷ):
    // nếu app gọi mở khoá thêm lần nữa thì test lỗi.
    final services = makeServices(
      auth: auth,
      biometric: _ScriptedBiometricService([false]),
    );
    await pumpScreen(tester, LoginScreen(services: services));

    await tester.enterText(field(0), 'huy');
    await tester.pump();
    expect(
      tester.widget<FingerprintButton>(find.byType(FingerprintButton)).dimmed,
      isTrue,
    );

    await tester.tap(find.byType(FingerprintButton));
    await tester.pumpAndSettle();
    expect(find.text('Sai tài khoản'), findsOneWidget);
    expect(find.textContaining('không thuộc tài khoản "huy"'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    // Khuôn mặt cũng vậy: không mở camera.
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đăng nhập bằng khuôn mặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng nhập bằng khuôn mặt'));
    await tester.pumpAndSettle();
    expect(find.text('Sai tài khoản'), findsOneWidget);
    expect(find.byType(FaceScanScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Gõ email của tài khoản trên máy thì vân tay vẫn dùng được', (
    tester,
  ) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    final services = makeServices(
      auth: auth,
      biometric: _ScriptedBiometricService([false, true]),
    );
    await pumpScreen(tester, LoginScreen(services: services));

    await tester.enterText(field(0), 'Alice@Example.com');
    await tester.tap(find.byType(FingerprintButton));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào, alice'), findsOneWidget);
  });

  testWidgets('Đăng nhập bằng tên đăng nhập: tra email trên Firebase', (
    tester,
  ) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    await auth.signOut();
    await pumpScreen(tester, LoginScreen(services: makeServices(auth: auth)));

    // Tên chưa ai dùng → báo không có tài khoản, không gọi đăng nhập.
    await tester.enterText(field(0), 'bob');
    await tester.enterText(field(1), 'secret123');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Không có tài khoản nào tên "bob"'),
      findsOneWidget,
    );
    expect(auth.log, isNot(contains(startsWith('signIn'))));

    // Sai mật khẩu.
    await tester.enterText(field(0), 'alice');
    await tester.enterText(field(1), 'wrong');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Sai email/tên đăng nhập hoặc mật khẩu.'), findsOneWidget);

    // Đúng (viết hoa cũng được): tên "Alice" được đổi thành email của tài khoản.
    await tester.enterText(field(0), 'Alice');
    await tester.enterText(field(1), 'secret123');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(auth.log, contains('lookup alice'));
    expect(auth.log, contains('signIn alice@example.com'));
    expect(find.text('Xin chào, alice'), findsOneWidget);
  });

  testWidgets('Máy mới (chưa có hồ sơ): đăng nhập bằng tên đăng nhập được', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final auth = FakeAuthService()
      ..seed(username: 'bob', email: 'bob@example.com', password: 'bobpass1');
    final services = makeServices(auth: auth);
    await pumpScreen(tester, LoginScreen(services: services));

    await tester.enterText(field(0), 'bob');
    await tester.enterText(field(1), 'bobpass1');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(auth.log, contains('signIn bob@example.com'));
    expect(find.text('Xin chào, bob'), findsOneWidget);
    expect((await services.storage.getProfile())!.username, 'bob');
  });

  testWidgets('Không tra được tên trên Firebase: dùng hồ sơ trên máy', (
    tester,
  ) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    await auth.signOut();
    auth.lookupError = const AuthFailure('unavailable', 'Mất mạng.');
    await pumpScreen(tester, LoginScreen(services: makeServices(auth: auth)));

    // Tên lạ: không có trên máy → báo lỗi tra cứu.
    await tester.enterText(field(0), 'bob');
    await tester.enterText(field(1), 'secret123');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Mất mạng.'), findsOneWidget);

    // Tên trùng hồ sơ trên máy → vẫn đăng nhập được.
    await tester.enterText(field(0), 'alice');
    await tester.enterText(field(1), 'secret123');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào, alice'), findsOneWidget);
  });

  testWidgets('Đăng nhập tài khoản khác trên máy: xoá vân tay/khuôn mặt cũ', (
    tester,
  ) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    auth.seed(username: 'bob', email: 'bob@example.com', password: 'bobpass1');
    final services = makeServices(auth: auth);
    await pumpScreen(tester, LoginScreen(services: services));

    await tester.enterText(field(0), 'bob@example.com');
    await tester.enterText(field(1), 'bobpass1');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Xin chào, bob'), findsOneWidget);
    final storage = services.storage;
    expect((await storage.getProfile())!.email, 'bob@example.com');
    expect(await storage.isBiometricEnabled(), isFalse);
    expect(await storage.getFaceEmbedding(), isNull);
  });

  testWidgets('Đăng ký: tạo tài khoản, lưu hồ sơ rồi vào Trang chủ', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final auth = FakeAuthService();
    final services = makeServices(auth: auth);
    await pumpScreen(tester, RegisterScreen(services: services));

    await tester.enterText(field(0), 'carol');
    await tester.enterText(field(1), 'carol@example.com');
    await tester.enterText(field(2), 'secret123');
    await tester.enterText(field(3), 'secret123');
    await tester.ensureVisible(find.text('Đăng ký'));
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    expect(auth.log, ['register carol@example.com', 'verifyEmail']);
    expect(find.text('Xin chào, carol'), findsOneWidget);
    expect(find.textContaining('ca***@example.com'), findsOneWidget);
    // Vừa gửi email: phải đợi một lúc mới gửi lại được.
    expect(find.text('Đã gửi, đợi 1 phút'), findsOneWidget);
    final profile = (await services.storage.getProfile())!;
    expect(profile.username, 'carol');
    expect(profile.email, 'carol@example.com');
  });

  testWidgets('Đăng ký: tên đăng nhập đã có người dùng thì báo, không tạo', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final auth = FakeAuthService()
      ..seed(username: 'Carol', email: 'carol@other.com', password: 'xxxxxx');
    await pumpScreen(
      tester,
      RegisterScreen(services: makeServices(auth: auth)),
    );

    await tester.enterText(field(0), 'carol');
    await tester.enterText(field(1), 'carol@example.com');
    await tester.enterText(field(2), 'secret123');
    await tester.enterText(field(3), 'secret123');
    await tester.ensureVisible(find.text('Đăng ký'));
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    expect(find.textContaining('đã có người dùng'), findsOneWidget);
    expect(auth.log, isNot(contains('register carol@example.com')));
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets(
    'Đăng ký: gửi email xác minh lỗi vẫn vào Trang chủ, gửi lại được',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final auth = FakeAuthService()
        ..verificationError = const AuthFailure(
          'too-many-requests',
          'Firebase tạm chặn.',
        );
      final services = makeServices(auth: auth);
      await pumpScreen(tester, RegisterScreen(services: services));

      await tester.enterText(field(0), 'carol');
      await tester.enterText(field(1), 'carol@example.com');
      await tester.enterText(field(2), 'secret123');
      await tester.enterText(field(3), 'secret123');
      await tester.ensureVisible(find.text('Đăng ký'));
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Tài khoản vẫn được tạo, hồ sơ vẫn lưu, báo rõ là chưa gửi được email.
      expect(find.text('Xin chào, carol'), findsOneWidget);
      expect(
        find.textContaining('chưa gửi được email xác minh'),
        findsOneWidget,
      );
      expect((await services.storage.getProfile())!.email, 'carol@example.com');

      // Gửi lại thành công → nút tạm khoá 1 phút rồi mở lại.
      auth.verificationError = null;
      await tester.tap(find.text('Gửi lại email'));
      await tester.pumpAndSettle();
      expect(auth.log, contains('verifyEmail'));
      expect(find.text('Đã gửi, đợi 1 phút'), findsOneWidget);

      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text('Gửi lại email'), findsOneWidget);
    },
  );

  testWidgets('Quên mật khẩu qua email: gửi email đặt lại', (tester) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    await pumpScreen(
      tester,
      ForgotPasswordScreen(
        services: makeServices(auth: auth),
        initialEmail: 'alice@example.com',
      ),
    );

    await tester.tap(find.text('Gửi email đặt lại mật khẩu'));
    await tester.pumpAndSettle();

    expect(auth.log, contains('reset alice@example.com'));
    expect(find.textContaining('al***@example.com'), findsOneWidget);
  });

  testWidgets('Đổi mật khẩu: sai mật khẩu hiện tại thì báo, đúng thì đổi', (
    tester,
  ) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    await pumpScreen(
      tester,
      HomeScreen(
        services: makeServices(auth: auth),
        username: 'alice',
      ),
    );

    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();

    await tester.enterText(field(0), 'wrong');
    await tester.enterText(field(1), 'newpass99');
    await tester.enterText(field(2), 'newpass99');
    await tester.tap(find.text('Lưu mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('Sai mật khẩu hiện tại.'), findsOneWidget);
    expect(auth.passwordOf('alice@example.com'), 'secret123');

    await tester.enterText(field(0), 'secret123');
    await tester.tap(find.text('Lưu mật khẩu'));
    await tester.pumpAndSettle();
    expect(auth.passwordOf('alice@example.com'), 'newpass99');
    expect(find.text('Đã đổi mật khẩu'), findsOneWidget);
  });

  testWidgets('Đăng xuất: lần sau vẫn chọn được vân tay hoặc khuôn mặt', (
    tester,
  ) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    // Lần tự bật vân tay khi về màn đăng nhập: người dùng huỷ.
    final services = makeServices(
      auth: auth,
      biometric: _ScriptedBiometricService([false]),
    );
    await pumpScreen(tester, HomeScreen(services: services, username: 'alice'));

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await services.storage.isBiometricEnabled(), isTrue);
    expect(await services.storage.getFaceEmbedding(), isNotNull);
    // Nút vân tay sáng (dùng được).
    final button = tester.widget<FingerprintButton>(
      find.byType(FingerprintButton),
    );
    expect(button.dimmed, isFalse);
  });

  testWidgets('Xoá tài khoản khỏi máy: thoát Firebase, xoá dữ liệu trên máy', (
    tester,
  ) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    final cloud = FakeCloudDataService();
    final services = makeServices(auth: auth, cloud: cloud);
    await pumpScreen(tester, HomeScreen(services: services, username: 'alice'));

    // Kéo Trang chủ lên tới cuối để thấy nút.
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá tài khoản khỏi máy này'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xoá khỏi máy'));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    expect(await services.storage.getProfile(), isNull);
    expect(await services.storage.getFaceEmbedding(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    // Khuôn mặt trong tài khoản Firebase vẫn còn để dùng lại.
    expect(cloud.faces['alice@example.com'], isNotNull);
  });

  testWidgets('Chọn mức an toàn khuôn mặt thì lưu lại', (tester) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth);
    final services = makeServices(auth: auth);
    await pumpScreen(tester, HomeScreen(services: services, username: 'alice'));
    expect(
      await services.storage.getFaceSecurityLevel(),
      kDefaultFaceSecurityLevel,
    );

    await tester.dragUntilVisible(
      find.text('Rất cao'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rất cao'));
    await tester.pumpAndSettle();

    expect(
      await services.storage.getFaceSecurityLevel(),
      FaceSecurityLevel.veryHigh,
    );
    expect(find.textContaining('Mức an toàn: Rất cao'), findsOneWidget);
  });

  testWidgets('Khuôn mặt đăng ký trên máy cũ được đưa lên Firebase', (
    tester,
  ) async {
    final auth = FakeAuthService();
    seedSignedInDevice(auth); // máy có khuôn mặt [0.6, 0.8], Firebase chưa có
    final cloud = FakeCloudDataService();
    await pumpScreen(
      tester,
      HomeScreen(
        services: makeServices(auth: auth, cloud: cloud),
        username: 'alice',
      ),
    );
    expect(cloud.faces['alice@example.com'], [0.6, 0.8]);
  });

  testWidgets(
    'Máy mới: đăng nhập bằng mật khẩu thì tải khuôn mặt từ Firebase',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final auth = FakeAuthService()
        ..seed(username: 'bob', email: 'bob@example.com', password: 'bobpass1');
      final cloud = FakeCloudDataService()
        ..faces['bob@example.com'] = [0.6, 0.8];
      final services = makeServices(auth: auth, cloud: cloud);
      await pumpScreen(tester, LoginScreen(services: services));

      await tester.enterText(field(0), 'bob');
      await tester.enterText(field(1), 'bobpass1');
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Xin chào, bob'), findsOneWidget);
      expect(find.textContaining('Đã tải khuôn mặt'), findsOneWidget);
      expect(await services.storage.getFaceEmbedding(), [0.6, 0.8]);
    },
  );
}

/// Trả về kết quả mở khoá vân tay lần lượt theo danh sách cho trước.
class _ScriptedBiometricService extends FakeBiometricService {
  _ScriptedBiometricService(this._results);

  final List<bool> _results;
  int _call = 0;

  @override
  Future<BiometricResult> unlock(StorageService storage) async =>
      (success: _results[_call++], message: null);
}
