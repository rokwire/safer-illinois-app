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
import 'package:illinois/service/Exposure.dart';
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
//TMP: import 'package:flutter/services.dart' show rootBundle;

class Health with Service implements NotificationsListener {

  static const String notifyUserUpdated                = "edu.illinois.rokwire.health.user.updated";
  static const String notifyStatusUpdated              = "edu.illinois.rokwire.health.status.updated";
  static const String notifyHistoryUpdated             = "edu.illinois.rokwire.health.history.updated";
  static const String notifyUserAccountCanged          = "edu.illinois.rokwire.health.user.account.changed";
  static const String notifyCountyChanged              = "edu.illinois.rokwire.health.county.changed";
  static const String notifyRulesChanged               = "edu.illinois.rokwire.health.rules.changed";
  static const String notifyBuildingAccessRulesChanged = "edu.illinois.rokwire.health.building_access_rules.changed";
  static const String notifyRefreshing                 = "edu.illinois.rokwire.health.refreshing.updated";

  static const String _rulesFileName                   = "rules.json";
  static const String _historyFileName                 = "history.json";

  HealthUser _user;
  PrivateKey _userPrivateKey;
  String _userAccountId;
  int _userTestMonitorInterval;

  HealthStatus _status;
  List<HealthHistory> _history;
  
  HealthCounty _county;
  HealthRulesSet _rules;
  Map<String, dynamic> _buildingAccessRules;

  Directory _appDocumentsDir;
  PublicKey _servicePublicKey;
  HealthStatus _previousStatus;
  List<HealthPendingEvent> _processedEvents;
  Future<void> _refreshFuture;
  _RefreshOptions _refreshOptions;
  Set<String> _pendingNotifications;
  DateTime _pausedDateTime;

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
    _userAccountId = Storage().healthUserAccountId;
    _userTestMonitorInterval = Storage().healthUserTestMonitorInterval;

    _status = _loadStatusFromStorage();
    _history = await _loadHistoryFromCache();

    _county = await _ensureCounty();
    _rules = await _loadRulesFromCache();
    _rules?.userTestMonitorInterval = _userTestMonitorInterval;
    _buildingAccessRules = _loadBuildingAccessRulesFromStorage();

