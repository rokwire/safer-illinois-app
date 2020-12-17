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

import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/UserProfile.dart';
import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';
import 'package:intl/intl.dart';
import "package:pointycastle/export.dart";


////////////////////////////////
// HealthStatus

class HealthStatus {
  final String id;
  final String accountId;
  final DateTime dateUtc;
  final String encryptedKey;
  final String encryptedBlob;
  HealthStatusBlob blob;

  HealthStatus({this.id, this.accountId, this.dateUtc, this.encryptedKey, this.encryptedBlob, this.blob});

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthStatus(
      id: json['id'],
      accountId: json['account_id'],
      dateUtc: healthDateTimeFromString(json['date']),
      encryptedKey: json['encrypted_key'],
      encryptedBlob: json['encrypted_blob'],
        ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'date': healthDateTimeToString(dateUtc),
      'encrypted_key': encryptedKey,
      'encrypted_blob': encryptedBlob,
    };
  }

  bool operator ==(o) {
    return (o is HealthStatus) &&
      (o.id == id) &&
      (o.accountId == accountId) &&
      (o.dateUtc == dateUtc) &&
      (o.encryptedKey == encryptedKey) &&
      (o.encryptedBlob == encryptedBlob);
  }

  int get hashCode =>
    (id?.hashCode ?? 0) ^
    (accountId?.hashCode ?? 0) ^
    (dateUtc?.hashCode ?? 0) ^
    (encryptedKey?.hashCode ?? 0) ^
    (encryptedBlob?.hashCode ?? 0);

  static Future<HealthStatus> decryptedFromJson(Map<String, dynamic> json, PrivateKey privateKey) async {
    try {
      HealthStatus value = HealthStatus.fromJson(json);
      if ((value != null) && (value.encryptedKey != null) && (value.encryptedBlob != null) && (privateKey != null)) {
        String blobString = await compute(_decryptBlob, {
          'encryptedKey': value.encryptedKey,
          'encryptedBlob': value.encryptedBlob,
          'privateKey': privateKey
        });
        value.blob = HealthStatusBlob.fromJson(AppJson.decodeMap(blobString));
      }
      return value;
    }
    catch(e) { print(e?.toString()); }
    return null;
  }

  Future<HealthStatus> encrypted(PublicKey publicKey) async {
    Map<String, dynamic> encrypted = await compute(_encryptBlob, {
      'blob': AppJson.encode(blob?.toJson()),
      'publicKey': publicKey
    });
    return HealthStatus(
      id: id,
      accountId: accountId,
      dateUtc: dateUtc,
      encryptedKey: encrypted['encryptedKey'],
      encryptedBlob: encrypted['encryptedBlob'],
    );
  }
}

///////////////////////////////
// HealthStatusBlob

class HealthStatusBlob {

  final String code;
  final int priority;

  final String nextStep;
  final String nextStepHtml;
  final DateTime nextStepDateUtc;

  final String eventExplanation;
  final String eventExplanationHtml;

  final String reason;
  final String warning;

  final dynamic fcmTopic;

  final HealthHistoryBlob historyBlob;

  static const String _nextStepDateMacro = '{next_step_date}';
  static const String _nextStepDateFormat = 'EEEE, MMM d';

  HealthStatusBlob({this.code, this.priority, this.nextStep, this.nextStepHtml, this.nextStepDateUtc, this.eventExplanation, this.eventExplanationHtml, this.reason, this.warning, this.fcmTopic, this.historyBlob});

  factory HealthStatusBlob.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthStatusBlob(
      code: json['code'] ?? json['health_status'],
      priority: json['priority'],
      nextStep: json['next_step'],
      nextStepHtml: json['next_step_html'],
      nextStepDateUtc: healthDateTimeFromString(json['next_step_date']),
      eventExplanation: json['event_explanation'],
      eventExplanationHtml: json['event_explanation_html'],
      reason: json['reason'],
      warning: json['warning'],
      fcmTopic: json['fcm_topic'],
      historyBlob: HealthHistoryBlob.fromJson(json['history_blob']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'priority': priority,
      'next_step': nextStep,
      'next_step_html': nextStepHtml,
      'next_step_date': healthDateTimeToString(nextStepDateUtc),
      'event_explanation': eventExplanation,
      'event_explanation_html': eventExplanationHtml,
      'reason': reason,
      'warning': warning,
      'fcm_topic': fcmTopic,
      'history_blob': historyBlob?.toJson(),
    };
  }

  bool operator ==(o) {
    return (o is HealthStatusBlob) &&
      (o.code == code) &&
      (o.priority == priority) &&
      (o.nextStep == nextStep) &&
      (o.nextStepHtml == nextStepHtml) &&
      (o.nextStepDateUtc == nextStepDateUtc) &&
      (o.eventExplanation == eventExplanation) &&
      (o.eventExplanationHtml == eventExplanationHtml) &&
      (o.reason == reason) &&
      (o.warning == warning) &&
      DeepCollectionEquality().equals(o.fcmTopic, fcmTopic) &&
      (o.historyBlob == historyBlob);
  }

  int get hashCode =>
    (code?.hashCode ?? 0) ^
    (priority?.hashCode ?? 0) ^
    (nextStep?.hashCode ?? 0) ^
    (nextStepHtml?.hashCode ?? 0) ^
    (nextStepDateUtc?.hashCode ?? 0) ^
    (eventExplanation?.hashCode ?? 0) ^
    (eventExplanationHtml?.hashCode ?? 0) ^
    (reason?.hashCode ?? 0) ^
    (warning?.hashCode ?? 0) ^
    (DeepCollectionEquality().hash(fcmTopic) ?? 0) ^
    (historyBlob?.hashCode ?? 0);

  String get displayNextStep {
    return _processMacros(nextStep);
  }

  String get displayNextStepHtml {
    return _processMacros(nextStepHtml);
  }

  String displayNextStepDate({String format = _nextStepDateFormat}) {
    if (nextStepDateUtc != null) {
      DateTime nextStepMidnightLocal = AppDateTime.midnight(nextStepDateUtc);
      if (nextStepMidnightLocal == AppDateTime.todayMidnightLocal) {
        return Localization().getStringEx('model.explore.time.today', 'Today').toLowerCase();
      }
      else if (nextStepMidnightLocal == AppDateTime.tomorrowMidnightLocal) {
        return Localization().getStringEx('model.explore.time.tomorrow', 'Tomorrow').toLowerCase();
      }
      else {
        return AppDateTime.formatDateTime(nextStepDateUtc.toLocal(), format: format, locale: Localization().currentLocale?.languageCode);
      }
    }
    return null;
  }

  String get displayEventExplanation {
    return _processMacros(eventExplanation);
  }

  String get displayEventExplanationHtml {
    return _processMacros(eventExplanationHtml);
  }

  String get displayReason {
    return _processMacros(reason);
  }

  String get displayWarning {
    return _processMacros(warning);
  }

  String _processMacros(String value) {
    if ((value != null) && (nextStepDateUtc != null) && value.contains(_nextStepDateMacro)) {
      return value.replaceAll(_nextStepDateMacro, displayNextStepDate() ?? '');
    }
    return value;
  }

  Set<String> get fcmTopics {
    if (fcmTopic is String) {
      return Set.from([fcmTopic]);
    }
    else if (fcmTopic is List) {
      try { return Set.from(fcmTopic.cast<String>()); }
      catch(e) { print(e?.toString()); }
    }
    return null;
  }

  bool get requiresTest {
    // TBD
    return (nextStep?.toLowerCase()?.contains("test") ?? false) ||
      (nextStepHtml?.toLowerCase()?.contains("test") ?? false);  
  }

  bool reportsExposures({HealthRulesSet rules}) {
    return (rules?.codes[code]?.reportsExposures == true);
  }
}

////////////////////////////////
// Building Access

const String kBuildingAccessGranted   = 'granted';
const String kBuildingAccessDenied    = 'denied';


///////////////////////////////
// HealthHistory

class HealthHistory implements Comparable<HealthHistory> {
  final String id;
  final String accountId;
  final DateTime dateUtc;
  final HealthHistoryType type;

  final String encryptedKey;
  final String encryptedBlob;
  
  final String locationId;
  final String countyId;
  final String encryptedImageKey;
  final String encryptedImageBlob;

  HealthHistoryBlob blob;

  HealthHistory({this.id, this.accountId, this.dateUtc, this.type, this.encryptedKey, this.encryptedBlob, this.locationId, this.countyId, this.encryptedImageKey, this.encryptedImageBlob });

  factory HealthHistory.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthHistory(
      id: json['id'],
      accountId: json['account_id'],
      dateUtc: healthDateTimeFromString(json['date']),
      type: healthHistoryTypeFromString(json['type']),

      encryptedKey: json['encrypted_key'],
      encryptedBlob: json['encrypted_blob'],

      locationId: json['location_id'],
      countyId: json['county_id'],
      encryptedImageKey: json['encrypted_image_key'],
      encryptedImageBlob: json['encrypted_image_blob'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'date': healthDateTimeToString(dateUtc),
      'type': healthHistoryTypeToString(type),

      'encrypted_key': encryptedKey,
      'encrypted_blob': encryptedBlob,

      'location_id': locationId,
      'county_id': countyId,
      'encrypted_image_key': encryptedImageKey,
      'encrypted_image_blob': encryptedImageBlob,
    };
  }

  bool operator ==(o) {
    return (o is HealthHistory) &&
      (o.id == id) &&
      (o.accountId == accountId) &&
      (o.dateUtc == dateUtc) &&
      (o.type == type) &&

      (o.encryptedKey == encryptedKey) &&
      (o.encryptedBlob == encryptedBlob) &&
      
      (o.locationId == locationId) &&
      (o.countyId == countyId) &&
      (o.encryptedImageKey == encryptedImageKey) &&
      (o.encryptedImageBlob == encryptedImageBlob);
  }

  int get hashCode =>
    (id?.hashCode ?? 0) ^
    (accountId?.hashCode ?? 0) ^
    (dateUtc?.hashCode ?? 0) ^
    (type?.hashCode ?? 0) ^
    
    (encryptedKey?.hashCode ?? 0) ^
    (encryptedBlob?.hashCode ?? 0) ^
    
    (locationId?.hashCode ?? 0) ^
    (countyId?.hashCode ?? 0) ^
    (encryptedImageKey?.hashCode ?? 0) ^
    (encryptedImageBlob?.hashCode ?? 0);

  int compareTo(HealthHistory other) {
    DateTime otherDateUtc = other?.dateUtc;
    if (dateUtc != null) {
      return (otherDateUtc != null) ? dateUtc.compareTo(otherDateUtc) : 1; // null is before an object
    }
    else {
      return (otherDateUtc != null) ? -1 : 0;
    }
  }

  static Future<HealthHistory> decryptedFromJson(Map<String, dynamic> json, Map<HealthHistoryType, PrivateKey> privateKeys ) async {
    try {
      HealthHistory value = HealthHistory.fromJson(json);
      PrivateKey privateKey = privateKeys[value.type];
      if ((value != null) && (value.encryptedKey != null) && (value.encryptedBlob != null) && (privateKey != null)) {
        String blobString = await compute(_decryptBlob, {
          'encryptedKey': value.encryptedKey,
          'encryptedBlob': value.encryptedBlob,
          'privateKey': privateKey
        });
        value.blob = HealthHistoryBlob.fromJson(AppJson.decodeMap(blobString));
      }
      return value;
    }
    catch(e) { print(e?.toString()); }
    return null;
  }

  static Future<HealthHistory> encryptedFromBlob({String id, String accountId, DateTime dateUtc, HealthHistoryType type, HealthHistoryBlob blob, String locationId, String countyId, String image, PublicKey publicKey}) async {
    Map<String, dynamic> encrypted = await compute(_encryptBlob, {
      'blob': AppJson.encode(blob?.toJson()),
      'publicKey': publicKey
    });
    Map<String, dynamic> encryptedImage = (image != null) ? await compute(_encryptBlob, {
      'blob': image,
      'publicKey': publicKey
    }) : null;
    return HealthHistory(
      id: id,
      accountId: accountId,
      dateUtc: dateUtc,
      type: type,
      encryptedKey: encrypted['encryptedKey'],
      encryptedBlob: encrypted['encryptedBlob'],
      locationId: locationId,
      countyId: countyId,
      encryptedImageKey: (encryptedImage != null) ? encryptedImage['encryptedKey'] : null,
      encryptedImageBlob: (encryptedImage != null) ? encryptedImage['encryptedBlob'] : null,
    );
  }

  bool get isTest {
    return (type == HealthHistoryType.test) || (type == HealthHistoryType.manualTestNotVerified) || (type == HealthHistoryType.manualTestVerified);
  }

