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
import 'package:flutter/foundation.dart';
import 'package:illinois/model/Auth.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/model/Organization.dart';
import 'package:illinois/model/UserProfile.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/prefer_universal/html.dart';

class Storage with Service {

  static const String notifySettingChanged  = "edu.illinois.rokwire.setting.changed";

  static final Storage _appStore = new Storage._internal();

  factory Storage() {
    return _appStore;
  }

  Storage._internal();

  SharedPreferences _sharedPreferences;
  Uint8List _encryptionKey;

  @override
  Future<void> initService() async {
    if (_sharedPreferences == null) {
      _sharedPreferences = await SharedPreferences.getInstance();
    }
    //TBD: DD - web
    if ((_encryptionKey == null) && !kIsWeb) {
      _encryptionKey = await NativeCommunicator().encryptionKey(name: 'storage', size: AESCrypt.kCCBlockSizeAES128);
    }
  }

  @override
  Future<void> clearService() async {
    if (kIsWeb) {
      html.window.document.cookie = ""; //clear cookies
      window.localStorage.clear();
    }
    if (_sharedPreferences != null) {
      await _sharedPreferences.clear();
    }
  }

  String _getStringWithName(String name, {String defaultValue}) {
    return _sharedPreferences.getString(name) ?? defaultValue;
  }

  void _setStringWithName(String name, String value) {
    _sharedPreferences.setString(name, value);
    NotificationService().notify(notifySettingChanged, name);
  }

  String _getEncryptedStringWithName(String name, {String defaultValue}) {
    String value = _sharedPreferences.getString(name);
    if ((_encryptionKey != null) && (value != null)) {
      value = AESCrypt.decrypt(value, keyBytes: _encryptionKey);
    }
    return value ?? defaultValue;
  }

  void _setEncryptedStringWithName(String name, String value) {
    if ((_encryptionKey != null) && (value != null)) {
      value = AESCrypt.encrypt(value, keyBytes: _encryptionKey);
    }
    _sharedPreferences.setString(name, value);
    NotificationService().notify(notifySettingChanged, name);
  }

  List<String> _getStringListWithName(String name, {List<String> defaultValue}) {
    return _sharedPreferences.getStringList(name) ?? defaultValue;
  }

  void _setStringListWithName(String name, List<String> value) {
    _sharedPreferences.setStringList(name, value);
    NotificationService().notify(notifySettingChanged, name);
  }

  bool _getBoolWithName(String name, {bool defaultValue = false}) {
    return _sharedPreferences.getBool(name) ?? defaultValue;
  }

  void _setBoolWithName(String name, bool value) {
    _sharedPreferences.setBool(name, value);
    NotificationService().notify(notifySettingChanged, name);
  }

  int _getIntWithName(String name, {int defaultValue = 0}) {
    return _sharedPreferences.getInt(name) ?? defaultValue;
  }

  void _setIntWithName(String name, int value) {
    _sharedPreferences.setInt(name, value);
    NotificationService().notify(notifySettingChanged, name);
  }

  /*double _getDoubleWithName(String name, {double defaultValue = 0.0}) {
    return _sharedPreferences.getDouble(name) ?? defaultValue;
  }

  void _setDoubleWithName(String name, double value) {
    _sharedPreferences.setDouble(name, value);
    NotificationService().notify(notifySettingChanged, name);
  }*/


  dynamic operator [](String name) {
    return _sharedPreferences.get(name);
  }

  void operator []=(String name, dynamic value) {
    if (value is String) {
      _sharedPreferences.setString(name, value);
    }
    else if (value is int) {
      _sharedPreferences.setInt(name, value);
    }
    else if (value is double) {
      _sharedPreferences.setDouble(name, value);
    }
    else if (value is bool) {
      _sharedPreferences.setBool(name, value);
    }
    else if (value is List) {
      _sharedPreferences.setStringList(name, value.cast<String>());
    }
}


  // Notifications

  bool getNotifySetting(String name) {
    return _getBoolWithName(name, defaultValue: null);
  }

  void setNotifySetting(String name, bool value) {
    return _setBoolWithName(name, value);
  }

