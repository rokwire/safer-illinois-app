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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as Http;
import 'package:illinois/model/UserProfile.dart';
import 'package:illinois/service/AppNavigation.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Connectivity.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:package_info/package_info.dart';
import 'package:device_info/device_info.dart';
import 'package:uuid/uuid.dart';

import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/LocationServices.dart';

class Analytics with Service implements NotificationsListener {

  // Database Data

  static const String   _databaseName         = "analytics.db";
  static const int      _databaseVersion      = 1;
  static const String   _databaseTable        = "events";
  static const String   _databaseColumn       = "packet";
  static const String   _databaseRowID        = "rowid";
  static const int      _databaseMaxPackCount = 64;
  static const Duration _timerTick            = const Duration(milliseconds: 100);
  
  // Log Data

  // Standard (shared) Attributes
  static const String   LogStdTimestampName                = "timestamp";
  static const String   LogStdAppIdName                    = "app_id";
  static const String   LogStdAppVersionName               = "app_version";
  static const String   LogStdOSName                       = "os_name";
  static const String   LogStdOSVersionName                = "os_version";
  static const String   LogStdLocaleName                   = "locale";
  static const String   LogStdDeviceModelName              = "device_model";
  static const String   LogStdConnectionName               = "connection";
  static const String   LogStdLocationSvcName              = "location_services";
  static const String   LogStdNotifySvcName                = "notification_services";
  static const String   LogStdSessionUuidName              = "session_uuid";
  static const String   LogStdUserUuidName                 = "user_uuid";
  static const String   LogStdUserRolesName                = "user_roles";
  static const String   LogStdAccessibilityName            = "accessibility";

  static const String   LogStdAuthCardRoleName             = "icard_role";
  static const String   LogStdAuthCardStudentLevel         = "icard_student_level";
  
  static const String   LogEvent                           = "event";
  static const String   LogEventName                       = "name";
  static const String   LogEventPageName                   = "page";

  static const List<String> DefaultAttributes = [
    LogStdTimestampName,
    LogStdAppIdName,
    LogStdAppVersionName,
    LogStdOSName,
    LogStdOSVersionName,
    LogStdLocaleName,
    LogStdDeviceModelName,
    LogStdConnectionName,
    LogStdLocationSvcName,
    LogStdNotifySvcName,
    LogStdSessionUuidName,
    LogStdUserUuidName,
    LogStdUserRolesName,
    LogStdAccessibilityName,
    LogStdAuthCardRoleName,
    LogStdAuthCardStudentLevel,
  ];

  static const List<String> HealthAttributes = [
    LogStdTimestampName,
    LogStdAppIdName,
    LogStdAppVersionName,
    LogStdSessionUuidName,
    LogStdUserUuidName,
  ];

  // Livecycle Event
  // { "event" : { "name":"livecycle", "livecycle_event":"..." } }
  static const String   LogLivecycleEventName              = "livecycle";
  static const String   LogLivecycleName                   = "livecycle_event";
  static const String   LogLivecycleEventCreate            = "create";
  static const String   LogLivecycleEventDestroy           = "destroy";
  static const String   LogLivecycleEventBackground        = "background";
  static const String   LogLivecycleEventForeground        = "foreground";

  // Page Event
  // { "event" : { "name":"page", "page":"...", "page_name":"...", "previous_page_name":"" } }
  static const String   LogPageEventName                   = "page";
  static const String   LogPageName                        = "page_name";
  static const String   LogPagePreviousName                = "previous_page_name";

  // Select Event
  // "event" : { "name":"select", "page":"...", "target":"..." } }
  static const String   LogSelectEventName                 = "select";
  static const String   LogSelectTargetName                = "target";

  // Alert Event
  // {  "event" : { "name":"alert", "page":"...", "text":"...", "selection":"..." }}
  static const String   LogAlertEventName                  = "alert";
  static const String   LogAlertTextName                   = "text";
  static const String   LogAlertSelectionName              = "selection";

