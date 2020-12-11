////  MapDirectionsController.m
//  Runner
//
//  Created by Mihail Varbanov on 12/8/20.
//  Copyright 2020 Board of Trustees of the University of Illinois.
	
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//    http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "MapDirectionsController.h"
#import "AppDelegate.h"
#import "MapRoute.h"

#import <GoogleMaps/GoogleMaps.h>
#import <CoreLocation/CoreLocation.h>

#import "UILabel+InaMeasure.h"
#import "NSDictionary+InaTypedValue.h"
#import "NSDictionary+UIUCConfig.h"
#import "NSUserDefaults+InaUtils.h"
#import "UIColor+InaParse.h"
#import "CLLocationCoordinate2D+InaUtils.h"
#import "InaSymbols.h"

typedef NS_ENUM(NSInteger, NavStatus) {
	NavStatus_Unknown,
	NavStatus_Start,
	NavStatus_Progress,
	NavStatus_Finished,
};

typedef NS_ENUM(NSInteger, RouteStatus) {
	RouteStatus_Unknown,
	RouteStatus_Progress,
	RouteStatus_Finished,
};

static float const kDefaultZoom = 17;
static float const kCurrentLocationUpdateThreshold = 1; // in meters

static NSString* const kTravelModes[] = { @"walking", @"bicycling", @"driving", @"transit" };
static CLLocationDistance const kInstructionDistanceThresholds[] = { 10, 15, 25, 20 };
static NSString* const kTravelModeKey = @"mapDirections.travelMode";

NSString* travelModeString(NSInteger travelMode);
NSInteger travelModeIndex(NSString* value);

@interface MapDirectionsController()<GMSMapViewDelegate, CLLocationManagerDelegate>

@property (nonatomic) UIActivityIndicatorView* activityIndicator;
@property (nonatomic) UILabel* activityStatus;
@property (nonatomic) UILabel* contentStatus;

@property (nonatomic) GMSMapView *mapView;

@property (nonatomic) UISegmentedControl* navTravelModesCtrl;
@property (nonatomic) UIButton* navRefreshButton;
@property (nonatomic) UIButton* navAutoUpdateButton;
@property (nonatomic) UIButton* navPrevButton;
@property (nonatomic) UIButton* navNextButton;
@property (nonatomic) UILabel* navStepLabel;

@property (nonatomic) CLLocation* targetLocation;

@property (nonatomic) CLLocationManager* locationManager;
@property (nonatomic) bool requestingAuthorization;

@property (nonatomic) CLLocation* currentLocation;
@property (nonatomic) NSError* currentLocationError;
@property (nonatomic) bool requestingCurrentLocation;

@property (nonatomic) MapRoute* route;
@property (nonatomic) RouteStatus routeStatus;

@property (nonatomic) GMSPolyline* stepPolyline;
@property (nonatomic) GMSMarker* stepStartMarker;
@property (nonatomic) GMSMarker* stepEndMarker;
@property (nonatomic) GMSMarker* currentLocationMarker;

@property (nonatomic) bool firstLocationUpdate;
@property (nonatomic) NSInteger travelMode;
@property (nonatomic) NavStatus navStatus;
@property (nonatomic) NavStatus navAutoUpdate;
@property (nonatomic) NSInteger navStepIndex;
@property (nonatomic) NSInteger navInstrIndex;

@end

@implementation MapDirectionsController

- (instancetype)init {
	if (self = [super init]) {
		self.navigationItem.title = NSLocalizedString(@"Directions", nil);

		_locationManager = [[CLLocationManager alloc] init];
		_locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
//	_locationManager.distanceFilter = kCurrentLocationUpdateThreshold;
		_locationManager.delegate = self;
		
		_travelMode = MAX(travelModeIndex([[NSUserDefaults standardUserDefaults] inaStringForKey:kTravelModeKey]), 0);
	}
	return self;
}

- (instancetype)initWithParameters:(NSDictionary*)parameters completionHandler:(FlutterCompletion)completionHandler {
	if (self = [self init]) {
		_parameters = parameters;
		_completionHandler = completionHandler;
	}
	return self;
}

