//
//  MapController.m
//  Runner
//
//  Created by Mihail Varbanov on 7/11/19.
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

#import "MapController.h"
#import "AppDelegate.h"
#import "AppKeys.h"
#import "MapMarkerView.h"

#import "NSDictionary+UIUCConfig.h"
#import "NSDictionary+InaTypedValue.h"
#import "NSArray+InaTypedValue.h"
#import "NSString+InaJson.h"
#import "NSUserDefaults+InaUtils.h"
#import "UIColor+InaParse.h"
#import "CLLocationCoordinate2D+InaUtils.h"
#import "NSDictionary+UIUCExplore.h"
#import "InaSymbols.h"

#import <Foundation/Foundation.h>


@interface MapController() 

@end

/////////////////////////////////
// MapController

@implementation MapController

- (instancetype)init {
	if (self = [super init]) {
		self.navigationItem.title = NSLocalizedString(@"Maps", nil);

		_clLocationManager = [[CLLocationManager alloc] init];
		_clLocationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
		_clLocationManager.delegate = self;
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
	
	NSDictionary *target = [_parameters inaDictForKey:@"target"];
	CLLocationDegrees latitude = [target inaDoubleForKey:@"latitude"] ?: kInitialCameraLocation.latitude;
	CLLocationDegrees longitude = [target inaDoubleForKey:@"longitude"] ?: kInitialCameraLocation.longitude;
	float zoom = [target inaFloatForKey:@"zoom"] ?: kInitialCameraZoom;
	
	GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude longitude:longitude zoom:zoom];
	_gmsMapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
	_gmsMapView.delegate = self;
	//_gmsMapView.myLocationEnabled = YES;
	//_gmsMapView.settings.compassButton = YES;
	//_gmsMapView.settings.myLocationButton = YES;
	[self.view addSubview:_gmsMapView];
	
	NSDictionary *options = [_parameters inaDictForKey:@"options"];
	
	if ((options != nil) && [options inaBoolForKey:@"showDebugLocation"]) {
		_debugStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_debugStatusLabel.font = [UIFont boldSystemFontOfSize:12];
		_debugStatusLabel.textAlignment = NSTextAlignmentCenter;
		_debugStatusLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
		_debugStatusLabel.shadowColor = [UIColor colorWithWhite:1 alpha:0.5];
		_debugStatusLabel.shadowOffset = CGSizeMake(2, 2);
		[_gmsMapView addSubview:_debugStatusLabel];
	}

	NSArray *markers = [_parameters inaArrayForKey:@"markers"];
	for (NSDictionary *markerJson in markers) {
		if ([markerJson isKindOfClass:[NSDictionary class]]) {
			GMSMarker *marker = [[GMSMarker alloc] init];
			CLLocationDegrees markerLatitude = [markerJson inaDoubleForKey:@"latitude"];
			CLLocationDegrees markerLongitude = [markerJson inaDoubleForKey:@"longitude"];
			marker.position = CLLocationCoordinate2DMake(markerLatitude, markerLongitude);
			marker.title = [markerJson inaStringForKey:@"name"];
			marker.snippet = [markerJson inaStringForKey:@"description"];
			marker.map = _gmsMapView;
		}
	}
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutSubViews];
}

- (void)layoutSubViews {
	CGSize contentSize = self.view.frame.size;
	_gmsMapView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);

	if (_debugStatusLabel != nil) {
		CGFloat labelH = 12;
		_debugStatusLabel.frame = CGRectMake(0, contentSize.height - 1 - labelH, contentSize.width, labelH);
	}
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self startCoreLocation];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self stopCoreLocation];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}

#pragma mark Core Location

- (void)startCoreLocation {
	[_clLocationManager startUpdatingLocation];
}

- (void)stopCoreLocation {
	[_clLocationManager stopUpdatingLocation];
}

#pragma mark Location

- (void)notifyLocationUpdate {
	if (_debugStatusLabel != nil) {
	if (_debugStatusLabel != nil) {
		if (_clLocation != nil) {
			_debugStatusLabel.text = [NSString stringWithFormat:@"[%.6f, %.6f] @ %@", _clLocation.coordinate.latitude, _clLocation.coordinate.longitude, @(_clLocation.floor.level)];
			_debugStatusLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
		}
		else if (_clLocationError != nil) {
			_debugStatusLabel.text = _clLocationError.debugDescription;
			_debugStatusLabel.textColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:1.0];
		}
	}
	}
}

#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation* location = [locations lastObject];
	NSLog(@"CoreLocation: at location: [%.6f, %.6f]", location.coordinate.latitude, location.coordinate.longitude);

	_clLocation = location;
	_clLocationError = nil;
	
	[self notifyLocationUpdate];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	NSLog(@"CoreLocation: Failed to retrieve location: %@", error.localizedDescription);
	_clLocation = nil;
	_clLocationError = error;
	[self notifyLocationUpdate];
}

#pragma mark GMSMapViewDelegate

- (void)mapView:(GMSMapView *)mapView idleAtCameraPosition:(GMSCameraPosition *)position {
}

#pragma mark MPMapControlDelegate

- (void)floorDidChange:(NSNumber*)floor {
	NSLog(@"Maps Indoors: floorDidChange: %d", floor.intValue);
}

@end

