////  GalleryPlugin.m
//  Runner
//
//  Created by Mladen Dryankov on 11.08.20.
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

#import "GalleryPlugin.h"
#import <Photos/Photos.h>

#import "NSDictionary+InaTypedValue.h"


typedef void(^GalleryPluginCompletionHandler)(PHAssetCollection *assetCollection);

static NSString* const kGalleryPluginMethodChanelName     	= @"edu.illinois.covid/gallery";

static NSString* const kGalleryPluginMethodName  						= @"store";
static NSString* const kGalleryPluginParamBytes   					= @"bytes";
static NSString* const kGalleryPluginParamName    					= @"name";

@interface GalleryPlugin(){
	FlutterMethodChannel	*channel;
	FlutterResult         result;
	
	FlutterMethodCall			*storeCall;
	FlutterResult					storeCallResult;
}

@end

@implementation GalleryPlugin

static GalleryPlugin *g_Instance = nil;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
	FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:kGalleryPluginMethodChanelName binaryMessenger:registrar.messenger];
	GalleryPlugin *instance = [[GalleryPlugin alloc] initWithMethodChannel:channel];
	[registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
	if (self = [super init]) {
		if (g_Instance == nil) {
			g_Instance = self;
		}
	}
	return self;
}

- (void)dealloc {
	if (g_Instance == self) {
		g_Instance = nil;
	}
}

- (instancetype)initWithMethodChannel:(FlutterMethodChannel*)_channel {
	if (self = [self init]) {
		channel = _channel;
	}
	return self;
}

+ (instancetype)sharedInstance {
	return g_Instance;
}

- (void)requestAuthorizationIfNeed{
	
}

#pragma mark MethodCall

- (void)handleStoreMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result requested:(bool)requested {
	storeCall = call; storeCallResult = result;
	
	NSDictionary *params = [call.arguments isKindOfClass:[NSDictionary class]] ? call.arguments : nil;
	NSString *name = [params inaStringForKey: kGalleryPluginParamName];
	FlutterStandardTypedData *flutterData = [params inaObjectForKey:kGalleryPluginParamBytes class:FlutterStandardTypedData.class];
	NSData *data = flutterData.data;
	UIImage *image = data ? [UIImage imageWithData:data] : nil;
	
	if(name.length > 0 && image != nil){
		NSLog(@"GalleryPlugin: Invoke store image (name: %@, image:<....>)", name);
	
		if(PHPhotoLibrary.authorizationStatus != PHAuthorizationStatusAuthorized){
			if(PHPhotoLibrary.authorizationStatus == PHAuthorizationStatusNotDetermined){
				[PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
					[self handleStoreMethodCall:call result:result requested:true];
				}];
				return;
			}
			else{
				result([NSNumber numberWithBool:NO]);
			}
		}
		
		[self createAlbum:name completion:^(PHAssetCollection *assetCollection) {
			if(assetCollection != nil){
				[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
						[PHAssetChangeRequest creationRequestForAssetFromImage:image];
				} completionHandler:^(BOOL success, NSError *error) {
						if (success) {
								 result([NSNumber numberWithBool:YES]);
						}
						else {
								NSLog(@"GalleryPlugin: Error on save image: %@", error);
								result([NSNumber numberWithBool:NO]);
						}
				}];
			} else {
				result([NSNumber numberWithBool:NO]);
			}
		}];
	} else {
		NSLog(@"GalleryPlugin: Bad Data");
		result([NSNumber numberWithBool:NO]);
	}
}

- (PHAssetCollection*)fetchAssetCollectionForAlbum:(NSString*)albumName{
	PHFetchOptions *options = [PHFetchOptions new];
	options.predicate = [NSPredicate predicateWithFormat:@"title = %@", albumName];
	PHFetchResult<PHAssetCollection *> *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:options];
	return result.firstObject;
}

- (void)createAlbum:(NSString*)albumName completion:(GalleryPluginCompletionHandler)completion{
	PHAssetCollection *album = [self fetchAssetCollectionForAlbum:albumName];
	if(album != nil){
		completion(album);
	}
	
	[PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
		[PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle: albumName];
  }
  completionHandler:^(BOOL success, NSError * _Nullable error) {
		if(success){
				PHAssetCollection *album = [self fetchAssetCollectionForAlbum:albumName];
				completion(album);
		} else {
			NSLog(@"GalleryPlugin: Error on create album: %@", error);
			completion(nil);
		}
	}];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
	if([kGalleryPluginMethodName isEqualToString: call.method]){
		[self handleStoreMethodCall:call result:result requested:false];
	} else {
		result(nil);
	}
}

@end
