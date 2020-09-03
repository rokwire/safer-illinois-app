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

import android.content.Context;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.text.Html;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;

import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.model.CameraPosition;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.gms.maps.model.PolygonOptions;
import com.google.android.gms.maps.model.Polyline;
import com.google.maps.android.ui.IconGenerator;

import org.json.JSONObject;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import edu.illinois.covid.MainActivity;
import edu.illinois.covid.R;
import edu.illinois.covid.Utils;

public class MapDirectionsActivity extends MapActivity {

    //region Class fields

    //Explores - could be Event, Dining, Laundry or ParkingLotInventory
    private Object explore;
    private HashMap exploreLocation;
    private Marker exploreMarker;
    private IconGenerator iconGenerator;
    private View markerLayoutView;
    private View markerGroupLayoutView;
    private float cameraZoom;

    //Navigation
    private CameraPosition cameraPosition;
    private List<Integer> mpRouteStepCoordCounts;
    private Polyline routePolyline;
    private NavStatus navStatus = NavStatus.UNKNOWN;
    private boolean navAutoUpdate;
    private int currentLegIndex = 0;
    private int currentStepIndex = -1;
    private boolean buildRouteAfterInitialization;

    //Navigation UI
    private static final String TRAVEL_MODE_PREFS_KEY = "directions.travelMode";
    private String selectedTravelMode;
    private Map<String, View> travelModesMap;
    private View navRefreshButton;
    private View navTravelModesContainer;
    private View navAutoUpdateButton;
    private View navPrevButton;
    private View navNextButton;
    private TextView navStepLabel;
    private View routeLoadingFrame;

    //endregion

