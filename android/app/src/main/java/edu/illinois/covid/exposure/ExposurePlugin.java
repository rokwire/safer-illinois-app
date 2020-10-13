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

package edu.illinois.covid.exposure;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.ParcelUuid;
import android.util.Log;

import com.welie.blessed.BluetoothCentral;
import com.welie.blessed.BluetoothPeripheral;

import org.json.JSONException;
import org.json.JSONObject;

import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;
import java.util.UUID;

import androidx.annotation.NonNull;
import at.favre.lib.crypto.HKDF;
import edu.illinois.covid.Constants;
import edu.illinois.covid.MainActivity;
import edu.illinois.covid.R;
import edu.illinois.covid.Utils;
import edu.illinois.covid.exposure.ble.ExposureClient;
import edu.illinois.covid.exposure.ble.ExposureServer;
import edu.illinois.covid.exposure.crypto.AES;
import edu.illinois.covid.exposure.crypto.AES_CTR;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

public class ExposurePlugin implements MethodChannel.MethodCallHandler, FlutterPlugin {

    private static final String TAG = "ExposurePlugin";

    private static ExposurePlugin instance;

    private MainActivity activityContext;
    private BinaryMessenger messenger;
    private MethodChannel methodChannel;
    private EventChannel eventChannel;

    private MethodChannel.Result startedResult;
    private Object settings;

    private ExposureServer exposureServer;
    private boolean serverStarted;
    private ExposureClient androidExposureClient;
    private boolean clientStarted;

    // iOS specific scanner/client
    private BluetoothCentral iosExposureCentral;
    private Handler handler = new Handler();
    private Map<String, BluetoothPeripheral> peripherals;
    private Map<String, byte[]> peripheralsRPIs;
    private Map<String, ExposureRecord> iosExposures;

    // iOS background variable scanner
    private static final int iosbgManufacturerID = 76;
    private static final byte[] manufacturerDataMask = Utils.Str.hexStringToByteArray("ff00000000000000000000000000002000");
    private static final byte[] manufacturerData = Utils.Str.hexStringToByteArray("0100000000000000000000000000002000");
    private BluetoothAdapter iosBgBluetoothAdapter;
    private BluetoothLeScanner iosBgBluoetoothLeScanner;
    private List<ScanFilter> iosBgScanFilters;
    private ScanSettings iosBgScanSettings;
    private Map<String, BluetoothGatt> peripherals_bg;
    private Handler ios_bg_handler = new Handler();
    private Handler mainHandler = new Handler(Looper.getMainLooper());
    private Handler callbackHandler = new Handler();
    private static final String CCC_DESCRIPTOR_UUID = "00002902-0000-1000-8000-00805f9b34fb"; // characteristic notification
    private Runnable iosBgScanTimeoutRunnable; // for restarting scan in android 9

    // RPI
    private byte[] rpi;
    private Timer rpiTimer;
    private static final int RPI_REFRESH_INTERVAL_SECS = 10 * 60; // 10 minutes
    private static final int TEKRollingPeriod = 144;

    private Timer exposuresTimer;
    private long lastNotifyExposureTickTimestamp;
    private Map<String, ExposureRecord> androidExposures;

    private Map<Integer, Map<byte[], Integer>> i_TEK_map;

    // Exposure Constants
    private static final int EXPOSURE_TIMEOUT_INTERVAL_MILLIS = 2 * 60 * 1000; // 2 minutes
    private static final int EXPOSURE_PING_INTERVAL_MILLIS = 60 * 1000; // 1 minute
    private static final int EXPOSURE_PROCESS_INTERVAL_MILLIS = 10 * 1000; // 10 secs
    private static final int EXPOSURE_NOTIFY_TICK_INTERVAL_MILLIS = 1000; // 1 secs

    // Exposure Settings
    private int exposureTimeoutIntervalInMillis;
    private int exposurePingIntervalInMillis;
    private int exposureProcessIntervalInMillis;
    private int exposureMinDurationInMillis;
    private int exposureMinRssi;
    private int exposureExpireDays;

    // Helper constants
    private static final String TEK_MAP_KEY = "tek";
    private static final String RPI_MAP_KEY = "rpi";
    private static final String EN_INTERVAL_NUMBER_MAP_KEY = "ENIntervalNumber";
    private static final String I_MAP_KEY = "i";
    private static final String DATABASE_VERSION_KEY = "databaseversion";

    public ExposurePlugin(MainActivity activity,  BinaryMessenger messenger) {
        this.activityContext = activity;
        this.messenger = messenger;

        this.peripherals = new HashMap<>();
        this.peripheralsRPIs = new HashMap<>();
        this.iosExposures = new HashMap<>();
        this.androidExposures = new HashMap<>();

        this.i_TEK_map = loadTeksFromStorage();
        this.peripherals_bg = new HashMap<>();
    }

    //region Public APIs Implementation

    private void handleStart(@NonNull MethodChannel.Result result, Object settings) {
        Log.d(TAG, "handleStart: start plugin");
        startedResult = result;
        initSettings(settings);
        bindExposureServer();
        bindExposureClient();
    }

    public void handleStop() {
        Log.d(TAG, "handleStop: stop plugin");
        startedResult = null;
        stop();
    }

    private void start() {
        Log.d(TAG, "start");
        refreshRpi();
        startAdvertise();
        startRpiTimer();
        startScan();
    }

    private void stop() {
        Log.d(TAG, "stop");
        stopAdvertise();
        stopScan();
        clearRpi();
        clearExposures();
        stopRpiTimer();
        unBindExposureServer();
        unBindExposureClient();
    }

    private void refreshRpi() {
        Log.d(TAG, "refreshRpi");
        Map<String, Object> retVal = generateRpi();
        rpi = (byte[]) retVal.get(RPI_MAP_KEY);
        byte[] tek = (byte[]) retVal.get(TEK_MAP_KEY);
        int i = (int) retVal.get(I_MAP_KEY);
        int enIntervalNumber = (int) retVal.get(EN_INTERVAL_NUMBER_MAP_KEY);
        Log.d(TAG, "Logged - tek: " + Utils.Base64.encode(tek) + ", i: " + i + ", enIntervalNumber: " + enIntervalNumber);
        uploadRPIUpdate(rpi, tek, Utils.DateTime.getCurrentTimeMillisSince1970(), i, enIntervalNumber);
        String rpiEncoded = Utils.Base64.encode(rpi);
        Log.d(TAG, "final rpi  = " + rpiEncoded + "size = " + (rpi != null ? rpi.length : "null"));
        if (exposureServer != null) {
            exposureServer.setRpi(rpi);
        }
    }