  /////////////
  // User

  static const String userProfileKey  = 'user';

  UserProfileData get userProfile {
    final String userToString = _getStringWithName(userProfileKey);
    final Map<String, dynamic> userToJson = AppJson.decode(userToString);
    return (userToJson != null) ? UserProfileData.fromJson(userToJson) : null;
  }

  set userProfile(UserProfileData user) {
    String userToString = (user != null) ? json.encode(user) : null;
    _setStringWithName(userProfileKey, userToString);
  }

  static const String localProfileUuidKey  = 'user_local_uuid';

  String get localProfileUuid {
    return _getStringWithName(localProfileUuidKey);
  }

  set localProfileUuid(String value) {
    _setStringWithName(localProfileUuidKey, value);
  }

  /////////////
  // UserPII

  static const String userPidKey  = 'user_pid';

  String get userPid {
    return _getStringWithName(userPidKey);
  }

  set userPid(String userPid) {
    _setStringWithName(userPidKey, userPid);
  }

  static const String userPiiDataTimeKey  = '_user_pii_data_time';

  int get userPiiDataTime {
    return _getIntWithName(userPiiDataTimeKey);
  }

  set userPiiDataTime(int value) {
    _setIntWithName(userPiiDataTimeKey, value);
  }

  ///////////////
  // On Boarding

  static const String onBoardingPassedKey  = 'on_boarding_passed';

  bool get onBoardingPassed {
    return _getBoolWithName(onBoardingPassedKey, defaultValue: false);
  }

  set onBoardingPassed(bool showOnBoarding) {
    _setBoolWithName(onBoardingPassedKey, showOnBoarding);
  }

  ////////////////
  // Upgrade

  static const String reportedUpgradeVersionsKey  = 'reported_upgrade_versions';

  Set<String> get reportedUpgradeVersions {
    List<String> list = _getStringListWithName(reportedUpgradeVersionsKey);
    return (list != null) ? Set.from(list) : Set<String>();
  }

  set reportedUpgradeVersion(String version) {
    if (version != null) {
      Set<String> versions = reportedUpgradeVersions;
      versions.add(version);
      _setStringListWithName(reportedUpgradeVersionsKey, versions.toList());
    }
  }

  ////////////////
  // Auth

  static const String authTokenKey  = '_auth_token';

  AuthToken get authToken {
    try {
      String jsonString = _getStringWithName(authTokenKey);
      dynamic jsonData = AppJson.decode(jsonString);
      return (jsonData != null) ? AuthToken.fromJson(jsonData) : null;
    } on Exception catch (e) {
      print(e.toString());
    }
    return null;
  }

  set authToken(AuthToken value) {
    _setStringWithName(authTokenKey, value != null ? json.encode(value.toJson()) : null);
  }

  static const String authUserKey  = '_auth_info';

  AuthUser get authUser {
    final String authUserToString = _getStringWithName(authUserKey);
    AuthUser authUser = AuthUser.fromJson(AppJson.decode(authUserToString));
    return authUser;
  }

  set authUser(AuthUser value) {
    _setStringWithName(authUserKey, value != null ? json.encode(value.toJson()) : null);
  }

  static const String authCardTimeKey  = '_auth_card_time';

  int get authCardTime {
    return _getIntWithName(authCardTimeKey);
  }

  set authCardTime(int value) {
    _setIntWithName(authCardTimeKey, value);
  }

  static const String rokmetroTokenKey  = '_rokmetro_token';

  RokmetroToken get rokmetroToken {
    try {
      String jsonString = _getStringWithName(rokmetroTokenKey);
      Map<String, dynamic> jsonData = AppJson.decodeMap(jsonString);
      return (jsonData != null) ? RokmetroToken.fromJson(jsonData) : null;
    } on Exception catch (e) { print(e.toString()); }
    return null;
  }

  set rokmetroToken(RokmetroToken value) {
    _setStringWithName(rokmetroTokenKey, AppJson.encode(value?.toJson()));
  }

  static const String rokmetroUserKey  = '_rokmetro_user';

