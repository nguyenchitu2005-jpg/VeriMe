package com.example.faceid;

import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyPermanentlyInvalidatedException;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import androidx.annotation.NonNull;
import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.FragmentActivity;

import java.security.KeyStore;
import java.security.SecureRandom;
import java.util.HashMap;
import java.util.Map;

import javax.crypto.AEADBadTagException;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Khoá đăng nhập bằng vân tay gắn với tập vân tay đang có trên máy.
 *
 * Khi bật: tạo khoá AES trong Android Keystore với setInvalidatedByBiometricEnrollment(true),
 * chỉ dùng được sau khi xác thực sinh trắc loại mạnh (Class 3). Người dùng quét vân tay để
 * mã hoá một mã bí mật ngẫu nhiên; app lưu bản mã.
 *
 * Khi đăng nhập: quét vân tay để giải mã. Nếu sau khi bật có vân tay được thêm hoặc xoá,
 * Android huỷ khoá vĩnh viễn (KeyPermanentlyInvalidatedException) và app báo KEY_INVALIDATED.
 *
 * Kênh: "faceid/biometric_lock". Lỗi trả về Dart qua PlatformException với các mã:
 * CANCELED, LOCKOUT, LOCKOUT_PERMANENT, NOT_ENROLLED, NO_HARDWARE, NO_CREDENTIAL, TIMEOUT,
 * KEY_INVALIDATED, KEY_MISSING, DECRYPT_FAILED, KEY_ERROR, AUTH_ERROR.
 */
final class BiometricLock implements MethodChannel.MethodCallHandler {
    static final String CHANNEL = "faceid/biometric_lock";

    private static final String KEYSTORE = "AndroidKeyStore";
    private static final String KEY_ALIAS = "faceid_biometric_lock";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int GCM_TAG_BITS = 128;
    private static final int TOKEN_BYTES = 32;
    private static final int STRONG = BiometricManager.Authenticators.BIOMETRIC_STRONG;

    private final FragmentActivity activity;

    BiometricLock(FragmentActivity activity) {
        this.activity = activity;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "status":
                result.success(status());
                break;
            case "keyState":
                result.success(keyState());
                break;
            case "enable":
                enable(call, result);
                break;
            case "unlock":
                unlock(call, result);
                break;
            case "disable":
                deleteKey();
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }

    /** Thiết bị có dùng được sinh trắc loại mạnh (vân tay Class 3) không. */
    private String status() {
        switch (BiometricManager.from(activity).canAuthenticate(STRONG)) {
            case BiometricManager.BIOMETRIC_SUCCESS:
                return "available";
            case BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED:
                return "notEnrolled";
            case BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE:
                return "noHardware";
            default:
                return "unavailable";
        }
    }

    /**
     * Kiểm tra khoá mà không hiện hộp thoại: "valid", "invalidated" (vân tay trên máy đã thay đổi),
     * "missing" (chưa có khoá) hoặc "error".
     * Với khoá yêu cầu xác thực mỗi lần dùng, cipher.init() không cần quét vân tay nhưng sẽ ném
     * KeyPermanentlyInvalidatedException nếu khoá đã bị huỷ.
     */
    private String keyState() {
        try {
            SecretKey key = getKey();
            if (key == null) return "missing";
            Cipher.getInstance(TRANSFORMATION).init(Cipher.ENCRYPT_MODE, key);
            return "valid";
        } catch (KeyPermanentlyInvalidatedException e) {
            deleteKey();
            return "invalidated";
        } catch (Exception e) {
            return "error";
        }
    }

