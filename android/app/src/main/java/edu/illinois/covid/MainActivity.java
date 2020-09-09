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
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Base64;
import android.util.Log;
import android.view.WindowManager;

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
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import edu.illinois.covid.exposure.ExposurePlugin;
import edu.illinois.covid.gallery.GalleryPlugin;
import edu.illinois.covid.maps.MapActivity;
import edu.illinois.covid.maps.MapDirectionsActivity;
import edu.illinois.covid.maps.MapViewFactory;
import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity implements MethodChannel.MethodCallHandler {

    private static final String TAG = "MainActivity";

    private final int REQUEST_LOCATION_PERMISSION_CODE = 1;

    private static MethodChannel METHOD_CHANNEL;
    private static final String NATIVE_CHANNEL = "edu.illinois.covid/core";
    private static MainActivity instance = null;

    private ExposurePlugin exposurePlugin;

    private HashMap keys;

    private int preferredScreenOrientation;
    private Set<Integer> supportedScreenOrientations;

    private RequestLocationCallback rlCallback;

    // Gallery Plugin
    private GalleryPlugin galleryPlugin;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);

        registerPlugins();
        instance = this;
        initScreenOrientation();
        initMethodChannel();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        // when activity is killed by user through the app manager, stop all exposure-related services
        if (exposurePlugin != null) {
            exposurePlugin.handleStop();
        }
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

    private void registerPlugins() {
        GeneratedPluginRegistrant.registerWith(this);

        // MapView
        Registrar registrar = registrarFor("MapPlugin");
        registrar.platformViewRegistry().registerViewFactory("mapview", new MapViewFactory(this, registrar));

        // ExposureNotifications
        Registrar exposureRegistrar = registrarFor("ExposurePlugin");
        exposurePlugin = ExposurePlugin.registerWith(exposureRegistrar);

        // GalleryPlugin
        Registrar galleryRegistrar = registrarFor("GalleryPlugin");
        galleryPlugin = GalleryPlugin.registerWith(exposureRegistrar);
    }

    private void initScreenOrientation() {
        preferredScreenOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT;
        supportedScreenOrientations = new HashSet<>(Collections.singletonList(preferredScreenOrientation));
    }

    private void initMethodChannel() {
        METHOD_CHANNEL = new MethodChannel(getFlutterView(), NATIVE_CHANNEL);
        METHOD_CHANNEL.setMethodCallHandler(this);
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
        //check if granted
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED  ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "request permission");

            rlCallback = new RequestLocationCallback() {
                @Override
                public void onResult(boolean granted) {
                    if (granted) {
                        result.success("allowed");

                        if (exposurePlugin != null) {
                            exposurePlugin.onLocationPermissionGranted();
                        }
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

    private Object handleHealthRsiPrivateKey(Object params) {
        String userId = null;
        String value = null;
        boolean remove = false;
        if (params instanceof HashMap) {
            HashMap paramsMap = (HashMap) params;
            Object userIdObj = paramsMap.get("userId");
            if (userIdObj instanceof String) {
                userId = (String) userIdObj;
            }
            Object valueObj = paramsMap.get("value");
            if (valueObj instanceof String) {
                value = (String) valueObj;
            }
            Object removeObj = paramsMap.get("remove");
            if (removeObj instanceof Boolean) {
                remove = (Boolean) removeObj;
            }
        }
        if (Utils.Str.isEmpty(userId)) {
            return null;
        }
        if (Utils.Str.isEmpty(value)) {
            if (remove) {
                Utils.BackupStorage.remove(this, Constants.HEALTH_SHARED_PREFS_FILE_NAME, userId);
                return true;
            } else {
                return Utils.BackupStorage.getString(this, Constants.HEALTH_SHARED_PREFS_FILE_NAME, userId);
            }
        } else {
            Utils.BackupStorage.saveString(this, Constants.HEALTH_SHARED_PREFS_FILE_NAME, userId, value);
            return true;
        }
    }

    /**
     * Overrides {@link io.flutter.plugin.common.MethodChannel.MethodCallHandler} onMethodCall()
     */
    @Override
    public void onMethodCall(MethodCall methodCall, @NonNull MethodChannel.Result result) {
        String method = methodCall.method;
        try {
            switch (method) {
                case Constants.APP_INIT_KEY:
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
                case Constants.APP_MICRO_BLINK_SCAN_KEY:
                    result.success(null);
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
                    requestLocationPermission(result);
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
                case Constants.HEALTH_RSI_PRIVATE_KEY:
                    Object healthRsiPrivateKeyResult = handleHealthRsiPrivateKey(methodCall.arguments);
                    result.success(healthRsiPrivateKeyResult);
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

    // RequestLocationCallback

    public static class RequestLocationCallback {
        public void onResult(boolean granted) {}
    }
}
