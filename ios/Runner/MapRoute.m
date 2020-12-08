////  MapRoute.m
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

#import "MapRoute.h"
#import "NSArray+InaTypedValue.h"
#import "NSDictionary+InaTypedValue.h"

@implementation MapRoute
- (instancetype)initWithJson:(NSDictionary*)json {
	if (self = [super init]) {
		_bounds = [MapBounds createFromJson:[json inaDictForKey:@"bounds"]];
		_copyrights = [json inaStringForKey:@"copyrights"];
		_summary = [json inaStringForKey:@"summary"];
		_legs = [MapLeg createListFromJson:[json inaArrayForKey:@"legs"]];
	}
	return self;
}

+ (instancetype)createFromJson:(NSDictionary*)json {
	return (json != nil) ? [[self alloc] initWithJson:json] : nil;
}

+ (NSArray<MapRoute*>*)createListFromJson:(NSArray*)json {
	NSMutableArray<MapRoute*>* result = nil;
	if (json != nil) {
		result = [[NSMutableArray alloc] init];
		for (NSDictionary *jsonEntry in json) {
			if ([jsonEntry isKindOfClass:[NSDictionary class]]) {
				[result addObject:[[MapRoute alloc] initWithJson:jsonEntry]];
			}
		}
	}
	return result;
}

@end

@implementation MapLeg

- (instancetype)initWithJson:(NSDictionary*)json {
	if (self = [super init]) {
		_distance = [MapValue createFromJson:[json inaDictForKey:@"distance"]];
		_duration = [MapValue createFromJson:[json inaDictForKey:@"duration"]];

		_startAddress = [json inaStringForKey:@"start_address"];
		_startLocation = [MapLocation createFromJson:[json inaDictForKey:@"start_location"]];
		
		_endAddress = [json inaStringForKey:@"end_address"];
		_endLocation = [MapLocation createFromJson:[json inaDictForKey:@"end_location"]];

		_steps = [MapStep createListFromJson:[json inaArrayForKey:@"steps"]];

	}
	return self;
}

+ (instancetype)createFromJson:(NSDictionary*)json {
	return (json != nil) ? [[self alloc] initWithJson:json] : nil;
}

+ (NSArray<MapLeg*>*)createListFromJson:(NSArray*)json {
	NSMutableArray<MapLeg*>* result = nil;
	if (json != nil) {
		result = [[NSMutableArray alloc] init];
		for (NSDictionary *jsonEntry in json) {
			if ([jsonEntry isKindOfClass:[NSDictionary class]]) {
				[result addObject:[[MapLeg alloc] initWithJson:jsonEntry]];
			}
		}
	}
	return result;
}

@end

@implementation MapStep

- (instancetype)initWithJson:(NSDictionary*)json {
	if (self = [super init]) {
		_distance = [MapValue createFromJson:[json inaDictForKey:@"distance"]];
		_duration = [MapValue createFromJson:[json inaDictForKey:@"duration"]];

		_htmlInstructions = [json inaStringForKey:@"html_instructions"];
		_maneuver = [json inaStringForKey:@"maneuver"];
		_travelMode = [json inaStringForKey:@"travel_mode"];
		_polyline = [MapLocation createListFromEncodedPointsString:[[json inaDictForKey:@"polyline"] inaStringForKey:@"points"]];

		_startLocation = [MapLocation createFromJson:[json inaDictForKey:@"start_location"]];
		_endLocation = [MapLocation createFromJson:[json inaDictForKey:@"end_location"]];
	}
	return self;
}

+ (instancetype)createFromJson:(NSDictionary*)json {
	return (json != nil) ? [[self alloc] initWithJson:json] : nil;
}

+ (NSArray<MapStep*>*)createListFromJson:(NSArray*)json {
	NSMutableArray<MapStep*>* result = nil;
	if (json != nil) {
		result = [[NSMutableArray alloc] init];
		for (NSDictionary *jsonEntry in json) {
			if ([jsonEntry isKindOfClass:[NSDictionary class]]) {
				[result addObject:[[MapStep alloc] initWithJson:jsonEntry]];
			}
		}
	}
	return result;
}

@end

@implementation MapBounds

- (instancetype)initWithJson:(NSDictionary*)json {
	if (self = [super init]) {
		_northeast = [MapLocation createFromJson:[json inaDictForKey:@"northeast"]];
		_southwest = [MapLocation createFromJson:[json inaDictForKey:@"southwest"]];
	}
	return self;
}

+ (instancetype)createFromJson:(NSDictionary*)json {
	return (json != nil) ? [[self alloc] initWithJson:json] : nil;
}

@end

@implementation MapLocation

- (instancetype)initWithJson:(NSDictionary*)json {
	if (self = [super init]) {
		_latitude = [json inaDoubleForKey:@"lat"];
		_longitude = [json inaDoubleForKey:@"lng"];
	}
	return self;
}

- (instancetype)initWithLatitude:(CLLocationDegrees)lat longitude:(CLLocationDegrees)lng {
	if (self = [super init]) {
		_latitude = lat;
		_longitude = lng;
	}
	return self;
}

+ (instancetype)createFromJson:(NSDictionary*)json {
	return (json != nil) ? [[self alloc] initWithJson:json] : nil;
}

+ (NSArray<MapLocation*>*)createListFromEncodedPointsString:(NSString*)points {
	const char             *bytes  = [points UTF8String];
	NSUInteger              length = [points lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	NSUInteger              idx    = 0;
	int                     lat    = 0;
	int                     lng    = 0;
	int                     byte   = 0;
	int                     res    = 0;
	int                     shift  = 0;

	NSMutableArray<MapLocation*>* result = nil;
	
	while (idx < length) {
		res   = 1;
		shift = 0;
		do {
			byte   = bytes[idx++] - 63 - 1;
			res   += byte << shift;
			shift += 5;
		}
		while (byte >= 0x1f);
		
		lat += ((res & 1) ? ~(res >> 1) : (res >> 1));
		
		res   = 1;
		shift = 0;
		do {
			byte   = bytes[idx++] - 63 - 1;
			res   += byte << shift;
			shift += 5;
		}
		while (byte >= 0x1f);
		
		lng += ((res & 1) ? ~(res >> 1) : (res >> 1));
		
		if (result == nil) {
			result = [[NSMutableArray alloc] init];
		}
		MapLocation *location = [[MapLocation alloc] initWithLatitude:(lat * 1e-5) longitude:(lng * 1e-5)];
		[result addObject:location];
	}
	
	return result;
}

@end

@implementation MapValue

- (instancetype)initWithJson:(NSDictionary*)json {
	if (self = [super init]) {
		_text = [json inaStringForKey:@"text"];
		_value = [json inaIntegerForKey:@"value"];
	}
	return self;
}

+ (instancetype)createFromJson:(NSDictionary*)json {
	return (json != nil) ? [[self alloc] initWithJson:json] : nil;
}

@end
