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

import 'package:flutter/material.dart';
//TMP:  import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/model/Health2.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/AppDateTime.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/BluetoothServices.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Exposure.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/LocationServices.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import "package:pointycastle/export.dart";

class Health with Service implements NotificationsListener {

  static const String notifyCountyChanged           = "edu.illinois.rokwire.health.county.changed";
  static const String notifyStatusChanged           = "edu.illinois.rokwire.health.status.changed";
  static const String notifyStatusUpdated           = "edu.illinois.rokwire.health.status.updated";
  static const String notifyHistoryUpdated          = "edu.illinois.rokwire.health.history.updated";
  static const String notifyUserUpdated             = "edu.illinois.rokwire.health.user.updated";
  static const String notifyUserPrivateKeyUpdated   = "edu.illinois.rokwire.health.user.private_key.updated";
  
  static const String notifyCountyStatusAvailable   = "edu.illinois.rokwire.health.county.status.available";
  static const String notifyUpdatedHistoryAvailable = "edu.illinois.rokwire.health.updated.history.available";
  
  static const String notifyHealthStatusChanged     = "edu.illinois.rokwire.health.health_status.changed";


  HealthUser _user;
  PrivateKey _userPrivateKey;
  PublicKey  _servicePublicKey;

  String   _currentCountyId;
  DateTime _pausedDateTime;

  bool _processingCountyStatus;
  bool _loadingUpdatedHistory;

  final int _rulesVersion = 2;

  // Singletone Instance

  static final Health _instance = Health._internal();

  factory Health() {
    return _instance;
  }

  Health._internal();



  // Service

  @override
  void createService() {
    NotificationService().subscribe(this, [
      AppLivecycle.notifyStateChanged,
      Auth.notifyLoginChanged,
      Config.notifyConfigChanged,
      FirebaseMessaging.notifyCovid19Action,
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {
    _currentCountyId = Storage().currentHealthCountyId;
    _user = _loadUserFromStorage();
    _servicePublicKey = RsaKeyHelper.parsePublicKeyFromPem(Config().healthPublicKey);
    _userPrivateKey = await _rsaUserPrivateKey;
    _refreshUser();
  }

  @override
  void initServiceUI() {
    this.currentCountyStatus;
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Storage(), Config(), User(), Auth(), NativeCommunicator()]);
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == AppLivecycle.notifyStateChanged) {
     _onAppLivecycleStateChanged(param); 
    }
    else if (name == Auth.notifyLoginChanged) {
      _onUserLoginChanged();
    }
    else if (name == Config.notifyConfigChanged) {
      _servicePublicKey = RsaKeyHelper.parsePublicKeyFromPem(Config().healthPublicKey);
    }
    else if (name == FirebaseMessaging.notifyCovid19Action) {
      processAction(param);
    }
  }