- (void)loadView {
	self.view = [[UIView alloc] initWithFrame:CGRectZero];
	self.view.backgroundColor = [UIColor whiteColor];

	_contentStatus = [[UILabel alloc] initWithFrame:CGRectZero];
	_contentStatus.font = [UIFont systemFontOfSize:18];
	_contentStatus.textAlignment = NSTextAlignmentCenter;
	_contentStatus.textColor = [UIColor blackColor];
	_contentStatus.numberOfLines = 0;
	[self.view addSubview:_contentStatus];
	
	_activityStatus = [[UILabel alloc] initWithFrame:CGRectZero];
	_activityStatus.font = [UIFont systemFontOfSize:16];
	_activityStatus.textAlignment = NSTextAlignmentCenter;
	_activityStatus.textColor = [UIColor darkGrayColor];
	_activityStatus.numberOfLines = 0;
	[self.view addSubview:_activityStatus];

	_activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	_activityIndicator.color = [UIColor blackColor];
	[self.view addSubview:_activityIndicator];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildInitialContent];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutSubViews];
	if (!_firstLocationUpdate && (0 < _mapView.frame.size.width) && (0 < _mapView.frame.size.height)) {
		[self initialUpdateMap];
		_firstLocationUpdate = true;
	}
}

- (void)layoutSubViews {

	CGSize contentSize = self.view.frame.size;
	
	CGSize contentGutter = CGSizeMake(32, 32);
	CGFloat contentInnerW = MAX(contentSize.width - 2 * contentGutter.width, 0);
	
	CGSize activityIndSize = [_activityIndicator sizeThatFits:contentSize];
	CGFloat activityIndY = contentSize.height / 2 - activityIndSize.height - 8;
	_activityIndicator.frame = CGRectMake((contentSize.width - activityIndSize.width) / 2, activityIndY, activityIndSize.width, activityIndSize.height);
	
	CGSize activityTxtSize = [_activityStatus inaTextSizeForBoundWidth:contentInnerW];
	CGFloat activityTxtY = contentSize.height / 2 + 8;
	_activityStatus.frame = CGRectMake(contentGutter.width, activityTxtY, contentInnerW, activityTxtSize.height);

	CGSize statusTxtSize = [_contentStatus inaTextSizeForBoundWidth:contentInnerW];
	_contentStatus.frame = CGRectMake(contentGutter.width, (contentSize.height - statusTxtSize.height) / 2, contentInnerW, statusTxtSize.height);

	_mapView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);

	CGFloat navBtnSize = 42;
	CGFloat navX = 0, navY, navW = contentSize.width;
	navX += navBtnSize / 2; navW = MAX(navW - navBtnSize, 0);
	
	navY = navBtnSize / 2;
	_navRefreshButton.frame = CGRectMake(navX, navY, navBtnSize, navBtnSize);
	
	CGFloat navAutoUpdateX = navX + 3 * navBtnSize / 2;
	_navAutoUpdateButton.frame = CGRectMake(navAutoUpdateX, navY, navBtnSize, navBtnSize);
	
	CGFloat navTravelModeBtnSize = 36;
	CGSize navTravelModesSize = CGSizeMake(navTravelModeBtnSize * _navTravelModesCtrl.numberOfSegments * 3 / 2, navTravelModeBtnSize);
	_navTravelModesCtrl.frame = CGRectMake(contentSize.width - navTravelModesSize.width - 4, navY + (navBtnSize - navTravelModeBtnSize) / 2, navTravelModesSize.width, navTravelModesSize.height);
	
	navY = contentSize.height - 2 * navBtnSize;
	_navPrevButton.frame = CGRectMake(navX, navY, navBtnSize, navBtnSize);
	_navNextButton.frame = CGRectMake(navX + navW - navBtnSize, navY, navBtnSize, navBtnSize);

	navX += navBtnSize; navW = MAX(navW - 2 * navBtnSize, 0);
	CGFloat stepTxtH = [_navStepLabel inaAttributedTextSizeForBoundWidth:navW].height;
	_navStepLabel.frame = CGRectMake(navX, navY + (navBtnSize - stepTxtH) / 2, navW, stepTxtH);
}

- (void)buildInitialContent {
	[self ensureTargetLocation] ||
	[self ensureLocationServices] ||
	[self ensureCurrentLocation] ||
	[self ensureRoute] ||
	[self ensureMapView];
}

- (bool)ensureMapView {
	if (_mapView == nil) {
		GMSCameraPosition *camera = nil;
		if (_route != nil)  {
			camera = [GMSCameraPosition cameraWithTarget:_route.legs.firstObject.startLocation.coordinate zoom:kDefaultZoom];
		}
		else if (_targetLocation != nil) {
			camera = [GMSCameraPosition cameraWithTarget:_targetLocation.coordinate zoom:self.targetZoom];
		}
		else {
			[self buildContentStatus:@"Internal Error Occured"];
			return true;
		}

		_mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
		_mapView.delegate = self;
		[self.view insertSubview:_mapView atIndex:0];
		
		[self buildNavControls];
		
		if (_route != nil) {
			_navStatus = NavStatus_Start;
			_navStepIndex = _navInstrIndex = -1;
			[self initRoutePreview];
		}
		else {
			_navStatus = NavStatus_Unknown;
			_navStepIndex = _navInstrIndex = -1;
			[self initLocationPreview];
		}

		[self updateNav];
	}
	return true;
}

