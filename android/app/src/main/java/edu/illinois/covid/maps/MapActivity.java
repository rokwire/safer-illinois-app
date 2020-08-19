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

package edu.illinois.covid.maps;

import android.graphics.Color;
import android.location.Location;
import android.os.Bundle;
import android.os.Looper;
import android.util.Log;
import android.view.MenuItem;
import android.view.View;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.ActionBar;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.SupportMapFragment;
import com.google.android.gms.maps.model.CameraPosition;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.mapsindoors.mapssdk.MPPositionResult;
import com.mapsindoors.mapssdk.MapControl;
import com.mapsindoors.mapssdk.MapsIndoors;
import com.mapsindoors.mapssdk.OnPositionUpdateListener;
import com.mapsindoors.mapssdk.OnStateChangedListener;
import com.mapsindoors.mapssdk.PermissionsAndPSListener;
import com.mapsindoors.mapssdk.Point;
import com.mapsindoors.mapssdk.PositionProvider;
import com.mapsindoors.mapssdk.PositionResult;
import com.mapsindoors.mapssdk.errors.MIError;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Timer;
import java.util.TimerTask;

import edu.illinois.covid.Constants;
import edu.illinois.covid.R;
import edu.illinois.covid.Utils;

public class MapActivity extends AppCompatActivity implements PositionProvider {
    //region Class fields

    //Google Maps
    private SupportMapFragment mapFragment;
    protected GoogleMap googleMap;

    //Android Location
    private FusedLocationProviderClient fusedLocationClient;
    protected Location coreLocation;
    private com.google.android.gms.location.LocationRequest coreLocationRequest;
    private LocationCallback coreLocationCallback;

    //Location timer
    private Timer locationTimer;
    protected long locationTimestamp;

    //MapsIndoors
    protected MapControl mapControl;
    protected MPPositionResult mpPositionResult;
    private boolean isRunning;
    private OnPositionUpdateListener mpPositionUpdateListener;

    private boolean firstLocationUpdatePassed;
    private HashMap target;
    private HashMap options;
    private ArrayList<HashMap> markers;
    private TextView debugStatusView;
    private boolean showDebugLocation;

    //endregion

