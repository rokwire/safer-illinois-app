//
//  ExposurePlugin.m
//  Runner
//
//  Created by Mihail Varbanov on 5/21/20.
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

#import "ExposurePlugin.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <HKDFKit/HKDFKit.h>

#import "Bluetooth+InaUtils.h"
#import "NSDictionary+InaTypedValue.h"
#import "CommonCrypto+UIUCUtils.h"
#import "Security+UIUCUtils.h"

static NSString* const kMethodChanelName        = @"edu.illinois.covid/exposure";
static NSString* const kServiceUuid             = @"CD19";
static NSString* const kCharacteristicUuid      = @"1f5bb1de-cdf0-4424-9d43-d8cc81a7f207";
static NSString* const kRangingBeaconUuid       = @"c965bc2c-5f28-4854-b046-7e68e0e60074";
static NSString* const kLocalNotificationId     = @"exposureNotification";
static NSString* const kExposureTEK1            = @"exposureTEKs";
static NSString* const kExposureTEK2            = @"exposureTEK2s";

static NSString* const kStartMethodName         = @"start";
static NSString* const kStopMethodName          = @"stop";
static NSString* const kTEKsMethodName          = @"TEKs";
static NSString* const kTekRPIsMethodName       = @"tekRPIs";
static NSString* const kExpireTEKMethodName     = @"expireTEK";
static NSString* const kRPILogMethodName        = @"exposureRPILog";
static NSString* const kRSSILogMethodName       = @"exposureRSSILog";
static NSString* const kSettingsParamName       = @"settings";
static NSString* const kTEKParamName            = @"tek";
static NSString* const kTimestampParamName      = @"timestamp";

static NSString* const kExpUpTimeMethodName     = @"exposureUpTime";
static NSString* const kUpTimeWinParamName      = @"upTimeWindow";

static NSString* const kTEKNotificationName     = @"tek";
static NSString* const kTEKTimestampParamName   = @"timestamp";
static NSString* const kTEKExpirestampParamName = @"expirestamp";
static NSString* const kTEKValueParamName       = @"tek";

static NSString* const kExposureNotificationName             = @"exposure";
static NSString* const kExposureThickNotificationName        = @"exposureThick";
static NSString* const kExposureTimestampParamName           = @"timestamp";
static NSString* const kExposureRPIParamName                 = @"rpi";
static NSString* const kExposureDurationParamName            = @"duration";
static NSString* const kExposureRSSIParamName                = @"rssi";

static NSInteger const kRPIRefreshInterval    = (10 * 60);     // 10 mins
static NSInteger const kTEKRollingPeriod      = (24 * 60 * 60) / kRPIRefreshInterval; // = 144 (kRPIRefreshInterval * kTEKRollingPeriod = 24 hours)

static NSTimeInterval const kExposureNotifyTickInterval      =   1;     // 1 sec

static int const kNoRssi = 127;

////////////////////////////////////
// ExposureRecord

@interface ExposureRecord : NSObject
@property (nonatomic, readonly) NSInteger      timestampCreated;
@property (nonatomic, readonly) NSTimeInterval timeUpdated;
@property (nonatomic, readonly) NSInteger      duration;
@property (nonatomic, readonly) NSTimeInterval durationInterval;
@property (nonatomic, readonly) int            rssi;

- (instancetype)initWithTimestamp:(NSTimeInterval)timestamp rssi:(int)rssi;
- (void)updateTimestamp:(NSTimeInterval)timestamp rssi:(int)rssi;
@end

////////////////////////////////////
// TEKRecord

@interface TEKRecord : NSObject
@property (nonatomic) NSData*   tek;
@property (nonatomic) int       expire;

- (instancetype)initWithTEK:(NSData*)tek expire:(int)expire;

+ (instancetype)fromJson:(NSDictionary*)json;
- (NSDictionary*)toJson;
@end

////////////////////////////////////
// ExposurePlugin

@interface ExposurePlugin() <CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate> {

	FlutterMethodChannel*                            _methodChannel;
	FlutterResult                                    _startResult;

	NSData*                                          _rpi;
	NSTimer*                                         _rpiTimer;
	NSMutableDictionary<NSNumber*, TEKRecord*>*      _teks;

	CBPeripheralManager*                             _peripheralManager;
	CBMutableService*                                _peripheralService;
	CBMutableCharacteristic*                         _peripheralCharacteristic;

	CBCentralManager*                                _centralManager;

	NSMutableDictionary<NSUUID*, CBPeripheral*>*     _peripherals;
	NSMutableDictionary<NSUUID*, NSData*>*           _peripheralRPIs;
	NSMutableDictionary<NSUUID*, ExposureRecord*>*   _iosExposures;
	NSMutableDictionary<NSData*, ExposureRecord*>*   _androidExposures;

	NSMutableDictionary<NSNumber*, NSNumber*>*       _exposureUpTime;
	NSTimeInterval                                   _exposureStartTime;
	
	NSTimer*                                         _scanTimer;
	NSTimeInterval                                   _lastNotifyExposireThickTime;
	
	CLLocationManager*                               _locationManager;
	CLBeaconRegion*                                  _beaconRegion;
	bool                                             _monitoringLocation;
	
	AVAudioPlayer*                                   _mutedAudioPlayer;

	NSTimeInterval                                   _exposureTimeoutInterval;
	NSTimeInterval                                   _exposurePingInterval;
	NSTimeInterval                                   _exposureScanWindowInterval;
	NSTimeInterval                                   _exposureScanWaitInterval;
	NSTimeInterval                                   _exposureMinDuration;
	
	int                                              _exposureMinRssi;
	int                                              _exposureExpireDays;
	int                                              _exposureUptimeExpireInterval;
}
@property (nonatomic, readonly) int                exposureMinRssi;
@property (nonatomic) UIBackgroundTaskIdentifier   bgTaskId;
@end

@implementation ExposurePlugin

static ExposurePlugin *g_Instance = nil;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
	FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:kMethodChanelName binaryMessenger:registrar.messenger];
	ExposurePlugin *instance = [[ExposurePlugin alloc] initWithMethodChannel:channel];
	[registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
	if (self = [super init]) {
		if (g_Instance == nil) {
			g_Instance = self;
		}
		_peripherals               = [[NSMutableDictionary alloc] init];
		_peripheralRPIs            = [[NSMutableDictionary alloc] init];
		_iosExposures              = [[NSMutableDictionary alloc] init];
		_androidExposures          = [[NSMutableDictionary alloc] init];
		_teks                      = [self.class loadTEK2sFromStorage];
		_bgTaskId                  = UIBackgroundTaskInvalid;
	}
	return self;
}

- (void)dealloc {
	if (g_Instance == self) {
		g_Instance = nil;
	}
}

- (instancetype)initWithMethodChannel:(FlutterMethodChannel*)channel {
	if (self = [self init]) {
		_methodChannel = channel;
	}
	return self;
}

+ (instancetype)sharedInstance {
	return g_Instance;
}

#pragma mark MethodCall

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
	NSDictionary *parameters = [call.arguments isKindOfClass:[NSDictionary class]] ? call.arguments : nil;
	if ([call.method isEqualToString:kStartMethodName]) {
		NSDictionary *settings = [parameters inaDictForKey:kSettingsParamName];
		[self startWithSettings:settings flutterResult:result];
	}
	else if ([call.method isEqualToString:kStopMethodName]) {
		[self stop];
		result([NSNumber numberWithBool:YES]);
	}
	else if ([call.method isEqualToString:kTEKsMethodName]) {
		bool remove = [parameters inaBoolForKey:@"remove"];
		if (remove) {
			[self.class saveTEK2sToStorage:nil];
			result(nil);
		}
		else {
			result(self.teksList);
		}
	}
	else if ([call.method isEqualToString:kTekRPIsMethodName]) {
		NSString *tekString = [parameters inaStringForKey:kTEKParamName];
		NSData *tek = [[NSData alloc] initWithBase64EncodedString:tekString options:0];
		NSInteger timestamp = [parameters inaIntegerForKey:kTimestampParamName];
		NSInteger expirestamp = [parameters inaIntegerForKey:kTEKExpirestampParamName];
		result([self rpisForTek:tek timestamp:timestamp expirestamp:expirestamp]);
	}
	else if ([call.method isEqualToString:kExpireTEKMethodName]) {
		[self updateTEKExpireTime];
		result(nil);
	}
	else if ([call.method isEqualToString:kExpUpTimeMethodName]) {
		NSInteger upTimeWindow = [parameters inaIntegerForKey:kUpTimeWinParamName];
		result([self exposureUptimeDurationInWindow:upTimeWindow]);
	}
	else {
		result(nil);
	}
}