- (void)buildNavControls {
	_navTravelModesCtrl = [[UISegmentedControl alloc] initWithFrame:CGRectZero];
	_navTravelModesCtrl.tintColor = [UIColor inaColorWithHex:@"#606060"];
	[_navTravelModesCtrl addTarget:self action:@selector(didNavTravelMode) forControlEvents:UIControlEventValueChanged];
	[self buildTravelModeSegments];
	[_navTravelModesCtrl setSelectedSegmentIndex:_travelMode];
	[_mapView addSubview:_navTravelModesCtrl];

	_navRefreshButton = [[UIButton alloc] initWithFrame:CGRectZero];
	[_navRefreshButton setExclusiveTouch:YES];
	[_navRefreshButton setImage:[UIImage imageNamed:@"button-icon-nav-refresh"] forState:UIControlStateNormal];
	[_navRefreshButton addTarget:self action:@selector(didNavRefresh) forControlEvents:UIControlEventTouchUpInside];
	[_mapView addSubview:_navRefreshButton];
	
	_navAutoUpdateButton = [[UIButton alloc] initWithFrame:CGRectZero];
	[_navAutoUpdateButton setExclusiveTouch:YES];
	[_navAutoUpdateButton setImage:[UIImage imageNamed:@"button-icon-nav-location"] forState:UIControlStateNormal];
	[_navAutoUpdateButton addTarget:self action:@selector(didNavAutoUpdate) forControlEvents:UIControlEventTouchUpInside];
	[_mapView addSubview:_navAutoUpdateButton];

	_navPrevButton = [[UIButton alloc] initWithFrame:CGRectZero];
	[_navPrevButton setExclusiveTouch:YES];
	[_navPrevButton setImage:[UIImage imageNamed:@"button-icon-nav-prev"] forState:UIControlStateNormal];
	[_navPrevButton addTarget:self action:@selector(didNavPrev) forControlEvents:UIControlEventTouchUpInside];
	[_mapView addSubview:_navPrevButton];

	_navNextButton = [[UIButton alloc] initWithFrame:CGRectZero];
	[_navNextButton setExclusiveTouch:YES];
	[_navNextButton setImage:[UIImage imageNamed:@"button-icon-nav-next"] forState:UIControlStateNormal];
	[_navNextButton addTarget:self action:@selector(didNavNext) forControlEvents:UIControlEventTouchUpInside];
	[_mapView addSubview:_navNextButton];

	_navStepLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_navStepLabel.font = [UIFont systemFontOfSize:18];
	_navStepLabel.numberOfLines = 3;
	_navStepLabel.textAlignment = NSTextAlignmentCenter;
	_navStepLabel.textColor = [UIColor blackColor];
	_navStepLabel.shadowColor = [UIColor colorWithWhite:1 alpha:0.5];
	_navStepLabel.shadowOffset = CGSizeMake(2, 2);
	[_mapView addSubview:_navStepLabel];
}

- (void)initialUpdateMap {
	if (_route != nil) {
		[self initRoutePreview];
	}
	else {
		[self initLocationPreview];
	}
}

- (void)initRoute {
	if (_navStatus == NavStatus_Progress) {
		[self initRouteStep];
	}
	else {
		[self initRoutePreview];
	}
}