    private Map<String, Object> generateRpi() {
        long currentTimestampInMillis = Utils.DateTime.getCurrentTimeMillisSince1970();
        long currentTimeStampInSecs = currentTimestampInMillis / 1000;
        int timestamp = (int) currentTimeStampInSecs;
        int ENIntervalNumber = timestamp / RPI_REFRESH_INTERVAL_SECS;
        Log.d(TAG, "ENIntervalNumber = " + ENIntervalNumber);
        int i = (ENIntervalNumber / TEKRollingPeriod) * TEKRollingPeriod;
        int expireIntervalNumber = i + TEKRollingPeriod;
        Log.d(TAG, "i = " + i);

        /* if new day, generate a new tek */
        /* if in the rest of the day, using last valid TEK */
        if ((i_TEK_map != null) && !i_TEK_map.isEmpty()) {
            Integer lastTimestamp = Collections.max(i_TEK_map.keySet());
            Map<byte[], Integer> lastTek = i_TEK_map.get(lastTimestamp);
            Integer lastExpireTime = (lastTek != null) ? lastTek.get(lastTek.keySet().iterator().next()) : null;
            if ((lastExpireTime != null) && (lastExpireTime == expireIntervalNumber)) {
                i = lastTimestamp;
            } else {
                i = ENIntervalNumber;
            }
        }

        Map<byte[], Integer> tek = new HashMap<>();
        if (i_TEK_map.isEmpty() || !i_TEK_map.containsKey(i)) {
            byte[] bytes = new byte[16];
            SecureRandom rand = new SecureRandom(); // generating TEK with a cryptographic random number generator
            rand.nextBytes(bytes);
            tek.put(bytes, expireIntervalNumber);
            i_TEK_map.put(i, tek); // putting the TEK map as a value for the current i

            // handling more than 14 (exposureExpireDays) i values in the map
            if (i_TEK_map.size() >= exposureExpireDays) {
                Iterator<Integer> it = i_TEK_map.keySet().iterator();
                while (it.hasNext()) {
                    int key = it.next();
                    if (key <= i - exposureExpireDays)
                        it.remove();
                }
            }

            // Save TEKs to storage
            saveTeksToStorage(i_TEK_map);

            // Notify TEK
            long notifyTimestampInMillis = (long) i * RPI_REFRESH_INTERVAL_SECS * 1000; // in millis
            long expireTime = (long) expireIntervalNumber * RPI_REFRESH_INTERVAL_SECS * 1000;
            byte[] tekData = tek.keySet().iterator().next();
            notifyTek(tekData, notifyTimestampInMillis, expireTime);
        } else {
            tek = i_TEK_map.get(i);
        }
        byte[] rpiTek = (tek != null) ? tek.keySet().iterator().next() : null;
        byte[] rpi = generateRpiForIntervalNumber(ENIntervalNumber, rpiTek);
        Map<String, Object> retVal = new HashMap<>();
        retVal.put(RPI_MAP_KEY, rpi);
        retVal.put(TEK_MAP_KEY, rpiTek);
        retVal.put(EN_INTERVAL_NUMBER_MAP_KEY, ENIntervalNumber);
        retVal.put(I_MAP_KEY, i);
        return retVal;
    }

    private byte[] generateRpiForIntervalNumber(int enIntervalNumber, byte[] tek) {
        // generating RPIK with salt as null and passing in the correct parameters to the extractandexpand function of HKDF class
        // in the file HKDF.java
        byte[] salt = null;
        byte[] info = "EN-RPIK".getBytes();
        byte[] RPIK = HKDF.fromHmacSha256().extractAndExpand(salt, tek, info, 16);

        // generating AEMK using the same method
        info = "EN-AEMK".getBytes();
        byte[] AEMK = HKDF.fromHmacSha256().extractAndExpand(salt, tek, info, 16);

        // creating the padded data for AES encryption of RPIK to get RPI
        byte[] padded_data = new byte[16];
        byte[] EN_RPI = "EN-RPI".getBytes();
        ByteBuffer bb = ByteBuffer.allocate(4);
        bb.putInt(enIntervalNumber);
        byte[] ENIN = bb.array();
        int j = 0;
        for (byte b : EN_RPI) {
            padded_data[j] = b;
            j++;
        }
        for (j = 6; j <= 11; j++) {
            padded_data[j] = 0;
        }
        for (byte b : ENIN) {
            padded_data[j] = b;
            j++;
        }

        byte[] rpi_byte = AES.encrypt(RPIK, padded_data);

        if (rpi_byte == null) {
            Log.w(TAG, "Newly generated rpi_byte is null");
            return null;
        }

        byte[] metadata = new byte[4];
        byte[] AEM_byte = new byte[4];
        try {
            AEM_byte = AES_CTR.encrypt(AEMK, rpi_byte, metadata);
        } catch (Exception e) {
            System.out.println("Error while encrypting: " + e.toString());
        }

        byte[] bluetoothpayload = new byte[20];
        System.arraycopy(rpi_byte, 0, bluetoothpayload, 0, rpi_byte.length);
        System.arraycopy(AEM_byte, 0, bluetoothpayload, rpi_byte.length, AEM_byte.length);

        return bluetoothpayload;
    }

    private void uploadRPIUpdate(byte[] rpi, byte[] parentTek, long updateTime, int i, int ENInvertalNumber) {
        String tekString = Utils.Base64.encode(parentTek);
        String rpiString = Utils.Base64.encode(rpi);
        Map<String, Object> rpiParams = new HashMap<>();
        rpiParams.put(Constants.EXPOSURE_PLUGIN_TIMESTAMP_PARAM_NAME, updateTime);
        rpiParams.put(Constants.EXPOSURE_PLUGIN_TEK_PARAM_NAME, tekString);
        rpiParams.put(Constants.EXPOSURE_PLUGIN_RPI_PARAM_NAME, rpiString);
        rpiParams.put("updateType", "");
        rpiParams.put("_i", i);
        rpiParams.put("ENInvertalNumber", ENInvertalNumber);
        invokeFlutterMethod(Constants.EXPOSURE_PLUGIN_METHOD_NAME_RPI_LOG, rpiParams);
    }

    private void clearRpi() {
        rpi = null;
    }

    private void startAdvertise() {
        if (exposureServer != null) {
            exposureServer.start();
        }
    }

    private void stopAdvertise() {
        if (exposureServer != null) {
            exposureServer.stop();
        }
    }

    private void startScan() {
        if (androidExposureClient != null) {
            androidExposureClient.startScan();
        }
        startIosScan();
    }

    private void stopScan() {
        if (androidExposureClient != null) {
            androidExposureClient.stopScan();
        }
        stopIosScan();
        processExposures();
    }

