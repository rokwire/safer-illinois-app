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

package edu.illinois.covid.gallery;


import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.IOException;
import java.io.OutputStream;

import edu.illinois.covid.Constants;
import edu.illinois.covid.MainActivity;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

public class GalleryPlugin implements MethodChannel.MethodCallHandler, FlutterPlugin {

    private static final String TAG = "GalleryPlugin";
    public static int STORAGE_PERMISSION_REQUEST_CODE = 100;

    private static GalleryPlugin instance;
    private final MainActivity activityContext;
    private BinaryMessenger messenger;
    private MethodChannel methodChannel;
    private EventChannel eventChannel;

    // Temp storage between permission request
    private byte[] bytes;
    private String name;
    private MethodChannel.Result channelResult;

    public GalleryPlugin(MainActivity activity,  BinaryMessenger messenger) {
        this.activityContext = activity;
        this.messenger = messenger;
    }

    private void handleStore() {
        try {
            if (hasWriteStoragePermission()) {
                handleStore(this.bytes, this.name, this.channelResult, false);
            }
        } finally {
            clearCache();
        }
    }

    private void handleStore(byte[] bytes, String name, @NonNull MethodChannel.Result result) {
        handleStore(bytes, name, result, true);
    }

    private void handleStore(byte[] bytes, String name, @NonNull MethodChannel.Result result, boolean performedPermissionCheck) {
        if (performedPermissionCheck) {
            if(!hasWriteStoragePermission()) {
                this.bytes = bytes;
                this.name = name;
                this.channelResult = result;
                requestWriteStoragePermission();
                return;
            }
        }
        else {
            if(!hasWriteStoragePermission()){
                result.success(Boolean.FALSE);
                return;
            }
        }

        if (android.os.Build.VERSION.SDK_INT >= 29) {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/");
            values.put(MediaStore.Images.Media.IS_PENDING, true);
            Uri uri = activityContext.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
            if (uri != null) {
                saveBytesToUri(bytes, uri);
                values.put(MediaStore.Images.Media.IS_PENDING, false);
                activityContext.getContentResolver().update(uri, values, null, null);
                result.success(Boolean.TRUE);
                return;
            }
        } else {
            String storagePath = Environment.getExternalStorageDirectory().toString();
            storagePath = storagePath.endsWith("/") ? storagePath : storagePath + "/";
            File directory = new File( storagePath + "Pictures/");
            if (!directory.exists()) {
                directory.mkdirs();
            }
            String fileName = System.currentTimeMillis() + ".png";
            File file = new File(directory, fileName);
            saveBytesToUri(bytes, Uri.fromFile(file));
            if (file.getAbsolutePath() != null) {
                ContentValues values = new ContentValues();
                values.put(MediaStore.Images.Media.DATA, file.getAbsolutePath());
                activityContext.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
                result.success(Boolean.TRUE);
                return;
            }
        }
        result.success(Boolean.FALSE);
    }

    private void saveBytesToUri(byte[] bytes, Uri uri){
        if(bytes != null && uri != null) {
            OutputStream out = null;
            try {
                out = activityContext.getContentResolver().openOutputStream(uri);
                if (out != null) {
                    out.write(bytes);
                }
            } catch (Exception e) {
                Log.e(TAG, String.format("Error on write %s", uri.toString()), e);
            }
            finally {
                if(out != null){
                    try {
                        out.flush();
                    } catch (IOException e) {
                        Log.e(TAG, String.format("Error on write %s", uri.toString()), e);
                    }
                    try {
                        out.close();
                    } catch (IOException e) {
                        Log.e(TAG, String.format("Error on write %s", uri.toString()), e);
                    }
                }
            }
        }
    }

    private void clearCache(){
        this.bytes = null;
        this.name = null;
        this.channelResult = null;
    }

    private boolean hasWriteStoragePermission() {
        return activityContext.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
    }

    private void requestWriteStoragePermission() {
        activityContext.requestPermissions(new String[] {android.Manifest.permission.WRITE_EXTERNAL_STORAGE}, STORAGE_PERMISSION_REQUEST_CODE);
    }

    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        if(requestCode == STORAGE_PERMISSION_REQUEST_CODE) {
            for (int i = 0; i < permissions.length && i < grantResults.length; i++) {
                String permission = permissions[i];
                int result = grantResults[i];
                if (android.Manifest.permission.WRITE_EXTERNAL_STORAGE.equals(permission)){
                    handleStore();
                }
            }
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        String method = call.method;
        try {
            switch (method) {
                case Constants.GALLERY_PLUGIN_METHOD_NAME_STORE:
                    byte[] bytes = call.argument(Constants.GALLERY_PLUGIN_PARAM_BYTES);
                    String name = call.argument(Constants.GALLERY_PLUGIN_PARAM_NAME);
                    handleStore(bytes, name, result); // Result is handled on a latter step
                    break;
            }
        } catch (Exception e){
            Log.e(TAG, "Error on reading command", e);
        }
    }

    // Flutter Plugin

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        setupChannels(binding.getBinaryMessenger(), binding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        disposeChannels();
    }

    private void setupChannels(BinaryMessenger messenger, Context context) {
        methodChannel = new MethodChannel(messenger, "edu.illinois.covid/gallery");
        methodChannel.setMethodCallHandler(this);
        eventChannel = new EventChannel(messenger, "edu.illinois.covid/gallery_events");
    }

    private void disposeChannels() {
        methodChannel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
        methodChannel = null;
        eventChannel = null;
    }
}