- (void)initRoutePreview {

	if ((_route != nil) && (0 < _mapView.frame.size.width) && (0 < _mapView.frame.size.height)) {
		[self clearMap];
		
		// add overview polyline
		if (_route.overviewPolyline != nil) {
			GMSMutablePath *path = [GMSMutablePath path];
			for (MapLocation *location in _route.overviewPolyline)
				[path addCoordinate:location.coordinate];
			
			GMSPolyline *polyline = [GMSPolyline polylineWithPath:path];
			polyline.strokeColor = [UIColor colorWithRed:0.17 green:0.60 blue:0.94 alpha:1.0];
			polyline.strokeWidth = 2.0f;
			polyline.map = _mapView;
		}
		
		// add start location marker
		MapLeg *firstLeg = _route.legs.firstObject;
		if (firstLeg.startLocation != nil) {
			GMSMarker *startLocationMarker = [GMSMarker markerWithPosition:firstLeg.startLocation.coordinate];
			startLocationMarker.title = firstLeg.startAddress;
			startLocationMarker.icon = [UIImage imageNamed:@"maps-icon-marker-origin-small.png"];
			startLocationMarker.groundAnchor = CGPointMake(0.5, 0.5);
			startLocationMarker.map = _mapView;
		}
		
		// add end location marker
		MapLeg *lastLeg = _route.legs.lastObject;
		if (lastLeg.endLocation != nil) {
			GMSMarker *endLocationMarker = [GMSMarker markerWithPosition:lastLeg.endLocation.coordinate];
			endLocationMarker.title = self.targetTitle ?: lastLeg.endAddress;
			endLocationMarker.snippet = self.targetDescription;
			endLocationMarker.icon = [UIImage imageNamed:@"maps-icon-marker-origin-small.png"];
			endLocationMarker.groundAnchor = CGPointMake(0.5, 0.5);
			endLocationMarker.map = _mapView;
		}
		
		// camera position
		if (_route.bounds != nil) {
			GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:_route.bounds.northeast.coordinate coordinate:_route.bounds.southwest.coordinate];
			GMSCameraPosition *camera = [_mapView cameraForBounds:bounds insets:UIEdgeInsetsMake(64, 48, 64, 48)];
			[_mapView animateToCameraPosition:camera];
		}
	}
}

- (void)initRouteStep {

	if ((_route != nil) && (0 < _mapView.frame.size.width) && (0 < _mapView.frame.size.height)) {
		
		MapStep *routeStep = ((0 <= _navStepIndex) && (_navStepIndex < _route.steps.count)) ? [_route.steps objectAtIndex:_navStepIndex] : nil;
		
		// add step polyline
		if (_stepPolyline.map != nil) {
			_stepPolyline.map = nil;
		}
		if (routeStep.polyline != nil) {
			GMSMutablePath *path = [GMSMutablePath path];
			for (MapLocation *location in routeStep.polyline)
				[path addCoordinate:location.coordinate];
			
			_stepPolyline = [GMSPolyline polylineWithPath:path];
			_stepPolyline.strokeColor = [UIColor colorWithRed:0.17 green:0.60 blue:0.94 alpha:1.0];
			_stepPolyline.strokeWidth = 5.0f;
			_stepPolyline.map = _mapView;
		}
		
		// add start location marker
		if (_stepStartMarker.map != nil) {
			_stepStartMarker.map = nil;
		}
		if (routeStep.startLocation != nil) {
			_stepStartMarker = [GMSMarker markerWithPosition:routeStep.startLocation.coordinate];
			_stepStartMarker.icon = [UIImage imageNamed:@"maps-icon-marker-origin-large.png"];
			_stepStartMarker.groundAnchor = CGPointMake(0.5, 0.5);
			_stepStartMarker.map = _mapView;
		}
		
		// add end location marker
		if (_stepEndMarker.map != nil) {
			_stepEndMarker.map = nil;
		}
		if (routeStep.endLocation != nil) {
			_stepEndMarker = [GMSMarker markerWithPosition:routeStep.endLocation.coordinate];
			_stepEndMarker.icon = [UIImage imageNamed:@"maps-icon-marker-origin-large.png"];
			_stepEndMarker.groundAnchor = CGPointMake(0.5, 0.5);
			_stepEndMarker.map = _mapView;
		}
		
		// camera position
		if ((routeStep.startLocation != nil) && (routeStep.endLocation != nil)) {
			GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:routeStep.startLocation.coordinate coordinate:routeStep.endLocation.coordinate];
			GMSCameraPosition *camera = [_mapView cameraForBounds:bounds insets:UIEdgeInsetsMake(96, 48, 96, 48)];
			[_mapView animateToCameraPosition:camera];
		}
	}
}

- (void)initLocationPreview {
	if ((0 < _mapView.frame.size.width) && (0 < _mapView.frame.size.height)) {
		[self clearMap];

		// add target location marker
		if (_targetLocation != nil) {
			GMSMarker *endLocationMarker = [GMSMarker markerWithPosition:_targetLocation.coordinate];
			endLocationMarker.icon = [UIImage imageNamed:@"maps-icon-marker-origin-small.png"];
			endLocationMarker.groundAnchor = CGPointMake(0.5, 0.5);
			endLocationMarker.title = self.targetTitle;
			endLocationMarker.snippet = self.targetDescription;
			endLocationMarker.map = _mapView;
		}

		// camera position
		if (_targetLocation != nil) {
			GMSCameraPosition *camera = nil;
			if (_currentLocation != nil) {
				GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:_currentLocation.coordinate coordinate:_targetLocation.coordinate];
				camera = [_mapView cameraForBounds:bounds insets:UIEdgeInsetsMake(96, 48, 96, 48)];
			}
			else {
				camera = [GMSCameraPosition cameraWithTarget:_targetLocation.coordinate zoom:self.targetZoom];
			}
			[_mapView animateToCameraPosition:camera];
		}
	}
}