  bool get isManualTest {
    return (type == HealthHistoryType.manualTestNotVerified) || (type == HealthHistoryType.manualTestVerified);
  }

  bool get isTestVerified {
    return (type == HealthHistoryType.test) || (type == HealthHistoryType.manualTestVerified);
  }

  bool get canTestUpdateStatus {
    return (type == HealthHistoryType.test) || (type == HealthHistoryType.manualTestVerified);
  }

  bool get isSymptoms {
    return (type == HealthHistoryType.symptoms);
  }

  bool get isContactTrace {
    return (type == HealthHistoryType.contactTrace);
  }

  bool get isAction {
    return (type == HealthHistoryType.action);
  }

  DateTime get dateMidnightLocal {
    if (dateUtc != null) {
      DateTime dateLocal = dateUtc.toLocal();
      return DateTime(dateLocal.year, dateLocal.month, dateLocal.day);
    }
    else {
      return null;
    }
  }

  bool matchPendingEvent(HealthPendingEvent event) {
    if (event.isTest) {
      return this.isTest &&
        (this.dateUtc == event?.blob?.dateUtc) &&
        (this.blob?.provider == event?.provider) &&
        (this.blob?.providerId == event?.providerId) &&
        (this.blob?.testType == event?.blob?.testType) &&
        (this.blob?.testResult == event?.blob?.testResult);
    }
    else if (event.isAction) {
      return this.isAction &&
        (this.dateUtc == event?.blob?.dateUtc) &&
        (this.blob?.actionType == event?.blob?.actionType) &&
        ((this.blob?.actionText == event?.blob?.actionText) ||
         ((this.blob?.actionText is Map) && (event?.blob?.actionText is Map) && MapEquality().equals(this.blob?.actionText, event?.blob?.actionText))
        );
    }
    else {
      return false;
    }
  }

  static Future<List<HealthHistory>> listFromJson(List<dynamic> json, Map<HealthHistoryType, PrivateKey> privateKeys) async {
    if (json != null) {
      List<Future<HealthHistory>> futures = [];
      for (dynamic entry in json) {
        futures.add(HealthHistory.decryptedFromJson((entry as Map)?.cast<String, dynamic>(), privateKeys));
      }
      return await Future.wait(futures);
    }
    return null;
  }

  static List<dynamic> listToJson(List<HealthHistory> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthHistory value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  static void sortListDescending(List<HealthHistory> history) {
    history?.sort((HealthHistory entry1, HealthHistory entry2) {
      if (entry1 != null) {
        return entry1.compareTo(entry2) * -1;
      }
      else {
        return (entry2 != null) ? 1 : 0;
      }
    });
  }

  static bool updateInList(List<HealthHistory> history, HealthHistory entry) {
    if ((history != null) && (entry != null)) {
      for (int index = 0; index < history.length; index++) {
        HealthHistory historyEntry = history[index];
        if (historyEntry?.id == entry.id) {
          history[index] = entry;
          return true;
        }
      }
    }
    return false;
  }

  static HealthHistory traceInList(List<HealthHistory> history, { String tek }) {
    if ((history != null) && (tek != null)) {
      for (HealthHistory historyEntry in history) {
        if ((historyEntry.type == HealthHistoryType.contactTrace) && (historyEntry.blob?.traceTEK == tek)) {
          return historyEntry;
        }
      }
    }
    return null;
  }

  static bool listContainsEvent(List<HealthHistory> history, HealthPendingEvent event) {
    if ((history != null) && (event != null)) {
      for (HealthHistory historyEntry in history) {
         if (historyEntry.matchPendingEvent(event)) {
           return true;
         }
      }
    }
    return false;
  }

  static HealthHistory mostRecent(List<HealthHistory> history) {
    if (history != null) {
      DateTime nowUtc = DateTime.now().toUtc();
      for (int index = 0; index < history.length; index++) {
        HealthHistory historyEntry = history[index];
        if ((historyEntry.dateUtc != null) && (historyEntry.dateUtc.isBefore(nowUtc))) {
          return historyEntry;
        }
      }
    }
    return null;
  }

  static HealthHistory mostRecentTest(List<HealthHistory> history, { DateTime beforeDateUtc, int onPosition = 1 }) {
    HealthHistory result;
    if (history != null) {
      if (beforeDateUtc == null) {
        beforeDateUtc = DateTime.now().toUtc();
      }
      for (int index = 0; (index < history.length) && (0 < onPosition); index++) {
        HealthHistory historyEntry = history[index];
        if (historyEntry.isTestVerified && (historyEntry.dateUtc != null) && (historyEntry.dateUtc.isBefore(beforeDateUtc))) {
          result = historyEntry;
          onPosition--;
        }
      }
    }
    return result;
  }

  static List<HealthHistory> pastList(List<HealthHistory> history) {
    List<HealthHistory> result;
    if (history != null) {
      result = List<HealthHistory>();
      DateTime nowUtc = DateTime.now().toUtc();
      for (int index = 0; index < history.length; index++) {
        HealthHistory historyEntry =  history[index];
        if ((historyEntry.dateUtc != null) && (historyEntry.dateUtc.isBefore(nowUtc))) {
          result.add(historyEntry);
        }
      }
    }
    return result;
  }

  static HealthHistory mostRecentContactTrace(List<HealthHistory> history, { DateTime minDateUtc, DateTime maxDateUtc }) {
    if (history != null) {
      for (int index = 0; index < history.length; index++) {
        HealthHistory historyEntry = history[index];
        if (historyEntry.isContactTrace &&
            ((minDateUtc == null) || ((historyEntry.dateUtc != null) && historyEntry.dateUtc.isAfter(minDateUtc))) &&
            ((maxDateUtc == null) || ((historyEntry.dateUtc != null) && historyEntry.dateUtc.isBefore(maxDateUtc)))) {
          return historyEntry;
        }
      }
    }
    return null;
  }
}

////////////////////////////////
// HealthHistoryBlob

class HealthHistoryBlob {
  final String provider;
  final String providerId;
  final String location;
  final String locationId;
  final String countyId;
  final String testType;
  final String testResult;
  
  final List<HealthSymptom> symptoms;
  
  final int traceDuration;
  final String traceTEK;
  
  final String actionType;
  final dynamic actionText;

  HealthHistoryBlob({
    this.provider, this.providerId, this.location, this.locationId, this.countyId, this.testType, this.testResult,
    this.symptoms,
    this.traceDuration, this.traceTEK,
    this.actionType, this.actionText,
  });

  factory HealthHistoryBlob.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthHistoryBlob(
      provider: json['provider'],
      providerId: json['provider_id'],
      location: json['location'],
      locationId: json['location_id'],
      countyId: json['county_id'],
      testType: json['test_type'],
      testResult: json['result'],
      
      symptoms: HealthSymptom.listFromJson(json['symptoms']),
      
      traceDuration: json['trace_duration'],
      traceTEK: json['trace_tek'],
      
      actionType: json['action_type'],
      actionText: json['action_text'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'provider_id': providerId,
      'location': location,
      'location_id': locationId,
      'county_id': countyId,
      'test_type': testType,
      'result': testResult,
      
      'symptoms': HealthSymptom.listToJson(symptoms),
      
      'trace_duration': traceDuration,
      'trace_tek': traceTEK,
      
      'action_type': actionType,
      'action_text': actionText,
    };
  }

  bool operator ==(o) {
    return (o is HealthHistoryBlob) &&
      (o.provider == provider) &&
      (o.providerId == providerId) &&
      (o.location == location) &&
      (o.locationId == locationId) &&
      (o.countyId == countyId) &&
      (o.testType == testType) &&
      (o.testResult == testResult) &&

      ListEquality().equals(o.symptoms, symptoms) &&

      (o.traceDuration == traceDuration) &&
      (o.traceTEK == traceTEK) &&

      (o.actionType == actionType) &&
      DeepCollectionEquality().equals(o.actionText, actionText);
  }

  int get hashCode =>
    (provider?.hashCode ?? 0) ^
    (providerId?.hashCode ?? 0) ^
    (location?.hashCode ?? 0) ^
    (locationId?.hashCode ?? 0) ^
    (countyId?.hashCode ?? 0) ^
    (testType?.hashCode ?? 0) ^
    (testResult?.hashCode ?? 0) ^

    ListEquality().hash(symptoms) ^

    (traceDuration?.hashCode ?? 0) ^
    (traceTEK?.hashCode ?? 0) ^

    (actionType?.hashCode ?? 0) ^
    (DeepCollectionEquality().hash(actionText) ?? 0);

  bool get isTest {
    return (providerId != null) || (locationId != null) || (testType != null) || (testResult != null);
  }

  bool get isSymptoms {
    return (symptoms != null);
  }

  bool get isContactTrace {
    return ((traceDuration != null) /*&& (traceTEK != null)*/);
  }

  bool get isAction {
    return (actionType != null);
  }

  Set<String> get symptomsIds {
    Set<String> symptomsIds;
    if (symptoms != null) {
      symptomsIds = Set<String>();
      for (HealthSymptom symptom in symptoms) {
        symptomsIds.add(symptom.id);
      }
    }
    return symptomsIds;
  }

  String symptomsDisplayString({HealthRulesSet rules}) {
    String result = "";
    if (symptoms != null) {
      for (HealthSymptom symptom in symptoms) {
        String symptomName = rules?.localeString(symptom?.name) ?? symptom?.name;
        if (AppString.isStringNotEmpty(symptomName)) {
          if (0 < result.length) {
            result += ", ";
          }
          result += symptomName;
        }
      }
    }
    return result;
  }

  int get traceDurationInMinutes {
    return (traceDuration != null) ? (traceDuration / 60000).round() : null;
  }

  String get traceDurationDisplayString {
    int durationInSeconds = (traceDuration != null) ? traceDuration ~/ 1000 : null;
    if (durationInSeconds != null) {
      if (durationInSeconds < 60) {
        return "$durationInSeconds second" + (1 != durationInSeconds ? "s" : "");
      }
      else {
        int durationInMinutes = durationInSeconds ~/ 60;
        if (durationInMinutes < TimeOfDay.minutesPerHour) {
          return "$durationInMinutes minute" + (1 != durationInMinutes ? "s" : "");
        } else {
          int exposureHours = durationInMinutes ~/ TimeOfDay.minutesPerHour;
          return "$exposureHours hour" + (1 != exposureHours ? "s" : "");
        }

      }
    }
    return null;
  }

  String get localeActionText {
    return Localization().localeString(actionText) ?? actionText;
  }

  String get actionDisplayString {
    return localeActionText ?? actionType;
  }
}

////////////////////////////////
// HealthHistoryType

enum HealthHistoryType { test, manualTestVerified, manualTestNotVerified, symptoms, contactTrace, action }

HealthHistoryType healthHistoryTypeFromString(String value) {
  if (value == 'received_test') {
    return HealthHistoryType.test;
  }
  else if (value == 'verified_manual_test') {
    return HealthHistoryType.manualTestVerified;
  }
  else if (value == 'unverified_manual_test') {
    return HealthHistoryType.manualTestNotVerified;
  }
  else if (value == 'symptoms') {
    return HealthHistoryType.symptoms;
  }
  else if (value == 'trace') {
    return HealthHistoryType.contactTrace;
  }
  else if (value == 'action') {
    return HealthHistoryType.action;
  }
  else {
    return null;
  }
}

String healthHistoryTypeToString(HealthHistoryType value) {
  switch (value) {
    case HealthHistoryType.test: return 'received_test';
    case HealthHistoryType.manualTestVerified: return 'verified_manual_test';
    case HealthHistoryType.manualTestNotVerified: return 'unverified_manual_test';
    case HealthHistoryType.symptoms: return 'symptoms';
    case HealthHistoryType.contactTrace: return 'trace';
    case HealthHistoryType.action: return 'action';
  }
  return null;
}

///////////////////////////////
// HealthPendingEvent

class HealthPendingEvent {
  final String   id;
  final String   provider;
  final String   providerId;
  final String   accountId;
  final String   encryptedKey;
  final String   encryptedBlob;
  final bool     processed;
  final DateTime dateCreated;
  final DateTime dateUpdated;

  HealthPendingEventBlob blob;

  HealthPendingEvent({this.id, this.provider, this.providerId, this.accountId, this.encryptedKey, this.encryptedBlob, this.processed, this.dateCreated, this.dateUpdated});