    private void initSettings(Object settings) {
        this.settings = settings;

        // Exposure Timeout Interval
        int timeoutIntervalInSecs = Utils.Map.getValueFromPath(settings, "covid19ExposureServiceTimeoutInterval", (EXPOSURE_TIMEOUT_INTERVAL_MILLIS / 1000)); // in seconds
        this.exposureTimeoutIntervalInMillis = timeoutIntervalInSecs * 1000; //in millis

        // Exposure Ping Interval
        int pingIntervalInSecs = Utils.Map.getValueFromPath(settings, "covid19ExposureServicePingInterval", (EXPOSURE_PING_INTERVAL_MILLIS / 1000)); // in seconds
        this.exposurePingIntervalInMillis = pingIntervalInSecs * 1000; //in millis

        // Exposure Process Interval
        int processIntervalInSecs = Utils.Map.getValueFromPath(settings, "covid19ExposureServiceProcessInterval", (EXPOSURE_PROCESS_INTERVAL_MILLIS / 1000)); // in seconds
        this.exposureProcessIntervalInMillis = processIntervalInSecs * 1000; //in millis

        // Exposure Min Duration Interval
        int minDurationInSecs = Utils.Map.getValueFromPath(settings, "covid19ExposureServiceLogMinDuration", (Constants.EXPOSURE_MIN_DURATION_MILLIS / 1000)); // in seconds
        this.exposureMinDurationInMillis = minDurationInSecs * 1000; //in millis

        // Exposure Min RSSI
        this.exposureMinRssi = Utils.Map.getValueFromPath(settings, "covid19ExposureServiceMinRSSI", Constants.EXPOSURE_MIN_RSSI_VALUE);

        // Exposure Expire Days
        this.exposureExpireDays = Utils.Map.getValueFromPath(settings, "covid19ExposureExpireDays", 14);
    }

    //endregion

    //region Single Instance

    public static ExposurePlugin getInstance() {
        return instance;
    }

    int getExposureMinRssi() {
        return exposureMinRssi;
    }

    //endregion

    //region External RPI implementation

    private void logAndroidExposure(String rpi, int rssi, String deviceAddress) {
        long currentTimeStamp = Utils.DateTime.getCurrentTimeMillisSince1970();
        ExposureRecord record = androidExposures.get(rpi);
        if (record == null) {
            Log.d(TAG, "registered android rpi: " + rpi);
            record = new ExposureRecord(currentTimeStamp, rssi);
            androidExposures.put(rpi, record);
            updateExposuresTimer();
        } else {
            record.updateTimeStamp(currentTimeStamp, rssi);
        }
        notifyExposureTick(rpi, rssi);
        notifyExposureRssiLog(rpi, currentTimeStamp, rssi, false, deviceAddress);
    }

    private void logIosExposure(String peripheralAddress, int rssi) {
        if (Utils.Str.isEmpty(peripheralAddress)) {
            return;
        }
        long currentTimestamp = Utils.DateTime.getCurrentTimeMillisSince1970();
        ExposureRecord record = iosExposures.get(peripheralAddress);
        if (record == null) {
            // Create new
            Log.d(TAG, "Registered ios peripheral: " + peripheralAddress);
            record = new ExposureRecord(currentTimestamp, rssi);
            iosExposures.put(peripheralAddress, record);
            updateExposuresTimer();
        } else {
            // Update existing
            record.updateTimeStamp(currentTimestamp, rssi);
        }
        byte[] rpi = peripheralsRPIs.get(peripheralAddress);
        String encodedRpi = "";
        if (rpi != null) {
            encodedRpi = Utils.Base64.encode(rpi);
            notifyExposureTick(encodedRpi, rssi);
        }
        notifyExposureRssiLog(encodedRpi, currentTimestamp, rssi, true, peripheralAddress);
    }

    private void notifyExposureTick(String rpi, int rssi) {
        if (Utils.Str.isEmpty(rpi)) {
            return;
        }
        long currentTimestamp = Utils.DateTime.getCurrentTimeMillisSince1970();
        // Do not allow more than one notification per second
        if (EXPOSURE_NOTIFY_TICK_INTERVAL_MILLIS <= (currentTimestamp - lastNotifyExposureTickTimestamp)) {
            Map<String, Object> exposureTickParams = new HashMap<>();
            exposureTickParams.put(Constants.EXPOSURE_PLUGIN_TIMESTAMP_PARAM_NAME, currentTimestamp);
            exposureTickParams.put(Constants.EXPOSURE_PLUGIN_RPI_PARAM_NAME, rpi);
            exposureTickParams.put(Constants.EXPOSURE_PLUGIN_RSSI_PARAM_NAME, rssi);
            invokeFlutterMethod(Constants.EXPOSURE_PLUGIN_METHOD_NAME_THICK, exposureTickParams);
            lastNotifyExposureTickTimestamp = currentTimestamp;
        }
    }

    private void notifyExposureRssiLog(String encodedRpi, long currentTimeStamp, int rssi, boolean isiOS, String address) {
        Map<String, Object> rssiParams = new HashMap<>();
        rssiParams.put(Constants.EXPOSURE_PLUGIN_RPI_PARAM_NAME, encodedRpi);
        rssiParams.put(Constants.EXPOSURE_PLUGIN_TIMESTAMP_PARAM_NAME, currentTimeStamp);
        rssiParams.put(Constants.EXPOSURE_PLUGIN_RSSI_PARAM_NAME, rssi);
        rssiParams.put(Constants.EXPOSURE_PLUGIN_IOS_RECORD_PARAM_NAME, isiOS);
        rssiParams.put(Constants.EXPOSURE_PLUGIN_ADDRESS_PARAM_NAME, address);
        invokeFlutterMethod(Constants.EXPOSURE_PLUGIN_METHOD_NAME_RSSI_LOG, rssiParams);
    }