    //region Activity methods

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        initExplore();
        buildTravelModes();
    }

    //endregion

    //region Map views initialization

    @Override
    protected void afterMapInitialized() {
        super.afterMapInitialized();
        buildExploreMarker();
        buildPolygon();
        if (buildRouteAfterInitialization) {
            buildRouteAfterInitialization = false;
            buildRoute();
        }
    }

    //endregion

    //region Common Location

    @Override
    protected void notifyLocationUpdate(long timestamp) {
        super.notifyLocationUpdate(timestamp);
            if ((navStatus == NavStatus.PROGRESS) && navAutoUpdate) {
                updateNavByCurrentLocation();
            }
    }

    @Override
    protected void notifyLocationFail() {
        super.notifyLocationFail();
        handleFirstLocationUpdate();
    }

    @Override
    protected void onLocationTimerTimeout() {
        super.onLocationTimerTimeout();
        if (coreLocation == null) {
            runOnUiThread(() -> {
                enableView(navPrevButton, false);
                enableView(navNextButton, false);
                showLoadingFrame(false);
                showAlert(getString(R.string.locationFailedMsg));
            });
        }
    }

    //endregion

    //region Explores

    private void initExplore() {
        Serializable exploreSeriazible = getIntent().getSerializableExtra("explore");
        if (exploreSeriazible == null) {
            return;
        }
        if (exploreSeriazible instanceof HashMap) {
            HashMap singleExplore;
            singleExplore = (HashMap) exploreSeriazible;
            this.explore = singleExplore;
            initExploreLocation(singleExplore);
        } else if (exploreSeriazible instanceof ArrayList) {
            ArrayList explores = (ArrayList) exploreSeriazible;
            this.explore = explores;
            Object firstExplore = (explores.size() > 0) ? explores.get(0) : null;
            if (firstExplore instanceof HashMap) {
                initExploreLocation((HashMap) firstExplore);
            }
        }
    }

    @Override
    protected void initUiViews() {
        super.initUiViews();
        showDirectionsUiViews();
        iconGenerator = new IconGenerator(this);
        iconGenerator.setBackground(getDrawable(R.color.transparent));
        LayoutInflater inflater = (LayoutInflater) getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        if (inflater != null) {
            markerLayoutView = inflater.inflate(R.layout.marker_info_layout, null);
            markerGroupLayoutView = inflater.inflate(R.layout.marker_group_layout, null);
        }
        navRefreshButton = findViewById(R.id.navRefreshButton);
        navTravelModesContainer = findViewById(R.id.navTravelModesContainer);
        navAutoUpdateButton = findViewById(R.id.navAutoUpdateButton);
        navPrevButton = findViewById(R.id.navPrevButton);
        navNextButton = findViewById(R.id.navNextButton);
        navStepLabel = findViewById(R.id.navStepLabel);
        routeLoadingFrame = findViewById(R.id.routeLoadingFrame);
    }

    private void showDirectionsUiViews() {
        View topNavBar = findViewById(R.id.topNavBar);
        if (topNavBar != null) {
            topNavBar.setVisibility(View.VISIBLE);
        }
        View bottomNavBar = findViewById(R.id.bottomNavBar);
        if (topNavBar != null) {
            bottomNavBar.setVisibility(View.VISIBLE);
        }
    }

    private void buildExploreMarker() {
        if (exploreLocation != null) {
            MarkerOptions markerOptions = Utils.Explore.constructMarkerOptions(this, explore, markerLayoutView, markerGroupLayoutView, iconGenerator);
            if (markerOptions != null) {
                exploreMarker = googleMap.addMarker(markerOptions);
                JSONObject tagJson = Utils.Explore.constructMarkerTagJson(this, exploreMarker.getTitle(), explore);
                exploreMarker.setTag(tagJson);
            }
            updateExploreMarkerAppearance();
        }
    }

    private void updateExploreMarkerAppearance() {
        float currentCameraZoom = googleMap.getCameraPosition().zoom;
        boolean updateMarkerInfo = (currentCameraZoom != cameraZoom);
        if (updateMarkerInfo) {
            boolean singleExploreMarker = Utils.Explore.optSingleExploreMarker(exploreMarker);
            Utils.Explore.updateCustomMarkerAppearance(this, exploreMarker, singleExploreMarker, currentCameraZoom, cameraZoom, markerLayoutView, markerGroupLayoutView, iconGenerator);
        }
        cameraZoom = currentCameraZoom;
    }

    private void initExploreLocation(HashMap singleExplore) {
        Utils.ExploreType exploreType = Utils.Explore.getExploreType(singleExplore);
        if (exploreType == Utils.ExploreType.PARKING) {
            LatLng latLng = Utils.Explore.optLocationLatLng(singleExplore);
            if (latLng != null) {
                this.exploreLocation = Utils.Explore.createLocationMap(latLng);
            }
        } else {
            this.exploreLocation = Utils.Explore.optLocation(singleExplore);
        }
    }

    private void buildPolygon() {
        if (googleMap == null) {
            return;
        }
        List<LatLng> polygonPoints = Utils.Explore.getExplorePolygon(explore);
        if ((polygonPoints == null) || polygonPoints.isEmpty()) {
            return;
        }
        Utils.ExploreType exploreType = Utils.Explore.getExploreType(explore);
        int strokeColor = getResources().getColor(Utils.Explore.getExploreColorResource(exploreType));
        int fillColor = Color.argb(10, 0, 0, 0);
        googleMap.addPolygon(new PolygonOptions().addAll(polygonPoints).
                clickable(false).strokeColor(strokeColor).strokeWidth(5.0f).fillColor(fillColor).zIndex(1.0f));
    }

    //endregion

    //region Navigation

    public void onRefreshNavClicked(View view) {
        if (routePolyline != null) {
            routePolyline.remove();
            routePolyline = null;
        }
        mpRouteStepCoordCounts = null;
        navStatus = NavStatus.UNKNOWN;
        navAutoUpdate = false;

        if (cameraPosition != null && googleMap != null) {
            googleMap.animateCamera(CameraUpdateFactory.newLatLngZoom(cameraPosition.target, cameraPosition.zoom));
        }
        cameraPosition = null;

        updateNav();
        buildRoute();
    }

    public void onAutoUpdateNavClicked(View view) {
        if (navStatus == NavStatus.PROGRESS) {
            MPRouteSegmentPath segmentPath = findNearestRouteSegmentByCurrentLocation();
            if (isValidSegmentPath(segmentPath)) {
                currentLegIndex = segmentPath.legIndex;
                currentStepIndex = segmentPath.stepIndex;
                navAutoUpdate = true;
            }
            updateNav();
        }
    }

    public void onWalkTravelModeClicked(View view) {
        changeSelectedTravelMode("WALKING");
    }

    public void onBikeTravelModeClicked(View view) {
        changeSelectedTravelMode("BICYCLING");
    }

    public void onDriveTravelModeClicked(View view) {
        changeSelectedTravelMode("DRIVING");
    }

    public void onTransitTravelModeClicked(View view) {
        changeSelectedTravelMode("TRANSIT");
    }

    public void onPrevNavClicked(View view) {
    }

    public void onNextNavClicked(View view) {
    }

    private void buildTravelModes() {
    }

    private void buildRoute() {
    }

    private void buildRoute(String travelModeValue) {
    }

    private void changeSelectedTravelMode(String newTravelMode) {

    }

    @Override
    protected void handleFirstLocationUpdate() {
    }

    private void updateNav() {
    }

    private void updateNavAutoUpdate() {
        MPRouteSegmentPath segmentPath = findNearestRouteSegmentByCurrentLocation();
        navAutoUpdate = (isValidSegmentPath(segmentPath) &&
                (currentLegIndex == segmentPath.legIndex) &&
                (currentStepIndex == segmentPath.stepIndex));
    }

    private void updateNavByCurrentLocation() {
        if ((navStatus == NavStatus.PROGRESS) && navAutoUpdate) {
            MPRouteSegmentPath segmentPath = findNearestRouteSegmentByCurrentLocation();
            if (isValidSegmentPath(segmentPath)) {
                updateNavFromSegmentPath(segmentPath);
            }
        }
    }

    private void updateNavFromSegmentPath(MPRouteSegmentPath segmentPath) {
        boolean modified = false;
        if (currentLegIndex != segmentPath.legIndex) {
            currentLegIndex = segmentPath.legIndex;
            modified = true;
        }
        if (currentStepIndex != segmentPath.stepIndex) {
            currentStepIndex = segmentPath.stepIndex;
            modified = true;
        }
        if (modified) {
            updateNav();
        }
    }

    @NonNull
    private MPRouteSegmentPath findNearestRouteSegmentByCurrentLocation() {
        MPRouteSegmentPath minRouteSegmentPath = new MPRouteSegmentPath(-1, -1);
        return minRouteSegmentPath;
    }

    private boolean isValidSegmentPath(MPRouteSegmentPath segmentPath) {
        return false;
    }

    private void setStepHtml(String htmlContent) {
        String formattedHtml = String.format("<html><body><center>%s</center></body></html>", htmlContent);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            navStepLabel.setText(Html.fromHtml(formattedHtml, Html.FROM_HTML_MODE_COMPACT));
        } else {
            navStepLabel.setText(Html.fromHtml(formattedHtml));
        }
    }

    private String buildRouteDisplayDescription() {
        return null;
    }

    private void notifyRouteStart() {
        notifyRouteEvent("map.route.start");
    }

    private void notifyRouteFinish() {
        notifyRouteEvent("map.route.finish");
    }

    private void notifyRouteEvent(String event) {
        String originString = null;
        String destinationString = null;
        String locationString = null;

        String analyticsParam = String.format(Locale.getDefault(), "{\"origin\":%s,\"destination\":%s,\"location\":%s}", originString, destinationString, locationString);
        MainActivity.invokeFlutterMethod(event, analyticsParam);
    }

    //endregion

    //region Utilities

    @Override
    protected String getLogTag() {
        return MapDirectionsActivity.class.getSimpleName();
    }

    private void showLoadingFrame(boolean show) {
        if (routeLoadingFrame != null) {
            routeLoadingFrame.setVisibility(show ? View.VISIBLE : View.GONE);
        }
    }

    private void showAlert(String message) {
        String appName = getString(R.string.app_name);
        AlertDialog.Builder alertBuilder = new AlertDialog.Builder(this);
        alertBuilder.setTitle(appName);
        alertBuilder.setMessage(message);
        alertBuilder.setPositiveButton(R.string.ok, null);
        alertBuilder.show();
    }

    private void enableView(View view, boolean enabled) {
        if (view == null) {
            return;
        }
        float viewAlpha = enabled ? 1.0f : 0.5f;
        view.setEnabled(enabled);
        view.setAlpha(viewAlpha);
    }

    //endregion

    //region NavStatus

    private enum NavStatus {UNKNOWN, START, PROGRESS, FINISHED}

    //endregion

    //region MPRouteSegmentPath

    private static class MPRouteSegmentPath {
        private int legIndex;
        private int stepIndex;

        private MPRouteSegmentPath(int legIndex, int stepIndex) {
            this.legIndex = legIndex;
            this.stepIndex = stepIndex;
        }
    }

    //endregion
}
