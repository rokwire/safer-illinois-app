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
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/BluetoothServices.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/LocationServices.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import "package:pointycastle/export.dart";

class Health2 with Service implements NotificationsListener {

  static const String notifyUserUpdated                = "edu.illinois.rokwire.health.user.updated";
  static const String notifyStatusChanged              = "edu.illinois.rokwire.health.status.changed";
  static const String notifyHistoryChanged             = "edu.illinois.rokwire.health.history.changed";
  static const String notifyCountyChanged              = "edu.illinois.rokwire.health.county.changed";
  static const String notifyRulesChanged               = "edu.illinois.rokwire.health.rules.changed";
  static const String notifyBuildingAccessRulesChanged = "edu.illinois.rokwire.health.building_access_rules.changed";

  static const String _rulesFileName                   = "rules.json";
  static const String _historyFileName                 = "history.json";

  HealthUser _user;
  PrivateKey _userPrivateKey;
  PublicKey  _servicePublicKey;

  Covid19Status _status;
  List<Covid19History> _history;
  
  HealthCounty _county;
  HealthRulesSet _rules;
  Map<String, dynamic> _buildingAccessRules;

  Directory _appDocumentsDir;
  DateTime _pausedDateTime;

  // Singletone Instance

  static final Health2 _instance = Health2._internal();

  factory Health2() {
    return _instance;
  }

  Health2._internal();

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
    _appDocumentsDir = await getApplicationDocumentsDirectory();
    _servicePublicKey = RsaKeyHelper.parsePublicKeyFromPem(Config().healthPublicKey);

    _user = _loadUserFromStorage();
    _userPrivateKey = await _loadUserPrivateKey();

    _status = _loadStatusFromStorage();
    _history = await _loadHistoryFromCache();

    _county = await _ensureCounty();
    _rules = await _loadRulesFromCache();
    _buildingAccessRules = _loadBuildingAccessRulesFromStorage();

