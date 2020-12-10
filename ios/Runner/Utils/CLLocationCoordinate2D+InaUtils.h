//
//  CLLocationCoordinate2D+InaUtils.h
//  InaUtils
//
//  Created by Mihail Varbanov on 7/17/19.
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

#import <CoreLocation/CoreLocation.h>

bool CLLocationCoordinate2DInaEqual(CLLocationCoordinate2D coord1, CLLocationCoordinate2D coord2);

// Returns the distance between two LatLngs, in meters.
double CLLocationCoordinate2DInaDistance(CLLocationCoordinate2D from, CLLocationCoordinate2D to);

