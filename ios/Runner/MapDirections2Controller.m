////  MapDirections2Controller.m
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

#import "MapDirections2Controller.h"
#import "AppDelegate.h"
#import "MapRoute.h"

#import <GoogleMaps/GoogleMaps.h>
#import <CoreLocation/CoreLocation.h>

#import "UILabel+InaMeasure.h"
#import "NSDictionary+InaTypedValue.h"
#import "NSDictionary+UIUCConfig.h"

@interface MapDirections2Controller()<GMSMapViewDelegate, CLLocationManagerDelegate>

@property (nonatomic, strong) UIActivityIndicatorView* activityIndicator;
@property (nonatomic, strong) UILabel* activityStatus;
@property (nonatomic, strong) UILabel* contentStatus;

@property (nonatomic, strong) CLLocationManager* locationManager;
@property (nonatomic)         bool requestingAuthorization;

@property (nonatomic, strong) CLLocation* currentLocation;
@property (nonatomic, strong) NSError* currentLocationError;
@property (nonatomic)         bool requestingCurrentLocation;

@property (nonatomic, strong) CLLocation* targetLocation;

@property (nonatomic, strong) MapRoute* route;
@property (nonatomic, strong) NSError* routeError;
@property (nonatomic)         bool requestingRoute;

@end

@implementation MapDirections2Controller

- (instancetype)init {
	if (self = [super init]) {
		self.navigationItem.title = NSLocalizedString(@"Directions", nil);

		_locationManager = [[CLLocationManager alloc] init];
		_locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
		_locationManager.delegate = self;
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
    [self buildContent];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutSubViews];
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
}

- (void)buildContent {
	[self ensureTargetLocation] ||
	[self ensureLocationServices] ||
	[self ensureCurrentLocation] ||
	[self ensureRoute];
	
	if (_route != nil) {
		[self buildContentStatus:@"TBD: route"];
	}
	else if (_targetLocation != nil) {
		[self buildContentStatus:@"TBD: map"];
	}
}

- (bool)ensureTargetLocation {
	if (_targetLocation == nil) {
		NSDictionary *target = [_parameters inaDictForKey:@"target"];
		NSNumber *latitude = [target inaNumberForKey:@"latitude"];
		NSNumber *longitude = [target inaNumberForKey:@"longitude"];
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
			[_locationManager requestLocation];
		}
		return true;
	}
	return false;
}

- (bool)ensureRoute {
	if ((_route == nil) &&
	    (_routeError == nil) &&
	    (_targetLocation != nil) &&
	    (_currentLocation != nil)) {
	    
		if (!_requestingRoute) {
			_requestingRoute = true;
			[self buildActivityStatus:@"Building route"];
			__weak typeof(self) weakSelf = self;
			[self requestRouteWithCompletionHandler:^(MapRoute *route, NSError *error) {
				weakSelf.route = route;
				weakSelf.routeError = error;
				weakSelf.requestingRoute = false;
				[weakSelf buildContent];
			}];
		}
		return true;
	}
	return false;
}

- (void)requestRouteWithCompletionHandler:(void (^)(MapRoute* route, NSError* error))completionHandler {
	NSString *travelMode = @"driving";
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
			if (route == nil) {
				error = [NSError errorWithDomain:@"edu.illinois.covid" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"Unexpected route JSON response" }];
			}
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (completionHandler != nil) {
				completionHandler(route, error);
			}
		});
	}] resume];
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

#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager*)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	_requestingAuthorization = false;
	[self buildContent];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
	CLLocation* location = [locations lastObject];

	_currentLocation = location;
	_currentLocationError = nil;
	_requestingCurrentLocation = false;
	
	[self buildContent];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	_currentLocation = nil;
	_currentLocationError = error;
	_requestingCurrentLocation = false;
	
	[self buildContent];
}

@end