  factory HealthPendingEvent.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthPendingEvent(
      id:            AppJson.stringValue(json['id']),
      provider:      AppJson.stringValue(json['provider']),
      providerId:    AppJson.stringValue(json['provider_id']),
      accountId:     AppJson.stringValue(json['account_id']),
      encryptedKey:  AppJson.stringValue(json['encrypted_key']),
      encryptedBlob: AppJson.stringValue(json['encrypted_blob']),
      processed:     AppJson.boolValue(json['processed']),
      dateCreated:   healthDateTimeFromString(AppJson.stringValue(json['date_created'])),
      dateUpdated:   healthDateTimeFromString(AppJson.stringValue(json['date_updated'])),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id']              = id;
    json['provider']        = provider;
    json['provider_id']     = providerId;
    json['account_id']         = accountId;
    json['encrypted_key']   = encryptedKey;
    json['encrypted_blob']  = encryptedBlob;
    json['processed']       = processed;
    json['date_created']    = healthDateTimeToString(dateCreated);
    json['date_updated']    = healthDateTimeToString(dateUpdated);
    return json;
  }

  static Future<HealthPendingEvent> decryptedFromJson(Map<String, dynamic> json, PrivateKey privateKey) async {
    try {
      HealthPendingEvent value = HealthPendingEvent.fromJson(json);
      if ((value != null) && (value.encryptedKey != null) && (value.encryptedBlob != null) && (privateKey != null)) {
        String blobString = await compute(_decryptBlob, {
          'encryptedKey': value.encryptedKey,
          'encryptedBlob': value.encryptedBlob,
          'privateKey': privateKey
        });
        value.blob = HealthPendingEventBlob.fromJson(AppJson.decodeMap(blobString));
      }
      return value;
    }
    catch(e) { print(e?.toString()); }
    return null;
  }

  static Future<List<HealthPendingEvent>> listFromJson(List<dynamic> json, PrivateKey privateKey) async {
    List<HealthPendingEvent> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthPendingEvent value = await HealthPendingEvent.decryptedFromJson(entry, privateKey);
          values.add(value);
      }
    }
    return values;
  }

  bool get isTest {
    return (blob != null) && blob.isTest && (providerId != null);
  }

  bool get isAction {
    return (blob != null) && blob.isAction;
  }
}

///////////////////////////////
// HealthPendingEventBlob

class HealthPendingEventBlob {
  final DateTime dateUtc;

  final String   testType;
  final String   testResult;

  final String   actionType;
  final dynamic  actionText;

  HealthPendingEventBlob({this.dateUtc, this.testType, this.testResult, this.actionType, this.actionText});

  factory HealthPendingEventBlob.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthPendingEventBlob(
      dateUtc:       healthDateTimeFromString(AppJson.stringValue(json['Date'])),
      testType:      AppJson.stringValue(json['TestName']),
      testResult:    AppJson.stringValue(json['Result']),
      actionType:    AppJson.stringValue(json['ActionType']),
      actionText:    json['ActionText'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    if ((testType != null) || (testResult != null)) {
      return {
        'Date': healthDateTimeToString(dateUtc),
        'TestName': testType,
        'Result': testResult,
      };
    }
    else if ((actionType != null) || (actionText != null)) {
      return {
        'Date': healthDateTimeToString(dateUtc),
        'ActionType': actionType,
        'ActionText': actionText,
      };
    }
    else {
      return {
        'Date': healthDateTimeToString(dateUtc),
      };
    }
  }

  bool get isTest {
    return AppString.isStringNotEmpty(testType) && AppString.isStringNotEmpty(testResult);
  }

  bool get isAction {
    return AppString.isStringNotEmpty(actionType);
  }

  String get defaultLocaleActionText {
    return Localization().defaultLocaleString(actionText) ?? actionText;
  } 
}


///////////////////////////////
// HealthOSFTest

class HealthOSFTest {
  final String provider;
  final String providerId;
  final String testType;
  final String testResult;
  final DateTime dateUtc;

  HealthOSFTest({this.provider, this.providerId,  this.testType, this.testResult, this.dateUtc,});
}


///////////////////////////////
// HealthManualTest

class HealthManualTest {
  final String provider;
  final String providerId;
  final String location;
  final String locationId;
  final String countyId;
  final String testType;
  final String testResult;
  final DateTime dateUtc;
  final String image;

  HealthManualTest({this.provider, this.providerId, this.location, this.locationId, this.countyId, this.testType, this.testResult, this.dateUtc, this.image});
}

///////////////////////////////
// HealthUser

class HealthUser {
  String uuid;
  String publicKeyString;
  PublicKey _publicKey;
  bool consent;
  bool exposureNotification;
  bool repost;
  List<HealthUserAccount> accounts;
  String encryptedKey;
  String encryptedBlob;
  String encryptedPrivateKey;

  HealthUserAccount defaultAccount;
  Map<String, HealthUserAccount> accountsMap;

  HealthUser({this.uuid, this.publicKeyString, PublicKey publicKey, this.consent, this.exposureNotification, this.repost, this.accounts, this.encryptedKey, this.encryptedBlob, this.encryptedPrivateKey}) {
    _publicKey = publicKey;
    accountsMap = HealthUserAccount.mapFromList(accounts);
    defaultAccount = HealthUserAccount.defaultInList(accounts);
  }

  factory HealthUser.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthUser(
      uuid: json['uuid'],
      publicKeyString: json['public_key'],
      consent: json['consent'],
      exposureNotification: json['exposure_notification'],
      repost: json['re_post'],
      accounts: HealthUserAccount.listFromJson(json['accounts']),
      encryptedKey: json['encrypted_key'],
      encryptedBlob: json['encrypted_blob'],
      encryptedPrivateKey: json['encrypted_pk'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'public_key': publicKeyString,
      'consent': consent,
      'exposure_notification': exposureNotification,
      're_post': repost,
      'accounts': HealthUserAccount.listToJson(accounts),
      'encrypted_key': encryptedKey,
      'encrypted_blob': encryptedBlob,
      'encrypted_pk': encryptedPrivateKey,
    };
  }

  bool operator == (o) =>
    o is HealthUser &&
      o.uuid == uuid &&
      o.publicKeyString == publicKeyString &&
      o.consent == consent &&
      o.exposureNotification == exposureNotification &&
      o.repost == repost &&
      ListEquality().equals(o.accounts, accounts) &&
      o.encryptedKey == encryptedKey &&
      o.encryptedBlob == encryptedBlob &&
      o.encryptedPrivateKey == encryptedPrivateKey;

  int get hashCode =>
    (uuid?.hashCode ?? 0) ^
    (publicKeyString?.hashCode ?? 0) ^
    (consent?.hashCode ?? 0) ^
    (exposureNotification?.hashCode ?? 0) ^
    (repost?.hashCode ?? 0) ^
    ListEquality().hash(accounts) ^
    (encryptedKey?.hashCode ?? 0) ^
    (encryptedBlob?.hashCode ?? 0) ^
    (encryptedPrivateKey?.hashCode ?? 0);

  Future<void> encryptBlob(HealthUserBlob blob, PublicKey publicKey) async {
    Map<String, dynamic> encrypted = await compute(_encryptBlob, {
      'blob': AppJson.encode(blob?.toJson()),
      'publicKey': publicKey
    });
    encryptedKey = encrypted['encryptedKey'];
    encryptedBlob = encrypted['encryptedBlob'];
  }

  factory HealthUser.fromUser(HealthUser user) {
    return (user != null) ? HealthUser(
      uuid: user.uuid,
      publicKeyString: user.publicKeyString,
      publicKey: user.publicKey,
      consent: user.consent,
      exposureNotification: user.exposureNotification,
      repost: user.repost,
      accounts: user.accounts,
      encryptedKey: user.encryptedKey,
      encryptedBlob: user.encryptedBlob,
      encryptedPrivateKey: user.encryptedPrivateKey,
    ) : null;
  }

  PublicKey get publicKey {
    if ((_publicKey == null) && (publicKeyString != null)) {
      _publicKey = RsaKeyHelper.parsePublicKeyFromPem(publicKeyString);
    }
    return _publicKey;
  }

  set publicKey(PublicKey value) {
    _publicKey = value;
    publicKeyString = (value != null) ? RsaKeyHelper.encodePublicKeyToPemPKCS1(value) : null;
  }

  bool get hasEncryptedPrivateKey => AppString.isStringNotEmpty(encryptedPrivateKey);

  HealthUserAccount account({String accountId}) {
    return ((accountsMap != null) && (accountId != null)) ? accountsMap[accountId] : null;
  }
}

///////////////////////////////
// HealthUserBlob

class HealthUserBlob {
  String info;

  HealthUserBlob({this.info});

  factory HealthUserBlob.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthUserBlob(
      info: json['info'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'info': info
    };
  }
}

///////////////////////////////
// HealthUserAccount

class HealthUserAccount {
  final String accountId;
  final String externalId;
  final bool isDefault;
  final bool isActive;

  final String email;
  final String phone;
  final String firstName;
  final String middleName;
  final String lastName;
  final String birthDateString;
  final String gender;

  final String address1;
  final String address2;
  final String address3;
  final String city;
  final String state;
  final String zip;

  HealthUserAccount({this.accountId, this.externalId, this.isDefault, this.isActive,
    this.email, this.phone, this.firstName, this.middleName, this.lastName, this.birthDateString, this.gender,
    this.address1, this.address2, this.address3, this.city, this.state, this.zip
  });

  factory HealthUserAccount.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthUserAccount(
      accountId: json['id'],
      externalId: json['external_id'],
      isDefault: json['default'],
      isActive: json['active'],

      email: json['email'],
      phone: json['phone'],
      firstName: json['first_name'],
      middleName: json['middle_name'],
      lastName: json['last_name'],
      birthDateString: json['birth_date'],
      gender: json['gender'],

      address1: json['address1'],
      address2: json['address2'],
      address3: json['address3'],
      city: json['city'],
      state: json['state'],
      zip: json['zip'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': accountId,
      'external_id': externalId,
      'default': isDefault,
      'active': isActive,

      'email': email,
      'phone': phone,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'birth_date': birthDateString,
      'gender': gender,

      'address1': address1,
      'address2': address2,
      'address3': address3,
      'city': city,
      'state': state,
      'zip': zip,
    };
  }

  bool operator == (o) =>
    o is HealthUserAccount &&
      o.accountId == accountId &&
      o.externalId == externalId &&
      o.isDefault == isDefault &&
      o.isActive == isActive &&
      
      o.email == email &&
      o.phone == phone &&
      o.firstName == firstName &&
      o.middleName == middleName &&
      o.lastName == lastName &&
      o.birthDateString == birthDateString &&
      o.gender == gender &&

      o.address1 == address1 &&
      o.address2 == address2 &&
      o.address3 == address3 &&
      o.city == city &&
      o.state == state &&
      o.zip == zip;

  int get hashCode =>
    (accountId?.hashCode ?? 0) ^
    (externalId?.hashCode ?? 0) ^
    (isDefault?.hashCode ?? 0) ^
    (isActive?.hashCode ?? 0) ^

    (email?.hashCode ?? 0) ^
    (phone?.hashCode ?? 0) ^
    (firstName?.hashCode ?? 0) ^
    (middleName?.hashCode ?? 0) ^
    (lastName?.hashCode ?? 0) ^
    (birthDateString?.hashCode ?? 0) ^
    (gender?.hashCode ?? 0) ^

    (address1?.hashCode ?? 0) ^
    (address2?.hashCode ?? 0) ^
    (address2?.hashCode ?? 0) ^
    (city?.hashCode ?? 0) ^
    (state?.hashCode ?? 0) ^
    (zip?.hashCode ?? 0);

  String get fullName {
    return AppString.fullName([firstName, middleName, lastName]);
  }

  DateTime get birthDate {
    return AppDateTime.parseDateTime(birthDateString, format: "MM/dd/yy");
  }

  static List<HealthUserAccount> listFromJson(List<dynamic> json) {
    List<HealthUserAccount> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthUserAccount value;
          try { value = HealthUserAccount.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }

    // TMP:
    /*if (!kReleaseMode && ((values?.length ?? 0) == 0)) {
      values = [
        HealthUserAccount(accountId: "1", externalId: "655618818", isDefault: true,  isActive: true, email: "email1@server.com", phone: "+000000000001", firstName: "Misho", lastName: "Varbanov", birthDateString: "01/01/70", gender: "M",),
        HealthUserAccount(accountId: "2", externalId: "655618818", isDefault: false, isActive: true, email: "email2@server.com", phone: "+000000000002", firstName: "Mihail", lastName: "Varbanov", birthDateString: "01/01/70", gender: "M",),
        HealthUserAccount(accountId: "3", externalId: "655618818", isDefault: false, isActive: true, email: "email3@server.com", phone: "+000000000003", firstName: "Quetzal", lastName: "Coatl", birthDateString: "01/01/70", gender: "M",),
      ];
    }*/

    return values;
  }