    private void processExposures() {
        Log.d(TAG, "Process Exposures");
        long currentTimestamp = Utils.DateTime.getCurrentTimeMillisSince1970();
        Set<String> expiredPeripheralAddress = null;

        // 1. Collect all iOS expired records (not updated after exposureTimeoutIntervalInMillis)
        if ((iosExposures != null) && !iosExposures.isEmpty()) {
            for (String peripheralAddress : iosExposures.keySet()) {
                ExposureRecord record = iosExposures.get(peripheralAddress);
                if (record != null) {
                    long lastHeardInterval = currentTimestamp - record.getTimestampUpdated();
                    if (exposureTimeoutIntervalInMillis <= lastHeardInterval) {
                        Log.d(TAG, "Expired ios exposure: " + peripheralAddress);
                        if (expiredPeripheralAddress == null) {
                            expiredPeripheralAddress = new HashSet<>();
                        }
                        expiredPeripheralAddress.add(peripheralAddress);
                    } else if(exposurePingIntervalInMillis <= lastHeardInterval) {
                        Log.d(TAG, "ios exposure ping: " + peripheralAddress);
                        BluetoothPeripheral peripheral = (peripherals != null) ? peripherals.get(peripheralAddress) : null;
                        if(peripheral != null) {
                            peripheral.readRemoteRssi();
                        }
                    }
                }
            }
        }

        if ((expiredPeripheralAddress != null) && !expiredPeripheralAddress.isEmpty()) {
            for (String address : expiredPeripheralAddress) {
                // remove expired records from iosExposures
                disconnectIosPeripheral(address);
            }
        }

        // 2. Collect all Android expired records (not updated after exposureTimeoutIntervalInMillis)
        Set<String> expiredRPIs = null;
        if((androidExposures != null) && !androidExposures.isEmpty()) {
            for(String encodedRpi : androidExposures.keySet()) {
                ExposureRecord record = androidExposures.get(encodedRpi);
                if(record != null) {
                    long lastHeardInterval = currentTimestamp - record.getTimestampUpdated();
                    if(exposureTimeoutIntervalInMillis <= lastHeardInterval) {
                        Log.d(TAG, "Expired android exposure: " + encodedRpi);
                        if(expiredRPIs == null) {
                            expiredRPIs = new HashSet<>();
                        }
                        expiredRPIs.add(encodedRpi);
                    }
                }
            }
        }

        if (expiredRPIs != null) {
            // remove expired records from androidExposures
            for (String encodedRpi : expiredRPIs) {
                removeAndroidRpi(encodedRpi);
            }
        }
    }

    private void clearExposures() {
        if ((iosExposures != null) && !iosExposures.isEmpty()) {
            Map<String, ExposureRecord> iosExposureCopy = new HashMap<>(iosExposures);
            for (String address : iosExposureCopy.keySet()) {
                disconnectIosPeripheral(address);
            }
        }
        if ((androidExposures != null) && !androidExposures.isEmpty()) {
            Map<String, ExposureRecord> androidExposureCopy = new HashMap<>(androidExposures);
            for (String encodedRpi : androidExposureCopy.keySet()) {
                removeAndroidRpi(encodedRpi);
            }
        }
    }

    private void disconnectIosPeripheral(String peripheralAddress) {
        disconnectIosBgPeripheral(peripheralAddress);
    }

    private void removeIosPeripheral(String address) {
        if (Utils.Str.isEmpty(address) || (peripherals == null) || (peripherals.isEmpty())) {
            return;
        }
        peripherals.remove(address);
        byte[] rpi = (peripheralsRPIs != null) ? peripheralsRPIs.get(address) : null;
        if (rpi != null) {
            peripheralsRPIs.remove(address);
        }
        if ((iosExposures == null) || iosExposures.isEmpty()) {
            return;
        }
        ExposureRecord record = iosExposures.get(address);
        if (record != null) {
            iosExposures.remove(address);
            updateExposuresTimer();
        }
        if ((rpi != null) && (record != null)) {
            String encodedRpi = Utils.Base64.encode(rpi);
            notifyExposure(record, encodedRpi, true, address);
        }
    }

    private void removeAndroidRpi(String rpi) {
        if ((androidExposures == null) || androidExposures.isEmpty()) {
            return;
        }
        ExposureRecord record = androidExposures.get(rpi);
        if (record != null) {
            androidExposures.remove(rpi);
            updateExposuresTimer();
        }

        if ((rpi != null) && (record != null)) {
            notifyExposure(record, rpi, false, "");
        }
    }

    private void notifyExposure(ExposureRecord record, String rpi, boolean isiOS, String peripheralUuid) {
        if ((record != null) && (exposureMinDurationInMillis <= record.getDuration())) {
            Map<String, Object> exposureParams = new HashMap<>();
            exposureParams.put(Constants.EXPOSURE_PLUGIN_TIMESTAMP_PARAM_NAME, record.getTimestampCreated());
            exposureParams.put(Constants.EXPOSURE_PLUGIN_RPI_PARAM_NAME, rpi);
            exposureParams.put(Constants.EXPOSURE_PLUGIN_DURATION_PARAM_NAME, record.getDuration());
            exposureParams.put(Constants.EXPOSURE_PLUGIN_IOS_RECORD_PARAM_NAME, isiOS);
            exposureParams.put(Constants.EXPOSURE_PLUGIN_PERIPHERAL_UUID_PARAM_NAME, peripheralUuid);
            invokeFlutterMethod(Constants.EXPOSURE_PLUGIN_EXPOSURE_METHOD_NAME, exposureParams);
        }
    }

    //endregion

    //region TEKs

    private void changeTekExpireTime() {
        i_TEK_map = loadTeksFromStorage();
        if (i_TEK_map != null) {
            Integer currentI = Collections.max(i_TEK_map.keySet());
            Map<byte[], Integer> oldTEK = i_TEK_map.get(currentI);
            byte[] tek = (oldTEK != null) ? oldTEK.keySet().iterator().next() : null;

            long currentTimestampInMillis = Utils.DateTime.getCurrentTimeMillisSince1970();
            long currentTimeStampInSecs = currentTimestampInMillis / 1000;
            int timestamp = (int) currentTimeStampInSecs;
            int ENIntervalNumber = timestamp / RPI_REFRESH_INTERVAL_SECS;
            Map<byte[], Integer> newTEK = new HashMap<>();
            newTEK.put(tek, (ENIntervalNumber + 1));

            i_TEK_map.replace(currentI, newTEK);
            saveTeksToStorage(i_TEK_map);
        }
    }

    private void saveTeksToStorage(Map<Integer, Map<byte[], Integer>> teks) {
        if (teks != null) {
            Map<String, String> storageTeks = new HashMap<>();
            for (Integer key : teks.keySet()) {
                String storageKey = key != null ? Integer.toString(key) : null;
                Map<byte[], Integer> value = teks.get(key);
                byte[] tek = (value != null) ? value.keySet().iterator().next() : null;
                Integer expire = (value != null) ? value.get(tek) : null;
                Map<String, String> tekAndExpireTime = new HashMap<>();
                tekAndExpireTime.put(Utils.Base64.encode(tek), (expire != null ? Integer.toString(expire) : null));
                JSONObject jsonTekAndExpireTime = new JSONObject(tekAndExpireTime);
                String storageValue = jsonTekAndExpireTime.toString();
                if (storageKey != null) {
                    storageTeks.put(storageKey, storageValue);
                }
            }
            JSONObject teksJson = new JSONObject(storageTeks);
            String teksString = teksJson.toString();
            Utils.BackupStorage.saveString(activityContext, Constants.EXPOSURE_TEKS_SHARED_PREFS_FILE_NAME, Constants.EXPOSURE_TEKS_SHARED_PREFS_KEY, teksString);
        } else {
            Utils.BackupStorage.remove(activityContext, Constants.EXPOSURE_TEKS_SHARED_PREFS_FILE_NAME, Constants.EXPOSURE_TEKS_SHARED_PREFS_KEY);
        }
    }

