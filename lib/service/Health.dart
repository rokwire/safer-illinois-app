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
import 'dart:io';

import 'package:flutter/material.dart';
//TMP: import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/BluetoothServices.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Exposure.dart';
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
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import "package:pointycastle/export.dart";

class Health with Service implements NotificationsListener {

  static const String notifyCountyChanged           = "edu.illinois.rokwire.health.county.changed";
  static const String notifyStatusChanged           = "edu.illinois.rokwire.health.status.changed";
  static const String notifyStatusUpdated           = "edu.illinois.rokwire.health.status.updated";
  static const String notifyHistoryUpdated          = "edu.illinois.rokwire.health.history.updated";
  static const String notifyUserUpdated             = "edu.illinois.rokwire.health.user.updated";
  static const String notifyUserPrivateKeyUpdated   = "edu.illinois.rokwire.health.user.private_key.updated";
  
  static const String notifyProcessingFinished      = "edu.illinois.rokwire.health.processing.finished";
  
  static const String _historyFileName              = "history.json";

  HealthUser _user;
  PrivateKey _userPrivateKey;
  PublicKey  _servicePublicKey;

  String   _currentCountyId;
  DateTime _pausedDateTime;

  File     _historyCacheFile;
  List<Covid19History> _historyCache;
  Map<String, HealthRulesSet> _rulesCache;
  Map<String, Map<String, dynamic>> _accessRulesCache;

  bool _processing;

  // Singletone Instance

  static final Health _instance = Health._internal();

  factory Health() {
    return _instance;
  }

  Health._internal() {
    _rulesCache = Map<String, HealthRulesSet>();
    _accessRulesCache =  Map<String, Map<String, dynamic>>();
  }



  // Service