    _refreshAll();
  }

  @override
  Future<void> clearService() async {
    _user = null;
    _userPrivateKey = null;
    _servicePublicKey = null;

    _status = null;
    _history = null;

    _county = null;
    _rules = null;
    _buildingAccessRules = null;
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Storage(), Config(), UserProfile(), Auth(), NativeCommunicator()]);
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
          _refreshAll();
        }
      }
    }
  }

  Future<void> _onUserLoginChanged() async {

    if (this._isAuthenticated) {
      _refreshUserData();
    }
    else {
      _userPrivateKey = null;
      _clearUser();
      _clearStatus();
      _clearHistory();
    }
  }

  Future<void> _refreshAll() async {

    await Future.wait([
      _refreshUser(),
      _refreshStatus(),
      _refreshHistory(),
      
      _refreshCounty(),
      _refreshRules(),
      _refreshBuildingAccessRules(),
    ]);
  }

  Future<void> _refreshUserData() async {

    // Update private key first because other services bellow depend on it
    await _refreshUserPrivateKey();

    await Future.wait([
      _refreshUser(),
      _refreshStatus(),
      _refreshHistory(),
    ]);
  }

  // Health User

  bool get _isAuthenticated {
    return (Auth().authToken?.idToken != null);
  }

  bool get _isReadAuthenticated {
    return this._isAuthenticated && (_userPrivateKey != null);
  }

  /*bool get _isWriteAuthenticated {
    return this._isAuthenticated && (_user?.publicKey != null);
  }*/

  bool get isLoggedIn {
    return this._isAuthenticated && (_user != null);
  }

  String get _userId {
    if (Auth().isShibbolethLoggedIn) {
      return Auth().authUser?.uin;
    }
    else if (Auth().isPhoneLoggedIn) {
      return Auth().phoneToken?.phone;
    }
    else {
      return null;
    }
  }

  Future<HealthUser> _loadUser() async {
    if (this._isAuthenticated && (Config().healthUrl != null)) {
      String url =  "${Config().healthUrl}/covid19/user";
      Response response = await Network().get(url, auth: NetworkAuth.User);
      if (response?.statusCode == 200) {
        HealthUser user = HealthUser.fromJson(AppJson.decodeMap(response.body)); // Return user or null if does not exist for sure.
        return user;
      }
      throw Exception("${response?.statusCode ?? '000'} ${response?.body ?? 'Unknown error occured'}");
    }
    throw Exception("User not logged in");
  }

  Future<bool> _saveUser(HealthUser user) async {
    if (this._isAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/login";
      String post = AppJson.encode(user?.toJson());
      Response response = await Network().post(url, body: post, auth: NetworkAuth.User);
      if ((response != null) && (response.statusCode == 200)) {
        return true;
      }
    }
    return false;
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

    bool userReset;
    bool userUpdated;
    if (user == null) {
      // User had not logged in -> create new user
      user = HealthUser(uuid: UserProfile().uuid);
      userUpdated = userReset = true;
    }
    
    // Always update user info.
    String userInfo = AppString.isStringNotEmpty(Auth().authUser?.fullName) ? Auth().authUser.fullName : Auth().phoneToken?.phone;
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
        userUpdated = userReset = true;
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
      if (userSaved) {
        _applyUser(user);
      }
      else {
        return null;
      } 
    }

    if (keys?.privateKey != null) {
      if (await _saveUserPrivateKey(keys.privateKey)) {
        _userPrivateKey = keys.privateKey;
      }
      else {
        return null;
      }
    }

    if (analyticsSettingsAttributes != null) {
      Analytics().logHealth( action: Analytics.LogHealthSettingChangedAction, attributes: analyticsSettingsAttributes, defaultAttributes: Analytics.DefaultAttributes);
    }

    if (exposureNotification == true) {
      if (await LocationServices().status == LocationServicesStatus.PermissionNotDetermined) {
        await LocationServices().requestPermission();
      }

      if (BluetoothServices().status == BluetoothStatus.PermissionNotDetermined) {
        await BluetoothServices().requestStatus();
      }
    }

    if (userReset) {
      _refreshUserData();
    }
    
    return user;
  }

  Future<void> _refreshUser() async {
    try { _applyUser(await _loadUser()); }
    catch (e) { print(e?.toString()); }
  }

  void _clearUser() {
    _applyUser(null);
  }

  void _applyUser(HealthUser user) {
    if (_user != user) {
      _saveUserToStorage(_user = user);
      NotificationService().notify(notifyUserUpdated);
    }
  }

  static HealthUser _loadUserFromStorage() {
    return HealthUser.fromJson(AppJson.decodeMap(Storage().healthUser));
  }

  static void _saveUserToStorage(HealthUser user) {
    Storage().healthUser = AppJson.encode(user?.toJson());
  }

  // User RSA keys

  Future<void> _refreshUserPrivateKey() async {
    _userPrivateKey = await _loadUserPrivateKey();
  }

  Future<PrivateKey> _loadUserPrivateKey() async {
    String privateKeyString = (_userId != null) ? await NativeCommunicator().getHealthRSAPrivateKey(userId: _userId) : null;
    return (privateKeyString != null) ? RsaKeyHelper.parsePrivateKeyFromPem(privateKeyString) : null;
  }

  Future<bool> _saveUserPrivateKey(PrivateKey privateKey) async {
    bool result;
    if (_userId != null) {
      if (privateKey != null) {
        String privateKeyString = RsaKeyHelper.encodePrivateKeyToPemPKCS1(privateKey);
        result = await NativeCommunicator().setHealthRSAPrivateKey(userId: _userId, value: privateKeyString);
      }
      else {
        result = await NativeCommunicator().removeHealthRSAPrivateKey(userId: _userId);
      }
    }
    return result;
  }

  // User Status

  Future<Covid19Status> _loadStatus() async {
    if (this._isReadAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/v2/app-version/2.2/statuses";
      Response response = await Network().get(url, auth: NetworkAuth.User);
      if (response?.statusCode == 200) {
        return await Covid19Status.decryptedFromJson(AppJson.decodeMap(response.body), _userPrivateKey);
      }
    }
    return null;
  }

  /*Future<bool> _saveStatus(Covid19Status status) async {
    if (this._isWriteAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/v2/app-version/2.2/statuses";
      Covid19Status encryptedStatus = await status?.encrypted(_user?.publicKey);
      String post = AppJson.encode(encryptedStatus?.toJson());
      Response response = await Network().put(url, body: post, auth: NetworkAuth.User);
      if (response?.statusCode == 200) {
        return true;
      }
    }
    return false;
  }*/

  /*Future<bool> _clearStatus() async {
    if (this._isAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/v2/app-version/2.2/statuses";
      Response response = await Network().delete(url, auth: NetworkAuth.User);
      return response?.statusCode == 200;
    }
    return false;
  }*/

  Future<void> _refreshStatus () async {
    Covid19Status status = await _loadStatus();
    if (status != null) {
      _applyStatus(status);
    }
  }

  void _clearStatus () {
    _applyStatus(null);
  }

  void _applyStatus(Covid19Status status) {
    if (_status != status) {
      String oldStatusCode = _status?.blob?.healthStatus;
      String newStatusCode = status?.blob?.healthStatus;
      if ((oldStatusCode != null) && (newStatusCode != null) && (oldStatusCode != newStatusCode)) {
        Analytics().logHealth(
          action: Analytics.LogHealthStatusChangedAction,
          status: newStatusCode,
          prevStatus: oldStatusCode
        );
      }

      _saveStatusToStorage(_status = status);
      NotificationService().notify(notifyStatusChanged);
    }
  }

  static Covid19Status _loadStatusFromStorage() {
    return Covid19Status.fromJson(AppJson.decodeMap(Storage().healthUserStatus));
  }

  static void _saveStatusToStorage(Covid19Status status) {
    Storage().healthUserStatus = AppJson.encode(status?.toJson());
  }

  // User History

  Future<void> _refreshHistory() async {
    String historyJsonString = await _loadHistoryJsonStringFromNet();
    List<Covid19History> history = await Covid19History.listFromJson(AppJson.decodeList(historyJsonString), _historyPrivateKeys);
    
    if ((history != null) && !ListEquality().equals(history, _history)) {
      _history = history;
      await _saveHistoryJsonStringToCache(historyJsonString);
      NotificationService().notify(notifyHistoryChanged);
    }
  }

  Future<void> _clearHistory() async {
    if (_history != null) {
      _history = null;
      await _clearHistoryCache();
      NotificationService().notify(notifyHistoryChanged);
    }
  }

  Future<String> _loadHistoryJsonStringFromNet() async {
    String url = (Config().healthUrl != null) ? "${Config().healthUrl}/covid19/v2/histories" : null;
    Response response = (url != null) ? await Network().get(url, auth: NetworkAuth.User) : null;
    return (response?.statusCode == 200) ? response.body : null;
  }

  Map<Covid19HistoryType, PrivateKey> get _historyPrivateKeys {
    return {
      Covid19HistoryType.test : _userPrivateKey,
      Covid19HistoryType.manualTestVerified : _userPrivateKey,
      Covid19HistoryType.manualTestNotVerified : null, // unencrypted
      Covid19HistoryType.symptoms : _userPrivateKey,
      Covid19HistoryType.contactTrace : _userPrivateKey,
      Covid19HistoryType.action : _userPrivateKey,
    };
  }

  File _getHistoryCacheFile() {
    String cacheFilePath = (_appDocumentsDir != null) ? join(_appDocumentsDir.path, _historyFileName) : null;
    return (cacheFilePath != null) ? File(cacheFilePath) : null;
  }

  Future<List<Covid19History>> _loadHistoryFromCache() async {
    return await Covid19History.listFromJson(AppJson.decodeList(await _loadHistoryJsonStringFromCache()), _historyPrivateKeys);
  }

  Future<String> _loadHistoryJsonStringFromCache() async {
    File cacheFile = _getHistoryCacheFile();
    try { return ((cacheFile != null) && await cacheFile.exists()) ? await cacheFile.readAsString() : null; } catch (e) { print(e?.toString()); }
    return null;
  }

  Future<void> _saveHistoryJsonStringToCache(String jsonString) async {
    File cacheFile = _getHistoryCacheFile();
    if (cacheFile != null) {
      try { await cacheFile.writeAsString(jsonString); } catch (e) { print(e?.toString()); }
    }
  }

  Future<void> _clearHistoryCache() async {
    File cacheFile = _getHistoryCacheFile();
    try {
      if ((cacheFile != null) && await cacheFile.exists()) {
        await cacheFile.delete();
      }
    }
    catch (e) { print(e?.toString()); }
  }

  // Counties

  Future<List<HealthCounty>> loadCounties({ bool guidelines }) async {
    String url = (Config().healthUrl != null) ? "${Config().healthUrl}/covid19/counties" : null;
    Response response = (url != null) ? await Network().get(url, auth: NetworkAuth.App) : null;
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseBody != null) ? AppJson.decodeList(responseBody) : null;
    return (responseJson != null) ? HealthCounty.listFromJson(responseJson, guidelines: guidelines) : null;
  }

  Future<HealthCounty> _loadCounty({String countyId, bool guidelines }) async {
    String url = ((countyId != null) && (Config().healthUrl != null)) ? "${Config().healthUrl}/covid19/counties/$countyId" : null;
    Response response = (url != null) ? await Network().get(url, auth: NetworkAuth.App) : null;
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    Map<String, dynamic> responseJson = (responseBody != null) ? AppJson.decodeMap(responseBody) : null;
    return (responseJson != null) ? HealthCounty.fromJson(responseJson, guidelines: guidelines) : null;
  }

  Future<HealthCounty> _ensureCounty() async {
    HealthCounty county = _loadCountyFromStorage();
    if (county == null) {
      List<HealthCounty> counties = await loadCounties();
      county = HealthCounty.getCounty(counties, countyId: Storage().currentHealthCountyId) ??
        HealthCounty.defaultCounty(counties);
      _saveCountyToStorage(county);
    }
    return county;
  }

  Future<void> _refreshCounty() async {
    if (_county != null) {
      HealthCounty county = await _loadCounty(countyId: _county?.id);
      if (county != null) {
        _applyCounty(county);
      }
    }
  }

  void _applyCounty(HealthCounty county) {
    if (_county != county) {
      _saveCountyToStorage(_county = county);
      NotificationService().notify(notifyCountyChanged);
    }
  }

  static HealthCounty _loadCountyFromStorage() {
    return HealthCounty.fromJson(AppJson.decodeMap(Storage().healthCounty));
  }

  static void _saveCountyToStorage(HealthCounty county) {
    Storage().healthCounty = AppJson.encode(county?.toJson());
  }

  // Rules

  Future<void> _refreshRules() async {
    String rulesJsonString = await _loadRulesJsonStringFromNet();
    HealthRulesSet rules = HealthRulesSet.fromJson(AppJson.decodeMap(rulesJsonString));
    if ((rules != null) && (rules != _rules)) {
      _rules = rules;
      await _saveRulesJsonStringToCache(rulesJsonString);
      NotificationService().notify(notifyRulesChanged);
    }
  }

  Future<String> _loadRulesJsonStringFromNet({String countyId}) async {
//TMP: return await rootBundle.loadString('assets/health.rules.json');
    countyId = countyId ?? _county?.id;
    String url = ((countyId != null) && (Config().healthUrl != null)) ? "${Config().healthUrl}/covid19/crules/county/$countyId" : null;
    String appVersion = AppVersion.majorVersion(Config().appVersion, 2);
    Response response = (url != null) ? await Network().get(url, auth: NetworkAuth.App, headers: { Network.RokwireAppVersion : appVersion }) : null;
    return (response?.statusCode == 200) ? response.body : null;
  }

  File _getRulesCacheFile() {
    String cacheFilePath = (_appDocumentsDir != null) ? join(_appDocumentsDir.path, _rulesFileName) : null;
    return (cacheFilePath != null) ? File(cacheFilePath) : null;
  }

  Future<HealthRulesSet> _loadRulesFromCache() async {
    return HealthRulesSet.fromJson(AppJson.decodeMap(await _loadRulesJsonStringFromCache()));
  }

  Future<String> _loadRulesJsonStringFromCache() async {
    File cacheFile = _getRulesCacheFile();
    try { return ((cacheFile != null) && await cacheFile.exists()) ? await cacheFile.readAsString() : null; } catch (e) { print(e?.toString()); }
    return null;
  }

  Future<void> _saveRulesJsonStringToCache(String jsonString) async {
    File cacheFile = _getRulesCacheFile();
    if (cacheFile != null) {
      try { await cacheFile.writeAsString(jsonString); } catch (e) { print(e?.toString()); }
    }
  }

  //TBD: on County switch
  /* Future<void> _clearRulesCache() async {
    File cacheFile = _getRulesCacheFile();
    try {
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (e) { print(e?.toString()); }
  }*/

  // Access Rules

  Future<Map<String, dynamic>> _loadBuildingAccessRules({String countyId}) async {
    countyId = countyId ?? _county?.id;
    String url = ((countyId != null) && (Config().healthUrl != null)) ? "${Config().healthUrl}/covid19/access-rules/county/$countyId" : null;
    Response response = (url != null) ? await Network().get(url, auth: NetworkAuth.App) : null;
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    return (responseBody != null) ? AppJson.decodeMap(responseBody) : null; 
  }

  Future<void> _refreshBuildingAccessRules() async {
    Map<String, dynamic> buildingAccessRules = await _loadBuildingAccessRules();
    if ((buildingAccessRules != null) && !DeepCollectionEquality().equals(_buildingAccessRules, buildingAccessRules)) {
      _saveBuildingAccessRulesToStorage(_buildingAccessRules = buildingAccessRules);
      NotificationService().notify(notifyBuildingAccessRulesChanged);
   }
  }

  static Map<String, dynamic> _loadBuildingAccessRulesFromStorage() {
    return AppJson.decodeMap(Storage().healthBuildingAccessRules);
  }

  static void _saveBuildingAccessRulesToStorage(Map<String, dynamic> buildingAccessRules) {
    Storage().healthBuildingAccessRules = AppJson.encode(buildingAccessRules);
  }
}