    private Map<Integer, Map<byte[], Integer>> loadTeksFromStorage() {
        Log.d(TAG, "entering loadTeksFromStorage function");

        //checking database version
        boolean dataBaseChangeVersion = false;
        String databaseVersion = Utils.BackupStorage.getString(activityContext, Constants.EXPOSURE_TEKS_SHARED_PREFS_FILE_NAME, Constants.EXPOSURE_TEK_VERSION);
        if (Utils.Str.isEmpty(databaseVersion)) {
            Log.d(TAG, "no database version found");
            dataBaseChangeVersion = true;
        } else {
            JSONObject jsonDatabaseVersion = null;
            try {
                jsonDatabaseVersion = new JSONObject(databaseVersion);
            } catch (JSONException e) {
                Log.e(TAG, "Failed to parse database version string to json!");
                e.printStackTrace();
            }
            if (jsonDatabaseVersion != null) {
                String version = jsonDatabaseVersion.optString(DATABASE_VERSION_KEY);
                Log.d(TAG, "current TEK database version is " + version);
                if (Utils.Str.isEmpty(version) || Integer.parseInt(version) != 2) {
                    dataBaseChangeVersion = true;
                }
            }
        }

        if (dataBaseChangeVersion) {
            Utils.BackupStorage.remove(activityContext, Constants.EXPOSURE_TEKS_SHARED_PREFS_FILE_NAME, Constants.EXPOSURE_TEKS_SHARED_PREFS_KEY);
        }

        Map<Integer, Map<byte[], Integer>> teks = new HashMap<>();
        String teksString = Utils.BackupStorage.getString(activityContext, Constants.EXPOSURE_TEKS_SHARED_PREFS_FILE_NAME, Constants.EXPOSURE_TEKS_SHARED_PREFS_KEY);
        if (!Utils.Str.isEmpty(teksString)) {
            JSONObject teksJson = null;
            try {
                teksJson = new JSONObject(teksString);
            } catch (JSONException e) {
                Log.e(TAG, "Failed to parse TEKs string to json!");
                e.printStackTrace();
            }
            if (teksJson != null) {
                Iterator<String> iterator = teksJson.keys();
                while (iterator.hasNext()) {
                    String storageKey = iterator.next();
                    String storageValue = teksJson.optString(storageKey);
                    Map<byte[], Integer> tekAndExpireTime = new HashMap<>();
                    if (!Utils.Str.isEmpty(storageValue)) {
                        JSONObject jsonTekAndExpireTime = null;
                        try {
                            jsonTekAndExpireTime = new JSONObject(storageValue);
                        } catch (JSONException e) {
                            Log.e(TAG, "Failed to parse TEK map string to json!");
                            e.printStackTrace();
                        }
                        if (jsonTekAndExpireTime != null) {
                            Log.d(TAG, "LoadTEK: Found Nested Map");
                            Iterator<String> tekIterator = jsonTekAndExpireTime.keys();
                            if (tekIterator.hasNext()) {
                                String tekString = tekIterator.next();
                                String expireString = jsonTekAndExpireTime.optString(tekString);
                                tekAndExpireTime.put(Utils.Base64.decode(tekString), Integer.parseInt(expireString));
                            }
                        }
                    }
                    teks.put(Integer.parseInt(storageKey), tekAndExpireTime);
                }
            }
        }

        // update database version

        if (dataBaseChangeVersion) {
            Map<String, String> databaseVersionToStore = new HashMap<>();
            databaseVersionToStore.put(DATABASE_VERSION_KEY, Integer.toString(2));
            JSONObject jsonDatabaseVersion = new JSONObject(databaseVersionToStore);
            String databaseVersionString = jsonDatabaseVersion.toString();
            Utils.BackupStorage.saveString(activityContext, Constants.EXPOSURE_TEKS_SHARED_PREFS_FILE_NAME, Constants.EXPOSURE_TEK_VERSION, databaseVersionString);
        }
        return teks;
    }

    private List<Map<String, Object>> getTeksList() {
        List<Map<String, Object>> teksList = new ArrayList<>();
        if ((i_TEK_map != null) && !i_TEK_map.isEmpty()) {
            for (Integer tekKey : i_TEK_map.keySet()) {
                long timestamp = tekKey.longValue() * RPI_REFRESH_INTERVAL_SECS * 1000; //in millis
                Map<byte[], Integer> tek = i_TEK_map.get(tekKey);
                byte[] tekData = (tek != null) ? tek.keySet().iterator().next() : null;
                String tekString = Utils.Base64.encode(tekData);
                Integer expireInteger = (tek != null) ? tek.get(tekData) : null;
                long expireTime = (expireInteger != null) ? expireInteger.longValue() * RPI_REFRESH_INTERVAL_SECS * 1000 : 0; //in millis
                Map<String, Object> tekMap = new HashMap<>();
                tekMap.put("timestamp", timestamp);
                tekMap.put("tek", tekString);
                tekMap.put(Constants.EXPOSURE_PLUGIN_TEK_EXPIRE_PARAM_NAME, expireTime);
                teksList.add(tekMap);
            }
        }
        return teksList;
    }

    private Map<String, Long> getRpisForTek(byte[] tek, long timestampInMillis, long expireTime) {
        long timestampInSecs = timestampInMillis / 1000;

        long expireTimeInSecs = expireTime / 1000;

        int startENIntervalNumber = (int) (timestampInSecs / RPI_REFRESH_INTERVAL_SECS);
        int endENIntervalNumber = (int) (expireTimeInSecs / RPI_REFRESH_INTERVAL_SECS);

        /* handle TEKs without expirestamp (0 or -1), default to 1 day later */
        if (endENIntervalNumber < startENIntervalNumber || endENIntervalNumber > startENIntervalNumber + TEKRollingPeriod)
            endENIntervalNumber = startENIntervalNumber + TEKRollingPeriod;

        Map<String, Long> rpiList = new HashMap<>();
        for (int intervalIndex = startENIntervalNumber; intervalIndex <= endENIntervalNumber; intervalIndex++) {
            byte[] rpi = generateRpiForIntervalNumber(intervalIndex, tek);
            String rpiString = Utils.Base64.encode(rpi);
            rpiList.put(rpiString, (long) intervalIndex * RPI_REFRESH_INTERVAL_SECS * 1000);
        }
        return rpiList;
    }

