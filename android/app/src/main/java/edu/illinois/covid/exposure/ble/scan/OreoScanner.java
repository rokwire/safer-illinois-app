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

import android.app.PendingIntent;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.ParcelUuid;
import android.util.Log;

import java.util.Collections;
import java.util.List;
import java.util.concurrent.TimeUnit;

import androidx.annotation.RequiresApi;
import edu.illinois.covid.Constants;

public class OreoScanner {

    private static final String TAG = "OreoScanner";

    private Context context;
    private BluetoothAdapter bluetoothAdapter;

    private PendingIntent pendingIntent;

    public OreoScanner(Context context, BluetoothAdapter bluetoothAdapter) {
        this.context = context;
        this.bluetoothAdapter = bluetoothAdapter;
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    public void startScan() {
        Log.d(TAG, "Started scan");
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
                    setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED).
                    setReportDelay(TimeUnit.SECONDS.toMillis(reportDelay)).
                    setLegacy(true);

            ScanSettings scanSettings = scanSettingsBuilder.build();

            Intent intent = new Intent(context, ExposureBleReceiver.class);
            intent.setAction(Constants.EXPOSURE_BLE_ACTION_FOUND);
            pendingIntent = PendingIntent.getBroadcast(context, 2, intent, PendingIntent.FLAG_UPDATE_CURRENT);

            if ((pendingIntent != null) && (bluetoothAdapter != null)) {
                BluetoothLeScanner bleScanner = bluetoothAdapter.getBluetoothLeScanner();
                if (bleScanner != null) {
                    bleScanner.startScan(scanFilters, scanSettings, pendingIntent);
                }
            }
        } catch (Exception ex) {
            Log.e(TAG, "Start scan failed:");
            ex.printStackTrace();
            //re-try
            startScan();
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    public void stopScan() {
        if (pendingIntent != null) {
            // Check if bluetooth adapter is not null and is turned on.
            BluetoothLeScanner bleScanner = ((bluetoothAdapter != null) && bluetoothAdapter.isEnabled() && (bluetoothAdapter.getState() == BluetoothAdapter.STATE_ON)) ? bluetoothAdapter.getBluetoothLeScanner() : null;
            if (bleScanner != null) {
                bleScanner.stopScan(pendingIntent);
            }
            pendingIntent = null;
        }
    }
}
