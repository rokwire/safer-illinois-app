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
import 'package:illinois/model/Auth.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/model/UserData.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
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

  @override
  Future<void> initService() async {
    Log.d("Init Storage");
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  void deleteEverything(){
    for(String key in _sharedPreferences.getKeys()){
      if(key != _configEnvKey){  // skip selected environment
        _sharedPreferences.remove(key);
      }
    }
  }

  String _getStringWithName(String name, {String defaultValue}) {
    return _sharedPreferences.getString(name) ?? defaultValue;
  }

  void _setStringWithName(String name, String value) {
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

  // Notifications

  bool getNotifySetting(String name) {
    return _getBoolWithName(name, defaultValue: null);
  }

  void setNotifySetting(String name, bool value) {
    return _setBoolWithName(name, value);
  }

  /////////////
  // User

  static const String userKey  = 'user';

  UserData get userData {
    final String userToString = _getStringWithName(userKey);
    final Map<String, dynamic> userToJson = AppJson.decode(userToString);
    return (userToJson != null) ? UserData.fromJson(userToJson) : null;
  }

  set userData(UserData user) {
    String userToString = (user != null) ? json.encode(user) : null;
    _setStringWithName(userKey, userToString);
  }

  static const String localUserUuidKey  = 'user_local_uuid';

  String get localUserUuid {
    return _getStringWithName(localUserUuidKey);
  }

  set localUserUuid(String value) {
    _setStringWithName(localUserUuidKey, value);
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

  ////////////////////////////
  // Last Run Version

  static const String lastRunVersionKey  = 'last_run_version';

  String get lastRunVersion {
    return _getStringWithName(lastRunVersionKey);
  }

  set lastRunVersion(String value) {
    _setStringWithName(lastRunVersionKey, value);
  }

  ////////////////
  // Auth

  static const String authTokenKey  = '_auth_token';

  AuthToken get authToken {
    try {
      String jsonString = _getStringWithName(authTokenKey);
      dynamic jsonData = AppJson.decode(jsonString);
      return (jsonData != null) ? AuthToken.fromJson(jsonData) : null;
    } on Exception catch (e) { print(e.toString()); }
    return null;
  }

  set authToken(AuthToken value) {
    _setStringWithName(authTokenKey, value != null ? json.encode(value.toJson()) : null);
  }

  static const String authInfoKey  = '_auth_info';

  AuthInfo get authInfo {
    final String authInfoToString = _getStringWithName(authInfoKey);
    AuthInfo authInfo = AuthInfo.fromJson(AppJson.decode(authInfoToString));
    return authInfo;
  }

  set authInfo(AuthInfo value) {
    _setStringWithName(authInfoKey, value != null ? json.encode(value.toJson()) : null);
  }

  static const String authCardTimeKey  = '_auth_card_time';

  int get authCardTime {
    return _getIntWithName(authCardTimeKey);
  }

  set authCardTime(int value) {
    _setIntWithName(authCardTimeKey, value);
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

  static const String lastHealthCovid19StatusKey = 'health_last_covid19_status';

  String get lastHealthCovid19Status {
    return _getStringWithName(lastHealthCovid19StatusKey);
  }

  set lastHealthCovid19Status(String value) {
    _setStringWithName(lastHealthCovid19StatusKey, value);
  }

  static const String healthUserKey = 'health_user';

  String get healthUser {
    return _getStringWithName(healthUserKey);
  }

  set healthUser(String value) {
    _setStringWithName(healthUserKey, value);
  }

  static const String lastHealthCovid19OsfTestDateKey = 'health_last_covid19_osf_test_date';

  DateTime get lastHealthCovid19OsfTestDateUtc {
    String dateString = _getStringWithName(lastHealthCovid19OsfTestDateKey);
    try { return (dateString != null) ? DateFormat('yyyy-MM-ddTHH:mm:ss').parse(dateString) : null; }
    catch (e) { print(e?.toString()); }
    return null;
  }

  set lastHealthCovid19OsfTestDateUtc(DateTime value) {
    String dateString = (value != null) ? DateFormat('yyyy-MM-ddTHH:mm:ss').format(value) : null;
    _setStringWithName(lastHealthCovid19OsfTestDateKey, dateString);
  }

  static const String lastHealthStatusEvalKey  = '_health_last_status_eval';

  int get lastHealthStatusEval {
    return _getIntWithName(lastHealthStatusEvalKey, defaultValue: null);
  }

  set lastHealthStatusEval(int value) {
    _setIntWithName(lastHealthStatusEvalKey, value);
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
}