#pragma mark API

- (void)startWithSettings:(NSDictionary*)settings flutterResult:(FlutterResult)result {

	if (self.isPeripheralAuthorized && self.isCentralAuthorized && (_peripheralManager == nil) && (_centralManager == nil) && (_startResult == nil)) {
		NSLog(@"ExposurePlugin: Start");
		_startResult = result;
		[self initSettings:settings];
		[self initRPI];
		[self startPeripheral];
		[self startCentral];
		[self startLocationManager];
		[self startAudioPlayer];
		[self connectAppLiveCycleEvents];
		[self startExposureUptime];
	}
	else if (result != nil) {
		result([NSNumber numberWithBool:YES]);
	}
}

- (void)checkStarted {
	if ((_startResult != nil) && self.isStarted) {
		FlutterResult flutterResult = _startResult;
		_startResult = nil;
		flutterResult([NSNumber numberWithBool:YES]);
	}
}

- (void)startFailed {
	if (_startResult != nil) {
		FlutterResult flutterResult = _startResult;
		_startResult = nil;
		flutterResult([NSNumber numberWithBool:NO]);
	}

}

- (bool)isStarted {
	return self.isPeripheralStarted && self.isCentralStarted;
}

- (void)stop {
	NSLog(@"ExposurePlugin: Stop");
	[self stopPeripheral];
	[self stopCentral];
	[self stopLocationManager];
	[self stopAudioPlayer];
	[self clearRPI];
	[self clearExposures];
	[self disconnectAppLiveCycleEvents];
	[self stopExposureUptime];
}

#pragma mark Peripheral

- (void)startPeripheral {
	if (self.isPeripheralAuthorized && (_peripheralManager == nil)) {
		_peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
	}
	else {
		[self startFailed];
	}
}

- (void)updatePeripheral {
	if (self.isPeripheralInitialized && (_rpi != nil) && _peripheralManager.isAdvertising) {
		[_peripheralManager updateValue:_rpi forCharacteristic:_peripheralCharacteristic onSubscribedCentrals:nil];
	}
}

- (void)stopPeripheral {

	if (_peripheralManager != nil) {
		if (_peripheralManager.isAdvertising) {
			[_peripheralManager stopAdvertising];
		}

		if (_peripheralService != nil) {
			[_peripheralManager removeService:_peripheralService];
			_peripheralService = nil;
		}

		_peripheralCharacteristic = nil;
	
		_peripheralManager.delegate = nil;
		_peripheralManager = nil;
	}
}

- (bool)isPeripheralAuthorized {
	return InaBluetooth.peripheralAuthorizationStatus == InaBluetoothAuthorizationStatusAuthorized;
}

- (bool)isPeripheralInitialized {
	return (_peripheralManager != nil) && (_peripheralManager.state == CBManagerStatePoweredOn) && (_peripheralService != nil) && (_peripheralCharacteristic != nil);
}

- (bool)isPeripheralStarted {
	return self.isPeripheralInitialized && _peripheralManager.isAdvertising;
}

