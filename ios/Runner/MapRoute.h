////  MapRoute.h
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

#import <Foundation/Foundation.h>
#import <CoreLocation/CLLocation.h>

@class MapRoute, MapLeg, MapStep, MapBounds, MapLocation, MapValue;

@interface MapRoute : NSObject
@property (nonatomic) MapBounds* bounds;
@property (nonatomic) NSString* copyrights;
@property (nonatomic) NSString* summary;
@property (nonatomic) NSArray<MapLeg*>* legs;

+ (instancetype)createFromJson:(NSDictionary*)json;
+ (NSArray<MapRoute*>*)createListFromJson:(NSArray*)json;
@end

@interface MapLeg : NSObject
@property (nonatomic) MapValue* distance;
@property (nonatomic) MapValue* duration;

@property (nonatomic) NSString* startAddress;
@property (nonatomic) MapLocation* startLocation;

@property (nonatomic) NSString* endAddress;
@property (nonatomic) MapLocation* endLocation;

@property (nonatomic) NSArray<MapStep*>* steps;

+ (instancetype)createFromJson:(NSDictionary*)json;
+ (NSArray<MapLeg*>*)createListFromJson:(NSArray*)json;
@end

@interface MapStep : NSObject
@property (nonatomic) MapValue* distance;
@property (nonatomic) MapValue* duration;

@property (nonatomic) NSString* htmlInstructions;
@property (nonatomic) NSString* maneuver;
@property (nonatomic) NSString* travelMode;
@property (nonatomic) NSArray<MapLocation*>* polyline;

@property (nonatomic) MapLocation* startLocation;
@property (nonatomic) MapLocation* endLocation;

+ (instancetype)createFromJson:(NSDictionary*)json;
+ (NSArray<MapStep*>*)createListFromJson:(NSArray*)json;
@end

@interface MapBounds : NSObject
@property (nonatomic) MapLocation* northeast;
@property (nonatomic) MapLocation* southwest;
+ (instancetype)createFromJson:(NSDictionary*)json;
@end

@interface MapLocation : NSObject
@property (nonatomic) CLLocationDegrees latitude;
@property (nonatomic) CLLocationDegrees longitude;
+ (instancetype)createFromJson:(NSDictionary*)json;
+ (NSArray<MapLocation*>*)createListFromEncodedPointsString:(NSString*)points;
@end

@interface MapValue : NSObject
@property (nonatomic) NSString* text;
@property (nonatomic) NSInteger value;
+ (instancetype)createFromJson:(NSDictionary*)json;
@end
