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
    if (_encryptionKey == null) {
      _encryptionKey = await NativeCommunicator().encryptionKey(name: 'storage', size: AESCrypt.kCCBlockSizeAES128);
    }
  }

  @override
  Future<void> clearService() async {
    if (_sharedPreferences != null) {
      await _sharedPreferences.clear();
    }
  }

  String getString(String key, {String defaultValue}) {
    return _sharedPreferences.getString(key) ?? defaultValue;
  }

  void setString(String key, String value) {
    if(value != null) {
      _sharedPreferences.setString(key, value);
    } else {
      _sharedPreferences.remove(key);
    }
    NotificationService().notify(notifySettingChanged, key);
  }

  String getEncryptedString(String key, {String defaultValue}) {
    String value = _sharedPreferences.getString(key);
    if ((_encryptionKey != null) && (value != null)) {
      value = AESCrypt.decrypt(value, keyBytes: _encryptionKey);
    }
    return value ?? defaultValue;
  }

  void setEncryptedString(String key, String value) {
    if(value != null) {
      if ((_encryptionKey != null) && (value != null)) {
        value = AESCrypt.encrypt(value, keyBytes: _encryptionKey);
      }
      _sharedPreferences.setString(key, value);
    } else {
      _sharedPreferences.remove(key);
    }
    NotificationService().notify(notifySettingChanged, key);
  }

  List<String> getStringList(String key, {List<String> defaultValue}) {
    return _sharedPreferences.getStringList(key) ?? defaultValue;
  }

  void setStringList(String key, List<String> value) {
    if(value != null) {
      _sharedPreferences.setStringList(key, value);
    } else {
      _sharedPreferences.remove(key);
    }
    NotificationService().notify(notifySettingChanged, key);
  }

  bool getBool(String key, {bool defaultValue = false}) {
    return _sharedPreferences.getBool(key) ?? defaultValue;
  }

  void setBool(String key, bool value) {
    if(value != null) {
      _sharedPreferences.setBool(key, value);
    } else {
      _sharedPreferences.remove(key);
    }
    NotificationService().notify(notifySettingChanged, key);
  }

  int getInt(String key, {int defaultValue = 0}) {
    return _sharedPreferences.getInt(key) ?? defaultValue;
  }

  void setInt(String key, int value) {
    if(value != null) {
      _sharedPreferences.setInt(key, value);
    } else {
    _sharedPreferences.remove(key);
    }
    NotificationService().notify(notifySettingChanged, key);
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    return _sharedPreferences.getDouble(key) ?? defaultValue;
  }

  void setDouble(String key, double value) {
    if(value != null) {
      _sharedPreferences.setDouble(key, value);
    } else {
    _sharedPreferences.remove(key);
    }
    NotificationService().notify(notifySettingChanged, key);
  }


  dynamic operator [](String key) {
    return _sharedPreferences.get(key);
  }

  void operator []=(String key, dynamic value) {
    if (value is String) {
      _sharedPreferences.setString(key, value);
    }
    else if (value is int) {
      _sharedPreferences.setInt(key, value);
    }
    else if (value is double) {
      _sharedPreferences.setDouble(key, value);
    }
    else if (value is bool) {
      _sharedPreferences.setBool(key, value);
    }
    else if (value is List) {
      _sharedPreferences.setStringList(key, value.cast<String>());
    }
    else if (value == null) {
      _sharedPreferences.remove(key);
    }
}


  // Notifications

  bool getNotifySetting(String name) {
    return getBool(name, defaultValue: null);
  }

  void setNotifySetting(String name, bool value) {
    return setBool(name, value);
  }

  /////////////
  // User

  static const String userProfileKey  = 'user';

  UserProfileData get userProfile {
    final String userToString = getString(userProfileKey);
    final Map<String, dynamic> userToJson = AppJson.decode(userToString);
    return (userToJson != null) ? UserProfileData.fromJson(userToJson) : null;
  }

  set userProfile(UserProfileData user) {
    String userToString = (user != null) ? json.encode(user) : null;
    setString(userProfileKey, userToString);
  }

  static const String localProfileUuidKey  = 'user_local_uuid';

  String get localProfileUuid {
    return getString(localProfileUuidKey);
  }

  set localProfileUuid(String value) {
    setString(localProfileUuidKey, value);
  }

  /////////////
  // UserPII

  static const String userPidKey  = 'user_pid';

  String get userPid {
    return getString(userPidKey);
  }

  set userPid(String userPid) {
    setString(userPidKey, userPid);
  }

  static const String userPiiDataTimeKey  = '_user_pii_data_time';

  int get userPiiDataTime {
    return getInt(userPiiDataTimeKey);
  }

  set userPiiDataTime(int value) {
    setInt(userPiiDataTimeKey, value);
  }

  ///////////////
  // On Boarding

  static const String onBoardingPassedKey  = 'on_boarding_passed';

  bool get onBoardingPassed {
    return getBool(onBoardingPassedKey, defaultValue: false);
  }

  set onBoardingPassed(bool showOnBoarding) {
    setBool(onBoardingPassedKey, showOnBoarding);
  }

  ////////////////
  // Upgrade

  static const String reportedUpgradeVersionsKey  = 'reported_upgrade_versions';

  Set<String> get reportedUpgradeVersions {
    List<String> list = getStringList(reportedUpgradeVersionsKey);
    return (list != null) ? Set.from(list) : Set<String>();
  }

  set reportedUpgradeVersion(String version) {
    if (version != null) {
      Set<String> versions = reportedUpgradeVersions;
      versions.add(version);
      setStringList(reportedUpgradeVersionsKey, versions.toList());
    }
  }

  ////////////////////////////
  // Last Run Version

  static const String lastRunVersionKey  = 'last_run_version';

  String get lastRunVersion {
    return getString(lastRunVersionKey);
  }

  set lastRunVersion(String value) {
    setString(lastRunVersionKey, value);
  }

  ////////////////////////
  // Config Notifications

  static const String reportedConfigNotifictionsKey  = 'reported_config_notifications';

  Set<String> get reportedConfigNotifictions {
    List<String> list = getStringList(reportedConfigNotifictionsKey);
    return (list != null) ? Set.from(list) : null;
  }

  set reportedConfigNotifiction(String notificationId) {
    if (notificationId != null) {
      Set<String> notifications = reportedConfigNotifictions ?? Set<String>();
      notifications.add(notificationId);
      setStringList(reportedConfigNotifictionsKey, notifications.toList());
    }
  }

  ////////////////
  // Auth

  static const String authTokenKey  = '_auth_token';

  AuthToken get authToken {
    try {
      String jsonString = getString(authTokenKey);
      dynamic jsonData = AppJson.decode(jsonString);
      return (jsonData != null) ? AuthToken.fromJson(jsonData) : null;
    } on Exception catch (e) { print(e.toString()); }
    return null;
  }

  set authToken(AuthToken value) {
    setString(authTokenKey, value != null ? json.encode(value.toJson()) : null);
  }

  static const String authUserKey  = '_auth_info';

  AuthUser get authUser {
    final String authUserToString = getString(authUserKey);
    AuthUser authUser = AuthUser.fromJson(AppJson.decode(authUserToString));
    return authUser;
  }

  set authUser(AuthUser value) {
    setString(authUserKey, value != null ? json.encode(value.toJson()) : null);
  }

  static const String authCardTimeKey  = '_auth_card_time';

  int get authCardTime {
    return getInt(authCardTimeKey);
  }

  set authCardTime(int value) {
    setInt(authCardTimeKey, value);
  }

  // Disable Rokmetro auth
  /*static const String rokmetroTokenKey  = '_rokmetro_token';

  RokmetroToken get rokmetroToken {
    try {
      String jsonString = getString(rokmetroTokenKey);
      Map<String, dynamic> jsonData = AppJson.decodeMap(jsonString);
      return (jsonData != null) ? RokmetroToken.fromJson(jsonData) : null;
    } on Exception catch (e) { print(e.toString()); }
    return null;
  }

  set rokmetroToken(RokmetroToken value) {
    setString(rokmetroTokenKey, AppJson.encode(value?.toJson()));
  }*/

  // Disable Rokmetro auth
  /*static const String rokmetroUserKey  = '_rokmetro_user';

  RokmetroUser get rokmetroUser {
    try {
      String jsonString = getString(rokmetroUserKey);
      Map<String, dynamic> jsonData = AppJson.decodeMap(jsonString);
      return (jsonData != null) ? RokmetroUser.fromJson(jsonData) : null;
    } on Exception catch (e) { print(e.toString()); }
    return null;
  }

  set rokmetroUser(RokmetroUser value) {
    setString(rokmetroUserKey, AppJson.encode(value?.toJson()));
  }*/

  /////////////////
  // Language

  static const String currentLanguageKey  = 'current_language';

  String get currentLanguage {
    return getString(currentLanguageKey);
  }

  set currentLanguage(String value) {
    setString(currentLanguageKey, value);
  }

  //////////////
  // Permanent subscription

  static const String firebaseSubscriptionTopisKey  = 'firebase_subscription_topis';

  Set<String> get firebaseSubscriptionTopis {
    List<String> topicsList = getStringList(firebaseSubscriptionTopisKey);
    return (topicsList != null) ? Set.from(topicsList) : null;
  }

  set firebaseSubscriptionTopis(Set<String> value) {
    List<String> topicsList = (value != null) ? List.from(value) : null;
    setStringList(firebaseSubscriptionTopisKey, topicsList);
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
    return Organization.fromJson(AppJson.decode(getEncryptedString(_organiationKey)));
  }

  set organization(Organization organization) {
    setEncryptedString(_organiationKey, AppJson.encode(organization?.toJson()));
  }

  /////////////
  // Config

  static const String _configEnvKey = 'config_environment';

  String get configEnvironment {
    return getString(_configEnvKey);
  }

  set configEnvironment(String value) {
    setString(_configEnvKey, value);
  }

  /////////////
  // Health

  // Obsolete
  static const String _currentHealthCountyIdKey = 'health_current_county_id';
  
  String get currentHealthCountyId {
    return getString(_currentHealthCountyIdKey);
  }

  set currentHealthCountyId(String value) {
    setString(_currentHealthCountyIdKey, value);
  }

  static const String _lastHealthProviderKey = 'health_last_provider';

  HealthServiceProvider get lastHealthProvider {
    String storedProviderJson = getString(_lastHealthProviderKey);
    return  HealthServiceProvider.fromJson(storedProviderJson!=null ? json.decode(storedProviderJson) : null);
  }

  set lastHealthProvider(HealthServiceProvider value) {
    setString(_lastHealthProviderKey, value!=null? json.encode(value.toJson()) :value);
  }

  static const String _lastHealthCovid19StatusKey = 'health_last_covid19_status';

  String get lastHealthCovid19Status {
    return getString(_lastHealthCovid19StatusKey);
  }

  set lastHealthCovid19Status(String value) {
    setString(_lastHealthCovid19StatusKey, value);
  }

  static const String _lastHealthOsfTestDateKey = 'health_last_covid19_osf_test_date';

  DateTime get lastHealthOsfTestDateUtc {
    String dateString = getString(_lastHealthOsfTestDateKey);
    try { return (dateString != null) ? DateFormat('yyyy-MM-ddTHH:mm:ss').parse(dateString) : null; }
    catch (e) { print(e?.toString()); }
    return null;
  }

  set lastHealthOsfTestDateUtc(DateTime value) {
    String dateString = (value != null) ? DateFormat('yyyy-MM-ddTHH:mm:ss').format(value) : null;
    setString(_lastHealthOsfTestDateKey, dateString);
  }

  static const String _healthUserKey = 'health_user';

  String get healthUser {
    return getString(_healthUserKey);
  }

  set healthUser(String value) {
    setString(_healthUserKey, value);
  }

  static const String _healthUserStatusKey = 'health_user_status';

  String get healthUserStatus {
    return getString(_healthUserStatusKey);
  }

  set healthUserStatus(String value) {
    setString(_healthUserStatusKey, value);
  }

  static const String _healthUserOverrideKey = 'health_user_override';

  String get healthUserOverride {
    return getString(_healthUserOverrideKey, defaultValue: null);
  }

  set healthUserOverride(String value) {
    setString(_healthUserOverrideKey, value);
  }

  static const String _healthUserAccountIdKey = 'health_user_account_id';

  String get healthUserAccountId {
    return getString(_healthUserAccountIdKey);
  }

  set healthUserAccountId(String value) {
    setString(_healthUserAccountIdKey, value);
  }

  static const String _healthCountyKey = 'health_county';
  
  String get healthCounty {
    return getString(_healthCountyKey);
  }

  set healthCounty(String value) {
    setString(_healthCountyKey, value);
  }

  static const String _healthBuildingAccessRulesKey = 'health_building_access_rules';
  
  String get healthBuildingAccessRules {
    return getString(_healthBuildingAccessRulesKey);
  }

  set healthBuildingAccessRules(String value) {
    setString(_healthBuildingAccessRulesKey, value);
  }

  static const String _healthFamilyMembersKey = 'health_family_members';
  
  String get healthFamilyMembers {
    return getString(_healthFamilyMembersKey);
  }

  set healthFamilyMembers(String value) {
    setString(_healthFamilyMembersKey, value);
  }
  /////////////
  // Http Proxy

  static const String _httpProxyEnabledKey = 'http_proxy_enabled';

  bool get httpProxyEnabled {
    return getBool(_httpProxyEnabledKey, defaultValue: false);
  }

  set httpProxyEnabled(bool value) {
    setBool(_httpProxyEnabledKey, value);
  }

  static const String _httpProxyHostKey = 'http_proxy_host';

  String get httpProxyHost {
    return getString(_httpProxyHostKey);
  }

  set httpProxyHost(String value) {
    setString(_httpProxyHostKey, value);
  }

  static const String _httpProxyPortKey = 'http_proxy_port';

  String get httpProxyPort {
    return getString(_httpProxyPortKey);
  }

  set httpProxyPort(String value) {
    setString(_httpProxyPortKey, value);
  }

  /////////////
  // Test Encryption

  static const String _testEncryptionStringKey = 'test_encryption';
  
  String get testEncryptionString {
    return getEncryptedString(_testEncryptionStringKey);
  }

  set testEncryptionString(String value) {
    setEncryptedString(_testEncryptionStringKey, value);
  }

  /////////////
}
