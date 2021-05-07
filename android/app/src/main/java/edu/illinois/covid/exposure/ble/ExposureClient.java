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

package edu.illinois.covid.exposure.ble;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.os.Binder;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;

import java.util.concurrent.atomic.AtomicBoolean;

import androidx.core.content.ContextCompat;
import edu.illinois.covid.Constants;
import edu.illinois.covid.R;
import edu.illinois.covid.Utils;
import edu.illinois.covid.exposure.ble.scan.OreoScanner;
import edu.illinois.covid.exposure.ble.scan.PreOreoScanner;

public class ExposureClient extends Service {
    private static final String TAG = "ExposureClient";

    public class LocalBinder extends Binder {
        public ExposureClient getService() {
            return ExposureClient.this;
        }
    }
    private final IBinder mBinder = new LocalBinder();

    private static ExposureClient instance;

    private BluetoothAdapter mBluetoothAdapter;

    private PreOreoScanner preOreoScanner;
    private OreoScanner oreoScanner;

    private RpiCallback rpiCallback;

    private AtomicBoolean waitBluetoothOn = new AtomicBoolean(false);
    private AtomicBoolean waitLocationPermissionGranted = new AtomicBoolean(false);

    private AtomicBoolean isScanning = new AtomicBoolean(false);

    private Object settings;

    public static ExposureClient getInstance() {
        return instance;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }

    @Override
    public void onCreate() {
        Object systemService = getSystemService(Context.BLUETOOTH_SERVICE);
        if (systemService instanceof BluetoothManager) {
            mBluetoothAdapter = ((BluetoothManager) systemService).getAdapter();
        }
        if (mBluetoothAdapter == null) {
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            oreoScanner = new OreoScanner(getApplicationContext(), mBluetoothAdapter);
        } else {
            preOreoScanner = new PreOreoScanner(mBluetoothAdapter);
        }
        startForegroundClientService();
        instance = this;
        IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
        registerReceiver(bluetoothReceiver, filter);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "onStartCommand - " + startId);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // This call is required to be made after startForegroundService() since API 26
            startForegroundClientService();
        }

        if (intent != null) {
            Bundle extras = intent.getExtras();
            if (extras != null) {
                Object found = extras.get(Constants.EXPOSURE_BLE_DEVICE_FOUND);
                if (found != null) {
                    if (found instanceof ScanResult) {
                        ScanResult scanResult = ((ScanResult) found);
                        onScanResultFound(scanResult);
                    } else {
                        Log.d(TAG, "found is not ScanResult");
                    }
                } else {
                    Log.d(TAG, "found is null");
                }
            } else {
                Log.d(TAG, "extras are null");
            }
        } else {
            Log.d(TAG, "The intent is null");
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        stopService();
        unregisterReceiver(bluetoothReceiver);
    }

    public void setRpiCallback(RpiCallback rpiCallback) {
        this.rpiCallback = rpiCallback;
    }

    @SuppressLint("NewApi")
    public void startScan() {
        Log.d(TAG, "startScan");

        //check if bluetooth is on
        boolean needsWaitBluetooth = needsWaitBluetooth();
        if (needsWaitBluetooth) {
            waitBluetoothOn.set(true);
            return;
        }
        waitBluetoothOn.set(false);

        //check if location permission is granted
        boolean needsWaitLocationPermission = needsWaitLocationPermission();
        if (needsWaitLocationPermission) {
            waitLocationPermissionGranted.set(true);
            return;
        }
        waitLocationPermissionGranted.set(false);

        startForegroundClientService();
        isScanning.set(true);

        if (preOreoScanner != null) {
            preOreoScanner.startScan(new PreOreoScanner.ScannerCallback() {
                @Override
                public void onDevice(ScanResult result) {
                    super.onDevice(result);
                    onScanResultFound(result);
                }
            });
        }
        if (oreoScanner != null) {
            oreoScanner.startScan();
        }
    }

    public boolean exposureServiceLocalNotificationEnabled() {
        return Utils.Map.getValueFromPath(settings, "covid19ExposureServiceLocalNotificationEnabledAndroid", false);
    }

    private boolean needsWaitBluetooth() {
        if ((mBluetoothAdapter == null) || !mBluetoothAdapter.isEnabled()) {
            Log.d(TAG, "processBluetoothCheck needs to wait for bluetooth");
            return true;
        } else {
            Log.d(TAG, "processBluetoothCheck - bluetooth ready");
        }
        return false;
    }

    private boolean needsWaitLocationPermission() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "needsWaitLocationPermission - location is not set");
            return true;
        } else {
            Log.d(TAG, "needsWaitLocationPermission - location ready");
        }
        return false;
    }

    @SuppressLint("NewApi")
    public void stopScan() {
        Log.d(TAG, "stopScan");

        if (preOreoScanner != null) {
            preOreoScanner.stopScan();
        }
        if (oreoScanner != null) {
            oreoScanner.stopScan();
        }
        waitBluetoothOn.set(false);
        waitLocationPermissionGranted.set(false);

        stopService();
        isScanning.set(false);
    }

    public void onLocationPermissionGranted() {
        Log.d(TAG, "onLocationPermissionGranted");

        //start the advertising if it waits for location
        Handler handler = new Handler(Looper.getMainLooper());
        Runnable runnable = () -> {
            if (waitLocationPermissionGranted.get()) {
                startScan();
            }
        };
        handler.postDelayed(runnable, 2000);
    }

    public void initSettings(Object settings) {
        this.settings = settings;
    }

    private void onScanResultFound(ScanResult scanResult) {
        if (scanResult == null) {
            Log.d(TAG, "onScanResultFound: result is null");
            return;
        }
        ScanRecord scanRecord = scanResult.getScanRecord();
        if (scanRecord == null) {
            Log.d(TAG, "onScanResultFound: ScanRecord is null for ScanResult: " + scanResult.toString());
            return;
        }

        // Android - check service data
        byte[] possibleRpi = scanRecord.getServiceData(Constants.EXPOSURE_PARCEL_SERVICE_UUID);

        if ((possibleRpi != null) && possibleRpi.length == Constants.EXPOSURE_CONTRACT_NUMBER_LENGTH) {
            Log.d(TAG, "onScanResultFound: Bytes are found in Android device!");
            String rpiEncoded = Utils.Base64.encode(possibleRpi);
            String deviceAddress = (scanResult.getDevice() != null ? scanResult.getDevice().getAddress() : "");
            Log.d(TAG, "onScanResultFound: rpiFound: " + rpiEncoded + " from device address: " + deviceAddress);
            if (rpiCallback != null) {
                rpiCallback.onRpiFound(possibleRpi, scanResult.getRssi(), deviceAddress);
            }
        } else if (possibleRpi == null) {
            // this could be an ios device
            Log.d(TAG, "onScanResultFound: might be ios: " + scanResult.getDevice().getAddress());
            if (rpiCallback != null) {
                rpiCallback.onIOSDeviceFound(scanResult);
            }
        }
    }

    private void stopService() {
        stopForeground(true);
        stopSelf();
    }

    //region BroadcastReceiver

    private final BroadcastReceiver bluetoothReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            final String action = intent.getAction();

            if ((action != null) && action.equals(BluetoothAdapter.ACTION_STATE_CHANGED)) {
                final int bluetoothState = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE,
                        BluetoothAdapter.ERROR);
                if (bluetoothState == BluetoothAdapter.STATE_ON) {
                    Log.d(TAG, "Bluetooth is on");
                    //start the advertising if it waits for bluetooth
                    Handler handler = new Handler(Looper.getMainLooper());
                    Runnable runnable = () -> {
                        if (waitBluetoothOn.get()) {
                            startScan();
                        }
                    };
                    handler.postDelayed(runnable, 2000);
                }
            }
        }
    };

    //endregion

    //region Foreground service

    private void createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            CharSequence name = getString(R.string.app_name);
            String description = getString(R.string.exposure_notification_channel_description);
            int importance = NotificationManager.IMPORTANCE_DEFAULT;
            NotificationChannel channel = new NotificationChannel(
                    NotificationCreator.getChannelId(), name, importance);
            channel.setDescription(description);
            // Register the channel with the system; you can't change the importance
            // or other notification behaviors after this
            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }

    private void startForegroundClientService() {
        boolean exposureServiceLocalNotificationEnabled = exposureServiceLocalNotificationEnabled();
        if (exposureServiceLocalNotificationEnabled) {
            createNotificationChannelIfNeeded();
            startForeground(NotificationCreator.getOngoingNotificationId(),
                    NotificationCreator.getNotification(this));
        }
    }


    //endregion

    //region RpiCallback

    public static class RpiCallback {
        public void onRpiFound(byte[] rpi, int rssi, String address) {}
        public void onIOSDeviceFound(ScanResult scanResult){}
    }

    //endregion
}
