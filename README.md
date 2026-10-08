# VeriMe – Ứng dụng xác thực sinh trắc học (Vân tay / Khuôn mặt) bằng Flutter

> Tên hiển thị **VeriMe** (`android:label` trong `AndroidManifest.xml` + `kAppName` trong `lib/widgets/common.dart`).
> Tên project/package vẫn là `faceid` / `com.example.faceid` – đổi package thì phải tạo lại `google-services.json` trên Firebase.
> Tổng hợp công nghệ và thư viện (kèm phiên bản): [CONG_NGHE.md](CONG_NGHE.md).

Ứng dụng Flutter (Dart) cho phép **đăng ký – đăng nhập bằng mật khẩu**, sau đó đăng nhập nhanh bằng **2 cách sinh trắc**:

| Cách | Công nghệ | Hoạt động trên |
|---|---|---|
| **A. Vân tay** (cảm biến của máy, khoá theo tập vân tay lúc bật) | BiometricPrompt + khoá Android Keystore (`BiometricLock.java`) | Máy có cảm biến vân tay (sinh trắc Class 3) |
| **B. Nhận diện khuôn mặt bằng camera** (app tự xử lý) | `camera` + ML Kit + TensorFlow Lite (FaceNet-512) | Mọi máy có camera trước |

> Nền tảng: **Android** (API 24 – Android 7.0 trở lên).
> Face ID là tính năng riêng của iPhone nên không có trong project này.

---

