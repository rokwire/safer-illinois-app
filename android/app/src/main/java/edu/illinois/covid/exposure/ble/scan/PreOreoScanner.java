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

package edu.illinois.covid.exposure.ble.scan;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.os.ParcelUuid;
import android.util.Log;

import java.util.Collections;
import java.util.List;
import java.util.concurrent.TimeUnit;

import edu.illinois.covid.Constants;

public class PreOreoScanner {

    private static final String TAG = PreOreoScanner.class.getSimpleName();

    private BluetoothAdapter bluetoothAdapter;

    private ScannerCallback discoverCallback;

    public PreOreoScanner(BluetoothAdapter bluetoothAdapter) {
        this.bluetoothAdapter = bluetoothAdapter;
    }

    public void startScan(ScannerCallback callback) {
        discoverCallback = callback;

        // Use try catch to handle DeadObject exception
        try {
            ScanFilter.Builder scanFilterBuilder = new ScanFilter.Builder();
            scanFilterBuilder.setServiceUuid(new ParcelUuid(Constants.EXPOSURE_UUID_SERVICE));
            List<ScanFilter> scanFilters = Collections.singletonList(scanFilterBuilder.build());
            long reportDelay = ((bluetoothAdapter != null) && bluetoothAdapter.isOffloadedScanBatchingSupported()) ? 5 : 0;

            ScanSettings.Builder scanSettingsBuilder = new ScanSettings.Builder().
                    setScanMode(ScanSettings.SCAN_MODE_LOW_POWER).
                    setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES).
                    setMatchMode(ScanSettings.MATCH_MODE_AGGRESSIVE).
                    setNumOfMatches(ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT).
                    setReportDelay(TimeUnit.SECONDS.toMillis(reportDelay));

            ScanSettings scanSettings = scanSettingsBuilder.build();
            if (bluetoothAdapter != null) {
                bluetoothAdapter.getBluetoothLeScanner().startScan(scanFilters, scanSettings, scanCallback);
            }
            Log.d(TAG, "Started scan");
        } catch (Exception ex) {
            Log.e(TAG, "Start scan failed:");
            ex.printStackTrace();
            // re-try
            startScan(callback);
        }
    }

    public void stopScan() {
        if (discoverCallback != null) {
            // Check if bluetooth adapter is not null and is turned on.
            BluetoothLeScanner bleScanner = ((bluetoothAdapter != null) && bluetoothAdapter.isEnabled() && (bluetoothAdapter.getState() == BluetoothAdapter.STATE_ON)) ? bluetoothAdapter.getBluetoothLeScanner() : null;
            if (bleScanner != null) {
                bleScanner.stopScan(scanCallback);
            }
            discoverCallback = null;
        }
    }

    private void onResult(final ScanResult result) {
        if (discoverCallback != null)
            discoverCallback.onDevice(result);
    }

    private ScanCallback scanCallback = new ScanCallback() {
        @Override
        public void onScanResult(int callbackType, final ScanResult result) {
            super.onScanResult(callbackType, result);
            onResult(result);
        }

        @Override
        public void onBatchScanResults(List<ScanResult> results) {
            super.onBatchScanResults(results);
            for (ScanResult result : results) {
                onResult(result);
            }
        }

        @Override
        public void onScanFailed(int errorCode) {
            super.onScanFailed(errorCode);
            Log.e(TAG, "onScanFailed errorCode = " + errorCode);
            if (errorCode == SCAN_FAILED_APPLICATION_REGISTRATION_FAILED) {
                // re-try
                startScan(discoverCallback);
            }
        }

    };

    //ScannerCallback

    public static abstract class ScannerCallback {
        public void onDevice(ScanResult result) {
        }
    }
}
