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

import com.google.android.gms.maps.model.LatLng;

public class Constants {

    //Flutter communication methods
    static final String APP_INIT_KEY = "init";
    static final String MAP_DIRECTIONS_KEY = "directions";
    static final String MAP_KEY = "map";
    static final String SHOW_NOTIFICATION_KEY = "showNotification";
    static final String APP_DISMISS_SAFARI_VC_KEY = "dismissSafariVC";
    static final String APP_DISMISS_LAUNCH_SCREEN_KEY = "dismissLaunchScreen";
    static final String APP_ADD_CARD_TO_WALLET_KEY = "addToWallet";
    static final String APP_ENABLED_ORIENTATIONS_KEY = "enabledOrientations";
    static final String APP_NOTIFICATIONS_AUTHORIZATION = "notifications_authorization";
    static final String APP_LOCATION_SERVICES_PERMISSION = "location_services_permission";
    static final String APP_BLUETOOTH_AUTHORIZATION = "bluetooth_authorization";
    static final String FIREBASE_INFO = "firebaseInfo";
    static final String DEVICE_ID_KEY = "deviceId";
    static final String HEALTH_RSA_PRIVATE_KEY = "healthRSAPrivateKey";
    static final String ENCRYPTION_KEY_KEY = "encryptionKey";
    static final String BARCODE_KEY = "barcode";

    //Maps
    public static final LatLng DEFAULT_INITIAL_CAMERA_POSITION = new LatLng(40.102116, -88.227129); //Illinois University: Center of Campus //(40.096230, -88.235899); // State Farm Center
    public static final float DEFAULT_CAMERA_ZOOM = 17.0f;
    static final float FIRST_THRESHOLD_MARKER_ZOOM = 16.0f;
    static final float SECOND_THRESHOLD_MARKER_ZOOM = 16.89f;
    static final int MARKER_TITLE_MAX_SYMBOLS_NUMBER = 15;
    public static final double EXPLORE_LOCATION_THRESHOLD_DISTANCE = 200.0; //meters

    //Health
    static final String HEALTH_SHARED_PREFS_FILE_NAME = "health_shared_prefs";

    //Encryption Key
    static final String ENCRYPTION_SHARED_PREFS_FILE_NAME = "encryption_shared_prefs";

    //Gallery
    public static final String GALLERY_PLUGIN_METHOD_NAME_STORE = "store";
    public static final String GALLERY_PLUGIN_PARAM_BYTES = "bytes";
    public static final String GALLERY_PLUGIN_PARAM_NAME = "name";

    // Shared Prefs
    static final String DEFAULT_SHARED_PREFS_FILE_NAME = "default_shared_prefs";
    static final String LOCATION_PERMISSIONS_REQUESTED_KEY = "location_permissions_requested";
}