- (void)clearMap {
	[_mapView clear];
	
	_stepPolyline = nil;
	_stepStartMarker = nil;
	_stepEndMarker = nil;
	_currentLocationMarker = nil;
	[self updateCurrentLocationMarker];
}

- (void)updateCurrentLocationMarker {
	if ((_currentLocation != nil) && (_mapView != nil)) {
		if (_currentLocationMarker != nil) {
			if (CLLocationCoordinate2DInaDistance(_currentLocationMarker.position, _currentLocation.coordinate) < kCurrentLocationUpdateThreshold) {
				return;
			}
			else {
				_currentLocationMarker.map = nil;
			}
		}
		_currentLocationMarker = [GMSMarker markerWithPosition:_currentLocation.coordinate];
		_currentLocationMarker.icon = [UIImage imageNamed:@"maps-icon-marker-my-location.png"];
		_currentLocationMarker.groundAnchor = CGPointMake(0.5, 0.5);
		_currentLocationMarker.zIndex = 1;
		_currentLocationMarker.map = _mapView;

		[self updateNavByCurrentLocation];
	}
}

- (void)initMapMarkers {
	NSArray *markers = [_parameters inaArrayForKey:@"markers"];
	for (NSDictionary *markerJson in markers) {
		if ([markerJson isKindOfClass:[NSDictionary class]]) {
			GMSMarker *marker = [[GMSMarker alloc] init];
			CLLocationDegrees markerLatitude = [markerJson inaDoubleForKey:@"latitude"];
			CLLocationDegrees markerLongitude = [markerJson inaDoubleForKey:@"longitude"];
			marker.position = CLLocationCoordinate2DMake(markerLatitude, markerLongitude);
			marker.title = [markerJson inaStringForKey:@"name"];
			marker.snippet = [markerJson inaStringForKey:@"description"];
			marker.map = _mapView;
		}
	}
}

- (void)updateNav {
	_navRefreshButton.hidden = (_currentLocation == nil) || (_targetLocation == nil);
	_navRefreshButton.enabled = (_routeStatus != RouteStatus_Progress);

	_navTravelModesCtrl.hidden = (_currentLocation == nil) || (_targetLocation == nil) || (_navStatus == NavStatus_Progress);
	_navTravelModesCtrl.enabled = (_routeStatus != RouteStatus_Progress);

	_navAutoUpdateButton.hidden = (_navStatus != NavStatus_Progress) || _navAutoUpdate;
	_navPrevButton.hidden = _navNextButton.hidden = _navStepLabel.hidden = (_navStatus == NavStatus_Unknown);

	if (_navStatus == NavStatus_Start) {
		[self setStepHtml:[NSString stringWithFormat:@"<b>%@</b><br>(%@, %@)",
			NSLocalizedString(@"START", nil), _route.distance.text, _route.duration.text]];
		_navPrevButton.enabled = false;
		_navNextButton.enabled = true;
	}
	else if (_navStatus == NavStatus_Progress) {
		[self setStepHtml:self.progressStepInstruction];
		_navPrevButton.enabled = _navNextButton.enabled = true;
	}
	else if (_navStatus == NavStatus_Finished) {
		[self setStepHtml:[NSString stringWithFormat:@"<b>%@</b>", NSLocalizedString(@"FINISH", nil)]];
		_navPrevButton.enabled = true;
		_navNextButton.enabled = false;
	}
	else {
		_navStepLabel.text = nil;
	}
}

- (NSString*)progressStepInstruction {
	NSString *stepInstr = nil;
	NSInteger stepIndex = _navStepIndex;
	if (_navAutoUpdate && (0 <= _navInstrIndex)) {
		if (_navInstrIndex < _route.steps.count) {
			stepIndex = _navInstrIndex;
		}
		else {
			stepInstr = @"<b>Arrival</b> at the destination";
		}
	}
	if ((stepInstr == nil) && (0 <= stepIndex) && (stepIndex < _route.steps.count)) {
		MapStep *step = [_route.steps objectAtIndex:stepIndex];
		stepInstr = step.htmlInstructions;
	}
	return stepInstr;
}

