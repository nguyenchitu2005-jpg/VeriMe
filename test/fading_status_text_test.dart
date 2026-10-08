import 'package:faceid/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Câu hướng dẫn trên màn quét khuôn mặt nhấp nháy qua lại rất nhanh (A → B → A → B
/// trong lúc hiệu ứng 200ms chưa xong). Bản cũ dùng chính nội dung làm khoá của
/// AnimatedSwitcher → 2 câu A cùng đang mờ dần → "Duplicate keys found", rồi
/// "'_dependents.isEmpty': is not true" (màn hình đỏ) – lỗi đã gặp trên điện thoại thật.
void main() {
  testWidgets('FadingStatusText đổi chữ nhanh qua lại không lỗi', (
    tester,
  ) async {
    for (final text in ['A', 'B', 'A', 'B']) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FadingStatusText(text))),
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });
}
