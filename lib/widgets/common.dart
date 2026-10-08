import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Tên hiển thị của ứng dụng (banner, danh sách ứng dụng gần đây). Tên dưới icon ngoài
/// màn hình chính nằm ở `android:label` trong AndroidManifest.xml – đổi thì sửa cả 2.
const kAppName = 'VeriMe';

/// Biểu tượng thương hiệu: ô vuông bo góc nền trắng mờ, hình khiên.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Icon(
        Icons.shield_outlined,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}

/// Banner gradient đầu trang: logo + tên app, rồi tiêu đề và mô tả.
class BrandBanner extends StatelessWidget {
  const BrandBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.bottomPadding = 56,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Có giá trị thì hiện nút quay lại ở đầu banner.
  final VoidCallback? onBack;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 20,
        16,
        bottomPadding,
      ),
      decoration: BoxDecoration(
        gradient: brandGradient(),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const BrandLogo(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  kAppName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bố cục màn hình đăng nhập/đăng ký: banner gradient, thẻ form nổi đè lên banner, chú thích cuối trang.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  /// Hiện nút quay lại trên banner (cho các màn hình con như Quên mật khẩu).
  final bool showBack;

  static const _overlap = 36.0;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: Column(
            children: [
              BrandBanner(
                title: title,
                subtitle: subtitle,
                bottomPadding: _overlap + 24,
                onBack: showBack
                    ? () => Navigator.of(context).maybePop()
                    : null,
              ),
              Transform.translate(
                offset: const Offset(0, -_overlap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Card(
                        elevation: 6,
                        shadowColor: brandColor.withValues(alpha: 0.18),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhãn nhỏ phía trên ô nhập.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Ô nhập mật khẩu có nút ẩn/hiện.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        hintText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
    );
  }
}

/// Nút vuông có biểu tượng vân tay, đặt cạnh ô mật khẩu (cao bằng ô nhập).
class FingerprintButton extends StatelessWidget {
  const FingerprintButton({
    super.key,
    required this.onPressed,
    this.dimmed = false,
  });

  final VoidCallback? onPressed;

  /// Chưa dùng được trên máy này (chưa bật vân tay): vẫn bấm được để xem hướng dẫn,
  /// nhưng tô màu nhạt.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 56,
      child: Tooltip(
        message: 'Đăng nhập bằng vân tay',
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(56),
            backgroundColor: dimmed
                ? scheme.surfaceContainerHighest
                : scheme.primaryContainer,
            foregroundColor: dimmed
                ? scheme.onSurfaceVariant
                : scheme.onPrimaryContainer,
          ),
          child: const Icon(Icons.fingerprint_rounded, size: 30),
        ),
      ),
    );
  }
}

/// Dòng chữ trạng thái, đổi chữ có hiệu ứng mờ dần.
///
/// Mỗi lần đổi chữ dùng một khoá mới (số đếm tăng dần) thay vì lấy chính nội dung làm
/// khoá: khi quét khuôn mặt, câu hướng dẫn có thể đổi qua lại rất nhanh (A → B → A trong
/// lúc hiệu ứng chưa xong); dùng nội dung làm khoá sẽ có 2 con trùng khoá trong
/// AnimatedSwitcher ("Duplicate keys found") và làm hỏng cả màn hình.
class FadingStatusText extends StatefulWidget {
  const FadingStatusText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<FadingStatusText> createState() => _FadingStatusTextState();
}

class _FadingStatusTextState extends State<FadingStatusText> {
  int _version = 0;

  @override
  void didUpdateWidget(FadingStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _version++;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        widget.text,
        key: ValueKey(_version),
        textAlign: widget.textAlign,
        style: widget.style,
      ),
    );
  }
}

/// Biểu tượng nằm trong ô vuông bo góc tô màu nhạt.
class IconCircle extends StatelessWidget {
  const IconCircle({super.key, required this.icon, this.size = 40, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: c, size: size * 0.55),
    );
  }
}

/// Tiêu đề nhỏ cho từng nhóm nội dung.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Nhãn trạng thái nhỏ (ví dụ "Đã đăng ký").
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? AppTheme.success : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Dòng "câu hỏi + liên kết", ví dụ "Chưa có tài khoản? Đăng ký".
class FooterLink extends StatelessWidget {
  const FooterLink({
    super.key,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wrap: thiếu chỗ (màn hẹp, cỡ chữ lớn) thì liên kết tự xuống dòng thay vì tràn.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}

/// Hộp thông báo nhỏ có biểu tượng (thành công / thông tin / cảnh báo).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  final String message;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Nút chính có vòng xoay khi đang xử lý.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(label),
    );
  }
}