    private void notifyTek(byte[] tek, long timestamp, long expireTime) {
        String tekString = Utils.Base64.encode(tek);
        Map<String, Object> tekParams = new HashMap<>();
        tekParams.put(Constants.EXPOSURE_PLUGIN_TIMESTAMP_PARAM_NAME, timestamp);
        tekParams.put(Constants.EXPOSURE_PLUGIN_TEK_PARAM_NAME, tekString);
        tekParams.put(Constants.EXPOSURE_PLUGIN_TEK_EXPIRE_PARAM_NAME, expireTime);
        invokeFlutterMethod(Constants.EXPOSURE_PLUGIN_TEK_METHOD_NAME, tekParams);
    }

    //endregion

    //region Exposure Server

    private void bindExposureServer() {
        Intent intent = new Intent(activityContext, ExposureServer.class);
        activityContext.bindService(intent, serverConnection, Context.BIND_AUTO_CREATE);
    }

    private void unBindExposureServer() {
        if (serverStarted) {
            activityContext.unbindService(serverConnection);
            serverStarted = false;
        }
    }

    private ServiceConnection serverConnection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder service) {
            exposureServer = ((ExposureServer.LocalServerBinder)service).getService();
            if (exposureServer == null) {
                return;
            }
            serverStarted = true;
            exposureServer.setCallback(serverCallback);
            checkStarted();
        }
        public void onServiceDisconnected(ComponentName className) {
            serverStarted = false;
            exposureServer = null;
        }
    };

    private ExposureServer.Callback serverCallback = new ExposureServer.Callback() {
        @Override
        public void onRequestBluetoothOn() {
            ExposurePlugin.this.requestBluetoothOn();
        }
    };

    //endregion

    //region Exposure Client

    private void bindExposureClient() {
        Intent intent = new Intent(activityContext, ExposureClient.class);
        activityContext.bindService(intent, clientConnection, Context.BIND_AUTO_CREATE);
    }

    private void unBindExposureClient() {
        if (clientStarted) {
            activityContext.unbindService(clientConnection);
            clientStarted = false;
        }
    }

    private ServiceConnection clientConnection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder service) {
            androidExposureClient = ((ExposureClient.LocalBinder)service).getService();
            if (androidExposureClient == null) {
                return;
            }
            androidExposureClient.initSettings(settings);
            clientStarted = true;
            androidExposureClient.setRpiCallback(clientRpiCallback);
            checkStarted();
        }
        public void onServiceDisconnected(ComponentName className) {
            clientStarted = false;
            androidExposureClient = null;
        }
    };

    private ExposureClient.RpiCallback clientRpiCallback = new ExposureClient.RpiCallback() {
        @Override
        public void onRpiFound(byte[] rpi, int rssi, String address) {
            if ((rpi != null) && (rssi != Constants.EXPOSURE_NO_RSSI_VALUE)) {
                String rpiEncoded = Utils.Base64.encode(rpi);
                Log.d(TAG, String.format(Locale.getDefault(), "onRpiFound: '%s' / rssi: %d", rpiEncoded, rssi));
                logAndroidExposure(rpiEncoded, rssi, address);
            }
        }

        @Override
        public void onIOSDeviceFound(ScanResult scanResult) {
            BluetoothDevice device = (scanResult != null) ? scanResult.getDevice() : null;
            String devAddress = (device != null) ? device.getAddress() : null;
            if (!Utils.Str.isEmpty(devAddress)) {
                if (peripherals_bg.get(devAddress) == null) {
                    Log.d(TAG, ": ios fg attempting to connect");
                    // new device discovered.
                    peripherals_bg.put(devAddress, device.connectGatt(activityContext, false, iOSBackgroundBluetoothGattCallback));
                }
                logIosExposure(devAddress, scanResult.getRssi());
            }
        }
    };

    //endregion

    //region iOS specific scanner/client

    private void startIosScan() {
        startIosBgScan();
    }

    private void stopIosScan() {
        stopIosBgScan();
    }

    //endregion

    //region iOS background specific scanner/client

    private void startIosBgScan() {
        Log.d(TAG, "startIosBgScan()");
        try {
            if (isIosBgScanning()) {
                stopIosBgScan();
            }
            if (iosBgBluetoothAdapter == null) {
                Object systemService = activityContext.getSystemService(Context.BLUETOOTH_SERVICE);
                if ((systemService instanceof BluetoothManager)) {
                    iosBgBluetoothAdapter = ((BluetoothManager) systemService).getAdapter();
                }
            }
            if (iosBgBluetoothAdapter == null) {
                Log.d(TAG, "ios bg scan bluetooth adapter init failure");
                return;
            }
            if (iosBgBluoetoothLeScanner == null) {
                iosBgBluoetoothLeScanner = iosBgBluetoothAdapter.getBluetoothLeScanner();
            }
            if (iosBgBluoetoothLeScanner == null) {
                Log.d(TAG, "ios bg scan bluetooth scanner init failure");
                return;
            }
            startIosBgScanTimer();
            ScanFilter.Builder scanFilterBuilder = new ScanFilter.Builder()
                    .setManufacturerData(iosbgManufacturerID, manufacturerData, manufacturerDataMask);
            iosBgScanFilters = Collections.singletonList(scanFilterBuilder.build());

            ScanSettings.Builder scanSettingsBuilder = new ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
                    .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
                    .setMatchMode(ScanSettings.MATCH_MODE_AGGRESSIVE)
                    .setNumOfMatches(ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT);
            iosBgScanSettings = scanSettingsBuilder.build();

            iosBgBluoetoothLeScanner.startScan(iosBgScanFilters, iosBgScanSettings, iOSBackgroundScanCallback);
            Log.d(TAG, "Start ios bg scan success!");
        } catch (Exception ex) {
            Log.e(TAG, ex.toString());
            ex.printStackTrace();
            // re-try
            startIosBgScan();
        }
    }

    private void stopIosBgScan() {
        stopIosBgScanTimer();
        if (isIosBgScanning()) {
            // Check if bluetooth is on.
            if (iosBgBluetoothAdapter.isEnabled() && (iosBgBluetoothAdapter.getState() == BluetoothAdapter.STATE_ON)) {
                iosBgBluoetoothLeScanner.stopScan(iOSBackgroundScanCallback);
            }
            Log.d(TAG, "stopped ios bg scanning");
        } else {
            Log.d(TAG, "no ios bg scanner is scanning");
        }
        iosBgBluoetoothLeScanner = null;
        iosBgBluetoothAdapter = null;
        iosBgScanFilters = null;
        iosBgScanSettings = null;
    }

    private boolean isIosBgScanning() {
        return ((iosBgBluetoothAdapter != null) && (iosBgBluoetoothLeScanner != null) &&
                (iosBgScanFilters != null) && (iosBgScanSettings != null));
    }

    private void startIosBgScanTimer() {
        stopIosBgScanTimer();

        iosBgScanTimeoutRunnable = () -> {
            Log.d(TAG, "scanning timeout, restarting scan");
            stopIosBgScan();
            // Restart the scan and timer
            callbackHandler.postDelayed(this::startIosBgScan, 1_000);
        };

        mainHandler.postDelayed(iosBgScanTimeoutRunnable, 180_000);
    }

    private void stopIosBgScanTimer() {
        if (iosBgScanTimeoutRunnable != null) {
            mainHandler.removeCallbacks(iosBgScanTimeoutRunnable);
            iosBgScanTimeoutRunnable = null;
        }
    }

    private void disconnectIosBgPeripheral(String peripheralAddress) {
        if (Utils.Str.isEmpty(peripheralAddress) || (peripherals_bg == null)) {
            return;
        }
        BluetoothGatt ble_gatt = peripherals_bg.get(peripheralAddress);
        if (ble_gatt == null) {
            Log.d(TAG, "gatt does not exist in bg");
            return;
        }
        // clean up connection
        ble_gatt.close();
        ble_gatt.disconnect();
        removeIosBgPeripheral(peripheralAddress);
    }

    private void removeIosBgPeripheral(String address) {
        if (Utils.Str.isEmpty(address) || (peripherals_bg == null) || (peripherals_bg.isEmpty())) {
            return;
        }
        peripherals_bg.remove(address);
        byte[] rpi = (peripheralsRPIs != null) ? peripheralsRPIs.get(address) : null;
        if (rpi != null) {
            peripheralsRPIs.remove(address);
        }
        if ((iosExposures == null) || iosExposures.isEmpty()) {
            return;
        }
        ExposureRecord record = iosExposures.get(address);
        if (record != null) {
            iosExposures.remove(address);
            updateExposuresTimer();
        }
        if ((rpi != null) && (record != null)) {
            String encodedRpi = Utils.Base64.encode(rpi);
            notifyExposure(record, encodedRpi, true, address);
        }
    }

    private BluetoothGattCallback iOSBackgroundBluetoothGattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            BluetoothGatt a = peripherals_bg.get(gatt.getDevice().getAddress());
            if (newState == 2 && a != null) {
                // seems that a delay is needed
                int delay = 600;
                ios_bg_handler.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        boolean result = gatt.discoverServices();
                        if (!result) {
                            Log.d(TAG, "DiscoverServices failed to start");
                        }
                    }
                }, delay);

            } else if (newState == 0) {
                peripherals_bg.remove(gatt.getDevice().getAddress());
                gatt.close();
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            if (status == 0) {
                BluetoothGatt _local_gatt = peripherals_bg.get(gatt.getDevice().getAddress());
                BluetoothGattService _local_service = (_local_gatt != null) ? _local_gatt.getService(Constants.EXPOSURE_UUID_SERVICE) : null;
                if (_local_service == null) {
                    // disconnect? remove from dictionary
                    peripherals_bg.remove(gatt.getDevice().getAddress());
                    gatt.close();
                } else {
                    // read characteristics from the service
                    // log ios devices.
                    BluetoothGattCharacteristic _local_characeristics = _local_service.getCharacteristic(Constants.EXPOSURE_UUID_CHARACTERISTIC);
                    _local_gatt.readCharacteristic(_local_characeristics);
                }
            } else {
                Log.d(TAG, "service discovery failed.: " + status);
            }
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic,
                                         int status) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "reading characteristics failed");
                return;
            }
            if (characteristic.getUuid().equals(Constants.EXPOSURE_UUID_CHARACTERISTIC)) {
                byte[] val = characteristic.getValue();
                peripheralsRPIs.put(gatt.getDevice().getAddress(), val);
                // copied from blessed image and modified
                BluetoothGattDescriptor descriptor = characteristic.getDescriptor(UUID.fromString(CCC_DESCRIPTOR_UUID));
                if (descriptor == null) {
                    peripherals_bg.remove(gatt.getDevice().getAddress());
                    gatt.close();
                    return;
                }
                byte[] value;
                int properties = characteristic.getProperties();
                if ((properties & BluetoothGattCharacteristic.PROPERTY_NOTIFY) > 0) {
                    value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE;
                } else if ((properties & BluetoothGattCharacteristic.PROPERTY_INDICATE) > 0) {
                    value = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;
                } else {
                    peripherals_bg.remove(gatt.getDevice().getAddress());
                    gatt.close();
                    return;
                }
                final byte[] finalValue = value;
                // First set notification for Gatt object
                // turn on or off
                if (!gatt.setCharacteristicNotification(characteristic, true)) {
                    Log.d(TAG, "setCharacteristicNotification failed for characteristic: "
                            + characteristic.getUuid());
                }
                // Then write to descriptor
                descriptor.setValue(finalValue);
                boolean result;
                result = gatt.writeDescriptor(descriptor);
                if (!result) {
                    peripherals_bg.remove(gatt.getDevice().getAddress());
                    gatt.close();
                }
                else{
                    Log.d(TAG, "descriptor written successfully");
                }
            }
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
            if (characteristic.getUuid().equals(Constants.EXPOSURE_UUID_CHARACTERISTIC)) {
                byte[] val = characteristic.getValue();
                String encoded = Utils.Base64.encode(val);
                Log.d(TAG, "onCharacteristicChange: value: " + encoded + ", device address: " + gatt.getDevice().getAddress());
                peripheralsRPIs.put(gatt.getDevice().getAddress(), val);
            }
        }
    };

    private final ScanCallback iOSBackgroundScanCallback = new ScanCallback() {

        @Override
        public void onScanFailed(int errorCode) {
            Log.d(TAG, "iOSBackgroundScanCallback: onScanFailed: " + errorCode);
        }

        @Override
        public void onBatchScanResults(List<ScanResult> results) {
            Log.d(TAG, "iOSBackgroundScanCallback: onBatchScanResults: " + ((results != null) ? results.size() : 0));
        }

        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            super.onScanResult(callbackType, result);
            ScanRecord scanrecord = result.getScanRecord();
            List<ParcelUuid> parcelUuids = (scanrecord != null) ? scanrecord.getServiceUuids() : null;
            List<UUID> serviceList = new ArrayList<>();
            if (parcelUuids != null) {
                for (int i = 0; i < parcelUuids.size(); i++) {
                    UUID serviceUUID = parcelUuids.get(i).getUuid();
                    if (!serviceList.contains(serviceUUID))
                        serviceList.add(serviceUUID);
                }
            } else {
                Log.d(TAG, "parcel UUID is null");
            }
            BluetoothDevice device = result.getDevice();
            byte[] manData = (scanrecord != null) ? scanrecord.getManufacturerSpecificData(iosbgManufacturerID) : null;
            if (manData != null) {
                // 01
                if (manData.length >= 17) {
                    if (manData[0] == 0x01) {
                        if (((manData[15] >> 5) & 0x01) == 1) {
                            String devAddress = device.getAddress();
                            // bg device discovered
                            // equivalently ondiscoverperipherals
                            if (peripherals_bg.get(devAddress) == null) {
                                // new device discovered.
                                peripherals_bg.put(devAddress,
                                        device.connectGatt(activityContext, false, iOSBackgroundBluetoothGattCallback));

                            }
                            // log ios exposure
                            logIosExposure(device.getAddress(), result.getRssi());
                        }
                    }
                }
            }
        }
    };

    //endregion

    //region Flutter Start Result

    private void checkStarted() {
        if (serverStarted && clientStarted) {
            start();
            if (startedResult != null) {
                MethodChannel.Result result = startedResult;
                startedResult = null;
                result.success(true);
            }
        }
    }

    //endregion

    //region RPI timer

    private void startRpiTimer() {
        long refreshIntervalInMillis = RPI_REFRESH_INTERVAL_SECS * 1000;
        stopRpiTimer();
        rpiTimer = new Timer();
        rpiTimer.scheduleAtFixedRate(new TimerTask() {
            @Override
            public void run() {
                refreshRpi();
            }
        }, refreshIntervalInMillis, refreshIntervalInMillis);
    }

    private void stopRpiTimer() {
        if (rpiTimer != null) {
            rpiTimer.cancel();
        }
        rpiTimer = null;
    }

    //endregion

    //region Exposures timer

    private void updateExposuresTimer() {
        int exposuresCount = androidExposures.size() + iosExposures.size();
        if ((exposuresCount > 0) && (exposuresTimer == null)) {
            exposuresTimer = new Timer();
            exposuresTimer.scheduleAtFixedRate(new TimerTask() {
                @Override
                public void run() {
                    processExposures();
                }
            }, exposureProcessIntervalInMillis, exposureProcessIntervalInMillis);
        } else if ((exposuresCount == 0) && (exposuresTimer != null)) {
            exposuresTimer.cancel();
            exposuresTimer = null;
        }
    }

    //endregion

    //region MethodCall

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        String method = call.method;
        try {
            switch (method) {
                case Constants.EXPOSURE_PLUGIN_METHOD_NAME_START:
                    Object settings = call.argument(Constants.EXPOSURE_PLUGIN_SETTINGS_PARAM_NAME);
                    handleStart(result, settings); // Result is handled on a latter step
                    break;
                case Constants.EXPOSURE_PLUGIN_METHOD_NAME_STOP:
                    handleStop();
                    result.success(true);
                    break;
                case Constants.EXPOSURE_PLUGIN_METHOD_NAME_TEKS:
                    boolean removeTeks = Utils.Map.getValueFromPath(call.arguments, "remove", false);
                    if (removeTeks) {
                        saveTeksToStorage(null);
                        result.success(null);
                    } else {
                        List<Map<String, Object>> teksList = getTeksList();
                        result.success(teksList);
                    }
                    break;
                case Constants.EXPOSURE_PLUGIN_METHOD_NAME_TEK_RPIS:
                    Object parameters = call.arguments;
                    String tekString = Utils.Map.getValueFromPath(parameters, Constants.EXPOSURE_PLUGIN_TEK_PARAM_NAME, null);
                    byte[] tek = Utils.Base64.decode(tekString);
                    long timestamp = Utils.Map.getValueFromPath(parameters, Constants.EXPOSURE_PLUGIN_TIMESTAMP_PARAM_NAME, -1L);
                    long expireTime = Utils.Map.getValueFromPath(parameters, Constants.EXPOSURE_PLUGIN_TEK_EXPIRE_PARAM_NAME, -1L);
                    Map<String, Long> rpis = getRpisForTek(tek, timestamp, expireTime);
                    result.success(rpis);
                    break;
                case Constants.EXPOSURE_PLUGIN_METHOD_NAME_EXPIRE_TEK:
                    changeTekExpireTime();
                    result.success(null);
                    break;
                default:
                    result.success(null);
                    break;

            }
        } catch (IllegalStateException exception) {
            String errorMsg = String.format("Ignoring exception '%s'. See https://github.com/flutter/flutter/issues/29092 for details.", exception.toString());
            Log.e(TAG, errorMsg);
            exception.printStackTrace();
        }
    }

    private void invokeFlutterMethod(String methodName, Object arguments) {
        if (methodChannel != null) {
            // Run on the ui thread
            Handler handler = new Handler(Looper.getMainLooper());
            handler.post(() -> methodChannel.invokeMethod(methodName, arguments));
        }
    }

    //endregion

    // region Bluetooth

    public void onLocationPermissionGranted() {
        Log.d(TAG, "onLocationPermissionGranted");
        if (androidExposureClient != null) {
            androidExposureClient.onLocationPermissionGranted();
        }
    }

    private void requestBluetoothOn() {
        Log.d(TAG, "requestBluetoothOn");

        Utils.showDialog(activityContext, activityContext.getString(R.string.app_name),
                activityContext.getString(R.string.exposure_request_bluetooth_on_message),
                (dialog, which) -> {
                    //Turn bluetooth on
                    Utils.enabledBluetooth();

                }, "Yes",
                (dialog, which) -> {
                }, "No",
                true);
    }

    //endregion

    //region Helpers

    private StringBuilder byte_to_hex(byte[] byte_array) {
        StringBuilder sb = new StringBuilder();
        if (byte_array != null) {
            for (byte b : byte_array) {
                sb.append(String.format("%02X ", b));
            }
        }
        return sb;
    }

    //endregion

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
        methodChannel = new MethodChannel(messenger, "edu.illinois.covid/exposure");
        methodChannel.setMethodCallHandler(this);
        eventChannel = new EventChannel(messenger, "edu.illinois.covid/exposure_events");
    }

    private void disposeChannels() {
        methodChannel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
        methodChannel = null;
        eventChannel = null;
    }
}