  // Http Response Event
  // "event" : { "name":"http_response", "http_request_url":"...", "http_request_method":"...", "http_response_code":... }
  static const String   LogHttpResponseEventName           = "http_response";
  static const String   LogHttpRequestUrlName              = "http_request_url";
  static const String   LogHttpRequestMethodName           = "http_request_method";
  static const String   LogHttpResponseCodeName            = "http_response_code";

  // Map Route
  static const String   LogMapRouteEventName               = "map_route";
  static const String   LogMapRouteAction                  = "action";
  static const String   LogMapRouteStartActionName         = "start";
  static const String   LogMapRouteFinishActionName        = "finish";
  static const String   LogMapRouteOrigin                  = "origin";
  static const String   LogMapRouteDestination             = "destination";
  static const String   LogMapRouteLocation                = "location";

  // Map Display
  static const String   LogMapDisplayEventName             = "map_dispaly";
  static const String   LogMapDisplayAction                = "action";
  static const String   LogMapDisplayShowActionName        = "show";
  static const String   LogMapDisplayHideActionName        = "hide";

  // GeoFence Regions
  static const String   LogGeoFenceRegionEventName         = "geofence_region";
  static const String   LogGeoFenceRegionAction            = "action";
  static const String   LogGeoFenceRegionEnterActionName   = "enter";
  static const String   LogGeoFenceRegionExitActionName    = "exit";
  static const String   LogGeoFenceRegionRegion            = "region";
  static const String   LogGeoFenceRegionRegionId          = "id";
  static const String   LogGeoFenceRegionRegionName        = "name";
  
  // Illini Cash
  static const String   LogIllniCashEventName              = "illini_cash";
  static const String   LogIllniCashAction                 = "action";
  static const String   LogIllniCashPurchaseActionName     = "purchase";
  static const String   LogIllniCashPurchaseAmount         = "amount";

  // Auth
  static const String   LogAuthEventName                   = "auth";
  static const String   LogAuthAction                      = "action";
  static const String   LogAuthLoginNetIdActionName        = "login_netid";
  static const String   LogAuthLoginPhoneActionName        = "login_phone";
  static const String   LogAuthLogoutActionName            = "logout";
  static const String   LogAuthResult                      = "result";

  // Document Scan
  static const String   LogDocumentScanEventName           = "document_scan";
  static const String   LogDocumentScanType                = "type";
  static const String   LogDocumentScanDrivingLicenseType  = "driving_license";
  static const String   LogDocumentScanPassportType        = "passport";
  static const String   LogDocumentScanResult              = "result";

  // Health
  static const String   LogHealthEventName                       = "health";
  static const String   LogHealthActionName                      = "action";
  static const String   LogHealthStatusChangedAction             = "status_changed";
  static const String   LogHealthSettingChangedAction            = "setting_changed";
  static const String   LogHealthProviderTestProcessedAction     = "provider_test_processed";
  static const String   LogHealthManualTestSubmittedAction       = "manual_test_submitted";
  static const String   LogHealthSymptomsSubmittedAction         = "symptoms_submitted";
  static const String   LogHealthActionProcessedAction           = "action_processed";
  static const String   LogHealthVaccinationAction               = "vaccination";
  static const String   LogHealthStatusName                      = "status";
  static const String   LogHealthPrevStatusName                  = "previous_status";
  static const String   LogHealthSettingConsentTestResultsName   = "consent_test_results";
  static const String   LogHealthSettingConsentVaccineInfoName   = "consent_vaccine_information";
  static const String   LogHealthSettingConsentExposureNotifName = "notify_exposures";
  static const String   LogHealthProviderName                    = "provider";
  static const String   LogHealthLocationName                    = "location";
  static const String   LogHealthTestTypeName                    = "test_type";
  static const String   LogHealthTestResultName                  = "test_result";
  static const String   LogHealthSymptomsName                    = "symptoms";
  static const String   LogHealthVaccineStatusName               = "vaccine_status";
  static const String   LogHealthActionTypeName                  = "action_type";
  static const String   LogHealthActionTitleName                 = "action_title";
  static const String   LogHealthActionTextName                  = "action_text";
  static const String   LogHealthActionParamsName                = "action_params";
  static const String   LogHealthActionTimestampName             = "action_timestamp";

