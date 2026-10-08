import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Hiện khi Firebase chưa được cấu hình (thiếu android/app/google-services.json).
class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, this.error});

  final String? error;

  static const _steps = [
    'Vào console.firebase.google.com → tạo dự án.',
    'Thêm ứng dụng Android với package name: com.example.faceid.',
    'Tải file google-services.json, chép vào thư mục android/app/.',
    'Authentication → Sign-in method: bật Email/Password.',
    'Firestore Database → Create database, rồi dán file firestore.rules vào tab Rules.',
    'Chạy lại: flutter clean, rồi flutter run.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthLayout(
      title: 'Cần cấu hình Firebase',
      subtitle: 'Ứng dụng dùng Firebase để quản lý tài khoản và gửi email',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBanner(
            icon: Icons.cloud_off_rounded,
            color: AppTheme.brandLight,
            message: 'Chưa tìm thấy cấu hình Firebase (android/app/google-services.json).',
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_steps[i], style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Chi tiết lỗi: $error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
