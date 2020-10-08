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

import android.os.ParcelUuid;

import com.google.android.gms.maps.model.LatLng;

import java.util.UUID;

public class Constants {

    //Flutter communication methods
    static final String APP_INIT_KEY = "init";
    static final String MAP_DIRECTIONS_KEY = "directions";
    static final String MAP_KEY = "map";
    static final String SHOW_NOTIFICATION_KEY = "showNotification";
    static final String APP_DISMISS_SAFARI_VC_KEY = "dismissSafariVC";
    static final String APP_DISMISS_LAUNCH_SCREEN_KEY = "dismissLaunchScreen";
    static final String APP_ADD_CARD_TO_WALLET_KEY = "addToWallet";
    static final String APP_MICRO_BLINK_SCAN_KEY = "microBlinkScan";
    static final String APP_ENABLED_ORIENTATIONS_KEY = "enabledOrientations";
    static final String APP_NOTIFICATIONS_AUTHORIZATION = "notifications_authorization";
    static final String APP_LOCATION_SERVICES_PERMISSION = "location_services_permission";
    static final String APP_BLUETOOTH_AUTHORIZATION = "bluetooth_authorization";
    static final String FIREBASE_INFO = "firebaseInfo";
    static final String DEVICE_ID_KEY = "deviceId";
    static final String HEALTH_RSI_PRIVATE_KEY = "healthRSAPrivateKey";
    static final String BARCODE_KEY = "barcode";

    //Maps
    public static final LatLng DEFAULT_INITIAL_CAMERA_POSITION = new LatLng(40.102116, -88.227129); //Illinois University: Center of Campus //(40.096230, -88.235899); // State Farm Center
    public static final float DEFAULT_CAMERA_ZOOM = 17.0f;
    static final float FIRST_THRESHOLD_MARKER_ZOOM = 16.0f;
    static final float SECOND_THRESHOLD_MARKER_ZOOM = 16.89f;
    static final int MARKER_TITLE_MAX_SYMBOLS_NUMBER = 15;
    public static final double EXPLORE_LOCATION_THRESHOLD_DISTANCE = 200.0; //meters
    public static final float INDOORS_BUILDING_ZOOM = 17.0f;
    public static final String ANALYTICS_ROUTE_LOCATION_FORMAT = "{\"latitude\":%f,\"longitude\":%f,\"floor\":%d}";
    public static final String ANALYTICS_USER_LOCATION_FORMAT = "{\"latitude\":%f,\"longitude\":%f,\"floor\":%d,\"timestamp\":%d}";

    //Health
    static final String HEALTH_SHARED_PREFS_FILE_NAME = "health_shared_prefs";

    //Exposure
    public static final String EXPOSURE_PLUGIN_METHOD_NAME_START = "start";
    public static final String EXPOSURE_PLUGIN_METHOD_NAME_STOP = "stop";
    public static final String EXPOSURE_PLUGIN_METHOD_NAME_TEKS = "TEKs";
    public static final String EXPOSURE_PLUGIN_METHOD_NAME_TEK_RPIS = "tekRPIs";
    public static final String EXPOSURE_PLUGIN_METHOD_NAME_RPI_LOG = "exposureRPILog";
    public static final String EXPOSURE_PLUGIN_METHOD_NAME_THICK = "exposureThick";
    public static final String EXPOSURE_PLUGIN_METHOD_NAME_RSSI_LOG = "exposureRSSILog";
    public static final String EXPOSURE_PLUGIN_METHOD_NAME_EXPIRE_TEK = "expireTEK";
    public static final String EXPOSURE_PLUGIN_SETTINGS_PARAM_NAME = "settings";
    public static final String EXPOSURE_PLUGIN_RPI_PARAM_NAME = "rpi";
    public static final String EXPOSURE_PLUGIN_TEK_METHOD_NAME = "tek";
    public static final String EXPOSURE_PLUGIN_TEK_PARAM_NAME = "tek";
    public static final String EXPOSURE_PLUGIN_TIMESTAMP_PARAM_NAME = "timestamp";
    public static final String EXPOSURE_PLUGIN_EXPOSURE_METHOD_NAME = "exposure";
    public static final String EXPOSURE_PLUGIN_DURATION_PARAM_NAME = "duration";
    public static final String EXPOSURE_PLUGIN_RSSI_PARAM_NAME = "rssi";
    public static final String EXPOSURE_PLUGIN_ADDRESS_PARAM_NAME = "address";
    public static final String EXPOSURE_PLUGIN_IOS_RECORD_PARAM_NAME = "isiOSRecord";
    public static final String EXPOSURE_PLUGIN_PERIPHERAL_UUID_PARAM_NAME = "peripheralUuid";
    public static final String EXPOSURE_PLUGIN_TEK_EXPIRE_PARAM_NAME = "expirestamp";
    public static final String EXPOSURE_BLE_DEVICE_FOUND = "edu.illinois.rokwire.exposure.ble.FOUND_DEVICE";
    public static final String EXPOSURE_BLE_ACTION_FOUND = "edu.illinois.rokwire.exposure.ble.scan.ACTION_FOUND";
    public static final int EXPOSURE_NO_RSSI_VALUE = 127;
    public static final int EXPOSURE_MIN_RSSI_VALUE = -50;
    public static final int EXPOSURE_MIN_DURATION_MILLIS = 0; // 0 minute
    public static final UUID EXPOSURE_UUID_SERVICE = UUID.fromString("0000CD19-0000-1000-8000-00805F9B34FB");
    public static final ParcelUuid EXPOSURE_PARCEL_SERVICE_UUID = new ParcelUuid(EXPOSURE_UUID_SERVICE);
    public static final UUID EXPOSURE_UUID_CHARACTERISTIC = UUID.fromString("1f5bb1de-cdf0-4424-9d43-d8cc81a7f207");
    public static final int EXPOSURE_CONTRACT_NUMBER_LENGTH = 20;
    public static final String EXPOSURE_TEKS_SHARED_PREFS_FILE_NAME = "exposure_teks_shared_prefs";
    public static final String EXPOSURE_TEKS_SHARED_PREFS_KEY = "exposure_teks";
    public static final String EXPOSURE_TEK_VERSION = "tekDatabaseVersion";

    //Gallery
    public static final String GALLERY_PLUGIN_METHOD_NAME_STORE = "store";
    public static final String GALLERY_PLUGIN_PARAM_BYTES = "bytes";
    public static final String GALLERY_PLUGIN_PARAM_NAME = "name";

    // Shared Prefs
    static final String DEFAULT_SHARED_PREFS_FILE_NAME = "default_shared_prefs";
    static final String LOCATION_PERMISSIONS_REQUESTED_KEY = "location_permissions_requested";
}
