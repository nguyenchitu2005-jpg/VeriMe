import 'package:faceid/services/auth_service.dart';
import 'package:faceid/services/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isValidEmail', () {
    expect(isValidEmail('alice@example.com'), isTrue);
    expect(isValidEmail(' alice@gmail.com '), isTrue);
    expect(isValidEmail('alice@'), isFalse);
    expect(isValidEmail('alice.example.com'), isFalse);
    expect(isValidEmail('a b@x.com'), isFalse);
  });

  test('maskEmail che bớt phần tên', () {
    expect(maskEmail('alice.nguyen@gmail.com'), 'al***@gmail.com');
    expect(maskEmail('ab@x.vn'), 'a***@x.vn');
  });

  test('validateUsername / normalizeUsername', () {
    expect(validateUsername('chitu'), isNull);
    expect(validateUsername(' Chi.Tu_2005-x '), isNull);
    expect(validateUsername('ab'), isNotNull);
    expect(validateUsername('a' * 31), isNotNull);
    expect(validateUsername('chí tú'), isNotNull); // dấu, khoảng trắng
    expect(validateUsername('a@b'), isNotNull);
    expect(validateUsername('a/b'), isNotNull);
    expect(validateUsername('__x__'), isNotNull); // tên Firestore dành riêng
    expect(normalizeUsername('  ChiTu '), 'chitu');
  });

  test('Thông báo lỗi Firestore bằng tiếng Việt', () {
    expect(
      FirebaseAuthService.firestoreMessageFor('permission-denied'),
      contains('firestore.rules'),
    );
    expect(
      FirebaseAuthService.firestoreMessageFor('not-found'),
      contains('Create database'),
    );
    // Chưa tạo Firestore: máy chủ trả permission-denied nhưng phải báo "Create database".
    expect(
      FirebaseAuthService.firestoreMessageFor(
        'permission-denied',
        'Cloud Firestore API has not been used in project x before or it is disabled.',
      ),
      contains('Create database'),
    );
  });

  test('Thông báo lỗi Firebase bằng tiếng Việt', () {
    expect(
      FirebaseAuthService.messageFor('wrong-password'),
      'Sai email/tên đăng nhập hoặc mật khẩu.',
    );
    expect(
      FirebaseAuthService.messageFor('email-already-in-use'),
      'Email này đã được dùng cho tài khoản khác.',
    );
    expect(FirebaseAuthService.messageFor('xyz'), contains('xyz'));
  });
}
