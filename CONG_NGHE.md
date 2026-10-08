# Công nghệ và thư viện sử dụng – VeriMe

Ứng dụng **VeriMe** (project `faceid`, package `com.example.faceid`): đăng ký/đăng nhập tài khoản bằng email, tên đăng nhập
và mật khẩu; đăng nhập nhanh bằng **vân tay** hoặc **khuôn mặt** (camera). Viết bằng **Flutter/Dart**, chạy trên **Android**.

> Phiên bản trong file này lấy từ `pubspec.lock`, các file Gradle và lệnh `flutter --version` của project.
> Hướng dẫn cài đặt và cách hoạt động chi tiết: xem [README.md](README.md).

---

## 1. Tổng quan

| Nhóm | Công nghệ chính |
|---|---|
| Ngôn ngữ, framework | Dart 3.13.3, Flutter 3.47.3 (Material 3); Java (mã Android tự viết) |
| Nền tảng | Android 7.0 trở lên (minSdk 24), build với SDK 36 |
| Tài khoản, máy chủ | Firebase Authentication, Cloud Firestore |
| Vân tay | Android BiometricPrompt + khoá trong Android Keystore (AES-256-GCM) |
| Nhận diện khuôn mặt | Camera (CameraX) + Google ML Kit Face Detection + TensorFlow Lite (model FaceNet-512) |
| Lưu dữ liệu trên máy | flutter_secure_storage (mã hoá bằng Android Keystore) |
| Kiểm thử | flutter_test (70 test), flutter_lints |
| Công cụ phụ trợ | flutter_launcher_icons; Python 3.12 + TensorFlow 2.21 + scikit-learn + Pillow |

```
┌──────────────────────── Ứng dụng Flutter (Dart) ────────────────────────┐
│  Giao diện Material 3 (sáng/tối)  ─  screens/ · widgets/ · theme/        │
│  Dịch vụ: AuthService · CloudDataService · BiometricService ·            │
│           StorageService · FaceRecognitionService                        │
└──────┬──────────────┬────────────────┬───────────────┬──────────────────┘
       │              │                │               │
 Firebase Auth   Cloud Firestore   MethodChannel     camera + ML Kit + TFLite
 (tài khoản,     (tên đăng nhập,   "faceid/          (quét mặt, nháy mắt,
  email)          vector mặt)       biometric_lock")   vector 512 chiều)
                                       │
                          Java: BiometricLock (BiometricPrompt + Keystore)
```

---

## 2. Môi trường phát triển

| Thành phần | Phiên bản / ghi chú |
|---|---|
| Flutter SDK | 3.47.3 (stable), Dart 3.13.3, DevTools 2.60.0 |
| Android Studio | Dùng JDK đi kèm (JBR) để build và lấy SHA-1 (`keytool`) |
| Gradle | 9.3.1 |
| Android Gradle Plugin | 9.1.0 |
| Kotlin Gradle Plugin | 2.4.0 (cho các plugin viết bằng Kotlin; mã app tự viết bằng Java) |
| Java | 17 (`sourceCompatibility`, `jvmTarget`) |
| Android SDK | compileSdk 36, targetSdk 36, minSdk 24 |
| Hệ điều hành máy phát triển | Windows 11 |
| Thiết bị thử nghiệm | OPPO CPH2797, Android 16 (API 36) |
| Trình soạn thảo | Visual Studio Code / Android Studio |

---

## 3. Thư viện Flutter (pub.dev)

### 3.1. Dùng trong ứng dụng