#pragma mark CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
	NSLog(@"ExposurePlugin: CBPeripheralManager didUpdateState: %@", @(peripheral.state));

	if (_peripheralManager.state == CBManagerStatePoweredOn) {
		CBUUID *serviceUuid = [CBUUID UUIDWithString:kServiceUuid];
		CBMutableService *service = [[CBMutableService alloc] initWithType:serviceUuid primary:YES];

		CBUUID *characteristicUuid = [CBUUID UUIDWithString:kCharacteristicUuid];
		CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicUuid properties:CBCharacteristicPropertyRead | CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
		service.characteristics = @[characteristic];

		[_peripheralManager addService:service];
	}
	else {
		[self startFailed];
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
	NSLog(@"ExposurePlugin: CBPeripheralManager didAddService");
	_peripheralService = [service isKindOfClass:[CBMutableService class]] ? ((CBMutableService*)service) : nil;
	_peripheralCharacteristic = [_peripheralService inaMutableCharacteristicWithUUID:[CBUUID UUIDWithString:kCharacteristicUuid]];

	if (self.isPeripheralInitialized) {
		[_peripheralManager startAdvertising:
			@{ CBAdvertisementDataServiceUUIDsKey :@[[CBUUID UUIDWithString:kServiceUuid]],
		}];
	}
	else {
		[self startFailed];
	}
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
	NSLog(@"ExposurePlugin: CBPeripheralManager peripheralManagerDidStartAdvertising");
	if (self.isPeripheralStarted) {
		[self checkStarted];
	}
	else {
		[self startFailed];
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request{
	NSLog(@"ExposurePlugin: CBPeripheralManager didReceiveReadRequest");
	request.value = _rpi;
	[peripheral respondToRequest:request withResult:CBATTErrorSuccess];
}

#pragma mark Central

- (void)startCentral {
	if (self.isCentralAuthorized && (_centralManager == nil)) {
		_centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{
			CBCentralManagerOptionShowPowerAlertKey : [NSNumber numberWithBool:NO],
		}];
	}
	else {
		[self startFailed];
	}
}

- (void)stopCentral {
	if (_centralManager != nil) {
		if (_centralManager.isScanning) {
			[_centralManager stopScan];
			[self processExposures];
		}

		_centralManager.delegate = nil;
		_centralManager = nil;
	}
		
	if (_scanTimer != nil) {
		[_scanTimer invalidate];
		_scanTimer = nil;
	}
}

- (void)startScanning {
	if (_centralManager != nil) {
		NSLog(@"ExposurePlugin: CBCentralManager scanForPeripheralsWithServices");
		[_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUuid]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
		
		if (_scanTimer != nil) {
			[_scanTimer invalidate];
		}
		_scanTimer = [NSTimer scheduledTimerWithTimeInterval:_exposureScanWindowInterval target:self selector:@selector(suspendScannig) userInfo:nil repeats:NO];

		[self postLocalNotificationRequestIfNeeded];
	}
}

- (void)suspendScannig {
	if (_centralManager != nil) {
		NSLog(@"ExposurePlugin: CBCentralManager stopScan");
		if (_centralManager.isScanning) {
			[_centralManager stopScan];
		}
		
		if (_scanTimer != nil) {
			[_scanTimer invalidate];
		}
		_scanTimer = [NSTimer scheduledTimerWithTimeInterval:_exposureScanWaitInterval target:self selector:@selector(startScanning) userInfo:nil repeats:NO];

		[self processExposures];
	}
}

- (bool)isCentralAuthorized {
	return InaBluetooth.centralAuthorizationStatus == InaBluetoothAuthorizationStatusAuthorized;
}

- (bool)isCentralInitialized {
	return (_centralManager != nil) && (_centralManager.state == CBManagerStatePoweredOn);
}

- (bool)isCentralScanning {
	return (_centralManager.isScanning || (_scanTimer != nil));
}

- (bool)isCentralStarted {
	return self.isCentralInitialized && self.isCentralScanning;
}

- (void)disconnectPeripheralWithUuid:(NSUUID*)peripheralUuid {
	[self _disconnectPeripheral:[_peripherals objectForKey:peripheralUuid]];
	[self _removePeripheralWithUuid:peripheralUuid];
}

- (void)disconnectPeripheral:(CBPeripheral*)peripheral {
	[self _disconnectPeripheral:peripheral];
	[self _removePeripheralWithUuid:peripheral.identifier];
}

- (void)_disconnectPeripheral:(CBPeripheral*)peripheral {
	if (peripheral != nil) {
		peripheral.delegate = nil;

		CBService *service = [peripheral inaServiceWithUUID:[CBUUID UUIDWithString:kServiceUuid]];
		CBCharacteristic *characteristic = [service inaCharacteristicWithUUID:[CBUUID UUIDWithString:kCharacteristicUuid]];
		if (characteristic != nil) {
			[peripheral setNotifyValue:NO forCharacteristic:characteristic];
		}
		
		[_centralManager cancelPeripheralConnection:peripheral];
	}
}

- (void)_removePeripheralWithUuid:(NSUUID*)peripheralUuid {
	if (peripheralUuid != nil) {
		[_peripherals removeObjectForKey:peripheralUuid];

		NSData *rpi = [_peripheralRPIs objectForKey:peripheralUuid];
		if (rpi != nil) {
			[_peripheralRPIs removeObjectForKey:peripheralUuid];
		}
		
		ExposureRecord *record = [_iosExposures objectForKey:peripheralUuid];
		if (record != nil) {
			[_iosExposures removeObjectForKey:peripheralUuid];
		}
		
		if ((rpi != nil) && (record != nil)) {
			[self notifyExposure:record rpi:rpi peripheralUuid:peripheralUuid];
		}
	}
}

- (void)_removeAndroidRpi:(NSData*)rpi {
	NSUUID *peripheralUuid = [self peripheralUuidForRPI:rpi];
	[self disconnectPeripheralWithUuid:peripheralUuid];

	ExposureRecord *record = [_androidExposures objectForKey:rpi];
	if (record != nil) {
		[_androidExposures removeObjectForKey:rpi];
	}

	if ((rpi != nil) && (record != nil)) {
		[self notifyExposure:record rpi:rpi peripheralUuid:nil];
	}
}

- (NSUUID*)peripheralUuidForRPI:(NSData*)rpi {
	for (NSUUID* peripheralUuid in _peripheralRPIs) {
		NSData *peripheralRpi = [_peripheralRPIs objectForKey:peripheralUuid];
		if ([peripheralRpi isEqualToData:rpi]) {
			return peripheralUuid;
		}
	}
	return nil;
}

#pragma mark CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
	NSLog(@"ExposurePlugin: CBCentralManager didUpdateState: %@", @(central.state));
	if (self.isCentralInitialized) {
		[self startScanning];
		[self checkStarted];
	}
	else {
		[self startFailed];
	}
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {

	CBUUID *serviceUuid = [CBUUID UUIDWithString:kServiceUuid];
	if ([advertisementData inaAdvertisementDataContainsServiceWithUuid:serviceUuid]) {

		NSUUID *peripheralUuid = peripheral.identifier;
		if ([_peripherals objectForKey:peripheralUuid] == nil) {
			NSLog(@"ExposurePlugin: CBCentralManager didDiscoverPeripheral");
			[_peripherals setObject:peripheral forKey:peripheralUuid];
			[_centralManager connectPeripheral:peripheral options:nil];
		}

		NSDictionary<CBUUID*, NSData*> *serviceData = [advertisementData inaDictForKey:CBAdvertisementDataServiceDataKey];
		NSData *rpiData = (serviceData != nil) ? [serviceData objectForKey:serviceUuid] : nil;
		if (rpiData != nil) { // Android
			if ([_peripheralRPIs objectForKey:peripheralUuid] == nil) {	// new record
				NSLog(@"ExposurePlugin: New Android peripheral RPI received");
				[_peripheralRPIs setObject:rpiData forKey:peripheralUuid];
			}
			else if (![rpiData isEqualToData:[_peripheralRPIs objectForKey:peripheralUuid]]) { // update existing record
				NSLog(@"ExposurePlugin: Connected Android peripheral RPI changed");
				NSData * rpi = [_peripheralRPIs objectForKey:peripheralUuid];
				ExposureRecord * record = [_androidExposures objectForKey:rpi];
				if (record != nil) {
					[_androidExposures removeObjectForKey:rpi];
				}
				if (rpi != nil && record != nil) {
					[self notifyExposure:record rpi:rpi peripheralUuid:peripheralUuid];
				}
				[_peripheralRPIs setObject:rpiData forKey:peripheralUuid];
			}
			[self logAndroidExposure:rpiData rssi:RSSI.intValue];
		}
		else { // iOS
			[self logiOSExposure:peripheralUuid rssi:RSSI.intValue];
		}
	}
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(nonnull CBPeripheral *)peripheral {
	NSLog(@"ExposurePlugin: CBCentralManager didConnectPeripheral");
	peripheral.delegate = self;
	[peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUuid]]];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
	NSLog(@"ExposurePlugin: CBCentralManager didFailToConnectPeripheral");
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
	NSLog(@"ExposurePlugin: CBCentralManager didDisconnectPeripheral");
	[self disconnectPeripheral:peripheral];
}

