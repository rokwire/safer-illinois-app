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

import android.annotation.TargetApi;
import android.bluetooth.le.ScanResult;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;

import java.util.ArrayList;

import edu.illinois.covid.Constants;
import edu.illinois.covid.exposure.ble.ExposureClient;

public class ExposureBleReceiver extends BroadcastReceiver {

    private static final String TAG = "ExposureBleReceiver";

    @TargetApi(Build.VERSION_CODES.O)
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) {
            Log.d(TAG, "onReceive - intent is null");
            return;
        }
        Log.d(TAG, "onReceive - " + intent.getAction());
        if (Constants.EXPOSURE_BLE_ACTION_FOUND.equals(intent.getAction())) {
            ScanResult scanResult = extractData(intent.getExtras());
            if (scanResult == null) {
                Log.d(TAG, "The scan result is null");
            }
            Intent bleClientIntent = new Intent(context, ExposureClient.class);
            bleClientIntent.putExtra(Constants.EXPOSURE_BLE_DEVICE_FOUND, scanResult);
            context.startService(bleClientIntent);
        }
    }

    private ScanResult extractData(Bundle extras) {
        if (extras != null) {
            Object list = extras.get("android.bluetooth.le.extra.LIST_SCAN_RESULT");
            if (list != null) {
                ArrayList l = (ArrayList) list;
                if (l.size() > 0) {
                    Object firstItem = l.get(0);
                    if (firstItem instanceof ScanResult) {
                        return (ScanResult) firstItem;
                    } else {
                        Log.d(TAG, "first item is not ScanResult");
                    }
                } else {
                    Log.d(TAG, "list is empty");
                }
            } else {
                Log.d(TAG, "list is null");
            }
        } else {
            Log.d(TAG, "extras are null");
        }
        return null;
    }
}