- (bool)ensureTargetLocation {
	if (_targetLocation == nil) {
		NSDictionary *target = [_parameters inaDictForKey:@"target"];
		NSNumber *latitude = [target inaNumberForKey:@"latitude"];
		NSNumber *longitude = [target inaNumberForKey:@"longitude"];
		NSNumber *zoom = [target inaNumberForKey:@"zoom"];
		if ((latitude != nil) && (longitude != nil)) {
			_targetLocation = [[CLLocation alloc] initWithLatitude:latitude.doubleValue longitude:longitude.doubleValue];
		}
		else {
			[self buildContentStatus:@"Missing target location"];
			return true;
		}
	}
	return false;
}

- (float)targetZoom {
	NSDictionary *target = [_parameters inaDictForKey:@"target"];
	NSNumber *zoom = [target inaNumberForKey:@"zoom"];
	return (zoom != nil) ? zoom.floatValue : kDefaultZoom;
}

- (NSString*)targetTitle {
	NSDictionary *target = [_parameters inaDictForKey:@"target"];
	return [target inaStringForKey:@"title"];
}

- (NSString*)targetDescription {
	NSDictionary *target = [_parameters inaDictForKey:@"target"];
	return [target inaStringForKey:@"description"];
}

- (bool)ensureLocationServices {
	if (CLLocationManager.locationServicesEnabled && (CLLocationManager.authorizationStatus == kCLAuthorizationStatusNotDetermined)) {
		if (!_requestingAuthorization) {
			_requestingAuthorization = true;
			[self buildActivityStatus:@"Requesting permisions"];
			[_locationManager requestAlwaysAuthorization];
		}
		return true;
	}
	return false;
}

- (bool)ensureCurrentLocation {
	if ((_currentLocation == nil) &&
	    (_currentLocationError == nil) &&
	    CLLocationManager.locationServicesEnabled &&
	    ((CLLocationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways) || (CLLocationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse))) {
		if (!_requestingCurrentLocation) {
			_requestingCurrentLocation = true;
			[self buildActivityStatus:@"Requesting location"];
			[_locationManager startUpdatingLocation];
		}
		return true;
	}
	return false;
}

- (bool)ensureRoute {
	if ((_routeStatus != RouteStatus_Finished) && (_targetLocation != nil)) {
	    
		if (_routeStatus == RouteStatus_Progress) {
			return true;
		}
		else if (_currentLocation != nil) {
			_routeStatus = RouteStatus_Progress;
			[self buildActivityStatus:@"Building route"];
			[self updateNav];

			__weak typeof(self) weakSelf = self;
			[self requestRouteWithCompletionHandler:^(MapRoute *route) {
				weakSelf.route = route;
				weakSelf.routeStatus = RouteStatus_Finished;
				weakSelf.navStatus = (route != nil) ? NavStatus_Start : NavStatus_Unknown;
				[weakSelf clearActiviyStatus];
				if (weakSelf.mapView != nil) {
					[self initialUpdateMap];
				}
				else {
					[weakSelf buildInitialContent];
				}
				[self updateNav];
			}];
			return true;
		}
	}
	if (_mapView != nil) {
		[self initialUpdateMap];
	}
	return false;
}

- (void)requestRouteWithCompletionHandler:(void (^)(MapRoute* route))completionHandler {
	NSString *travelMode = (0 <= _travelMode) && (_travelMode < _countof(kTravelModes)) ? kTravelModes[_travelMode] : kTravelModes[0];
	NSString *languageCode = @"en";
	NSString *apiKey = [AppDelegate.sharedInstance.keys uiucConfigStringForPathKey:@"google.maps.api_key"];
	NSString *urlString = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/directions/json?origin=%.6f,%.6f&destination=%.6f,%.6f&sensor=true&alternatives=false&mode=%@&language=%@&units=imperial&key=%@",
		_currentLocation.coordinate.latitude, _currentLocation.coordinate.longitude,
		_targetLocation.coordinate.latitude, _targetLocation.coordinate.longitude,
		travelMode, languageCode, apiKey
	];
	
	[[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {

		MapRoute *route = nil;
		if ((data != nil) && (error == nil)) {
			NSDictionary *responseJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
			if ([responseJson isKindOfClass:[NSDictionary class]]) {
				NSDictionary *routeJson = [[responseJson inaArrayForKey:@"routes"] firstObject];
				if ([routeJson isKindOfClass:[NSDictionary class]]) {
					route = [MapRoute createFromJson:routeJson];
				}
			}
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (completionHandler != nil) {
				completionHandler(route);
			}
		});
	}] resume];
}