  RokmetroUser get rokmetroUser {
    try {
      String jsonString = _getStringWithName(rokmetroUserKey);
      Map<String, dynamic> jsonData = AppJson.decodeMap(jsonString);
      return (jsonData != null) ? RokmetroUser.fromJson(jsonData) : null;
    } on Exception catch (e) { print(e.toString()); }
    return null;
  }

  set rokmetroUser(RokmetroUser value) {
    _setStringWithName(rokmetroUserKey, AppJson.encode(value?.toJson()));
  }

  /////////////////
  // Language

  static const String currentLanguageKey  = 'current_language';

  String get currentLanguage {
    return _getStringWithName(currentLanguageKey);
  }

  set currentLanguage(String value) {
    _setStringWithName(currentLanguageKey, value);
  }

  //////////////
  // Permanent subscription

  static const String firebaseSubscriptionTopisKey  = 'firebase_subscription_topis';

  Set<String> get firebaseSubscriptionTopis {
    List<String> topicsList = _getStringListWithName(firebaseSubscriptionTopisKey);
    return (topicsList != null) ? Set.from(topicsList) : null;
  }

  set firebaseSubscriptionTopis(Set<String> value) {
    List<String> topicsList = (value != null) ? List.from(value) : null;
    _setStringListWithName(firebaseSubscriptionTopisKey, topicsList);
  }

  void addFirebaseSubscriptionTopic(String value) {
    Set<String> topis = firebaseSubscriptionTopis ?? Set();
    topis.add(value);
    firebaseSubscriptionTopis = topis;
  }

  void removeFirebaseSubscriptionTopic(String value) {
    Set<String> topis = firebaseSubscriptionTopis;
    if (topis != null) {
      topis.remove(value);
      firebaseSubscriptionTopis = topis;
    }
  }

  /////////////
  // Organizaton

  static const String _organiationKey = 'organization';

  Organization get organization {
    return Organization.fromJson(AppJson.decode(_getEncryptedStringWithName(_organiationKey)));
  }

  set organization(Organization organization) {
    _setEncryptedStringWithName(_organiationKey, AppJson.encode(organization?.toJson()));
  }

  /////////////
  // Config

  static const String _configEnvKey = 'config_environment';

  String get configEnvironment {
    return _getStringWithName(_configEnvKey);
  }

  set configEnvironment(String value) {
    _setStringWithName(_configEnvKey, value);
  }

  /////////////
  // Health

  // Obsolete
  static const String _currentHealthCountyIdKey = 'health_current_county_id';
  
  String get currentHealthCountyId {
    return _getStringWithName(_currentHealthCountyIdKey);
  }

  set currentHealthCountyId(String value) {
    _setStringWithName(_currentHealthCountyIdKey, value);
  }

  static const String _lastHealthProviderKey = 'health_last_provider';

  HealthServiceProvider get lastHealthProvider {
    String storedProviderJson = _sharedPreferences.getString(_lastHealthProviderKey);
    return  HealthServiceProvider.fromJson(storedProviderJson!=null ? json.decode(storedProviderJson) : null);
  }

  set lastHealthProvider(HealthServiceProvider value) {
    _sharedPreferences.setString(_lastHealthProviderKey, value!=null? json.encode(value.toJson()) :value);
  }

  static const String _lastHealthCovid19StatusKey = 'health_last_covid19_status';

  String get lastHealthCovid19Status {
    return _getStringWithName(_lastHealthCovid19StatusKey);
  }

  set lastHealthCovid19Status(String value) {
    _setStringWithName(_lastHealthCovid19StatusKey, value);
  }

  static const String _lastHealthOsfTestDateKey = 'health_last_covid19_osf_test_date';

  DateTime get lastHealthOsfTestDateUtc {
    String dateString = _getStringWithName(_lastHealthOsfTestDateKey);
    try { return (dateString != null) ? DateFormat('yyyy-MM-ddTHH:mm:ss').parse(dateString) : null; }
    catch (e) { print(e?.toString()); }
    return null;
  }