  static List<dynamic> listToJson(List<HealthUserAccount> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthUserAccount value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  static Map<String, HealthUserAccount> mapFromList(List<HealthUserAccount> values) {
    Map<String, HealthUserAccount> map;
    if (values != null) {
      map = <String, HealthUserAccount>{};
      for (HealthUserAccount account in values) {
        if ((account.accountId != null) && (account.isActive != false)) {
          map[account.accountId] = account;
        }
      }
    }
    return map;
  }

  static HealthUserAccount defaultInList(List<HealthUserAccount> values) {
    if (values != null) {
      for (HealthUserAccount account in values) {
        if ((account.isDefault == true) && (account.isActive != false)) {
          return account;
        }
      }
    }
    return null;
  }
}

///////////////////////////////
// HealthOSFAuth

class HealthOSFAuth {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String scope;
  final String patient;

  HealthOSFAuth({this.accessToken, this.tokenType, this.expiresIn, this.scope, this.patient});

  factory HealthOSFAuth.fromJson(Map<String,dynamic>json){
    return HealthOSFAuth(
      accessToken: json["access_token"],
      tokenType: json["token_type"],
      expiresIn: json["expires_in"],
      scope: json["scope"],
      patient: json["patient"],
    );
  }

  toJson(){
    return {
      "access_token": accessToken,
      "token_type": tokenType,
      "expires_in": expiresIn,
      "scope": scope,
      "patient": patient,
    };
  }
}

///////////////////////////////
// HealthServiceProvider

class HealthServiceProvider {
  final String id;
  final String name;
  final bool allowManualTest;
  final List<HealthServiceMechanism> availableMechanisms;

  HealthServiceProvider({this.id, this.name, this.allowManualTest, this.availableMechanisms});

  factory HealthServiceProvider.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthServiceProvider(
      id: json['id'],
      name: json['provider_name'],
      allowManualTest: json['manual_test'],
      availableMechanisms: healthServiceMechanismListFromJson(json["available_mechanisms"]),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_name': name,
      'manual_test': allowManualTest,
      "available_mechanisms" : healthServiceMechanismListToJson(availableMechanisms)
    };
  }

  static List<HealthServiceProvider> listFromJson(List<dynamic> json) {
    List<HealthServiceProvider> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthServiceProvider value;
          try { value = HealthServiceProvider.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthServiceProvider> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthServiceProvider value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  static Map<String, List<HealthServiceProvider>> countyProvidersMapFromJson(Map<String, dynamic> json) {
    if (json != null) {
      Map<String, List<HealthServiceProvider>> result = Map();
      for (String countyId in json.keys) {
        result[countyId] = listFromJson(json[countyId]);
      }
      return result;
    }
    return null;
  }
}

////////////////////////////////
//HealthServiceMechanism

enum HealthServiceMechanism{epic, mcKinley, none}

HealthServiceMechanism healthServiceMechanismFromString(String value) {
  if (value != null) {
    if (value == 'Epic') {
      return HealthServiceMechanism.epic;
    }
    else if (value == 'McKinley') {
      return HealthServiceMechanism.mcKinley;
    }
    else if (value == 'McKinley') {
      return HealthServiceMechanism.mcKinley;
    }
  }
  return null;
}

String healthServiceMechanismToString(HealthServiceMechanism value) {
  if (value != null) {
    if (value == HealthServiceMechanism.epic) {
      return 'Epic';
    }
    else if (value == HealthServiceMechanism.mcKinley) {
      return 'McKinley';
    }
    else if (value == HealthServiceMechanism.mcKinley) {
      return 'McKinley';
    }
  }
  return null;
}

List<HealthServiceMechanism> healthServiceMechanismListFromJson(List<dynamic> json) {
  List<HealthServiceMechanism> values;
  if (json != null) {
    values = [];
    for (dynamic entry in json) {
      HealthServiceMechanism value;
      try { value = healthServiceMechanismFromString((entry as String)); }
      catch(e) { print(e?.toString()); }
      values.add(value);
    }
  }
  return values;
}

List<dynamic>  healthServiceMechanismListToJson(List<HealthServiceMechanism> values) {
  List<dynamic> json;
  if (values != null) {
    json = [];
    for (HealthServiceMechanism value in values) {
      json.add(healthServiceMechanismToString(value));
    }
  }
  return json;
}



///////////////////////////////
// HealthServiceLocation

class HealthServiceLocation {
  final String id;
  final String name;
  final String contact;
  final String city;
  final String address1;
  final String address2;
  final String state;
  final String country;
  final String zip;
  final String url;
  final String notes;
  final double latitude;
  final double longitude;
  final HealthLocationWaitTimeColor waitTimeColor;
  final List<String> availableTests;
  final List<HealthLocationDayOfOperation> daysOfOperation;
  
  HealthServiceLocation({this.id, this.name, this.availableTests, this.contact, this.city, this.address1, this.address2, this.state, this.country, this.zip, this.url, this.notes, this.latitude, this.longitude, this.waitTimeColor, this.daysOfOperation});

  factory HealthServiceLocation.fromJson(Map<String, dynamic> json) {
    List jsoTests = json['available_tests'];
    List jsonDaysOfOperation = json['days_of_operation'];
    return (json != null) ? HealthServiceLocation(
      id: json['id'],
      name: json['name'],
      contact: json["contact"],
      city: json["city"],
      state: json["state"],
      country: json["country"],
      address1: json["address_1"],
      address2: json["address_2"],
      zip: json["zip"],
      url: json["url"],
      notes: json["notes"],
      latitude: AppJson.doubleValue(json["latitude"]),
      longitude: AppJson.doubleValue(json["longitude"]),
      waitTimeColor: HealthServiceLocation.waitTimeColorFromString(json['wait_time_color']),
      availableTests: jsoTests!=null ? List.from(jsoTests) : null,
      daysOfOperation: jsonDaysOfOperation!=null ? HealthLocationDayOfOperation.listFromJson(jsonDaysOfOperation) : null,
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'city': city,
      'state': state,
      'country': country,
      'address_1': address1,
      'address_2': address2,
      'zip': zip,
      'url': url,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'wait_time_color': HealthServiceLocation.waitTimeColorToKeyString(waitTimeColor),
      'available_tests': availableTests,
    };
  }

  String get fullAddress{
    String address = "";
    address = address1?? "";
    if(address2?.isNotEmpty?? false) {
      address += address.isNotEmpty ? ", " : "";
      address += address2;
    }
    if(city?.isNotEmpty?? false) {
      address += address.isNotEmpty ? ", " : "";
      address += city;
    }
    if(state?.isNotEmpty?? false) {
      address += address.isNotEmpty ? ", " : "";
      address += state;
    }
    return address;
  }

  static List<HealthServiceLocation> listFromJson(List<dynamic> json) {
    List<HealthServiceLocation> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
        HealthServiceLocation value;
        try { value = HealthServiceLocation.fromJson((entry as Map)?.cast<String, dynamic>()); }
        catch(e) { print(e?.toString()); }
        values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthServiceLocation> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthServiceLocation value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  static HealthLocationWaitTimeColor waitTimeColorFromString(String colorString) {
    if (colorString == 'red') {
      return HealthLocationWaitTimeColor.red;
    } else if (colorString == 'yellow') {
      return HealthLocationWaitTimeColor.yellow;
    } else if (colorString == 'green') {
      return HealthLocationWaitTimeColor.green;
    } else if (colorString == 'grey') {
      return HealthLocationWaitTimeColor.grey;
    } else {
      return null;
    }
  }

  static String waitTimeColorToKeyString(HealthLocationWaitTimeColor color) {
    switch (color) {
      case HealthLocationWaitTimeColor.red:
        return 'red';
      case HealthLocationWaitTimeColor.yellow:
        return 'yellow';
      case HealthLocationWaitTimeColor.green:
        return 'green';
      case HealthLocationWaitTimeColor.grey:
        return 'grey';
      default:
        return null;
    }
  }

  static Color waitTimeColorHex(HealthLocationWaitTimeColor color) {
    switch (color) {
      case HealthLocationWaitTimeColor.red:
        return Styles().colors.healthLocationWaitTimeColorRed;
      case HealthLocationWaitTimeColor.yellow:
        return Styles().colors.healthLocationWaitTimeColorYellow;
      case HealthLocationWaitTimeColor.green:
        return Styles().colors.healthLocationWaitTimeColorGreen;
      default:
        return Styles().colors.healthLocationWaitTimeColorGrey;
    }
  }
}

///////////////////////////////
// HealthLocationDayOfOperation

class HealthLocationDayOfOperation {
  final String name;
  final String openTime;
  final String closeTime;

  final int weekDay;
  final int openMinutes;
  final int closeMinutes;

  HealthLocationDayOfOperation({this.name, this.openTime, this.closeTime}) :
    weekDay = (name != null) ? AppDateTime.getWeekDayFromString(name.toLowerCase()) : null,
    openMinutes = _timeMinutes(openTime),
    closeMinutes = _timeMinutes(closeTime);

  factory HealthLocationDayOfOperation.fromJson(Map<String,dynamic> json){
    return (json != null) ? HealthLocationDayOfOperation(
      name: json["name"],
      openTime: json["open_time"],
      closeTime: json["close_time"],
    ) : null;
  }

  String get displayString{
    return "$name $openTime to $closeTime";
  }

  bool get isOpen {
    if ((openMinutes != null) && (closeMinutes != null)) {
      int nowWeekDay = DateTime.now().weekday;
      int nowMinutes = _timeOfDayMinutes(TimeOfDay.now());
      return nowWeekDay == weekDay && openMinutes < nowMinutes && nowMinutes < closeMinutes;
    }
    return false;
  }

  bool get willOpen {
    if (openMinutes != null) {
      int nowWeekDay = DateTime.now().weekday;
      int nowMinutes = _timeOfDayMinutes(TimeOfDay.now());
      return nowWeekDay == weekDay && nowMinutes < openMinutes;
    }

    return false;
  }

  static List<HealthLocationDayOfOperation> listFromJson(List<dynamic> json) {
    List<HealthLocationDayOfOperation> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
        HealthLocationDayOfOperation value;
        try { value = HealthLocationDayOfOperation.fromJson((entry as Map)?.cast<String, dynamic>()); }
        catch(e) { print(e?.toString()); }
        values.add(value);
      }
    }
    return values;
  }

  // Helper function for conversion work time string to number of minutes

  static int _timeMinutes(String time, {String format = 'hh:mma'}) {
    DateTime dateTime = (time != null) ? AppDateTime.parseDateTime(time.toUpperCase(), format: format) : null;
    TimeOfDay timeOfDay = (dateTime != null) ? TimeOfDay.fromDateTime(dateTime) : null;
    return _timeOfDayMinutes(timeOfDay);
  }

  static int _timeOfDayMinutes(TimeOfDay timeOfDay) {
    return (timeOfDay != null) ? (timeOfDay.hour * 60 + timeOfDay.minute) : null;
  }
}

///////////////////////////////
// HealthLocationWaitTimeColor

enum HealthLocationWaitTimeColor { red, yellow, green, grey }

///////////////////////////////
// HealthTestType

class HealthTestType {
  final String id;
  final String name;
  final List<HealthTestTypeResult> results;

  HealthTestType({this.id, this.name, this.results});

  factory HealthTestType.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestType(
      id: json['id'],
      name: json['name'],
      results: HealthTestTypeResult.listFromJson(json['results']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'results': HealthTestTypeResult.listToJson(results),
    };
  }