  @override
  void createService() {
    NotificationService().subscribe(this, [
      AppLivecycle.notifyStateChanged,
      Auth.notifyLoginChanged,
      Config.notifyConfigChanged,
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {
    _currentCountyId = await _loadCurrentCountyId();
    _user = _loadUserFromStorage();
    _servicePublicKey = RsaKeyHelper.parsePublicKeyFromPem(Config().healthPublicKey);
    _userPrivateKey = await _rsaUserPrivateKey;
    _historyCacheFile = await _getHistoryCacheFile();
    _historyCache = await _loadHistoryCache();
    _refreshUser();
  }

  @override
  void initServiceUI() {
    _process();
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
  }

  void _onAppLivecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
    }
    else if (state == AppLifecycleState.resumed) {
      if (_pausedDateTime != null) {
        Duration pausedDuration = DateTime.now().difference(_pausedDateTime);
        if (Config().refreshTimeout < pausedDuration.inSeconds) {
          _refreshUser().then((_) {
            _process();
          });
        }
      }
    }
  }

  void _onUserLoginChanged() {

    if (this._isAuthenticated) {
      _refreshRSAPrivateKey().then((_) {
        _refreshUser().then((_) {
          _process();
        });
      });
    }
    else {
      _lastCovid19Status = null;
      _healthUserPrivateKey = null;
      _healthUser = null;

      _clearHistoryCache();
      
      NotificationService().notify(notifyStatusChanged, null);
      NotificationService().notify(notifyHistoryUpdated, null);
      // NotificationService().notify(notifyUserUpdated, null); 
      // NotificationService().notify(notifyUserPrivateKeyUpdated, null); 
    }
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
        _applyLastCovid19Status(status);
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
        _applyLastCovid19Status(status);
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

  Future<File> _getHistoryCacheFile() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String cacheFilePath = join(appDocDir.path, _historyFileName);
    return File(cacheFilePath);
  }

  Future<List<Covid19History>> _loadHistoryCache() async {
     if (this._isLoggedIn && (_historyCacheFile != null)) {
      String cachedString = await _historyCacheFile.exists() ? await _historyCacheFile.readAsString() : null;
      List<dynamic> cachedJson = (cachedString != null) ? AppJson.decodeList(cachedString) : null;
      return (cachedJson != null) ? await Covid19History.listFromJson(cachedJson, _decryptHistoryKeys) : null;
     }
     return null;
  }

  Future<void> _clearHistoryCache() async {
    _historyCache = null;
    if (await _historyCacheFile.exists()) {
      try { await _historyCacheFile.delete(); } catch (e) { print(e?.toString()); }
    }
  }

  Future<List<Covid19History>> loadCovid19History({bool force}) async {
    if (this._isLoggedIn) {
      if ((_historyCache != null) && (force != true)) {
        return _historyCache;
      }
      else {
        String url = "${Config().healthUrl}/covid19/v2/histories";
        Response response = await Network().get(url, auth: NetworkAuth.User);
        String responseString = (response?.statusCode == 200) ? response.body : null;
        List<dynamic> responseJson = (responseString != null) ? AppJson.decodeList(responseString) : null;
        List<Covid19History> result = (responseJson != null) ? await Covid19History.listFromJson(responseJson, _decryptHistoryKeys) : null;
        if (result != null) {
          _historyCache = result;
          try { await _historyCacheFile?.writeAsString(responseString, flush: true); } catch (e) { print(e?.toString()); }
          return result;
        }
      }
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
      if (response?.statusCode == 200) {
        await _clearHistoryCache();
        return await Covid19History.decryptedFromJson(AppJson.decode(response.body), _decryptHistoryKeys);
      }
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
      if (response?.statusCode == 200) {
        await _clearHistoryCache();
        return await Covid19History.decryptedFromJson(AppJson.decode(response.body), _decryptHistoryKeys);
      }
    }
    return null;
  }

  Future<bool> _clearCovid19History() async {
    if (this._isAuthenticated) {
      String url = "${Config().healthUrl}/covid19/v2/histories";
      Response response = await Network().delete(url, auth: NetworkAuth.User);
      if (response?.statusCode == 200) {
        await _clearHistoryCache();
        return true;
      }
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
    HealthRulesSet rules = await _loadRules2();
    return rules?.symptoms?.groups;
    /*
    String url = "${Config().healthUrl}/covid19/symptoms";
    String appVersion = AppVersion.majorVersion(Config().appVersion, 2);
    Response response = await Network().get(url, auth: NetworkAuth.App, headers: { Network.RokwireVersion : appVersion });
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseBody != null) ? AppJson.decodeList(responseBody) : null;
    return (responseJson != null) ? HealthSymptomsGroup.listFromJson(responseJson) : null;
    */
  }

  // Network API: HealthCounty

  Future<String> _loadCurrentCountyId() async {
    String currentCountyId = Storage().currentHealthCountyId;
    if (currentCountyId == null) {
      List<HealthCounty> counties = await loadCounties();
      currentCountyId = HealthCounty.defaultCounty(counties)?.id;
      if (currentCountyId != null) {
        Storage().currentHealthCountyId = currentCountyId;
      }
    }
    return currentCountyId;
  }

  Future<bool> _ensureCurrentCountyId() async {
    if (_currentCountyId == null) {
      _currentCountyId = await _loadCurrentCountyId();
      if (_currentCountyId != null) {
        return true;
      }
    }
    return false;
  }

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

  bool get processing {
    return _processing;
  }

  Future<_ProcessResult> _process({bool ensureStatus}) async {
    
    if (!this._isLoggedIn || (_processing == true)) {
      return null;
    }
    _processing = true;

    bool countyChanged = false, statusChanged = false, historyUpdated = false;

    // 1. Ensure county
    if (await _ensureCurrentCountyId()) {
      countyChanged = true;
    }

    // 2. Check for pending CTests
    List<Covid19Event> events = await _processPendingEvents();
    if ((events != null) && (0 < events.length)) {
      historyUpdated = true;
    }

    // 3. Load history
    List<Covid19History> histories = await loadCovid19History(force: true);
    
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
    if ((currentStatus == null) && (ensureStatus == true)) {
      currentStatus = await _loadCovid19Status();
    }
    
    // 5. Log processed events
    _logProcessedEvents(events: events, status: newHealthStatus, prevStatus: lastHealthStatus);

    // 6. Fnish & Notify
    _processing = null;
    
    _ProcessResult result = _ProcessResult(status: currentStatus, history: histories);
    NotificationService().notify(notifyProcessingFinished, result);

    if (countyChanged) {
      NotificationService().notify(notifyCountyChanged, null);
    }

    if (statusChanged) {
      NotificationService().notify(notifyStatusChanged, currentStatus);
    }

    if (historyUpdated) {
      NotificationService().notify(notifyHistoryUpdated, histories);
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

    return result;
  }

  Future<Covid19Status> get currentCountyStatus async {
    _ProcessResult processResult = await _process(ensureStatus: true);
    return processResult?.status;
  }

  Future<List<Covid19History>> loadUpdatedHistory() async {
    _ProcessResult processResult = await _process();
    return processResult?.history;
  }

  Future<Covid19Status> updateStatusFromHistory() async {
    
    if (!this._isLoggedIn) {
      return null;
    }

    bool countyChanged = false, statusChanged = false;

    // 1. Ensure county
    if (await _ensureCurrentCountyId()) {
      countyChanged = true;
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

    List<Future<dynamic>> futures = <Future>[
      _loadRules2(countyId: countyId, force: true),
      _loadUserTestMonitorInterval()
    ];
    if (histories == null) {
      futures.add(loadCovid19History(force: true));
    }
    List<dynamic> results = await Future.wait(futures);

    HealthRulesSet rules = ((results != null) && (0 < results.length)) ? results[0] : null;
    if (rules == null) {
      return null;
    }

    dynamic userTestMonitorInterval = ((results != null) && (1 < results.length)) ? results[1] : false;
    if (userTestMonitorInterval == false) {
      return null;
    }
    else if (userTestMonitorInterval is int) {
      rules.userTestMonitorInterval = userTestMonitorInterval;
    }

    if (histories == null) {
      histories = ((results != null) && (2 < results.length)) ? results[2] : null;
      if (histories == null) {
        return null;
      }
    }

    Covid19Status status;
    HealthRuleStatus defaultStatus = rules?.defaults?.status?.eval(history: histories, historyIndex: -1, rules: rules);
    if (defaultStatus != null) {
      status = Covid19Status(
        dateUtc: null,
        blob: Covid19StatusBlob(
          healthStatus: defaultStatus.healthStatus,
          priority: defaultStatus.priority,
          nextStep: defaultStatus.nextStep,
          nextStepHtml: defaultStatus.nextStepHtml,
          nextStepDateUtc: null,
          eventExplanation: defaultStatus.eventExplanation,
          eventExplanationHtml: defaultStatus.eventExplanationHtml,
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

        HealthRuleStatus historyStatus;
        if (history.isTest && history.canTestUpdateStatus) {
          if (rules.tests != null) {
            HealthTestRuleResult testRuleResult = rules.tests.matchRuleResult(blob: history?.blob, rules: rules);
            historyStatus = testRuleResult?.status?.eval(history: histories, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
          
        }
        else if (history.isSymptoms) {
          if (rules.symptoms != null) {
            HealthSymptomsRule symptomsRule = rules.symptoms.matchRule(blob: history?.blob, rules: rules);
            historyStatus = symptomsRule?.status?.eval(history: histories, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
        }
        else if (history.isContactTrace) {
          if (rules.contactTrace != null) {
            HealthContactTraceRule contactTraceRule = rules.contactTrace.matchRule(blob: history?.blob, rules: rules);
            historyStatus = contactTraceRule?.status?.eval(history: histories, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
        }
        else if (history.isAction) {
          if (rules.actions != null) {
            HealthActionRule actionRule = rules.actions.matchRule(blob: history?.blob, rules: rules);
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
              nextStepDateUtc: ((historyStatus.nextStepInterval != null) || (historyStatus.nextStep != null) || (historyStatus.nextStepHtml != null) || (historyStatus.healthStatus != null)) ? historyStatus.nextStepDateUtc(history.dateUtc, rules: rules) : status.blob.nextStepDateUtc,
              eventExplanation: ((historyStatus.eventExplanation != null) || (historyStatus.eventExplanationHtml != null) || (historyStatus.healthStatus != null)) ? historyStatus.eventExplanation : status.blob.eventExplanation,
              eventExplanationHtml: ((historyStatus.eventExplanation != null) || (historyStatus.eventExplanationHtml != null) || (historyStatus.healthStatus != null)) ? historyStatus.eventExplanationHtml : status.blob.eventExplanationHtml,
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
    Storage().lastHealthCovid19Status = healthStatus;
  }

  void _applyLastCovid19Status(Covid19Status status) {
    String oldStatus = _lastCovid19Status;
    String newStatus = status?.blob?.healthStatus;
    if (covid19HealthStatusIsValid(newStatus) && (oldStatus != newStatus)) {
      _lastCovid19Status = newStatus;

      Analytics().logHealth(
        action: Analytics.LogHealthStatusChangedAction,
        status: newStatus,
        prevStatus: oldStatus
      );

    }
    _applyBuildingAccessFromStatus(status: status);
    _updateExposureReportTarget(status: status);
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

    List<Covid19Event> events = await loadCovid19Events(processed: false);
    if (events != null) {
      if (0 < events.length) {
        List<Covid19History> histories = await loadCovid19History();
        if (histories != null) {
          List<Covid19Event> result = List<Covid19Event>();
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
          return result;
        }
      }
    }
    return null;
  }

  void _logProcessedEvents({List<Covid19Event> events, String status, String prevStatus}) {
    if (events != null) {
      int exposureTestReportDays = Config().settings['covid19ExposureTestReportDays'];
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
          
          if (exposureTestReportDays != null) {
            DateTime maxDateUtc = event?.blob?.dateUtc;
            DateTime minDateUtc = maxDateUtc?.subtract(Duration(days: exposureTestReportDays));
            if ((maxDateUtc != null) && (minDateUtc != null)) {
              Covid19History contactTrace = Covid19History.mostRecentContactTrace(_historyCache, minDateUtc: minDateUtc, maxDateUtc: maxDateUtc);
              if (contactTrace != null) {
                Analytics().logHealth(
                  action: Analytics.LogHealthContactTraceTestAction,
                  status: status,
                  prevStatus: prevStatus,
                  attributes: {
                    Analytics.LogHealthExposureTimestampName: contactTrace.dateUtc?.toIso8601String(),
                    Analytics.LogHealthDurationName: contactTrace.blob?.traceDuration,
                    Analytics.LogHealthProviderName: event.provider,
                    Analytics.LogHealthTestTypeName: event.blob?.testType,
                    Analytics.LogHealthTestResultName: event.blob?.testResult,
                });
              }
            }
          }
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
      DateTime lastOsfTestDateUtc = Storage().lastHealthCovid19OsfTestDateUtc;
      DateTime latestOsfTestDateUtc;

      for (Covid19OSFTest osfTest in osfTests) {
        if ((testTypeSet != null && testTypeSet.contains(osfTest.testType)) && osfTest.dateUtc != null && (lastOsfTestDateUtc == null || lastOsfTestDateUtc.isBefore(osfTest.dateUtc))) {
          Covid19History testHistory = await _applyOsfTestHistory(osfTest);
          if (testHistory != null) {
            processed.add(osfTest);
            if ((latestOsfTestDateUtc == null) || latestOsfTestDateUtc.isBefore(osfTest.dateUtc)) {
              latestOsfTestDateUtc = osfTest.dateUtc;
            }
          }
        }
      }
      if (latestOsfTestDateUtc != null) {
        Storage().lastHealthCovid19OsfTestDateUtc = latestOsfTestDateUtc;
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

  // User Test Monitor Interval

  Future<dynamic> loadUserTestMonitorInterval() async {
    return await _loadUserTestMonitorInterval();
  }

  Future<dynamic> _loadUserTestMonitorInterval() async {
    if (this._isLoggedIn) {
      String url = "${Config().healthUrl}/covid19/uin-override";
      Response response = await Network().get(url, auth: NetworkAuth.User);
      if (response?.statusCode == 200) {
        Map<String, dynamic> responseJson = AppJson.decodeMap(response.body);
        return (responseJson != null) ? responseJson['interval'] : null;
      }
      return false;
    }
    return null;
  }

  // Consolidated Rules
  Future<HealthRulesSet> loadRules2({String countyId, bool force}) async {
    return await _loadRules2(countyId: countyId, force: force);
  }

  Future<HealthRulesSet> _loadRules2({String countyId, bool force}) async {
    HealthRulesSet rules;
    if (countyId == null) {
      countyId = _currentCountyId;
    }
    if (countyId != null) {
      rules = (force != true) ? _rulesCache[countyId] : null;
      if (rules == null) {
        Map<String, dynamic> rulesJson = await _loadRules2Json(countyId: countyId);
        rules = (rulesJson != null) ? HealthRulesSet.fromJson(rulesJson) : null;
        if (rules != null) {
          _rulesCache[countyId] = rules;
        }
      }
    }
    return rules;
  }

  Future<Map<String, dynamic>> loadRules2Json({String countyId}) async {
    return await _loadRules2Json(countyId: countyId);
  }

  Future<Map<String, dynamic>> _loadRules2Json({String countyId}) async {
    String appVersion = AppVersion.majorVersion(Config().appVersion, 2);
    String url = "${Config().healthUrl}/covid19/crules/county/$countyId";
    Response response = await Network().get(url, auth: NetworkAuth.App, headers: { Network.RokwireVersion : appVersion });
    String responseString = (response?.statusCode == 200) ? response.body : null;
//TMP: String responseString = await rootBundle.loadString('assets/sample.health.rules.json');
    return (responseString != null) ? AppJson.decodeMap(responseString) : null;
  }

  // Building Access

  Future<Map<String, dynamic>> _loadBuildingAccessRules({String countyId, bool force}) async {

    Map<String, dynamic> accessRules;
    if (countyId != null) {
      accessRules = (force != true) ? _accessRulesCache[countyId] : null;
      if (accessRules == null) {
        String url = "${Config().healthUrl}/covid19/access-rules/county/$countyId";
        Response response = await Network().get(url, auth: NetworkAuth.App);
        String responseBody = (response?.statusCode == 200) ? response.body : null;
        accessRules = (responseBody != null) ? AppJson.decodeMap(responseBody) : null; 
        if (accessRules != null) {
          _accessRulesCache[countyId] = accessRules;
        }
      }
    }

    return accessRules;
  }

  Future<bool> isBuildingAccessGranted(String healthStatus) async {
    Map<String, dynamic> accessRules = await _loadBuildingAccessRules(countyId: _currentCountyId, force: true);
    return (accessRules != null) && (accessRules[healthStatus] == kCovid19AccessGranted);
  }

  Future<void> _applyBuildingAccessFromStatus({Covid19Status status}) async {
    if (Config().settings['covid19ReportBuildingAccess'] == true) {
      Map<String, dynamic> accessRules = await _loadBuildingAccessRules(countyId: _currentCountyId);
      if (accessRules != null) {
        String access = accessRules[status?.blob?.healthStatus];
        if (access != null) {
          await _logBuildingAccess(dateUtc: DateTime.now().toUtc(), access: access);
        }
      }
    }
  }

  Future<bool> _logBuildingAccess({DateTime dateUtc, String access}) async {
    String url = "${Config().healthUrl}/covid19/building-access";
    String post = AppJson.encode({
      'date': healthDateTimeToString(dateUtc),
      'access': access
    });
    //Log.d("$post");
    Response response = await Network().put(url, body: post, auth: NetworkAuth.User);
    return (response?.statusCode == 200);
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
        _process();
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

      await _clearHistoryCache();

      Storage().currentHealthCountyId = _currentCountyId = null;
      Storage().lastHealthProvider = null;
      Storage().lastHealthCovid19Status = null;
      Storage().lastHealthCovid19OsfTestDateUtc = null;
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
    
class _ProcessResult {
  final Covid19Status status;
  final List<Covid19History> history;
  _ProcessResult({this.status, this.history});
}