- (NSInteger)stepIndexFromCurrentLocation {
	NSInteger minStepIndex = -1;
	CLLocationDistance minStepDistance = DBL_MAX;
	if ((_currentLocation != nil) && (_route != nil)) {
		for (NSInteger index = 0; index < _route.steps.count; index++ ) {
			MapStep *step = [_route.steps objectAtIndex:index];
			if ((step.startLocation != nil) && (step.endLocation != nil)) {
				CLLocationDistance distance =
					CLLocationCoordinate2DInaDistance(step.startLocation.coordinate, _currentLocation.coordinate) +
					CLLocationCoordinate2DInaDistance(_currentLocation.coordinate, step.endLocation.coordinate) -
					CLLocationCoordinate2DInaDistance(step.startLocation.coordinate, step.endLocation.coordinate);
				if (distance < minStepDistance) {
					minStepIndex = index;
					minStepDistance = distance;
				}
			}
		}
	}
	return minStepIndex;
}

- (NSInteger)instructionIndexFromCurrentLocationUsingStepIndex:(NSInteger)stepIndex {
	MapStep *step = ((0 <= stepIndex) && (stepIndex < _route.steps.count)) ? [_route.steps objectAtIndex:stepIndex] : nil;
	if ((step.endLocation != nil) && (_currentLocation != nil)) {
		NSInteger stepTravelMode = travelModeIndex(step.travelMode);
		CLLocationDistance endThreshold = ((0 <= stepTravelMode) && (stepTravelMode < _countof(kInstructionDistanceThresholds))) ? kInstructionDistanceThresholds[stepTravelMode] : 0;
		CLLocationDistance distanceToEnd = CLLocationCoordinate2DInaDistance(_currentLocation.coordinate, step.endLocation.coordinate);
		return (distanceToEnd < endThreshold) ? (stepIndex + 1) : stepIndex;
	}
	return -1;
}

- (void)updateNavByCurrentLocation {
	if ((_route != nil) && (_currentLocation != nil) && (_navStatus == NavStatus_Progress) && _navAutoUpdate) {
		NSInteger stepIndex = [self stepIndexFromCurrentLocation];
		NSInteger instrIndex = [self instructionIndexFromCurrentLocationUsingStepIndex:stepIndex];
		NSInteger lastStepIndex = _navStepIndex, lastInstrIndex = _navInstrIndex;
		if ((0 <= stepIndex) && (stepIndex < _route.steps.count) && (stepIndex != _navStepIndex)) {
			_navStepIndex = stepIndex;
			[self initRouteStep];
		}
		if ((0 <= instrIndex) && (instrIndex <= _route.steps.count) && (_navInstrIndex != instrIndex)) {
			_navInstrIndex = instrIndex;
		}
		if ((lastStepIndex != _navStepIndex) || (lastInstrIndex != _navInstrIndex)) {
			[self updateNav];
		}
	}
}

- (void)turnOffAutoUpdateIfNeeded {
	if ((_route != nil) && (_currentLocation != nil) && _navAutoUpdate &&
	    ((_navStatus != NavStatus_Progress) || (_navStepIndex != [self stepIndexFromCurrentLocation]))) {
		_navAutoUpdate = false;
		_navInstrIndex = -1;
	}
}

- (void)buildContentStatus:(NSString*)status {
	_contentStatus.text = status;
	_activityStatus.text = nil;
	[_activityIndicator stopAnimating];
	[self.view setNeedsLayout];
}

- (void)buildActivityStatus:(NSString*)status {
	_contentStatus.text = nil;
	_activityStatus.text = status;
	[_activityIndicator startAnimating];
	[self.view setNeedsLayout];
}

- (void)clearActiviyStatus {
	_activityStatus.text = nil;
	[_activityIndicator stopAnimating];
	[self.view setNeedsLayout];
}

- (void)setStepHtml:(NSString*)htmlContent {

	NSString *html = [NSString stringWithFormat:@"<html>\
		<head><style>body { margin: 0px; padding: 0px; text-align:center; font-family: Helvetica; font-weight: regular; font-size: 18px; color:#000000 } </style></head>\
		<body>%@</body>\
	</html>", htmlContent];
	
	NSAttributedString *attributedString = [[NSAttributedString alloc]
		initWithData:[html dataUsingEncoding:NSUTF8StringEncoding]
		options:@{
			NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
			NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)
		}
		documentAttributes:nil
		error:nil
	];
	
	if (![_navStepLabel.attributedText isEqualToAttributedString:attributedString]) {
		_navStepLabel.attributedText = attributedString;
		[self.view setNeedsLayout];
	}
}