  static List<HealthTestType> listFromJson(List<dynamic> json) {
    List<HealthTestType> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
        HealthTestType value;
        try { value = HealthTestType.fromJson((entry as Map)?.cast<String, dynamic>()); }
        catch(e) { print(e?.toString()); }
        values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthTestType> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthTestType value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// HealthTestRuleResult

class HealthTestTypeResult {
  final String id;
  final String name;
  final String nextStep;
  final int nextStepOffset;
  final int nextStepExpiresOffset;

  HealthTestTypeResult({this.id, this.name, this.nextStep, this.nextStepOffset,this.nextStepExpiresOffset});

  factory HealthTestTypeResult.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestTypeResult(
        id: json['id'],
        name: json['name'],
        nextStep: json['next_step'],
        nextStepOffset: json['next_step_offset'],
        nextStepExpiresOffset: json['result_expires_offset']
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'next_step': nextStep,
      'next_step_offset': nextStepOffset,
      'result_expires_offset': nextStepExpiresOffset,
    };
  }

  DateTime nextStepDate(DateTime testDate) {
    return ((testDate != null) && (nextStepOffset != null)) ?
    testDate.add(Duration(hours: nextStepOffset)) : null;
  }

  static List<HealthTestTypeResult> listFromJson(List<dynamic> json) {
    List<HealthTestTypeResult> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
        HealthTestTypeResult value;
        try { value = HealthTestTypeResult.fromJson((entry as Map)?.cast<String, dynamic>()); }
        catch(e) { print(e?.toString()); }
        values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthTestTypeResult> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthTestTypeResult value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// HealthCounty

class HealthCounty {
  final String id;
  final String name;
  final String state;
  final String country;
  final List<HealthGuideline> guidelines;

  HealthCounty({this.id, this.name, this.state, this.country,this.guidelines});

  factory HealthCounty.fromCounty(HealthCounty county, { bool guidelines }) {
    return (county != null) ? HealthCounty(
      id: county.id,
      name: county.name,
      state: county.state,
      country: county.country,
      guidelines: (guidelines == true) ? county.guidelines : null,
    ) : null;
  }

  factory HealthCounty.fromJson(Map<String, dynamic> json, { bool guidelines }) {
    return (json != null) ? HealthCounty(
      id: json['id'],
      name: json['name'],
      state: json['state_province'],
      country: json['country'],
      guidelines: (guidelines == true) ? HealthGuideline.fromJsonList(json['guidelines']) : null,
    ) : null;
  }

  Map<String, dynamic> toJson({ bool guidelines }) {
    return {
      'id': id,
      'name': name,
      'state': state,
      'country': country,
      'guidelines': (guidelines == true) ? HealthGuideline.listToJson(this.guidelines) : null,
    };
  }

  bool operator ==(o) =>
    (o is HealthCounty) &&
      (o.id == id) &&
      (o.name == name) &&
      (o.state == state) &&
      (o.country == country);

  int get hashCode =>
    (id?.hashCode ?? 0) ^
    (name?.hashCode ?? 0) ^
    (state?.hashCode ?? 0) ^
    (country?.hashCode ?? 0);

  String get displayName {
    return AppString.isStringNotEmpty(state) ? "$name, $state" : name;
  }

  static HealthCounty defaultCounty(Iterable<HealthCounty> counties) {
    if ((counties != null) && (0 < counties.length)) {
      for (HealthCounty county in counties) {
        if (county.name == 'Champaign') {
          return county;
        }
      }
      return counties.first;
    }
    return null;
  }

  static HealthCounty getCounty(Iterable<HealthCounty> counties, { String countyId }) {
    if ((counties != null) && (0 < counties.length)) {
      for (HealthCounty county in counties) {
        if ((countyId != null) && (county.id == countyId)) {
          return county;
        }
      }
    }
    return null;
  }

  static LinkedHashMap<String, HealthCounty> listToMap(List<HealthCounty> counties) {
    LinkedHashMap<String, HealthCounty> countiesMap;
    if (counties != null) {
      countiesMap = LinkedHashMap<String, HealthCounty>();
      for (HealthCounty county in counties) {
        countiesMap[county.id] = county;
      }
    }
    return countiesMap;
  }

  static List<HealthCounty> listFromJson(List<dynamic> json, { bool guidelines }) {
    List<HealthCounty> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthCounty value;
          try { value = HealthCounty.fromJson((entry as Map)?.cast<String, dynamic>(), guidelines: guidelines); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthCounty> values, { bool guidelines }) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthCounty value in values) {
        json.add(value?.toJson(guidelines : guidelines));
      }
    }
    return json;
  }
}


///////////////////////////////
// HealthGuideline

class HealthGuideline {
  final String id;
  final String name;
  final List<HealthGuidelineItem> items;

  HealthGuideline({this.id, this.name, this.items});

  factory HealthGuideline.fromJson(Map<String, dynamic> json) {
    if (json == null) {
      return null;
    }
    return HealthGuideline(
        id: json['id'],
        name: json['name'],
        items: HealthGuidelineItem.fromJsonList(json["items"])
    );
  }

  static List<HealthGuideline> fromJsonList(List<dynamic> jsonList) {
    List<HealthGuideline> sections;
    if (jsonList != null) {
      sections = List();
      for (dynamic jsonEntry in jsonList) {
        sections.add(HealthGuideline.fromJson(jsonEntry));
      }
    }
    return sections;
  }

  static List<dynamic> listToJson(List<HealthGuideline> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthGuideline value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': HealthGuidelineItem.listToJson(items),
    };
  }
}

///////////////////////////////
// HealthGuidelineItem

class HealthGuidelineItem {
  final String icon;
  final String description;
  final String type;

  HealthGuidelineItem({this.icon, this.description, this.type});

  factory HealthGuidelineItem.fromJson(Map<String, dynamic> json) {
    if (json == null) {
      return null;
    }
    return HealthGuidelineItem(
      icon: json['icon'],
      description: json['description'],
      type: json['type'],
    );
  }

  static List<HealthGuidelineItem> fromJsonList(List<dynamic> jsonList) {
    List<HealthGuidelineItem> guidelineItems;
    if (jsonList != null) {
      guidelineItems = List();
      for (dynamic jsonEntry in jsonList) {
        guidelineItems.add(HealthGuidelineItem.fromJson(jsonEntry));
      }
    }
    return guidelineItems;
  }

  static List<dynamic> listToJson(List<HealthGuidelineItem> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthGuidelineItem value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  Map<String, dynamic> toJson() {
    return {
      'icon': icon,
      'description': description,
      'type': type,
    };
  }
}

///////////////////////////////
// HealthSymptom

class HealthSymptom {
  final String id;
  final String name;

  HealthSymptom({this.id, this.name});

