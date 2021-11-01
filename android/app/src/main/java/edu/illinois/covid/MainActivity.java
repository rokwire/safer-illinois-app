/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package edu.illinois.covid;

import android.Manifest;
import android.app.Application;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.location.LocationManager;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.google.firebase.FirebaseApp;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.MultiFormatWriter;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.journeyapps.barcodescanner.BarcodeEncoder;

import java.io.ByteArrayOutputStream;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import edu.illinois.covid.gallery.GalleryPlugin;

import edu.illinois.covid.maps.MapActivity;
import edu.illinois.covid.maps.MapDirectionsActivity;
import edu.illinois.covid.maps.MapViewFactory;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

public class MainActivity extends FlutterActivity implements MethodChannel.MethodCallHandler, PluginRegistry.PluginRegistrantCallback {

    private static final String TAG = "MainActivity";

    private final int REQUEST_LOCATION_PERMISSION_CODE = 1;

    private static MethodChannel METHOD_CHANNEL;
    private static final String NATIVE_CHANNEL = "edu.illinois.covid/core";
    private static MainActivity instance = null;

    private HashMap keys;

    private int preferredScreenOrientation;
    private Set<Integer> supportedScreenOrientations;

    private RequestLocationCallback rlCallback;

    // Gallery Plugin
    private GalleryPlugin galleryPlugin;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        instance = this;
        initScreenOrientation();
    }

    public static MainActivity getInstance() {
        return instance;
    }

    public App getApp() {
        Application application = getApplication();
        return (application instanceof App) ? (App) application : null;
    }

    public static void invokeFlutterMethod(String methodName, Object arguments) {
        if (METHOD_CHANNEL != null) {
            getInstance().runOnUiThread(() -> METHOD_CHANNEL.invokeMethod(methodName, arguments));
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);

        if (requestCode == REQUEST_LOCATION_PERMISSION_CODE) {
            boolean granted;
            if (grantResults.length > 1 &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED && grantResults[1] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "granted");
                granted = true;
            } else {
                Log.d(TAG, "not granted");
                granted = false;
            }
            if (rlCallback != null) {
                rlCallback.onResult(granted);
                rlCallback = null;
            }
        } else if(requestCode == GalleryPlugin.STORAGE_PERMISSION_REQUEST_CODE){
            galleryPlugin.onRequestPermissionsResult(requestCode, permissions, grantResults);
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        METHOD_CHANNEL = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), NATIVE_CHANNEL);
        METHOD_CHANNEL.setMethodCallHandler(this);

        flutterEngine
                .getPlatformViewsController()
                .getRegistry()
                .registerViewFactory("mapview", new MapViewFactory(this, flutterEngine.getDartExecutor().getBinaryMessenger()));

        galleryPlugin = new GalleryPlugin(this);
        flutterEngine.getPlugins().add(galleryPlugin);
    }

    private void initScreenOrientation() {
        preferredScreenOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT;
        supportedScreenOrientations = new HashSet<>(Collections.singletonList(preferredScreenOrientation));
    }

    private void initWithParams(Object keys) {
        HashMap keysMap = null;
        if (keys instanceof HashMap) {
            keysMap = (HashMap) keys;
        }
        if (keysMap == null) {
            return;
        }
        this.keys = keysMap;
    }

    private void launchMapsDirections(Object explore, Object options) {
        Intent intent = new Intent(this, MapDirectionsActivity.class);
        if (explore instanceof HashMap) {
            HashMap singleExplore = (HashMap) explore;
            intent.putExtra("explore", singleExplore);
        } else if (explore instanceof ArrayList) {
            ArrayList exploreList = (ArrayList) explore;
            intent.putExtra("explore", exploreList);
        }
        HashMap optionsMap = (options instanceof HashMap) ? (HashMap) options : null;
        if (optionsMap != null) {
            intent.putExtra("options", optionsMap);
        }
        startActivity(intent);
    }

    private void launchMap(Object target, Object options, Object markers) {
        HashMap targetMap = (target instanceof HashMap) ? (HashMap) target : null;
        HashMap optionsMap = (options instanceof HashMap) ? (HashMap) options : null;
        ArrayList<HashMap> markersValues = (markers instanceof  ArrayList) ? ( ArrayList<HashMap>) markers : null;
        Intent intent = new Intent(this, MapActivity.class);
        Bundle serializableExtras = new Bundle();
        serializableExtras.putSerializable("target", targetMap);
        serializableExtras.putSerializable("options", optionsMap);
        serializableExtras.putSerializable("markers", markersValues);
        intent.putExtras(serializableExtras);
        startActivity(intent);
    }

    private void launchNotification(MethodCall methodCall) {
        String title = methodCall.argument("title");
        String body = methodCall.argument("body");
        App app = getApp();
        if (app != null) {
            app.showNotification(title, body);
        }
    }

    private void requestLocationPermission(MethodChannel.Result result) {
        Utils.AppSharedPrefs.saveBool(this, Constants.LOCATION_PERMISSIONS_REQUESTED_KEY, true);
        //check if granted
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED  ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "request permission");

            rlCallback = new RequestLocationCallback() {
                @Override
                public void onResult(boolean granted) {
                    if (granted) {
                        result.success("allowed");
                    } else {
                        result.success("denied");
                    }
                }
            };

            ActivityCompat.requestPermissions(MainActivity.this,
                    new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION},
                    REQUEST_LOCATION_PERMISSION_CODE);
        } else {
            Log.d(TAG, "already granted");
            result.success("allowed");
        }
    }

    private String getLocationServicesStatus() {
        boolean locationServicesEnabled;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // This is new method provided in API 28
            LocationManager lm = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
            locationServicesEnabled = ((lm != null) && lm.isLocationEnabled());
        } else {
            // This is Deprecated in API 28
            int mode = Settings.Secure.getInt(getContentResolver(), Settings.Secure.LOCATION_MODE,
                    Settings.Secure.LOCATION_MODE_OFF);
            locationServicesEnabled = (mode != Settings.Secure.LOCATION_MODE_OFF);
        }
        if (locationServicesEnabled) {
            if ((ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
                    ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED)) {
                return "allowed";
            } else {
                boolean locationPermissionRequested = Utils.AppSharedPrefs.getBool(this, Constants.LOCATION_PERMISSIONS_REQUESTED_KEY, false);
                return locationPermissionRequested ? "denied" : "not_determined";
            }
        } else {
            return "disabled";
        }
    }

    private List<String> handleEnabledOrientations(Object orientations) {
        List<String> resultList = new ArrayList<>();
        if (preferredScreenOrientation != ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED) {
            resultList.add(getScreenOrientationToString(preferredScreenOrientation));
        }
        if (supportedScreenOrientations != null && !supportedScreenOrientations.isEmpty()) {
            for (int supportedOrientation : supportedScreenOrientations) {
                if (supportedOrientation != preferredScreenOrientation) {
                    resultList.add(getScreenOrientationToString(supportedOrientation));
                }
            }
        }
        List<String> orientationsList;
        if (orientations instanceof List) {
            orientationsList = (List<String>) orientations;
            int preferredOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED;
            Set<Integer> supportedOrientations = new HashSet<>();
            for (String orientationString : orientationsList) {
                int orientation = getScreenOrientationFromString(orientationString);
                if (orientation != ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED) {
                    supportedOrientations.add(orientation);
                    if (preferredOrientation == ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED) {
                        preferredOrientation = orientation;
                    }
                }
            }
            if ((preferredOrientation != ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED) && (preferredScreenOrientation != preferredOrientation)) {
                preferredScreenOrientation = preferredOrientation;
            }
            if ((supportedOrientations.size() > 0) && !supportedOrientations.equals(supportedScreenOrientations)) {
                supportedScreenOrientations = supportedOrientations;
                int currentOrientation = getRequestedOrientation();
                if (!supportedScreenOrientations.contains(currentOrientation)) {
                    setRequestedOrientation(preferredScreenOrientation);
                }
            }
        }
        return resultList;
    }

    private String getScreenOrientationToString(int orientationValue) {
        switch (orientationValue) {
            case ActivityInfo.SCREEN_ORIENTATION_PORTRAIT:
                return "portraitUp";
            case ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT:
                return "portraitDown";
            case ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE:
                return "landscapeLeft";
            case ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE:
                return "landscapeRight";
            default:
                return null;
        }
    }

    private String getDeviceId(){
        String deviceId = "";
        try
        {
            UUID uuid;
            final String androidId = Settings.Secure.getString(getContentResolver(), Settings.Secure.ANDROID_ID);
            uuid = UUID.nameUUIDFromBytes(androidId.getBytes("utf8"));
            deviceId = uuid.toString();
        }
        catch (Exception e)
        {
            Log.d(TAG, "Failed to generate uuid");
        }
        return deviceId;
    }

    private int getScreenOrientationFromString(String orientationString) {
        if (Utils.Str.isEmpty(orientationString)) {
            return ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED;
        }
        switch (orientationString) {
            case "portraitUp":
                return ActivityInfo.SCREEN_ORIENTATION_PORTRAIT;
            case "portraitDown":
                return ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT;
            case "landscapeLeft":
                return ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE;
            case "landscapeRight":
                return ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE;
            default:
                return ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED;
        }
    }

    private String handleBarcode(Object params) {
        String barcodeImageData = null;
        String content = Utils.Map.getValueFromPath(params, "content", null);
        String format = Utils.Map.getValueFromPath(params, "format", null);
        int width = Utils.Map.getValueFromPath(params, "width", 0);
        int height = Utils.Map.getValueFromPath(params, "height", 0);
        BarcodeFormat barcodeFormat = null;
        if (!Utils.Str.isEmpty(format)) {
            switch (format) {
                case "aztec":
                    barcodeFormat = BarcodeFormat.AZTEC;
                    break;
                case "codabar":
                    barcodeFormat = BarcodeFormat.CODABAR;
                    break;
                case "code39":
                    barcodeFormat = BarcodeFormat.CODE_39;
                    break;
                case "code93":
                    barcodeFormat = BarcodeFormat.CODE_93;
                    break;
                case "code128":
                    barcodeFormat = BarcodeFormat.CODE_128;
                    break;
                case "dataMatrix":
                    barcodeFormat = BarcodeFormat.DATA_MATRIX;
                    break;
                case "ean8":
                    barcodeFormat = BarcodeFormat.EAN_8;
                    break;
                case "ean13":
                    barcodeFormat = BarcodeFormat.EAN_13;
                    break;
                case "itf":
                    barcodeFormat = BarcodeFormat.ITF;
                    break;
                case "maxiCode":
                    barcodeFormat = BarcodeFormat.MAXICODE;
                    break;
                case "pdf417":
                    barcodeFormat = BarcodeFormat.PDF_417;
                    break;
                case "qrCode":
                    barcodeFormat = BarcodeFormat.QR_CODE;
                    break;
                case "rss14":
                    barcodeFormat = BarcodeFormat.RSS_14;
                    break;
                case "rssExpanded":
                    barcodeFormat = BarcodeFormat.RSS_EXPANDED;
                    break;
                case "upca":
                    barcodeFormat = BarcodeFormat.UPC_A;
                    break;
                case "upce":
                    barcodeFormat = BarcodeFormat.UPC_E;
                    break;
                case "upceanExtension":
                    barcodeFormat = BarcodeFormat.UPC_EAN_EXTENSION;
                    break;
                default:
                    break;
            }
        }

        if (barcodeFormat != null) {
            MultiFormatWriter multiFormatWriter = new MultiFormatWriter();
            Bitmap bitmap = null;
            try {
                BitMatrix bitMatrix = multiFormatWriter.encode(content, barcodeFormat, width, height);
                BarcodeEncoder barcodeEncoder = new BarcodeEncoder();
                bitmap = barcodeEncoder.createBitmap(bitMatrix);
            } catch (WriterException e) {
                Log.e(TAG, "Failed to encode image:");
                e.printStackTrace();
            }
            if (bitmap != null) {
                ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream);
                byte[] byteArray = byteArrayOutputStream.toByteArray();
                if (byteArray != null) {
                    barcodeImageData = Base64.encodeToString(byteArray, Base64.NO_WRAP);
                }
            }
        }
        return barcodeImageData;
    }

    //region Health RSA keys

    private Object handleHealthRsaPrivateKey(Object params) {
        String userId = Utils.Map.getValueFromPath(params, "userId", null);
        if (Utils.Str.isEmpty(userId)) {
            return null;
        }
        String organization = Utils.Map.getValueFromPath(params, "organization", null);
        String environment = Utils.Map.getValueFromPath(params, "environment", null);
        String value = Utils.Map.getValueFromPath(params, "value", null);
        boolean remove = Utils.Map.getValueFromPath(params, "remove", false);
        List<String> source = Arrays.asList(Utils.Str.defaultEmpty(organization), Utils.Str.defaultEmpty(environment), Utils.Str.defaultEmpty(userId));
        List<String> keys = new ArrayList<>();
        processHealthRsaStorageKeysFromSource(source, 0, keys);

        if (Utils.Str.isEmpty(value)) {
            if (remove) {
                for (String key : keys) {
                    String existingValue = Utils.BackupStorage.getHealthString(this, key);
                    if (existingValue != null) {
                        Utils.BackupStorage.removeHealth(this, key);
                        return true;
                    }
                }
                return false;
            } else {
                for (String key : keys) {
                    String existingValue = Utils.BackupStorage.getHealthString(this, key);
                    if (existingValue != null) {
                        return existingValue;
                    }
                }
                return null;
            }
        } else {
            Utils.BackupStorage.saveHealthString(this, keys.get(0), value);
            return true;
        }
    }

    private void processHealthRsaStorageKeysFromSource(List<String> source, int index, List<String> keys) {
        if ((index + 1) < source.size()) {
            processHealthRsaStorageKeysFromSource(source, (index + 1), keys);
            String entry = source.get(index);
            if (!Utils.Str.isEmpty(entry)) {
                source.set(index, "");
                processHealthRsaStorageKeysFromSource(source, (index + 1), keys);
                source.set(index, entry);
            }
        } else {
            String key = getHealthRsaStorageKeyFromSource(source);
            keys.add(key);
        }
    }

    private String getHealthRsaStorageKeyFromSource(List<String> source) {
        StringBuilder result = new StringBuilder();
        if (source != null && !source.isEmpty()) {
            for (String sourceEntry : source) {
                if (!Utils.Str.isEmpty(sourceEntry)) {
                    if (result.length() > 0) {
                        result.append("-");
                    }
                    result.append(sourceEntry);
                }
            }
        }
        return (result.length() > 0) ? result.toString() : "";
    }

    //endregion

    //region Encryption key

    private Object handleEncryptionKey(Object params) {
        String name = Utils.Map.getValueFromPath(params, "name", null);
        if (Utils.Str.isEmpty(name)) {
            return null;
        }
        int keySize = Utils.Map.getValueFromPath(params, "size", 0);
        if (keySize <= 0) {
            return null;
        }
        String base64KeyValue = Utils.BackupStorage.getString(this, Constants.ENCRYPTION_SHARED_PREFS_FILE_NAME, name);
        byte[] encryptionKey = Utils.Base64.decode(base64KeyValue);
        if ((encryptionKey != null) && (encryptionKey.length == keySize)) {
            return base64KeyValue;
        } else {
            byte[] keyBytes = new byte[keySize];
            SecureRandom secRandom = new SecureRandom();
            secRandom.nextBytes(keyBytes);
            base64KeyValue = Utils.Base64.encode(keyBytes);
            Utils.BackupStorage.saveString(this, Constants.ENCRYPTION_SHARED_PREFS_FILE_NAME, name, base64KeyValue);
            return base64KeyValue;
        }
    }

    //endregion

    /**
     * Overrides {@link io.flutter.plugin.common.MethodChannel.MethodCallHandler} onMethodCall()
     */
    @Override
    public void onMethodCall(MethodCall methodCall, @NonNull MethodChannel.Result result) {
        String method = methodCall.method;
        try {
            switch (method) {
                case Constants.APP_INIT_KEY:
                    StringBuilder builder = new StringBuilder();
                    Object keysObject = methodCall.argument("keys");
                    initWithParams(keysObject);
                    result.success(true);
                    break;
                case Constants.MAP_DIRECTIONS_KEY:
                    Object explore = methodCall.argument("explore");
                    Object optionsObj = methodCall.argument("options");
                    launchMapsDirections(explore, optionsObj);
                    result.success(true);
                    break;
                case Constants.MAP_KEY:
                    Object target = methodCall.argument("target");
                    Object options = methodCall.argument("options");
                    Object markers = methodCall.argument("markers");
                    launchMap(target, options,markers);
                    result.success(true);
                    break;
                case Constants.SHOW_NOTIFICATION_KEY:
                    launchNotification(methodCall);
                    result.success(true);
                    break;
                case Constants.APP_DISMISS_SAFARI_VC_KEY:
                case Constants.APP_DISMISS_LAUNCH_SCREEN_KEY:
                case Constants.APP_ADD_CARD_TO_WALLET_KEY:
                    result.success(false);
                    break;
                case Constants.APP_ENABLED_ORIENTATIONS_KEY:
                    Object orientations = methodCall.argument("orientations");
                    List<String> orientationsList = handleEnabledOrientations(orientations);
                    result.success(orientationsList);
                    break;
                case Constants.APP_NOTIFICATIONS_AUTHORIZATION:
                    result.success(true); // notifications are allowed in Android by default
                    break;
                case Constants.APP_LOCATION_SERVICES_PERMISSION:
                    String locationServicesMethod = Utils.Map.getValueFromPath(methodCall.arguments, "method", null);
                    if ("query".equals(locationServicesMethod)) {
                        String locationServicesStatus = getLocationServicesStatus();
                        result.success(locationServicesStatus);
                    } else if ("request".equals(locationServicesMethod)) {
                        requestLocationPermission(result);
                    }
                    break;
                case Constants.APP_BLUETOOTH_AUTHORIZATION:
                    result.success("allowed"); // bluetooth is always enabled in Android by default
                    break;
                case Constants.FIREBASE_INFO:
                    String projectId = FirebaseApp.getInstance().getOptions().getProjectId();
                    result.success(projectId);
                    break;
                case Constants.DEVICE_ID_KEY:
                    String deviceId = getDeviceId();
                    result.success(deviceId);
                    break;
                case Constants.HEALTH_RSA_PRIVATE_KEY:
                    Object healthRsaPrivateKeyResult = handleHealthRsaPrivateKey(methodCall.arguments);
                    result.success(healthRsaPrivateKeyResult);
                    break;
                case Constants.ENCRYPTION_KEY_KEY:
                    Object encryptionKey = handleEncryptionKey(methodCall.arguments);
                    result.success(encryptionKey);
                    break;
                case Constants.BARCODE_KEY:
                    String barcodeImageData = handleBarcode(methodCall.arguments);
                    result.success(barcodeImageData);
                    break;
                default:
                    result.notImplemented();
                    break;

            }
        } catch (IllegalStateException exception) {
            String errorMsg = String.format("Ignoring exception '%s'. See https://github.com/flutter/flutter/issues/29092 for details.", exception.toString());
            Log.e(TAG, errorMsg);
            exception.printStackTrace();
        }
    }

    @Override
    public void registerWith(PluginRegistry registry) {

    }

    // RequestLocationCallback

    public static class RequestLocationCallback {
        public void onResult(boolean granted) {}
    }
}