    _refresh(_RefreshOptions.all());
  }

  @override
  Future<void> clearService() async {
    _user = null;
    _userPrivateKey = null;
    _userAccountId = null;
    _userTestMonitorInterval = null;
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
          _refresh(_RefreshOptions.all());
        }
      }
    }
  }

  void _onUserLoginChanged() {

    if (this._isUserAuthenticated) {
      _refreshUserPrivateKey().then((_) {
        _refresh(_RefreshOptions.fromList([_RefreshOption.user, _RefreshOption.userInterval, _RefreshOption.history]));
      });
    }
    else {
      _userPrivateKey = null;
      _clearUser();
      _clearUserAccountId();
      _clearUserTestMonitorInterval();
      _clearStatus();
      _clearHistory();
    }
  }

  // Refresh

  bool get refreshing {
    return (_refreshFuture != null);
  }

  Future<void> refreshStatus() async {
    return _refresh(_RefreshOptions.fromList([_RefreshOption.userInterval, _RefreshOption.history, _RefreshOption.rules, _RefreshOption.buildingAccessRules]));
  }

  Future<void> refreshStatusAndUser() async {
    return _refresh(_RefreshOptions.fromList([_RefreshOption.user, _RefreshOption.userInterval, _RefreshOption.history, _RefreshOption.rules, _RefreshOption.buildingAccessRules]));
  }

  Future<void> refreshUser() async {
    return _refresh(_RefreshOptions.fromList([_RefreshOption.user, _RefreshOption.userPrivateKey]));
  }

  Future<void> _refresh(_RefreshOptions options) async {

    if (_refreshOptions != null) {
      options = options.difference(_refreshOptions);
    }

    if (_refreshFuture != null) {
      await _refreshFuture;
    }

    if (options.isNotEmpty) {
      await (_refreshFuture = _refreshInternal(options));
    }
  }

  Future<void> _refreshInternal(_RefreshOptions options) async {
    _refreshOptions = options;
    NotificationService().notify(notifyRefreshing);

    await Future.wait([
      options.user ? _refreshUser() : Future<void>.value(),
      options.userPrivateKey ? _refreshUserPrivateKey() : Future<void>.value(),
      
      options.userInterval ? _refreshUserTestMonitorInterval() : Future<void>.value(),
      options.status ? _refreshStatus() : Future<void>.value(),
      options.history ? _refreshHistory() : Future<void>.value(),
      
      options.county ? _refreshCounty() : Future<void>.value(),
      options.rules ? _refreshRules() : Future<void>.value(),
      options.buildingAccessRules ? _refreshBuildingAccessRules() : Future<void>.value(),
    ]);
    
    if (options.rules || options.userInterval) {
      _rules?.userTestMonitorInterval = _userTestMonitorInterval;
    }

    if (options.history || options.rules || options.userInterval) {
      await _rebuildStatus();
      await _logProcessedEvents();
    }

    _refreshOptions = null;
    _refreshFuture = null;
    NotificationService().notify(notifyRefreshing);
  }

  // Notifications

  void _beginNotificationsCache() {
    if (_pendingNotifications == null) {
      _pendingNotifications = Set<String>();
    }
  }

  void _endNotificationsCache() {
    if (_pendingNotifications != null) {
      Set<String> pendingNotifications = _pendingNotifications;
      _pendingNotifications = null;

      for (String notification in pendingNotifications) {
        NotificationService().notify(notification);
      }
    }
  }

  void _notify(String notification) {
    if (notification != null) {
      if (_pendingNotifications != null) {
        _pendingNotifications.add(notification);
      }
      else {
        NotificationService().notify(notification);
      }
    }
  }

  // Public Accessories
  
  bool get isUserLoggedIn {
    return this._isUserAuthenticated && (_user != null);
  }

  bool get userExposureNotification {
    return this.isUserLoggedIn && (_user?.exposureNotification ?? false);
  }

  // User

  HealthUser get user {
    return _user;
  }

  bool get _isUserAuthenticated {
    return (Auth().authToken?.idToken != null);
  }

  bool get _isUserReadAuthenticated {
    return this._isUserAuthenticated && (_userPrivateKey != null);
  }

  bool get _isUserWriteAuthenticated {
    return this._isUserAuthenticated && (_user?.publicKey != null);
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

  String get _userInfo {
    String userName;
    if (AppString.isStringNotEmpty(userName = Auth().fullUserName)) {
      return userName;
    }
    else if (AppString.isStringNotEmpty(userName = Auth().authUser?.uin)) {
      return userName;
    }
    else if (AppString.isStringNotEmpty(userName = Auth().authUser?.email)) {
      return userName;
    }
    else if (AppString.isStringNotEmpty(userName = Auth().authUser?.phone)) {
      return userName;
    }
    else if (AppString.isStringNotEmpty(userName = Auth().phoneToken?.phone)) {
      return userName;
    }
    else {
      return null;
    }
  }

  Future<HealthUser> _loadUserFromNet() async {
    if (this._isUserAuthenticated && (Config().healthUrl != null)) {
      String url =  "${Config().healthUrl}/covid19/user";
      Response response = await Network().get(url, auth: Network.RokmetroUserAuth);
      if (response?.statusCode == 200) {
        HealthUser user = HealthUser.fromJson(AppJson.decodeMap(response.body)); // Return user or null if does not exist for sure.
        return user;
      }
      throw Exception("${response?.statusCode ?? '000'} ${response?.body ?? 'Unknown error occured'}");
    }
    throw Exception("User not logged in");
  }

  Future<bool> _saveUserToNet(HealthUser user) async {
    if (this._isUserAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/login";
      String post = AppJson.encode(user?.toJson());
      Response response = await Network().post(url, body: post, auth: Network.RokmetroUserAuth);
      if ((response != null) && (response.statusCode == 200)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _clearUserFromNet() async {
    if (this._isUserAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/user/clear";
      Response response = await Network().get(url, auth: Network.RokmetroUserAuth);
      if (response?.statusCode == 200) {
        _clearUser();
        return true;
      }
    }
    return false;
  }

  Future<HealthUser> loginUser({bool consent, bool exposureNotification, AsymmetricKeyPair<PublicKey, PrivateKey> keys}) async {

    if (!this._isUserAuthenticated) {
      return null;
    }

    HealthUser user;
    try {
      user = await _loadUserFromNet();
    }
    catch (e) {
      print(e?.toString());
      return null; // Load user request failed -> login failed
    }

    bool userUpdated, userReset;
    if (user == null) {
      // User had not logged in -> create new user
      user = HealthUser(uuid: UserProfile().uuid);
      userUpdated = userReset = true;
    }
    
    // Always update user info.
    await user.encryptBlob(HealthUserBlob(info: _userInfo), _servicePublicKey);
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
      bool userSaved = await _saveUserToNet(user);
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
        userReset = true;
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

    if (userReset == true) {
      await _refresh(_RefreshOptions.fromList([_RefreshOption.userInterval, _RefreshOption.history]));
    }
    
    return user;
  }

  Future<bool> deleteUser() async {
    if (await _clearUserFromNet()) {
      await _saveUserPrivateKey(_userPrivateKey = null);
      await _clearHistory();
      _clearStatus();
      _clearUserAccountId();
      _clearUserTestMonitorInterval();
      return true;
    }
    return false;
  }

  Future<bool> repostUser() async {

    HealthUser user;
    try { user = await _loadUserFromNet(); }
    catch (e) { print(e?.toString()); }

    if (user != null) {
      user.repost = true;
      return await _saveUserToNet(user);
    }
    
    return false;
  }

  Future<void> _refreshUser() async {
    try { _applyUser(await _loadUserFromNet()); }
    catch (e) { print(e?.toString()); }
  }

  void _clearUser() {
    _applyUser(null);
  }

  void _applyUser(HealthUser user) {
    if (_user != user) {
      _saveUserToStorage(_user = user);
      _notify(notifyUserUpdated);
    }
  }

  static HealthUser _loadUserFromStorage() {
    return HealthUser.fromJson(AppJson.decodeMap(Storage().healthUser));
  }

  static void _saveUserToStorage(HealthUser user) {
    Storage().healthUser = AppJson.encode(user?.toJson());
  }

  // User RSA keys

  PrivateKey get userPrivateKey {
    return _userPrivateKey;
  }
  
  Future<bool> setUserPrivateKey(PrivateKey privateKey) async {
    if (await _saveUserPrivateKey(privateKey)) {
      _userPrivateKey = privateKey;
      _refresh(_RefreshOptions.fromList([_RefreshOption.history]));
      return true;
    }
    return false;
  }

  Future<AsymmetricKeyPair<PublicKey, PrivateKey>> resetUserKeys() async {
    AsymmetricKeyPair<PublicKey, PrivateKey> keys = await RsaKeyHelper.computeRSAKeyPair(RsaKeyHelper.getSecureRandom());

    HealthUser user = await loginUser(keys: keys);
    if (user != null) {
      // The old status and history is useless
      _beginNotificationsCache();
      await _clearNetHistory();
      await _clearNetStatus();
      _refresh(_RefreshOptions.fromList([_RefreshOption.history]));
      _endNotificationsCache();
      return keys;
    }

    return null; // Failure - keep the old keys
  }

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

  // User Accounts

  HealthUserAccount get userAccount {
    return _user?.account(accountId: _userAccountId) ?? _user?.defaultAccount;
  }

  String get userAccountId {
    return userAccount?.accountId;
  }

  Future<void> setUserAccountId(String accountId) {
    if ((accountId != null) && (accountId == _user?.defaultAccount?.accountId)) {
      accountId = null;
    }
    return _applyUserAccount(accountId);
  }

  bool get userMultipleAccounts {
    return 1 < (_user?.accountsMap?.length ?? 0);
  }

  Future<void> _applyUserAccount(String accountId) async {
    if (_userAccountId != accountId) {
      Storage().healthUserAccountId = _userAccountId = accountId;
      _notify(notifyUserAccountCanged);

      _beginNotificationsCache();
      _clearStatus();
      _clearUserTestMonitorInterval();
      await _clearHistory();
      await _refresh(_RefreshOptions.fromList([_RefreshOption.userInterval, _RefreshOption.history]));
      _endNotificationsCache();
    }
  }

  void _clearUserAccountId() {
    _applyUserAccount(null);
  }

  // User test monitor interval

  int get userTestMonitorInterval {
    return _userTestMonitorInterval;
  }

  Future<void> _refreshUserTestMonitorInterval() async {
    try {
      Storage().healthUserTestMonitorInterval = _userTestMonitorInterval = await _loadUserTestMonitorInterval();
    }
    catch (e) {
      print(e?.toString());
    }
  }

  Future<int> _loadUserTestMonitorInterval() async {
    if (this._isUserAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/uin-override";
      Response response = await Network().get(url, auth: Network.HealthUserAuth);
      if (response?.statusCode == 200) {
        Map<String, dynamic> responseJson = AppJson.decodeMap(response.body);
        return (responseJson != null) ? responseJson['interval'] : null;
      }
      throw Exception("${response?.statusCode ?? '000'} ${response?.body ?? 'Unknown error occured'}");
    }
    throw Exception("User not logged in");
  }

  void _clearUserTestMonitorInterval() {
    Storage().healthUserTestMonitorInterval = _userTestMonitorInterval = null;
  }

  // Status

  HealthStatus get status  {
    return _status;
  }
  
  HealthStatus get previousStatus  {
    return _previousStatus;
  }
  
  Future<HealthStatus> _loadStatusFromNet() async {
    if (this._isUserReadAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/v2/app-version/2.2/statuses";
      Response response = await Network().get(url, auth: Network.HealthUserAuth);
      if (response?.statusCode == 200) {
        return await HealthStatus.decryptedFromJson(AppJson.decodeMap(response.body), _userPrivateKey);
      }
    }
    return null;
  }

  Future<bool> _saveStatusToNet(HealthStatus status) async {
    if (this._isUserWriteAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/v2/app-version/2.2/statuses";
      HealthStatus encryptedStatus = await status?.encrypted(_user?.publicKey);
      String post = AppJson.encode(encryptedStatus?.toJson());
      Response response = await Network().put(url, body: post, auth: Network.HealthUserAuth);
      if (response?.statusCode == 200) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _clearNetStatus() async {
    if (this._isUserAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/v2/app-version/2.2/statuses";
      Response response = await Network().delete(url, auth: Network.HealthUserAuth);
      if (response?.statusCode == 200) {
       _saveStatusToStorage(_status = _previousStatus = null);
        _notify(notifyStatusUpdated);
        return true;
      }
    }
    return false;
  }

  Future<void> _refreshStatus () async {
    HealthStatus status = await _loadStatusFromNet();
    if (status != null) {
      _applyStatus(status);
    }
  }

  void _clearStatus () {
    _applyStatus(null);
  }

  Future<void> _rebuildStatus() async {
    if (this._isUserWriteAuthenticated && (_rules != null) && (_history != null)) {
      HealthStatus status = _buildStatus(rules: _rules, history: _history);
      if ((status?.blob != null) && (status?.blob != _status?.blob)) {
        if (await _saveStatusToNet(status)) {
          _applyStatus(status);
        }
      }
    }
  }

  void _applyStatus(HealthStatus status) {
    if (_status != status) {
      String oldStatusCode = _status?.blob?.code;
      String newStatusCode = status?.blob?.code;
      if ((oldStatusCode != null) && (newStatusCode != null) && (oldStatusCode != newStatusCode)) {
        Analytics().logHealth(
          action: Analytics.LogHealthStatusChangedAction,
          status: newStatusCode,
          prevStatus: oldStatusCode
        );
      }

      _previousStatus = (status != null) ? _status : null;
      _saveStatusToStorage(_status = status);
      _notify(notifyStatusUpdated);
    }
    _applyBuildingAccessForStatus(status);
    _updateExposureReportTarget(status);
  }

  void _updateExposureReportTarget(HealthStatus status) {
    if ((status?.blob?.reportsExposures(rules: _rules) == true) &&
        /*status?.blob?.historyBlob?.isTest && */
        (status?.dateUtc != null))
    {
      Exposure().reportTargetTimestamp = status.dateUtc.millisecondsSinceEpoch;
    }
  }
  static HealthStatus _buildStatus({HealthRulesSet rules, List<HealthHistory> history}) {
    if ((rules == null) || (history == null)) {
      return null;
    }

    HealthRuleStatus defaultStatus = rules?.defaults?.status?.eval(history: history, historyIndex: -1, rules: rules);
    if (defaultStatus == null) {
      return null;
    }

    HealthStatus status = HealthStatus(
      dateUtc: null,
      blob: HealthStatusBlob(
        code: defaultStatus.code,
        priority: defaultStatus.priority,
        nextStep: rules.localeString(defaultStatus.nextStep),
        nextStepHtml: rules.localeString(defaultStatus.nextStepHtml),
        nextStepDateUtc: null,
        eventExplanation: rules.localeString(defaultStatus.eventExplanation),
        eventExplanationHtml: rules.localeString(defaultStatus.eventExplanationHtml),
        warning: rules.localeString(defaultStatus.warning),
        warningHtml: rules.localeString(defaultStatus.warningHtml),
        reason: rules.localeString(defaultStatus.reason),
        fcmTopic: defaultStatus.fcmTopic,
        historyBlob: null,
      ),
    );

    // Start from older
    DateTime nowUtc = DateTime.now().toUtc();
    for (int index = history.length - 1; 0 <= index; index--) {

      HealthHistory historyEntry = history[index];
      if ((historyEntry.dateUtc != null) && historyEntry.dateUtc.isBefore(nowUtc)) {

        HealthRuleStatus ruleStatus;
        if (historyEntry.isTest && historyEntry.canTestUpdateStatus) {
          if (rules.tests != null) {
            HealthTestRuleResult testRuleResult = rules.tests?.matchRuleResult(blob: historyEntry?.blob, rules: rules);
            ruleStatus = testRuleResult?.status?.eval(history: history, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
        }
        else if (historyEntry.isSymptoms) {
          if (rules.symptoms != null) {
            HealthSymptomsRule symptomsRule = rules.symptoms.matchRule(blob: historyEntry?.blob, rules: rules);
            ruleStatus = symptomsRule?.status?.eval(history: history, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
        }
        else if (historyEntry.isContactTrace) {
          if (rules.contactTrace != null) {
            HealthContactTraceRule contactTraceRule = rules.contactTrace.matchRule(blob: historyEntry?.blob, rules: rules);
            ruleStatus = contactTraceRule?.status?.eval(history: history, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
        }
        else if (historyEntry.isAction) {
          if (rules.actions != null) {
            HealthActionRule actionRule = rules.actions.matchRule(blob: historyEntry?.blob, rules: rules);
            ruleStatus = actionRule?.status?.eval(history: history, historyIndex: index, rules: rules);
          }
          else {
            return null;
          }
        }

        if ((ruleStatus != null) && ruleStatus.canUpdateStatus(blob: status.blob)) {
          status = HealthStatus(
            dateUtc: historyEntry.dateUtc,
            blob: HealthStatusBlob(
              code: (ruleStatus.code != null) ? ruleStatus.code : status.blob.code,
              priority: (ruleStatus.priority != null) ? ruleStatus.priority.abs() : status.blob.priority,
              nextStep: ((ruleStatus.nextStep != null) || (ruleStatus.nextStepHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.nextStep) : status.blob.nextStep,
              nextStepHtml: ((ruleStatus.nextStep != null) || (ruleStatus.nextStepHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.nextStepHtml) : status.blob.nextStepHtml,
              nextStepDateUtc: ((ruleStatus.nextStepInterval != null) || (ruleStatus.nextStep != null) || (ruleStatus.nextStepHtml != null) || (ruleStatus.code != null)) ? ruleStatus.nextStepDateUtc : status.blob.nextStepDateUtc,
              eventExplanation: ((ruleStatus.eventExplanation != null) || (ruleStatus.eventExplanationHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.eventExplanation) : status.blob.eventExplanation,
              eventExplanationHtml: ((ruleStatus.eventExplanation != null) || (ruleStatus.eventExplanationHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.eventExplanationHtml) : status.blob.eventExplanationHtml,
              warning: ((ruleStatus.warning != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.warning) : status.blob.warning,
              warningHtml: ((ruleStatus.warningHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.warningHtml) : status.blob.warningHtml,
              reason: ((ruleStatus.reason != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.reason) : status.blob.reason,
              fcmTopic: ((ruleStatus.fcmTopic != null) || (ruleStatus.code != null)) ?  ruleStatus.fcmTopic : status.blob.fcmTopic,
              historyBlob: historyEntry.blob,
            ),
          );
        }
      }
    }
    return status;
  }

  static HealthStatus _loadStatusFromStorage() {
    return HealthStatus.fromJson(AppJson.decodeMap(Storage().healthUserStatus));
  }

  static void _saveStatusToStorage(HealthStatus status) {
    Storage().healthUserStatus = AppJson.encode(status?.toJson());
  }

  // History

  List<HealthHistory> get history {
    return _history;
  }

  Future<HealthHistory> addHistory({DateTime dateUtc, HealthHistoryType type, HealthHistoryBlob blob}) async {
    HealthHistory historyEntry = await _addHistory(await HealthHistory.encryptedFromBlob(
      dateUtc: dateUtc,
      type: type,
      blob: blob,
      publicKey: _user?.publicKey
    ));
    if (historyEntry != null) {
      _notify(notifyHistoryUpdated);
      await _rebuildStatus();
    }
    return historyEntry;
  }

  Future<HealthHistory> updateHistory({String id, DateTime dateUtc, HealthHistoryType type, HealthHistoryBlob blob}) async {
    HealthHistory historyEntry = await _updateHistory(await HealthHistory.encryptedFromBlob(
      id: id,
      dateUtc: dateUtc,
      type: type,
      blob: blob,
      publicKey: _user?.publicKey
    ));
    if (historyEntry != null) {
      _notify(notifyHistoryUpdated);
      await _rebuildStatus();
    }
    return historyEntry;
  }

  Future<bool> clearHistory() async {
    if (await _clearNetHistory()) {
      await _rebuildStatus();
      return true;
    }
    return false;
  }

  Future<void> _refreshHistory() async {
    bool historyUpdated;
    String historyJsonString = await _loadHistoryJsonStringFromNet();
    List<HealthHistory> history = await HealthHistory.listFromJson(AppJson.decodeList(historyJsonString), _historyPrivateKeys);
    
    if ((history != null) && !ListEquality().equals(history, _history)) {
      _history = history;
      await _saveHistoryJsonStringToCache(historyJsonString);
      historyUpdated = true;
    }

    List<HealthPendingEvent> processedEvents = await _processPendingEvents();
    if ((processedEvents != null) && (0 < processedEvents.length)) {
      _applyProcessedEvents(processedEvents);
      historyUpdated = true;
    }

    if (historyUpdated == true) {
      _notify(notifyHistoryUpdated);
    }
  }

  Future<void> _clearHistory() async {
    if (_history != null) {
      _history = null;
      await _clearHistoryCache();
      _notify(notifyHistoryUpdated);
    }
  }

  Future<bool> _clearNetHistory() async {
    if (this._isUserAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/v2/histories";
      Response response = await Network().delete(url, auth: Network.HealthUserAuth);
      if (response?.statusCode == 200) {
        _history = <HealthHistory>[];
        await _saveHistoryJsonStringToCache(AppJson.encode(HealthHistory.listToJson(_history)));
        return true;
      }
    }
    return false;
  }

  Future<String> _loadHistoryJsonStringFromNet() async {
    String url = (this._isUserReadAuthenticated && (Config().healthUrl != null)) ? "${Config().healthUrl}/covid19/v2/histories" : null;
    Response response = (url != null) ? await Network().get(url, auth: Network.HealthUserAuth) : null;
    return (response?.statusCode == 200) ? response.body : null;
  }

  Future<HealthHistory> _addHistory(HealthHistory history) async {
    if (this._isUserWriteAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/v2/histories";
      String post = AppJson.encode(history?.toJson());
      Response response = await Network().post(url, body: post, auth: Network.HealthUserAuth);
      HealthHistory historyEntry = (response?.statusCode == 200) ? await HealthHistory.decryptedFromJson(AppJson.decode(response.body), _historyPrivateKeys) : null;
      if ((_history != null) && (historyEntry != null)) {
        _history.add(historyEntry);
        HealthHistory.sortListDescending(_history);
        await _saveHistoryJsonStringToCache(AppJson.encode(HealthHistory.listToJson(_history)));
      }
      return historyEntry;
    }
    return null;
  }

  Future<HealthHistory> _updateHistory(HealthHistory history) async {
    if (this._isUserWriteAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/v2/histories/${history.id}";
      String post = AppJson.encode(history?.toJson());
      Response response = await Network().put(url, body: post, auth: Network.HealthUserAuth);
      HealthHistory historyEntry = (response?.statusCode == 200) ? await HealthHistory.decryptedFromJson(AppJson.decode(response.body), _historyPrivateKeys) : null;
      if ((_history != null) && (historyEntry != null) && HealthHistory.updateInList(_history, historyEntry)) {
        HealthHistory.sortListDescending(_history);
        await _saveHistoryJsonStringToCache(AppJson.encode(HealthHistory.listToJson(_history)));
      }
      return historyEntry;
    }
    return null;
  }

  Map<HealthHistoryType, PrivateKey> get _historyPrivateKeys {
    return {
      HealthHistoryType.test : _userPrivateKey,
      HealthHistoryType.manualTestVerified : _userPrivateKey,
      HealthHistoryType.manualTestNotVerified : null, // unencrypted
      HealthHistoryType.symptoms : _userPrivateKey,
      HealthHistoryType.contactTrace : _userPrivateKey,
      HealthHistoryType.action : _userPrivateKey,
    };
  }

  File _getHistoryCacheFile() {
    String cacheFilePath = (_appDocumentsDir != null) ? join(_appDocumentsDir.path, _historyFileName) : null;
    return (cacheFilePath != null) ? File(cacheFilePath) : null;
  }

  Future<List<HealthHistory>> _loadHistoryFromCache() async {
    return await HealthHistory.listFromJson(AppJson.decodeList(await _loadHistoryJsonStringFromCache()), _historyPrivateKeys);
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

  // Waiting on table

  Future<List<HealthPendingEvent>> _loadPendingEvents({bool processed}) async {
    if (this._isUserReadAuthenticated && (Config().healthUrl != null)) {
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
      Response response = await Network().get(url, auth: Network.HealthUserAuth);
      String responseString = (response?.statusCode == 200) ? response.body : null;
      List<dynamic> responseJson = (responseString != null) ? AppJson.decodeList(responseString) : null;
      return (responseJson != null) ? await HealthPendingEvent.listFromJson(responseJson, _userPrivateKey) : null;
    }
    return null;
  }

  Future<bool> _markPendingEventAsProcessed(HealthPendingEvent event) async {
    String url = (this._isUserAuthenticated && Config().healthUrl != null) ? "${Config().healthUrl}/covid19/ctests/${event.id}" : null;
    String post = AppJson.encode({'processed' : true});
    Response response = (url != null) ? await Network().put(url, body:post, auth: Network.HealthUserAuth) : null;
    if (response?.statusCode == 200) {
      return true;
    }
    else {
      return false;
    }
  }

  Future<List<HealthPendingEvent>> _processPendingEvents() async {
    List<HealthPendingEvent> result;
    List<HealthPendingEvent> events = this._isUserWriteAuthenticated ? await _loadPendingEvents(processed: false) : null;
    if ((events != null) && (0 < events?.length)) {
      for (HealthPendingEvent event in events) {
        if (HealthHistory.listContainsEvent(_history, event)) {
          // mark it as processed without duplicating the histyr entry
          await _markPendingEventAsProcessed(event);
        }
        else {
          // add history entry and mark as processed
          if (await _applyPendingEventInHistory(event)) {
            await _markPendingEventAsProcessed(event);
            if (result == null) {
              result = List<HealthPendingEvent>();
            }
            result.add(event);
          }
        }
      }
    }
    return result;
  }

  Future<bool> _applyPendingEventInHistory(HealthPendingEvent event) async {
    HealthHistory historyEntry;
    if (event.isTest) {
      historyEntry = await _addHistory(await HealthHistory.encryptedFromBlob(
        dateUtc: event?.blob?.dateUtc,
        type: HealthHistoryType.test,
        blob: HealthHistoryBlob(
          provider: event?.provider,
          providerId: event?.providerId,
          testType: event?.blob?.testType,
          testResult: event?.blob?.testResult,
        ),
        publicKey: _user?.publicKey
      ));
    }
    else if (event.isAction) {
      historyEntry = await _addHistory(await HealthHistory.encryptedFromBlob(
        dateUtc: event?.blob?.dateUtc,
        type: HealthHistoryType.action,
        blob: HealthHistoryBlob(
          actionType: event?.blob?.actionType,
          actionText: event?.blob?.actionText,
        ),
        publicKey: _user?.publicKey
      ));
    }
    return (historyEntry != null);
  }

  void _applyProcessedEvents(List<HealthPendingEvent> processedEvents) {
    if ((processedEvents != null) && (0 < processedEvents.length)) {
      if (_processedEvents != null) {
        _processedEvents.addAll(processedEvents);
      }
      else {
        _processedEvents = processedEvents;
      }
    }
  }

  Future<void> _logProcessedEvents() async {
    if ((_processedEvents != null) && (0 < _processedEvents.length)) {

      int exposureTestReportDays = Config().settings['covid19ExposureTestReportDays'];
      for (HealthPendingEvent event in _processedEvents) {
        if (event.isTest) {
          HealthHistory previousTest = HealthHistory.mostRecentTest(_history, beforeDateUtc: event.blob?.dateUtc, onPosition: 2);
          int score = await Exposure().evalTestResultExposureScoring(previousTestDateUtc: previousTest?.dateUtc);
          
          Analytics().logHealth(
            action: Analytics.LogHealthProviderTestProcessedAction,
            status: _status?.blob?.code,
            prevStatus: _previousStatus?.blob?.code,
            attributes: {
              Analytics.LogHealthProviderName: event.provider,
              Analytics.LogHealthTestTypeName: event.blob?.testType,
              Analytics.LogHealthTestResultName: event.blob?.testResult,
              Analytics.LogHealthExposureScore: score,
          });
          
          if (exposureTestReportDays != null)  {
            DateTime maxDateUtc = event?.blob?.dateUtc;
            DateTime minDateUtc = maxDateUtc?.subtract(Duration(days: exposureTestReportDays));
            if ((maxDateUtc != null) && (minDateUtc != null)) {
              HealthHistory contactTrace = HealthHistory.mostRecentContactTrace(_history, minDateUtc: minDateUtc, maxDateUtc: maxDateUtc);
              if (contactTrace != null) {
                Analytics().logHealth(
                  action: Analytics.LogHealthContactTraceTestAction,
                  status: _status?.blob?.code,
                  prevStatus: _previousStatus?.blob?.code,
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
            status: _status?.blob?.code,
            prevStatus: _previousStatus?.blob?.code,
            attributes: {
              Analytics.LogHealthActionTypeName: event.blob?.actionType,
              Analytics.LogHealthActionTextName: event.blob?.defaultLocaleActionText,
          });
        }
      }
      
      // clear after logging
      _processedEvents = null;
    }
  }

  // OCF tests

  Future<int> processOsfTests({List<HealthOSFTest> osfTests}) async {

    List<HealthTestType> testTypes = await loadTestTypes();
    Set<String> testTypeSet = testTypes != null ? testTypes.map((entry) => entry.name).toSet() : null;
    if (osfTests != null) {
      List<HealthOSFTest> processed = List<HealthOSFTest>();
      DateTime lastOsfTestDateUtc = Storage().lastHealthOsfTestDateUtc;
      DateTime latestOsfTestDateUtc;

      for (HealthOSFTest osfTest in osfTests) {
        if (((testTypeSet != null) && testTypeSet.contains(osfTest.testType)) && (osfTest.dateUtc != null) && ((lastOsfTestDateUtc == null) || lastOsfTestDateUtc.isBefore(osfTest.dateUtc))) {
          HealthHistory testHistory = await _applyOsfTestHistory(osfTest);
          if (testHistory != null) {
            processed.add(osfTest);
            if ((latestOsfTestDateUtc == null) || latestOsfTestDateUtc.isBefore(osfTest.dateUtc)) {
              latestOsfTestDateUtc = osfTest.dateUtc;
            }
          }
        }
      }
      if (latestOsfTestDateUtc != null) {
        Storage().lastHealthOsfTestDateUtc = latestOsfTestDateUtc;
      }

      if (0 < processed.length) {
        _notify(notifyHistoryUpdated);

        HealthStatus previousStatus = _status;
        await _rebuildStatus();
        
        for (HealthOSFTest osfTest in processed) {
          Analytics().logHealth(
              action: Analytics.LogHealthProviderTestProcessedAction,
              status: _status?.blob?.code,
              prevStatus: previousStatus?.blob?.code,
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

  Future<HealthHistory> _applyOsfTestHistory(HealthOSFTest test) async {
    return await _addHistory(await HealthHistory.encryptedFromBlob(
      dateUtc: test?.dateUtc,
      type: HealthHistoryType.test,
      blob: HealthHistoryBlob(
        provider: test?.provider,
        providerId: test?.providerId,
        testType: test?.testType,
        testResult: test?.testResult,
      ),
      publicKey: _user?.publicKey
    ));
  }

  // Manual tests

  Future<bool> processManualTest(HealthManualTest test) async {
    if (test != null) {
      HealthHistory manualHistory = await _addHistory(await HealthHistory.encryptedFromBlob(
        dateUtc: test?.dateUtc,
        type: HealthHistoryType.manualTestNotVerified,
        blob: HealthHistoryBlob(
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

      if (manualHistory != null) {
        _notify(notifyHistoryUpdated);
  
        HealthStatus previousStatus = _status;
        await _rebuildStatus();
  
        Analytics().logHealth(
          action: Analytics.LogHealthManualTestSubmittedAction,
          status: _status?.blob?.code,
          prevStatus: previousStatus?.blob?.code,
          attributes: {
            Analytics.LogHealthProviderName: test.provider,
            Analytics.LogHealthLocationName: test.location,
            Analytics.LogHealthTestTypeName: test.testType,
            Analytics.LogHealthTestResultName: test.testResult,
        });
        return true;
      }
    }
    return false;
  }

  // Symptoms

  Future<bool> processSymptoms({Set<String> selected, DateTime dateUtc}) async {
    List<HealthSymptom> symptoms = HealthSymptomsGroup.getSymptoms(_rules?.symptoms?.groups, selected);

    HealthHistory history = await _addHistory(await HealthHistory.encryptedFromBlob(
      dateUtc: dateUtc ?? DateTime.now().toUtc(),
      type: HealthHistoryType.symptoms,
      blob: HealthHistoryBlob(
        symptoms: symptoms,
      ),
      publicKey: _user?.publicKey
    ));

    if (history != null) {
      _notify(notifyHistoryUpdated);

      HealthStatus previousStatus = _status;
      await _rebuildStatus();

      List<String> analyticsSymptoms = [];
      symptoms?.forEach((HealthSymptom symptom) {
        if (AppString.isStringNotEmpty(symptom?.name)) {
          analyticsSymptoms.add(symptom.name);
        }
      });
      Analytics().logHealth(
        action: Analytics.LogHealthSymptomsSubmittedAction,
        status: previousStatus?.blob?.code,
        prevStatus: _status?.blob?.code,
        attributes: {
          Analytics.LogHealthSymptomsName: analyticsSymptoms
      });

      return true;
    }
    return false;
  }

  // Contact Trace

  // Used only from debug panel, see Exposure.checkExposures
  Future<bool> processContactTrace({DateTime dateUtc, int duration}) async {
    
    HealthHistory history = await _addHistory(await HealthHistory.encryptedFromBlob(
      dateUtc: dateUtc ?? DateTime.now().toUtc(),
      type: HealthHistoryType.contactTrace,
      blob: HealthHistoryBlob(
        traceDuration: duration,
      ),
      publicKey: _user?.publicKey
    ));

    if (history != null) {
      _notify(notifyHistoryUpdated);

      HealthStatus previousStatus = _status;
      await _rebuildStatus();

      Analytics().logHealth(
        action: Analytics.LogHealthContactTraceProcessedAction,
        status: previousStatus?.blob?.code,
        prevStatus: _status?.blob?.code,
        attributes: {
          Analytics.LogHealthDurationName: duration,
          Analytics.LogHealthExposureTimestampName: dateUtc?.toIso8601String(),
      });

      return true;
    }
    return false;
  }

  // Counties

  HealthCounty get county {
    return _county;
  }

  Future<void> setCounty(HealthCounty county) {
    return _applyCounty(HealthCounty.fromCounty(county)); // ensure no guidelines in storage county
  }

  Future<List<HealthCounty>> loadCounties({ bool guidelines }) async {
    return _loadCounties(guidelines: guidelines);
  }


  Future<List<HealthCounty>> _loadCounties({ bool guidelines }) async {
    String url = (Config().healthUrl != null) ? "${Config().healthUrl}/covid19/counties" : null;
    Response response = (url != null) ? await Network().get(url, auth: Network.AppAuth) : null;
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseBody != null) ? AppJson.decodeList(responseBody) : null;
    return (responseJson != null) ? HealthCounty.listFromJson(responseJson, guidelines: guidelines) : null;
  }

  Future<HealthCounty> _loadCounty({String countyId, bool guidelines }) async {
    String url = ((countyId != null) && (Config().healthUrl != null)) ? "${Config().healthUrl}/covid19/counties/$countyId" : null;
    Response response = (url != null) ? await Network().get(url, auth: Network.AppAuth) : null;
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    Map<String, dynamic> responseJson = (responseBody != null) ? AppJson.decodeMap(responseBody) : null;
    return (responseJson != null) ? HealthCounty.fromJson(responseJson, guidelines: guidelines) : null;
  }

  Future<HealthCounty> _ensureCounty() async {
    HealthCounty county = _loadCountyFromStorage();
    if (county == null) {
      List<HealthCounty> counties = await _loadCounties();
      county = HealthCounty.getCounty(counties, countyId: Storage().currentHealthCountyId) ??
        HealthCounty.defaultCounty(counties);
      _saveCountyToStorage(county);
    }
    return county;
  }

  Future<void> _refreshCounty() async {
    if (_county != null) {
      HealthCounty county = await _loadCounty(countyId: _county?.id);
      if ((county != null) && (_county != county)) {
        _saveCountyToStorage(_county = county);
        _notify(notifyCountyChanged);
      }
    }
  }

  Future<void> _applyCounty(HealthCounty county) async {
    if (_county?.id != county?.id) {
      _saveCountyToStorage(_county = county);
      _notify(notifyCountyChanged);

      _beginNotificationsCache();
      await _clearRules();
      _clearBuildingAccessRules();
      await _refresh(_RefreshOptions.fromList([_RefreshOption.rules, _RefreshOption.buildingAccessRules]));
      _endNotificationsCache();
    }
  }

  static HealthCounty _loadCountyFromStorage() {
    return HealthCounty.fromJson(AppJson.decodeMap(Storage().healthCounty));
  }

  static void _saveCountyToStorage(HealthCounty county) {
    Storage().healthCounty = AppJson.encode(county?.toJson());
  }

  // Rules

  HealthRulesSet get rules {
    return _rules;
  }

  Future<Map<String, dynamic>> loadRulesJson({String countyId}) async {
    return AppJson.decodeMap(await _loadRulesJsonStringFromNet(countyId: countyId));
  }

  Future<void> _refreshRules() async {
    String rulesJsonString = await _loadRulesJsonStringFromNet();
    HealthRulesSet rules = HealthRulesSet.fromJson(AppJson.decodeMap(rulesJsonString));
    if ((rules != null) && (rules != _rules)) {
      _rules = rules;
      await _saveRulesJsonStringToCache(rulesJsonString);
      _notify(notifyRulesChanged);
    }
  }

  Future<void> _clearRules() async {
    _rules = null;
    await _clearRulesCache();
  }

  Future<String> _loadRulesJsonStringFromNet({String countyId}) async {
//TMP: return await rootBundle.loadString('assets/health.rules.json');
    countyId = countyId ?? _county?.id;
    String url = ((countyId != null) && (Config().healthUrl != null)) ? "${Config().healthUrl}/covid19/crules/county/$countyId" : null;
    String appVersion = AppVersion.majorVersion(Config().appVersion, 2);
    Response response = (url != null) ? await Network().get(url, auth: Network.AppAuth, headers: { Network.RokwireAppVersion : appVersion }) : null;
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

  Future<void> _clearRulesCache() async {
    File cacheFile = _getRulesCacheFile();
    try {
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (e) { print(e?.toString()); }
  }

  // Building Access Rules

  Map<String, dynamic> get buildingAccessRules {
    return _buildingAccessRules;
  }

  bool get buildingAccessGranted {
    return ((_buildingAccessRules != null) && (_status?.blob?.code != null)) ?
      (_buildingAccessRules[_status?.blob?.code] == kBuildingAccessGranted) : null;
  }

  Future<Map<String, dynamic>> _loadBuildingAccessRules({String countyId}) async {
    countyId = countyId ?? _county?.id;
    String url = ((countyId != null) && (Config().healthUrl != null)) ? "${Config().healthUrl}/covid19/access-rules/county/$countyId" : null;
    Response response = (url != null) ? await Network().get(url, auth: Network.AppAuth) : null;
    String responseBody = (response?.statusCode == 200) ? response.body : null;
    return (responseBody != null) ? AppJson.decodeMap(responseBody) : null; 
  }

  Future<void> _refreshBuildingAccessRules() async {
    Map<String, dynamic> buildingAccessRules = await _loadBuildingAccessRules();
    if ((buildingAccessRules != null) && !DeepCollectionEquality().equals(_buildingAccessRules, buildingAccessRules)) {
      _saveBuildingAccessRulesToStorage(_buildingAccessRules = buildingAccessRules);
      _notify(notifyBuildingAccessRulesChanged);
   }
  }

  void _clearBuildingAccessRules() {
    _saveBuildingAccessRulesToStorage(_buildingAccessRules = null);
  }

  Future<void> _applyBuildingAccessForStatus(HealthStatus status) async {
    if (Config().settings['covid19ReportBuildingAccess'] == true) {
      String access = (_buildingAccessRules != null) ? _buildingAccessRules[status?.blob?.code] : null;
      if (access != null) {
        await _logBuildingAccess(dateUtc: DateTime.now().toUtc(), access: access);
      }
    }
  }

  Future<bool> _logBuildingAccess({DateTime dateUtc, String access}) async {
    if (this._isUserAuthenticated && (Config().healthUrl != null)) {
      String url = "${Config().healthUrl}/covid19/building-access";
      String post = AppJson.encode({
        'date': healthDateTimeToString(dateUtc),
        'access': access
      });
      Response response = (url != null) ? await Network().put(url, body: post, auth: Network.HealthUserAuth) : null;
      return (response?.statusCode == 200);
    }
    return false;
  }

  static Map<String, dynamic> _loadBuildingAccessRulesFromStorage() {
    return AppJson.decodeMap(Storage().healthBuildingAccessRules);
  }

  static void _saveBuildingAccessRulesToStorage(Map<String, dynamic> buildingAccessRules) {
    Storage().healthBuildingAccessRules = AppJson.encode(buildingAccessRules);
  }

  // Network API: HealthTestType

  Future<List<HealthTestType>> loadTestTypes({List<String> typeIds})async{
    String url = (Config().healthUrl != null) ? "${Config().healthUrl}/covid19/test-types" : null;
    if ((url != null) && (typeIds?.isNotEmpty ?? false)) {
      url += "?ids=";
      typeIds.forEach((id){
        url += "$id,";
      });
      url = url.substring(0, url.length - 1);
    }
    Response response = (url != null) ? await Network().get(url, auth: Network.AppAuth) : null;
    String responseString = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseString != null) ? AppJson.decode(responseString) : null;
    return (responseJson != null) ? HealthTestType.listFromJson(responseJson) : null;
  }

  // Network API: HealthServiceProvider

  Future<List<HealthServiceProvider>> loadProviders({String countyId}) async {
    String url = (Config().healthUrl != null) ? "${Config().healthUrl}/covid19/providers" : null;

    if ((url != null) && (countyId != null)) {
      url += "/county/$countyId";
    }

    Response response = (url != null) ? await Network().get(url, auth: Network.AppAuth) : null;
    String responseString = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseString != null) ? AppJson.decode(responseString) : null;
    return (responseJson != null) ? HealthServiceProvider.listFromJson(responseJson) : null;
  }

  // Network API: HealthServiceLocation

  Future<List<HealthServiceLocation>> loadLocations({String countyId, String providerId})async{
    String url = (Config().healthUrl != null) ? "${Config().healthUrl}/covid19/locations" : null;

    if (url != null) {
      if ((countyId != null))
        url += "?county-id=$countyId";
      if (providerId!=null)
        url += (countyId != null ? "&" : "?") + "provider-id=$providerId";
    }

    Response response = (url != null) ? await Network().get(url, auth: Network.AppAuth) : null;
    String responseString = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseString != null) ? AppJson.decode(responseString) : null;
    return (responseJson != null) ? HealthServiceLocation.listFromJson(responseJson) : null;
  }

  Future<HealthServiceLocation> loadLocation({String locationId})async{
    String url = (Config().healthUrl != null) ? "${Config().healthUrl}/covid19/locations" : null;

    if ((url != null) && (locationId != null))
      url += "/$locationId";

    Response response = (url != null) ? await Network().get(url, auth: Network.AppAuth) : null;
    String responseString = (response?.statusCode == 200) ? response.body : null;
    Map<String,dynamic> responseJson = (responseString != null) ? AppJson.decode(responseString) : null;
    return (responseJson != null) ? HealthServiceLocation.fromJson(responseJson) : null;
  }

}

class _RefreshOptions {
  final Set<_RefreshOption> options;

  _RefreshOptions({Set<_RefreshOption> options}) :
    this.options = options ?? Set<_RefreshOption>();

  factory _RefreshOptions.fromList(List<_RefreshOption> list) {
    return (list != null) ? _RefreshOptions(options: Set<_RefreshOption>.from(list)) : null;
  }

  factory _RefreshOptions.fromSet(Set<_RefreshOption> options) {
    return (options != null) ? _RefreshOptions(options: options) : null;
  }

  factory _RefreshOptions.all() {
    return _RefreshOptions.fromList(_RefreshOption.values);
  }

  bool get isEmpty { return options.isEmpty; }
  bool get isNotEmpty { return options.isNotEmpty; }

  bool get user { return options.contains(_RefreshOption.user); }
  bool get userPrivateKey { return options.contains(_RefreshOption.userPrivateKey); }
  bool get userInterval { return options.contains(_RefreshOption.userInterval); }

  bool get status { return options.contains(_RefreshOption.status); }
  bool get history { return options.contains(_RefreshOption.history); }

  bool get county { return options.contains(_RefreshOption.county); }
  bool get rules { return options.contains(_RefreshOption.rules); }
  bool get buildingAccessRules { return options.contains(_RefreshOption.buildingAccessRules); }

  _RefreshOptions difference(_RefreshOptions other) {
    return _RefreshOptions.fromSet(options?.difference(other?.options));
  }
}

enum _RefreshOption {
  user,
  userPrivateKey,
  userInterval,

  status,
  history,
  
  county,
  rules,
  buildingAccessRules,
}