  factory HealthSymptom.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptom(
      id: json['id'],
      name: json['name'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  bool operator ==(o) =>
    (o is HealthSymptom) &&
      (o.id == id) &&
      (o.name == name);

  int get hashCode =>
    (id?.hashCode ?? 0) ^
    (name?.hashCode ?? 0);

  static List<HealthSymptom> listFromJson(List<dynamic> json) {
    List<HealthSymptom> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthSymptom value;
          try { value = HealthSymptom.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthSymptom> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthSymptom value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// HealthSymptomsGroup

class HealthSymptomsGroup {
  final String id;
  final String name;
  final String group;
  final bool visible;
  final List<HealthSymptom> symptoms;

  HealthSymptomsGroup({this.id, this.name, this.group, this.visible, this.symptoms});

  factory HealthSymptomsGroup.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptomsGroup(
      id: json['id'],
      name: json['name'],
      visible: json['visible'],
      group: json['group'],
      symptoms: HealthSymptom.listFromJson(json['symptoms']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group': group,
      'visible': visible,
      'symptoms': HealthSymptom.listToJson(symptoms),
    };
  }

  bool operator ==(o) =>
    (o is HealthSymptomsGroup) &&
      (o.id == id) &&
      (o.name == name) &&
      (o.visible == visible) &&
      (o.group == group) &&
      ListEquality().equals(o.symptoms, symptoms);

  int get hashCode =>
    (id?.hashCode ?? 0) ^
    (name?.hashCode ?? 0) ^
    (visible?.hashCode ?? 0) ^
    (group?.hashCode ?? 0) ^
    ListEquality().hash(symptoms);

  static Map<String, int> getCounts(List<HealthSymptomsGroup> groups, Set<String> selected) {
    Map<String, int> counts = Map<String, int>();
    if ((groups != null) && (selected != null)) {
      for (HealthSymptomsGroup group in groups) {
        int count = 0;
        if (group.symptoms != null) {
          for (HealthSymptom symptom in group.symptoms) {
            if (selected.contains(symptom.id)) {
              count++;
            }
          }
        }
        counts[group.name] = count;
      }
    }
    return counts;
  }

  static List<HealthSymptom> getSymptoms(List<HealthSymptomsGroup> groups, Set<String> selected) {
    List<HealthSymptom> symptoms = List<HealthSymptom>();
    if ((groups != null) && (selected != null)) {
      for (HealthSymptomsGroup group in groups) {
        if ((group.symptoms != null)) {
          for (HealthSymptom symptom in group.symptoms) {
            if (selected.contains(symptom.id)) {
              symptoms.add(symptom);
            }
          }
        }
      }
    }
    return symptoms;
  }

  static List<HealthSymptomsGroup> listFromJson(List<dynamic> json) {
    List<HealthSymptomsGroup> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthSymptomsGroup value;
          try { value = HealthSymptomsGroup.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthSymptomsGroup> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthSymptomsGroup value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// HealthRulesSet

class HealthRulesSet {
  final HealthTestRulesSet tests;
  final HealthSymptomsRulesSet symptoms;
  final HealthContactTraceRulesSet contactTrace;
  final HealthActionRulesSet actions;
  final HealthDefaultsSet defaults;
  final HealthCodesSet codes;
  final Map<String, _HealthRuleStatus> statuses;
  final Map<String, dynamic> constants;
  final Map<String, dynamic> constantOverrides;
  final Map<String, dynamic> strings;


  static const String UserTestMonitorInterval = 'UserTestMonitorInterval';

  HealthRulesSet({this.tests, this.symptoms, this.contactTrace, this.actions, this.defaults, HealthCodesSet codes, this.statuses, Map<String, dynamic> constants, Map<String, dynamic> strings}) :
    this.codes = codes ?? HealthCodesSet(),
    this.constants = constants ?? Map<String, dynamic>(),
    this.constantOverrides = Map<String, dynamic>(),
    this.strings = strings ?? Map<String, dynamic>();

  factory HealthRulesSet.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRulesSet(
      tests: HealthTestRulesSet.fromJson(json['tests']),
      symptoms: HealthSymptomsRulesSet.fromJson(json['symptoms']),
      contactTrace: HealthContactTraceRulesSet.fromJson(json['contact_trace']),
      actions: HealthActionRulesSet.fromJson(json['actions']),
      defaults: HealthDefaultsSet.fromJson(json['defaults']),
      codes: HealthCodesSet.fromJson(json['codes']),
      statuses: _HealthRuleStatus.mapFromJson(json['statuses']),
      constants: json['constants'],
      strings: json['strings'],
    ) : null;
  }

  bool operator ==(o) {
    return (o is HealthRulesSet) &&
      (o.tests == tests) &&
      (o.symptoms == symptoms) &&
      (o.contactTrace == contactTrace) &&
      (o.actions == actions) &&
      (o.defaults == defaults) &&
      (o.codes == codes) &&
      MapEquality().equals(o.statuses, statuses) &&
      MapEquality().equals(o.constants, constants) &&
      DeepCollectionEquality().equals(o.strings, strings);
  }

  int get hashCode =>
    (tests?.hashCode ?? 0) ^
    (symptoms?.hashCode ?? 0) ^
    (contactTrace?.hashCode ?? 0) ^
    (actions?.hashCode ?? 0) ^
    (defaults?.hashCode ?? 0) ^
    (codes?.hashCode ?? 0) ^
    MapEquality().hash(statuses) ^
    MapEquality().hash(constants) ^
    DeepCollectionEquality().hash(strings);

  int get userTestMonitorInterval {
    return getConstant(UserTestMonitorInterval);
  }

  set userTestMonitorInterval(int value) {
    constantOverrides[UserTestMonitorInterval] = value;
  }

  dynamic getConstant(String name) {
    return constantOverrides[name] ?? constants[name];
  }

  String localeString(dynamic entry) {
    if ((strings != null) && (entry is String)) {
      String currentLanguage = Localization().currentLocale?.languageCode;
      Map<String, dynamic> currentLanguageStrings = (currentLanguage != null) ? strings[currentLanguage] : null;
      dynamic currentResult = (currentLanguageStrings != null) ? currentLanguageStrings[entry] : null;
      if (currentResult != null) {
        return currentResult;
      }

      String defaultLanguage = Localization().defaultLocale?.languageCode;
      Map<String, dynamic> defaultLanguageStrings = (defaultLanguage != null) ? strings[defaultLanguage] : null;
      dynamic defaultResult = (defaultLanguageStrings != null) ? defaultLanguageStrings[entry] : null;
      if (defaultResult is String) {
        return defaultResult;
      }
    }

    return Localization().localeString(entry) ?? entry;
  }
}

///////////////////////////////
// HealthDefaultsSet

class HealthDefaultsSet {
  final _HealthRuleStatus status;

  HealthDefaultsSet({this.status});

  factory HealthDefaultsSet.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthDefaultsSet(
      status: _HealthRuleStatus.fromJson(json['status']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthDefaultsSet) &&
      (o.status == status);

  int get hashCode =>
    (status?.hashCode ?? 0);
}

///////////////////////////////
// HealthCodesSet

class HealthCodesSet {
  final List<HealthCodeData> _codesList;
  final Map<String, HealthCodeData> _codesMap;
  final List<String> _info;

  HealthCodesSet({List<HealthCodeData> codes, List<String> info}) :
    _codesList = codes,
    _codesMap = HealthCodeData.mapFromList(codes),
    _info = info;


  factory HealthCodesSet.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthCodesSet(
      codes: HealthCodeData.listFromJson(json['list']),
      info: json['info']?.cast<String>()
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthCodesSet) &&
      ListEquality().equals(o._codesList, _codesList) &&
      ListEquality().equals(o._info, _info);

  int get hashCode =>
    ListEquality().hash(_codesList) ^
    ListEquality().hash(_info);

  List<HealthCodeData> get list {
    return _codesList;
  }

  HealthCodeData operator [](String code) {
    return (_codesMap != null) ? _codesMap[code] : null;
  }

  List<String> info({HealthRulesSet rules}) {
    List<String> result;
    if (_info != null) {
      result = <String>[];
      for (String entry in _info) {
        result.add(rules?.localeString(entry) ?? entry);
      }
    }
    return result;
  }
}

///////////////////////////////
// HealthCodeData

class HealthCodeData {
  final String code;
  final String _colorString;
  final Color  _color;
  final String _name;
  final String _description;
  final String _longDescription;
  final bool visible;
  final bool reportsExposures;

  HealthCodeData({this.code, String color, String name, String description, String longDescription, this.visible, this.reportsExposures}) :
    _colorString = color,
    _color = UiColors.fromHex(color),
    _name = name,
    _description = description,
    _longDescription = longDescription;

  factory HealthCodeData.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthCodeData(
      code: json['code'],
      color: json['color'],
      name: json['name'],
      description: json['description'],
      longDescription: json['long_description'],
      visible: json['visible'],
      reportsExposures: json['reports_exposures']
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthCodeData) &&
      (o.code == code) &&
      (o._colorString == _colorString) &&
      (o._name == _name) &&
      (o._description == _description) &&
      (o._longDescription == _longDescription) &&
      (o.visible == visible) &&
      (o.reportsExposures == reportsExposures);

  int get hashCode =>
    (code?.hashCode ?? 0) ^
    (_colorString?.hashCode ?? 0) ^
    (_name?.hashCode ?? 0) ^
    (_description?.hashCode ?? 0) ^
    (_longDescription?.hashCode ?? 0) ^
    (visible?.hashCode ?? 0) ^
    (reportsExposures?.hashCode ?? 0);

  Color get color {
    return _color;
  }
  
  String name({HealthRulesSet rules}) {
    return rules?.localeString(_name) ?? _name;
  }

  String description({HealthRulesSet rules}) {
    return rules?.localeString(_description) ?? _description;
  }

  String displayName({HealthRulesSet rules}) {
    String nameValue = name(rules: rules);
    String descriptionValue = description(rules: rules);
    return ((nameValue != null) && (descriptionValue != null)) ? "$nameValue, $descriptionValue" : nameValue;
  }

  String longDescription({HealthRulesSet rules}) {
    return rules?.localeString(_longDescription) ?? _longDescription;
  }

  static List<HealthCodeData> listFromJson(List<dynamic> json) {
    List<HealthCodeData> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthCodeData.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static Map<String, HealthCodeData> mapFromList(List<HealthCodeData> list) {
    Map<String, HealthCodeData> map;
    if (list != null) {
      map = <String, HealthCodeData>{};
      for (HealthCodeData entry in list) {
        if (entry?.code != null) {
          map[entry.code] = entry;
        }
      }
    }
    return map;
  }
}

///////////////////////////////
// HealthTestRulesSet

class HealthTestRulesSet {
  final List<HealthTestRule> _rules;

  HealthTestRulesSet({List<HealthTestRule> rules}) : _rules = rules;

  factory HealthTestRulesSet.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRulesSet(
      rules: HealthTestRule.listFromJson(json['rules'])
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthTestRulesSet) &&
      ListEquality().equals(o._rules, _rules);

  int get hashCode =>
    ListEquality().hash(_rules);

  HealthTestRuleResult matchRuleResult({ HealthHistoryBlob blob, HealthRulesSet rules }) {
    if ((_rules != null) && (blob != null)) {
      for (HealthTestRule rule in _rules) {
        if ((rule?.testType != null) && (rule?.testType?.toLowerCase() == blob?.testType?.toLowerCase()) && (rule.results != null)) {
          for (HealthTestRuleResult ruleResult in rule.results) {
            if ((ruleResult?.testResult != null) && (ruleResult.testResult.toLowerCase() == blob?.testResult?.toLowerCase())) {
              return ruleResult;
            }
          }
        }
      }
    }
    return null;
  }
}


///////////////////////////////
// HealthTestRule

class HealthTestRule {
  final String testType;
  final String category;
  final List<HealthTestRuleResult> results;

  HealthTestRule({this.testType, this.category, this.results});

  factory HealthTestRule.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRule(
      testType: json['test_type'],
      category: json['category'],
      results: HealthTestRuleResult.listFromJson(json['results']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthTestRule) &&
      (o.testType == testType) &&
      (o.category == category) &&
      ListEquality().equals(o.results, results);

  int get hashCode =>
    (testType?.hashCode ?? 0) ^
    (category?.hashCode ?? 0) ^
    ListEquality().hash(results);

  static List<HealthTestRule> listFromJson(List<dynamic> json) {
    List<HealthTestRule> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthTestRule.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }
}

///////////////////////////////
// HealthTestRuleResult

class HealthTestRuleResult {
  final String testResult;
  final String category;
  final _HealthRuleStatus status;

  HealthTestRuleResult({this.testResult, this.category, this.status});

  factory HealthTestRuleResult.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRuleResult(
      testResult: json['result'],
      category: json['category'],
      status: _HealthRuleStatus.fromJson(json['status']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthTestRuleResult) &&
      (o.testResult == testResult) &&
      (o.category == category) &&
      (status == status);

  int get hashCode =>
    (testResult?.hashCode ?? 0) ^
    (category?.hashCode ?? 0) ^
    (status?.hashCode ?? 0);

  static List<HealthTestRuleResult> listFromJson(List<dynamic> json) {
    List<HealthTestRuleResult> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthTestRuleResult.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static HealthTestRuleResult matchRuleResult(List<HealthTestRuleResult> results, { HealthHistoryBlob blob }) {
    if (results != null) {
      for (HealthTestRuleResult result in results) {
        if (result._matchBlob(blob)) {
          return result;
        }
      }
    }
    return null;
  }

  bool _matchBlob(HealthHistoryBlob blob) {
    return ((testResult != null) && (testResult.toLowerCase() == blob?.testResult?.toLowerCase()));
  }
}

///////////////////////////////
// HealthSymptomsRulesSet

class HealthSymptomsRulesSet {
  final List<HealthSymptomsRule> _rules;
  final List<HealthSymptomsGroup> groups;

  HealthSymptomsRulesSet({List<HealthSymptomsRule> rules, this.groups}) : _rules = rules;

  factory HealthSymptomsRulesSet.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptomsRulesSet(
      rules: HealthSymptomsRule.listFromJson(json['rules']),
      groups: HealthSymptomsGroup.listFromJson(json['groups']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthSymptomsRulesSet) &&
      ListEquality().equals(o._rules, _rules) &&
      ListEquality().equals(o.groups, groups);

  int get hashCode =>
    ListEquality().hash(_rules) ^
    ListEquality().hash(groups);

  HealthSymptomsRule matchRule({ HealthHistoryBlob blob, HealthRulesSet rules }) {
    if ((_rules != null) && (groups != null) && (blob?.symptomsIds != null)) {
     Map<String, int> counts = HealthSymptomsGroup.getCounts(groups, blob.symptomsIds);
      for (HealthSymptomsRule rule in _rules) {
        if (rule._matchCounts(counts, rules: rules)) {
          return rule;
        }
      }
    }
    return null;
  }
}

///////////////////////////////
// HealthSymptomsRule

class HealthSymptomsRule {
  final Map<String, _HealthRuleInterval> counts;
  final _HealthRuleStatus status;
  
  HealthSymptomsRule({this.counts, this.status});

  factory HealthSymptomsRule.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptomsRule(
      counts: _countsFromJson(json['counts']),
      status: _HealthRuleStatus.fromJson(json['status']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthSymptomsRule) &&
      MapEquality().equals(o.counts, counts) &&
      (o.status == status);

  int get hashCode =>
    MapEquality().hash(counts) ^
    (status?.hashCode ?? 0);

  static List<HealthSymptomsRule> listFromJson(List<dynamic> json) {
    List<HealthSymptomsRule> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthSymptomsRule.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static Map<String, _HealthRuleInterval> _countsFromJson(Map<String, dynamic> json) {
    Map<String, _HealthRuleInterval> values;
    if (json != null) {
      values = Map<String, _HealthRuleInterval>();
      json.forEach((key, value) {
        values[key] = _HealthRuleInterval.fromJson(value);
      });
    }
    return values;
  }

  bool _matchCounts(Map<String, int> testCounts, { HealthRulesSet rules }) {
    if (this.counts != null) {
      for (String groupName in this.counts.keys) {
        _HealthRuleInterval value = this.counts[groupName];
        int count = (testCounts != null) ? testCounts[groupName] : null;
        if (!value.match(count, rules: rules)) {
          return false;
        }

      }
    }
    return true;
  }
}

///////////////////////////////
// HealthContactTraceRulesSet

class HealthContactTraceRulesSet {
  final List<HealthContactTraceRule> _rules;

  HealthContactTraceRulesSet({List<HealthContactTraceRule> rules}) : _rules = rules;

  factory HealthContactTraceRulesSet.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthContactTraceRulesSet(
      rules: HealthContactTraceRule.listFromJson(json['rules']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthContactTraceRulesSet) &&
      ListEquality().equals(o._rules, _rules);

  int get hashCode =>
    ListEquality().hash(_rules);


  HealthContactTraceRule matchRule({ HealthHistoryBlob blob, HealthRulesSet rules }) {
    if ((_rules != null) && (blob != null)) {
      for (HealthContactTraceRule rule in _rules) {
        if (rule._matchBlob(blob, rules: rules)) {
          return rule;
        }
      }
    }
    return null;
  }
}

///////////////////////////////
// HealthContactTraceRule

class HealthContactTraceRule {
  final _HealthRuleInterval duration;
  final _HealthRuleStatus status;

  HealthContactTraceRule({this.duration, this.status});

  bool operator ==(o) =>
    (o is HealthContactTraceRule) &&
      (o.duration == duration) &&
      (o.status == status);

  int get hashCode =>
    (duration?.hashCode ?? 0) ^
    (status?.hashCode ?? 0);

  factory HealthContactTraceRule.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthContactTraceRule(
      duration: _HealthRuleInterval.fromJson(json['duration']),
      status: _HealthRuleStatus.fromJson(json['status']),
    ) : null;
  }

  static List<HealthContactTraceRule> listFromJson(List<dynamic> json) {
    List<HealthContactTraceRule> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthContactTraceRule.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  bool _matchBlob(HealthHistoryBlob blob, { HealthRulesSet rules }) {
    return (duration != null) && duration.match(blob?.traceDurationInMinutes, rules: rules);
  }
}

///////////////////////////////
// HealthActionRulesSet

class HealthActionRulesSet {
  final List<HealthActionRule> _rules;

  HealthActionRulesSet({List<HealthActionRule> rules}) : _rules = rules;

  factory HealthActionRulesSet.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthActionRulesSet(
      rules: HealthActionRule.listFromJson(json['rules']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthActionRulesSet) &&
      ListEquality().equals(o._rules, _rules);

  int get hashCode =>
    ListEquality().hash(_rules);

  HealthActionRule matchRule({ HealthHistoryBlob blob, HealthRulesSet rules }) {
    if (_rules != null) {
      for (HealthActionRule rule in _rules) {
        if (rule._matchBlob(blob, rules: rules)) {
          return rule;
        }
      }
    }
    return null;
  }
}

///////////////////////////////
// HealthActionRule

class HealthActionRule {
  final String type;
  final _HealthRuleStatus status;

  HealthActionRule({this.type, this.status});

  factory HealthActionRule.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthActionRule(
      type: json['type'],
      status: _HealthRuleStatus.fromJson(json['status']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthActionRule) &&
      (o.type == type) &&
      (o.status == status);

  int get hashCode =>
    (type?.hashCode ?? 0) ^
    (status?.hashCode ?? 0);

  static List<HealthActionRule> listFromJson(List<dynamic> json) {
    List<HealthActionRule> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthActionRule.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  bool _matchBlob(HealthHistoryBlob blob, {HealthRulesSet rules}) {
    return (type != null) && (type.toLowerCase() == blob?.actionType?.toLowerCase());
  }
}

///////////////////////////////
// _HealthRuleStatus

abstract class _HealthRuleStatus {
  
  _HealthRuleStatus();
  
  factory _HealthRuleStatus.fromJson(dynamic json) {
    if (json is Map) {
      if (json['condition'] != null) {
        try { return HealthRuleConditionalStatus.fromJson(json.cast<String, dynamic>()); }
        catch (e) { print(e?.toString()); }
      }
      else {
        try { return HealthRuleStatus.fromJson(json.cast<String, dynamic>()); }
        catch (e) { print(e?.toString()); }
      }
    }
    else if (json is String) {
      return HealthRuleReferenceStatus.fromJson(json);
    }
    return null;
  }

  static Map<String, _HealthRuleStatus> mapFromJson(Map<String, dynamic> json) {
    Map<String, _HealthRuleStatus> result;
    if (json != null) {
      result = Map<String, _HealthRuleStatus>();
      json.forEach((String key, dynamic value) {
        try { result[key] =  _HealthRuleStatus.fromJson(value); }
        catch (e) { print(e?.toString()); }
      });
    }
    return result;
  }

  HealthRuleStatus eval({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules });
}

///////////////////////////////
// HealthRuleStatus

class HealthRuleStatus extends _HealthRuleStatus {

  final String code;
  final int priority;

  final dynamic nextStep;
  final dynamic nextStepHtml;
  final _HealthRuleInterval nextStepInterval;
  final DateTime nextStepDateUtc;

  final dynamic eventExplanation;
  final dynamic eventExplanationHtml;

  final dynamic reason;
  final dynamic warning;

  final dynamic fcmTopic;

  HealthRuleStatus({this.code, this.priority,
    this.nextStep, this.nextStepHtml, this.nextStepInterval, this.nextStepDateUtc,
    this.eventExplanation, this.eventExplanationHtml,
    this.reason, this.warning, this.fcmTopic });

  factory HealthRuleStatus.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleStatus(
      code:                 json['code'],
      priority:             json['priority'],
      nextStep:             json['next_step'],
      nextStepHtml:         json['next_step_html'],
      nextStepInterval:     _HealthRuleInterval.fromJson(json['next_step_interval']),
      eventExplanation:     json['event_explanation'],
      eventExplanationHtml: json['event_explanation_html'],
      reason:               json['reason'],
      warning:              json['warning'],
      fcmTopic:             json['fcm_topic']
    ) : null;
  }

  factory HealthRuleStatus.fromStatus(HealthRuleStatus status, { DateTime nextStepDateUtc, }) {
    
    return (status != null) ? HealthRuleStatus(
      code:                 status.code,
      priority:             status.priority,
      nextStep:             status.nextStep,
      nextStepHtml:         status.nextStepHtml,
      nextStepInterval:     status.nextStepInterval,
      nextStepDateUtc:      nextStepDateUtc ?? status.nextStepDateUtc,
      eventExplanation:     status.eventExplanation,
      eventExplanationHtml: status.eventExplanationHtml,
      reason:               status.reason,
      warning:              status.warning,
      fcmTopic:             status.fcmTopic,
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthRuleStatus) &&
      (o.code == code) &&
      (o.priority == priority) &&
      
      (o.nextStep == nextStep) &&
      (o.nextStepHtml == nextStepHtml) &&
      (o.nextStepInterval == nextStepInterval) &&
      (o.nextStepDateUtc == nextStepDateUtc) &&

      (o.eventExplanation == eventExplanation) &&
      (o.eventExplanationHtml == eventExplanationHtml) &&

      (o.reason == reason) &&
      (o.warning == warning) &&

      (o.fcmTopic == fcmTopic);

  int get hashCode =>
    (code?.hashCode ?? 0) ^
    (priority?.hashCode ?? 0) ^
    
    (nextStep?.hashCode ?? 0) ^
    (nextStepHtml?.hashCode ?? 0) ^
    (nextStepInterval?.hashCode ?? 0) ^
    (nextStepDateUtc?.hashCode ?? 0) ^

    (eventExplanation?.hashCode ?? 0) ^
    (eventExplanationHtml?.hashCode ?? 0) ^

    (reason?.hashCode ?? 0) ^
    (warning?.hashCode ?? 0) ^

    (fcmTopic?.hashCode ?? 0);

  @override
  HealthRuleStatus eval({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules }) {
    int originIndex = (nextStepInterval?.origin(rules: rules) == HealthRuleIntervalOrigin.referenceDate) ? referenceIndex : historyIndex;
    HealthHistory originEntry = ((history != null) && (originIndex != null) && (0 <= originIndex) && (originIndex < history.length)) ? history[originIndex] : null;
    DateTime originDateUtc = originEntry?.dateUtc;
    int numberOfDays = nextStepInterval?.value(rules: rules);

    return HealthRuleStatus.fromStatus(this,
      nextStepDateUtc: ((originDateUtc != null) && (numberOfDays != null)) ? originDateUtc.add(Duration(days: numberOfDays)) : null,
    ) ;
  }

  bool canUpdateStatus({HealthStatusBlob blob}) {
    int blobStatusPriority = blob?.priority ?? 0;
    int newStatusPriority = this.priority ?? 0;
    return (newStatusPriority < 0) || (blobStatusPriority <= newStatusPriority);
  }
}

///////////////////////////////
// HealthRuleReferenceStatus

class HealthRuleReferenceStatus extends _HealthRuleStatus {
  final String reference;
  HealthRuleReferenceStatus({this.reference});

  factory HealthRuleReferenceStatus.fromJson(String json) {
    return (json != null) ? HealthRuleReferenceStatus(
      reference: json,
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthRuleReferenceStatus) &&
      (o.reference == reference);

  int get hashCode =>
    (reference?.hashCode ?? 0);

  @override
  HealthRuleStatus eval({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules }) {
    _HealthRuleStatus status = (rules?.statuses != null) ? rules?.statuses[reference] : null;
    return status?.eval(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules);
  }
}

///////////////////////////////
// HealthRuleConditionalStatus

class HealthRuleConditionalStatus extends _HealthRuleStatus {
  final String condition;
  final Map<String, dynamic> params;
  final _HealthRuleStatus successStatus;
  final _HealthRuleStatus failStatus;

  HealthRuleConditionalStatus({this.condition, this.params, this.successStatus, this.failStatus});

  factory HealthRuleConditionalStatus.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleConditionalStatus(
      condition: json['condition'],
      params: json['params'],
      successStatus: _HealthRuleStatus.fromJson(json['success']) ,
      failStatus: _HealthRuleStatus.fromJson(json['fail']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthRuleConditionalStatus) &&
      (o.condition == condition) &&
      DeepCollectionEquality().equals(o.params, params) &&
      (o.successStatus == successStatus) &&
      (o.failStatus == failStatus);

  int get hashCode =>
    (condition?.hashCode ?? 0) ^
    DeepCollectionEquality().hash(params) ^
    (successStatus?.hashCode ?? 0) ^
    (failStatus?.hashCode ?? 0);

  @override
  HealthRuleStatus eval({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules }) {
    dynamic result;
    if (condition == 'require-test') {
      // (index >= 0) / -1 / null
      result = _evalRequireTest(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules);
    }
    else if (condition == 'require-symptoms') {
      // (index >= 0) / -1 / null
      result = _evalRequireSymptoms(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules);
    }
    else if (condition == 'timeout') {
      // true / false / null
      result = _evalTimeout(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules);
    }
    else if (condition == 'test-user') {
      // true / false
      result = _evalTestUser(rules: rules);
    }
    else if (condition == 'test-interval') {
      // true / false
      result = _evalTestInterval(rules: rules);
    }
    
    _HealthRuleStatus status;
    if (result is bool) {
      status = result ? successStatus : failStatus;
    }
    else if (result is int) {
      if (0 <= result) {
        status = successStatus;
        referenceIndex = result;
      }
      else {
        status = failStatus;
      }
    }

    return status?.eval(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules);
  }

  dynamic _evalRequireTest({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules }) {
    
    _HealthRuleInterval interval = _HealthRuleInterval.fromJson(params['interval']);
    if (interval == null) {
      return null;
    }

    int originIndex = (interval.origin(rules: rules) == HealthRuleIntervalOrigin.referenceDate) ? referenceIndex : historyIndex;
    HealthHistory originEntry = ((history != null) && (originIndex != null) && (0 <= originIndex) && (originIndex < history.length)) ? history[originIndex] : null;
    DateTime originDateMidnightLocal = originEntry?.dateMidnightLocal;
    if (originDateMidnightLocal == null) {
      return null;
    }

    dynamic category = params['category'];
    if (category is List) {
      category = Set.from(category);
    }

    int scope = interval.scope(rules: rules) ?? 0;
    if (0 < scope) { // check only newer items than the current
      for (int index = originIndex - 1; 0 <= index; index--) {
        if (_evalRequireTestEntryFulfills(history[index], originDateMidnightLocal: originDateMidnightLocal, interval: interval, rules: rules, category: category)) {
          return index;
        }
      }
    }
    else if (0 < scope) { // check only older items than the current
      for (int index = originIndex + 1; index < history.length; index++) {
        if (_evalRequireTestEntryFulfills(history[index], originDateMidnightLocal: originDateMidnightLocal, interval: interval, rules: rules, category: category)) {
          return index;
        }
      }
    }
    else { // check all history items
      for (int index = 0; index < history.length; index++) {
        if ((index != originIndex) && _evalRequireTestEntryFulfills(history[index], originDateMidnightLocal: originDateMidnightLocal, interval: interval, rules: rules, category: category)) {
          return index;
        }
      }
    }

    // If positive time interval is not already expired - do not return failed status yet.
    if ((interval.current(rules: rules) == true) && _evalCurrentIntervalFulfills(interval, originDateMidnightLocal: originDateMidnightLocal, rules: rules)) {
      return originIndex;
    }

    return -1;
  }

  static bool _evalRequireTestEntryFulfills(HealthHistory entry, { DateTime originDateMidnightLocal,  _HealthRuleInterval interval, HealthRulesSet rules, dynamic category }) {
    if (entry.isTest && entry.canTestUpdateStatus) {
      DateTime entryDateMidnightLocal = entry.dateMidnightLocal;
      final difference = entryDateMidnightLocal.difference(originDateMidnightLocal).inDays;
      if (interval.match(difference, rules: rules)) {
        if (category == null) {
          return true; // any test matches
        }
        else {
          HealthTestRuleResult entryRuleResult = rules?.tests?.matchRuleResult(blob: entry?.blob);
          if ((entryRuleResult != null) && (entryRuleResult.category != null) &&
              (((category is String) && (category == entryRuleResult.category)) ||
                ((category is Set) && category.contains(entryRuleResult.category))))
          {
            return true; // only tests from given category matches
          }
        }
      }
    }
    return false;
  }

  dynamic _evalRequireSymptoms({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules }) {
    _HealthRuleInterval interval = _HealthRuleInterval.fromJson(params['interval']);
    if (interval == null) {
      return null;
    }

    int originIndex = (interval.origin(rules: rules) == HealthRuleIntervalOrigin.referenceDate) ? referenceIndex : historyIndex;
    HealthHistory originEntry = ((history != null) && (originIndex != null) && (0 <= originIndex) && (originIndex < history.length)) ? history[originIndex] : null;
    DateTime originDateMidnightLocal = originEntry?.dateMidnightLocal;
    if (originDateMidnightLocal == null) {
      return null;
    }

    int scope = interval.scope(rules: rules) ?? 0;
    if (0 < scope) { // check only newer items than the current
      for (int index = originIndex - 1; 0 <= index; index--) {
        if (_evalRequireSymptomsEntryFulfills(history[index], originDateMidnightLocal: originDateMidnightLocal, interval: interval, rules: rules)) {
          return index;
        }
      }
    }
    else if (0 < scope) { // check only older items than the current
      for (int index = originIndex + 1; index < history.length; index++) {
        if (_evalRequireSymptomsEntryFulfills(history[index], originDateMidnightLocal: originDateMidnightLocal, interval: interval, rules: rules)) {
          return index;
        }
      }
    }
    else { // check all history items
      for (int index = 0; index < history.length; index++) {
        if ((index != originIndex) && _evalRequireSymptomsEntryFulfills(history[index], originDateMidnightLocal: originDateMidnightLocal, interval: interval, rules: rules)) {
          return index;
        }
      }
    }

    // If positive time interval is not already expired - do not return failed status yet.
    if ((interval.current(rules: rules) == true) && _evalCurrentIntervalFulfills(interval, originDateMidnightLocal: originDateMidnightLocal, rules: rules)) {
      return originIndex;
    }

    return -1;
  }

  static bool _evalRequireSymptomsEntryFulfills(HealthHistory entry, { DateTime originDateMidnightLocal,  _HealthRuleInterval interval, HealthRulesSet rules }) {
    if (entry.isSymptoms) {
      DateTime entryDateMidnightLocal = entry.dateMidnightLocal;
      final difference = entryDateMidnightLocal.difference(originDateMidnightLocal).inDays;
      if (interval.match(difference, rules: rules)) {
        return true;
      }
    }
    return false;
  }

  dynamic _evalTimeout({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules }) {
    _HealthRuleInterval interval = _HealthRuleInterval.fromJson(params['interval']);
    if (interval == null) {
      return null;
    }

    int originIndex = (interval.origin(rules: rules) == HealthRuleIntervalOrigin.referenceDate) ? referenceIndex : historyIndex;
    HealthHistory originEntry = ((history != null) && (originIndex != null) && (0 <= originIndex) && (originIndex < history.length)) ? history[originIndex] : null;
    DateTime originDateMidnightLocal = originEntry?.dateMidnightLocal;
    if (originDateMidnightLocal == null) {
      return null;
    }

    // while current time is within interval 'timeout' condition fails
    return !_evalCurrentIntervalFulfills(interval, originDateMidnightLocal: originDateMidnightLocal, rules: rules);
  }

  static bool _evalCurrentIntervalFulfills(_HealthRuleInterval currentInterval, { DateTime originDateMidnightLocal, HealthRulesSet rules } ) {
    if (currentInterval != null) {
      final difference = AppDateTime.todayMidnightLocal.difference(originDateMidnightLocal).inDays;
      if (currentInterval.match(difference, rules: rules)) {
        return true;
      }
    }
    return false;
  }

  dynamic _evalTestInterval({ HealthRulesSet rules }) {
    dynamic interval = _HealthRuleInterval.fromJson(params['interval']);
    return (interval?.valid(rules: rules) ?? false);
  }

  dynamic _evalTestUser({ HealthRulesSet rules }) {
    
    dynamic role = params['role'];
    if ((role != null) && !_matchStringTarget(target: UserRole.userRolesToList(UserProfile().roles), source: role)) {
      return false;
    }
    
    dynamic login = params['login'];
    if (login != null) {
      if (login is bool) {
        if (Auth().isLoggedIn != login) {
          return false;
        }
      }
      else if (login is String) {
        String loginLowerCase = login.toLowerCase();
        if ((loginLowerCase == 'phone') && !Auth().isPhoneLoggedIn) {
          return false;
        }
        else if ((loginLowerCase == 'phone.uin') && (!Auth().isPhoneLoggedIn || !Auth().hasUIN)) {
          return false;
        }
        else if ((loginLowerCase == 'netid') && !Auth().isShibbolethLoggedIn) {
          return false;
        }
        else if ((loginLowerCase == 'netid.uin') && (!Auth().isShibbolethLoggedIn || !Auth().hasUIN)) {
          return false;
        }
      }
    }
    
    dynamic cardRole = params['card.role'];
    if ((cardRole != null) && !_matchStringTarget(target: Auth().authCard?.role, source: cardRole)) {
      return false;
    }
    
    dynamic cardStudentLevel = params['card.student_level'];
    if ((cardStudentLevel != null) && !_matchStringTarget(target: Auth().authCard?.studentLevel, source: cardStudentLevel)) {
      return false;
    }

    return true;
  }

  static bool _matchStringTarget({dynamic source, dynamic target}) {
    if (target is String) {
      if (source is String) {
        return source.toLowerCase() == target.toLowerCase();
      }
      else if (source is List) {
        for (dynamic sourceEntry in source) {
          if ((sourceEntry is String) && (sourceEntry.toLowerCase() == target.toLowerCase())) {
            return true;
          }
        }
      }
    }
    else if (target is Iterable) {
      for (dynamic targetEntry in target) {
        if (_matchStringTarget(source: source, target: targetEntry)) {
          return true;
        }
      }
    }
    return false;
  }

}

///////////////////////////////
// _HealthRuleInterval

abstract class _HealthRuleInterval {
  _HealthRuleInterval();
  
  factory _HealthRuleInterval.fromJson(dynamic json) {
    if (json is int) {
      return HealthRuleIntervalValue.fromJson(json);
    }
    else if (json is String) {
      return HealthRuleIntervalReference.fromJson(json);
    }
    else if (json is Map) {
      return HealthRuleInterval.fromJson(json.cast<String, dynamic>());
    }
    else {
      return null;
    }
  }

  bool match(int value, { HealthRulesSet rules });
  int  value({ HealthRulesSet rules });
  bool valid({ HealthRulesSet rules });
  int  scope({ HealthRulesSet rules });
  bool current({ HealthRulesSet rules });
  HealthRuleIntervalOrigin origin({ HealthRulesSet rules });
}

enum HealthRuleIntervalOrigin { historyDate, referenceDate }

///////////////////////////////
// HealthRuleIntervalValue

class HealthRuleIntervalValue extends _HealthRuleInterval {
  final int _value;
  
  HealthRuleIntervalValue({int value}) :
    _value = value;

  factory HealthRuleIntervalValue.fromJson(dynamic json) {
    return (json is int) ? HealthRuleIntervalValue(value: json) : null;
  }

  bool operator ==(o) =>
    (o is HealthRuleIntervalValue) &&
      (o._value == _value);

  int get hashCode =>
    (_value?.hashCode ?? 0);

  @override
  bool match(int value, { HealthRulesSet rules }) {
    return (_value == value);
  }

  @override int  value({ HealthRulesSet rules })   { return _value; }
  @override bool valid({ HealthRulesSet rules })   { return (_value != null); }
  @override int  scope({ HealthRulesSet rules })   { return null; }
  @override bool current({ HealthRulesSet rules }) { return null; }
  @override HealthRuleIntervalOrigin origin({ HealthRulesSet rules }) { return null; }
}

///////////////////////////////
// HealthRuleInterval

class HealthRuleInterval extends _HealthRuleInterval {
  final _HealthRuleInterval _min;
  final _HealthRuleInterval _max;
  final _HealthRuleInterval _value;
  final int _scope;
  final bool _current;
  final HealthRuleIntervalOrigin _origin;
  
  HealthRuleInterval({_HealthRuleInterval min, _HealthRuleInterval max, _HealthRuleInterval value, int scope, bool current, HealthRuleIntervalOrigin origin}) :
    _min = min,
    _max = max,
    _value = value,
    _scope = scope,
    _current = current,
    _origin = origin;

  factory HealthRuleInterval.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleInterval(
      min: _HealthRuleInterval.fromJson(json['min']),
      max: _HealthRuleInterval.fromJson(json['max']),
      value: _HealthRuleInterval.fromJson(json['value']),
      scope: _scopeFromJson(json['scope']),
      current: json['current'],
      origin: _originFromJson(json['origin']),
    ) : null;
  }

  bool operator ==(o) =>
    (o is HealthRuleInterval) &&
      (o._min == _min) &&
      (o._max == _max) &&
      (o._value == _value) &&
      (o._scope == _scope) &&
      (o._current == _current) &&
      (o._origin == _origin);

  int get hashCode =>
    (_min?.hashCode ?? 0) ^
    (_max?.hashCode ?? 0) ^
    (_value?.hashCode ?? 0) ^
    (_scope?.hashCode ?? 0) ^
    (_current?.hashCode ?? 0) ^
    (_origin?.hashCode ?? 0);

  @override
  bool match(int value, { HealthRulesSet rules }) {
    if (value != null) {
      if (_min != null) {
        int minValue = _min.value(rules: rules);
        if ((minValue == null) || (minValue > value)) {
          return false;
        }
      }
      if (_max != null) {
        int maxValue = _max.value(rules: rules);
        if ((maxValue == null) || (maxValue < value)) {
          return false;
        }
      }
      if (_value != null) {
        int valueValue = _value.value(rules: rules);
        if ((valueValue == null) || (valueValue != value)) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override bool valid({ HealthRulesSet rules })   {
    return ((_min == null) || _min.valid(rules: rules)) &&
           ((_max == null) || _max.valid(rules: rules)) &&
           ((_value == null) || _value.valid(rules: rules));
  }

  @override int  value({ HealthRulesSet rules }) { return _value?.value(rules: rules); }
  @override int  scope({ HealthRulesSet rules }) { return _scope; }
  @override bool current({ HealthRulesSet rules }) { return _current; }
  @override HealthRuleIntervalOrigin origin({ HealthRulesSet rules }) { return _origin; }

  static int _scopeFromJson(dynamic value) {
    if (value is String) {
      if (value == 'future') {
        return 1;
      }
      else if (value == 'past') {
        return -1;
      }
    }
    else if (value is int) {
      if (0 < value) {
        return 1;
      }
      else if (value < 0) {
        return -1;
      }
    }
    return null;
  }

  static HealthRuleIntervalOrigin _originFromJson(dynamic value) {
    if (value == 'historyDate') {
      return HealthRuleIntervalOrigin.historyDate;
    }
    else if (value == 'referenceDate') {
      return HealthRuleIntervalOrigin.referenceDate;
    }
    else {
      return null;
    }
  }
}

///////////////////////////////
// HealthRuleIntervalReference

class HealthRuleIntervalReference extends _HealthRuleInterval {
  final String _reference;
  _HealthRuleInterval _referenceValue;

  HealthRuleIntervalReference({String reference}) :
    _reference = reference;

  factory HealthRuleIntervalReference.fromJson(dynamic json) {
    return (json is String) ? HealthRuleIntervalReference(reference: json) : null;
  }

  bool operator ==(o) =>
    (o is HealthRuleIntervalReference) &&
      (o._reference == _reference);

  int get hashCode =>
    (_reference?.hashCode ?? 0);

  _HealthRuleInterval referenceValue({ HealthRulesSet rules }) {
    if (_referenceValue == null) {
      _referenceValue = _HealthRuleInterval.fromJson(rules?.getConstant(_reference));
    }
    return _referenceValue;
  }

  @override
  bool match(int value, { HealthRulesSet rules }) {
    return referenceValue(rules: rules)?.match(value, rules: rules) ?? false;
  }
  
  @override bool valid({ HealthRulesSet rules })   { return referenceValue(rules: rules)?.valid(rules: rules) ?? false; }
  @override int  value({ HealthRulesSet rules })   { return referenceValue(rules: rules)?.value(rules: rules); }
  @override int  scope({ HealthRulesSet rules })   { return referenceValue(rules: rules)?.scope(rules: rules); }
  @override bool current({ HealthRulesSet rules }) { return referenceValue(rules: rules)?.current(rules: rules); }
  @override HealthRuleIntervalOrigin origin({ HealthRulesSet rules }) { return referenceValue(rules: rules)?.origin(rules: rules); }
}

///////////////////////////////
// Health DateTime

final List<String> _covid19ServerDateFormatsIn  = [
  "yyyy-MM-ddTHH:mm:ss.SSSZ",
  "yyyy-MM-ddTHH:mm:ss.SSZ",
  "yyyy-MM-ddTHH:mm:ss.SZ",
  "yyyy-MM-ddTHH:mm:ssZ",
];
final String _covid19ServerDateFormatOut = "yyyy-MM-ddTHH:mm:ss.SSS";

DateTime healthDateTimeFromString(String dateTimeString) {
  if (dateTimeString != null) {
    for (String dateFormat in _covid19ServerDateFormatsIn) {
      if (dateTimeString.length == dateFormat.length) {
        try { return DateFormat(dateFormat).parse(dateTimeString, true); }
        catch (e) { print(e?.toString()); }
      }
    }
  }
  return null;
}

String healthDateTimeToString(DateTime dateTime) {
  if (dateTime != null) {
    try { return DateFormat(_covid19ServerDateFormatOut).format(dateTime) + 'Z'; }
    catch (e) { print(e?.toString()); }
  }
  return null;
}

///////////////////////////////
// Blob Encryption & Decryption

String _decryptBlob(Map<String, dynamic> param) {
  String encKey = (param != null) ? param['encryptedKey'] : null;
  String encBlob = (param != null) ? param['encryptedBlob'] : null;
  PrivateKey privateKey = (param != null) ? param['privateKey'] : null;

  String aesKey = ((privateKey != null) && (encKey != null)) ? RSACrypt.decrypt(encKey, privateKey) : null;
  String blob = ((aesKey != null) && (encBlob != null)) ? AESCrypt.decrypt(encBlob, keyString: aesKey) : null;
  return blob;
}

Map<String, dynamic> _encryptBlob(Map<String, dynamic> param) {
  String blob = (param != null) ? param['blob'] : null;
  PublicKey publicKey =  (param != null) ? param['publicKey'] : null;
  String aesKey = AESCrypt.randomKey();

  String encryptedBlob = ((blob != null) && (aesKey != null)) ? AESCrypt.encrypt(blob, keyString: aesKey) : null;
  String encryptedKey = ((blob != null) && (aesKey != null) && (publicKey != null)) ? RSACrypt.encrypt(aesKey, publicKey) : null;

  return {
    'encryptedKey': encryptedKey,
    'encryptedBlob': encryptedBlob,
  };
}