    private void enable(MethodCall call, MethodChannel.Result result) {
        final Cipher cipher;
        try {
            deleteKey();
            generateKey();
            cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, getKey());
        } catch (Exception e) {
            deleteKey();
            result.error("KEY_ERROR", e.getMessage(), null);
            return;
        }
        authenticate(call, cipher, result, authorized -> {
            byte[] token = new byte[TOKEN_BYTES];
            new SecureRandom().nextBytes(token);
            byte[] ciphertext = authorized.doFinal(token);
            Map<String, String> data = new HashMap<>();
            data.put("token", encode(token));
            data.put("iv", encode(authorized.getIV()));
            data.put("ciphertext", encode(ciphertext));
            return data;
        }, true);
    }

    private void unlock(MethodCall call, MethodChannel.Result result) {
        final String iv = call.argument("iv");
        final String ciphertext = call.argument("ciphertext");
        final Cipher cipher;
        try {
            SecretKey key = getKey();
            if (key == null) {
                result.error("KEY_MISSING", "Biometric key not found", null);
                return;
            }
            cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(GCM_TAG_BITS, decode(iv)));
        } catch (KeyPermanentlyInvalidatedException e) {
            deleteKey();
            result.error("KEY_INVALIDATED", "Biometric enrollment changed", null);
            return;
        } catch (Exception e) {
            result.error("KEY_ERROR", e.getMessage(), null);
            return;
        }
        authenticate(call, cipher, result, authorized -> encode(authorized.doFinal(decode(ciphertext))), false);
    }

    private interface CipherAction {
        Object run(Cipher authorizedCipher) throws Exception;
    }

    /** Hiện hộp thoại vân tay gắn với [cipher]; chỉ khi quét đúng, cipher mới dùng được. */
    private void authenticate(
            MethodCall call,
            Cipher cipher,
            MethodChannel.Result result,
            CipherAction onSuccess,
            boolean deleteKeyOnFailure) {
        final boolean[] replied = {false};
        BiometricPrompt prompt = new BiometricPrompt(
                activity,
                ContextCompat.getMainExecutor(activity),
                new BiometricPrompt.AuthenticationCallback() {
                    @Override
                    public void onAuthenticationSucceeded(@NonNull BiometricPrompt.AuthenticationResult auth) {
                        if (replied[0]) return;
                        replied[0] = true;
                        BiometricPrompt.CryptoObject crypto = auth.getCryptoObject();
                        Cipher authorized = crypto == null ? null : crypto.getCipher();
                        if (authorized == null) {
                            if (deleteKeyOnFailure) deleteKey();
                            result.error("AUTH_ERROR", "Missing crypto object", null);
                            return;
                        }
                        try {
                            result.success(onSuccess.run(authorized));
                        } catch (AEADBadTagException e) {
                            if (deleteKeyOnFailure) deleteKey();
                            result.error("DECRYPT_FAILED", e.getMessage(), null);
                        } catch (KeyPermanentlyInvalidatedException e) {
                            deleteKey();
                            result.error("KEY_INVALIDATED", e.getMessage(), null);
                        } catch (Exception e) {
                            if (deleteKeyOnFailure) deleteKey();
                            result.error("KEY_ERROR", e.getMessage(), null);
                        }
                    }

                    @Override
                    public void onAuthenticationError(int errorCode, @NonNull CharSequence message) {
                        if (replied[0]) return;
                        replied[0] = true;
                        if (deleteKeyOnFailure) deleteKey();
                        result.error(errorCodeName(errorCode), message.toString(), null);
                    }

                    // onAuthenticationFailed: một lần quét sai, hộp thoại vẫn mở để thử lại – không trả kết quả.
                });

        BiometricPrompt.PromptInfo info = new BiometricPrompt.PromptInfo.Builder()
                .setTitle(argument(call, "title", "Xác thực vân tay"))
                .setSubtitle(argument(call, "subtitle", null))
                .setNegativeButtonText(argument(call, "cancel", "Huỷ"))
                .setAllowedAuthenticators(STRONG)
                .build();
        prompt.authenticate(info, new BiometricPrompt.CryptoObject(cipher));
    }

    private static String errorCodeName(int code) {
        switch (code) {
            case BiometricPrompt.ERROR_USER_CANCELED:
            case BiometricPrompt.ERROR_NEGATIVE_BUTTON:
            case BiometricPrompt.ERROR_CANCELED:
                return "CANCELED";
            case BiometricPrompt.ERROR_LOCKOUT:
                return "LOCKOUT";
            case BiometricPrompt.ERROR_LOCKOUT_PERMANENT:
                return "LOCKOUT_PERMANENT";
            case BiometricPrompt.ERROR_NO_BIOMETRICS:
                return "NOT_ENROLLED";
            case BiometricPrompt.ERROR_HW_NOT_PRESENT:
            case BiometricPrompt.ERROR_HW_UNAVAILABLE:
                return "NO_HARDWARE";
            case BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL:
                return "NO_CREDENTIAL";
            case BiometricPrompt.ERROR_TIMEOUT:
                return "TIMEOUT";
            default:
                return "AUTH_ERROR";
        }
    }

    @SuppressWarnings("deprecation")
    private static void generateKey() throws Exception {
        KeyGenParameterSpec.Builder builder = new KeyGenParameterSpec.Builder(
                KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(true)
                // Thêm hoặc xoá vân tay trên máy => khoá bị huỷ vĩnh viễn.
                .setInvalidatedByBiometricEnrollment(true);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // 0 giây: phải quét vân tay cho mỗi lần dùng khoá; chỉ chấp nhận sinh trắc loại mạnh.
            builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG);
        } else {
            builder.setUserAuthenticationValidityDurationSeconds(-1);
        }
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE);
        generator.init(builder.build());
        generator.generateKey();
    }

    private static SecretKey getKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance(KEYSTORE);
        keyStore.load(null);
        return (SecretKey) keyStore.getKey(KEY_ALIAS, null);
    }

    private static void deleteKey() {
        try {
            KeyStore keyStore = KeyStore.getInstance(KEYSTORE);
            keyStore.load(null);
            keyStore.deleteEntry(KEY_ALIAS);
        } catch (Exception ignored) {
            // Không có khoá để xoá.
        }
    }

    private static String argument(MethodCall call, String name, String fallback) {
        String value = call.argument(name);
        return value != null ? value : fallback;
    }

    private static String encode(byte[] bytes) {
        return Base64.encodeToString(bytes, Base64.NO_WRAP);
    }

    private static byte[] decode(String text) {
        return Base64.decode(text, Base64.NO_WRAP);
    }
}