## Mục lục
1. [Tính năng](#1-tính-năng)
2. [Yêu cầu môi trường](#2-yêu-cầu-môi-trường)
3. [Thư viện sử dụng](#3-thư-viện-sử-dụng)
4. [Cấu hình Android (bắt buộc)](#4-cấu-hình-android-bắt-buộc) – gồm **[4.8. Cấu hình Firebase](#48-cấu-hình-firebase-tài-khoản-và-email)**, [4.9. Logo ứng dụng](#49-logo-ứng-dụng)
5. [Cấu trúc thư mục và luồng hoạt động](#5-cấu-trúc-thư-mục-và-luồng-hoạt-động)
6. [Cách A – Vân tay gắn với tập vân tay trên máy](#6-cách-a--vân-tay-gắn-với-tập-vân-tay-trên-máy)
7. [Cách B – Nhận diện khuôn mặt bằng camera](#7-cách-b--nhận-diện-khuôn-mặt-bằng-camera)
8. [Chạy ứng dụng](#8-chạy-ứng-dụng)
9. [Giả lập vân tay trên Android Emulator](#9-giả-lập-vân-tay-trên-android-emulator)
10. [Kiểm thử](#10-kiểm-thử)
11. [Bảo mật](#11-bảo-mật)
12. [Xử lý sự cố thường gặp](#12-xử-lý-sự-cố-thường-gặp)
13. [Kế hoạch phát triển](#13-kế-hoạch-phát-triển)

---

## 1. Tính năng

- **Đăng ký** bằng tên đăng nhập, **email** và mật khẩu. Tài khoản lưu trên **Firebase Authentication**;
  Firebase gửi **email xác minh** sau khi đăng ký.
- **Đăng nhập** bằng email hoặc tên đăng nhập + mật khẩu. **Lần đầu trên mỗi máy phải dùng mật khẩu**; từ lần sau có thể
  chọn **vân tay** (nút ngay cạnh ô mật khẩu) hoặc **khuôn mặt**.
- **Quên mật khẩu**: Firebase gửi **email chứa đường dẫn đặt lại mật khẩu**.
- Trang chủ: xem email đã xác minh chưa, gửi lại email xác minh, **đổi mật khẩu**, **đăng xuất** (giữ vân tay/khuôn mặt
  cho lần sau), **xoá tài khoản khỏi máy**.
- **Dùng trên nhiều máy**: tên đăng nhập và vector khuôn mặt lưu trong tài khoản Firebase (Cloud Firestore), nên trên máy
  khác chỉ cần đăng nhập bằng mật khẩu một lần là khuôn mặt tự tải về. Vân tay phải bật riêng trên từng máy.
- **Cách A:** bật / tắt đăng nhập bằng vân tay; tự hiện hộp thoại khi mở màn hình đăng nhập.
  - Chỉ nhận các vân tay **có trên máy lúc bật**. Nếu sau đó có vân tay mới được thêm vào máy, app tự tắt tính năng và bắt đăng nhập lại bằng mật khẩu.
- **Cách B:** đăng ký khuôn mặt bằng camera trước (chụp 5 ảnh), đăng nhập bằng cách quét mặt.
  - Tự **căn thẳng khuôn mặt** theo 2 mắt và **loại ảnh kém** (quay đầu, nhắm mắt) để kết quả ổn định.
  - Nút **Thử** ở Trang chủ để đo độ khớp mà không cần đăng xuất.
  - Kiểm tra **người thật** bằng cách yêu cầu **nháy mắt** (chống dùng ảnh in/ảnh trên điện thoại khác).
  - Hiển thị **khoảng cách** giữa khuôn mặt quét được và khuôn mặt đã đăng ký; chọn **mức an toàn** (Cơ bản / Cao / Rất cao) ở Trang chủ.
  - Khoá đăng nhập bằng khuôn mặt sau 3 lần không khớp.
- Thông báo lỗi tiếng Việt: chưa đăng ký vân tay, không có cảm biến, chưa cấp quyền camera, bị khoá do sai nhiều lần…
- Xoá tài khoản để đăng ký lại (khi quên mật khẩu).

## 2. Yêu cầu môi trường

| Thành phần | Phiên bản |
|---|---|
| Flutter SDK | bản stable mới (Dart SDK `^3.13`) |
| Android Studio | bản mới, có Android SDK + emulator hoặc điện thoại thật |
| JDK | 17 trở lên (đi kèm Android Studio) |
| Thiết bị chạy thử | Android 7.0 (API 24)+, **đã đặt khoá màn hình**. Cách A cần đăng ký vân tay; Cách B cần **camera trước** (nên dùng **điện thoại thật**) |

```bash
flutter doctor
```

## 3. Thư viện sử dụng

Tất cả các gói được tải từ [pub.dev](https://pub.dev):

| Gói | Phiên bản | Dùng cho | Mục đích |
|---|---|---|---|
| [`local_auth`](https://pub.dev/packages/local_auth) | ^3.0.2 | Cách A | Liệt kê loại sinh trắc thiết bị hỗ trợ (hiển thị ở Trang chủ) |
| `androidx.biometric:biometric` (Gradle, không phải pub.dev) | 1.1.0 | Cách A | BiometricPrompt + CryptoObject cho khoá vân tay trong `BiometricLock.java` |
| [`camera`](https://pub.dev/packages/camera) | ^0.12.1 | Cách B | Mở camera trước, lấy luồng hình và chụp ảnh |
| [`google_mlkit_face_detection`](https://pub.dev/packages/google_mlkit_face_detection) | ^0.15.1 | Cách B | **Phát hiện** khuôn mặt, xác suất mắt mở (để kiểm tra nháy mắt), góc quay đầu |
| [`tflite_flutter`](https://pub.dev/packages/tflite_flutter) | ^0.12.1 | Cách B | Chạy model **FaceNet-512** để **nhận diện** (tạo vector 512 chiều) |
| [`image`](https://pub.dev/packages/image) | ^4.10.1 | Cách B | Giải mã ảnh JPEG, xoay đúng chiều, cắt và resize khuôn mặt |
| [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) | ^11.2.0 | Chung | Lưu tài khoản, hash mật khẩu, cờ sinh trắc, vector khuôn mặt – mã hoá bằng Android Keystore |
| [`crypto`](https://pub.dev/packages/crypto) | ^3.0.7 | Chung | SHA-256 của mã bí mật trong khoá vân tay |
| [`firebase_core`](https://pub.dev/packages/firebase_core) | ^4.15.0 | Tài khoản | Khởi tạo Firebase (đọc `google-services.json`) |
| [`firebase_auth`](https://pub.dev/packages/firebase_auth) | ^6.7.0 | Tài khoản | Đăng ký/đăng nhập email + mật khẩu, email xác minh, email đặt lại mật khẩu, đổi mật khẩu |
| [`cloud_firestore`](https://pub.dev/packages/cloud_firestore) | ^6.10.0 | Tài khoản | Bảng **tên đăng nhập → email** trên máy chủ, để đăng nhập bằng tên đăng nhập trên mọi máy |

Lệnh cài (đã chạy sẵn, các gói đã có trong `pubspec.yaml`):

```bash
flutter pub add local_auth flutter_secure_storage crypto firebase_core firebase_auth cloud_firestore
flutter pub add camera google_mlkit_face_detection tflite_flutter image
```

### Model nhận diện khuôn mặt (không có trên pub.dev)

File [assets/models/facenet_512.tflite](assets/models/facenet_512.tflite) (~24 MB) – **FaceNet** (Inception-ResNet-v1, huấn luyện
trên VGGFace2), lấy từ repo [shubham0204/FaceRecognition_With_FaceNet_Android](https://github.com/shubham0204/FaceRecognition_With_FaceNet_Android)
(giấy phép Apache-2.0) – khai báo trong `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/models/facenet_512.tflite
```

| Thông số | Giá trị |
|---|---|
| Đầu vào | `[1, 160, 160, 3]` float32 – ảnh khuôn mặt RGB, **chuẩn hoá theo từng ảnh**: `(pixel − trung bình) / độ lệch chuẩn` |
| Đầu ra | `[1, 512]` float32 – vector đặc trưng khuôn mặt |

Nếu file bị mất, tải lại bằng:

```bash
curl -L -o assets/models/facenet_512.tflite https://raw.githubusercontent.com/shubham0204/FaceRecognition_With_FaceNet_Android/master/app/src/main/assets/facenet_512.tflite
```

> Bản trước dùng **MobileFaceNet** (5 MB, 192 chiều). Đo trên LFW (mục 7.3), model đó để người có nét giống lọt quá nhiều nên đã được
> thay. Mẫu khuôn mặt cũ không so được với model mới – sau khi cập nhật cần **đăng ký lại khuôn mặt**.

## 4. Cấu hình Android (bắt buộc)

Các bước dưới đây **đã được làm sẵn** trong project; ghi lại để bạn hiểu và làm lại cho project khác.

### 4.1. `FlutterFragmentActivity` và kênh khoá vân tay
BiometricPrompt cần `FragmentActivity`. `MainActivity` cũng đăng ký kênh `faceid/biometric_lock` để Dart gọi
[BiometricLock.java](android/app/src/main/java/com/example/faceid/BiometricLock.java) (mục 6).
File [MainActivity.java](android/app/src/main/java/com/example/faceid/MainActivity.java):

```java
public class MainActivity extends FlutterFragmentActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BiometricLock.CHANNEL)
                .setMethodCallHandler(new BiometricLock(this));
    }
}
```

### 4.2. Khai báo quyền
File [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml):

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera.front" android:required="false"/>
```

Quyền camera được hỏi tự động khi mở màn hình quét khuôn mặt lần đầu.

### 4.3. `minSdk = 24`, AppCompat và androidx.biometric
File [android/app/build.gradle.kts](android/app/build.gradle.kts):

```kotlin
defaultConfig {
    minSdk = 24   // local_auth và flutter_secure_storage yêu cầu API 24+
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.biometric:biometric:1.1.0") // BiometricPrompt + CryptoObject
}
```

### 4.4. Theme khởi động AppCompat
Tránh crash hộp thoại sinh trắc trên Android 8 trở xuống. `LaunchTheme` trong
[values/styles.xml](android/app/src/main/res/values/styles.xml) và [values-night/styles.xml](android/app/src/main/res/values-night/styles.xml):

```xml
<style name="LaunchTheme" parent="Theme.AppCompat.DayNight.NoActionBar">
```

### 4.5. Đồng bộ JVM target cho `tflite_flutter`
`tflite_flutter` đặt Java target 11 nhưng không đặt Kotlin target, khiến build báo
`Inconsistent JVM Target Compatibility`. Đã thêm vào [android/build.gradle.kts](android/build.gradle.kts):

```kotlin
subprojects {
    if (name == "tflite_flutter") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
}
```

### 4.6. (Windows) Tắt Kotlin incremental compile
Khi project nằm ở ổ khác với pub cache (ví dụ project ở `D:`, pub cache ở `C:`), Gradle báo
`this and base files have different roots`. Đã thêm vào [android/gradle.properties](android/gradle.properties):

```properties
kotlin.incremental=false
```

### 4.7. Vì sao chọn Java khi tạo project mà vẫn có Kotlin?

Tuỳ chọn **Android language: Java** trong hộp thoại *New Project* chỉ quyết định **ngôn ngữ của code Android do bạn viết**
(`MainActivity`). Code Android của app đúng là toàn Java:
[MainActivity.java](android/app/src/main/java/com/example/faceid/MainActivity.java) và
[BiometricLock.java](android/app/src/main/java/com/example/faceid/BiometricLock.java). Kotlin vẫn xuất hiện vì 2 lý do:

1. **File cấu hình Gradle dùng Kotlin DSL** (`.gradle.kts`). Template Flutter mới luôn tạo `build.gradle.kts`,
   `settings.gradle.kts` bất kể chọn Java hay Kotlin – đây chỉ là cú pháp của file cấu hình build, không phải code app.
2. **Nhiều plugin Flutter được viết bằng Kotlin**, nên Gradle phải có Kotlin plugin để biên dịch chúng
   (khai báo `org.jetbrains.kotlin.android` trong `settings.gradle.kts`):

| Plugin | Code Android |
|---|---|
| `local_auth_android` | Kotlin |
| `google_mlkit_commons`, `google_mlkit_face_detection` | Kotlin |
| `tflite_flutter` | Kotlin |
| `camera_android_camerax` | Java + một phần Kotlin |
| `flutter_secure_storage` | Java |

Vì vậy **không bỏ Kotlin được** – bỏ đi thì các plugin trên không build được. Bạn vẫn viết code của mình bằng Java bình thường;
Java và Kotlin chạy chung trên JVM và gọi qua lại được.

### 4.8. Cấu hình Firebase (tài khoản và email)

Gửi email cần máy chủ, nên tài khoản được lưu trên **Firebase Authentication** – gói miễn phí (Spark) là đủ, không cần
thẻ thanh toán. Firebase Authentication chỉ biết **email**, không có khái niệm tên đăng nhập, nên app lưu thêm bảng
**tên đăng nhập → email** trên **Cloud Firestore** (cũng miễn phí) – nhờ vậy đăng nhập bằng tên đăng nhập hay email
đều được, trên bất kỳ máy nào. Chưa cấu hình thì app vẫn build được và hiện màn **"Cần cấu hình Firebase"** kèm hướng dẫn (plugin
Google Services chỉ được bật khi có file cấu hình – xem [android/app/build.gradle.kts](android/app/build.gradle.kts)).

1. Vào [console.firebase.google.com](https://console.firebase.google.com) → **Add project** → đặt tên → tạo.
2. **Add app → Android** → *Android package name*: `com.example.faceid` (mục SHA-1 có thể bỏ trống – đăng nhập bằng email không cần).
3. Tải **`google-services.json`** → chép vào **`android/app/google-services.json`**.
4. **Build → Authentication → Get started → Sign-in method → Email/Password → Enable**.
5. **Build → Firestore Database → Create database** → *Location*: `asia-southeast1 (Singapore)` → **Start in production mode** → **Create**.
6. Trong Firestore Database, tab **Rules** → xoá nội dung cũ, dán **toàn bộ** file [firestore.rules](firestore.rules) → **Publish**.
7. Chạy lại: `flutter clean` rồi `flutter run`.

Sau bước 5–6, trong **Firestore Database → Data** sẽ thấy:
- collection **`usernames`**: mỗi tài liệu có mã là tên đăng nhập (viết thường), chứa `uid`, `email`, `username`, `createdAt`;
- collection **`users`**: mỗi tài liệu có mã là UID tài khoản, chứa `faceEmbedding` (512 số) và `faceUpdatedAt`.

> Mỗi khi file `firestore.rules` thay đổi (ví dụ khi cập nhật app), dán lại vào tab **Rules** rồi **Publish**.

Tuỳ chọn: **Authentication → Templates** để đổi ngôn ngữ email xác minh / email đặt lại mật khẩu sang tiếng Việt.

#### Luồng tài khoản

```
Đăng ký: tên + email + mật khẩu ──► kiểm tra tên chưa có người dùng (Firestore) ──► Firebase tạo tài khoản
         ──► lưu usernames/{tên} ──► gửi email xác minh (lỗi gửi thư vẫn vào được Trang chủ) ──► Trang chủ
Đăng nhập: email, hoặc tên đăng nhập (tra email ở usernames/{tên}, không phân biệt hoa thường;
           mất mạng thì dùng hồ sơ trên máy) + mật khẩu ──► Firebase kiểm tra
Tài khoản tạo trước khi có bảng tên: đăng nhập bằng email một lần (hoặc mở Trang chủ) ──► app tự thêm tên vào bảng
Quên mật khẩu: email ──► Firebase gửi đường dẫn đặt lại ──► người dùng đặt mật khẩu mới trên trang của Firebase
               ──► quay lại app đăng nhập bằng mật khẩu mới
Đổi mật khẩu (Trang chủ): mật khẩu hiện tại + mật khẩu mới ──► Firebase xác thực lại rồi đổi
Lần đầu trên máy: phải đăng nhập bằng mật khẩu (nút vân tay/khuôn mặt vẫn hiện, bấm vào thì app hướng dẫn).
Vân tay / khuôn mặt: mở khoá nhanh khi phiên đăng nhập Firebase còn trên máy (không cần mạng), CHỈ cho tài khoản đã
           đăng ký chúng trên máy: ô tên đăng nhập ghi tài khoản khác (vd. "huy" trong khi khuôn mặt là của "chitu")
           ──► hộp thoại "Sai tài khoản", không quét, không tự vào tài khoản trên máy.
Quét mặt không khớp ──► hộp thoại "Gương mặt không khớp" (còn bao nhiêu lần thử, khoảng cách/ngưỡng).
Đăng xuất (Trang chủ): về màn đăng nhập, giữ phiên + vân tay + khuôn mặt ──► lần sau chọn mật khẩu, vân tay hoặc khuôn mặt.
Xoá tài khoản khỏi máy: thoát Firebase + xoá hồ sơ, khoá vân tay, khuôn mặt trên máy (dữ liệu trên Firebase vẫn còn).
Khuôn mặt: đăng ký ──► lưu trên máy + users/{uid} trên Firestore; máy khác đăng nhập bằng mật khẩu ──► tự tải về.
Vân tay: không lưu lên mạng được (Android giữ trong phần cứng của từng máy) ──► mỗi máy bật riêng ở Trang chủ.
```

Mã nguồn: [auth_service.dart](lib/services/auth_service.dart) (lớp trừu tượng `AuthService` + `FirebaseAuthService`,
bảng tên đăng nhập trên Firestore, thông báo lỗi tiếng Việt), [validators.dart](lib/services/validators.dart) (kiểm tra
email, mật khẩu, tên đăng nhập), [firestore.rules](firestore.rules) (luật bảo mật của bảng tên đăng nhập).

### 4.9. Logo ứng dụng

Logo VeriMe: nền chuyển màu navy → xanh dương, khiên trắng có dấu vân tay – cùng tông màu với giao diện.
Có đủ: icon thường (Android < 8), **icon thích ứng** (Android 8+, launcher tự bo tròn/vuông) và **icon đơn sắc** theo theme
(Android 13+). Icon trong `android/app/src/main/res/mipmap-*` và `drawable-*` được tạo tự động bằng
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) (cấu hình trong `pubspec.yaml`):

```bash
python tool/make_icon.py          # (tuỳ chọn) vẽ lại ảnh gốc trong assets/icon/, xem trước ở build/icon_preview.png
dart run flutter_launcher_icons   # tạo icon Android từ assets/icon/
```

Muốn dùng logo khác: thay 4 ảnh trong `assets/icon/` (1024×1024; ảnh lớp trước phải nằm trong vòng tròn giữa ảnh, đường kính
~61% – vùng an toàn của icon thích ứng) rồi chạy lại lệnh thứ hai. Màn hình khởi động của Android 12+ cũng tự dùng icon này.

## 5. Cấu trúc thư mục và luồng hoạt động

```
android/app/src/main/java/com/example/faceid/
├── MainActivity.java                # FlutterFragmentActivity + đăng ký kênh faceid/biometric_lock
└── BiometricLock.java               # Cách A: khoá AES trong Keystore gắn với tập vân tay, BiometricPrompt + CryptoObject
assets/models/
└── facenet_512.tflite               # Model nhận diện khuôn mặt FaceNet-512
assets/icon/                         # Logo app (khiên + vân tay): ảnh gốc 1024px để tạo icon Android
tool/
├── make_icon.py                     # Vẽ logo (Pillow + font Material Icons của Flutter SDK)
└── eval_lfw.py                      # Đo model nhận diện trên bộ ảnh LFW (mục 7.3)
firestore.rules                      # Luật bảo mật Firestore cho bảng tên đăng nhập (dán vào Firebase Console)
lib/
├── main.dart                        # Khởi tạo app, khoá màn hình dọc, chọn màn hình đầu
├── face/
│   ├── face_math.dart               # Chuẩn hoá/khoảng cách vector, cắt & tiền xử lý ảnh khuôn mặt, ngưỡng so khớp
│   └── liveness_checker.dart        # Máy trạng thái kiểm tra người thật (mở mắt → nháy → mở lại)
├── services/
│   ├── app_services.dart            # Gom StorageService + BiometricService + AuthService để truyền qua màn hình
│   ├── auth_service.dart            # Tài khoản Firebase: đăng ký, đăng nhập (email/tên), email xác minh, đặt lại/đổi mật khẩu; bảng tên trên Firestore
│   ├── validators.dart              # Kiểm tra email, mật khẩu, tên đăng nhập; che bớt email khi hiển thị
│   ├── biometric_service.dart       # Cách A: gọi BiometricLock qua MethodChannel, bật/mở khoá/kiểm tra/tắt, lỗi tiếng Việt
│   ├── cloud_data_service.dart      # Lưu/tải vector khuôn mặt trong tài khoản (Firestore users/{uid}) để dùng trên máy khác
│   ├── face_recognition_service.dart# Cách B: ML Kit tìm khuôn mặt + FaceNet-512 tạo vector
│   └── storage_service.dart         # flutter_secure_storage: hồ sơ (tên, email), bản mã khoá vân tay, vector khuôn mặt
├── theme/
│   └── app_theme.dart               # Theme Material 3 sáng/tối, tông xanh navy, gradient thương hiệu
├── widgets/
│   └── common.dart                  # Widget dùng chung: BrandBanner, AuthLayout, PasswordField, FingerprintButton, StatusPill…
└── screens/
    ├── register_screen.dart         # Tạo tài khoản: tên, email, mật khẩu
    ├── forgot_password_screen.dart  # Quên mật khẩu: gửi email đặt lại mật khẩu
    ├── change_password_screen.dart  # Đổi mật khẩu (mật khẩu hiện tại + mật khẩu mới)
    ├── firebase_setup_screen.dart   # Hướng dẫn khi chưa có google-services.json
    ├── login_screen.dart            # Đăng nhập: mật khẩu / sinh trắc hệ thống / khuôn mặt camera
    ├── home_screen.dart             # Bật/tắt sinh trắc, đăng ký/xoá khuôn mặt, đăng xuất
    └── face_scan_screen.dart        # Camera + kiểm tra nháy mắt + chụp ảnh → trả về vector khuôn mặt
test/
├── fakes.dart                       # Bản giả: FakeAuthService (Firebase trong bộ nhớ), FakeBiometricService
├── validators_test.dart             # Kiểm tra email, che email, thông báo lỗi Firebase
├── widget_test.dart                 # Màn hình đầu, màn hướng dẫn Firebase, hồ sơ, vector khuôn mặt
├── biometric_service_test.dart      # Khoá vân tay (giả lập phần native): bật, mở khoá, vân tay đã thay đổi, huỷ
├── face_math_test.dart              # Toán vector và tiền xử lý ảnh
├── liveness_checker_test.dart       # Logic kiểm tra nháy mắt
└── ui_layout_test.dart              # Dựng các màn hình ở 360dp (sáng + tối), bắt lỗi tràn giao diện
```

Luồng hoạt động:

```
Mở app
  ├─ Chưa có tài khoản ──► Đăng ký ──► Trang chủ
  └─ Đã có tài khoản  ──► Đăng nhập
        ├─ Mật khẩu đúng ───────────────────────────────► Trang chủ
        ├─ (Cách A) đã bật ──► khoá còn hợp lệ? ──► hộp thoại vân tay tự hiện ──► giải mã được ──► Trang chủ
        │                        └─ vân tay trên máy đã thay đổi ──► tự tắt, yêu cầu mật khẩu
        └─ (Cách B) đã đăng ký khuôn mặt ──► nút "Đăng nhập bằng khuôn mặt (camera)"
              └─ Quét mặt + nháy mắt ──► khoảng cách < ngưỡng ? ──► Trang chủ

Trang chủ
  ├─ Công tắc "Vân tay" (Cách A) ──► quét vân tay ──► tạo khoá Keystore + lưu bản mã
  └─ "Đăng ký khuôn mặt" (Cách B) ──► quét mặt, chụp 5 ảnh ──► lưu vector trung bình
```

## 6. Cách A – Vân tay gắn với tập vân tay trên máy

### 6.1. App có tự đăng ký vân tay riêng được không?

**Không, với cảm biến vân tay của điện thoại.** Android **không cho bất kỳ ứng dụng nào** đọc dữ liệu từ cảm biến vân tay
(ảnh hay mẫu vân tay) hoặc tự đăng ký vân tay. Cảm biến nằm trong vùng phần cứng bảo mật (TEE), và ứng dụng chỉ được hỏi
qua BiometricPrompt: *"có phải người đã đăng ký trên máy không?"* → **đúng/sai**. Mọi app (ngân hàng, ví điện tử…) đều chịu giới hạn này.

Vân tay được đăng ký trong **Cài đặt → Bảo mật → Vân tay** của Android. Ở bước đó hệ thống tự yêu cầu đặt ngón nhiều lần, ở nhiều vị trí.

Muốn vân tay **hoàn toàn độc lập với điện thoại** thì phải dùng **máy quét vân tay rời** (cắm USB-C/OTG, có SDK Android
như SecuGen, Mantra, Futronic). Project này không dùng cách đó.

### 6.2. Cách app làm: khoá theo tập vân tay hiện có

Thay vì chỉ lưu cờ "đã bật" (khi đó **bất kỳ vân tay nào** thêm vào máy sau này cũng mở được app), app dùng **khoá mã hoá trong
Android Keystore gắn với tập vân tay lúc bật** – code native ở [BiometricLock.java](android/app/src/main/java/com/example/faceid/BiometricLock.java):

```
BẬT (Trang chủ → công tắc Vân tay)
  1. Tạo khoá AES-256 trong Android Keystore:
       setUserAuthenticationRequired(true)          → phải quét vân tay mỗi lần dùng khoá
       setUserAuthenticationParameters(0, STRONG)   → chỉ nhận sinh trắc loại mạnh (Class 3)
       setInvalidatedByBiometricEnrollment(true)    → thêm/xoá vân tay trên máy ⇒ khoá bị huỷ vĩnh viễn
  2. BiometricPrompt + CryptoObject(cipher) → người dùng quét vân tay → cipher được mở khoá
  3. Mã hoá một mã bí mật ngẫu nhiên 32 byte → lưu IV + bản mã + SHA-256(mã bí mật) vào flutter_secure_storage

ĐĂNG NHẬP
  1. Khởi tạo cipher giải mã bằng khoá
       └─ KeyPermanentlyInvalidatedException ⇒ vân tay trên máy đã thay đổi
          ⇒ tự tắt tính năng, báo "hãy đăng nhập bằng mật khẩu rồi bật lại"
  2. BiometricPrompt + CryptoObject → quét vân tay → giải mã bản mã
  3. So SHA-256 của mã giải ra với hash đã lưu → khớp ⇒ vào Trang chủ (bằng tên tài khoản đã lưu)
```

Kết quả:

| Tình huống | App xử lý |
|---|---|
| Quét đúng một vân tay **có trên máy lúc bật** | Đăng nhập thành công |
| Ai đó **thêm vân tay mới** vào máy (hoặc xoá bớt) sau khi bật | Khoá bị Android huỷ → app tự tắt đăng nhập bằng vân tay, bắt nhập mật khẩu và bật lại |
| Quét sai nhiều lần | Android khoá tạm thời / khoá hẳn → dùng mật khẩu |
| Bấm **Huỷ** | Không báo lỗi, vẫn giữ tính năng |

Vì xác thực dùng **CryptoObject**, kết quả "đúng" không chỉ là một giá trị true/false có thể bị giả – phải có vân tay hợp lệ thì
khoá trong phần cứng mới giải mã được bản mã.

**Giới hạn còn lại:** app vẫn **không phân biệt được từng ngón** trong số các vân tay đã có trên máy lúc bật (ví dụ máy có
vân tay của 2 người từ trước thì cả 2 đều mở được). Chỉ nhận **sinh trắc loại mạnh (Class 3)**: vân tay gần như luôn đạt;
face unlock chỉ đạt trên số ít máy (ví dụ Pixel 8 trở lên).

### 6.3. Dùng trong code Dart

```dart
final biometric = BiometricService();
await biometric.enable(storage);                 // Trang chủ: bật (quét vân tay, tạo khoá)
final r = await biometric.unlock(storage);       // Đăng nhập: quét vân tay, giải mã
if (r.success) { /* vào app */ } else if (r.message != null) { /* báo lỗi tiếng Việt */ }
await biometric.checkLock(storage);              // Mở Trang chủ: phát hiện vân tay đã thay đổi
await biometric.disable(storage);                // Tắt: xoá khoá trong Keystore
```

Dart gọi phần native qua `MethodChannel('faceid/biometric_lock')` với các lệnh `status`, `keyState`, `enable`, `unlock`, `disable`
(đăng ký trong [MainActivity.java](android/app/src/main/java/com/example/faceid/MainActivity.java)).

## 7. Cách B – Nhận diện khuôn mặt bằng camera

### 7.1. Phát hiện và nhận diện khác nhau thế nào?
- **Phát hiện (detection)** – ML Kit trả lời *"trong ảnh có khuôn mặt nào, ở đâu, mắt đang mở hay nhắm"*. Không biết đó là ai.
- **Nhận diện (recognition)** – FaceNet-512 biến khuôn mặt thành **vector 512 số**. Hai ảnh của cùng một người cho ra 2 vector **gần nhau**; người khác cho ra vector **xa nhau**.

### 7.2. Các bước xử lý (trong [face_scan_screen.dart](lib/screens/face_scan_screen.dart))
1. **Mở camera trước** (`ResolutionPreset.medium`, định dạng `nv21` để ML Kit đọc được).
2. **Kiểm tra người thật**: mỗi khung hình được đưa vào ML Kit (`enableClassification: true`).
   [`LivenessChecker`](lib/face/liveness_checker.dart) yêu cầu: đúng 1 khuôn mặt, nhìn thẳng (quay đầu ≤ 20°),
   **mắt mở (> 0.7) → nhắm (< 0.3) → mở lại**. Mất khuôn mặt hoặc có 2 người thì làm lại từ đầu.
3. **Chụp ảnh** (đăng ký: 5 ảnh, đăng nhập/thử: 2 ảnh; nghỉ 0,35 giây giữa các ảnh), với mỗi ảnh ([face_recognition_service.dart](lib/services/face_recognition_service.dart)):
   - **Giải mã một lần** (`decodeUpright`): đọc JPEG, xoay/lật đúng chiều theo EXIF, thu nhỏ còn cạnh dài ≤ 1024px, ra mảng pixel RGBA.
     **Cùng ảnh này** được đưa cho ML Kit (`InputImage.fromBitmap`) và cho bước cắt ảnh, nên toạ độ khuôn mặt luôn khớp với
     ảnh được cắt (ảnh camera trước thường lưu nằm ngang 90°/270° và có thể bị lật – nếu ML Kit và bước cắt hiểu EXIF khác nhau,
     vùng cắt sẽ lệch khỏi khuôn mặt).
     Bản gửi ML Kit được đổi sang thứ tự **BGRA** (`toMlKitBitmap`): phần Android của `google_mlkit_commons` đóng gói pixel sai thứ tự
     so với `Bitmap.ARGB_8888`, nếu gửi RGBA thì ML Kit thấy ảnh bị đảo đỏ ↔ xanh dương (mặt màu xanh lam), phát hiện mặt và mắt kém ổn định.
   - ML Kit (chế độ `accurate`, bật landmarks + classification) tìm khuôn mặt lớn nhất và vị trí 2 mắt.
   - **Kiểm tra chất lượng** (`faceQualityProblem`): loại ảnh có **mặt quá nhỏ** (bề rộng mặt < 25% ảnh – đứng quá xa), quay đầu/ngẩng/cúi
     quá 15° hoặc mắt đang nhắm, và hiện lý do lên màn hình. Mỗi ảnh được thử lại tối đa 3 lần.
   - **Căn thẳng** (`alignAndCropFace`): xoay ảnh để đường nối 2 mắt nằm ngang, rồi cắt vùng vuông quanh khuôn mặt (nới 10%).
   - Resize về 160×160, chuẩn hoá theo từng ảnh `(pixel − trung bình) / độ lệch chuẩn` — chạy trong `Isolate` để không giật giao diện.
   - FaceNet-512 → vector 512 chiều → chuẩn hoá L2 (độ dài = 1).
4. **Đăng ký**: lấy trung bình 5 vector rồi lưu (xem [mục 7.6](#76-dữ-liệu-khuôn-mặt-được-lưu-ở-đâu)). Chỉ lưu vector, **không lưu ảnh**; ảnh chụp bị xoá ngay.
5. **Đăng nhập**: tính **khoảng cách Euclid** từ vector đã lưu tới từng ảnh vừa chụp, lấy **khoảng cách nhỏ nhất** (`matchDistance`); nhỏ hơn ngưỡng của **mức an toàn** đang chọn là khớp.

> **Vì sao trước đây "lúc được lúc không"?** Phiên bản đầu không căn thẳng khuôn mặt (nghiêng đầu vài độ là vector lệch nhiều),
> không kiểm tra ảnh chụp (có thể chụp đúng lúc quay đầu/nhắm mắt), đăng ký bằng 3 ảnh chụp liền nhau gần như giống hệt,
> và đăng nhập chỉ dựa vào 1 ảnh. Các điểm này đã được sửa. Vector đăng ký theo cách cũ bị bỏ tự động (khoá lưu đổi sang
> `face_embedding_v2`), nên **cần đăng ký lại khuôn mặt** sau khi cập nhật.

### 7.3. Mức an toàn (ngưỡng so khớp) và vì sao đổi sang FaceNet-512

Ngưỡng nằm trong [lib/face/face_math.dart](lib/face/face_math.dart), chọn ở Trang chủ → *Khuôn mặt* → **Mức an toàn**:

```dart
enum FaceSecurityLevel {
  standard(0.75, 'Cơ bản'),
  high(0.65, 'Cao'),        // mặc định
  veryHigh(0.55, 'Rất cao');
}
```

Các số dưới đây **được đo thực tế**, không phải ước đoán: chạy đúng file `.tflite` (TensorFlow Lite trên máy tính) trên bộ ảnh công khai
**LFW** – 217 người, 4.822 ảnh – mô phỏng đúng quy trình của app: mẫu đăng ký là trung bình 5 ảnh, đăng nhập lấy ảnh tốt nhất trong 2.
Ngoài người lạ ngẫu nhiên, phép đo còn thử với **10 người giống nhất** của mỗi người (mẫu gần nhất) – gần với tình huống "người trông
giống mình" ngoài đời.

**So sánh 2 model ở cùng mức chặt:**

| | MobileFaceNet (bản cũ) | **FaceNet-512 (đang dùng)** |
|---|---|---|
| Chính chủ được nhận khi người giống nhất chỉ lọt 0,3% | 69,7% | **~90%** |
| Người giống nhất lọt khi chính chủ được nhận 90% | 5,6% | **0,24–0,49%** |

**FaceNet-512 theo từng ngưỡng** (trung bình 2 cỡ vùng cắt):

| Ngưỡng | Chính chủ được nhận | Người lạ ngẫu nhiên lọt | **Người giống nhất lọt** (mỗi lần thử) |
|---|---|---|---|
| 0,85 | ~99% | 0,18% | 4,3% |
| **0,75 – *Cơ bản*** | ~96% | 0,03% | ~1% |
| 0,70 | ~91% | 0% | 0,32% |
| **0,65 – *Cao* (mặc định)** | **~83%** | **0%** | **~0,1%** |
| 0,60 | ~71% | 0% | ~0,03% |
| **0,55 – *Rất cao*** | ~53% | 0% | ~0,01% |

> **Vì sao trước đây bị nhận nhầm người?** Bản cũ dùng MobileFaceNet với ngưỡng 0,95, chỉ được chọn theo người lạ ngẫu nhiên (lọt 2,3%).
> Với người có nét giống (cùng độ tuổi, cùng đeo kính…) tỉ lệ lọt là **~21% mỗi lần thử**; cho thử 3 lần thì gần một nửa là lọt. Trên điện
> thoại thật còn tệ hơn: người khác đạt khoảng cách 0,58 – thấp hơn cả ngưỡng chặt nhất mà chính chủ còn dùng được – và 2 ảnh liên tiếp
> của cùng một người lệch nhau 0,58 ↔ 1,1. Siết ngưỡng không đủ, nên đã đổi sang model mạnh hơn.

- Đã thử thêm cách "cả 2 ảnh đều phải khớp": **kém hơn** lấy ảnh tốt nhất (cùng mức an toàn thì từ chối chính chủ nhiều hơn hẳn),
  nên app vẫn lấy ảnh tốt nhất và chỉ chỉnh ngưỡng.
- LFW gồm ảnh chụp cách nhau nhiều năm, ánh sáng rất khác nhau, nên **chính chủ khó hơn selfie trên cùng một điện thoại** – dùng thật,
  tỉ lệ chính chủ được nhận cao hơn cột 2 khá nhiều. Bị từ chối thì cứ quét lại; nếu thường xuyên bị từ chối, đăng ký lại khuôn mặt
  ở nơi đủ sáng hoặc chọn mức *Cơ bản*.
- Vùng cắt: cạnh dài khung khuôn mặt × 1,3 (`kFaceCropScale`) – đo trên LFW, lề 20–50% cho kết quả gần như nhau.
- Script đo: [tool/eval_lfw.py](tool/eval_lfw.py) (Python 3.12 + TensorFlow; bộ ảnh LFW tự tải qua `sklearn`). Hướng dẫn cài và chạy
  nằm ở đầu file; truyền đường dẫn model khác để so sánh trước khi thay model.
- App chỉ cho **3 lần** sai liên tiếp, rồi bắt đăng nhập bằng mật khẩu.

Khoảng cách nằm trong khoảng 0 – 2. Khi không khớp, app hiện khoảng cách, ví dụ *"Khuôn mặt không khớp (khoảng cách 0.91, ngưỡng 0.65 – mức Cao)"*.

Chọn mức phù hợp với điện thoại của mình bằng nút **Thử** ở thẻ *Khuôn mặt* trên Trang chủ (quét mặt, hiện khoảng cách 2 ảnh + Khớp/Không khớp):
- Bấm **Thử** bằng chính mặt mình vài lần (ánh sáng khác nhau, có/không đeo kính) và nhờ vài người khác thử, ghi lại khoảng cách.
- Chọn mức có ngưỡng nằm **giữa** khoảng cách của chính chủ và của người khác.
- Bản debug ghi khoảng cách ra log (`adb logcat | findstr "khuôn mặt"`) và lưu 4 ảnh khuôn mặt gần nhất đã cắt (đúng ảnh đưa vào model)
  để kiểm tra bước cắt: `adb exec-out run-as com.example.faceid cat cache/face_debug_0.png > face0.png`.

### 7.4. Có cần quay trái / quay phải để lấy góc nghiêng không?

**Không cần, và cũng không nên.** Cả lúc đăng ký lẫn lúc đăng nhập đều dùng **mặt nhìn thẳng**:

| Bước | Yêu cầu về góc mặt |
|---|---|
| Kiểm tra người thật (luồng camera) | Quay đầu trái/phải ≤ 20°, nếu lệch hơn app báo *Hãy nhìn thẳng vào camera* |
| Ảnh dùng để nhận diện (đăng ký và đăng nhập) | Quay trái/phải và ngẩng/cúi ≤ 15°, nếu lệch hơn ảnh bị loại và chụp lại |
| Nghiêng đầu sang vai (roll) | Không cần giữ thẳng, app tự xoay ảnh cho 2 mắt nằm ngang |

Lý do:
- Model nhận diện được huấn luyện chủ yếu với ảnh mặt **chính diện đã căn thẳng**. Vector của ảnh nghiêng 45–90° khác hẳn vector chính diện của cùng một người.
- Mẫu đăng ký là **trung bình** các vector. Trộn vector mặt nghiêng vào sẽ làm mẫu "nhoè", khiến khoảng cách tới ảnh chính diện lúc đăng nhập **tăng lên**, tức là dễ báo không khớp hơn.
- Lúc đăng nhập app cũng chỉ nhận ảnh gần chính diện, nên mẫu góc nghiêng không bao giờ được dùng tới.
- Các thay đổi nhỏ tự nhiên (lệch vài độ, biểu cảm, ánh sáng) đã được xử lý bằng 5 ảnh đăng ký chụp cách nhau, căn thẳng 2 mắt và lấy ảnh tốt nhất khi đăng nhập.

> Ghi chú: quay đầu trái/phải theo **yêu cầu ngẫu nhiên** là một cách **kiểm tra người thật** mạnh hơn nháy mắt (khó giả bằng video quay sẵn),
> nhưng đó là để chống giả mạo, không phải để lấy thêm dữ liệu nhận diện. Xem mục Mở rộng ở cuối README.

**Vân tay** cũng không cần app lấy góc. Việc đặt ngón nhiều lần ở nhiều vị trí do Android làm trong Cài đặt (xem mục 6).

### 7.5. Mẹo để nhận diện tốt
- Đủ sáng, ánh sáng chiếu từ phía trước; tránh ngược sáng.
- Đăng ký và đăng nhập trong điều kiện giống nhau (cùng có/không đeo kính).
- Giữ mặt trong khung oval, cách điện thoại 30–40 cm, giữ yên khi đang chụp.

### 7.6. Dữ liệu khuôn mặt được lưu ở đâu

| Câu hỏi | Trả lời |
|---|---|
| Lưu cái gì? | **Một vector 512 số thực** (trung bình 5 ảnh lúc đăng ký), dạng JSON. **Không lưu ảnh** – ảnh chụp tạm bị xoá ngay sau khi tạo vector. |
| Lưu bằng gì? | `flutter_secure_storage`, khoá `face_embedding_v2` (code: [storage_service.dart](lib/services/storage_service.dart)). Cùng chỗ với tên đăng nhập, salt + hash mật khẩu, bản mã của khoá vân tay (`biometric_iv`, `biometric_ciphertext`, `biometric_token_hash`). |
| File nằm ở đâu? | Trong bộ nhớ riêng của app trên điện thoại: `/data/data/com.example.faceid/shared_prefs/FlutterSecureStorage.xml`. Ứng dụng khác không đọc được thư mục này (trừ máy đã root). |
| Có mã hoá không? | Có. Giá trị được mã hoá **AES-GCM**; khoá AES được bọc bằng khoá **RSA nằm trong Android Keystore** (phần cứng bảo mật của máy, không lấy ra được). Mở file XML chỉ thấy chuỗi đã mã hoá. |
| Có gửi lên mạng/server không? | **Không.** Toàn bộ chụp ảnh, nhận diện, so khớp và lưu trữ đều diễn ra offline trên máy. |
| Khi nào bị xoá? | Bấm biểu tượng thùng rác ở thẻ khuôn mặt, *Quên mật khẩu → Xoá tài khoản*, gỡ app, hoặc xoá dữ liệu app trong Cài đặt. |
| Có bị sao lưu lên Google Drive không? | Không – đã đặt `android:allowBackup="false"` trong `AndroidManifest.xml`. Nếu bật sao lưu, dữ liệu mã hoá được khôi phục nhưng khoá trong Keystore thì không, gây lỗi `InvalidKeyException`. |
| Từ vector có dựng lại được ảnh mặt không? | Gần như không thể dựng lại ảnh rõ ràng, nhưng vector vẫn là **dữ liệu sinh trắc học** của một người – cần bảo vệ như mật khẩu. |

Xem nhanh dữ liệu (chỉ trên bản debug, sẽ thấy giá trị đã mã hoá):

```bash
adb shell run-as com.example.faceid cat shared_prefs/FlutterSecureStorage.xml
```

### 7.7. Hạn chế
- **Kém an toàn hơn Cách A.** Kiểm tra nháy mắt chặn được ảnh tĩnh nhưng **có thể bị qua mặt bằng video** quay sẵn. Không dùng cho ngân hàng/thanh toán.
- Độ chính xác phụ thuộc ánh sáng, góc mặt, camera.
- **Emulator** dùng webcam máy tính được nhưng chậm và kém chính xác — nên thử trên điện thoại thật.

## 8. Chạy ứng dụng

```bash
flutter pub get          # tải thư viện
flutter devices          # xem thiết bị
flutter run              # chạy debug

flutter build apk --release                 # APK chung cho mọi CPU (~100 MB)
flutter build apk --release --split-per-abi # APK riêng từng CPU (nhỏ hơn nhiều, cài file arm64-v8a cho đa số máy)
```

Cách thử:
1. Cấu hình Firebase (mục 4.8, gồm cả Firestore). Mở app → **Tạo tài khoản**: tên, **email thật** (để nhận email), mật khẩu.
   Mở email để bấm đường dẫn xác minh, rồi ở Trang chủ bấm **Tôi đã xác minh**.
   Màn Đăng nhập có ô **Email hoặc tên đăng nhập** và ô **Mật khẩu**; **nút vân tay nằm ngay bên phải ô mật khẩu**.
   Thử đăng nhập lần lượt bằng **tên đăng nhập** và bằng **email** – cả hai đều phải vào được.
   Thử **Quên mật khẩu?** → nhận email → đặt mật khẩu mới → đăng nhập lại bằng mật khẩu mới.
2. **Cách A**: ở Trang chủ bật công tắc *Vân tay* → quét vân tay để tạo khoá.
3. **Cách B**: ở Trang chủ bấm **Đăng ký khuôn mặt** → cho phép camera → nhìn vào khung → **nháy mắt** → giữ yên để chụp 5 ảnh. Sau đó bấm **Thử** vài lần để xem khoảng cách có ổn định không.
4. Bấm **Đăng xuất** → hộp thoại vân tay tự hiện (Cách A; bấm Huỷ để thử Cách B) → bấm **Đăng nhập bằng khuôn mặt** → nháy mắt → vào Trang chủ.
   Thử trên máy thứ hai: đăng nhập bằng mật khẩu → app báo *Đã tải khuôn mặt…* → bấm Đăng xuất → đăng nhập bằng khuôn mặt.
5. Thử tính năng khoá theo vân tay: vào **Cài đặt → Bảo mật → Vân tay**, **thêm một vân tay mới** → quay lại app → app báo
   *"Vân tay trên máy đã thay đổi…"*, công tắc Vân tay tự tắt, phải đăng nhập bằng mật khẩu rồi bật lại.
5. Thử: che camera, giơ ảnh chụp, nhờ người khác quét → app phải từ chối.

## 9. Giả lập vân tay trên Android Emulator

1. Tạo emulator (image **API 30+ có Google APIs**) trong Android Studio → *Device Manager*.
2. Trong emulator: **Settings → Security → Screen lock** → đặt PIN.
3. **Settings → Security → Fingerprint** → *Add fingerprint*. Khi được yêu cầu chạm cảm biến:
   - *Extended controls* (nút `...`) → **Fingerprint** → **Touch the sensor** (lặp lại vài lần), hoặc
   - `adb -e emu finger touch 1`
4. Khi app hiện hộp thoại vân tay: `finger touch 1` = vân tay đã đăng ký, `finger touch 2` = vân tay lạ.

> Để emulator dùng webcam cho Cách B: *Device Manager → Edit → Show Advanced Settings → Camera Front = Webcam0*.

## 10. Kiểm thử

```bash
flutter analyze   # kiểm tra lỗi tĩnh
flutter test      # chạy toàn bộ test trong test/
```

| File test | Nội dung |
|---|---|
| `widget_test.dart` | Máy chưa có tài khoản → Đăng ký, đã có hồ sơ → Đăng nhập; chưa cấu hình Firebase → màn hướng dẫn; hồ sơ không chứa mật khẩu; đăng xuất xoá sạch dữ liệu; vector khuôn mặt |
| `validators_test.dart` | Kiểm tra email; che email; kiểm tra/chuẩn hoá tên đăng nhập; thông báo lỗi Firebase và Firestore tiếng Việt |
| `face_math_test.dart` | Chuẩn hoá L2, khoảng cách Euclid, trung bình vector, khoảng cách tốt nhất, góc nghiêng 2 mắt, kiểm tra chất lượng ảnh, **căn thẳng khuôn mặt** (2 mắt nằm ngang sau khi xoay), cắt sát mép ảnh, chuẩn hoá theo từng ảnh (FaceNet), vector model cũ bị loại, tensor 160×160×3, mức an toàn |
| `fading_status_text_test.dart` | Câu hướng dẫn trên màn quét đổi qua lại rất nhanh (A → B → A → B trong 0,2 giây) không làm trùng khoá – lỗi màn hình đỏ đã gặp trên điện thoại |
| `liveness_checker_test.dart` | Nháy mắt hợp lệ thì qua; ảnh tĩnh (luôn mở mắt) không qua; mất mặt/2 mặt thì làm lại; quay đầu; mắt hé không tính |
| `biometric_service_test.dart` | Khoá vân tay với phần native giả lập: bật lưu bản mã (không lưu mã gốc), mở khoá đúng/sai mã, **vân tay trên máy thay đổi → tự tắt**, bấm Huỷ giữ khoá, kiểm tra khoá khi mở Trang chủ, tắt xoá khoá, dữ liệu bản cũ coi như chưa bật |
| `ui_layout_test.dart` | (dùng Firebase giả) Màn hình ở 360dp sáng/tối không tràn; **nút vân tay cạnh ô mật khẩu** (cả khi chưa dùng được: bấm thì hướng dẫn đăng nhập bằng mật khẩu / bật vân tay); **gõ tài khoản khác rồi bấm vân tay/khuôn mặt → "Sai tài khoản"**, không mở camera, không vào tài khoản trên máy; gõ email của tài khoản trên máy thì vẫn dùng được; **đăng nhập bằng tên** (tra trên Firebase, không phân biệt hoa thường; máy mới chưa có hồ sơ; mất mạng thì dùng hồ sơ trên máy); sai mật khẩu; đăng nhập tài khoản khác xoá vân tay/khuôn mặt cũ; **đăng ký → lưu hồ sơ → Trang chủ**; tên đăng nhập trùng bị từ chối; gửi email xác minh lỗi vẫn vào Trang chủ và gửi lại được sau 1 phút; **quên mật khẩu → gửi email**; **đổi mật khẩu** (sai/đúng mật khẩu hiện tại); **đăng xuất giữ vân tay/khuôn mặt**; xoá tài khoản khỏi máy (dữ liệu
Firebase vẫn còn); **khuôn mặt đưa lên Firebase** và **máy mới tự tải khuôn mặt về** |

Test dùng `FlutterSecureStorage.setMockInitialValues({})` để thay bộ nhớ thật bằng bộ nhớ giả. Phần camera, ML Kit và TFLite cần thiết bị thật nên phải thử thủ công theo mục 8.

## 11. Bảo mật

- **Mật khẩu không lưu trên máy**: Firebase Authentication kiểm tra mật khẩu trên máy chủ (băm bằng scrypt). Trên máy chỉ lưu
  hồ sơ (tên, email) để đổi tên đăng nhập thành email và điền sẵn khi quên mật khẩu.
- Email xác minh và email đặt lại mật khẩu do Firebase gửi; đổi mật khẩu phải nhập đúng mật khẩu hiện tại.
- Bảng **`usernames`** trên Firestore: ai biết một tên đăng nhập thì tra được email của tên đó (cần thiết để đăng nhập
  bằng tên khi chưa đăng nhập), nhưng **không liệt kê được cả bảng**; chỉ chủ tài khoản mới tạo/xoá được tên của mình,
  không ai ghi đè tên đã có người dùng (xem [firestore.rules](firestore.rules)). Muốn giấu hẳn email thì phải chuyển
  bước đăng nhập bằng tên lên Cloud Functions (cần gói Blaze).
- Mọi dữ liệu lưu bằng `flutter_secure_storage`, mã hoá bằng khoá trong **Android Keystore**.
- **Cách A**: dữ liệu vân tay **không bao giờ đi vào app**. App chỉ lưu bản mã của một mã bí mật ngẫu nhiên; chỉ khoá trong
  Android Keystore (mở bằng vân tay hợp lệ qua CryptoObject) mới giải mã được. Thêm/xoá vân tay trên máy làm khoá bị huỷ.
- **Cách B**: app chỉ lưu **vector 512 số**, không lưu ảnh; ảnh chụp tạm bị xoá ngay sau khi xử lý. Việc nhận diện chạy
  **offline trên máy**, không gửi ảnh lên mạng. Vector được sao lưu vào tài khoản Firebase (`users/{uid}`, chỉ chủ tài khoản
  đọc/ghi được – xem [firestore.rules](firestore.rules)) để dùng trên máy khác; xoá khuôn mặt ở Trang chủ thì xoá cả bản trên Firebase.
  Vector khuôn mặt vẫn là dữ liệu sinh trắc học – ứng dụng thật cần hỏi ý kiến người dùng trước khi sao lưu lên mạng.
- Vân tay/khuôn mặt chỉ mở khoá **phiên đăng nhập Firebase đã có trên máy**: lần đầu trên mỗi máy (hoặc sau khi *Xoá tài khoản
  khỏi máy*) bắt buộc nhập mật khẩu. **Đăng xuất** giữ phiên để lần sau dùng vân tay/khuôn mặt; đổi mật khẩu ở máy khác làm
  phiên hết hạn và phải nhập mật khẩu lại. Đăng nhập sang tài khoản khác thì khoá vân tay và khuôn mặt cũ trên máy bị xoá.
  Với ứng dụng thật nên:
  - Bật **Email Enumeration Protection** và **App Check** trong Firebase để tránh dò email và lạm dụng.
  - Với Cách B, dùng kiểm tra người thật mạnh hơn (camera 3D, hoặc dịch vụ liveness chuyên dụng).

## 12. Xử lý sự cố thường gặp

| Lỗi / hiện tượng | Nguyên nhân | Cách xử lý |
|---|---|---|
| App crash hoặc báo lỗi khi hiện hộp thoại vân tay; `MissingPluginException` kênh `faceid/biometric_lock` | `MainActivity` vẫn kế thừa `FlutterActivity` hoặc chưa đăng ký kênh | Làm đúng mục 4.1 |
| *Vân tay trên máy đã thay đổi…*, công tắc Vân tay tự tắt | Đã thêm hoặc xoá vân tay trong Cài đặt sau khi bật; Android huỷ khoá (đúng thiết kế) | Đăng nhập bằng mật khẩu rồi bật lại công tắc Vân tay |
| Công tắc Vân tay mờ dù máy có face unlock | App chỉ nhận sinh trắc loại mạnh (Class 3); face unlock của đa số máy không đạt | Đăng ký vân tay, hoặc dùng **Cách B** |
| `uses-sdk:minSdkVersion ... cannot be smaller than version 24` | `minSdk` quá thấp | `minSdk = 24` (mục 4.3) |
| App crash khi hiện hộp thoại trên Android 8- | Theme không phải AppCompat | Đổi `LaunchTheme` (mục 4.4) |
| `Inconsistent JVM Target Compatibility` ở `:tflite_flutter` | Plugin đặt Java 11 nhưng Kotlin theo JDK | Cấu hình ở mục 4.5 |
| `this and base files have different roots` | Project và pub cache khác ổ đĩa (Windows) | `kotlin.incremental=false` (mục 4.6) |
| *Chưa có vân tay nào trên máy* (`NOT_ENROLLED`) | Thiết bị chưa đăng ký vân tay | Cài đặt → Bảo mật → thêm vân tay |
| *Thiết bị chưa đặt khoá màn hình* (`NO_CREDENTIAL`) | Chưa có PIN/mật khẩu màn hình | Đặt khoá màn hình trước |
| *Vân tay bị khoá tạm thời* / *Vân tay bị khoá* (`LOCKOUT`, `LOCKOUT_PERMANENT`) | Quét sai nhiều lần | Đợi ~30 giây, hoặc mở khoá màn hình bằng PIN |
| *Chưa cấp quyền camera* | Đã từ chối quyền camera | Cài đặt → Ứng dụng → faceid → Quyền → Camera → Cho phép |
| *Không tải được model nhận diện* | Thiếu file `.tflite` hoặc chưa khai báo assets | Kiểm tra `assets/models/facenet_512.tflite` và `pubspec.yaml` (mục 3), chạy lại `flutter run` (không dùng hot reload) |
| Mãi không qua bước *Hãy nháy mắt* | Thiếu sáng, mặt quá xa, đeo kính phản quang | Tăng ánh sáng, đưa mặt gần hơn, nháy mắt chậm và rõ |
| *Khuôn mặt không khớp* dù là chính chủ, hoặc lúc được lúc không | Ánh sáng/góc khác lúc đăng ký, ngưỡng quá chặt, hoặc vẫn dùng mẫu đăng ký cũ | Đăng ký lại khuôn mặt ở nơi đủ sáng; dùng nút **Thử** đo khoảng cách nhiều lần rồi chọn **Mức an toàn** phù hợp (mục 7.3) |
| Người khác đăng nhập được bằng khuôn mặt của mình | Bản cũ dùng ngưỡng 0,95 – người có nét giống lọt ~21% mỗi lần thử | Cập nhật app (model FaceNet-512, mức *Cao* 0,65) rồi **đăng ký lại khuôn mặt**; nếu vẫn lọt, chọn *Rất cao* (mục 7.3) |
| Màn hình đỏ *'_dependents.isEmpty': is not true* / *Duplicate keys found* sau khi quét khuôn mặt | Bản cũ: câu hướng dẫn đổi quá nhanh làm trùng khoá trong `AnimatedSwitcher` | Đã sửa bằng `FadingStatusText` (khoá đếm tăng dần) – cập nhật app |
| Báo *Hãy nhìn thẳng…* / *Hãy mở mắt khi chụp* rồi quay lại bước 1 | Ảnh chụp không đạt kiểm tra chất lượng | Giữ đầu thẳng, mắt mở, đứng yên khi thanh tiến trình chạy |
| Sau khi cập nhật app, khuôn mặt hiện *Chưa đăng ký* | Mẫu cũ (chưa căn thẳng) bị bỏ vì không còn tương thích | Bấm **Đăng ký** lại |
| *Sai khuôn mặt quá nhiều lần* | 3 lần không khớp liên tiếp | Đăng nhập bằng mật khẩu (bộ đếm reset khi mở lại app) |
| Màn *Cần cấu hình Firebase* | Chưa có `android/app/google-services.json` | Làm mục 4.8, rồi `flutter clean` và `flutter run` |
| *Đăng nhập bằng Email/Password chưa được bật* (`operation-not-allowed`) | Chưa bật Email/Password | Firebase Console → Authentication → Sign-in method |
| *Email này đã được dùng cho tài khoản khác* | Email đã đăng ký trước đó | Đăng nhập bằng email đó, hoặc dùng **Quên mật khẩu?** |
| *Không có tài khoản nào tên …* | Gõ sai tên, hoặc tài khoản tạo trước khi có bảng tên đăng nhập | Kiểm tra lại tên; tài khoản cũ: đăng nhập bằng **email** một lần để app tự thêm tên lên Firestore |
| *Chưa tạo Cloud Firestore…* | Chưa làm bước 5 mục 4.8 (máy chủ báo `Cloud Firestore API has not been used…`) | Firestore Database → **Create database** |
| *Firestore từ chối truy cập bảng tên đăng nhập…* (`permission-denied`) | Chưa dán luật, hoặc vẫn để luật mặc định | Bước 6 mục 4.8: dán `firestore.rules` → **Publish** |
| *Tên đăng nhập này đã có người dùng* | Tên (không phân biệt hoa thường) đã được tài khoản khác giữ | Chọn tên khác |
| Máy mới không tự tải khuôn mặt về; log có *Chưa đồng bộ được khuôn mặt… permission-denied* | Rules trên Firebase là bản cũ (chưa có `users/{uid}`), hoặc chưa đăng ký khuôn mặt ở máy nào | Dán lại `firestore.rules` → **Publish**; mở Trang chủ ở máy đã đăng ký để app đưa khuôn mặt lên |
| Hộp thoại *Sai tài khoản* khi bấm vân tay/khuôn mặt | Ô tên đăng nhập đang ghi tài khoản khác với tài khoản đã đăng ký vân tay/khuôn mặt trên máy | Sửa lại tên đăng nhập, hoặc đăng nhập tài khoản kia bằng mật khẩu |
| Bấm nút vân tay chỉ hiện hướng dẫn | Lần đầu trên máy / chưa bật vân tay trên máy này (nút màu nhạt) | Đăng nhập bằng mật khẩu → Trang chủ → bật **Vân tay** |
| Không nhận được email xác minh | Thư (từ `noreply@<project-id>.firebaseapp.com`) vào mục Spam/Quảng cáo, hoặc đến chậm vài phút; thư chứa **đường dẫn** để bấm, không có mã số | Kiểm tra Spam; đợi 1 phút rồi bấm **Gửi lại email** ở Trang chủ; xem lỗi thật bằng `adb logcat \| findstr AuthFailure` |
| *Đã tạo tài khoản nhưng chưa gửi được email xác minh* | Tài khoản đã tạo, chỉ bước gửi thư bị lỗi (thường là `too-many-requests`) | Vào Trang chủ, đợi vài phút rồi bấm **Gửi lại email** |
| *Firebase tạm chặn vì thao tác quá nhiều lần* (`too-many-requests`) | Sai mật khẩu nhiều lần hoặc gửi email liên tục | Đợi vài phút rồi thử lại (app khoá nút gửi lại 1 phút sau mỗi lần gửi) |

## 13. Kế hoạch phát triển

| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| 1. Khởi tạo | Tạo project Flutter, cài `local_auth`, `flutter_secure_storage`, `crypto` | ✅ Xong |
| 2. Cấu hình Android | `FlutterFragmentActivity`, quyền `USE_BIOMETRIC`, `minSdk 24`, theme AppCompat, `kotlin.incremental=false` | ✅ Xong |
| 3. Tầng service | `StorageService`, `BiometricService` (thông báo lỗi tiếng Việt) | ✅ Xong |
| 4. Giao diện | Đăng ký, Đăng nhập, Trang chủ (bật/tắt sinh trắc) | ✅ Xong |
| 5. Nhận diện khuôn mặt bằng camera | Cài `camera`, `google_mlkit_face_detection`, `tflite_flutter`, `image`; thêm model nhận diện (MobileFaceNet, sau đổi sang FaceNet-512); quyền `CAMERA`; sửa JVM target cho `tflite_flutter`; `FaceRecognitionService`, `LivenessChecker`, `FaceScanScreen`; đăng ký/đăng nhập bằng khuôn mặt | ✅ Xong |
| 6. Giao diện | Theme Material 3 sáng/tối tông xanh navy; banner thương hiệu + thẻ form nổi; Đăng nhập: ô tên đăng nhập, **ô mật khẩu kèm nút vân tay bên cạnh**, nút đăng nhập bằng khuôn mặt; Trang chủ dạng nhóm cài đặt; màn quét khuôn mặt toàn màn hình có khung oval và 3 bước | ✅ Xong |
| 7. Ổn định nhận diện | Căn thẳng khuôn mặt theo 2 mắt, kiểm tra chất lượng ảnh, đăng ký 5 ảnh, đăng nhập lấy ảnh tốt nhất trong 2, nút **Thử** đo khoảng cách, tắt Auto Backup, bỏ mẫu cũ (`face_embedding_v2`) | ✅ Xong |
| 8. Khoá vân tay theo tập vân tay trên máy | `BiometricLock.java` (Keystore + `setInvalidatedByBiometricEnrollment` + CryptoObject), `BiometricService` gọi qua MethodChannel, tự tắt khi vân tay thay đổi, chỉ nhận Class 3 | ✅ Xong |
| 9. Sửa luồng nhận diện | ML Kit và bước cắt ảnh dùng chung mảng pixel đã xoay theo EXIF (`decodeUpright` + `InputImage.fromBitmap`); loại ảnh mặt quá nhỏ; gửi ML Kit ảnh BGRA để không bị đảo màu; **đo model trên LFW** → xác nhận tiền xử lý đúng, giới hạn 3 lần sai | ✅ Xong |
| 10. Kiểm thử | `flutter analyze`, 70 unit/widget test (gồm bố cục 360dp, vị trí nút vân tay, xoay ảnh theo EXIF, căn thẳng khuôn mặt, khoá vân tay với phần native giả lập), build APK debug + release | ✅ Xong; chạy thử trên điện thoại thật: tự thực hiện theo mục 8 và chỉnh ngưỡng theo mục 7.3 |
| 11. Tài khoản Firebase (chỉ email) | Đăng ký bằng email; đăng nhập email/tên + mật khẩu; quên mật khẩu qua email; email xác minh (gửi riêng, chống gửi dồn); đổi mật khẩu; đăng xuất; test với Firebase giả | ✅ Xong, đã chạy trên điện thoại thật |
| 12. Tên đăng nhập trên máy chủ | Bảng `usernames` trên Cloud Firestore + `firestore.rules`; đăng nhập bằng tên trên mọi máy; chặn tên trùng; tự thêm tên cho tài khoản cũ | ✅ Code xong – **cần bạn tạo Firestore (mục 4.8 bước 5–6)** |
| 13. Đăng nhập nhiều cách, nhiều máy | Nút vân tay luôn cạnh ô mật khẩu (lần đầu hướng dẫn nhập mật khẩu); **Đăng xuất** giữ vân tay/khuôn mặt, thêm **Xoá tài khoản khỏi máy**; vector khuôn mặt lưu trong tài khoản (`users/{uid}`) và tự tải về máy mới | ✅ Code xong – **cần dán lại `firestore.rules` (mục 4.8 bước 6)** |
| 14. Chống nhận nhầm người | Đo lại trên LFW với **người giống nhất** (ngưỡng cũ 0,95 cho lọt ~21%/lần); thêm **Mức an toàn**; ghi khoảng cách ra log, lưu ảnh đã cắt ở bản debug; **đổi model sang FaceNet-512** (người giống nhất lọt ít hơn 15–20 lần ở cùng mức tiện lợi), Cơ bản 0,75 / Cao 0,65 / Rất cao 0,55 | ✅ Xong – cần đăng ký lại khuôn mặt |
| 15. Logo ứng dụng | Logo khiên + vân tay tông navy; icon thường, icon thích ứng, icon đơn sắc (Android 13+) bằng `flutter_launcher_icons`; script vẽ logo `tool/make_icon.py` | ✅ Xong |
| 16. Mở rộng (tuỳ chọn) | Tự khoá app khi chạy nền, liveness mạnh hơn (quay đầu ngẫu nhiên), hỗ trợ iOS Face ID (cần máy Mac + `NSFaceIDUsageDescription`) | ⏳ Chưa làm |