  // Event Attributes
  static const String   LogAttributeUrl                    = "url";
  static const String   LogAttributeEventId                = "event_id";
  static const String   LogAttributeEventName              = "event_name";
  static const String   LogAttributeEventCategory          = "event_category";
  static const String   LogAttributeRecurrenceId           = "recurrence_id";
  static const String   LogAttributeDiningId               = "dining_id";
  static const String   LogAttributeDiningName             = "dining_name";
  static const String   LogAttributePlaceId                = "place_id";
  static const String   LogAttributePlaceName              = "place_name";
  static const String   LogAttributeGameId                 = "game_id";
  static const String   LogAttributeGameName               = "game_name";
  static const String   LogAttributeLaundryId              = "laundry_id";
  static const String   LogAttributeLaundryName            = "laundry_name";
  static const String   LogAttributeLocation               = "location";


  // Data

  Database             _database;
  Timer                _timer;
  bool                 _inTimer = false;
  
  String               _currentPageName;
  Map<String, dynamic> _currentPageAttributes;
  bool                 _currentPageAnonymous;
  PackageInfo          _packageInfo;
  AndroidDeviceInfo    _androidDeviceInfo;
  IosDeviceInfo        _iosDeviceInfo;
  String               _appId;
  String               _appVersion;
  String               _osVersion;
  String               _deviceModel;
  ConnectivityStatus   _connectionStatus;
  String               _connectionName;
  String               _locationServices;
  String               _notificationServices;
  String               _sessionUuid;
  String               _accessibilityState;
  List<dynamic>        _userRoles;
  

  // Singletone Instance

  Analytics._internal();
  static final Analytics _instance = Analytics._internal();

  factory Analytics() {
    return _instance;
  }
  
  static Analytics get instance {
    return _instance;
  }

  // Initialization

  @override
  void createService() {
    NotificationService().subscribe(this, [
      Connectivity.notifyStatusChanged,
      AppLivecycle.notifyStateChanged,
      AppNavigation.notifyEvent,
      LocationServices.notifyStatusChanged,
      UserProfile.notifyRolesUpdated,
      UserProfile.notifyProfileUpdated,
      UserProfile.notifyProfileDeleted,
      NativeCommunicator.notifyMapRouteStart,
      NativeCommunicator.notifyMapRouteFinish,
    ]);
  }