#pragma mark CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
	NSLog(@"ExposurePlugin: CBPeripheral didDiscoverServices");
	if (error == nil) {
		CBService *service = [peripheral inaServiceWithUUID:[CBUUID UUIDWithString:kServiceUuid]];
		if (service != nil) {
			[peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:kCharacteristicUuid]] forService:service];
		}
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
	NSLog(@"ExposurePlugin: CBPeripheral didModifyServices");
	CBUUID *serviceUuid = [CBUUID UUIDWithString:kServiceUuid];
	for (CBService *service in invalidatedServices) {
		if ([service.UUID isEqual:serviceUuid]) {
			[peripheral discoverServices:@[serviceUuid]];
			break;
		}
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error {
	NSLog(@"ExposurePlugin: CBPeripheral didDiscoverCharacteristicsForService");
	if (error == nil) {
		CBCharacteristic *characteristic = [service inaCharacteristicWithUUID:[CBUUID UUIDWithString:kCharacteristicUuid]];
		if (characteristic != nil) {
			[peripheral setNotifyValue:YES forCharacteristic:characteristic];
			[peripheral readValueForCharacteristic:characteristic];
		}
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
	NSLog(@"ExposurePlugin: CBPeripheral didUpdateValueForCharacteristic");
	if ((error == nil) && [characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUuid]] && (characteristic.value != nil)) {
		NSUUID *peripheralUuid = peripheral.identifier;
		NSData *rpi = [_peripheralRPIs objectForKey:peripheralUuid];
		if (rpi == nil) {
			[_peripheralRPIs setObject:characteristic.value forKey:peripheralUuid];
		}
		else if (![rpi isEqualToData:characteristic.value]) {
			// update existing record
			[_peripheralRPIs setObject:characteristic.value forKey:peripheralUuid];

			NSLog(@"ExposurePlugin: Connected iOS peripheral RPI changed");
			ExposureRecord *record = [_iosExposures objectForKey:peripheralUuid];
			if (record != nil) {
				[_iosExposures removeObjectForKey:peripheralUuid];
			}
			if ((rpi != nil) && (record != nil)) {
				[self notifyExposure:record rpi:rpi peripheralUuid:peripheralUuid];
			}

			NSTimeInterval currentTimestamp = [[[NSDate alloc] init] timeIntervalSince1970];
			record = [[ExposureRecord alloc] initWithTimestamp:currentTimestamp rssi:record.rssi];
			[_iosExposures setObject:record forKey:peripheralUuid];
		}
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
	NSLog(@"ExposurePlugin: CBPeripheral didReadRSSI");
	if (error == nil) {
		[self logiOSExposure:peripheral.identifier rssi:RSSI.intValue];
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
}

#pragma mark Audio Player

- (void)startAudioPlayer {
	if (_mutedAudioPlayer == nil) {
	
		// Init audio session
		AVAudioSession *session = [AVAudioSession sharedInstance];
		[session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
		[session setActive:YES error:nil];

		// Init audio player
		NSError *error = nil;
//	NSString *audioPath = [[NSBundle mainBundle] pathForResource:@"audio" ofType:@"mp3"];
		NSString *audioPath = [[NSBundle mainBundle] pathForResource:@"silence" ofType:@"mp3"];
		NSURL *audioUrl = [NSURL fileURLWithPath:audioPath];
		_mutedAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioUrl error:&error];
		
		if ((_mutedAudioPlayer != nil) && (error == nil)) {
			_mutedAudioPlayer.numberOfLoops = -1;
			_mutedAudioPlayer.volume = 0.0f;
			[_mutedAudioPlayer play];
		}
		else {
			NSLog(@"ExposurePlugin Audio Player init error: %@", error.localizedDescription);
		}
	}
}

- (void)stopAudioPlayer {
	if (_mutedAudioPlayer != nil) {
		if (_mutedAudioPlayer.playing) {
			[_mutedAudioPlayer stop];
		}
		_mutedAudioPlayer = nil;
	}
}


#pragma mark Location Monitor

- (void)startLocationManager {
	if (_locationManager == nil) {
		_locationManager = [[CLLocationManager alloc] init];
		_locationManager.delegate = self;
		_locationManager.distanceFilter = 1000;
		_locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
		_locationManager.pausesLocationUpdatesAutomatically = NO;
		_locationManager.allowsBackgroundLocationUpdates = YES;
		[self startBeaconRanging];
		[self startLocationMonitor];
	}
}

- (void)stopLocationManager {
	if (_locationManager != nil) {
		[self stopBeaconRanging];
		[self stopLocationMonitor];
		_locationManager.delegate = nil;
		_locationManager = nil;
	}
}

#pragma mark Beacon Ranging

//
// http://www.davidgyoungtech.com/2020/05/07/hacking-the-overflow-area
//

- (void)startBeaconRanging {
	if ((_locationManager != nil) && (_beaconRegion == nil) && self.canBeaconRanging) {
		_beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:[[NSUUID alloc] initWithUUIDString:kRangingBeaconUuid] identifier:kRangingBeaconUuid];
		[_locationManager startRangingBeaconsInRegion:_beaconRegion];
	}
}

- (void)stopBeaconRanging {
	if ((_locationManager != nil) && (_beaconRegion != nil)) {
		[_locationManager stopRangingBeaconsInRegion:_beaconRegion];
		_beaconRegion = nil;
	}
}

- (bool)isBeaconRangingStarted {
	return (_locationManager != nil) && (_beaconRegion != nil);
}

- (void)updateBeaconRanging {
	if (self.canBeaconRanging && !self.isBeaconRangingStarted) {
		[self startBeaconRanging];
	}
	else if (!self.canBeaconRanging && self.isBeaconRangingStarted) {
		[self stopBeaconRanging];
	}
}

- (bool)canBeaconRanging {
	return self.canLocationMonitor &&
		[CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]];
}


#pragma mark Location & Heading Monitor

- (void)startLocationMonitor {
	if ((_locationManager != nil) && !_monitoringLocation && self.canLocationMonitor) {
//  [_locationManager startUpdatingLocation];
//  [_locationManager startUpdatingHeading];
    [_locationManager startMonitoringSignificantLocationChanges];
    _monitoringLocation = YES;
	}
}

- (void)stopLocationMonitor {
	if ((_locationManager != nil) && _monitoringLocation) {
//	[_locationManager stopUpdatingLocation];
//	[_locationManager stopUpdatingHeading];
		_monitoringLocation = NO;
	}
}

- (bool)isLocationMonitorStarted {
	return (_locationManager != nil) && _monitoringLocation;
}

- (void)updateLocationMonitor {
	if (self.canLocationMonitor && !self.isLocationMonitorStarted) {
		[self startLocationMonitor];
	}
	else if (!self.canLocationMonitor && self.isLocationMonitorStarted) {
		[self stopLocationMonitor];
	}
}

- (bool)canLocationMonitor {
	return
		[CLLocationManager locationServicesEnabled] &&
		(
			([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) ||
			([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse)
		);
}

#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager*)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	NSLog(@"ExposurePlugin didChangeAuthorizationStatus: %@", @(status));
	[self updateBeaconRanging];
	[self updateLocationMonitor];
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray<CLBeacon*>*)beacons inRegion:(CLBeaconRegion *)clBeaconRegion {
	//NSLog(@"ExposurePlugin didRangeBeacons:[<%@>] inRegion: %@", @(beacons.count), clBeaconRegion.identifier);
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)clBeaconRegion withError:(NSError *)error {
	//NSLog(@"ExposurePlugin rangingBeaconsDidFailForRegion: %@ withError: %@", clBeaconRegion.identifier, error.localizedDescription);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
//    UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
//    content.body = @"didUpdateLocations";
//    content.sound = nil;
//
//    UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:kLocalNotificationId content:content trigger:nil];
//    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError* error) {
//    }];
}

#pragma mark Local Notifications

- (void)postLocalNotificationRequestIfNeeded {
	if ((UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) &&
	   (UIScreen.mainScreen.brightness == 0))
	{
		NSLog(@"ExposurePlugin: Posting Exposure Local Notification");
		
		__weak typeof(self) weakSelf = self;
		[[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
			if (settings.authorizationStatus == 2 && settings.lockScreenSetting == 2) {
				[weakSelf exposureUptimeHeartBeat];
			}
		}];

		UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
		content.body = @"Exposure Notification system checking";
		content.sound = nil;
		
		UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:kLocalNotificationId content:content trigger:nil];
		[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError* error) {
			//UIScreen.mainScreen.brightness = 0.01;
		}];
	}

}

#pragma mark Exposure Uptime

- (void)startExposureUptime {
	_exposureStartTime = [[[NSDate alloc] init] timeIntervalSince1970];
	_exposureUpTime = [self loadExposureUptimeFromStorage];
}

- (void)stopExposureUptime {
	[self exposureUptimeHeartBeat];
	_exposureStartTime = 0.0;
	_exposureUpTime = nil;
}

- (void)exposureUptimeHeartBeat {
	if ((0.0 < _exposureStartTime) && (_exposureUpTime != nil)) {
		NSTimeInterval upTime = [[[NSDate alloc] init] timeIntervalSince1970] - _exposureStartTime;
		[_exposureUpTime setObject:[NSNumber numberWithInteger:upTime] forKey:[NSNumber numberWithInteger:_exposureStartTime]];
		[self saveExposureUptimeToStorage];
	}
}

- (NSString*)exposureUptimeFilePath {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	return [documentsDirectory stringByAppendingPathComponent:@"exposureUpTime.json"];
}

- (void)saveExposureUptimeToStorage {
	if (_exposureUpTime != nil) {
		NSMutableDictionary<NSString*, NSNumber*> *storageUpTime = [[NSMutableDictionary alloc] init];
		NSMutableArray<NSNumber*> *expiredTimeKeys = nil;

		NSInteger currentTimestamp = (NSInteger)[[[NSDate alloc] init] timeIntervalSince1970];
		NSInteger expireTimestamp = currentTimestamp - _exposureUptimeExpireInterval;

		for (NSNumber *timeNum in _exposureUpTime) {
			NSInteger time = [timeNum integerValue];
			NSString *timeStr = [timeNum stringValue];

			NSNumber *durationNum = [_exposureUpTime inaNumberForKey:timeNum];
			NSInteger duration = [durationNum integerValue];

			if ((time + duration) < expireTimestamp) {
				if (expiredTimeKeys == nil) {
					expiredTimeKeys = [[NSMutableArray alloc] init];
				}
				[expiredTimeKeys addObject:timeNum];
			}
			else if ((timeStr != nil) && (durationNum != nil)) {
				[storageUpTime setObject:durationNum forKey:timeStr];
			}
		}

		if (expiredTimeKeys != nil) {
			for (NSNumber *timeKey in expiredTimeKeys) {
				[_exposureUpTime removeObjectForKey:timeKey];
			}
		}

		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:storageUpTime options:0 error:NULL];
		[jsonData writeToFile:self.exposureUptimeFilePath atomically:YES];
	}
}

