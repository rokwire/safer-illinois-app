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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/utils/Utils.dart';

class NativeCommunicator with Service {
  
  static const String notifyMapSelectExplore  = "edu.illinois.rokwire.nativecommunicator.map.explore.select";
  static const String notifyMapClearExplore   = "edu.illinois.rokwire.nativecommunicator.map.explore.clear";
  
  static const String notifyMapRouteStart    = "edu.illinois.rokwire.nativecommunicator.map.route.start";
  static const String notifyMapRouteFinish   = "edu.illinois.rokwire.nativecommunicator.map.route.finish";
  
  final MethodChannel _platformChannel = const MethodChannel("edu.illinois.covid/core");

  // Singletone
  static final NativeCommunicator _communicator = new NativeCommunicator._internal();

  factory NativeCommunicator() {
    return _communicator;
  }

  NativeCommunicator._internal();

  // Initialization

  @override
  void createService() {
    _platformChannel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Future<void> initService() async {
    await _nativeInit();
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Config()]);
  }

  Future<void> _nativeInit() async {
    try {
      await _platformChannel.invokeMethod('init', { "keys": Config().secretKeys });
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> launchExploreMapDirections({dynamic target}) async {
    dynamic jsonData;
    try {
      if (target != null) {
        if (target is List) {
          jsonData = List<dynamic>();
          for (dynamic entry in target) {
            jsonData.add(entry.toJson());
          }
        }
        else {
          jsonData = target.toJson();
        }
      }
    } on PlatformException catch (e) {
      print(e.message);
    }
    
    if (jsonData != null) {
      await launchMapDirections(jsonData: jsonData);
    }
  }

  Future<void> launchMapDirections({dynamic jsonData}) async {
    try {
      String lastPageName = Analytics().currentPageName;
      Map<String, dynamic> lastPageAttributes = Analytics().currentPageAttributes;
      Analytics().logPage(name: 'MapDirections');
      Analytics().logMapShow();
      
      await _platformChannel.invokeMethod('directions', {
        'explore': jsonData,
        'options': {
          'showDebugLocation': Storage().debugMapLocationProvider,
          'hideLevels': Storage().debugMapHideLevels,
        }});

      Analytics().logMapHide();
      Analytics().logPage(name: lastPageName, attributes: lastPageAttributes);
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> launchMap({dynamic target, dynamic markers}) async {
    try {
      String lastPageName = Analytics().currentPageName;
      Map<String, dynamic> lastPageAttributes = Analytics().currentPageAttributes;
      Analytics().logPage(name: 'Map');
      Analytics().logMapShow();

      await _platformChannel.invokeMethod('map', {
        'target': target,
        'options': {
          'showDebugLocation': Storage().debugMapLocationProvider,
          'hideLevels': Storage().debugMapHideLevels,
        },
        'markers': markers,
      });

      Analytics().logMapHide();
      Analytics().logPage(name: lastPageName, attributes: lastPageAttributes);

    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void>launchNotification({String title, String subtitle, String body, bool sound = true}) async {
    await _platformChannel.invokeMethod('showNotification', {
      'title': title,
      'subtitle': subtitle,
      'body': body,
      'sound': sound,
    });
  }

  Future<void> dismissSafariVC() async {
    try {
      await _platformChannel.invokeMethod('dismissSafariVC');
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> dismissLaunchScreen() async {
    try {
      await _platformChannel.invokeMethod('dismissLaunchScreen');
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> addCardToWallet(List<int> cardData) async {
    try {
      String cardBase64Data = base64Encode(cardData);
      await _platformChannel.invokeMethod('addToWallet', { "cardBase64Data" : cardBase64Data });
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<dynamic> microBlinkScan({List<String> recognizers}) async {
    try {
      return await _platformChannel.invokeMethod('microBlinkScan', { 'recognizers' : recognizers });
    } on PlatformException catch (e) {
      print(e.message);
    }
    return null;
  }

  Future<List<DeviceOrientation>> enabledOrientations(List<DeviceOrientation> orientationsList) async {
    List<DeviceOrientation> result;
    try {
      dynamic inputStringsList = AppDeviceOrientation.toStrList(orientationsList);
      dynamic outputStringsList = await _platformChannel.invokeMethod('enabledOrientations', { "orientations" : inputStringsList });
      result = AppDeviceOrientation.fromStrList(outputStringsList);
    } on PlatformException catch (e) {
      print(e.message);
    }
    return result;
  }

  Future<String> queryFirebaseInfo() async {
    String result;
    try {
      result = await _platformChannel.invokeMethod('firebaseInfo');
    } on PlatformException catch (e) {
      print(e.message);
    }
    return result;
  }

  Future<bool> queryNotificationsAuthorization(String method) async {
    bool result = false;
    try {
      result = await _platformChannel.invokeMethod('notifications_authorization', {"method": method });
    } on PlatformException catch (e) {
      print(e.message);
    }
    return result;
  }

  Future<String> queryLocationServicesPermission(String method) async {
    String result;
    try {
      result = await _platformChannel.invokeMethod('location_services_permission', {"method": method });
    } on PlatformException catch (e) {
      print(e.message);
    }
    return result;
  }

  Future<String> queryBluetoothAuthorization(String method) async {
    String result;
    try {
      result = await _platformChannel.invokeMethod('bluetooth_authorization', {"method": method });
    } on PlatformException catch (e) {
      print(e.message);
    }
    return result;
  }

  Future<String> getDeviceId() async {
    String result;
    try {
      result = await _platformChannel.invokeMethod('deviceId');
    }on PlatformException catch (e) {
      print(e.message);
    }
    return result;
  }

  Future<String> getHealthRSAPrivateKey({String userId}) async {
    String result;
    try {
      result = await _platformChannel.invokeMethod('healthRSAPrivateKey', {
        'userId': userId,
      });
    } catch (e) {
      print(e?.toString());
    }
    return result;
  }

  Future<bool> setHealthRSAPrivateKey({String userId, String value}) async {
    bool result;
    try {
      result = await _platformChannel.invokeMethod('healthRSAPrivateKey', {
        'userId': userId,
        'value': value,
      });
    } catch (e) {
      print(e?.toString());
    }
    return result;
  }

  Future<bool> removeHealthRSAPrivateKey({String userId}) async {
    bool result;
    try {
      result = await _platformChannel.invokeMethod('healthRSAPrivateKey', {
        'userId': userId,
        'remove': true,
      });
    } catch (e) {
      print(e?.toString());
    }
    return result;
  }

  Future<Uint8List> getBarcodeImageData(Map<String, dynamic> params) async {
    try {
      String base64String = await _platformChannel.invokeMethod('barcode', params);
      return (base64String != null) ? base64Decode(base64String) : null;
    }
    catch (e) {
      print(e.message);
    }
    return null;
  }

  Future<void> launchTest() async {
    try {
      await _platformChannel.invokeMethod('test');
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "map.explore.select":
        _notifyMapSelectExplore(call.arguments);
        break;
      case "map.explore.clear":
        _notifyMapClearExplore(call.arguments);
        break;
      
      case "map.route.start":
        _notifyMapRouteStart(call.arguments);
        break;
      case "map.route.finish":
        _notifyMapRouteFinish(call.arguments);
        break;
      
      case "firebase_message":
        //PS use firebase messaging plugin!
        //FirebaseMessaging().onMessage(call.arguments);
        break;

      default:
        break;
    }
    return null;
  }

  void _notifyMapSelectExplore(dynamic arguments) {
    dynamic jsonData = (arguments is String) ? AppJson.decode(arguments) : null;
    Map<String, dynamic> params = (jsonData is Map) ? jsonData.cast<String, dynamic>() : null;
    int mapId = (params is Map) ? params['mapId'] : null;
    dynamic exploreJson = (params is Map) ? params['explore'] : null;

    NotificationService().notify(notifyMapSelectExplore, {
      'mapId': mapId,
      'exploreJson': exploreJson
    });
  }
  
  void _notifyMapClearExplore(dynamic arguments) {
    dynamic jsonData = (arguments is String) ? AppJson.decode(arguments) : null;
    Map<String, dynamic> params = (jsonData is Map) ? jsonData.cast<String, dynamic>() : null;
    int mapId = (params is Map) ? params['mapId'] : null;

    NotificationService().notify(notifyMapClearExplore, {
      'mapId': mapId,
    });
  }

  void _notifyMapRouteStart(dynamic arguments) {
    dynamic jsonData = (arguments is String) ? AppJson.decode(arguments) : null;
    Map<String, dynamic> params = (jsonData is Map) ? jsonData.cast<String, dynamic>() : null;
    NotificationService().notify(notifyMapRouteStart, params);
  }

  void _notifyMapRouteFinish(dynamic arguments) {
    dynamic jsonData = (arguments is String) ? AppJson.decode(arguments) : null;
    Map<String, dynamic> params = (jsonData is Map) ? jsonData.cast<String, dynamic>() : null;
    NotificationService().notify(notifyMapRouteFinish, params);
  }
}