- (void)buildTravelModeSegments {
	for (NSInteger index = 0; index < _countof(kTravelModes); index++) {
		UIImage *segmentImage = nil;
		NSString *travelMode = kTravelModes[index];
		if ([travelMode isEqualToString:@"walking"]) {
			segmentImage = [UIImage imageNamed:@"travel-mode-walk"];
		}
		else if ([travelMode isEqualToString:@"bicycling"]) {
			segmentImage = [UIImage imageNamed:@"travel-mode-bicycle"];
		}
		else if ([travelMode isEqualToString:@"driving"]) {
			segmentImage = [UIImage imageNamed:@"travel-mode-drive"];
		}
		else if ([travelMode isEqualToString:@"transit"]) {
			segmentImage = [UIImage imageNamed:@"travel-mode-transit"];
		}
		else {
			segmentImage = [UIImage imageNamed:@"travel-mode-unknown"];
		}
		[_navTravelModesCtrl insertSegmentWithImage:segmentImage atIndex:index animated:NO];
	}
}

- (void)didNavTravelMode {

	NSInteger travelMode = _navTravelModesCtrl.selectedSegmentIndex;
	if ((0 <= travelMode) && (travelMode <= _countof(kTravelModes)) && (_travelMode != travelMode)) {

		_travelMode = travelMode;
		[[NSUserDefaults standardUserDefaults] setObject:kTravelModes[travelMode] forKey:kTravelModeKey];

		_route = nil;
		_routeStatus = RouteStatus_Unknown;
		_navStatus = NavStatus_Unknown;
		_navStepIndex = _navInstrIndex = -1;
		_navAutoUpdate = false;
		[self clearMap];
		
		[self ensureRoute];
	}
}

- (void)didNavRefresh {
	_route = nil;
	_routeStatus = RouteStatus_Unknown;
	_navStatus = NavStatus_Unknown;
	_navStepIndex = _navInstrIndex = -1;
	_navAutoUpdate = false;
	[self clearMap];
	
	[self ensureRoute];
}

- (void)didNavAutoUpdate {
	if ((_route != nil) && (_navStatus == NavStatus_Progress) && !_navAutoUpdate) {
		_navAutoUpdate = true;
		[self updateNavByCurrentLocation];
	}
}

- (void)didNavPrev {
	if (_navStatus == NavStatus_Start) {
	}
	else if (_navStatus == NavStatus_Progress) {
		if (0 < _navStepIndex) {
			_navStepIndex -= 1;
		}
		else {
			_navStatus = NavStatus_Start;
			_navStepIndex = -1;
		}
	}
	else if (_navStatus == NavStatus_Finished) {
		_navStatus = NavStatus_Progress;
		_navStepIndex = _route.steps.count - 1;
	}
	
	[self turnOffAutoUpdateIfNeeded];
	[self initRoute];
	[self updateNav];
}

- (void)didNavNext {
	if (_navStatus == NavStatus_Start) {
		_navStatus = NavStatus_Progress;
		_navStepIndex = 0;
	}
	else if (_navStatus == NavStatus_Progress) {
		if ((_navStepIndex + 1) < _route.steps.count) {
			_navStepIndex++;
		}
		else {
			_navStatus = NavStatus_Finished;
			_navStepIndex = -1;
		}
	}
	else if (_navStatus == NavStatus_Finished) {
	}
	
	[self turnOffAutoUpdateIfNeeded];
	[self initRoute];
	[self updateNav];
}

#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager*)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	if (_requestingAuthorization) {
		_requestingAuthorization = false;
		[self buildInitialContent];
	}
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
	CLLocation* location = [locations lastObject];
	
	_currentLocation = location;
	_currentLocationError = nil;
	[self updateCurrentLocationMarker];

	if (_requestingCurrentLocation) {
		_requestingCurrentLocation = false;
		[self buildInitialContent];
	}
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	//_currentLocation = nil;
	_currentLocationError = error;
	
	if (_requestingCurrentLocation) {
		_requestingCurrentLocation = false;
		[self buildInitialContent];
	}
}

#pragma mark GMSMapViewDelegate

- (void)mapView:(GMSMapView *)mapView idleAtCameraPosition:(GMSCameraPosition *)position {
}

@end

NSString* travelModeString(NSInteger travelMode) {
	return ((0 <= travelMode) && (travelMode < _countof(kTravelModes))) ? kTravelModes[travelMode] : nil;
}

NSInteger travelModeIndex(NSString* value) {
	if (value != nil) {
		for (NSInteger index = 0; index < _countof(kTravelModes); index++) {
			NSString *travelMode = kTravelModes[index];
			if ([travelMode caseInsensitiveCompare:value] == NSOrderedSame) {
				return index;
			}
		}
	}
	return -1;
}