  void _onAppLivecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
    }
    else if (state == AppLifecycleState.resumed) {
      if (_pausedDateTime != null) {
        Duration pausedDuration = DateTime.now().difference(_pausedDateTime);
        if (Config().refreshTimeout < pausedDuration.inSeconds) {
          this.currentCountyStatus;
          _refreshUser();
        }
      }
    }
  }

  void _onUserLoginChanged() {

    if (this._isAuthenticated) {
      _refreshRSAPrivateKey().then((_) {
        _refreshUser().then((_) {
          this.currentCountyStatus;
        });
      });
    }
    else {
      _lastCovid19Status = null;
      _healthUserPrivateKey = null;
      _healthUser = null;
      
      NotificationService().notify(notifyStatusChanged, null);
      NotificationService().notify(notifyHistoryUpdated, null);
      // NotificationService().notify(notifyUserUpdated, null); 
      // NotificationService().notify(notifyUserPrivateKeyUpdated, null); 
    }
  }

  // Network API: Covid19News, Covid19FAQ, Covid19Resource

  Future<List<Covid19News>> loadCovid19News() async {
    List<Covid19News> newsList;
    try {
      int limit = Config().settings['covid19NewsLimit'] ?? 10;
      String url = "${Config().healthUrl}/covid19/news?limit=$limit";
      Response response = await Network().get(url, auth: NetworkAuth.App);
      String responseString = ((response != null) && (response.statusCode == 200)) ? response.body : null;
      List<dynamic> responseList = AppJson.decode(responseString);
      if (responseList != null) {
        newsList = List();
        for (dynamic responseEntry in responseList) {
          newsList.add(Covid19News.fromJson(responseEntry));
        }
      }
    }
    catch(e) {
      print(e.toString());
    }
    return newsList;
  }

  Future<Covid19FAQ> loadCovid19FAQs() async {
    try {
      String url = "${Config().healthUrl}/covid19/faq";
      Response response = await Network().get(url, auth: NetworkAuth.App);
      String responseString = ((response != null) && (response.statusCode == 200)) ? response.body : null;
      Map<String, dynamic> responseJson = AppJson.decode(responseString);
      return (responseJson != null) ? Covid19FAQ.fromJson(responseJson) : null;
    }
    catch(e) {
      print(e.toString());
    }
    return null;
  }

  Future<List<Covid19Resource>> loadCovid19Resources() async {
    List<Covid19Resource> resourcesList;
    try {
      String url = "${Config().healthUrl}/covid19/resources";
      Response response = await Network().get(url, auth: NetworkAuth.App);
      String responseString = ((response != null) && (response.statusCode == 200)) ? response.body : null;
      List<dynamic> responseList = AppJson.decode(responseString);
      if (responseList != null) {
        resourcesList = List();
        for (dynamic responseEntry in responseList) {
          resourcesList.add(Covid19Resource.fromJson(responseEntry));
        }
      }
    }
    catch(e) {
      print(e.toString());
    }
    return resourcesList;
  }

  // Network API: Covid19Status

  Future<Covid19Status> loadCovid19Status() async {
    return _loadCovid19Status();
  }

  Future<Covid19Status> _loadCovid19Status() async {
    if (this._isLoggedIn) {
      String url = "${Config().healthUrl}/covid19/v2/app-version/2.2/statuses";
      Response response = await Network().get(url, auth: NetworkAuth.User);
      if (response?.statusCode == 200) {
        Covid19Status status = await Covid19Status.decryptedFromJson(AppJson.decodeMap(response.body), _userPrivateKey);
        _lastCovid19Status = status?.blob?.healthStatus;
        _updateExposureReportTarget(status: status);
        return status;
      }
    }
    return null;
  }

  Future<bool> _updateCovid19Status(Covid19Status status) async {
    if (this._isLoggedIn) {
      String url = "${Config().healthUrl}/covid19/v2/app-version/2.2/statuses";
      Covid19Status encryptedStatus = await status?.encrypted(_user?.publicKey);
      String post = AppJson.encode(encryptedStatus?.toJson());
      Response response = await Network().put(url, body: post, auth: NetworkAuth.User);
      if (response?.statusCode == 200) {
        _lastCovid19Status = status?.blob?.healthStatus;
        _updateExposureReportTarget(status: status);
        return true;
      }
    }
    return false;
  }

  Future<bool> _clearCovid19Status() async {
    if (this._isAuthenticated) {
      String url = "${Config().healthUrl}/covid19/v2/app-version/2.2/statuses";
      Response response = await Network().delete(url, auth: NetworkAuth.User);
      return response?.statusCode == 200;
    }
    return false;
  }

  // Network API: Covid19History

  Future<List<Covid19History>> loadCovid19History() async {
    if (this._isLoggedIn) {
      String url = "${Config().healthUrl}/covid19/v2/histories";
      Response response = await Network().get(url, auth: NetworkAuth.User);
      String responseString = (response?.statusCode == 200) ? response.body : null;
      List<dynamic> responseJson = (responseString != null) ? AppJson.decodeList(responseString) : null;
      return (responseJson != null) ? await Covid19History.listFromJson(responseJson, _decryptHistoryKeys) : null;
    }
    return null;
  }

  Future<Covid19History> addCovid19History({DateTime dateUtc, Covid19HistoryType type, Covid19HistoryBlob blob}) async {
    return this._isLoggedIn ? await _addCovid19History(await Covid19History.encryptedFromBlob(
      dateUtc: dateUtc,
      type: type,
      blob: blob,
      publicKey: _user?.publicKey
    )) : null;
  }

  Future<Covid19History> _addCovid19History(Covid19History history) async {
    if (this._isLoggedIn) {
      String url = "${Config().healthUrl}/covid19/v2/histories";
      String post = AppJson.encode(history?.toJson());
      Response response = await Network().post(url, body: post, auth: NetworkAuth.User);
      String responseString = (response?.statusCode == 200) ? response.body : null;
      return await Covid19History.decryptedFromJson(AppJson.decode(responseString), _decryptHistoryKeys);
    }
    return null;
  }

  Future<Covid19History> updateCovid19History({String id, String userId, DateTime dateUtc, Covid19HistoryType type, Covid19HistoryBlob blob}) async {
    return this._isLoggedIn ?  _updateCovid19History(await Covid19History.encryptedFromBlob(
      id: id,
      dateUtc: dateUtc,
      type: type,
      blob: blob,
      publicKey: _user?.publicKey
    )) : null;
  }

  Future<Covid19History> _updateCovid19History(Covid19History history) async {
    if (this._isLoggedIn) {
      String url = "${Config().healthUrl}/covid19/v2/histories/${history.id}";
      String post = AppJson.encode(history?.toJson());
      Response response = await Network().put(url, body: post, auth: NetworkAuth.User);
      String responseString = (response?.statusCode == 200) ? response.body : null;
      return await Covid19History.decryptedFromJson(AppJson.decode(responseString), _decryptHistoryKeys);
    }
    return null;
  }

  Future<bool> _clearCovid19History() async {
    if (this._isAuthenticated) {
      String url = "${Config().healthUrl}/covid19/v2/histories";
      Response response = await Network().delete(url, auth: NetworkAuth.User);
      return response?.statusCode == 200;
    }
    return false;
  }

  Map<Covid19HistoryType, PrivateKey> get _decryptHistoryKeys {
    return {
      Covid19HistoryType.test : _userPrivateKey,
      Covid19HistoryType.manualTestVerified : _userPrivateKey,
      Covid19HistoryType.manualTestNotVerified : null, // _servicePrivateKey NA
      Covid19HistoryType.symptoms : _userPrivateKey,
      Covid19HistoryType.contactTrace : _userPrivateKey,
      Covid19HistoryType.action : _userPrivateKey,

    };
  }

  // Network API: Covid19Event

  Future<List<Covid19Event>> loadCovid19Events({bool processed}) async {
    if (this._isLoggedIn) {
      String url = "${Config().healthUrl}/covid19/ctests";
      String params = "";
      if (processed != null) {
        if (0 < params.length) {
          params += "&";
        }
        params += "processed=$processed";
      }
      if (0 < params.length) {
        url += "?$params";
      }
      Response response = await Network().get(url, auth: NetworkAuth.User);
      String responseString = (response?.statusCode == 200) ? response.body : null;
      List<dynamic> responseJson = (responseString != null) ? AppJson.decodeList(responseString) : null;
      return (responseJson != null) ? await Covid19Event.listFromJson(responseJson, _userPrivateKey) : null;
    }
    return null;
  }

  Future<bool> clearCovid19Tests() async {
    if (this._isAuthenticated) {
      String url = "${Config().healthUrl}/covid19/ctests";
      Response response = await Network().delete(url, auth: NetworkAuth.User);
      return (response?.statusCode == 200);
    }
    return false;
  }

  // Network API: HealthServiceProvider

  Future<List<HealthServiceProvider>> loadHealthServiceProviders({String countyId}) async {
    String url = "${Config().healthUrl}/covid19/providers";

    if(countyId != null)
      url += "/county/$countyId";

    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseString = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseString != null) ? AppJson.decode(responseString) : null;
    return (responseJson != null) ? HealthServiceProvider.listFromJson(responseJson) : null;
  }

  Future<Map<String, List<HealthServiceProvider>>> loadHealthServiceProvidersForCounties(Set<String> countyIds) async {
    if (AppCollection.isCollectionEmpty(countyIds)) {
      return null;
    }
    String idsToString = countyIds.join(',');
    String url = "${Config().healthUrl}/covid19/providers?county-ids=$idsToString";
    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseString = (response?.statusCode == 200) ? response.body : null;
    Map<String, dynamic> responseJson = AppJson.decodeMap(responseString);
    if (responseJson == null) {
      return null;
    }
    Map<String, List<HealthServiceProvider>> countyProvidersMap = Map();
    for (String countyId in responseJson.keys) {
      dynamic providersJson = responseJson[countyId];
      List<HealthServiceProvider> providers = HealthServiceProvider.listFromJson(providersJson);
      countyProvidersMap[countyId] = providers;
    }
    return countyProvidersMap;
  }

  // Network API: HealthServiceLocation

  Future<List<HealthServiceLocation>> loadHealthServiceLocations({String countyId, String providerId})async{
    String url = "${Config().healthUrl}/covid19/locations";

    if(countyId != null)
      url += "?county-id=$countyId";
    if(providerId!=null)
      url += (countyId!=null ? "&":"?")+"provider-id=$providerId";

    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseString = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseString != null) ? AppJson.decode(responseString) : null;
    return (responseJson != null) ? HealthServiceLocation.listFromJson(responseJson) : null;
  }

  Future<HealthServiceLocation> loadHealthServiceLocation({String locationId})async{
    String url = "${Config().healthUrl}/covid19/locations";

    if(locationId!=null)
      url+= "/$locationId";

    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseString = (response?.statusCode == 200) ? response.body : null;
    Map<String,dynamic> responseJson = (responseString != null) ? AppJson.decode(responseString) : null;
    return (responseJson != null) ? HealthServiceLocation.fromJson(responseJson) : null;
  }

  // Network API: HealthTestType

  Future<List<HealthTestType>> loadHealthServiceTestTypes({List<String> typeIds})async{
    String url = "${Config().healthUrl}/covid19/test-types";

    if(typeIds?.isNotEmpty??false) {
      url += "?ids=";
      typeIds.forEach((id){
        url+="$id,";
      });
      url = url.substring(0,url.length-1);
    }
    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseString = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseString != null) ? AppJson.decode(responseString) : null;
    return (responseJson != null) ? HealthTestType.listFromJson(responseJson) : null;
  }

  // Network API: HealthSymptomsGroup

  Future<List<HealthSymptomsGroup>> loadSymptomsGroups() async {
    switch(_rulesVersion) {
      case 1:  return _loadSymptomsGroups1();
      case 2:  return _loadSymptomsGroups2();
      default: return null;
    }
  }

  Future<List<HealthSymptomsGroup>> _loadSymptomsGroups1() async {
    String url = "${Config().healthUrl}/covid19/symptom-groups";
    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseString = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseString != null) ? AppJson.decodeList(responseString) : null;
    return (responseJson != null) ? HealthSymptomsGroup.listFromJson(responseJson) : null;
  }

  Future<List<HealthSymptomsGroup>> _loadSymptomsGroups2() async {

    if (_currentCountyId != null) {
      HealthRulesSet2 rules = await _loadRules2(countyId: _currentCountyId);
      return rules?.symptoms?.groups;
    }
    else {
      String url = "${Config().health2Url}/symptoms/symptoms.json";
      Response response = await Network().get(url);
      String responseBody = (response?.statusCode == 200) ? response.body : null;
//TMP:String responseBody = await rootBundle.loadString('assets/sample.health.symptoms.json');
      List<dynamic> responseJson = (responseBody != null) ? AppJson.decodeList(responseBody) : null;
      return (responseJson != null) ? HealthSymptomsGroup.listFromJson(responseJson) : null;
    }
  }

  // Network API: HealthCounty

  Future<List<HealthCounty>> loadCounties({String name, String state, String country}) async{
    String url = "${Config().healthUrl}/covid19/counties";
    String params = '';
    if (name != null) {
      params += "${(0 < params.length) ? '&' : ''}name=$name";
    }
    if (state != null) {
      params += "${(0 < params.length) ? '&' : ''}state_province=$state";
    }
    if (country != null) {
      params += "${(0 < params.length) ? '&' : ''}country=$country";
    }
    if (0 < params.length) {
      url += "?$params";
    }

    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseBody != null) ? AppJson.decodeList(responseBody) : null;
    return (responseJson != null) ? HealthCounty.listFromJson(responseJson) : null;
  }

  // Current County

  String get currentCountyId {
    return _currentCountyId;
  }

  bool get processingCountyStatus {
    return _processingCountyStatus;
  }

  Future<Covid19Status> get currentCountyStatus async {
    
    if (!this._isLoggedIn) {
      return null;
    }
    
    if (_processingCountyStatus == true) {
      return null;
    }
    _processingCountyStatus = true;

    bool needStatusRebuild = false, countyChanged = false, statusChanged = false, historyUpdated = false;
    
    // 1. Ensure county
    if (_currentCountyId == null) {
      List<HealthCounty> counties = await loadCounties();
      _currentCountyId = HealthCounty.defaultCounty(counties)?.id;
      if (_currentCountyId != null) {
        needStatusRebuild = countyChanged = true;
      }
    }

    // 2. Check for pending CTests
    List<Covid19Event> events = await _processPendingEvents();
    if ((events != null) && (0 < events.length)) {
      needStatusRebuild = historyUpdated = true;
    }

    // 3. Check for cleared status
    Covid19Status currentStatus;
    if (!needStatusRebuild) {
      currentStatus = await _loadCovid19Status();
      if (currentStatus == null) {
        needStatusRebuild = true;
      }
    }

    // 4. Make sure we rebuild status at lease once daily
    int lastHealthStatusEvalDateMs = Storage().lastHealthStatusEval;
    DateTime lastHealthStatusDateEval = (lastHealthStatusEvalDateMs != null) ? DateTime.fromMillisecondsSinceEpoch(lastHealthStatusEvalDateMs, isUtc: false) : null;
    int difference = (lastHealthStatusDateEval != null) ? AppDateTime.todayMidnightLocal.difference(lastHealthStatusDateEval).inDays : null;
    if ((difference == null) || (0 < difference)) {
      needStatusRebuild = true;
    }
    
    // 5. Rebuild status if needed
    String lastHealthStatus = this._lastCovid19Status;
    String newHealthStatus = lastHealthStatus;
    if (needStatusRebuild && (_currentCountyId != null)) {
      currentStatus = await _statusForCounty(_currentCountyId);
      if (currentStatus != null) {
        if (await _updateCovid19Status(currentStatus)) {
          statusChanged = true;
        }
        if (covid19HealthStatusIsValid(currentStatus?.blob?.healthStatus)) {
          newHealthStatus = currentStatus?.blob?.healthStatus;
        }
      }
    } else if (currentStatus == null) {
      currentStatus = await _loadCovid19Status();
    }

    // 5. Log processed events
    _logProcessedEvents(events: events, status: newHealthStatus, prevStatus: lastHealthStatus);

    // 6. Notify
    _processingCountyStatus = null;
    NotificationService().notify(notifyCountyStatusAvailable, currentStatus);

    if (countyChanged) {
      NotificationService().notify(notifyCountyChanged, null);
    }

    if (statusChanged) {
      NotificationService().notify(notifyStatusChanged, currentStatus);
    }

    if (historyUpdated) {
      NotificationService().notify(notifyHistoryUpdated, null);
    }

    // 7. Check for status update
    if ((lastHealthStatus != null) && (lastHealthStatus != newHealthStatus)) {
      Timer(Duration(milliseconds: 100), () {
        NotificationService().notify(notifyStatusUpdated, {
          'lastHealthStatus': lastHealthStatus,
          'status': currentStatus,
        });
      });
    }

    return currentStatus;
  }

  Future<Covid19Status> updateStatusFromHistory() async {
    
    if (!this._isLoggedIn) {
      return null;
    }

    bool countyChanged = false, statusChanged = false;

    // 1. Ensure county
    if (_currentCountyId == null) {
      List<HealthCounty> counties = await loadCounties();
      _currentCountyId = HealthCounty.defaultCounty(counties)?.id;
      if (_currentCountyId != null) {
        countyChanged = true;
      }
    }


    // 2. Build the status
    Covid19Status currentStatus;
    String lastHealthStatus = this._lastCovid19Status;
    String newHealthStatus = lastHealthStatus;
    if (_currentCountyId != null) {
      currentStatus = await _statusForCounty(_currentCountyId);
      if (currentStatus != null) {
        if (await _updateCovid19Status(currentStatus)) {
          statusChanged = true;
        }
        if (covid19HealthStatusIsValid(currentStatus?.blob?.healthStatus)) {
          newHealthStatus = currentStatus?.blob?.healthStatus;
        }
      }
    }

    // 3. Notify
    if (countyChanged) {
      NotificationService().notify(notifyCountyChanged, null);
    }

    if (statusChanged) {
      NotificationService().notify(notifyStatusChanged, currentStatus);
    }

    // 4. Check for status update
    if ((lastHealthStatus != null)  && (lastHealthStatus != newHealthStatus)) {
      Timer(Duration(milliseconds: 100), () {
        NotificationService().notify(notifyStatusUpdated, {
          'lastHealthStatus': lastHealthStatus,
          'status': currentStatus,
        });
      });
    }

    return currentStatus;
  }

  bool get loadingUpdatedHistory {
    return _loadingUpdatedHistory;
  }

  Future<List<Covid19History>> loadUpdatedHistory() async {
    
    if (!this._isLoggedIn) {
      return null;
    }

    if (_loadingUpdatedHistory == true) {
      return null;
    }
    _loadingUpdatedHistory = true;
    
    bool countyChanged = false, statusChanged = false;
    
    // 1. Ensure county
    if (_currentCountyId == null) {
      List<HealthCounty> counties = await loadCounties();
      _currentCountyId = HealthCounty.defaultCounty(counties)?.id;
      if (_currentCountyId != null) {
        countyChanged = true;
      }
    }

    // 2. Check for pending CTests
    List<Covid19Event> events = await _processPendingEvents();

    // 3. Load history
    List<Covid19History> histories = await loadCovid19History();
    
    // 4. Rebuild status if we had been processed pending events
    Covid19Status currentStatus;
    String lastHealthStatus = this._lastCovid19Status;
    String newHealthStatus = lastHealthStatus;
    if ((histories != null) && (_currentCountyId != null)) {
      currentStatus = await _statusForCounty(_currentCountyId, histories: histories);
      if (currentStatus != null) {
        if (await _updateCovid19Status(currentStatus)) {
          statusChanged = true;
        }
        if (covid19HealthStatusIsValid(currentStatus?.blob?.healthStatus)) {
          newHealthStatus = currentStatus?.blob?.healthStatus;
        }
      }
    }
    
    // 5. Log processed events
    _logProcessedEvents(events: events, status: newHealthStatus, prevStatus: lastHealthStatus);

    // 6. Notify
    _loadingUpdatedHistory = null;
    NotificationService().notify(notifyUpdatedHistoryAvailable, histories);

    if (countyChanged) {
      NotificationService().notify(notifyCountyChanged, null);
    }

    if (statusChanged) {
      NotificationService().notify(notifyStatusChanged, currentStatus);
    }

    // 7. Check for status update
    if ((lastHealthStatus != null) && (lastHealthStatus != newHealthStatus)) {
      Timer(Duration(milliseconds: 100), () {
        NotificationService().notify(notifyStatusUpdated, {
          'lastHealthStatus': lastHealthStatus,
          'status': currentStatus,
        });
      });
    }

    return histories;
  }

  Future<Covid19Status> switchCounty(String countyId) async {
    Covid19Status status;
    if ((countyId != null) && (_currentCountyId != countyId)) {
      status = await _updateStatusForCounty(countyId);
      Storage().currentHealthCountyId = _currentCountyId = countyId;
      NotificationService().notify(notifyCountyChanged, null);
    }
    return status;
  }

  Future<Covid19Status> _updateStatusForCounty(String countyId) async {
    Covid19Status status = await _statusForCounty(countyId);
    if (status != null) {
      if (await _updateCovid19Status(status)) {
        NotificationService().notify(notifyStatusChanged, status);
        return status;
      }
    }
    return null;
  }

  Future<Covid19Status> _statusForCounty(String countyId, { List<Covid19History> histories }) async {
    switch(_rulesVersion) {
      case 1:  return _statusForCounty1(countyId, histories: histories);
      case 2:  return _statusForCounty2(countyId, histories: histories);
      default: return null;
    }
  }

  Future<Covid19Status> _statusForCounty1(String countyId, { List<Covid19History> histories }) async {
    
    if (histories == null) {
      histories = await loadCovid19History();
      if (histories == null) {
        return null;
      }
    }

    Covid19Status status = Covid19Status(
      dateUtc: DateTime.now().toUtc(),
      blob: Covid19StatusBlob(
        healthStatus: kCovid19HealthStatusOrange,
        nextStep: Localization().getStringEx('model.covid19.step.initial', 'Take a SHIELD Saliva Test when you return to campus.'),
        historyBlob: null,
      ),
    );

    List<HealthTestRule> testRules;
    HealthSymptomsRule symptomsRule;
    List<HealthSymptomsGroup> symptomsGroups;
    List<HealthContactTraceRule> traceRules;

    // Start from older
    DateTime nowUtc = DateTime.now().toUtc();
    for (int index = histories.length - 1; 0 <= index; index--) {
      Covid19History history = histories[index];
      if ((history.dateUtc != null) && history.dateUtc.isBefore(nowUtc)) {
        if (history.isTest && history.canTestUpdateStatus) {
          if (testRules == null) {
            testRules = await _loadTestRules(countyId: countyId);
          }
          if (testRules != null) {
            HealthTestRuleResult testRuleResult = HealthTestRule.matchResult(testRules, testType: history?.blob?.testType, testResult: history?.blob?.testResult);
            if (testRuleResult != null) {
              bool resultHasStatus = covid19HealthStatusIsValid(testRuleResult.healthStatus);
              status = Covid19Status(
                dateUtc: history.dateUtc,
                blob: Covid19StatusBlob(
                  healthStatus: resultHasStatus ? testRuleResult.healthStatus : status.blob.healthStatus,
                  nextStep: ((testRuleResult.nextStep != null) || resultHasStatus) ? testRuleResult.nextStep: status.blob.nextStep,
                  nextStepDateUtc: testRuleResult?.nextStepDate(history.dateUtc),
                  historyBlob: history.blob,
                ),
              );
            }
          }
        }
        else if (history.isSymptoms) {
          if (symptomsGroups == null) {
            symptomsGroups = await loadSymptomsGroups();
          }
          if (symptomsRule == null) {
            symptomsRule = await _loadSymptomsRule(countyId: countyId);
          }
          Map<String, int> symptomsCounts = HealthSymptomsGroup.getCounts(symptomsGroups, history?.blob?.symptomsIds);
          if ((symptomsRule != null) && (symptomsCounts != null)) {
            HealthSymptomsRuleResult symptomsRuleResult = symptomsRule.matchResult(symptomsCounts);
            if (symptomsRuleResult != null) {
              bool resultHasStatus = covid19HealthStatusIsValid(symptomsRuleResult.healthStatus);
              status = Covid19Status(
                dateUtc: history.dateUtc,
                blob: Covid19StatusBlob(
                  healthStatus: resultHasStatus ? symptomsRuleResult.healthStatus : status.blob.healthStatus,
                  nextStep: ((symptomsRuleResult.nextStep != null) || resultHasStatus) ? symptomsRuleResult.nextStep : status.blob.nextStep,
                  historyBlob: history.blob,
                ),
              );
            }
          }
        }
        else if (history.isContactTrace) {
          if (traceRules == null) {
            traceRules = await _loadContactTraceRules();
          }
          if (traceRules != null) {
            HealthContactTraceRuleResult traceRuleResult = HealthContactTraceRule.matchResult(traceRules, traceDate: history.dateUtc, traceDuration: history.blob?.traceDurationInMinutes);
            if (traceRuleResult != null) {
              bool resultHasStatus = covid19HealthStatusIsValid(traceRuleResult.healthStatus);
              status = Covid19Status(
                dateUtc: history.dateUtc,
                blob: Covid19StatusBlob(
                  healthStatus: resultHasStatus ? traceRuleResult.healthStatus : status.blob.healthStatus,
                  nextStep: ((traceRuleResult.nextStep != null) || resultHasStatus) ? traceRuleResult.nextStep : status.blob.nextStep,
                  historyBlob: history.blob,
                ),
              );
            }
          }
        }
      }
    }
    
    return status;
  }

  Future<Covid19Status> _statusForCounty2(String countyId, { List<Covid19History> histories }) async {

    if (histories == null) {
      histories = await loadCovid19History();
      if (histories == null) {
        return null;
      }
    }

    HealthRulesSet2 rules = await _loadRules2(countyId: countyId);
    if (rules == null) {
      return null;
    }

    
    Covid19Status status;
    HealthRuleStatus2 defaultStatus = rules?.defaults?.status?.eval(history: histories, historyIndex: -1, rules: rules);
    if (defaultStatus != null) {
      status = Covid19Status(
        dateUtc: null,
        blob: Covid19StatusBlob(
          healthStatus: defaultStatus.healthStatus,
          priority: defaultStatus.priority,
          nextStep: defaultStatus.nextStep,
          nextStepHtml: defaultStatus.nextStepHtml,
          nextStepDateUtc: null,
          reason: defaultStatus.reason,
          warning: defaultStatus.warning,
          historyBlob: null,
        ),
      );
    }
    else {
      return null;
    }

    // Start from older
    DateTime nowUtc = DateTime.now().toUtc();
    for (int index = histories.length - 1; 0 <= index; index--) {

      Covid19History history = histories[index];
      if ((history.dateUtc != null) && history.dateUtc.isBefore(nowUtc)) {

        HealthRuleStatus2 historyStatus;
        if (history.isTest && history.canTestUpdateStatus) {
          if (rules.tests != null) {
            HealthTestRuleResult2 testRuleResult = rules.tests.matchRuleResult(blob: history?.blob);
            historyStatus = testRuleResult?.status?.eval(history: histories, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
          
        }
        else if (history.isSymptoms) {
          if (rules.symptoms != null) {
            HealthSymptomsRule2 symptomsRule = rules.symptoms.matchRule(blob: history?.blob);
            historyStatus = symptomsRule?.status?.eval(history: histories, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
        }
        else if (history.isContactTrace) {
          if (rules.contactTrace != null) {
            HealthContactTraceRule2 contactTraceRule = rules.contactTrace.matchRule(blob: history?.blob);
            historyStatus = contactTraceRule?.status?.eval(history: histories, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
        }
        else if (history.isAction) {
          if (rules.actions != null) {
            HealthActionRule2 actionRule = rules.actions.matchRule(blob: history?.blob);
            historyStatus = actionRule?.status?.eval(history: histories, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
        }

        if ((historyStatus != null) && historyStatus.canUpdateStatus(blob: status.blob)) {
          status = Covid19Status(
            dateUtc: history.dateUtc,
            blob: Covid19StatusBlob(
              healthStatus: (historyStatus.healthStatus != null) ? historyStatus.healthStatus : status.blob.healthStatus,
              priority: (historyStatus.priority != null) ? historyStatus.priority.abs() : status.blob.priority,
              nextStep: ((historyStatus.nextStep != null) || (historyStatus.nextStepHtml != null) || (historyStatus.healthStatus != null)) ? historyStatus.nextStep : status.blob.nextStep,
              nextStepHtml: ((historyStatus.nextStep != null) || (historyStatus.nextStepHtml != null) || (historyStatus.healthStatus != null)) ? historyStatus.nextStepHtml : status.blob.nextStepHtml,
              nextStepDateUtc: ((historyStatus.nextStepInterval != null) || (historyStatus.healthStatus != null)) ? historyStatus.nextStepDateUtc(history.dateUtc) : status.blob.nextStepDateUtc,
              reason: ((historyStatus.reason != null) || (historyStatus.healthStatus != null)) ? historyStatus.reason: status.blob.reason,
              warning: ((historyStatus.warning != null) || (historyStatus.healthStatus != null)) ? historyStatus.warning: status.blob.warning,
              historyBlob: history.blob,
            ),
          );
        }
      }
    }

    Storage().lastHealthStatusEval = AppDateTime.todayMidnightLocal.millisecondsSinceEpoch;

    return status;
  }

  String get lastCovid19Status {
    return (this._isLoggedIn) ? Storage().lastHealthCovid19Status : null;
  }

  String get _lastCovid19Status {
    return Storage().lastHealthCovid19Status;
  }

  set _lastCovid19Status(String healthStatus) {
    if (covid19HealthStatusIsValid(healthStatus) && (healthStatus != _lastCovid19Status)) {
      Analytics().logHealth(
        action: Analytics.LogHealthStatusChangedAction,
        status: healthStatus,
        prevStatus: lastCovid19Status
      );
      Storage().lastHealthCovid19Status = healthStatus;
      NotificationService().notify(notifyHealthStatusChanged, null);
    }
  }

  void _updateExposureReportTarget({Covid19Status status}) {
    if ((status != null) && (status.blob != null) &&
        (status.blob.healthStatus == kCovid19HealthStatusRed) &&
        /*(status.blob.historyBlob != null) && status.blob.historyBlob.isTest && */
        (status.dateUtc != null))
    {
      Exposure().reportTargetTimestamp = status.dateUtc.millisecondsSinceEpoch;
    }
  }

  // WaitingOnTable processing

  Future<List<Covid19Event>> _processPendingEvents() async {

    List<Covid19Event> result;
    List<Covid19Event> events = await loadCovid19Events(processed: false);
    if (events != null) {
      result = List<Covid19Event>();
      if (0 < events.length) {
        List<Covid19History> histories = await loadCovid19History();
        if (histories != null) {
          for (Covid19Event event in events) {
            if (Covid19History.listContainsEvent(histories, event)) {
              // mark it as processed without duplicating the histyr entry
              await _markEventAsProcessed(event);
            }
            else {
              // add history entry and mark as processed
              Covid19History eventHistory = await _applyEventHistory(event);
              if (eventHistory != null) {
                await _markEventAsProcessed(event);
                result.add(event);
              }
            }
          }
        }
      }
    }
    return result;
  }

  void _logProcessedEvents({List<Covid19Event> events, String status, String prevStatus}) {
    if (events != null) {
      for (Covid19Event event in events) {
        if (event.isTest) {
          Analytics().logHealth(
            action: Analytics.LogHealthProviderTestProcessedAction,
            status: status,
            prevStatus: prevStatus,
            attributes: {
              Analytics.LogHealthProviderName: event.provider,
              Analytics.LogHealthTestTypeName: event.blob?.testType,
              Analytics.LogHealthTestResultName: event.blob?.testResult,
          });
        }
        else if (event.isAction) {
          Analytics().logHealth(
            action: Analytics.LogHealthActionProcessedAction,
            status: status,
            prevStatus: prevStatus,
            attributes: {
              Analytics.LogHealthActionTypeName: event.blob?.actionType,
              Analytics.LogHealthActionTextName: event.blob?.actionText,
          });
        }
      }
    }
  }

  Future<int> processOsfTests({List<Covid19OSFTest> osfTests}) async {

    List<HealthTestType> testTypes = await loadHealthServiceTestTypes();
    Set<String> testTypeSet = testTypes != null ? testTypes.map((entry) => entry.name).toSet() : null;
    if (osfTests != null) {
      List<Covid19OSFTest> processed = List<Covid19OSFTest>();
      DateTime lastOsfTestDate = Storage().lastHealthCovid19OsfTestDate;
      DateTime latestOsfTestDate;

      for (Covid19OSFTest osfTest in osfTests) {
        if ((testTypeSet != null && testTypeSet.contains(osfTest.testType)) && osfTest.dateUtc != null && (lastOsfTestDate == null || lastOsfTestDate.isBefore(osfTest.dateUtc))) {
          Covid19History testHistory = await _applyOsfTestHistory(osfTest);
          if (testHistory != null) {
            processed.add(osfTest);
            if ((latestOsfTestDate == null) || latestOsfTestDate.isBefore(osfTest.dateUtc)) {
              latestOsfTestDate = osfTest.dateUtc;
            }
          }
        }
      }
      if (latestOsfTestDate != null) {
        Storage().lastHealthCovid19OsfTestDate = latestOsfTestDate;
      }

      if (0 < processed.length) {
        NotificationService().notify(notifyHistoryUpdated, null);

        String lastHealthStatus = this._lastCovid19Status;
        String newHealthStatus = lastHealthStatus;
        Covid19Status status = await updateStatusFromHistory();
        if (covid19HealthStatusIsValid(status?.blob?.healthStatus)) {
          newHealthStatus = status?.blob?.healthStatus;
        }

        for (Covid19OSFTest osfTest in processed) {
          Analytics().logHealth(
              action: Analytics.LogHealthProviderTestProcessedAction,
              status: newHealthStatus,
              prevStatus: lastHealthStatus,
              attributes: {
                Analytics.LogHealthProviderName: osfTest.provider,
                Analytics.LogHealthTestTypeName: osfTest.testType,
                Analytics.LogHealthTestResultName: osfTest.testResult,
              });
        }
      }
      return processed.length;
    }
    return 0;
  }
  
  Future<bool> processManualTest(Covid19ManualTest test) async {
    if (test != null) {
      Covid19History manualHistory = await _applyManualTestHistory(test);
      if (manualHistory != null) {
        Analytics().logHealth(
          action: Analytics.LogHealthManualTestSubmittedAction,
          attributes: {
            Analytics.LogHealthProviderName: test.provider,
            Analytics.LogHealthLocationName: test.location,
            Analytics.LogHealthTestTypeName: test.testType,
            Analytics.LogHealthTestResultName: test.testResult,
        });
        NotificationService().notify(notifyHistoryUpdated, null);
        return true;
      }
    }
    return false;
  }

  Future<Covid19History> _applyEventHistory(Covid19Event event) async {
    if (event.isTest) {
      return await _addCovid19History(await Covid19History.encryptedFromBlob(
        dateUtc: event?.blob?.dateUtc,
        type: Covid19HistoryType.test,
        blob: Covid19HistoryBlob(
          provider: event?.provider,
          providerId: event?.providerId,
          testType: event?.blob?.testType,
          testResult: event?.blob?.testResult,
        ),
        publicKey: _user?.publicKey
      ));
    }
    else if (event.isAction) {
      return await _addCovid19History(await Covid19History.encryptedFromBlob(
        dateUtc: event?.blob?.dateUtc,
        type: Covid19HistoryType.action,
        blob: Covid19HistoryBlob(
          actionType: event?.blob?.actionType,
          actionText: event?.blob?.actionText,
        ),
        publicKey: _user?.publicKey
      ));
    }
    else {
      return null;
    }
  }

  Future<Covid19History> _applyOsfTestHistory(Covid19OSFTest test) async {
    return await _addCovid19History(await Covid19History.encryptedFromBlob(
      dateUtc: test?.dateUtc,
      type: Covid19HistoryType.test,
      blob: Covid19HistoryBlob(
        provider: test?.provider,
        providerId: test?.providerId,
        testType: test?.testType,
        testResult: test?.testResult,
      ),
      publicKey: _user?.publicKey
    ));
  }

  Future<Covid19History> _applyManualTestHistory(Covid19ManualTest test) async {
    return await _addCovid19History(await Covid19History.encryptedFromBlob(
      dateUtc: test?.dateUtc,
      type: Covid19HistoryType.manualTestNotVerified,
      blob: Covid19HistoryBlob(
        provider: test?.provider,
        providerId: test?.providerId,
        location: test?.location,
        locationId: test?.locationId,
        countyId: test?.countyId,
        testType: test?.testType,
        testResult: test?.testResult,
      ),
      locationId: test?.locationId,
      countyId: test?.countyId,
      image: test?.image,

      publicKey: _servicePublicKey,
    ));
  }

  Future<List<HealthTestRule>> _loadTestRules({String countyId}) async {
    String url = "${Config().healthUrl}/covid19/rules/county/$countyId";
    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseBody != null) ? AppJson.decodeList(responseBody) : null; 
    return (responseJson != null) ? HealthTestRule.listFromJson(responseJson) : null;
  }

  Future<bool> _markEventAsProcessed(Covid19Event event) async {
    String url = "${Config().healthUrl}/covid19/ctests/${event.id}";
    String post = AppJson.encode({'processed':true});
    Response response = await Network().put(url, body:post, auth: NetworkAuth.User);
    if (response?.statusCode == 200) {
      return true;
    }
    else {
      Log.e('Health Service: Unable to mark covid test as processed');
      return false;
    }
  }

  // Symptoms processing

  Future<dynamic> processSymptoms({List<HealthSymptomsGroup> groups, Set<String> selected, DateTime dateUtc}) async {

    List<HealthSymptom> symptoms = HealthSymptomsGroup.getSymptoms(groups, selected);
    Covid19History history = await _applySymptomsHistory(symptoms, dateUtc: dateUtc ?? DateTime.now().toUtc());
    if (history != null) {
      NotificationService().notify(notifyHistoryUpdated, null);

      String lastHealthStatus = this._lastCovid19Status;
      String newHealthStatus = lastHealthStatus;
      Covid19Status status = await updateStatusFromHistory();
      if (covid19HealthStatusIsValid(status?.blob?.healthStatus)) {
        newHealthStatus = status?.blob?.healthStatus;
      }

      List<String> analyticsSymptoms = [];
      symptoms?.forEach((HealthSymptom symptom) { analyticsSymptoms.add(symptom?.name); });
      Analytics().logHealth(
        action: Analytics.LogHealthSymptomsSubmittedAction,
        status: newHealthStatus,
        prevStatus: lastHealthStatus,
        attributes: {
          Analytics.LogHealthSymptomsName: analyticsSymptoms
      });

      // Check for status update
      if ((lastHealthStatus != null) && (lastHealthStatus != newHealthStatus)) {
        return status; // Succeeded, Status updated
      }
      else {
        return history; // Succeeded
      }
    }
    return null; // Failed
  }

  Future<Covid19History> _applySymptomsHistory(List<HealthSymptom> symptoms, { DateTime dateUtc }) async {
    return await _addCovid19History(await Covid19History.encryptedFromBlob(
      dateUtc: dateUtc,
      type: Covid19HistoryType.symptoms,
      blob: Covid19HistoryBlob(
        symptoms: symptoms,
      ),
      publicKey: _user?.publicKey
    ));
  }
  
  Future<HealthSymptomsRule> _loadSymptomsRule({String countyId}) async {
    String url = "${Config().healthUrl}/covid19/symptom-rules/county/$countyId";
    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    Map<String, dynamic> responseJson = (responseBody != null) ? AppJson.decodeMap(responseBody) : null; 
    return (responseJson != null) ? HealthSymptomsRule.fromJson(responseJson) : null;
  }

  // Contact Trace processing

  // Used only from debug panel, see Exposure.checkExposures
  Future<bool> processContactTrace({DateTime dateUtc, int duration}) async {
    
    Covid19History history = await _addCovid19History(await Covid19History.encryptedFromBlob(
      dateUtc: dateUtc,
      type: Covid19HistoryType.contactTrace,
      blob: Covid19HistoryBlob(
        traceDuration: duration,
      ),
      publicKey: _user?.publicKey
    ));

    if (history != null) {
      NotificationService().notify(notifyHistoryUpdated, null);

      String lastHealthStatus = this._lastCovid19Status;
      String newHealthStatus = lastHealthStatus;
      Covid19Status status = await updateStatusFromHistory();
      if (covid19HealthStatusIsValid(status?.blob?.healthStatus)) {
        newHealthStatus = status?.blob?.healthStatus;
      }
      
      Analytics().logHealth(
        action: Analytics.LogHealthContactTraceProcessedAction,
        status: newHealthStatus,
        prevStatus: lastHealthStatus,
        attributes: {
          Analytics.LogHealthDurationName: duration,
          Analytics.LogHealthExposureTimestampName: dateUtc?.toIso8601String(),
      });

      return true;
    }
    return false;
  }

  Future<List<HealthContactTraceRule>> _loadContactTraceRules({String countyId}) async {
    String url = "https://rokwire-ios-beta.s3.us-east-2.amazonaws.com/Assets/covid19_contact_trace_rules.json";
    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseBody != null) ? AppJson.decodeList(responseBody) : null; 
    return (responseJson != null) ? HealthContactTraceRule.listFromJson(responseJson) : null;
  }

  // Actions processing

  Future<bool> processAction(Map<String, dynamic> action) async {
   /*action = {
      "type": "health.covid19.action",
      "health.covid19.action.date": "2020-07-30T21:23:47Z",
      "health.covid19.action.type": "require-test-48",
      "health.covid19.action.text": "You must take a COVID-19 test in next 48 hours",
    }*/

    if (action != null) {
      DateTime dateUtc = healthDateTimeFromString(AppJson.stringValue(action['health.covid19.action.date']));
      if (dateUtc == null) {
        dateUtc = DateTime.now().toUtc();
      }
      String actionType = AppJson.stringValue(action['health.covid19.action.type']);
      String actionText = AppJson.stringValue(action['health.covid19.action.text']);
      
      if ((actionType != null) || (actionText != null)) {
        Covid19History history = await _addCovid19History(await Covid19History.encryptedFromBlob(
          dateUtc: dateUtc,
          type: Covid19HistoryType.action,
          blob: Covid19HistoryBlob(
            actionType: actionType,
            actionText: actionText,
          ),
          publicKey: _user?.publicKey
        ));

        if (history != null) {
          NotificationService().notify(notifyHistoryUpdated, null);

          String lastHealthStatus = this._lastCovid19Status;
          String newHealthStatus = lastHealthStatus;
          Covid19Status status = await updateStatusFromHistory();
          if (covid19HealthStatusIsValid(status?.blob?.healthStatus)) {
            newHealthStatus = status?.blob?.healthStatus;
          }
          
          Analytics().logHealth(
            action: Analytics.LogHealthActionProcessedAction,
            status: newHealthStatus,
            prevStatus: lastHealthStatus,
            attributes: {
              Analytics.LogHealthActionTypeName: actionType,
              Analytics.LogHealthActionTextName: actionText,
              Analytics.LogHealthActionTimestampName: dateUtc?.toIso8601String(),
          });

          return true;
        }
      }
    }
    return false;
  }

  // Consolidated Rules

  Future<HealthRulesSet2> _loadRules2({String countyId}) async {
    String url = "${Config().health2Url}/rules/county/$countyId/rules.json";
    Response response = await Network().get(url);
    String responseBody = (response?.statusCode == 200) ? response.body : null;
//TMP:String responseBody = await rootBundle.loadString('assets/sample.health.rules.json');
    Map<String, dynamic> responseJson = (responseBody != null) ? AppJson.decodeMap(responseBody) : null;
    return (responseJson != null) ? HealthRulesSet2.fromJson(responseJson) : null;
  }

  // Access Rules

  Future<Map<String, dynamic>> _loadAccessRules({String countyId}) async {
    String url = "${Config().healthUrl}/covid19/access-rules/county/$countyId";
    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    return (responseBody != null) ? AppJson.decodeMap(responseBody) : null; 
  }

  Future<bool> isAccessGranted(String healthStatus) async {
    Map<String, dynamic> accessRules = await _loadAccessRules(countyId: _currentCountyId);
    return (accessRules != null) && (accessRules[healthStatus] == kCovid19AccessGranted);
  }


  // Health User

  bool get _isAuthenticated {
    return (Auth().authToken?.idToken != null);
  }

  bool get _isLoggedIn {
    return this._isAuthenticated && (_user?.publicKey != null) && (_userPrivateKey != null);
  }

  String get _userId {
    return Auth().authInfo?.uin ?? Auth().phoneToken?.phone;
  }

  bool get isUserLoggedIn {
    return this._isLoggedIn;
  }

  Future<HealthUser> loginUser({bool consent, bool exposureNotification, AsymmetricKeyPair<PublicKey, PrivateKey> keys}) async {

    if (!this._isAuthenticated) {
      return null;
    }

    HealthUser user;
    try {
      user = await _loadUser();
    }
    catch (e) {
      print(e?.toString());
      return null; // Load user request failed -> login failed
    }

    bool userUpdated;
    if (user == null) {
      // User had not logged in -> create new user
      user = HealthUser(uuid: User().uuid);
      userUpdated = true;
    }
    
    // Always update user info.
    String userInfo = AppString.isStringNotEmpty(Auth().authInfo?.fullName) ? Auth().authInfo.fullName : Auth().phoneToken?.phone;
    await user.encryptBlob(HealthUserBlob(info: userInfo), _servicePublicKey);
    // update user info only if we have something to set
    // userUpdated = true;

    // User RSA keys
    if ((user.publicKeyString == null) || (keys != null)) {
      if (keys == null) {
        keys = await RsaKeyHelper.computeRSAKeyPair(RsaKeyHelper.getSecureRandom());
      }
      if (keys != null) {
        user.publicKeyString = RsaKeyHelper.encodePublicKeyToPemPKCS1(keys.publicKey);
        userUpdated = true;
      }
      else {
        return null; // unable to generate RSA key pair
      }
    }
    
    // Consent
    Map<String, dynamic> analyticsSettingsAttributes = {}; 
    if (consent != null) {
      if (consent != user.consent) {
        analyticsSettingsAttributes[Analytics.LogHealthSettingConsentName] = consent;
        user.consent = consent;
        userUpdated = true;
      }
    }
    
    // Exposure Notification
    if (exposureNotification != null) {
      if (exposureNotification != user.exposureNotification) {
        analyticsSettingsAttributes[Analytics.LogHealthSettingNotifyExposuresName] = exposureNotification;
        user.exposureNotification = exposureNotification;
        userUpdated = true;
      }
    }

    // Save
    if (userUpdated == true) {
      bool userSaved = await _saveUser(user);
      if (!userSaved){
        return null;
      }
    }

    if (analyticsSettingsAttributes != null) {
      Analytics().logHealth( action: Analytics.LogHealthSettingChangedAction, attributes: analyticsSettingsAttributes, defaultAttributes: Analytics.DefaultAttributes);
    }

    if (keys?.privateKey != null) {
      if (!await setUserRSAPrivateKey(keys.privateKey)) {
        return null;
      }
    }

    if (exposureNotification == true) {
      if (await LocationServices().status == LocationServicesStatus.PermissionNotDetermined) {
        await LocationServices().requestPermission();
      }

      if (BluetoothServices().status == BluetoothStatus.PermissionNotDetermined) {
        await BluetoothServices().requestStatus();
      }
    }
    
    return user;
  }

  Future<void> repostHealthHistory() async{
    HealthUser user = await _loadUser();
    user.repost = true;
    await _saveUser(user);
  }

  Future<PrivateKey> loadRSAPrivateKey() async {
    return _rsaUserPrivateKey;
  }

  Future<bool> setUserRSAPrivateKey(PrivateKey privateKey) async {
    if (_userId != null) {
      bool result;
      if (privateKey != null) {
        String privateKeyString = RsaKeyHelper.encodePrivateKeyToPemPKCS1(privateKey);
        result = await NativeCommunicator().setHealthRSAPrivateKey(userId: _userId, value: privateKeyString);
      }
      else {
        result = await NativeCommunicator().removeHealthRSAPrivateKey(userId: _userId);
      }
      if (result == true) {
        _healthUserPrivateKey = privateKey;
        this.currentCountyStatus;
        return true;
      }
    }
    return false;
  }

  Future<PrivateKey> get _rsaUserPrivateKey async {
    String privateKeyString = (_userId != null) ? await NativeCommunicator().getHealthRSAPrivateKey(userId: _userId) : null;
    return (privateKeyString != null) ? RsaKeyHelper.parsePrivateKeyFromPem(privateKeyString) : null;
  }

  set _healthUserPrivateKey(PrivateKey value) {
    if (_userPrivateKey != value) {
      _userPrivateKey = value;
      NotificationService().notify(notifyUserPrivateKeyUpdated);
    }
  }

  Future<void> _refreshRSAPrivateKey() async {
    _healthUserPrivateKey = await _rsaUserPrivateKey;
  }

  Future<PublicKey> loadRSAPublicKey() async {
    try {
      HealthUser user = await _loadUser();
      return user?.publicKey;
    } catch(e){
      print(e?.toString());
      return null;
    }
  }

  Future<AsymmetricKeyPair<PublicKey, PrivateKey>> refreshRSAKeys() async {
    AsymmetricKeyPair<PublicKey, PrivateKey> keys = await RsaKeyHelper.computeRSAKeyPair(RsaKeyHelper.getSecureRandom());

    HealthUser user = await loginUser(keys: keys);
    if(user != null){
      await clearUserData(); // The old history is useless
      return keys;
    }

    return null; // Failure - keep the old keys
  }
  
  Future<HealthUser> loadUser() async {
    try { return await _loadUser(); }
    catch (e) { print(e?.toString()); }
    return null;
  }

  Future<HealthUser> _loadUser() async {
    if (this._isAuthenticated) {
      String url = "${Config().healthUrl}/covid19/user";
      Response response = await Network().get(url, auth: NetworkAuth.User);
      if (response?.statusCode == 200) {
        HealthUser user = HealthUser.fromJson(AppJson.decodeMap(response.body)); // Return user or null if does not exist for sure.
        _healthUser = user;
        return user;
      }
      throw Exception("${response?.statusCode ?? '000'} ${response?.body ?? 'Unknown error occured'}");
    }
    throw Exception("User not logged in");
  }

  Future<bool> _saveUser(HealthUser user) async {
    if (this._isAuthenticated) {
      String url = "${Config().healthUrl}/covid19/login";
      String post = AppJson.encode(user?.toJson());
      Response response = await Network().post(url, body: post, auth: NetworkAuth.User);
      if ((response != null) && (response.statusCode == 200)) {
        _healthUser = user;
        return true;
      }
    }
    return false;
  }

  Future<bool> _clearUser() async {
    if (this._isAuthenticated) {
      String url = "${Config().healthUrl}/covid19/user/clear";
      Response response = await Network().get(url, auth: NetworkAuth.User);
      return response?.statusCode == 200;
    }
    return false;
  }

  Future<void> _refreshUser() async {
    try { await _loadUser(); }
    catch (e) { print(e?.toString()); }
  }

  set _healthUser(HealthUser user) {
    if (_user != user) {
      _saveUserToStorage(_user = HealthUser.fromUser(user));
      NotificationService().notify(notifyUserUpdated, null);
    }
  }

  static HealthUser _loadUserFromStorage() {
    return HealthUser.fromJson(AppJson.decode(Storage().healthUser));
  }

  static void _saveUserToStorage(HealthUser user) {
    Storage().healthUser = AppJson.encode(user?.toJson());
  }

  HealthUser get healthUser {
    return this._isLoggedIn ? _user : null;
  }

  bool get userExposureNotification {
    return this._isLoggedIn ? ( _user?.exposureNotification ?? false) : false;
  }

  bool get userConsent {
    return this._isLoggedIn ? (_user?.consent ?? false) : false;
  }

  PublicKey get userPublicKey {
    return this._isLoggedIn ? _user?.publicKey : null;
  }

  Future<bool> deleteUser() async {
    if (await _clearUser()) {
      NativeCommunicator().removeHealthRSAPrivateKey(userId: _userId);

      Storage().currentHealthCountyId = _currentCountyId = null;
      Storage().lastHealthProvider = null;
      Storage().lastHealthCovid19Status = null;
      Storage().lastHealthCovid19OsfTestDate = null;
      _healthUserPrivateKey = null;
      _healthUser = null;

      NotificationService().notify(notifyCountyChanged, null);
      NotificationService().notify(notifyStatusChanged, null);
      NotificationService().notify(notifyHistoryUpdated, null);
      NotificationService().notify(notifyUserUpdated, null);

      return true;
    }
    return false;
  }

  Future<bool> clearUserData() async {
    if (await _clearCovid19History()) {
      Covid19Status status = await updateStatusFromHistory();
      // Notify after status update, loadUpdatedHistory can triger anoher status rebuild
      NotificationService().notify(notifyHistoryUpdated, null);
      if (status == null) {
        _clearCovid19Status();
      }
      return true;
    }
    return false;
  }
}
    
