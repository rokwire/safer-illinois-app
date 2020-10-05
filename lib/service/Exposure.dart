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
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:illinois/model/Exposure.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/BluetoothServices.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/utils/Utils.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class Exposure with Service implements NotificationsListener {

  // Notifications

  static const String notifyStartStop                   = "edu.illinois.rokwire.exposure.start_stop";
  static const String notifyTEKsUpdated                 = "edu.illinois.rokwire.exposure.teks.updated";
  static const String notifyExposureUpdated             = "edu.illinois.rokwire.exposure.expsure.updated";
  static const String notifyExposureThick               = "edu.illinois.rokwire.exposure.expsure.thick";

  // Native
  
  static const String _methodChannelName               = 'edu.illinois.covid/exposure';
  
  static const String _startMethodName                 = 'start';
  static const String _stopMethodName                  = 'stop';
  static const String _teksMethodName                  = 'TEKs';
  static const String _tekRPIsMethodName               = 'tekRPIs';
  static const String _expireTEKMethodName             = 'expireTEK';
  static const String _exposureRPIMethodName           = 'exposureRPILog';
  static const String _exposureRSSIMethodName          = 'exposureRSSILog';

  static const String _settingsParamName               = 'settings';
  static const String _tekParamName                    = 'tek';
  static const String _timestampParamName              = 'timestamp';
  static const String _expirestampParamName            = 'expirestamp';

  static const String _tecNotificationName              = 'tek';
  static const String _exposureNotificationName         = 'exposure';
  static const String _exposureThickNotificationName    = 'exposureThick';

  // Database

  static const String _databaseName                     = "exposures.db";
  static const int    _databaseVersion                  = 1;

  static const String _databaseExposureTable            = "Exposures";
  static const String _databaseExposureTimestampField   = "Timestamp";
  static const String _databaseExposureRPIField         = "RPI";
  static const String _databaseExposureDurationField    = "Duration";
  static const String _databaseExposureProcessedField   = "Processed";

  static const String _databaseRpiTable                 = "ExposureRpi";
  static const String _databaseRpiSessionIdField        = "SessionId";
  static const String _databaseRpiTEKField              = "TEK";
  static const String _databaseRpiTEKStartTimeField     = "TEKStartTime";
  static const String _databaseRpiRPIField              = "RPI";
  static const String _databaseRpiRPIStartTimeField     = "RPIStartTime";
  static const String _databaseRpiEventField            = "Event";
  
  static const String _databaseContactTable             = "ExposureContact";
  static const String _databaseContactSessionIdField    = "SessionId";
  static const String _databaseContactStartTimeField    = "StartTime";
  static const String _databaseContactDurationField     = "Duration";
  static const String _databaseContactRPIField          = "RPI";
  static const String _databaseContactSourceField       = "Source";
  static const String _databaseContactAddressField      = "Address";

  static const String _databaseRssiTable                = "ExposureRssi";
  static const String _databaseRssiSessionIdField       = "SessionId";
  static const String _databaseRssiTimestampField       = "Timestamp";
  static const String _databaseRssiRSSIField            = "RSSI";
  static const String _databaseRssiRPIField             = "RPI";
  static const String _databaseRssiSourceField          = "Source";
  static const String _databaseRssiAddressField         = "Address";

  static const String _databaseRowID                    = "rowid";

  // Time
  static const int _rpiRefreshInterval = (10 * 60 * 1000); // 10 min, in milisconds
  static const int _rpiCheckExposureBuffer = (30 * 60 * 1000); // 30 min as buffer time
  static const int _millisecondsInDay = 24 * 60 * 60 * 1000; // 1 day, in milliseconds
  
  // Data
  final MethodChannel _methodChannel = const MethodChannel(_methodChannelName);
  Database _database;
  
  bool     _serviceInitialized = false;

  bool     _pluginInitialized = false;
  bool     _isPluginStarted = false;
  Map<String, dynamic> _pluginSettings;
  
  Timer    _exposuresMonitorTimer;
  DateTime _pausedDateTime;

  bool     _checkingReport;
  bool     _checkingExposures;
  int      _exposureMinDuration;
  int      _reportTargetTimestamp;
  int      _lastReportTimestamp;

  int      _logSessionId;

  // Singletone instance

  static final Exposure _service = Exposure._internal();
  
  Exposure._internal() {
    _methodChannel.setMethodCallHandler(this._nativeCallback);
  }

  factory Exposure() {
    return _service;
  }

  // Service

  @override
  void createService() {
    NotificationService().subscribe(this, [
      BluetoothServices.notifyStatusChanged,
      Config.notifyConfigChanged,
      AppLivecycle.notifyStateChanged,
      Health.notifyUserUpdated,
      Health.notifyUserPrivateKeyUpdated,
      Auth.notifyLoggedOut,
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
    _closeDatabase();
    _destroyPlugin();
    _stopExposuresMonitor();
  }

  @override
  Future<void> initService() async {
    _reportTargetTimestamp = Storage().exposureReportTargetTimestamp;
    _lastReportTimestamp = Storage().exposureLastReportedTimestamp;

    await _openDatabase();
    
    _initializePlugin().then((_) {
      _pluginInitialized = true;
    });
    
    _updateExposureMinDuration();
    
    _serviceInitialized = true;
  }

  @override
  void initServiceUI() {
    checkExposures().then((_){
      _startExposuresMonitor();
    });
    checkReport();
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Storage(), Config(), Health()]);
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (_serviceInitialized) {
      if (name == Config.notifyConfigChanged) {
        _updatePlugin(forceRestart: true);
        _updateExposuresMonitor();
        _updateExposureMinDuration();
        checkReport();
      }
      else if (name == Health.notifyUserUpdated || name == Health.notifyUserPrivateKeyUpdated) {
        _updatePlugin();
        _updateExposuresMonitor();
        checkReport();        
      }
      else if (name == Auth.notifyLoggedOut) {
        _updatePlugin();
        _updateExposuresMonitor();
      }
      else if (name == BluetoothServices.notifyStatusChanged) {
        _updatePlugin();
      }
      else if (name == AppLivecycle.notifyStateChanged) {
        _onAppLivecycleStateChanged(param); 
      }
    }
  }

  void _onAppLivecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
      _stopExposuresMonitor();
    }
    else if (state == AppLifecycleState.resumed) {
      Duration pausedDuration = (_pausedDateTime != null) ? DateTime.now().difference(_pausedDateTime) : null;
      if ((pausedDuration != null) && (Config().refreshTimeout < pausedDuration.inSeconds)) {
        checkReport();
        checkExposures().then((_){
          _startExposuresMonitor();
        });
      }
      else {
        _startExposuresMonitor();
      }
    }
  }

  // Initialize and Destroy

  bool get _serviceEnabled {
    return  (Config().settings['covid19ExposureMonitorEnabled'] == true) &&
      (Health().userExposureNotification == true);
  }

  bool get _pluginEnabled {
    return (BluetoothServices().status == BluetoothStatus.PermissionAllowed) && _serviceEnabled;
  }

  Future<void> _initializePlugin() async {
    if (_pluginEnabled && !_isPluginStarted && _wasStarted) {
      await _nativeStart();
    }
  }

  Future<void> _destroyPlugin() async {
    if (_isPluginStarted) {
      await _nativeStop();
    }
  }

  Future<void> _updatePlugin({bool forceRestart}) async {
    if (_pluginInitialized) {
      if (_pluginEnabled && _isPluginStarted && (forceRestart == true)) {
        await _nativeStop();
      }
      if (_pluginEnabled && !_isPluginStarted && _wasStarted) {
        await _nativeStart();
      }
      else if (!_pluginEnabled && _isPluginStarted) {
        await _nativeStop();
      }
    }
  }

  // Method Channel

  Future<void> _nativeStart({Map<String, dynamic> settings}) async {
    if (settings == null) {
      settings = Config().settings;
    }
    if (await _methodChannel.invokeMethod(_startMethodName, { _settingsParamName: settings })) {
      _isPluginStarted = true;
      _pluginSettings = settings;
    }
  }

  Future<void> _nativeStop() async {
    await _methodChannel.invokeMethod(_stopMethodName);
    _isPluginStarted = false;
    _pluginSettings = null;
  }

  Future<void> _expireTEK() async {
    await _methodChannel.invokeMethod(_expireTEKMethodName);
  }

  Future<List<ExposureTEK>> loadTeks({int minStamp, int maxStamp}) async {
    List<ExposureTEK> teks;
    List<dynamic> json = await _methodChannel.invokeMethod(_teksMethodName);
    if (json != null) {
      teks = [];
      for (dynamic entry in json) {
        ExposureTEK tek;
        try { tek = ExposureTEK.fromJson((entry as Map)?.cast<String, dynamic>()); }
        catch(e) { print(e?.toString()); }
        if (((minStamp == null) || ((tek.timestamp != null) && (minStamp <= tek.timestamp))) &&
            ((maxStamp == null) || ((tek.timestamp != null) && (maxStamp >= tek.timestamp))))
        {
          teks.add(tek);
        }
      }
    }
    return teks;
  }

  Future<void> deleteTeks() async {
    await _methodChannel.invokeMethod(_teksMethodName, {
      'remove': true,
    });
  }

  Future<Map<String, int>> _loadTekRPIs(ExposureTEK tek) async {
    Map<dynamic, dynamic> result = await _methodChannel.invokeMethod(_tekRPIsMethodName, {
      _tekParamName : tek.tek,
      _timestampParamName: tek.timestamp,
      _expirestampParamName: tek.expirestamp,
    });
    return result?.cast<String, int>();
  }

  Future<dynamic> _nativeCallback(MethodCall call) async {
    if (call.method == _tecNotificationName) {
      NotificationService().notify(notifyTEKsUpdated, null);
      _clearExpiredLocalExposures();
    }
    else if (call.method == _exposureNotificationName) {
      _storeLocalExposure(call.arguments);
      _logContact(call.arguments);
    }
    else if (call.method == _exposureThickNotificationName) {
      NotificationService().notify(notifyExposureThick, call.arguments);
    }
    else if (call.method == _exposureRPIMethodName) {
      _logRpi(call.arguments);
    }
    else if (call.method == _exposureRSSIMethodName) {
      _logRssi(call.arguments);
    }
    return null;
  }

  // Database

  Future<void> _openDatabase() async {
    if (_database == null) {
      String databasePath = await getDatabasesPath();
      String databaseFile = join(databasePath, _databaseName);
      _database = await openDatabase(databaseFile, version: _databaseVersion, onCreate: (db, version) async {
        try { await db.execute("CREATE TABLE IF NOT EXISTS $_databaseExposureTable($_databaseExposureTimestampField INTEGER NOT NULL, $_databaseExposureRPIField TEXT NOT NULL, $_databaseExposureDurationField INTEGER NOT NULL, $_databaseExposureProcessedField INTEGER NOT NULL DEFAULT '0')",); } catch(e) { print(e?.toString()); }
        try { await db.execute("CREATE TABLE IF NOT EXISTS $_databaseRpiTable($_databaseRpiSessionIdField INTEGER, $_databaseRpiTEKField TEXT, $_databaseRpiTEKStartTimeField INTEGER, $_databaseRpiRPIField TEXT, $_databaseRpiRPIStartTimeField INTEGER, $_databaseRpiEventField TEXT)",); } catch(e) { print(e?.toString()); }
        try { await db.execute("CREATE TABLE IF NOT EXISTS $_databaseContactTable($_databaseContactSessionIdField INTEGER, $_databaseContactStartTimeField INTEGER, $_databaseContactDurationField INTEGER, $_databaseContactRPIField TEXT, $_databaseContactSourceField TEXT, $_databaseContactAddressField TEXT)",); } catch(e) { print(e?.toString()); }
        try { await db.execute("CREATE TABLE IF NOT EXISTS $_databaseRssiTable($_databaseRssiSessionIdField INTEGER, $_databaseRssiTimestampField INTEGER, $_databaseRssiRSSIField INTEGER, $_databaseRssiRPIField TEXT, $_databaseRssiSourceField TEXT, $_databaseRssiAddressField TEXT)",); } catch(e) { print(e?.toString()); }
      });
    }
  }

  void _closeDatabase() {
    if (_database != null) {
      try { _database.close(); } catch(e) { print(e?.toString()); }
      _database = null;
    }
  }

  // Public API

  void start({ Map<dynamic, dynamic> settings }) {
    if (_pluginEnabled && !_isPluginStarted) {
      _nativeStart(settings: settings).then((_) {
        _wasStarted = true;
        NotificationService().notify(notifyStartStop, null);
      });
    }
  }

  void stop() {
    if (_isPluginStarted) {
      _nativeStop().then((_) {
        _wasStarted = false;
        NotificationService().notify(notifyStartStop, null);
      });
    }
  }

  Future<void> deleteUser() async {
    _stopExposuresMonitor();
    await deleteTeks();
    await clearLocalExposures();
    await _destroyPlugin();
    Storage().exposureStarted = null;
    Storage().exposureLastReportedTimestamp = null;
  }

  bool get isEnabled {
    return _pluginEnabled;
  }

  bool get isStarted {
    return _isPluginStarted;
  }

  Map<String, dynamic> get startSettings {
    return _pluginSettings;
  }

  bool get _wasStarted {
    return Storage().exposureStarted;
  }

  set _wasStarted(bool value) {
    Storage().exposureStarted = value;
  }

  static int get _currentTimestamp {
    return DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  static int get thresholdTimestamp {
    return getThresholdTimestamp(origin: _currentTimestamp);
  }

  static int getThresholdTimestamp({int origin}) {
    // Two weeks before origin is standard thresold for checking exposures
    int midnightTimestamp = (origin ~/ _millisecondsInDay) * _millisecondsInDay;
    int twoWeeksAgoMidnightTimestamp = midnightTimestamp - _exposureExpireInterval;
    return twoWeeksAgoMidnightTimestamp;
  }

  static int get _exposureExpireInterval {
    return (Config().settings['covid19ExposureExpireDays'] ?? 14) * _millisecondsInDay;
  }

  static Set<String> get _negativeTestCategories {
    //TMP: return Set.from(["antibody.positive", "PCR.negative", "SAR.negative"]);
    dynamic list = Config().settings['covid19ExposureNegativeTestCategories'];
    return (list is List) ? Set.from(list) : null;
  }

  // Local Exposures

  Future<List<ExposureRecord>> loadLocalExposures({int timestamp, bool processed }) async {
    List<ExposureRecord> result;

    String query = "SELECT $_databaseRowID, $_databaseExposureTimestampField, $_databaseExposureRPIField, $_databaseExposureDurationField FROM $_databaseExposureTable";
    
    String where = '';
    if (timestamp != null) {
      if (where.isNotEmpty) {
        where += ' AND ';
      }
      where += "$_databaseExposureTimestampField >= $timestamp";  
    }
    if (processed != null) {
      if (where.isNotEmpty) {
        where += ' AND ';
      }
      where += "$_databaseExposureProcessedField ${processed ? '<>' : '='} 0";  
    }
    if (where.isNotEmpty) {
      query += " WHERE $where";
    }
    
    query += " ORDER BY $_databaseExposureTimestampField DESC";

    List<Map<String, dynamic>> records;
    try { records = (_database != null) ? await _database.rawQuery(query) : null; } catch (e) { print(e?.toString()); }
    if (records != null) {
      result = [];
      for (Map<String, dynamic> record in records) {
        result.add(ExposureRecord(
          id:        record['$_databaseRowID'],
          timestamp: record['$_databaseExposureTimestampField'],
          rpi:       record['$_databaseExposureRPIField'],
          duration:  record['$_databaseExposureDurationField'],
        ));
      }
    }

    return result;
  }

  Future<void> clearLocalExposures() async {
    if (_database != null) {
      try {
        await _database.execute("DELETE FROM $_databaseExposureTable",);
        NotificationService().notify(notifyExposureUpdated, null);
      }
      catch(e) { print(e?.toString()); }
    }
  }

  /* clean up recorded RPI exposures picked up more than 14 days ago
   * This method should be called strictly in "notifyTEK"
   * so that every time there is a TEK update (typically per day),
   * old RPI will be pruned.
   */
  Future<void> _clearExpiredLocalExposures() async {
    if (_database != null) {
      try {
        int currentTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
        int expireTimestamp = currentTimestamp - _exposureExpireInterval;
        await _database.execute("DELETE FROM $_databaseExposureTable where $_databaseExposureTimestampField < $expireTimestamp",);
      } catch (e) { print(e?.toString()); }
    }
  }

  Future<void> _markLocalExposureProcessed(Set<int> exposureIds) async {
    if ((_database != null) && exposureIds.isNotEmpty) {
      String exposureIdsList = '';
      for (int exposureId in exposureIds) {
        if (exposureIdsList.isNotEmpty) {
          exposureIdsList += ', ';
        }
        exposureIdsList += '$exposureId';
      }
      try {
        await _database.execute("UPDATE $_databaseExposureTable SET $_databaseExposureProcessedField = 1 WHERE $_databaseRowID IN ($exposureIdsList)",);
        NotificationService().notify(notifyExposureUpdated, null);
      }
      catch(e) { print(e?.toString()); }
    }
  }

  Future<int> _storeLocalExposure(Map<dynamic, dynamic> exposure) async {
    int result = -1;
    String rpi = (exposure != null) ? exposure['rpi'] : null;
    int timestamp = (exposure != null) ? exposure['timestamp'] : null;
    int duration = (exposure != null) ? exposure['duration'] : null;
    Log.d('Exposure: Detected Exposure RPI: {$rpi} / duration: $duration ms');

    if ((_database != null) && (rpi != null)) {
      try {
        result = await _database.insert(_databaseExposureTable, {
          _databaseExposureTimestampField : timestamp ?? 0,
          _databaseExposureRPIField : rpi ?? "",
          _databaseExposureDurationField : duration ?? 0,
        });
        if (0 <= result) {
          NotificationService().notify(notifyExposureUpdated, null);
        }
      }
      catch(e) { print(e?.toString()); }
    }
    return result;
  }

  Future<void> _logContact(Map<dynamic, dynamic> exposure) async {
    if ((_logSessionId != null) && (_database != null) && (exposure != null)) {
      String rpi = (exposure != null) ? exposure['rpi'] : null;
      int timestamp = (exposure != null) ? exposure['timestamp'] : null;
      int duration = (exposure != null) ? exposure['duration'] : null;
      bool isiOSRecord = (exposure != null) ? exposure['isiOSRecord'] : null;
      String source = (isiOSRecord == true) ? 'iOSRecord' : 'AndroidRecord';
      String peripheralUuid = (exposure != null) ? exposure['peripheralUuid'] : null;
      //int endTimestamp = (exposure != null) ? exposure['endTimestamp'] : null;

      try {
        await _database.insert(_databaseContactTable, {
          _databaseContactSessionIdField: _logSessionId,
          _databaseContactStartTimeField: timestamp,
          _databaseContactDurationField: duration,
          _databaseContactRPIField: rpi,
          _databaseContactSourceField: source,
          _databaseContactAddressField: peripheralUuid,
        });
      } catch (e) {
        print(e?.toString());
      }
    }
  }

  Future<void> _logRpi(Map<dynamic, dynamic> rpiUpdates) async {
    if ((_logSessionId != null) && (_database != null) && (rpiUpdates != null)) {
      String rpi = (rpiUpdates != null) ? rpiUpdates['rpi'] : null;
      String updateType = (rpiUpdates != null) ? rpiUpdates['updateType'] : null;
      int updateTime = (rpiUpdates != null) ? rpiUpdates['timestamp'] : null;
      int _i = (rpiUpdates != null) ? rpiUpdates['_i'] : null;
      String tekString = (rpiUpdates != null) ? rpiUpdates['tek'] : null;
      var _iTimestamp = _i * _rpiRefreshInterval;

      try {
        await _database.insert(_databaseRpiTable, {
          _databaseRpiSessionIdField:   _logSessionId,
          _databaseRpiTEKField:          tekString,
          _databaseRpiTEKStartTimeField: _iTimestamp,
          _databaseRpiRPIField:          rpi,
          _databaseRpiRPIStartTimeField: updateTime,
          _databaseRpiEventField:        updateType,
        });
      }
      catch(e) { print(e?.toString()); }
    }
  }

  Future<void> _logRssi(Map<dynamic, dynamic> rssi) async {
    if ((_logSessionId != null) && (_database != null) && (rssi != null)) {
      int timestamp = (rssi != null) ? rssi['timestamp'] : null;
      String rpi = (rssi != null) ? rssi['rpi'] : null;
      int rssiVal = (rssi != null) ? rssi['rssi'] : null;
      String address = (rssi != null) ? rssi['address'] : null;
      bool isiOSRecord = (rssi != null) ? rssi['isiOSRecord'] : null;
      String source = (isiOSRecord == true) ? 'iOSRecord' : 'AndroidRecord';

      try {
        await _database.insert(_databaseRssiTable, {
          _databaseRssiSessionIdField: _logSessionId,
          _databaseRssiTimestampField: timestamp,
          _databaseRssiRSSIField: rssiVal,
          _databaseRssiRPIField: rpi,
          _databaseRssiSourceField: source,
          _databaseRssiAddressField: address,
        });
      }
      catch(e) { print(e?.toString()); }
    }
  }

  // Networking

  Future<bool> reportTEKs(List<ExposureTEK> teks) async {
    String url = "${Config().healthUrl}/covid19/trace/report";
    String post = AppJson.encode(ExposureTEK.listToJson(teks));
    Response response = await Network().post(url, body: post, auth: NetworkAuth.App);
    return (response?.statusCode == 200);
  }

  Future<List<ExposureTEK>> loadReportedTEKs({int timestamp, int dateAdded}) async {
    String url = "${Config().healthUrl}/covid19/trace/exposures";
    
    String params = '';
    if (timestamp != null) {
      if (params.isNotEmpty) {
        params += '&';
      }
      params += "timestamp=$timestamp";
    }
    if (dateAdded != null) {
      if (params.isNotEmpty) {
        params += '&';
      }
      params += "date-added=$dateAdded";
    }
    if (params.isNotEmpty) {
      url += '?$params';
    }

    Response response = await Network().get(url, auth: NetworkAuth.App);
    String responseString = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseString != null) ? AppJson.decodeList(responseString) : null;
    return (responseJson != null) ? ExposureTEK.listFromJson(responseJson) : null;
  }

  // Report

  set reportTargetTimestamp(int value) {
    if (_reportTargetTimestamp != value) {
      Storage().exposureReportTargetTimestamp = _reportTargetTimestamp = value;
      checkReport();
    }
  }

  Future<int> checkReport() async {

    if (!_serviceEnabled) {
      return 0;
    }

    dynamic exposureActiveDays = Config().settings['covid19ExposureActiveDays'] ?? 0;
    int activeInterval = (exposureActiveDays is int) ? (exposureActiveDays * _millisecondsInDay) : null;

    if (activeInterval != null) {
      
      if (_reportTargetTimestamp == null) {
        return 0;
      }
      else if ((Health().lastCovid19Status != kCovid19HealthStatusRed) && (_lastReportTimestamp != null) && (_reportTargetTimestamp < _lastReportTimestamp)) {
        Storage().exposureReportTargetTimestamp = _reportTargetTimestamp = null;
        await _expireTEK(); 
        return 0;
      }
    }
    else {
      if (Health().lastCovid19Status != kCovid19HealthStatusRed) {
        return 0;
      }
    }

    if (_checkingReport == true) {
      return null;
    }

    Log.d('Exposure: Checking local TEKs to report...');
    _checkingReport = true;

    List<Covid19History> histories = await Health().loadCovid19History();
    HealthRulesSet rules = await Health().loadRules2();
    Set<String> negativeTestCategories = _negativeTestCategories;

    int minTimestamp, maxTimestamp, currentTimestamp = _currentTimestamp;
    if (activeInterval != null) {

      minTimestamp = getThresholdTimestamp(origin: _reportTargetTimestamp); // two weeks before the target;
      int recentTestTimestamp = _findMostRecentNegativeTestTimestamp(histories: histories, rules: rules, negativeTestCategories: negativeTestCategories, minTimestamp: minTimestamp, maxTimestamp: _reportTargetTimestamp);
      if ((recentTestTimestamp != null) && (minTimestamp < recentTestTimestamp)) {
        minTimestamp = recentTestTimestamp; // not earlier than the last negative test result
      }
      if ((_lastReportTimestamp != null) && (minTimestamp < _lastReportTimestamp)) {
        minTimestamp = _lastReportTimestamp; // not earlier since the last report
      }
      
      maxTimestamp = _reportTargetTimestamp + activeInterval;
      int earlyTestTimestamp = _findEarlierNegativeTestTimestamp(histories: histories, rules: rules, negativeTestCategories: negativeTestCategories, minTimestamp: _reportTargetTimestamp, maxTimestamp: maxTimestamp);
      if ((earlyTestTimestamp != null) && (earlyTestTimestamp < maxTimestamp)) {
        maxTimestamp = earlyTestTimestamp;
      }
      if (currentTimestamp < maxTimestamp) {
        maxTimestamp = currentTimestamp;    // not later than now
      }
    }
    else {
      minTimestamp = getThresholdTimestamp(origin: currentTimestamp);
      int recentTestTimestamp = _findMostRecentNegativeTestTimestamp(histories: histories, rules: rules, negativeTestCategories: negativeTestCategories, minTimestamp: minTimestamp, maxTimestamp: currentTimestamp);
      if ((recentTestTimestamp != null) && (minTimestamp < recentTestTimestamp)) {
        minTimestamp = recentTestTimestamp; // not earlier than the last negative test result
      }
      if ((_lastReportTimestamp != null) && (minTimestamp < _lastReportTimestamp)) {
        minTimestamp = _lastReportTimestamp;
      }

      maxTimestamp = currentTimestamp;
    }

    int result;
    List<ExposureTEK> teks = await loadTeks(minStamp: minTimestamp, maxStamp: maxTimestamp);
    if (teks == null) {
      Log.d('Failed to load local TEKs');
      result = null;
    }
    else if (teks.isEmpty) {
      Log.d('No local TEKs newer than $_reportTargetTimestamp.');
      Storage().exposureLastReportedTimestamp = _lastReportTimestamp = maxTimestamp;
      result = 0;
    }
    else if (!await reportTEKs(teks)) {
      Log.d('Failed to report ${teks.length} local TEKs');
      result = null;
    }
    else {
      Log.d('Reported ${teks.length} local TEKs');
      Analytics().logHealth(action: Analytics.LogHealthReportExposuresAction);
      Storage().exposureLastReportedTimestamp = _lastReportTimestamp = maxTimestamp;
      result = teks.length;
    }

    // Check whether to stop processing
    if ((activeInterval != null) && (_reportTargetTimestamp != null) && (_lastReportTimestamp != null) && ((_reportTargetTimestamp + activeInterval) <= _lastReportTimestamp)) {
      Storage().exposureReportTargetTimestamp = _reportTargetTimestamp = null;
      await _expireTEK(); 
    }

    _checkingReport = null;
    return result;
  }

  int _findMostRecentNegativeTestTimestamp({List<Covid19History> histories, HealthRulesSet rules, Set<String> negativeTestCategories, int minTimestamp, int maxTimestamp}) {
    if ((histories != null) && (rules != null) && (negativeTestCategories != null)) {
      // start from newest
      for (int index = 0; index < histories.length; index++) {
        Covid19History history = histories[index];
        int historyTimestamp = (history.dateUtc != null) ? history.dateUtc.millisecondsSinceEpoch : null;
        if (historyTimestamp != null) {
          if ((maxTimestamp != null) && (maxTimestamp < historyTimestamp)) {
            continue;
          }
          if ((minTimestamp != null) && (historyTimestamp < minTimestamp)) {
            break;
          }
          HealthTestRuleResult testRuleResult = history.isTestVerified ? rules.tests.matchRuleResult(blob: history?.blob) : null;
          if ((testRuleResult?.category != null) && negativeTestCategories.contains(testRuleResult.category)) {
            return historyTimestamp;
          }
        }
      }
    }
    return null;
  }

  int _findEarlierNegativeTestTimestamp({List<Covid19History> histories, HealthRulesSet rules, Set<String> negativeTestCategories, int minTimestamp, int maxTimestamp}) {
    if ((histories != null) && (rules != null) && (negativeTestCategories != null)) {
      // start from oldest
      for (int index = histories.length - 1; 0 <= index; index--) {
        Covid19History history = histories[index];
        int historyTimestamp = (history.dateUtc != null) ? history.dateUtc.millisecondsSinceEpoch : null;
        if (historyTimestamp != null) {
          if ((minTimestamp != null) && (historyTimestamp < minTimestamp)) {
            continue;
          }
          if ((maxTimestamp != null) && (maxTimestamp < historyTimestamp)) {
            break;
          }
          HealthTestRuleResult testRuleResult = history.isTestVerified ? rules.tests.matchRuleResult(blob: history?.blob) : null;
          if ((testRuleResult?.category != null) && negativeTestCategories.contains(testRuleResult.category)) {
            return historyTimestamp;
          }
        }
      }
    }
    return null;
  }

  // Monitor

  void _startExposuresMonitor() {
    if (_serviceEnabled && (_exposuresMonitorTimer == null)) {
      int monitorInterval = Config().settings['covid19ExposureMonitorTimeInterval'] ?? 900;
      _exposuresMonitorTimer = Timer(Duration(seconds: monitorInterval), checkExposures);
    }
  }

  void _stopExposuresMonitor() {
    if (_exposuresMonitorTimer != null) {
      _exposuresMonitorTimer.cancel();
      _exposuresMonitorTimer = null;
    }
  }

  void _updateExposuresMonitor() {
    if (_serviceEnabled && (_exposuresMonitorTimer == null)) {
      checkExposures().then((_){
        _startExposuresMonitor();
      });
    }
    else if (!_serviceEnabled && (_exposuresMonitorTimer != null)){
      _stopExposuresMonitor();
    }
  }

  int get exposureMinDuration {
    return _exposureMinDuration ~/ 1000;
  }

  set exposureMinDuration(int value) {
    if (value != null) {
      _exposureMinDuration = value * 1000;
    }
    else {
      _updateExposureMinDuration();
    }
  }

  void _updateExposureMinDuration() {
    _exposureMinDuration    = (Config().settings['covid19ExposureServiceMinDuration']    ?? 7200) * 1000;
  }

  Future<int> checkExposures() async {
    if (!_serviceEnabled || (_checkingExposures == true)) {
      return null;
    }
    
    Log.d('Exposure: Checking Infected Exposures...');

    _checkingExposures = true;
    int thresholdTimestamp = Exposure.thresholdTimestamp;

    List<ExposureRecord> exposures = await Exposure().loadLocalExposures(timestamp: thresholdTimestamp, processed: false);
    if (exposures == null) {
      _checkingExposures = null; 
      Log.d('Failed to load local exposures.');
      return null;
    }
    else if (exposures.isEmpty) {
      _checkingExposures = null; 
      Log.d('No local exposures for processing.');
      return 0;
    }
    else {
      Log.d('Processing ${exposures.length} exposures newer than $thresholdTimestamp.');
    }
 
    List<ExposureTEK> reportedTEKs = await loadReportedTEKs(timestamp: thresholdTimestamp);
    if (reportedTEKs == null) {
      Log.d('Failed to load reported TEKs.');
      _checkingExposures = null; 
      return null;
    }
    else if (reportedTEKs.isEmpty) {
      Log.d('No TEKs newer than $thresholdTimestamp reported.');
      _checkingExposures = null; 
      return 0;
    }
    else {
      Log.d('Processing ${reportedTEKs.length} TEKs newer than $thresholdTimestamp reported.');
    }

    List<Covid19History> histories = await Health().loadCovid19History();

    Analytics().logHealth(action: Analytics.LogHealthCheckExposuresAction);

    int detected = 0;
    List<Covid19History> results;

    
    // Map<int, int> scoringExposures = new Map<int, int>;
    // key = time interval, value = number of rpis in that time interval
    Map<int, Set<String>> scoringExposures = new Map<int, Set<String>>(); 
    int scoringDayThreshold = _evalScoringDayThreshold(histories: histories);

    for (ExposureTEK tek in reportedTEKs) {
      Map<String, int> rpisMap = await _loadTekRPIs(tek);
      if (rpisMap != null) {
        Set<String> rpisSet = Set.from(rpisMap.keys);
        Set<int> detectedExposures;

        DateTime exposureDateUtc;
        int exposureDuration = 0;
        for (ExposureRecord exposure in exposures) {
          if (rpisSet.contains(exposure.rpi) &&
              ((exposure.timestamp + _rpiCheckExposureBuffer) >= rpisMap[exposure.rpi]) &&
              ((exposure.timestamp - _rpiCheckExposureBuffer - _rpiRefreshInterval) < rpisMap[exposure.rpi])
          ) {
            DateTime exposureRecordDateUtc = exposure.dateUtc;
            if ((exposureRecordDateUtc != null) && ((exposureDateUtc == null) || exposureRecordDateUtc.isBefore(exposureDateUtc))) {
              exposureDateUtc = exposureRecordDateUtc;
            }
            exposureDuration += exposure.duration;
            if (detectedExposures == null) {
              detectedExposures = Set<int>();
            }
            detectedExposures.add(exposure.id);

            // increment the exposure in that time interval
            int intervalNum = exposure.timestamp ~/ _rpiRefreshInterval;
            if (intervalNum >= scoringDayThreshold) {
                // filter out the date before the day threshold
                Set<String> durationRPISet = scoringExposures[intervalNum];
                if (durationRPISet == null) {
                  scoringExposures[intervalNum] = durationRPISet = Set<String>();
                }
                durationRPISet.add(exposure.rpi);
            }
          }
        }

        if ((exposureDateUtc != null) && (_exposureMinDuration <= exposureDuration)) {
          Covid19History result;  
          
          Covid19History history = Covid19History.traceInList(histories, tek: tek.tek);
          if (history != null) {
            if ((history.dateUtc != null) && history.dateUtc.isBefore(exposureDateUtc)) {
              exposureDateUtc = history.dateUtc;
            }
            if (history.blob?.traceDuration != null) {
              exposureDuration += history.blob?.traceDuration;
            }

            result = await Health().updateCovid19History(
              id: history.id,
              dateUtc: exposureDateUtc,
              type: Covid19HistoryType.contactTrace,
              blob: Covid19HistoryBlob(
                traceDuration: exposureDuration,
                traceTEK: tek.tek
              ));
          }
          else {
            result = await Health().addCovid19History(
              dateUtc: exposureDateUtc,
              type: Covid19HistoryType.contactTrace,
              blob: Covid19HistoryBlob(
                traceDuration: exposureDuration,
                traceTEK: tek.tek
              ));
          }

          if (result != null) {
            _markLocalExposureProcessed(detectedExposures);
            if (results == null) {
              results = List<Covid19History>();
            }
            results.add(result);
          }
        }
      }
    }

    if (results != null) {
      NotificationService().notify(Health.notifyHistoryUpdated, null);

      String lastHealthStatus = Health().lastCovid19Status;
      String newHealthStatus = lastHealthStatus;
      Covid19Status status = await Health().updateStatusFromHistory();
      if (covid19HealthStatusIsValid(status?.blob?.healthStatus)) {
        newHealthStatus = status?.blob?.healthStatus;
      }

      for (Covid19History result in results) {
        Analytics().logHealth(
          action: Analytics.LogHealthContactTraceProcessedAction,
          status: newHealthStatus,
          prevStatus: lastHealthStatus,
          attributes: {
            Analytics.LogHealthDurationName: result.blob.traceDuration,
            Analytics.LogHealthExposureTimestampName: result.dateUtc?.toIso8601String(),
        });
      }
    }

    Log.d('Detected: $detected Processed: ${results?.length ?? 0}');

    // each time duration = 10mins. cumulative duration = 10 * #people in that interval
    // finish searching, try to sum all duration:
    // Zero the dose only after 2 zero intervals
    // trigger the exposure notification only after there is a does above the threshold.
    Log.d("scoringExposures = $scoringExposures");
    int scoringStartTime = -1, scoringEndTime = -1;
    bool scoringIsExposured = false;
    if (scoringExposures.isNotEmpty) {
      
      // there is a match
      
      // sort the time interval in ascending order 
      List<int> enIntervalNumberList = List.from(scoringExposures.keys);
      enIntervalNumberList.sort(); 
      
      scoringStartTime = enIntervalNumberList[0];
      int lastKey = enIntervalNumberList[0] - 1;
      int tempSum = 0;
      
      for (int k in enIntervalNumberList) {
        // loop all time interval
        if (k - lastKey <= 1) {
          // consective time interval
          tempSum += scoringExposures[k].length * 10;
        }
        else {
          // Zero the dose only after 2 zero interval
          Log.d("tempSum = $tempSum");
          scoringStartTime = k;
          tempSum = scoringExposures[k].length * 10;
        }
        lastKey = k;
        
        if (tempSum > _exposureMinDuration) {
          scoringIsExposured = true;
          scoringEndTime = k;
          Log.d("Above the threshold! Trigger exposure notification");
          break;
        }
      }
      Log.d("tempSum = $tempSum");
    }
    
    // if isexposure = false, then scoringStartTime and scoringEndTime are meaningless
    Log.d("is exposure = $scoringIsExposured, start = $scoringStartTime, end = $scoringEndTime");

    _checkingExposures = null; 
    return detected;
  }

  int _evalScoringDayThreshold({List<Covid19History> histories}) {
    int scoringDateTimestamp;
    Covid19History lastTest = Covid19History.mostRecentTest(histories);
    DateTime lastTestDateUtc = lastTest?.dateUtc;
    if (lastTestDateUtc != null) {
      int lastTestTimestamp = lastTestDateUtc.millisecondsSinceEpoch;
      scoringDateTimestamp = lastTestTimestamp - _millisecondsInDay; // a day before last test timestamp
    }
    else {
      int currentTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      int midnightTimestamp = (currentTimestamp ~/ _millisecondsInDay) * _millisecondsInDay;
      scoringDateTimestamp = midnightTimestamp - (5 * _millisecondsInDay); // five days ago midnight timestamp
    }
    return scoringDateTimestamp ~/ _rpiRefreshInterval;
  }

  // Logging
  
  void startLogSession(int sessionId) {
    _logSessionId = sessionId;
  }

  void endLogSession(String deviceId, bool isAndroid) {
    if (_logSessionId != null) {
      _postSessionData(sessionId: _logSessionId, deviceId: deviceId, isAndroid: isAndroid);
      _logSessionId = null;
    }
  }

  Future<bool> _postSessionData({int sessionId, String deviceId, bool isAndroid}) async {
    List<Map<String, dynamic>> recordRssi;
    String rssiQuery = "SELECT * FROM $_databaseRssiTable WHERE $_databaseRssiSessionIdField = $sessionId";
    try { recordRssi = (_database != null) ? await _database.rawQuery(rssiQuery) : null; } catch (e) { print(e?.toString()); }

    List<Map<String, dynamic>> recordContact;
    String contactQuery = "SELECT * FROM $_databaseContactTable WHERE $_databaseContactSessionIdField = $sessionId";
    try { recordContact = (_database != null) ? await _database.rawQuery(contactQuery) : null; } catch (e) { print(e?.toString()); }

    List<Map<String, dynamic>> recordRpi;
    String rpiQuery = "SELECT * FROM $_databaseRpiTable WHERE $_databaseRpiSessionIdField = $sessionId";
    try { recordRpi = (_database != null) ? await _database.rawQuery(rpiQuery) : null; } catch (e) { print(e?.toString()); }

    Map<String, dynamic> upload = {
      "deviceID": deviceId,
      "isAndroid": isAndroid,
      "contact": recordContact,
      "rpi": recordRpi,
      "rssi": recordRssi
    };
    Response response = await Network().post(
        'http://ec2-18-191-37-235.us-east-2.compute.amazonaws.com:8003/PostSessionData',
        body: AppJson.encode(upload),
        auth: NetworkAuth.App);
    return response?.statusCode == 200;
  }



}