  @override
  Future<void> initService() async {

    await _initDatabase();
    _initTimer();
    
    _updateConnectivity();
    _updateLocationServices();
    _updateNotificationServices();
    _updateUserRoles();
    _updateSessionUuid();

    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      _packageInfo = packageInfo;
      _appId = _packageInfo?.packageName;
      _appVersion = "${_packageInfo?.version}+${_packageInfo?.buildNumber}";
    });

    if (defaultTargetPlatform == TargetPlatform.android) {
      DeviceInfoPlugin().androidInfo.then((AndroidDeviceInfo androidDeviceInfo) {
        _androidDeviceInfo = androidDeviceInfo;
        _deviceModel = _androidDeviceInfo.model;
        _osVersion = _androidDeviceInfo.version.release;
      });
    }
    else if (defaultTargetPlatform == TargetPlatform.iOS) {
      DeviceInfoPlugin().iosInfo.then((IosDeviceInfo iosDeviceInfo) {
        _iosDeviceInfo = iosDeviceInfo;
        _deviceModel = _iosDeviceInfo.model;
        _osVersion = _iosDeviceInfo.systemVersion;
      });
    }
  }

  @override
  Future<void> clearService() async {
    await _clearDatabase();
    _closeTimer();
    
    _clearUserRoles();
    _updateSessionUuid();
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);

    _closeDatabase();
    _closeTimer();
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Config(), UserProfile(), LocationServices(), Connectivity() ]);
  }

  // Database

  Future<void> _initDatabase() async {
    if (_database == null) {
      String databasePath = await getDatabasesPath();
      String databaseFile = join(databasePath, _databaseName);
      _database = await openDatabase(databaseFile, version: _databaseVersion, onCreate: (db, version) {
        return db.execute("CREATE TABLE IF NOT EXISTS $_databaseTable($_databaseColumn TEXT NOT NULL)",);
      });
    }
  }

  Future<void> _clearDatabase() async {
    if (_database != null) {
      await _database.execute("DELETE FROM $_databaseTable",);
    }
  }

  void _closeDatabase() {
    if (_database != null) {
      _database.close();
      _database = null;
    }
  }

  // Timer

  void _initTimer() {
      if (_timer == null) {
        //Log.d("Analytics: awake");
        _timer = Timer.periodic(_timerTick, _onTimer);
        _inTimer = false;
      }
  }

  void _closeTimer() {
    if (_timer != null) {
      //Log.d("Analytics: asleep");
      _timer.cancel();
      _timer = null;
    }
    _inTimer = false;
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Connectivity.notifyStatusChanged) {
      _applyConnectivityStatus(param);
    }
    else if (name == LocationServices.notifyStatusChanged) {
      _applyLocationServicesStatus(param);
    }
    else if (name == AppLivecycle.notifyStateChanged) {
      _onAppLivecycleStateChanged(param);
    }
    else if (name == AppNavigation.notifyEvent) {
      _onAppNavigationEvent(param);
    }
    else if (name == UserProfile.notifyRolesUpdated) {
      _updateUserRoles();
    }
    else if (name == UserProfile.notifyProfileUpdated) {
      _updateUserRoles();
    }
    else if (name == UserProfile.notifyProfileDeleted) {
      _updateSessionUuid();
      _updateUserRoles();
    }
    else if (name == NativeCommunicator.notifyMapRouteStart) {
      logMapRoute(action: LogMapRouteStartActionName, params: param);
    }
    else if (name == NativeCommunicator.notifyMapRouteFinish) {
      logMapRoute(action: LogMapRouteFinishActionName, params: param);
    }
  }

  // Connectivity

  void _updateConnectivity() {
    _applyConnectivityStatus(Connectivity().status);
}

  void _applyConnectivityStatus(ConnectivityStatus status) {
    _connectionName = _connectivityStatusToString(_connectionStatus = status);
  }

  static String _connectivityStatusToString(ConnectivityStatus result) {
    return result?.toString()?.substring("ConnectivityStatus.".length);
  }
  
  // App Livecycle Service
  
  void _onAppLivecycleStateChanged(AppLifecycleState state) {

    if (state == AppLifecycleState.paused) {
      logLivecycle(name: LogLivecycleEventBackground);
    }
    else if (state == AppLifecycleState.resumed) {
      _updateSessionUuid();
      _updateNotificationServices();
      logLivecycle(name: LogLivecycleEventForeground);
    }
    else if (state == AppLifecycleState.detached) {
      logLivecycle(name: Analytics.LogLivecycleEventDestroy);
    }

  }

  // App Naviagtion Service

  void _onAppNavigationEvent(Map<String, dynamic> param) {
    AppNavigationEvent event = param[AppNavigation.notifyParamEvent];
    if (event == AppNavigationEvent.push) {
      _logRoute(param[AppNavigation.notifyParamRoute]);
    }
    else if (event == AppNavigationEvent.pop) {
      _logRoute(param[AppNavigation.notifyParamPreviousRoute]);
    }
    else if (event == AppNavigationEvent.remove) {
      _logRoute(param[AppNavigation.notifyParamPreviousRoute]);
    }
    else if (event == AppNavigationEvent.replace) {
      _logRoute(param[AppNavigation.notifyParamRoute]);
    }
  }

  void _logRoute(Route route) {

    WidgetBuilder builder;
    if (route is CupertinoPageRoute) {
      builder = route.builder;
    }
    else if (route is MaterialPageRoute) {
      builder = route.builder;
    }

    if (builder != null) {
      Widget panel = builder(null);
      if (panel != null) {
        String panelName;
        if (panel is AnalyticsPageName) {
          panelName = (panel as AnalyticsPageName).analyticsPageName;
        }
        if (panelName == null) {
          panelName = panel.runtimeType.toString();
        }

        Map<String, dynamic> panelAttributes;
        if (panel is AnalyticsPageAttributes) {
          panelAttributes = (panel as AnalyticsPageAttributes).analyticsPageAttributes;
        }

        bool anonymous = (panel is AnalyticsPageAnonymous) ? (panel as AnalyticsPageAnonymous).analyticsPageAnonymous : true;

        logPage(name: panelName, attributes: panelAttributes, anonymous: anonymous);
      }
    }
  }

  // Location Services

  void _updateLocationServices() {
    LocationServices.instance.status.then((LocationServicesStatus locationServicesStatus) {
      _applyLocationServicesStatus(locationServicesStatus);
    });
  }

  void _applyLocationServicesStatus(LocationServicesStatus locationServicesStatus) {
    switch (locationServicesStatus) {
      case LocationServicesStatus.ServiceDisabled:          _locationServices = "disabled"; break;
      case LocationServicesStatus.PermissionNotDetermined:  _locationServices = "not_determined"; break;
      case LocationServicesStatus.PermissionDenied:         _locationServices = "denied"; break;
      case LocationServicesStatus.PermissionAllowed:        _locationServices = "allowed"; break;
    }
  }

  // Notification Services

  void updateNotificationServices() {
    _updateNotificationServices();
  }

  void _updateNotificationServices() {
    // Android does not need for permission for user notifications
    if (Platform.isAndroid) {
      _notificationServices = 'enabled';
    } else if (Platform.isIOS) {
      NativeCommunicator().queryNotificationsAuthorization("query").then((bool notificationsAuthorized) {
        _notificationServices = notificationsAuthorized ? 'enabled' : "not_enabled";
      });
    }
  }

  // Sesssion Uuid

  void _updateSessionUuid() {
    _sessionUuid = Uuid().v1();
  }

  // Accessibility

  bool get accessibilityState {
    return (_accessibilityState != null) ? (true.toString() == _accessibilityState) : null;
  }

  set accessibilityState(bool value) {
    _accessibilityState = (value != null) ? value.toString() : null;
  }

  // UserProfile Roles Service

  void _updateUserRoles() {
    Set<UserRole> roles = UserProfile().roles;
    _userRoles = UserRole.userRolesToList(roles);
  }

  void _clearUserRoles() {
    _userRoles = null;
  }

  // Packets Processing
  
  Future<int> _savePacket(String packet) async {
    if ((packet != null) && (_database != null)) {
      int result = await _database.insert(_databaseTable, { _databaseColumn : packet });
      //Log.d("Analytics: scheduled packet #$result $packet");
      _initTimer();
      return result;
    }
    return -1;
  }

  void _onTimer(_) {
    
    if ((_database != null) && !_inTimer && (_connectionStatus != ConnectivityStatus.none)) {
      _inTimer = true;
      
      _database.rawQuery("SELECT $_databaseRowID, $_databaseColumn FROM $_databaseTable ORDER BY $_databaseRowID LIMIT $_databaseMaxPackCount").then((List<Map<String, dynamic>> records) {
        if ((records != null) && (0 < records.length)) {

          String packets = '', rowIDs = '';
          for (Map<String, dynamic> record in records) {

            if (0 < packets.length)
              packets += ',';
            packets += '${record[_databaseColumn]}';

            if (0 < rowIDs.length)
              rowIDs += ',';
            rowIDs += '${record[_databaseRowID]}';
          }
          packets = '[' + packets + ']';
          rowIDs = '(' + rowIDs + ')';

          _sendPacket(packets).then((bool success) {
            if (success) {
              _database.execute("DELETE FROM $_databaseTable WHERE $_databaseRowID in $rowIDs").then((_){
                //Log.d("Analytics: sent packets $rowIDs");
                _inTimer = false;
              });
            }
            else {
              //Log.d("Analytics: failed to send packets $rowIDs");
              _inTimer = false;
            }
          });
        }
        else {
          _closeTimer();
        }
      });
    }
  }

  Future<bool>_sendPacket(String packet) async {
    if (packet != null) {
      try {
        final response = (Config().loggingUrl != null) ? await Network().post(Config().loggingUrl, body: packet, headers: { "Accept": "application/json", "Content-type":"application/json" }, auth: Network.AppAuth, sendAnalytics: false) : null;
        return (response != null) && ((response.statusCode == 200) || (response.statusCode == 201));
      }
      catch (e) {
        print(e.toString());
        return false;
      }
    }
    return false;
  }

  // Public Accessories

  void logEvent(Map<String, dynamic> event, { List<String> defaultAttributes = DefaultAttributes, bool anonymous = true}) {
    if (event != null) {
      
      event[LogEventPageName] = _currentPageName;

      Map<String, dynamic> analyticsEvent = {
        LogEvent:            event,
      };

      for (String attributeName in defaultAttributes) {
        if (attributeName == LogStdTimestampName) {
          analyticsEvent[LogStdTimestampName] = DateTime.now().toUtc().toIso8601String();
        }
        else if (attributeName == LogStdAppIdName) {
          analyticsEvent[LogStdAppIdName] = _appId;
        }
        else if (attributeName == LogStdAppVersionName) {
          analyticsEvent[LogStdAppVersionName] = _appVersion;
        }
        else if (attributeName == LogStdOSName) {
          analyticsEvent[LogStdOSName] = Platform.operatingSystem;
        }
        else if (attributeName == LogStdOSVersionName) {
          analyticsEvent[LogStdOSVersionName] =_osVersion; // Platform.operatingSystemVersion;
        }
        else if (attributeName == LogStdLocaleName) {
          analyticsEvent[LogStdLocaleName] = Platform.localeName;
        }
        else if (attributeName == LogStdDeviceModelName) {
          analyticsEvent[LogStdDeviceModelName] = _deviceModel;
        }
        else if (attributeName == LogStdConnectionName) {
          analyticsEvent[LogStdConnectionName] = _connectionName;
        }
        else if (attributeName == LogStdLocationSvcName) {
          analyticsEvent[LogStdLocationSvcName] = _locationServices;
        }
        else if (attributeName == LogStdNotifySvcName) {
          analyticsEvent[LogStdNotifySvcName] = _notificationServices;
        }
        else if (attributeName == LogStdSessionUuidName) {
          analyticsEvent[LogStdSessionUuidName] = _sessionUuid;
        }
        else if (attributeName == LogStdUserUuidName) {
          analyticsEvent[LogStdUserUuidName] = ((UserProfile().uuid != null) && (anonymous != false)) ? UserProfile.analyticsUuid : UserProfile().uuid;
        }
        else if (attributeName == LogStdUserRolesName) {
          analyticsEvent[LogStdUserRolesName] = _userRoles;
        }
        else if (attributeName == LogStdAccessibilityName) {
          analyticsEvent[LogStdAccessibilityName] = _accessibilityState;
        }
        else if(attributeName == LogStdAuthCardRoleName){
          analyticsEvent[LogStdAuthCardRoleName] = Auth()?.authCard?.role;
        }
        else if(attributeName == LogStdAuthCardStudentLevel){
          analyticsEvent[LogStdAuthCardStudentLevel] = Auth()?.authCard?.studentLevel;
        }
      }

      String packet = json.encode(analyticsEvent);
      if (packet != null) {
        print('Analytics: $packet');
        _savePacket(packet);
      }
    }
  }

  void logLivecycle({String name, bool anonymous = true}) {
    logEvent({
      LogEventName          : LogLivecycleEventName,
      LogLivecycleName      : name,
    },
    anonymous: anonymous);
  }

  String get currentPageName {
    return _currentPageName;
  }

  Map<String, dynamic> get currentPageAttributes {
    return _currentPageAttributes;
  }

  bool get currentPageAnonymous {
    return _currentPageAnonymous;
  }

  void logPage({String name,  Map<String, dynamic> attributes, bool anonymous : true}) {

    if (_currentPageAnonymous != null) {
      anonymous = (anonymous != null) ? (anonymous || _currentPageAnonymous) : _currentPageAnonymous;
    }

    // Update Current page name
    String previousPageName = _currentPageName;
    _currentPageName        = name;
    _currentPageAttributes  = attributes;
    _currentPageAnonymous   = anonymous;

    // Build event data
    Map<String, dynamic> event = {
      LogEventName          : LogPageEventName,
      LogPageName           : name,
      LogPagePreviousName   : previousPageName
    };

    if (attributes != null) {
      event.addAll(attributes);
    }

    // Log the event
    logEvent(event, anonymous: (anonymous != false));
  }

  void logSelect({String target, bool anonymous = true}) {
    logEvent({
      LogEventName          : LogSelectEventName,
      LogSelectTargetName   : target,
    }, anonymous: anonymous);
  }

  void logAlert({String text, String selection, bool anonymous = true}) {
    logEvent({
      LogEventName          : LogAlertEventName,
      LogAlertTextName      : text,
      LogAlertSelectionName : selection,
    }, anonymous: anonymous);
  }

  void logHttpResponse(Http.Response response, {String requestMethod, String requestUrl, bool anonymous = true}) {
    Map<String, dynamic> httpResponseEvent = {
      LogEventName                    : LogHttpResponseEventName,
      LogHttpRequestUrlName           : requestUrl,
      LogHttpRequestMethodName        : requestMethod,
      LogHttpResponseCodeName         : response?.statusCode
    };
    logEvent(httpResponseEvent, anonymous: anonymous);
  }

  void logMapRoute({String action, Map<String, dynamic> params}) {
    
    logEvent({
      LogEventName             : LogMapRouteEventName,
      LogMapRouteAction        : action,
      LogMapRouteOrigin        : params['origin'],
      LogMapRouteDestination   : params['destination'],
      LogMapRouteLocation      : params['location'],
    });
  }

  void logMapShow() {
    logMapDisplay(action: LogMapDisplayShowActionName);
  }

  void logMapHide() {
    logMapDisplay(action: LogMapDisplayHideActionName);
  }

  void logMapDisplay({String action}) {
    
    logEvent({
      LogEventName             : LogMapDisplayEventName,
      LogMapDisplayAction      : action
    });
  }

  void logIlliniCash({String action, Map<String, dynamic> attributes}) {
    Map<String, dynamic> event = {
      LogEventName           : LogIllniCashEventName,
      LogIllniCashAction     : action,
    };
    if (attributes != null) {
      event.addAll(attributes);
    }
    logEvent(event);
  }

  void logAuth({String action, bool result, Map<String, dynamic> attributes}) {
    Map<String, dynamic> event = {
      LogEventName           : LogAuthEventName,
      LogAuthAction          : action,
    };
    if (result != null) {
      event[LogAuthResult] = result;
    }
    if (attributes != null) {
      event.addAll(attributes);
    }
    logEvent(event);
  }

  void logDocumentScan({String type, bool result, Map<String, dynamic> attributes, bool anonymous = true}) {
    Map<String, dynamic> event = {
      LogEventName             : LogDocumentScanEventName,
      LogDocumentScanType      : type,
      LogDocumentScanResult    : result,
    };
    if (attributes != null) {
      event.addAll(attributes);
    }
    logEvent(event, anonymous: anonymous);
  }

  void logHealth({String action, String status, String prevStatus, Map<String, dynamic> attributes, List<String> defaultAttributes = HealthAttributes, bool anonymous = true }) {
    Map<String, dynamic> event = {
      LogEventName            : LogHealthEventName,
      LogHealthActionName     : action,
    };
    if (status != null) {
      event[LogHealthStatusName] = status;
    }
    if (prevStatus != null) {
      event[LogHealthPrevStatusName] = prevStatus;
    }
    if (attributes != null) {
      event.addAll(attributes);
    }
    logEvent(event, defaultAttributes: defaultAttributes, anonymous: anonymous);
  }
}


abstract class AnalyticsPageName {
  String get analyticsPageName;
}

abstract class AnalyticsPageAttributes {
  Map<String, dynamic> get analyticsPageAttributes;
}

abstract class AnalyticsPageAnonymous {
  bool get analyticsPageAnonymous {
    return true;
  }
}
