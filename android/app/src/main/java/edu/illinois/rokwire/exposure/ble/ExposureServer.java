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

package edu.illinois.rokwire.exposure.ble;

import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.AdvertiseCallback;
import android.bluetooth.le.AdvertiseData;
import android.bluetooth.le.AdvertiseSettings;
import android.bluetooth.le.BluetoothLeAdvertiser;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Binder;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.ParcelUuid;
import android.util.Log;
import android.widget.Toast;

import java.util.concurrent.atomic.AtomicBoolean;

import androidx.annotation.Nullable;
import edu.illinois.rokwire.BuildConfig;
import edu.illinois.rokwire.Constants;

public class ExposureServer extends Service {

    //region Member fields

    private static final String TAG = ExposureServer.class.getSimpleName();

    public class LocalServerBinder extends Binder {
        public ExposureServer getService() {
            return ExposureServer.this;
        }
    }

    private final IBinder binder = new LocalServerBinder();

    private BluetoothAdapter bluetoothAdapter;

    private AtomicBoolean isAdvertising = new AtomicBoolean(false);
    private AtomicBoolean waitBluetoothOn = new AtomicBoolean(false);

    private byte[] rpi;

    private Callback callback;

    //endregion

    //region Service implementation

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    @Override
    public void onCreate() {
        Object systemService = getSystemService(Context.BLUETOOTH_SERVICE);
        if (systemService instanceof BluetoothManager) {
            bluetoothAdapter = ((BluetoothManager) systemService).getAdapter();
        }
        if (bluetoothAdapter == null) {
            Log.d(TAG, "onCreate: bluetoothAdapter is null");
            return;
        }
        IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
        registerReceiver(bluetoothReceiver, filter);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) { return START_STICKY;  }

    @Override
    public void onDestroy() {
        stopAdvertising();
        unregisterReceiver(bluetoothReceiver);
    }

    //endregion

    //region Public APIs

    public void start() {
        Log.d(TAG, "start server");

        if (bluetoothAdapter == null) {
            Log.d(TAG, "start - bluetoothAdapter is null");
            return;
        }

        // ask for bluetooth if not set
        if (!bluetoothAdapter.isEnabled()) {
            if (callback != null)
                callback.onRequestBluetoothOn();
        }
        startAdvertising();
    }

    public void stop() {
        Log.d(TAG, "stop server");
        stopAdvertising();
    }

    public void setRpi(byte[] rpi) {
        Log.d(TAG, "set rpi");
        this.rpi = rpi;
        if (isAdvertising.get()) {
            stopAdvertising();
            startAdvertising();
        }
    }

    public void setCallback(Callback callback) {
        this.callback = callback;
    }

    //endregion

    //region Advertising

    private void startAdvertising() {
        if ((rpi == null)) {
            Log.d(TAG, "startAdvertising: rpi is null! Advertising not started!");
            return;
        }
        if (!bluetoothAdapter.isEnabled()) {
            Log.d(TAG, "startAdvertising: wait for bluetooth to be enabled");
            waitBluetoothOn.set(true);
            return;
        }
        waitBluetoothOn.set(false);

        BluetoothLeAdvertiser advertiser = bluetoothAdapter.getBluetoothLeAdvertiser();
        if (advertiser == null) {
            Log.w(TAG, "Device does not support BLE advertisement");
            showToast("Exposure: This device does not support BLE advertisement");
            return;
        }
        showToast("Exposure: Start advertising");

        // Use try catch to handle DeadObject exception
        try {
            AdvertiseSettings.Builder settingsBuilder = new AdvertiseSettings.Builder();
            settingsBuilder.setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED);
            settingsBuilder.setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM);
            settingsBuilder.setConnectable(true);
            settingsBuilder.setTimeout(0);

            ParcelUuid parceluuid = new ParcelUuid(Constants.EXPOSURE_UUID_SERVICE);
            AdvertiseData.Builder dataBuilder = new AdvertiseData.Builder();
            dataBuilder.setIncludeDeviceName(false);
            dataBuilder.addServiceUuid(parceluuid);
            dataBuilder.addServiceData(parceluuid, rpi);

            AdvertiseSettings advertiseSettings = settingsBuilder.build();
            AdvertiseData advertiseData = dataBuilder.build();
            advertiser.startAdvertising(advertiseSettings, advertiseData, advertiseCallback);
        } catch (Exception ex) {
            String errMsg = "Exposure: start advertising failed!";
            Log.e(TAG, errMsg);
            ex.printStackTrace();
            showToast(errMsg);
            // re-try
            startAdvertising();
        }
    }

    private void stopAdvertising() {
        showToast("Exposure: Stop advertising");
        waitBluetoothOn.set(false);
        if (bluetoothAdapter != null) {
            BluetoothLeAdvertiser advertiser = bluetoothAdapter.getBluetoothLeAdvertiser();
            if (advertiser != null) {
                advertiser.stopAdvertising(advertiseCallback);
            }
        }
        stopForeground(true);
        isAdvertising.set(false);
    }

    private AdvertiseCallback advertiseCallback = new AdvertiseCallback() {

        @Override
        public void onStartSuccess(AdvertiseSettings settingsInEffect) {
            super.onStartSuccess(settingsInEffect);
            Log.d(TAG, "AdvertiseCallback onStartSuccess ");

            showToast("Exposure: Start advertising Succeed");

            isAdvertising.set(true);
        }

        @Override
        public void onStartFailure(int errorCode) {
            super.onStartFailure(errorCode);
            Log.e(TAG, "AdvertiseCallback onStartFailure " + errorCode);

            showToast("Exposure: Start advertising failed " + errorCode);

            isAdvertising.set(false);
        }
    };

    /**
     * Show toasts only for DEBUG builds
     * @param message the message that has to be shown
     */
    private void showToast(String message) {
        if (BuildConfig.DEBUG) {
            new Handler(Looper.getMainLooper()).post(() -> Toast.makeText(getApplicationContext(), message, Toast.LENGTH_SHORT).show());
        }
    }

    //endregion

    //region Bluetooth Receiver

    private final BroadcastReceiver bluetoothReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            final String action = intent.getAction();

            if ((action != null) && action.equals(BluetoothAdapter.ACTION_STATE_CHANGED)) {
                final int bluetoothState = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);
                if (bluetoothState == BluetoothAdapter.STATE_ON) {
                    Log.d(TAG, "Bluetooth is on");
                    //start the advertising if it waits for bluetooth
                    Handler handler = new Handler(Looper.getMainLooper());
                    Runnable runnable = () -> {
                        if (waitBluetoothOn.get()) {
                            startAdvertising();
                        }
                    };
                    handler.postDelayed(runnable, 2000);
                }
            }
        }
    };

    //endregion

    //region Exposure Server Callback

    public static class Callback {
        public void onRequestBluetoothOn() {}
    }

    //endregion
}