    //region Activity methods

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.map_layout);

        initHeaderBar();
        initParameters();
        initUiViews();
        initCoreLocation();
        initMap();
    }

    @Override
    protected void onStart() {
        super.onStart();
        if (mapControl != null) {
            mapControl.onStart();
        }
        startMonitor();
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (mapControl != null) {
            mapControl.onStop();
        }
        stopMonitor();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (mapControl != null) {
            mapControl.onResume();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (mapControl != null) {
            mapControl.onPause();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (mapControl != null) {
            mapControl.onDestroy();
        }
    }

    @Override
    public void onLowMemory() {
        super.onLowMemory();
        if (mapControl != null) {
            mapControl.onLowMemory();
        }
    }

    /**
     * Handle up (back) navigation button clicked
     */
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        onBackPressed();
        return true;
    }

    //endregion

    //region Common initialization

    private void initHeaderBar() {
        setSupportActionBar(findViewById(R.id.toolbar));
        ActionBar actionBar = getSupportActionBar();
        if (actionBar != null) {
            actionBar.setDisplayShowTitleEnabled(false);
            actionBar.setDisplayHomeAsUpEnabled(true);
            actionBar.setDisplayShowHomeEnabled(true);
        }
    }

    private void initParameters() {
        Serializable targetSerializable = getIntent().getSerializableExtra("target");
        if (targetSerializable instanceof HashMap) {
            this.target = (HashMap) targetSerializable;
        }
        Serializable optionsSerializable = getIntent().getSerializableExtra("options");
        if (optionsSerializable instanceof HashMap) {
            this.options = (HashMap) optionsSerializable;
        }
        Serializable markersSerializable = getIntent().getSerializableExtra("markers");
        if (markersSerializable instanceof List) {
            this.markers = (ArrayList<HashMap>) markersSerializable;
        }
    }

    protected void initUiViews() {
        showDebugLocation = Utils.Map.getValueFromPath(options, "showDebugLocation", false);
        if (showDebugLocation) {
            debugStatusView = findViewById(R.id.debugStatusTextView);
            debugStatusView.setVisibility(View.VISIBLE);
        }
    }

    //endregion

    //region Map views initialization

    private void initMap() {
        mapFragment = ((SupportMapFragment) getSupportFragmentManager().findFragmentById(R.id.map_fragment));
        if (mapFragment != null) {
            mapFragment.getMapAsync(this::didGetMapAsync);
        }
    }

    private void didGetMapAsync(GoogleMap map) {
        googleMap = map;
        double latitude = Utils.Map.getValueFromPath(target, "latitude", Constants.DEFAULT_INITIAL_CAMERA_POSITION.latitude);
        double longitude = Utils.Map.getValueFromPath(target, "longitude", Constants.DEFAULT_INITIAL_CAMERA_POSITION.longitude);
        double zoom = Utils.Map.getValueFromPath(target, "zoom", Constants.DEFAULT_CAMERA_ZOOM);
        googleMap.moveCamera(CameraUpdateFactory.newCameraPosition(CameraPosition.fromLatLngZoom(new LatLng(latitude, longitude), (float)zoom)));
        initMapControl();
    }

    private void initMapControl() {
        mapControl = new MapControl(this);
        mapControl.setGoogleMap(googleMap, mapFragment.getView());
        MapsIndoors.setPositionProvider(this);
        mapControl.showUserPosition(true);
        mapControl.setOnFloorUpdateListener((building, i) -> onFloorChanged(i));
        mapControl.setOnMarkerClickListener(this::onMarkerClicked);
        mapControl.addOnCameraIdleListener(this::onCameraIdle);
        mapControl.init(this::mapControlDidInit);
    }

    private void mapControlDidInit(MIError error) {
        Log.d(getLogTag(), "mapControlDidInit()");
        runOnUiThread(() -> {
            if (error == null) {
                afterMapControlInitialized();
            } else {
                Log.d(getLogTag(), error.message);
            }
        });
    }

    protected void afterMapControlInitialized() {
        mapControl.selectFloor(0);
        boolean hideLevels = Utils.Map.getValueFromPath(options, "hideLevels", false);
        mapControl.enableFloorSelector(!hideLevels);
        startPositioning(null);
        fillMarkers();
    }

    private void fillMarkers(){
        if(markers!=null && !markers.isEmpty()){
            for(HashMap markerData: markers){
                Object latVal =  markerData.get("latitude");
                Object lngVal =  markerData.get("longitude");

                double lat = latVal instanceof Double? (double)latVal :
                        latVal instanceof Integer? Double.valueOf((int)latVal) : 0;
                double lng = lngVal instanceof Double? (double)lngVal :
                        lngVal instanceof Integer? Double.valueOf((int)lngVal) : 0;
                String name = markerData.containsKey("name")?(String) markerData.get("name") : "";
                String description = markerData.containsKey("description") && markerData.get("description")!=null?(String) markerData.get("description") : "";

                googleMap.addMarker(new MarkerOptions()
                        .position(new LatLng(lat, lng))
                        .title(name).snippet(description)).showInfoWindow();
            }
        }
    }

    //endregion

    //region MapsIndoors

    protected void onFloorChanged(int floor) {
        Log.d(getLogTag(), "MapControl.onFloorUpdate: " + floor);
    }

    protected void onCameraIdle() {
        Log.d(getLogTag(), "MapControl.onCameraIdle");
    }

    protected boolean onMarkerClicked(Marker marker) {
        Log.d(getLogTag(), "MapControl.onMarkerClicked");
        return false;
    }

    /**
     * PositionProvider interface
     */

    @NonNull
    @Override
    public String[] getRequiredPermissions() {
        return new String[0];
    }

    @Override
    public boolean isPSEnabled() {
        return true;
    }

    @Override
    public void startPositioning(@Nullable String s) {
        startMonitor();
    }

    @Override
    public void stopPositioning(@Nullable String s) {
        stopMonitor();
    }

    @Override
    public boolean isRunning() {
        return isRunning;
    }

    @Override
    public void addOnPositionUpdateListener(@Nullable OnPositionUpdateListener onPositionUpdateListener) {
        this.mpPositionUpdateListener = onPositionUpdateListener;
    }

    @Override
    public void removeOnPositionUpdateListener(@Nullable OnPositionUpdateListener onPositionUpdateListener) {
        this.mpPositionUpdateListener = null;
    }

    @Override
    public void setProviderId(@Nullable String s) {
        Log.d(getLogTag(), "PositionProvider.setProviderId");
    }

    @Override
    public void addOnStateChangedListener(@Nullable OnStateChangedListener onStateChangedListener) {
        Log.d(getLogTag(), "PositionProvider.addOnStateChangedListener");
    }

    @Override
    public void removeOnStateChangedListener(@Nullable OnStateChangedListener onStateChangedListener) {
        Log.d(getLogTag(), "PositionProvider.removeOnStateChangedListener");
    }

    @Override
    public void checkPermissionsAndPSEnabled(PermissionsAndPSListener permissionsAndPSListener) {
        Log.d(getLogTag(), "PositionProvider.checkPermissionsAndPSEnabled");
    }

    @Nullable
    @Override
    public String getProviderId() {
        Log.d(getLogTag(), "PositionProvider.getProviderId");
        return null;
    }

    @Nullable
    @Override
    public PositionResult getLatestPosition() {
        return mpPositionResult;
    }

    @Override
    public void startPositioningAfter(int i, @Nullable String s) {
        new Timer().schedule(new TimerTask() {
            @Override
            public void run() {
                startPositioning(s);
            }
        }, i);
    }

    @Override
    public void terminate() {
        Log.d(getLogTag(), "PositionProvider.terminate");
    }

    //endregion

    //region Core Location

    private void initCoreLocation() {
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this);
        createCoreLocationCallback();
        createCoreLocationRequest();
    }

    private void notifyCoreLocationUpdate() {
        if (coreLocation != null) {
            Point coreLocationPoint = new Point(coreLocation.getLatitude(), coreLocation.getLongitude(), 0);
            MPPositionResult positionResult = new MPPositionResult(coreLocationPoint, 0, 0, 0);
            positionResult.setProvider(this);
            notifyLocationUpdate(positionResult, coreLocation.getTime());
        }
    }

    private void createCoreLocationRequest() {
        coreLocationRequest = com.google.android.gms.location.LocationRequest.create();
        coreLocationRequest.setInterval(60000); //in millis
        coreLocationRequest.setFastestInterval(30000); //in millis
        coreLocationRequest.setPriority(com.google.android.gms.location.LocationRequest.PRIORITY_HIGH_ACCURACY);
    }

    private void createCoreLocationCallback() {
        coreLocationCallback = new LocationCallback() {
            @Override
            public void onLocationResult(LocationResult locationResult) {
                if (locationResult == null) {
                    return;
                }
                for (Location location : locationResult.getLocations()) {
                    coreLocation = location;
                }
                notifyCoreLocationUpdate();
            }
        };
    }

    //endregion

    //region Common Location

    protected void notifyLocationUpdate(MPPositionResult positionResult, long timestamp) {
        if (positionResult != null) {
            mpPositionResult = positionResult;
            locationTimestamp = timestamp;
            if (mpPositionUpdateListener != null) {
                mpPositionUpdateListener.onPositionUpdate(positionResult);
            }
            if (!firstLocationUpdatePassed) {
                firstLocationUpdatePassed = true;
                handleFirstLocationUpdate();
            }
            if ((debugStatusView != null) && showDebugLocation) {
                String sourceAbbr = "CL";
                int sourceColor = Color.rgb(0, 126, 0);
                double lat = 0.0d;
                double lng = 0.0d;
                int floor = 0;
                if (mpPositionResult.getPoint() != null) {
                    lat = mpPositionResult.getPoint().getLat();
                    lng = mpPositionResult.getPoint().getLng();
                    floor = mpPositionResult.getFloor();
                }
                debugStatusView.setText(String.format(Locale.getDefault(), "%s [%.6f, %.6f] @ %d", sourceAbbr, lat, lng, floor));
                debugStatusView.setTextColor(sourceColor);
            }
        }
    }

    protected void notifyLocationFail() {

    }

    protected void handleFirstLocationUpdate() {

    }

    private void startMonitor() {
        if (!isRunning) {
            if (fusedLocationClient != null) {
                fusedLocationClient.requestLocationUpdates(coreLocationRequest, coreLocationCallback, Looper.getMainLooper());
            }
            isRunning = true;
            startLocationTimer();
        }
    }

    private void stopMonitor() {
        if (isRunning) {
            stopLocationTimer();
            if (fusedLocationClient != null) {
                fusedLocationClient.removeLocationUpdates(coreLocationCallback);
            }
            isRunning = false;
        }
    }

    private void startLocationTimer() {
        stopLocationTimer();
        locationTimer = new Timer();
        locationTimer.schedule(new TimerTask() {
            @Override
            public void run() {
                onLocationTimerTimeout();
            }
        }, (4000)); //4 secs
    }

    private void stopLocationTimer() {
        if (locationTimer != null) {
            locationTimer.cancel();
            locationTimer = null;
        }
    }

    protected void onLocationTimerTimeout() {
        stopLocationTimer();
    }

    //endregion

    //region Utilities

    protected String getLogTag() {
        return MapActivity.class.getSimpleName();
    }

    //endregion
}