- (NSMutableDictionary<NSNumber*, NSNumber*>*)loadExposureUptimeFromStorage {
	NSMutableDictionary<NSNumber*, NSNumber*> *upTimes = [[NSMutableDictionary alloc] init];

	NSInteger currentTimestamp = (NSInteger)[[[NSDate alloc] init] timeIntervalSince1970];
	NSInteger expireTimestamp = currentTimestamp - _exposureUptimeExpireInterval;

	NSData *jsonData = [NSData dataWithContentsOfFile:self.exposureUptimeFilePath options:0 error:NULL];
	NSDictionary* storedDictionary = (jsonData != nil) ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL] : nil;
	if ([storedDictionary isKindOfClass:[NSDictionary class]]) {
		for (NSString *timeStr in storedDictionary) {
			NSInteger time = [timeStr integerValue];
			NSNumber *durationNum = [storedDictionary inaNumberForKey:timeStr];
			NSInteger duration = [durationNum integerValue];
			if ((time + duration) > expireTimestamp) {
				[upTimes setObject:durationNum forKey:[NSNumber numberWithInteger:time]];
			}
		}
	}

	return upTimes;
}

- (NSNumber*)exposureUptimeDurationInWindow:(NSInteger)timeWindow {
	NSInteger durationInWindow = 0;
	if (_exposureUpTime != nil) {
		NSTimeInterval currentTime = [[[NSDate alloc] init] timeIntervalSince1970];
		NSTimeInterval timeWindowInSeconds = timeWindow * 60 * 60;
		NSInteger startTimestamp = (NSInteger)(currentTime - timeWindowInSeconds);

		for (NSNumber *timeNum in _exposureUpTime) {
			NSInteger time = [timeNum integerValue];
			NSInteger duration = [_exposureUpTime inaIntegerForKey:timeNum];
			if ((time + duration) >= startTimestamp) {
				if (time >= startTimestamp) {
					durationInWindow += duration;
				} else {
					durationInWindow += (duration + time - startTimestamp);
				}
			}
		}
	}
	return [NSNumber numberWithInteger:durationInWindow];
}

#pragma mark App Livecycle Events

