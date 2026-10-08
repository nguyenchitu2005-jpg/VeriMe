import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/firebase_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/app_services.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/cloud_data_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khoá màn hình dọc để khung camera và hướng ảnh gửi cho ML Kit luôn ổn định.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Firebase đọc cấu hình từ android/app/google-services.json (xem README).
  // Chưa có file đó thì hiện màn hướng dẫn thay vì crash.
  AuthService? auth;
  String? firebaseError;
  try {
    await Firebase.initializeApp();
    // Email xác minh / đặt lại mật khẩu do Firebase gửi sẽ viết bằng tiếng Việt.
    await FirebaseAuth.instance.setLanguageCode('vi');
    auth = FirebaseAuthService();
  } catch (e) {
    firebaseError = '$e';
  }

  runApp(
    auth == null
        ? FirebaseSetupApp(error: firebaseError)
        : FaceIdApp(
            services: AppServices(
              storage: StorageService(),
              biometric: BiometricService(),
              auth: auth,
              cloud: FirestoreCloudDataService(),
            ),
          ),
  );
}

class FaceIdApp extends StatelessWidget {
  const FaceIdApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: FutureBuilder<AccountProfile?>(
        future: services.storage.getProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Máy đã từng đăng nhập (có hồ sơ) hoặc còn phiên Firebase → Đăng nhập; chưa → Đăng ký.
          final known = snapshot.data != null || services.auth.isSignedIn;
          return known
              ? LoginScreen(services: services)
              : RegisterScreen(services: services);
        },
      ),
    );
  }
}

/// App tối giản hiển thị hướng dẫn khi Firebase chưa được cấu hình.
class FirebaseSetupApp extends StatelessWidget {
  const FirebaseSetupApp({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: FirebaseSetupScreen(error: error),
    );
  }
}