  set lastHealthOsfTestDateUtc(DateTime value) {
    String dateString = (value != null) ? DateFormat('yyyy-MM-ddTHH:mm:ss').format(value) : null;
    _setStringWithName(_lastHealthOsfTestDateKey, dateString);
  }

  static const String _healthUserKey = 'health_user';

  String get healthUser {
    return _getStringWithName(_healthUserKey);
  }

  set healthUser(String value) {
    _setStringWithName(_healthUserKey, value);
  }

  static const String _healthUserStatusKey = 'health_user_status';

  String get healthUserStatus {
    return _getStringWithName(_healthUserStatusKey);
  }

  set healthUserStatus(String value) {
    _setStringWithName(_healthUserStatusKey, value);
  }

  static const String _healthUserTestMonitorIntervalKey = 'health_user_test_monitor_interval';

  int get healthUserTestMonitorInterval {
    return _getIntWithName(_healthUserTestMonitorIntervalKey);
  }

  set healthUserTestMonitorInterval(int value) {
    _setIntWithName(_healthUserTestMonitorIntervalKey, value);
  }

  static const String _healthUserAccountIdKey = 'health_user_account_id';

  String get healthUserAccountId {
    return _getStringWithName(_healthUserAccountIdKey);
  }

  set healthUserAccountId(String value) {
    _setStringWithName(_healthUserAccountIdKey, value);
  }

  static const String _healthCountyKey = 'health_county';
  
  String get healthCounty {
    return _getStringWithName(_healthCountyKey);
  }

  set healthCounty(String value) {
    _setStringWithName(_healthCountyKey, value);
  }

  static const String _healthBuildingAccessRulesKey = 'health_building_access_rules';
  
  String get healthBuildingAccessRules {
    return _getStringWithName(_healthBuildingAccessRulesKey);
  }

  set healthBuildingAccessRules(String value) {
    _setStringWithName(_healthBuildingAccessRulesKey, value);
  }

  /////////////
  // Exposure

  static const String _exposureStartedKey = 'exposure_started';

  bool get exposureStarted {
    return _getBoolWithName(_exposureStartedKey, defaultValue: true);
  }

  set exposureStarted(bool value) {
    _setBoolWithName(_exposureStartedKey, value);
  }

  static const String _exposureReportTargetTimestampKey = 'exposure_report_target_timestamp';

  int get exposureReportTargetTimestamp {
    return _getIntWithName(_exposureReportTargetTimestampKey, defaultValue: null);
  }

  set exposureReportTargetTimestamp(int value) {
    _setIntWithName(_exposureReportTargetTimestampKey, value);
  }

  static const String _exposureLastReportedTimestampKey = 'exposure_last_reported_timestamp';

  int get exposureLastReportedTimestamp {
    return _getIntWithName(_exposureLastReportedTimestampKey, defaultValue: null);
  }

  set exposureLastReportedTimestamp(int value) {
    _setIntWithName(_exposureLastReportedTimestampKey, value);
  }

  /////////////
  // Http Proxy

  static const String _httpProxyEnabledKey = 'http_proxy_enabled';

  bool get httpProxyEnabled {
    return _getBoolWithName(_httpProxyEnabledKey, defaultValue: false);
  }

  set httpProxyEnabled(bool value) {
    _setBoolWithName(_httpProxyEnabledKey, value);
  }

  static const String _httpProxyHostKey = 'http_proxy_host';

  String get httpProxyHost {
    return _getStringWithName(_httpProxyHostKey);
  }

  set httpProxyHost(String value) {
    _setStringWithName(_httpProxyHostKey, value);
  }

  static const String _httpProxyPortKey = 'http_proxy_port';

  String get httpProxyPort {
    return _getStringWithName(_httpProxyPortKey);
  }

  set httpProxyPort(String value) {
    _setStringWithName(_httpProxyPortKey, value);
  }

  /////////////
  // Test Encryption

  static const String _testEncryptionStringKey = 'test_encryption';
  
  String get testEncryptionString {
    return _getEncryptedStringWithName(_testEncryptionStringKey);
  }

  set testEncryptionString(String value) {
    _setEncryptedStringWithName(_testEncryptionStringKey, value);
  }
}
