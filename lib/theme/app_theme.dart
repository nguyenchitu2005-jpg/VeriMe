import 'package:flutter/material.dart';

/// Theme dùng chung cho toàn app (Material 3, hỗ trợ sáng/tối).
/// Tông xanh navy – xanh dương, bo góc vừa phải, phong cách ứng dụng bảo mật/tài chính.
class AppTheme {
  AppTheme._();

  static const seedColor = Color(0xFF1D4ED8);

  /// Màu đầu và cuối của dải gradient thương hiệu (dùng cố định ở cả chế độ sáng/tối,
  /// để chữ trắng đặt trên gradient luôn đủ tương phản).
  static const brandDark = Color(0xFF0B1F4D);
  static const brandLight = Color(0xFF1D4ED8);

  static const success = Color(0xFF15803D);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      // fidelity: giữ đúng sắc xanh thương hiệu thay vì làm nhạt như mặc định.
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      surface: isDark ? const Color(0xFF0E1525) : const Color(0xFFF4F6FB),
    );
    final cardColor = isDark ? const Color(0xFF161F33) : Colors.white;
    final radius = BorderRadius.circular(12);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    final buttonShape = RoundedRectangleBorder(borderRadius: radius);
    // Lấy kiểu chữ từ textTheme mặc định để nút/chip dùng cùng font với phần còn lại.
    final textTheme = ThemeData(colorScheme: scheme).textTheme;
    final buttonText = textTheme.labelLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardColor: cardColor,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        fillColor: isDark ? const Color(0xFF1C2740) : const Color(0xFFF1F4F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border(scheme.outlineVariant),
        enabledBorder: border(
          isDark ? const Color(0xFF2A3858) : const Color(0xFFDCE2EC),
        ),
        focusedBorder: border(scheme.primary, 2),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 2),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: buttonShape,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF243150) : const Color(0xFFE3E8F0),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: isDark ? const Color(0xFF243150) : const Color(0xFFE9EDF3),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        backgroundColor: scheme.secondaryContainer,
        labelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

/// Màu chính của gradient thương hiệu (dùng cho bóng đổ).
const Color brandColor = AppTheme.brandLight;

/// Dải màu chuyển dùng cho banner và biểu tượng thương hiệu.
LinearGradient brandGradient() => const LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppTheme.brandDark, AppTheme.brandLight],
);
