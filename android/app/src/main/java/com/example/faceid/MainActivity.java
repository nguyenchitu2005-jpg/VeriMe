package com.example.faceid;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

// local_auth và BiometricLock cần FragmentActivity để hiển thị BiometricPrompt.
public class MainActivity extends FlutterFragmentActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BiometricLock.CHANNEL)
                .setMethodCallHandler(new BiometricLock(this));
    }
}