- (void)connectAppLiveCycleEvents {
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(audioSessionInterruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
}

- (void)disconnectAppLiveCycleEvents {
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
	[notificationCenter removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
	[notificationCenter removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
	[notificationCenter removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
	[notificationCenter removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
	[notificationCenter removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
}

- (void)applicationDidEnterBackground {
	if (_bgTaskId == UIBackgroundTaskInvalid) {
		__weak typeof(self) weakSelf = self;
		_bgTaskId = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{
			weakSelf.bgTaskId = UIBackgroundTaskInvalid;
		}];
	}
}

- (void)applicationWillEnterForeground {
	if (_bgTaskId != UIBackgroundTaskInvalid) {
		[UIApplication.sharedApplication endBackgroundTask:_bgTaskId];
		_bgTaskId = UIBackgroundTaskInvalid;
	}
}

- (void)applicationWillResignActive {
	[UIApplication.sharedApplication beginReceivingRemoteControlEvents];
	if ((_locationManager != nil) && self.canLocationMonitor && _monitoringLocation) {
//  [_locationManager startUpdatingLocation];
//  [_locationManager startUpdatingHeading];
    [_locationManager startMonitoringSignificantLocationChanges];
	}
}

- (void)applicationDidBecomeActive {
	[UIApplication.sharedApplication endReceivingRemoteControlEvents];
}

- (void)applicationWillTerminate {
    if (0.0 < _exposureStartTime) {
        [self stopExposureUptime];
    }
}

- (void)audioSessionInterruptionNotification:(NSNotification *)notification {
	if (_mutedAudioPlayer != nil) {
		int interruptionType = [notification.userInfo inaIntForKey:AVAudioSessionInterruptionTypeKey];
		int interruptionOption = [notification.userInfo inaIntForKey:AVAudioSessionInterruptionOptionKey];
		if ((interruptionType == AVAudioSessionInterruptionTypeBegan) && _mutedAudioPlayer.playing) {
			[_mutedAudioPlayer pause];
		}
		else if ((interruptionType == AVAudioSessionInterruptionTypeEnded) && (interruptionOption == AVAudioSessionInterruptionOptionShouldResume) && !_mutedAudioPlayer.playing) {
			[_mutedAudioPlayer play];
		}
	}
}

#pragma mark Settings

- (void)initSettings:(NSDictionary*)settings {
	_exposureTimeoutInterval      = (settings != nil) ? [settings inaDoubleForKey:@"covid19ExposureServiceTimeoutInterval"      defaults:    300] :    300; // 5 minutes
	_exposurePingInterval         = (settings != nil) ? [settings inaDoubleForKey:@"covid19ExposureServicePingInterval"         defaults:     60] :     60; // 1 minute
	_exposureScanWindowInterval   = (settings != nil) ? [settings inaDoubleForKey:@"covid19ExposureServiceScanWindowInterval"   defaults:      4] :      4; // 4 seconds of scanning
	_exposureScanWaitInterval     = (settings != nil) ? [settings inaDoubleForKey:@"covid19ExposureServiceScanWaitInterval"     defaults:    150] :    150; // 2.5 minutes of latent period
	_exposureMinDuration          = (settings != nil) ? [settings inaDoubleForKey:@"covid19ExposureServiceLogMinDuration"       defaults:      0] :      0; // 0 seconds
	_exposureExpireDays           = (settings != nil) ? [settings inaIntForKey:   @"covid19ExposureExpireDays"                  defaults:     14] :     14; // 14 days
	_exposureMinRssi              = (settings != nil) ? [settings inaIntForKey:   @"covid19ExposureServiceMinRSSI"              defaults:    -90] :    -90;
	_exposureUptimeExpireInterval = (settings != nil) ? [settings inaIntForKey:   @"covid19ExposureServiceUptimeExpireInterval" defaults: 604800] : 604800; // 7 days (168 * 60 * 60)
}

#pragma mark RPI

- (void)initRPI {
	_rpi = [self generateRPI];

	if (_rpiTimer == nil) {
		_rpiTimer = [NSTimer scheduledTimerWithTimeInterval:kRPIRefreshInterval target:self selector:@selector(refreshRPI) userInfo:nil repeats:YES];
	}
}

- (void)refreshRPI {
	_rpi = [self generateRPI];

	[self updatePeripheral];
}

- (void)clearRPI {
	if (_rpi != nil) {
		_rpi = nil;
	}
	if (_rpiTimer != nil) {
		[_rpiTimer invalidate];
		_rpiTimer = nil;
	}
}

- (NSData*)generateRPI {
	NSTimeInterval currentTimestamp = [[[NSDate alloc] init] timeIntervalSince1970];
	
	/* obtain ENInvertalNumber and timestamp i for teks generation */
	uint32_t ENInvertalNumber = currentTimestamp / kRPIRefreshInterval;
	
	/* _i : time aligned with TEKRollingPeriod */
	uint32_t _i = (ENInvertalNumber / kTEKRollingPeriod) * kTEKRollingPeriod;
	uint32_t _iExpire = _i + kTEKRollingPeriod;

	/* if new day, generate a new tek */
	/* if in the rest of the day, using last valid TEK */
	if (_teks != nil) {
		NSNumber *iMax = [self maxTEKsI];
		if (iMax != nil) {
			TEKRecord *maxRecord = [_teks objectForKey:iMax];
			if (maxRecord.expire == (_iExpire)) {
				_i = [iMax intValue];
			} else
			{
				_i = ENInvertalNumber;
			}
		}
	}

	//NSLog(@"ExposurePlugin: ENIntervalNumber: %d, i: %d", ENInvertalNumber, _i);
	
	/* generate tek each day, and store 14 of them in a database with timestamp i */
	TEKRecord* tekRecord = [_teks objectForKey:[NSNumber numberWithInt: _i]];
	if (tekRecord == nil) {
		UInt8 bytes[16];
		int status = SecRandomCopyBytes(kSecRandomDefault, (sizeof bytes)/(sizeof bytes[0]), &bytes);
		NSData *tek = (status == errSecSuccess) ? [NSData dataWithBytes:bytes length:sizeof(bytes)] : nil;
		if (tek != nil) {
			tekRecord = [[TEKRecord alloc] initWithTEK:tek expire:_iExpire];
			[_teks setObject:tekRecord forKey:[NSNumber numberWithInt: _i]];

			if (_teks.count > (_exposureExpireDays + 1)) { // [0 - 14] gives 15 entries alltogether
				uint32_t thresholdI = _i - _exposureExpireDays * kTEKRollingPeriod;
				for (NSNumber *tekI in _teks.allKeys) {
					if ([tekI intValue] < thresholdI) {
						[_teks removeObjectForKey:tekI];
					}
				}
			}
			
			[self.class saveTEK2sToStorage:_teks];

			NSInteger timestamp = ((NSInteger)_i) * kRPIRefreshInterval * 1000; // in miliseconds
			NSInteger expirestamp = ((NSInteger)_iExpire) * kRPIRefreshInterval * 1000; // in miliseconds
			[self notifyTEK:tek timestamp:timestamp expirestamp:expirestamp];
		}
		else {
			//NSLog(@"ExposurePlugin: Failed to generate new tek for i: %d", _i);
		}
	}
	//NSLog(@"ExposurePlugin: Obtain tek {%@}", tek);
	
	NSData* rpi = [self generateRPIForIntervalNumber:ENInvertalNumber tek:tekRecord.tek];
	[self notifyRPI:rpi tek:tekRecord.tek updateType:(_rpi != nil) ? @"update" : @"init" timestamp:(currentTimestamp * 1000.0) _i:_i ENInvertalNumber:ENInvertalNumber];
	return rpi;
}

- (NSData*)generateRPIForIntervalNumber:(uint32_t)ENInvertalNumber tek:(NSData*)tek {
	//NSLog(@"ExposurePlugin: Refresh TEK");
	
	/* generate rpik and aemk based on tek */
	NSData* rpik = [HKDFKit deriveKey:tek info:[@"EN-RPIK" dataUsingEncoding:NSUTF8StringEncoding] salt:nil outputSize:16];
	//NSLog(@"ExposurePlugin: Obtain rpik {%@}", rpik);
	
	NSData* aemk = [HKDFKit deriveKey:tek info:[@"EN-AEMK" dataUsingEncoding:NSUTF8StringEncoding] salt:nil outputSize:16];
	//NSLog(@"ExposurePlugin: Obtain aemk {%@}", aemk);
	
	/* generate paddedData for rpi message */
	NSData* paddedData_0_5 = [@"EN-RPI" dataUsingEncoding:NSUTF8StringEncoding];
	
	const char char_pd_6_11[6] = "\x00\x00\x00\x00\x00\x00";
	NSData *paddedData_6_11 = [NSData dataWithBytes:char_pd_6_11 length:6];
	
	uint32_t reverseENIntervalNumber = 0;
	reverseENIntervalNumber = CFSwapInt32HostToBig(ENInvertalNumber);
	NSData *paddedData_12_15 = [NSData dataWithBytes: &reverseENIntervalNumber length: 4];
	
	NSMutableData* paddedData = [NSMutableData data];
	[paddedData appendData:paddedData_0_5];
	[paddedData appendData:paddedData_6_11];
	[paddedData appendData:paddedData_12_15];
	//NSLog(@"ExposurePlugin: PaddedData {%@}", paddedData);
	
	/* generate encrypted en_rpi with AES-128 */
	NSError *error = nil;
	NSData* en_rpi = uiuc_aes_operation(paddedData, kCCEncrypt, kCCModeECB, kCCAlgorithmAES, ccNoPadding, kCCKeySizeAES128, nil, rpik, &error);
	//NSLog(@"ExposurePlugin: RPI_en {%@}", en_rpi);
	
	/* generate metadata for aem message */
	NSData *metadata = [NSData dataWithBytes:(char[]){0x00,0x00,0x00,0x00} length:4];
	//NSLog(@"ExposurePlugin: metadata {%@}", metadata);
	
	 /* generate encrypted en_aem with AES-128-CTR */
	NSData* en_aem = uiuc_aes_operation(metadata, kCCEncrypt, kCCModeCTR, kCCAlgorithmAES, ccNoPadding, kCCKeySizeAES128, en_rpi, aemk, &error);
	//NSLog(@"ExposurePlugin: AEM_en {%@}", en_aem);
	
	/* contaticate en_rpi and en_aem to form the payload */
	NSMutableData* ble_load = [NSMutableData data];
	[ble_load appendData:en_rpi];
	[ble_load appendData:en_aem];
	//NSLog(@"ExposurePlugin: BLE_Payload {%@}", ble_load);
	return ble_load;
}

- (NSNumber*)maxTEKsI {
	NSNumber *result = nil;
	if (_teks != nil) {
		for (NSNumber *i in _teks) {
			if ((result == nil) || ([result intValue] < [i intValue])) {
				result = i;
			}
		}
	}
	return result;
}

- (NSArray*)teksList {
	NSMutableArray *teksList = [[NSMutableArray alloc] init];
	for (NSNumber *tekKey in _teks) {
		NSInteger _i = [tekKey intValue];
		TEKRecord *tekRecord = [_teks objectForKey:tekKey];
		NSInteger timestamp = ((NSInteger)_i) * kRPIRefreshInterval * 1000; // in miliseconds
		NSInteger expirestamp = ((NSInteger)tekRecord.expire) * kRPIRefreshInterval * 1000; // in miliseconds
		NSString *tekString = [tekRecord.tek base64EncodedStringWithOptions:0];
		[teksList addObject:@{
			kTEKTimestampParamName : [NSNumber numberWithInteger:timestamp],
			kTEKExpirestampParamName : [NSNumber numberWithInteger:expirestamp],
			kTEKValueParamName: tekString ?: [NSNull null],
		}];
	}
	return teksList;
}

- (NSDictionary*)rpisForTek:(NSData*)tek timestamp:(NSInteger)timestamp expirestamp:(NSInteger)expirestamp {
	NSTimeInterval timestampInterval = (timestamp / 1000.0);
	NSTimeInterval expirestampInterval = (expirestamp / 1000.0);
	
	/* obtain start/endENInvertalNumber and timestamp i for teks generation */
	uint32_t startENInvertalNumber = timestampInterval / kRPIRefreshInterval;
	uint32_t endENInvertalNumber = expirestampInterval / kRPIRefreshInterval;

	/* handle TEKs without expirestamp (0 or -1), default to 1 day later */
	if (endENInvertalNumber < startENInvertalNumber || endENInvertalNumber > startENInvertalNumber + kTEKRollingPeriod)
		endENInvertalNumber = startENInvertalNumber + kTEKRollingPeriod;
	
	NSMutableDictionary *rpis = [[NSMutableDictionary alloc] init];
	for (uint32_t intervalIndex = startENInvertalNumber; intervalIndex <= endENInvertalNumber; intervalIndex++) {
		NSData *rpi = [self generateRPIForIntervalNumber:intervalIndex tek:tek];
		NSString *rpiString = [rpi base64EncodedStringWithOptions:0];
		NSInteger interval = (((NSInteger)intervalIndex) * kRPIRefreshInterval * 1000);
		[rpis setObject:[NSNumber numberWithInteger:interval] forKey:rpiString];
	}
	return rpis;
}

- (void)updateTEKExpireTime {
	if (_teks != nil) {
		NSNumber * current_i = [self maxTEKsI];
		TEKRecord* tekRecord = [_teks objectForKey:current_i];
		NSTimeInterval currentTimestamp = [[[NSDate alloc] init] timeIntervalSince1970];
		tekRecord.expire = currentTimestamp / kRPIRefreshInterval;
		[self.class saveTEK2sToStorage:_teks];
	}
}

+ (void)saveTEK1sToStorage:(NSDictionary<NSNumber*, NSData*>*)teks {
	if (teks != nil) {
		NSMutableDictionary<NSString*, NSString*> *storageTeks = [[NSMutableDictionary alloc] init];
		for (NSNumber *_i in teks) {
			NSData *value = [teks objectForKey:_i];
			NSString *storageKey = [_i stringValue];
			NSString *storageValue = [value base64EncodedStringWithOptions:0];
			if ((storageKey != nil) && (storageValue != nil)) {
				[storageTeks setObject:storageValue forKey:storageKey];
			}
		}
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:storageTeks options:0 error:NULL];
		uiucSecStorageData(kExposureTEK1, kExposureTEK1, jsonData);
	}
	else {
		uiucSecStorageData(kExposureTEK1, kExposureTEK1, [NSNull null]);
	}
}

+ (NSMutableDictionary<NSNumber*, NSData*>*)loadTEK1sFromStorage {
	NSMutableDictionary<NSNumber*, NSData*>* teks = [[NSMutableDictionary alloc] init];
	NSData *jsonData = uiucSecStorageData(kExposureTEK1, kExposureTEK1, nil);
	if (jsonData != nil) {
		NSDictionary *storageTeks = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
		if ([storageTeks isKindOfClass:[NSDictionary class]]) {
			for (NSString *storageKey in storageTeks) {
				NSString *storageValue = [storageTeks inaStringForKey:storageKey];
				NSData *value = [[NSData alloc] initWithBase64EncodedString:storageValue options:0];
				if (value != nil) {
					[teks setObject:value forKey:[NSNumber numberWithInt:[storageKey intValue]]];
				}
			}
		}
	}
	return teks;
}

+ (void)saveTEK2sToStorage:(NSDictionary<NSNumber*, TEKRecord*>*)teks {
	if (teks != nil) {
		NSMutableDictionary<NSString*, NSDictionary*> *storageTeks = [[NSMutableDictionary alloc] init];
		for (NSNumber *_i in teks) {
			TEKRecord	*record = [teks objectForKey:_i];
			NSString *storageKey = [_i stringValue];
			NSDictionary *storageValue = record.toJson;
			if ((storageKey != nil) && (storageValue != nil)) {
				[storageTeks setObject:storageValue forKey:storageKey];
			}
		}
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:storageTeks options:0 error:NULL];
		uiucSecStorageData(kExposureTEK2, kExposureTEK2, jsonData);
	}
	else {
		uiucSecStorageData(kExposureTEK2, kExposureTEK2, [NSNull null]);
	}
}

+ (NSMutableDictionary<NSNumber*, TEKRecord*>*)loadTEK2sFromStorage {
	NSMutableDictionary<NSNumber*, TEKRecord*>* teks = [[NSMutableDictionary alloc] init];
	NSData *jsonData = uiucSecStorageData(kExposureTEK2, kExposureTEK2, nil);
	if (jsonData != nil) {
		NSDictionary *storageTeks = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
		if ([storageTeks isKindOfClass:[NSDictionary class]]) {
			for (NSString *storageKey in storageTeks) {
				NSDictionary *storageValue = [storageTeks inaDictForKey:storageKey];
				TEKRecord *record = [TEKRecord fromJson:storageValue];
				if (record != nil) {
					[teks setObject:record forKey:[NSNumber numberWithInt:[storageKey intValue]]];
				}
			}
		}
	}
	else {
		NSDictionary<NSNumber*, NSData*>* teks1 = [self loadTEK1sFromStorage];
		if (teks1 != nil) {
			for (NSNumber *i in teks1) {
				NSData *tek = [teks1 inaDataForKey:i];
				int expire = [i intValue] + kTEKRollingPeriod;
				[teks setObject:[[TEKRecord alloc] initWithTEK:tek expire:expire] forKey:i];
			}
		}
	}
	return teks;
}

#pragma mark Exposure

- (void)logiOSExposure:(NSUUID*)peripheralUuid rssi:(int)rssi {
	NSLog(@"ExposurePlugin: {%@} / rssi: %@", peripheralUuid, @(rssi));

	NSTimeInterval currentTimestamp = [[[NSDate alloc] init] timeIntervalSince1970];
	ExposureRecord *record = [_iosExposures objectForKey:peripheralUuid];
	if (record == nil) {
		// Create new
		NSLog(@"ExposurePlugin: {%@} registred", peripheralUuid);
		record = [[ExposureRecord alloc] initWithTimestamp:currentTimestamp rssi:rssi];
		[_iosExposures setObject:record forKey:peripheralUuid];
	}
	else {
		// Update existing
		[record updateTimestamp:currentTimestamp rssi:rssi];
	}

	NSData *rpi = [_peripheralRPIs objectForKey:peripheralUuid];
	[self notifyExposureTick:rpi rssi:rssi peripheralUuid:peripheralUuid];
	[self notifyRSSI:rssi rpi:rpi timestamp:(currentTimestamp * 1000.0) peripheralUuid:peripheralUuid];
}

- (void)logAndroidExposure:(NSData*)rpi rssi:(int)rssi {
	NSLog(@"ExposurePlugin: {%@} / rssi: %@", rpi, @(rssi));

	NSTimeInterval currentTimestamp = [[[NSDate alloc] init] timeIntervalSince1970];
	ExposureRecord *record = [_androidExposures objectForKey:rpi];
	if (record == nil) {
		// Create new
		NSLog(@"ExposurePlugin: {%@} registred", rpi);
		record = [[ExposureRecord alloc] initWithTimestamp:currentTimestamp rssi:rssi];
		[_androidExposures setObject:record forKey:rpi];
	}
	else {
		// Update existing
		[record updateTimestamp:currentTimestamp rssi:rssi];
	}

	[self notifyExposureTick:rpi rssi:rssi peripheralUuid:nil];
	[self notifyRSSI:rssi rpi:rpi timestamp:(currentTimestamp * 1000.0) peripheralUuid:nil];
}

- (void)processExposures {

	NSLog(@"ExposurePlugin: Processing exposures");
	NSTimeInterval currentTimestamp = [[[NSDate alloc] init] timeIntervalSince1970];

	// collect all iOS expired records (not updated after _exposureTimeoutInterval)
	NSMutableSet<NSUUID*> *expiredPeripheralUuid = nil;
	for (NSUUID *peripheralUuid in _iosExposures) {
		ExposureRecord *record = [_iosExposures objectForKey:peripheralUuid];
		NSTimeInterval lastHeardInterval = currentTimestamp - record.timeUpdated;

		if (_exposureTimeoutInterval <= lastHeardInterval) {
			NSLog(@"ExposurePlugin: {%@} expired", peripheralUuid);
			if (expiredPeripheralUuid == nil) {
				expiredPeripheralUuid = [[NSMutableSet alloc] init];
			}
			[expiredPeripheralUuid addObject:peripheralUuid];
		}
//	ping disabled
//	else if (_exposurePingInterval <= lastHeardInterval) {
//		NSLog(@"ExposurePlugin: {%@} ping", peripheralUuid);
//		CBPeripheral *peripheral = [_peripherals objectForKey:peripheralUuid];
//		[peripheral readRSSI];
//	}
	}
	
	if (expiredPeripheralUuid != nil) {
		// remove expired records from _iosExposures
		for (NSUUID *peripheralUuid in expiredPeripheralUuid) {
			[self disconnectPeripheralWithUuid:peripheralUuid];
		}
	}
	
	// collect all Android expired records (not updated after _exposureTimeoutInterval)
	NSMutableSet<NSData*> *expiredRPIs = nil;
	for (NSData *rpi in _androidExposures) {
		ExposureRecord *record = [_androidExposures objectForKey:rpi];
		NSTimeInterval lastHeardInterval = currentTimestamp - record.timeUpdated;

		if (_exposureTimeoutInterval <= lastHeardInterval) {
			NSLog(@"ExposurePlugin: {%@} expired", rpi);
			if (expiredRPIs == nil) {
				expiredRPIs = [[NSMutableSet alloc] init];
			}
			[expiredRPIs addObject:rpi];
		}
		else if (_exposurePingInterval <= lastHeardInterval) {
			NSLog(@"ExposurePlugin: {%@} ping", rpi);
			NSUUID *peripheralUuid = [self peripheralUuidForRPI:rpi];
			CBPeripheral *peripheral = [_peripherals objectForKey:peripheralUuid];
			[peripheral readRSSI];
		}
	}

	if (expiredRPIs != nil) {
		// remove expired records from _androidExposures
		for (NSData *rpi in expiredRPIs) {
			[self _removeAndroidRpi:rpi];
		}
	}
}

- (void)clearExposures {
	for (NSUUID *peripheralUuid in _iosExposures.allKeys) {
		[self disconnectPeripheralWithUuid:peripheralUuid];
	}
	for (NSData *rpi in _androidExposures.allKeys) {
		[self _removeAndroidRpi:rpi];
	}
}

#pragma mark Notifications

- (void)notifyExposure:(ExposureRecord*)record rpi:(NSData*)rpi peripheralUuid:(NSUUID*)peripheralUuid {
	if (_exposureMinDuration <= record.durationInterval) {
		NSString *rpiString = [rpi base64EncodedStringWithOptions:0];
		NSTimeInterval currentTimeInterval = [[[NSDate alloc] init] timeIntervalSince1970];
		NSLog(@"ExposurePlugin: Report Exposure: rpi: {%@} duration: %@", rpiString, @(record.duration));
		
		[_methodChannel invokeMethod:kExposureNotificationName arguments:@{
			kExposureTimestampParamName: [NSNumber numberWithInteger:record.timestampCreated],
			kExposureRPIParamName:       rpiString ?: [NSNull null],
			kExposureDurationParamName:  [NSNumber numberWithInteger:record.duration],

			@"peripheralUuid":           [peripheralUuid UUIDString] ?: [NSNull null],
			@"isiOSRecord":              [NSNumber numberWithBool:(peripheralUuid != nil)],
			@"endTimestamp":             [NSNumber numberWithInteger:currentTimeInterval * 1000.0],
		}];
	}
}

- (void)notifyExposureTick:(NSData*)rpi rssi:(int)rssi peripheralUuid:(NSUUID*)peripheralUuid {

	// Do not allow more than 1 notification per second
	NSTimeInterval currentTimeInterval = [[[NSDate alloc] init] timeIntervalSince1970];
	if (kExposureNotifyTickInterval <= (currentTimeInterval - _lastNotifyExposireThickTime)) {

		NSString *rpiString = (rpi != nil) ? [rpi base64EncodedStringWithOptions:0] : nil;
		NSInteger currentTimestamp = (NSInteger)(currentTimeInterval * 1000.0);

		[_methodChannel invokeMethod:kExposureThickNotificationName arguments:@{
			kExposureTimestampParamName: [NSNumber numberWithInteger:currentTimestamp],
			kExposureRPIParamName:       rpiString ?: @"...",
			kExposureRSSIParamName:      [NSNumber numberWithInteger:rssi],
			@"peripheralUuid":           [peripheralUuid UUIDString] ?: [NSNull null],
		}];
	
		_lastNotifyExposireThickTime = currentTimeInterval;
	}

}

- (void)notifyTEK:(NSData*)tek timestamp:(NSInteger)timestamp expirestamp:(NSInteger)expirestamp {
	NSString *tekString = [tek base64EncodedStringWithOptions:0];
	NSLog(@"ExposurePlugin: Report TEK: {%@}", tekString);
	[_methodChannel invokeMethod:kTEKNotificationName arguments:@{
		kTEKTimestampParamName:   [NSNumber numberWithInteger:timestamp], // in milliseconds
		kTEKExpirestampParamName: [NSNumber numberWithInteger:expirestamp],  // in milliseconds
		kTEKValueParamName:       tekString ?: [NSNull null],
	}];
}

- (void)notifyRPI:(NSData*)rpi tek:(NSData*)tek updateType:(NSString*)updateType timestamp:(NSInteger)timestamp _i:(uint32_t)_i ENInvertalNumber:(uint32_t)ENInvertalNumber {
	NSString *rpiString = [rpi base64EncodedStringWithOptions:0];
	NSString *tekString = [tek base64EncodedStringWithOptions:0];
	NSLog(@"ExposurePlugin: Report RPI: {%@}", rpiString);
	[_methodChannel invokeMethod:kRPILogMethodName arguments:@{
		kExposureTimestampParamName:            [NSNumber numberWithInteger:timestamp],
		@"updateType":                          updateType ?: [NSNull null],
		@"rpi":                                 rpiString ?: [NSNull null],
		@"tek":                                 tekString ?: [NSNull null],
		@"_i":                                  [NSNumber numberWithInteger:_i],
		@"ENInvertalNumber":                    [NSNumber numberWithInteger:ENInvertalNumber],
	}];
}

- (void)notifyRSSI:(int)rssi rpi:(NSData*)rpi timestamp:(NSInteger)timestamp peripheralUuid:(NSUUID*)peripheralUuid {
	NSString *rpiString = [rpi base64EncodedStringWithOptions:0];
	[_methodChannel invokeMethod:kRSSILogMethodName arguments:@{
		kExposureTimestampParamName: [NSNumber numberWithInteger:timestamp],
		@"rpi":                      rpiString ?: [NSNull null],
		@"rssi":                     [NSNumber numberWithInt:rssi],
		@"isiOSRecord":              [NSNumber numberWithBool:(peripheralUuid != nil)],
		@"address":                  [peripheralUuid UUIDString] ?: [NSNull null],
	}];
}

@end

////////////////////////////////////
// ExposureRecord

@interface ExposureRecord() {
	NSTimeInterval _timeCreated;
	NSTimeInterval _timeUpdated;
	int            _lastRSSI;
	NSTimeInterval _durationInterval;
}
@end

@implementation ExposureRecord

- (instancetype)initWithTimestamp:(NSTimeInterval)timestamp rssi:(int)rssi {
	if (self = [super init]) {
		_lastRSSI = rssi;
		_durationInterval = 0;
		_timeCreated = _timeUpdated = timestamp;
	}
	return self;
}

- (void)updateTimestamp:(NSTimeInterval)timestamp rssi:(int)rssi {
	if ((ExposurePlugin.sharedInstance.exposureMinRssi <= _lastRSSI) && (_lastRSSI != kNoRssi)) {
		_durationInterval += (timestamp - _timeUpdated);
	}
	_lastRSSI = rssi;
	_timeUpdated = timestamp;
}

- (NSInteger)timestampCreated {
	return (NSInteger)(_timeCreated * 1000.0); // in milliseconds
}

- (NSTimeInterval)timeUpdated {
	return _timeUpdated;
}

- (NSInteger)duration {
	return (NSInteger)(_durationInterval * 1000.0); // in milliseconds
}

- (NSTimeInterval)durationInterval {
	return _durationInterval; // in seconds
}

- (int)rssi {
	return _lastRSSI;
}

@end

////////////////////////////////////
// TEKRecord

@implementation TEKRecord
//@property (nonatomic) int expire;
//@property (nonatomic) NSData*   tek;

- (instancetype)initWithTEK:(NSData*)tek expire:(int)expire {
	if (self = [super init]) {
		_tek = tek;
		_expire = expire;
	}
	return self;

}

+ (instancetype)fromJson:(NSDictionary*)json {
	return (json != nil) ? [[TEKRecord alloc]
		initWithTEK: [[NSData alloc] initWithBase64EncodedString:[json inaStringForKey:@"tek"] options:0]
		expire: [json inaIntForKey:@"expire"]] : nil;
}

- (NSDictionary*)toJson {
	return @{
		@"tek": [_tek base64EncodedStringWithOptions:0] ?: [NSNull null],
		@"expire": @(_expire)
	};
}

@end