| Thư viện | Phiên bản | Dùng để làm gì |
|---|---|---|
| [`firebase_core`](https://pub.dev/packages/firebase_core) | 4.15.0 | Khởi tạo Firebase (đọc `google-services.json`) |
| [`firebase_auth`](https://pub.dev/packages/firebase_auth) | 6.7.0 | Đăng ký, đăng nhập email + mật khẩu, email xác minh, email đặt lại mật khẩu, đổi mật khẩu |
| [`cloud_firestore`](https://pub.dev/packages/cloud_firestore) | 6.10.0 | Bảng **tên đăng nhập → email** (đăng nhập bằng tên trên mọi máy) và lưu **vector khuôn mặt** để dùng trên máy khác |
| [`local_auth`](https://pub.dev/packages/local_auth) | 3.0.2 (Android: `local_auth_android` 2.2.0) | Liệt kê loại sinh trắc học máy hỗ trợ (vân tay, khuôn mặt, mạnh/yếu) |
| [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) | 11.2.0 | Lưu hồ sơ, khoá vân tay đã mã hoá, vector khuôn mặt, mức an toàn – mã hoá AES-GCM, khoá được bọc bằng khoá RSA trong Android Keystore |
| [`crypto`](https://pub.dev/packages/crypto) | 3.0.7 | Băm SHA-256 mã bí mật của khoá vân tay (chỉ lưu bản băm, không lưu mã gốc) |
| [`camera`](https://pub.dev/packages/camera) | 0.12.1 (Android: `camera_android_camerax` 0.7.5+1 – CameraX) | Mở camera trước, lấy luồng hình NV21 để kiểm tra nháy mắt, chụp ảnh để nhận diện |
| [`google_mlkit_face_detection`](https://pub.dev/packages/google_mlkit_face_detection) | 0.15.1 (`google_mlkit_commons` 0.13.0) | **Phát hiện** khuôn mặt trên máy (không cần mạng): khung mặt, vị trí 2 mắt, xác suất mắt mở, góc quay đầu |
| [`tflite_flutter`](https://pub.dev/packages/tflite_flutter) | 0.12.1 | Chạy model **TensorFlow Lite** FaceNet-512 trên máy (4 luồng CPU) để **nhận diện** khuôn mặt |
| [`image`](https://pub.dev/packages/image) | 4.10.1 | Giải mã JPEG, xoay ảnh theo EXIF, thu nhỏ, xoay căn thẳng 2 mắt, cắt khuôn mặt (chạy trong Isolate) |
| [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) | 1.0.9 | Bộ icon mặc định của project Flutter |

### 3.2. Dùng khi phát triển

| Thư viện | Phiên bản | Dùng để làm gì |
|---|---|---|
| `flutter_test` (SDK) | theo Flutter 3.47.3 | Unit test và widget test |
| [`flutter_lints`](https://pub.dev/packages/flutter_lints) | 6.0.0 | Bộ luật kiểm tra code cho `flutter analyze` |
| [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) | 0.14.4 | Tạo icon Android (icon thường, icon thích ứng, icon đơn sắc) từ ảnh trong `assets/icon/` |

---

## 4. Thư viện và thành phần Android (native)

| Thành phần | Phiên bản | Dùng để làm gì |
|---|---|---|
| `androidx.biometric:biometric` | 1.1.0 | `BiometricPrompt` + `CryptoObject` cho khoá vân tay (file `BiometricLock.java`) |
| `androidx.appcompat:appcompat` | 1.7.0 | Theme AppCompat cho hộp thoại sinh trắc học |
| Google Services Gradle plugin | 4.4.4 | Đọc `google-services.json` để kết nối Firebase (chỉ bật khi có file) |
| Android Keystore | hệ thống | Khoá AES-256-GCM chỉ mở được bằng vân tay; **tự huỷ khi vân tay trên máy thay đổi** |
| `FlutterFragmentActivity` | Flutter | Activity bắt buộc để hiện `BiometricPrompt` |
| MethodChannel `faceid/biometric_lock` | Flutter | Cầu nối Dart ↔ Java: `status`, `keyState`, `enable`, `unlock`, `disable` |

---

## 5. Dịch vụ đám mây – Firebase (gói Spark miễn phí)

| Dịch vụ | Dùng để làm gì |
|---|---|
| **Firebase Authentication** (Email/Password) | Lưu tài khoản và mật khẩu (băm scrypt trên máy chủ); gửi **email xác minh** và **email đặt lại mật khẩu** (tiếng Việt); đổi mật khẩu có xác thực lại |
| **Cloud Firestore** | `usernames/{tên}` → `{uid, email, username, createdAt}`: đăng nhập bằng tên đăng nhập, chặn tên trùng. `users/{uid}` → `{faceEmbedding, faceUpdatedAt}`: sao lưu vector khuôn mặt (512 số, không phải ảnh) để dùng trên máy khác |
| **Firestore Security Rules** ([firestore.rules](firestore.rules)) | Ai cũng tra được 1 tên đăng nhập nhưng không liệt kê được cả bảng; chỉ chủ tài khoản tạo/xoá tên của mình; chỉ chủ tài khoản đọc/ghi vector khuôn mặt của mình |

---

## 6. Trí tuệ nhân tạo và xử lý ảnh (nhận diện khuôn mặt)

| Bước | Công nghệ |
|---|---|
| Lấy hình | `camera` (CameraX), camera trước, luồng NV21 độ phân giải trung bình |
| Kiểm tra người thật | ML Kit (chế độ nhanh) trên từng khung hình + **máy trạng thái nháy mắt** (mắt mở → nhắm → mở lại); chặn ảnh tĩnh |
| Chụp và xoay đúng chiều | `takePicture`; gói `image` xoay theo EXIF, thu nhỏ ≤ 1024px (trong Isolate) |
| Phát hiện khuôn mặt | ML Kit (chế độ chính xác): khung mặt, vị trí 2 mắt, mắt mở, góc đầu; loại ảnh quay đầu > 15°, nhắm mắt, mặt quá nhỏ |
| Căn thẳng và cắt | Xoay để 2 mắt nằm ngang, cắt vùng vuông 1,3 × khung mặt, đổi về 160×160 |
| Tạo vector | **TensorFlow Lite – FaceNet-512** (Inception-ResNet-v1 huấn luyện trên VGGFace2): chuẩn hoá theo từng ảnh → vector 512 chiều, chuẩn hoá L2 |
| So khớp | Khoảng cách Euclid. Mẫu đăng ký = trung bình 5 ảnh; đăng nhập chụp 2 ảnh, lấy ảnh khớp nhất. **Mức an toàn**: Cơ bản 0,75 / Cao 0,65 (mặc định) / Rất cao 0,55; sai 3 lần thì phải dùng mật khẩu |

**Đánh giá model** trên bộ ảnh công khai **LFW** (217 người, 4.822 ảnh), mô phỏng đúng quy trình của app, có thử với "người giống nhất":

| Model | Chính chủ được nhận khi người giống nhất chỉ lọt 0,3% |
|---|---|
| MobileFaceNet (bản đầu, 5 MB, 192 chiều) | 69,7% |
| **FaceNet-512 (đang dùng, 24 MB, 512 chiều)** | **~90%** |

Model ban đầu (MobileFaceNet) để người có nét giống lọt qua, nên đã được thay bằng FaceNet-512. Trên điện thoại thật,
chính chủ đo được khoảng cách 0,28–0,38, còn người khác khoảng 1,0, với ngưỡng 0,65.

---

## 7. Bảo mật

| Kỹ thuật | Áp dụng |
|---|---|
| Không lưu mật khẩu trên máy | Firebase Authentication kiểm tra mật khẩu trên máy chủ |
| Khoá gắn với tập vân tay | Android Keystore: `setUserAuthenticationRequired` + `setInvalidatedByBiometricEnrollment`; chỉ nhận sinh trắc loại mạnh (`BIOMETRIC_STRONG`); giải mã qua `BiometricPrompt.CryptoObject` |
| Mã hoá dữ liệu trên máy | flutter_secure_storage (AES-GCM, khoá bọc bằng RSA trong Android Keystore); tắt sao lưu tự động (`android:allowBackup="false"`) |
| Băm | SHA-256 (gói `crypto`) cho mã bí mật của khoá vân tay |
| Phân quyền máy chủ | Firestore Security Rules theo tài khoản |
| Chống giả mạo khuôn mặt | Kiểm tra nháy mắt; kiểm tra chất lượng ảnh; giới hạn 3 lần sai |
| Đúng tài khoản | Vân tay/khuôn mặt chỉ mở tài khoản đã đăng ký trên máy; gõ tên tài khoản khác thì báo "Sai tài khoản" |
| Không lưu ảnh khuôn mặt | Chỉ lưu vector 512 số; ảnh chụp tạm bị xoá ngay |

---

## 8. Kiến trúc mã nguồn

- **Phân lớp**: `screens/` (giao diện) → `services/` (tài khoản, Firestore, vân tay, lưu trữ, nhận diện) → `face/` (toán và xử lý ảnh
  thuần Dart). 19 file Dart, khoảng 4.300 dòng trong `lib/`.
- **Truyền phụ thuộc** qua `AppServices`; các dịch vụ là lớp trừu tượng (`AuthService`, `CloudDataService`…) nên test được bằng bản giả.
- **Isolate** (`Isolate.run`) cho việc nặng: giải mã ảnh, căn thẳng/cắt khuôn mặt, ghi ảnh debug – giao diện không bị giật.
- **Nạp model một lần** cho cả phiên chạy (tránh rò rỉ bộ nhớ của `Interpreter.fromAsset` trong `tflite_flutter`).
- **Quản lý trạng thái** bằng `StatefulWidget` + `setState` (không dùng thư viện quản lý state).

---

## 9. Giao diện

- **Material 3**, theme sáng/tối (`ColorScheme.fromSeed`, `DynamicSchemeVariant.fidelity`), tông navy → xanh dương (`#0B1F4D` → `#1D4ED8`).
- Widget tự viết: banner chuyển màu, thẻ form nổi, nút vân tay cạnh ô mật khẩu, màn quét toàn màn hình có khung oval và 3 bước,
  dòng trạng thái mờ dần (`FadingStatusText`), hộp thoại "Sai tài khoản" / "Gương mặt không khớp".
- Toàn bộ chữ trên giao diện và thông báo lỗi bằng **tiếng Việt**.
- **Logo**: khiên trắng + vân tay trên nền chuyển màu; icon thích ứng (Android 8+) và icon đơn sắc theo theme (Android 13+).

---

## 10. Kiểm thử và gỡ lỗi

| Công cụ | Dùng để làm gì |
|---|---|
| `flutter analyze` + `flutter_lints` | Kiểm tra lỗi tĩnh (không còn cảnh báo) |
| `flutter test` – **70 test** | Toán khuôn mặt, xoay EXIF, căn thẳng, kiểm tra nháy mắt, khoá vân tay (MethodChannel giả lập), kiểm tra dữ liệu nhập, bố cục 360dp sáng/tối, luồng đăng ký/đăng nhập/quên mật khẩu/đổi mật khẩu, sai tài khoản, đồng bộ khuôn mặt, lỗi trùng khoá `AnimatedSwitcher` |
| Bản giả (fakes) | `FakeAuthService` (Firebase trong bộ nhớ), `FakeCloudDataService`, `FakeBiometricService`, MethodChannel giả |
| `adb logcat`, `flutter run` | Đọc log và lỗi trên điện thoại thật (khoảng cách so khớp, lỗi Firebase) |
| `adb shell dumpsys meminfo` | Đo bộ nhớ, tìm ra rò rỉ khi nạp model nhiều lần |
| `adb exec-out run-as` | Lấy ảnh khuôn mặt đã cắt (bản debug) để kiểm tra bước cắt ảnh |

---

## 11. Công cụ phụ trợ (Python)

| Script | Công nghệ | Dùng để làm gì |
|---|---|---|
| [tool/eval_lfw.py](tool/eval_lfw.py) | Python 3.12, TensorFlow 2.21 (TFLite Interpreter), NumPy, scikit-learn (tải LFW), Pillow | Đo tỉ lệ nhận đúng / nhận nhầm của model trên LFW để chọn model và ngưỡng |
| [tool/make_icon.py](tool/make_icon.py) | Pillow, font Material Icons của Flutter SDK | Vẽ logo 1024px (nền, lớp trước, đơn sắc) |

---

## 12. Nguồn tài nguyên và giấy phép

| Tài nguyên | Nguồn | Giấy phép |
|---|---|---|
| Model `facenet_512.tflite` | [shubham0204/FaceRecognition_With_FaceNet_Android](https://github.com/shubham0204/FaceRecognition_With_FaceNet_Android) | Apache-2.0 |
| Icon khiên, vân tay trong logo | Material Icons (Flutter SDK) | Apache-2.0 |
| Bộ ảnh đánh giá LFW | Labeled Faces in the Wild (qua `sklearn.datasets.fetch_lfw_people`) | Dùng cho nghiên cứu |
| Firebase, ML Kit | Google | Theo điều khoản dịch vụ của Google |
