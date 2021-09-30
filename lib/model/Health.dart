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
import 'dart:math';

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
      (o.encryptedBlob == encryptedBlob) &&
      (o.blob == blob);
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

  final String warning;
  final String warningHtml;

  final String eventExplanation;
  final String eventExplanationHtml;

  final String statusUpdateNotice;
  final String statusUpdateNoticeHtml;

  final String statusUpdateReason;
  final String statusUpdateReasonHtml;

  final dynamic fcmTopic;

  final HealthHistoryBlob historyBlob;

  static const String _nextStepDateMacro = '{next_step_date}';
  static const String _nextStepDateFormat = 'EEEE, MMM d';

  HealthStatusBlob({this.code, this.priority,
    this.nextStep, this.nextStepHtml, this.nextStepDateUtc,
    this.warning, this.warningHtml,
    this.eventExplanation, this.eventExplanationHtml,
    this.statusUpdateNotice, this.statusUpdateNoticeHtml,
    this.statusUpdateReason, this.statusUpdateReasonHtml,
    this.fcmTopic, this.historyBlob});

  factory HealthStatusBlob.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthStatusBlob(
      code: json['code'] ?? json['health_status'],
      priority: json['priority'],
      nextStep: json['next_step'],
      nextStepHtml: json['next_step_html'],
      nextStepDateUtc: healthDateTimeFromString(json['next_step_date']),
      warning: json['warning'],
      warningHtml: json['warning_html'],
      eventExplanation: json['event_explanation'],
      eventExplanationHtml: json['event_explanation_html'],
      statusUpdateNotice: json['notice'],
      statusUpdateNoticeHtml: json['notice_html'],
      statusUpdateReason: json['reason'],
      statusUpdateReasonHtml: json['reason_html'],
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
      'warning': warning,
      'warning_html': warningHtml,
      'event_explanation': eventExplanation,
      'event_explanation_html': eventExplanationHtml,
      'notice': statusUpdateNotice,
      'notice_html': statusUpdateNoticeHtml,
      'reason': statusUpdateReason,
      'reason_html': statusUpdateReasonHtml,
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
      (o.warning == warning) &&
      (o.warningHtml == warningHtml) &&
      (o.eventExplanation == eventExplanation) &&
      (o.eventExplanationHtml == eventExplanationHtml) &&
      (o.statusUpdateNotice == statusUpdateNotice) &&
      (o.statusUpdateNoticeHtml == statusUpdateNoticeHtml) &&
      (o.statusUpdateReason == statusUpdateReason) &&
      (o.statusUpdateReasonHtml == statusUpdateReasonHtml) &&
      DeepCollectionEquality().equals(o.fcmTopic, fcmTopic) &&
      (o.historyBlob == historyBlob);
  }

  int get hashCode =>
    (code?.hashCode ?? 0) ^
    (priority?.hashCode ?? 0) ^
    (nextStep?.hashCode ?? 0) ^
    (nextStepHtml?.hashCode ?? 0) ^
    (nextStepDateUtc?.hashCode ?? 0) ^
    (warning?.hashCode ?? 0) ^
    (warningHtml?.hashCode ?? 0) ^
    (eventExplanation?.hashCode ?? 0) ^
    (eventExplanationHtml?.hashCode ?? 0) ^
    (statusUpdateNotice?.hashCode ?? 0) ^
    (statusUpdateNoticeHtml?.hashCode ?? 0) ^
    (statusUpdateReason?.hashCode ?? 0) ^
    (statusUpdateReasonHtml?.hashCode ?? 0) ^
    (DeepCollectionEquality().hash(fcmTopic) ?? 0) ^
    (historyBlob?.hashCode ?? 0);

  factory HealthStatusBlob.fromRuleStatus(HealthRuleStatus ruleStatus, { HealthRulesSet rules, HealthStatusBlob previousStatusBlob, HealthHistoryBlob historyBlob }) {
    return (ruleStatus != null) ? HealthStatusBlob(
      code: (ruleStatus.code != null) ? ruleStatus.code : previousStatusBlob?.code,
      priority: (ruleStatus.priority != null) ? ruleStatus.priority.abs() : previousStatusBlob?.priority,
      nextStep: ((ruleStatus.nextStep != null) || (ruleStatus.nextStepHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.nextStep) : previousStatusBlob?.nextStep,
      nextStepHtml: ((ruleStatus.nextStep != null) || (ruleStatus.nextStepHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.nextStepHtml) : previousStatusBlob?.nextStepHtml,
      nextStepDateUtc: ((ruleStatus.nextStepInterval != null) || (ruleStatus.nextStep != null) || (ruleStatus.nextStepHtml != null) || (ruleStatus.code != null)) ? ruleStatus.nextStepDateUtc : previousStatusBlob?.nextStepDateUtc,
      eventExplanation: ((ruleStatus.eventExplanation != null) || (ruleStatus.eventExplanationHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.eventExplanation) : previousStatusBlob?.eventExplanation,
      eventExplanationHtml: ((ruleStatus.eventExplanation != null) || (ruleStatus.eventExplanationHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.eventExplanationHtml) : previousStatusBlob?.eventExplanationHtml,
      warning: ((ruleStatus.warning != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.warning) : previousStatusBlob?.warning,
      warningHtml: ((ruleStatus.warningHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.warningHtml) : previousStatusBlob?.warningHtml,
      statusUpdateNotice: ((ruleStatus.statusUpdateNotice != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.statusUpdateNotice) : previousStatusBlob?.statusUpdateNotice,
      statusUpdateNoticeHtml: ((ruleStatus.statusUpdateNoticeHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.statusUpdateNoticeHtml) : previousStatusBlob?.statusUpdateNoticeHtml,
      statusUpdateReason: ((ruleStatus.statusUpdateReason != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.statusUpdateReason) : previousStatusBlob?.statusUpdateReason,
      statusUpdateReasonHtml: ((ruleStatus.statusUpdateReasonHtml != null) || (ruleStatus.code != null)) ? rules.localeString(ruleStatus.statusUpdateReasonHtml) : previousStatusBlob?.statusUpdateReasonHtml,
      fcmTopic: ((ruleStatus.fcmTopic != null) || (ruleStatus.code != null)) ?  ruleStatus.fcmTopic : previousStatusBlob?.fcmTopic,
      historyBlob: historyBlob,
    ) : null;
  }
  
  String get displayNextStep {
    return _processMacros(nextStep);
  }

  String get displayNextStepHtml {
    return _processMacros(nextStepHtml);
  }

  String displayNextStepDate({String format = _nextStepDateFormat}) {
    if (nextStepDateUtc != null) {
      DateTime nextStepMidnightLocal = AppDateTime.midnight(nextStepDateUtc.toLocal());
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

  String get displayWarning {
    return _processMacros(warning);
  }

  String get displayWarningHtml {
    return _processMacros(warningHtml);
  }

  String get displayEventExplanation {
    return _processMacros(eventExplanation);
  }

  String get displayEventExplanationHtml {
    return _processMacros(eventExplanationHtml);
  }

  String get displayStatusUpdateNotice {
    return _processMacros(statusUpdateNotice);
  }

  String get displayStatusUpdateNoticeHtml {
    return _processMacros(statusUpdateNoticeHtml);
  }

  String get displayStatusUpdateReason {
    return _processMacros(statusUpdateReason);
  }

  String get displayStatusUpdateReasonHtml {
    return _processMacros(statusUpdateReasonHtml);
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

  bool get isVaccine {
    return (type == HealthHistoryType.vaccine);
  }

  bool get isAction {
    return (type == HealthHistoryType.action);
  }

  DateTime get dateMidnightLocal {
    return (dateUtc != null) ? AppDateTime.midnight(dateUtc.toLocal()) : null;
  }

  bool matchPendingEvent(HealthPendingEvent event) {
    if (event.isTest) {
      return this.isTest &&
        (this.dateUtc == event?.blob?.dateUtc) &&
        (this.blob?.provider == event?.provider) &&
        (this.blob?.providerId == event?.providerId) &&
        (this.blob?.testType == event?.blob?.testType) &&
        (this.blob?.testResult == event?.blob?.testResult) &&
        (DeepCollectionEquality().equals(this.blob.extras, event.blob.extras));
    }
    else if (event.isVaccine) {
      return this.isVaccine &&
        (this.dateUtc == event?.blob?.dateUtc) &&
        (this.blob?.provider == event?.provider) &&
        (this.blob?.providerId == event?.providerId) &&
        (this.blob?.vaccine == event?.blob?.vaccine);
    }
    else if (event.isAction) {
      return this.isAction &&
        (this.dateUtc == event?.blob?.dateUtc) &&
        (this.blob?.actionType == event?.blob?.actionType) &&
        (DeepCollectionEquality().equals(this.blob?.actionText, event?.blob?.actionText)) &&
        (DeepCollectionEquality().equals(this.blob?.actionTitle, event?.blob?.actionTitle)) &&
        (DeepCollectionEquality().equals(this.blob?.actionParams, event?.blob?.actionParams)) &&
        (DeepCollectionEquality().equals(this.blob.extras, event.blob.extras));
    }
    else {
      return false;
    }
  }

  static Future<List<HealthHistory>> listFromJson(List<dynamic> json, Map<HealthHistoryType, PrivateKey> privateKeys) async {
    if (json != null) {
      List<Future<HealthHistory>> futures = <Future<HealthHistory>>[];
      for (dynamic entry in json) {
        futures.add(HealthHistory.decryptedFromJson((entry as Map)?.cast<String, dynamic>(), privateKeys));
      }
      List<HealthHistory> results = await Future.wait(futures);
      return (results != null) ? List.from(results) : null;
    }
    return null;
  }

  static List<dynamic> listToJson(List<HealthHistory> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
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

  static int retrieveNumTests(List<HealthHistory> history, int prevHours, { DateTime maxDateUtc }) {
    int count = 0;
    if (history != null) {

      if (maxDateUtc == null) {
        maxDateUtc = DateTime.now().toUtc();
      }
      DateTime startDate = maxDateUtc.subtract(Duration(hours: prevHours));
      for (int index = 0; index < history.length; index++) {
        HealthHistory historyEntry = history[index];
        if (historyEntry.isTestVerified && (historyEntry.dateUtc != null) &&
            (historyEntry.dateUtc.isAfter(startDate)) &&
            (historyEntry.dateUtc.isBefore(maxDateUtc))) {
          count++;
        }
      }
    }
    return count;
  }

  static List<HealthHistory> pastList(List<HealthHistory> history) {
    List<HealthHistory> result;
    if (history != null) {
      result = <HealthHistory>[];
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

  static HealthHistory mostRecentVaccine(List<HealthHistory> history, { String vaccine }) {
    if (history != null) {
      for (int index = 0; index < history.length; index++) {
        HealthHistory historyEntry = history[index];
        if (historyEntry.isVaccine && ((vaccine == null) || (historyEntry.blob?.vaccine?.toLowerCase() == vaccine?.toLowerCase()))) {
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

  final String vaccine;
  
  final String actionType;
  final dynamic actionTitle;
  final dynamic actionText;
  final Map<String, dynamic> actionParams;

  final List<HealthEventExtra> extras;

  static const String VaccineEffective = "Effective";

  HealthHistoryBlob({
    this.provider, this.providerId, this.location, this.locationId, this.countyId, this.testType, this.testResult,
    this.symptoms,
    this.traceDuration, this.traceTEK,
    this.vaccine,
    this.actionType, this.actionTitle, this.actionText, this.actionParams,
    this.extras
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

      vaccine: json['vaccine'],
      
      actionType: json['action_type'],
      actionTitle: json['action_title'],
      actionText: json['action_text'],
      actionParams: json['action_params'],

      extras: HealthEventExtra.listFromJson(json['extra'])      

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

      'vaccine': vaccine,
      
      'action_type': actionType,
      'action_title': actionTitle,
      'action_text': actionText,
      'action_params': actionParams,

      'extra': HealthEventExtra.listToJson(extras),
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

      DeepCollectionEquality().equals(o.symptoms, symptoms) &&

      (o.traceDuration == traceDuration) &&
      (o.traceTEK == traceTEK) &&

      (o.vaccine == vaccine) &&

      (o.actionType == actionType) &&
      DeepCollectionEquality().equals(o.actionTitle, actionTitle) &&
      DeepCollectionEquality().equals(o.actionText, actionText) &&
      DeepCollectionEquality().equals(o.actionParams, actionParams) &&

      DeepCollectionEquality().equals(o.extras, extras);
  }

  int get hashCode =>
    (provider?.hashCode ?? 0) ^
    (providerId?.hashCode ?? 0) ^
    (location?.hashCode ?? 0) ^
    (locationId?.hashCode ?? 0) ^
    (countyId?.hashCode ?? 0) ^
    (testType?.hashCode ?? 0) ^
    (testResult?.hashCode ?? 0) ^

    DeepCollectionEquality().hash(symptoms) ^

    (traceDuration?.hashCode ?? 0) ^
    (traceTEK?.hashCode ?? 0) ^

    (vaccine?.hashCode ?? 0) ^

    (actionType?.hashCode ?? 0) ^
    (DeepCollectionEquality().hash(actionTitle) ?? 0) ^
    (DeepCollectionEquality().hash(actionText) ?? 0) ^
    (DeepCollectionEquality().hash(actionParams) ?? 0) ^

    (DeepCollectionEquality().hash(extras) ?? 0);

  bool get isTest {
    return (testType != null) && (testResult != null);
  }

  bool get isSymptoms {
    return (symptoms != null);
  }

  bool get isContactTrace {
    return ((traceDuration != null) /*&& (traceTEK != null)*/);
  }

  bool get isVaccine {
    return (vaccine != null);
  }

  bool get isVaccineEffective {
    return (vaccine != null) && (vaccine.toLowerCase() == VaccineEffective.toLowerCase());
  }

  bool get isAction {
    return (actionType != null) || (actionTitle != null) || (actionText != null) || (actionParams != null);
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

  String get localeActionTitle {
    return Localization().localeString(actionTitle) ?? actionTitle;
  }

  String get localeActionText {
    return Localization().localeString(actionText) ?? actionText;
  }
}

////////////////////////////////
// HealthHistoryType

enum HealthHistoryType { test, manualTestVerified, manualTestNotVerified, symptoms, contactTrace, vaccine, action }

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
  else if (value == 'vaccine') {
    return HealthHistoryType.vaccine;
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
    case HealthHistoryType.vaccine: return 'vaccine';
    case HealthHistoryType.action: return 'action';
  }
  return null;
}

///////////////////////////////
// HealthPendingEvent

class HealthPendingEvent {
  final String   id;
  final String   accountId;
  final String   provider;
  final String   providerId;
  final String   encryptedKey;
  final String   encryptedBlob;
  final bool     processed;
  final DateTime dateCreated;
  final DateTime dateUpdated;

  HealthPendingEventBlob blob;

  HealthPendingEvent({this.id, this.accountId, this.provider, this.providerId, this.encryptedKey, this.encryptedBlob, this.processed, this.dateCreated, this.dateUpdated});

  factory HealthPendingEvent.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthPendingEvent(
      id:            AppJson.stringValue(json['id']),
      accountId:     AppJson.stringValue(json['account_id']),
      provider:      AppJson.stringValue(json['provider']),
      providerId:    AppJson.stringValue(json['provider_id']),
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
    json['account_id']      = accountId;
    json['provider']        = provider;
    json['provider_id']     = providerId;
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
      values = <HealthPendingEvent>[];
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

  bool get isVaccine {
    return (blob != null) && blob.isVaccine;
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

  final String   vaccine;

  final String   actionType;
  final dynamic  actionTitle;
  final dynamic  actionText;
  final Map<String, dynamic> actionParams;

  final List<HealthEventExtra> extras;

  HealthPendingEventBlob({this.dateUtc,
    this.testType, this.testResult,
    this.vaccine,
    this.actionType, this.actionTitle, this.actionText, this.actionParams,
    this.extras});

  factory HealthPendingEventBlob.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthPendingEventBlob(
      dateUtc:       healthDateTimeFromString(AppJson.stringValue(json['Date'])),
      
      testType:      AppJson.stringValue(json['TestName']),
      testResult:    AppJson.stringValue(json['Result']),

      vaccine:       AppJson.stringValue(json['Vaccine']),
      
      actionType:    AppJson.stringValue(json['ActionType']),
      actionTitle:    json['ActionTitle'],
      actionText:    json['ActionText'],
      actionParams:  AppJson.mapValue(json['ActionParams']),
      
      extras:        HealthEventExtra.listFromJson(AppJson.listValue(json['Extra'])),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    if ((testType != null) || (testResult != null)) {
      return {
        'Date': healthDateTimeToString(dateUtc),
        'TestName': testType,
        'Result': testResult,
        'Extra': HealthEventExtra.listToJson(extras),
      };
    }
    else if (vaccine != null) {
      return {
        'Date': healthDateTimeToString(dateUtc),
        'Vaccine': vaccine,
        'Extra': HealthEventExtra.listToJson(extras),
      };
    }
    else if ((actionType != null) || (actionTitle != null) || (actionText != null) || (actionParams != null)) {
      return {
        'Date': healthDateTimeToString(dateUtc),
        'ActionType': actionType,
        'ActionTitle': actionTitle,
        'ActionText': actionText,
        'ActionParams': actionParams,
        'Extra': HealthEventExtra.listToJson(extras),
      };
    }
    else {
      return {
        'Date': healthDateTimeToString(dateUtc),
        'Extra': HealthEventExtra.listToJson(extras),
      };
    }
  }

  bool get isTest {
    return AppString.isStringNotEmpty(testType) && AppString.isStringNotEmpty(testResult);
  }

  bool get isVaccine {
    return (vaccine != null);
  }

  bool get isAction {
    return AppString.isStringNotEmpty(actionType) || AppString.isStringNotEmpty(defaultLocaleActionTitle) || AppString.isStringNotEmpty(defaultLocaleActionText);
  }

  String get defaultLocaleActionTitle {
    return Localization().defaultLocaleString(actionTitle) ?? actionTitle;
  } 

  String get defaultLocaleActionText {
    return Localization().defaultLocaleString(actionText) ?? actionText;
  } 
}

///////////////////////////////
// HealthEventExtra

class HealthEventExtra {
  final dynamic displayName;
  final dynamic displayValue;

  HealthEventExtra({this.displayName, this.displayValue});

  factory HealthEventExtra.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthEventExtra(
      displayName:       json['display_name'],
      displayValue:      json['display_value'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'display_value': displayValue,
    };
  }

  bool operator ==(o) =>
    (o is HealthEventExtra) &&
    DeepCollectionEquality().equals(o.displayName, displayName) && 
    DeepCollectionEquality().equals(o.displayValue, displayValue);

  int get hashCode =>
    (DeepCollectionEquality().hash(displayName) ?? 0) ^
    (DeepCollectionEquality().hash(displayValue) ?? 0);

  bool get isVisible {
    return (0 < (localeDisplayName?.length ?? 0));
  }

  String get localeDisplayName {
    return Localization().localeString(displayName) ?? displayName;
  }

  String get localeDisplayValue {
    return Localization().localeString(displayValue) ?? displayValue;
  }

  static List<HealthEventExtra> listFromJson(List<dynamic> json) {
    List<HealthEventExtra> values;
    if (json != null) {
      values = <HealthEventExtra>[];
      for (dynamic entry in json) {
        HealthEventExtra value;
        try { value = HealthEventExtra.fromJson((entry as Map)?.cast<String, dynamic>()); }
        catch(e) { print(e?.toString()); }
        values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthEventExtra> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (HealthEventExtra value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  static bool listHasVisible(List<HealthEventExtra> values) {
    if (values != null) {
      for (HealthEventExtra value in values) {
        if (value?.isVisible ?? false) {
          return true;
        }
      }
    }
    return false;
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
  bool consentTestResults;
  bool consentVaccineInformation;
  bool consentExposureNotification;
  bool repost;
  List<HealthUserAccount> accounts;
  String encryptedKey;
  String encryptedBlob;

  HealthUserAccount defaultAccount;
  Map<String, HealthUserAccount> accountsMap;

  HealthUser({this.uuid, this.publicKeyString, PublicKey publicKey, this.consentTestResults, this.consentVaccineInformation, this.consentExposureNotification, this.repost, this.accounts, this.encryptedKey, this.encryptedBlob}) {
    _publicKey = publicKey;
    accountsMap = HealthUserAccount.mapFromList(accounts);
    defaultAccount = HealthUserAccount.defaultInList(accounts);
  }

  factory HealthUser.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthUser(
      uuid: json['uuid'],
      publicKeyString: json['public_key'],
      consentTestResults: json['consent'],
      consentVaccineInformation: json['consent_vaccine'],
      consentExposureNotification: json['exposure_notification'],
      repost: json['re_post'],
      accounts: HealthUserAccount.listFromJson(json['accounts']),
      encryptedKey: json['encrypted_key'],
      encryptedBlob: json['encrypted_blob'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'public_key': publicKeyString,
      'consent': consentTestResults,
      'consent_vaccine': consentVaccineInformation,
      'exposure_notification': consentExposureNotification,
      're_post': repost,
      'accounts': HealthUserAccount.listToJson(accounts),
      'encrypted_key': encryptedKey,
      'encrypted_blob': encryptedBlob,
    };
  }

  bool operator == (o) =>
    o is HealthUser &&
      o.uuid == uuid &&
      o.publicKeyString == publicKeyString &&
      o.consentTestResults == consentTestResults &&
      o.consentVaccineInformation == consentVaccineInformation &&
      o.consentExposureNotification == consentExposureNotification &&
      o.repost == repost &&
      DeepCollectionEquality().equals(o.accounts, accounts) &&
      o.encryptedKey == encryptedKey &&
      o.encryptedBlob == encryptedBlob;

  int get hashCode =>
    (uuid?.hashCode ?? 0) ^
    (publicKeyString?.hashCode ?? 0) ^
    (consentTestResults?.hashCode ?? 0) ^
    (consentVaccineInformation?.hashCode ?? 0) ^
    (consentExposureNotification?.hashCode ?? 0) ^
    (repost?.hashCode ?? 0) ^
    DeepCollectionEquality().hash(accounts) ^
    (encryptedKey?.hashCode ?? 0) ^
    (encryptedBlob?.hashCode ?? 0);

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
      consentTestResults: user.consentTestResults,
      consentVaccineInformation: user.consentVaccineInformation,
      consentExposureNotification: user.consentExposureNotification,
      repost: user.repost,
      accounts: user.accounts,
      encryptedKey: user.encryptedKey,
      encryptedBlob: user.encryptedBlob,
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
      values = <HealthUserAccount>[];
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
      json = <dynamic>[];
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
      values = <HealthServiceProvider>[];
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
      json = <dynamic>[];
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
    values = <HealthServiceMechanism>[];
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
    json = <dynamic>[];
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
      values = <HealthServiceLocation>[];
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
      json = <dynamic>[];
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
      values = <HealthLocationDayOfOperation>[];
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
      values = <HealthTestType>[];
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
      json = <dynamic>[];
      for (HealthTestType value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// HealthTestTypeResult

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
      values = <HealthTestTypeResult>[];
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
      json = <dynamic>[];
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
      values = <HealthCounty>[];
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
      json = <dynamic>[];
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
      sections = <HealthGuideline>[];
      for (dynamic jsonEntry in jsonList) {
        sections.add(HealthGuideline.fromJson(jsonEntry));
      }
    }
    return sections;
  }

  static List<dynamic> listToJson(List<HealthGuideline> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
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
      guidelineItems = <HealthGuidelineItem>[];
      for (dynamic jsonEntry in jsonList) {
        guidelineItems.add(HealthGuidelineItem.fromJson(jsonEntry));
      }
    }
    return guidelineItems;
  }

  static List<dynamic> listToJson(List<HealthGuidelineItem> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
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
// HealthFamilyMember

class HealthFamilyMember {
  final String        id;
  final DateTime      dateCreated;
  final String        groupName;
        String        status;
  final String        applicantFirstName;
  final String        applicantLastName;
  final String        applicantEmail;
  final String        applicantPhone;
  final String        approverId;
  final String        approverLastName;

  static const String StatusAccepted = 'accepted';
  static const String StatusRevoked  = 'rejected';
  static const String StatusPending  = 'pending';

  HealthFamilyMember({this.id, this.dateCreated, this.groupName, this.status,
    this.applicantFirstName, this.applicantLastName, this.applicantEmail, this.applicantPhone,
    this.approverId, this.approverLastName});

  factory HealthFamilyMember.fromJson(Map<String, dynamic> json){
    return (json != null) ? HealthFamilyMember(
      id: json['id'],
      dateCreated: healthDateTimeFromString(json['date_created']),
      groupName: json['group_name'],
      status: json['status'],
      applicantFirstName: json['first_name'],
      applicantLastName: json['last_name'],
      applicantEmail: json['email'],
      applicantPhone: json['phone'],
      approverId: json['external_approver_id'],
      approverLastName: json['external_approver_last_name'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date_created': healthDateTimeToString(dateCreated),
      'group_name': groupName,
      'status': status,
      'first_name': applicantFirstName,
      'last_name': applicantLastName,
      'email': applicantEmail,
      'phone': applicantPhone,
      'external_approver_id': approverId,
      'external_approver_last_name': approverLastName,
    };
  }

  bool operator ==(o) =>
    (o is HealthFamilyMember) &&
      (o.id == id) &&
      (o.dateCreated == dateCreated) &&
      (o.groupName == groupName) &&
      (o.status == status) &&
      (o.applicantFirstName == applicantFirstName) &&
      (o.applicantLastName == applicantLastName) &&
      (o.applicantEmail == applicantEmail) &&
      (o.applicantPhone == applicantPhone) &&
      (o.approverId == approverId) &&
      (o.approverLastName == approverLastName);

  int get hashCode =>
    (id?.hashCode ?? 0) ^
    (dateCreated?.hashCode ?? 0) ^
    (groupName?.hashCode ?? 0) ^
    (status?.hashCode ?? 0) ^
    (applicantFirstName?.hashCode ?? 0) ^
    (applicantLastName?.hashCode ?? 0) ^
    (applicantEmail?.hashCode ?? 0) ^
    (applicantPhone?.hashCode ?? 0) ^
    (approverId?.hashCode ?? 0) ^
    (approverLastName?.hashCode ?? 0);

  String get applicantFullName {
    if (AppString.isStringNotEmpty(applicantFirstName)) {
      if (AppString.isStringNotEmpty(applicantLastName)) {
        return "$applicantFirstName $applicantLastName";
      }
      else {
        return "$applicantFirstName";
      }
    }
    else {
      return "$applicantLastName";
    }
  }

  String get applicantEmailOrPhone {
    if (AppString.isStringNotEmpty(applicantEmail)) {
      return applicantEmail;
    }
    else if (AppString.isStringNotEmpty(applicantPhone)) {
      return applicantPhone;
    }
    else {
      return null;
    }
  }

  bool get isPending {
    return status == StatusPending;
  }

  bool get isAcepted {
    return status == StatusAccepted;
  }

  bool get isRevoked {
    return status == StatusRevoked;
  }

  static List<HealthFamilyMember> listFromJson(List<dynamic> json) {
    List<HealthFamilyMember> values;
    if (json != null) {
      values = <HealthFamilyMember>[];
      for (dynamic entry in json) {
          HealthFamilyMember value;
          try { value = HealthFamilyMember.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthFamilyMember> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (HealthFamilyMember value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  static HealthFamilyMember pendingMemberFromList(List<HealthFamilyMember> values) {
    if (values != null) {
      for (HealthFamilyMember member in values) {
        if (member.isPending) {
          return member;
        }
      }
    }
    return null;
  }

  static HealthFamilyMember memberFromList(List<HealthFamilyMember> values, String memberId) {
    if (values != null) {
      for (HealthFamilyMember member in values) {
        if (member.id == memberId) {
          return member;
        }
      }
    }
    return null;
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
      values = <HealthSymptom>[];
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
      json = <dynamic>[];
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
      DeepCollectionEquality().equals(o.symptoms, symptoms);

  int get hashCode =>
    (id?.hashCode ?? 0) ^
    (name?.hashCode ?? 0) ^
    (visible?.hashCode ?? 0) ^
    (group?.hashCode ?? 0) ^
    DeepCollectionEquality().hash(symptoms);

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
    List<HealthSymptom> symptoms = <HealthSymptom>[];
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
      values = <HealthSymptomsGroup>[];
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
      json = <dynamic>[];
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
  final HealthVaccineRulesSet vaccines;
  final HealthActionRulesSet actions;
  final HealthDefaultsSet defaults;
  final HealthCodesSet codes;
  final Map<String, _HealthRuleStatus> statuses;
  final Map<String, _HealthRuleInterval> intervals;
  final Map<String, dynamic> constants;
  final Map<String, dynamic> strings;


  static const String UserTestMonitorInterval = 'UserTestMonitorInterval';
  static const String FamilyMemberTestPrice = 'FamilyMemberTestPrice';

  HealthRulesSet({this.tests, this.symptoms, this.contactTrace, this.vaccines, this.actions, this.defaults, HealthCodesSet codes, this.statuses, this.intervals, Map<String, dynamic> constants, Map<String, dynamic> strings}) :
    this.codes = codes ?? HealthCodesSet(),
    this.strings = strings ?? Map<String, dynamic>(),
    this.constants = constants ?? Map<String, dynamic>();

  factory HealthRulesSet.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRulesSet(
      tests: HealthTestRulesSet.fromJson(json['tests']),
      symptoms: HealthSymptomsRulesSet.fromJson(json['symptoms']),
      contactTrace: HealthContactTraceRulesSet.fromJson(json['contact_trace']),
      vaccines: HealthVaccineRulesSet.fromJson(json['vaccines']), 
      actions: HealthActionRulesSet.fromJson(json['actions']),
      defaults: HealthDefaultsSet.fromJson(json['defaults']),
      codes: HealthCodesSet.fromJson(json['codes']),
      statuses: _HealthRuleStatus.mapFromJson(json['statuses']),
      intervals: _HealthRuleInterval.mapFromJson(json['intervals']),
      strings: json['strings'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'tests': tests?.toJson(),
      'symptoms': symptoms?.toJson(),
      'contact_trace': contactTrace?.toJson(),
      'vaccines': vaccines?.toJson(),
      'actions': actions?.toJson(),
      'defaults': defaults?.toJson(),
      'codes': codes?.toJson(),
      'statuses': _HealthRuleStatus.mapToJson(statuses),
      'intervals': _HealthRuleInterval.mapToJson(intervals),
      'strings': strings,
    };
  }

  bool operator ==(o) {
    return (o is HealthRulesSet) &&
      (o.tests == tests) &&
      (o.symptoms == symptoms) &&
      (o.contactTrace == contactTrace) &&
      (o.vaccines == vaccines) &&
      (o.actions == actions) &&
      (o.defaults == defaults) &&
      (o.codes == codes) &&
      DeepCollectionEquality().equals(o.statuses, statuses) &&
      DeepCollectionEquality().equals(o.intervals, intervals) &&
      DeepCollectionEquality().equals(o.strings, strings);
  }

  int get hashCode =>
    (tests?.hashCode ?? 0) ^
    (symptoms?.hashCode ?? 0) ^
    (contactTrace?.hashCode ?? 0) ^
    (vaccines?.hashCode ?? 0) ^
    (actions?.hashCode ?? 0) ^
    (defaults?.hashCode ?? 0) ^
    (codes?.hashCode ?? 0) ^
    DeepCollectionEquality().hash(statuses) ^
    DeepCollectionEquality().hash(intervals) ^
    DeepCollectionEquality().hash(strings);

  _HealthRuleInterval _getInterval(String name) {
    return (intervals != null) ? intervals[name] : null; 
  }

  String get familyMemberTestPrice {
    return localeString(constants[FamilyMemberTestPrice]);
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

  String localeDisclaimerHtml(HealthHistoryBlob blob) {
    return localeString(tests?.matchRuleResult(blob: blob, rules: this)?.disclaimerHtml);
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

  Map<String, dynamic> toJson() {
    return {
      'status': status?.toJson(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'list': HealthCodeData.listToJson(_codesList),
      'info': _info
    };
  }

  bool operator ==(o) =>
    (o is HealthCodesSet) &&
      DeepCollectionEquality().equals(o._codesList, _codesList) &&
      DeepCollectionEquality().equals(o._info, _info);

  int get hashCode =>
    DeepCollectionEquality().hash(_codesList) ^
    DeepCollectionEquality().hash(_info);

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

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'color': _colorString,
      'name': _name,
      'description': _description,
      'long_description': _longDescription,
      'visible': visible,
      'reports_exposures': reportsExposures
    };
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
      values = <HealthCodeData>[];
      for (dynamic entry in json) {
          try { values.add(HealthCodeData.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthCodeData> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (HealthCodeData value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
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

  Map<String, dynamic> toJson() {
    return {
      'rules': HealthTestRule.listToJson(_rules),
    };
  }

  bool operator ==(o) =>
    (o is HealthTestRulesSet) &&
      DeepCollectionEquality().equals(o._rules, _rules);

  int get hashCode =>
    DeepCollectionEquality().hash(_rules);

  HealthTestRuleResult matchRuleResult({ HealthHistoryBlob blob, HealthRulesSet rules }) {
    if ((_rules != null) && (blob != null) && (blob.testType != null) && (blob.testResult != null)) {
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

  Map<String, dynamic> toJson() {
    return {
      'test_type': testType,
      'category': category,
      'results': HealthTestRuleResult.listToJson(results),
    };
  }

  bool operator ==(o) =>
    (o is HealthTestRule) &&
      (o.testType == testType) &&
      (o.category == category) &&
      DeepCollectionEquality().equals(o.results, results);

  int get hashCode =>
    (testType?.hashCode ?? 0) ^
    (category?.hashCode ?? 0) ^
    DeepCollectionEquality().hash(results);

  static List<HealthTestRule> listFromJson(List<dynamic> json) {
    List<HealthTestRule> values;
    if (json != null) {
      values = <HealthTestRule>[];
      for (dynamic entry in json) {
          try { values.add(HealthTestRule.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthTestRule> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (HealthTestRule value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// HealthTestRuleResult

class HealthTestRuleResult {
  final String testResult;
  final String category;
  final String disclaimerHtml;
  final _HealthRuleStatus status;

  HealthTestRuleResult({this.testResult, this.category, this.status, this.disclaimerHtml});

  factory HealthTestRuleResult.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRuleResult(
      testResult: json['result'],
      category: json['category'],
      disclaimerHtml: json['disclaimer_html'],
      status: _HealthRuleStatus.fromJson(json['status']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'result': testResult,
      'category': category,
      'disclaimer_html': disclaimerHtml,
      'status': status?.toJson(),
    };
  }

  bool operator ==(o) =>
    (o is HealthTestRuleResult) &&
      (o.testResult == testResult) &&
      (o.category == category) &&
      (o.disclaimerHtml == disclaimerHtml) &&
      (o.status == status);

  int get hashCode =>
    (testResult?.hashCode ?? 0) ^
    (category?.hashCode ?? 0) ^
    (disclaimerHtml?.hashCode ?? 0) ^
    (status?.hashCode ?? 0);

  static List<HealthTestRuleResult> listFromJson(List<dynamic> json) {
    List<HealthTestRuleResult> values;
    if (json != null) {
      values = <HealthTestRuleResult>[];
      for (dynamic entry in json) {
          try { values.add(HealthTestRuleResult.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthTestRuleResult> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (HealthTestRuleResult value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
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

  Map<String, dynamic> toJson() {
    return {
      'rules': HealthSymptomsRule.listToJson(_rules),
      'groups': HealthSymptomsGroup.listToJson(groups),
    };
  }

  bool operator ==(o) =>
    (o is HealthSymptomsRulesSet) &&
      DeepCollectionEquality().equals(o._rules, _rules) &&
      DeepCollectionEquality().equals(o.groups, groups);

  int get hashCode =>
    DeepCollectionEquality().hash(_rules) ^
    DeepCollectionEquality().hash(groups);

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
      counts: _HealthRuleInterval.mapFromJson(json['counts']),
      status: _HealthRuleStatus.fromJson(json['status']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'counts': _HealthRuleInterval.mapToJson(counts),
      'status': status?.toJson()
    };
  }

  bool operator ==(o) =>
    (o is HealthSymptomsRule) &&
      DeepCollectionEquality().equals(o.counts, counts) &&
      (o.status == status);

  int get hashCode =>
    DeepCollectionEquality().hash(counts) ^
    (status?.hashCode ?? 0);

  static List<HealthSymptomsRule> listFromJson(List<dynamic> json) {
    List<HealthSymptomsRule> values;
    if (json != null) {
      values = <HealthSymptomsRule>[];
      for (dynamic entry in json) {
          try { values.add(HealthSymptomsRule.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthSymptomsRule> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (HealthSymptomsRule value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
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

  Map<String, dynamic> toJson() {
    return {
      'rules': HealthContactTraceRule.listToJson(_rules),
    };
  }

  bool operator ==(o) =>
    (o is HealthContactTraceRulesSet) &&
      DeepCollectionEquality().equals(o._rules, _rules);

  int get hashCode =>
    DeepCollectionEquality().hash(_rules);


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

  Map<String, dynamic> toJson() {
    return {
      'duration': duration?.toJson(),
      'status': status?.toJson(),
    };
  }

  static List<HealthContactTraceRule> listFromJson(List<dynamic> json) {
    List<HealthContactTraceRule> values;
    if (json != null) {
      values = <HealthContactTraceRule>[];
      for (dynamic entry in json) {
          try { values.add(HealthContactTraceRule.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthContactTraceRule> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (HealthContactTraceRule value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  bool _matchBlob(HealthHistoryBlob blob, { HealthRulesSet rules }) {
    return (duration != null) && duration.match(blob?.traceDurationInMinutes, rules: rules);
  }
}

///////////////////////////////
// HealthVaccineRulesSet

class HealthVaccineRulesSet {
  final List<HealthVaccineRule> _rules;

  HealthVaccineRulesSet({List<HealthVaccineRule> rules}) : _rules = rules;

  factory HealthVaccineRulesSet.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthVaccineRulesSet(
      rules: HealthVaccineRule.listFromJson(json['rules']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'rules': HealthVaccineRule.listToJson(_rules),
    };
  }

  bool operator ==(o) =>
    (o is HealthVaccineRulesSet) &&
      DeepCollectionEquality().equals(o._rules, _rules);

  int get hashCode =>
    DeepCollectionEquality().hash(_rules);

  HealthVaccineRule matchRule({ HealthHistoryBlob blob, HealthRulesSet rules }) {
    if (_rules != null) {
      for (HealthVaccineRule rule in _rules) {
        if (rule._matchBlob(blob, rules: rules)) {
          return rule;
        }
      }
    }
    return null;
  }
}

///////////////////////////////
// HealthVaccineRule

class HealthVaccineRule {
  final String vaccine;
  final _HealthRuleStatus status;

  HealthVaccineRule({this.vaccine, this.status});

  factory HealthVaccineRule.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthVaccineRule(
      vaccine: json['vaccine'],
      status: _HealthRuleStatus.fromJson(json['status']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'vaccine': vaccine,
      'status': status?.toJson(),
    };
  }

  bool operator ==(o) =>
    (o is HealthVaccineRule) &&
      (o.vaccine == vaccine) &&
      (o.status == status);

  int get hashCode =>
    (vaccine?.hashCode ?? 0) ^
    (status?.hashCode ?? 0);

  static List<HealthVaccineRule> listFromJson(List<dynamic> json) {
    List<HealthVaccineRule> values;
    if (json != null) {
      values = <HealthVaccineRule>[];
      for (dynamic entry in json) {
          try { values.add(HealthVaccineRule.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthVaccineRule> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (HealthVaccineRule value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  bool _matchBlob(HealthHistoryBlob blob, {HealthRulesSet rules}) {
    return (vaccine != null) && (vaccine.toLowerCase() == blob?.vaccine?.toLowerCase());
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

  Map<String, dynamic> toJson() {
    return {
      'rules': HealthActionRule.listToJson(_rules),
    };
  }

  bool operator ==(o) =>
    (o is HealthActionRulesSet) &&
      DeepCollectionEquality().equals(o._rules, _rules);

  int get hashCode =>
    DeepCollectionEquality().hash(_rules);

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

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'status': status?.toJson()
    };
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
      values = <HealthActionRule>[];
      for (dynamic entry in json) {
          try { values.add(HealthActionRule.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthActionRule> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (HealthActionRule value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
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
      if (HealthRuleConditionalStatus.isJsonCompatible(json)) {
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

  dynamic toJson();

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

  static Map<String, dynamic> mapToJson(Map<String, _HealthRuleStatus> values) {
    Map<String, dynamic> json;
    if (values != null) {
      json = Map<String, dynamic>();
      values.forEach((key, value) {
        json[key] = value?.toJson();
      });
    }
    return json;
  }

  HealthRuleStatus eval({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params });
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

  final dynamic warning;
  final dynamic warningHtml;

  final dynamic eventExplanation;
  final dynamic eventExplanationHtml;

  final dynamic statusUpdateNotice;
  final dynamic statusUpdateNoticeHtml;

  final dynamic statusUpdateReason;
  final dynamic statusUpdateReasonHtml;

  final dynamic fcmTopic;

  HealthRuleStatus({this.code, this.priority,
    this.nextStep, this.nextStepHtml, this.nextStepInterval, this.nextStepDateUtc,
    this.warning, this.warningHtml,
    this.eventExplanation, this.eventExplanationHtml,
    this.statusUpdateNotice, this.statusUpdateNoticeHtml,
    this.statusUpdateReason, this.statusUpdateReasonHtml,
    this.fcmTopic });

  factory HealthRuleStatus.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleStatus(
      code:                   json['code'],
      priority:               json['priority'],
      nextStep:               json['next_step'],
      nextStepHtml:           json['next_step_html'],
      nextStepInterval:       _HealthRuleInterval.fromJson(json['next_step_interval']),
      warning:                json['warning'],
      warningHtml:            json['warning_html'],
      eventExplanation:       json['event_explanation'],
      eventExplanationHtml:   json['event_explanation_html'],
      statusUpdateNotice:     json['notice'],
      statusUpdateNoticeHtml: json['notice_html'],
      statusUpdateReason:     json['reason'],
      statusUpdateReasonHtml: json['reason_html'],
      fcmTopic:               json['fcm_topic']
    ) : null;
  }

  @override
  dynamic toJson() {
    return {
      'code':                   code,
      'priority':               priority,
      'next_step':              nextStep,
      'next_step_html':         nextStepHtml,
      'next_step_interval':     nextStepInterval?.toJson(),
      'warning':                warning,
      'warning_html':           warningHtml,
      'event_explanation':      eventExplanation,
      'event_explanation_html': eventExplanationHtml,
      'notice':                 statusUpdateNotice,
      'notice_html':            statusUpdateNoticeHtml,
      'reason':                 statusUpdateReason,
      'reason_html':            statusUpdateReasonHtml,
      'fcm_topic':              fcmTopic,
    };
  }

  factory HealthRuleStatus.fromStatus(HealthRuleStatus status, { DateTime nextStepDateUtc, }) {
    
    return (status != null) ? HealthRuleStatus(
      code:                   status.code,
      priority:               status.priority,
      nextStep:               status.nextStep,
      nextStepHtml:           status.nextStepHtml,
      nextStepInterval:       status.nextStepInterval,
      nextStepDateUtc:        nextStepDateUtc ?? status.nextStepDateUtc,
      warning:                status.warning,
      warningHtml:            status.warningHtml,
      eventExplanation:       status.eventExplanation,
      eventExplanationHtml:   status.eventExplanationHtml,
      statusUpdateNotice:     status.statusUpdateNotice,
      statusUpdateNoticeHtml: status.statusUpdateNoticeHtml,
      statusUpdateReason:     status.statusUpdateReason,
      statusUpdateReasonHtml: status.statusUpdateReasonHtml,
      fcmTopic:               status.fcmTopic,
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

      (o.warning == warning) &&
      (o.warningHtml == warningHtml) &&

      (o.eventExplanation == eventExplanation) &&
      (o.eventExplanationHtml == eventExplanationHtml) &&

      (o.statusUpdateNotice == statusUpdateNotice) &&
      (o.statusUpdateNoticeHtml == statusUpdateNoticeHtml) &&

      (o.statusUpdateReason == statusUpdateReason) &&
      (o.statusUpdateReasonHtml == statusUpdateReasonHtml) &&

      (o.fcmTopic == fcmTopic);

  int get hashCode =>
    (code?.hashCode ?? 0) ^
    (priority?.hashCode ?? 0) ^
    
    (nextStep?.hashCode ?? 0) ^
    (nextStepHtml?.hashCode ?? 0) ^
    (nextStepInterval?.hashCode ?? 0) ^
    (nextStepDateUtc?.hashCode ?? 0) ^

    (warning?.hashCode ?? 0) ^
    (warningHtml?.hashCode ?? 0) ^

    (eventExplanation?.hashCode ?? 0) ^
    (eventExplanationHtml?.hashCode ?? 0) ^

    (statusUpdateNotice?.hashCode ?? 0) ^
    (statusUpdateNoticeHtml?.hashCode ?? 0) ^

    (statusUpdateReason?.hashCode ?? 0) ^
    (statusUpdateReasonHtml?.hashCode ?? 0) ^

    (fcmTopic?.hashCode ?? 0);

  @override
  HealthRuleStatus eval({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    int originIndex = (nextStepInterval?.origin(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params) == HealthRuleIntervalOrigin.referenceDate) ? referenceIndex : historyIndex;
    HealthHistory originEntry = ((history != null) && (originIndex != null) && (0 <= originIndex) && (originIndex < history.length)) ? history[originIndex] : null;
    DateTime originDateUtc = originEntry?.dateUtc;
    int numberOfDays = nextStepInterval?.value(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);

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

  @override
  dynamic toJson() {
    return reference;
  }

  bool operator ==(o) =>
    (o is HealthRuleReferenceStatus) &&
      (o.reference == reference);

  int get hashCode =>
    (reference?.hashCode ?? 0);

  @override
  HealthRuleStatus eval({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    _HealthRuleStatus status = (rules?.statuses != null) ? rules?.statuses[reference] : null;
    return status?.eval(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
  }
}

///////////////////////////////
// HealthRuleConditionalStatus

class HealthRuleConditionalStatus extends _HealthRuleStatus with HealthRuleCondition {
  final String condition;
  final Map<String, dynamic> conditionParams;
  final _HealthRuleStatus successStatus;
  final _HealthRuleStatus failStatus;

  HealthRuleConditionalStatus({this.condition, this.conditionParams, this.successStatus, this.failStatus});

  factory HealthRuleConditionalStatus.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleConditionalStatus(
      condition: json['condition'],
      conditionParams: json['params'],
      successStatus: _HealthRuleStatus.fromJson(json['success']) ,
      failStatus: _HealthRuleStatus.fromJson(json['fail']),
    ) : null;
  }

  @override
  dynamic toJson() {
    return {
      'condition': condition,
      'params': conditionParams,
      'success': successStatus?.toJson(),
      'fail': failStatus?.toJson(),
    };
  }

  static bool isJsonCompatible(dynamic json) {
    return (json is Map) && (json['condition'] is String);
  }

  bool operator ==(o) =>
    (o is HealthRuleConditionalStatus) &&
      (o.condition == condition) &&
      (DeepCollectionEquality().equals(o.conditionParams, conditionParams)) &&
      (o.successStatus == successStatus) &&
      (o.failStatus == failStatus);

  int get hashCode =>
    (condition?.hashCode ?? 0) ^
    (DeepCollectionEquality().hash(conditionParams)) ^
    (successStatus?.hashCode ?? 0) ^
    (failStatus?.hashCode ?? 0);

  @override
  HealthRuleStatus eval({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    HealthRuleConditionResult conditionResult = evalCondition(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    _HealthRuleStatus status = (conditionResult?.result != null) ? (conditionResult.result ? successStatus : failStatus) : null;
    return status?.eval(history: history, historyIndex: historyIndex, referenceIndex: conditionResult?.referenceIndex ?? referenceIndex, rules: rules, params: params);
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
    else if (json is List) {
      try { return HealthRuleIntervalSet.fromJson(json.cast<dynamic>()); }
      catch (e) { print(e?.toString()); }
    }
    else if (json is Map) {
      if (HealthRuleIntervalCondition.isJsonCompatible(json)) {
        try { return HealthRuleIntervalCondition.fromJson(json.cast<String, dynamic>()); }
        catch (e) { print(e?.toString()); }
      }
      else {
        try { return HealthRuleInterval.fromJson(json.cast<String, dynamic>()); }
        catch (e) { print(e?.toString()); }
      }
    }
    return null;
  }

  dynamic toJson();

  bool match(int value, { DateTime orgDate, List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params });
  int  value({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params });
  bool valid({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params });
  int  scope({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params });
  bool current({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params });
  HealthRuleIntervalOrigin origin({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params });

  static Map<String, _HealthRuleInterval> mapFromJson(Map<String, dynamic> json) {
    Map<String, _HealthRuleInterval> result;
    if (json != null) {
      result = Map<String, _HealthRuleInterval>();
      json.forEach((key, value) {
        result[key] = _HealthRuleInterval.fromJson(value);
      });
    }
    return result;
  }

  static Map<String, dynamic> mapToJson(Map<String, _HealthRuleInterval> values) {
    Map<String, dynamic> json;
    if (values != null) {
      json = Map<String, dynamic>();
      values.forEach((key, value) {
        json[key] = value?.toJson();
      });
    }
    return json;
  }

  static List<_HealthRuleInterval> listFromJson(List<dynamic> json) {
    List<_HealthRuleInterval> values;
    if (json != null) {
      values = <_HealthRuleInterval>[];
      for (dynamic entry in json) {
        try { values.add(_HealthRuleInterval.fromJson(entry)); }
        catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<_HealthRuleInterval> values) {
    List<dynamic> json;
    if (values != null) {
      json = <dynamic>[];
      for (_HealthRuleInterval value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  static int applyWeekdayExtent(_HealthRuleInterval weekdayExtent, DateTime orgDate, int value, int step, { List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params } ) {
    if ((weekdayExtent != null) && (orgDate != null) && (value != null) && (step != null)) {
      //DateTime dateExt = orgDate.add(Duration(days: value + step));
      DateTime dateExt = DateTime(orgDate.year, orgDate.month, orgDate.day + value + step, orgDate.hour, orgDate.minute, orgDate.second);
      while (weekdayExtent.match(dateExt.weekday, orgDate: orgDate, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params)) {
        value += step;
        // dateExt = dateExt.add(Duration(days: step));
        dateExt = DateTime(dateExt.year, dateExt.month, dateExt.day + step, orgDate.hour, orgDate.minute, orgDate.second);
      }
      return value;
    }
    return null;
  }

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

  @override
  dynamic toJson() {
    return _value;
  }

  bool operator ==(o) =>
    (o is HealthRuleIntervalValue) &&
      (o._value == _value);

  int get hashCode =>
    (_value?.hashCode ?? 0);

  @override bool match(int value, { DateTime orgDate, List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {return (_value == value); }
  @override int  value({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })            { return _value; }
  @override bool valid({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })            { return (_value != null); }
  @override int  scope({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })            { return null; }
  @override bool current({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })          { return null; }
  @override HealthRuleIntervalOrigin origin({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) { return null; }
}

///////////////////////////////
// HealthRuleInterval

class HealthRuleInterval extends _HealthRuleInterval {
  static const int FutureScope           =  1;
  static const int FutureAndCurrentScope =  2;
  static const int NoScope               =  0;
  static const int PastScope             = -1;
  static const int PastAndCurrentScope   = -2;

  final _HealthRuleInterval _min;
  final _HealthRuleInterval _max;
  final _HealthRuleInterval _value;
  final int _scope;
  final bool _current;
  final HealthRuleIntervalOrigin _origin;
  final _HealthRuleInterval _minWeekdaysExtent;
  final _HealthRuleInterval _maxWeekdaysExtent;
  
  HealthRuleInterval({_HealthRuleInterval min, _HealthRuleInterval max, _HealthRuleInterval value, int scope, bool current, HealthRuleIntervalOrigin origin, _HealthRuleInterval minWeekdaysExtent, _HealthRuleInterval maxWeekdaysExtent }) :
    _min = min,
    _max = max,
    _value = value,
    _scope = scope,
    _current = current,
    _origin = origin,
    _minWeekdaysExtent = minWeekdaysExtent,
    _maxWeekdaysExtent = maxWeekdaysExtent;

  factory HealthRuleInterval.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleInterval(
      min: _HealthRuleInterval.fromJson(json['min']),
      max: _HealthRuleInterval.fromJson(json['max']),
      value: _HealthRuleInterval.fromJson(json['value']),
      scope: _scopeFromJson(json['scope']),
      current: json['current'],
      origin: _originFromJson(json['origin']),
      minWeekdaysExtent: _HealthRuleInterval.fromJson(json['min-weekdays-extent']),
      maxWeekdaysExtent: _HealthRuleInterval.fromJson(json['max-weekdays-extent']),
    ) : null;
  }

  @override
  dynamic toJson() {
    return {
      'min': _min?.toJson(),
      'max': _max?.toJson(),
      'value': _value?.toJson(),
      'scope': _scopeToJson(_scope),
      'current': _current,
      'origin': _originToJson(_origin),
      'min-weekdays-extent': _minWeekdaysExtent?.toJson(),
      'max-weekdays-extent': _maxWeekdaysExtent?.toJson(),
    };
  }

  bool operator ==(o) =>
    (o is HealthRuleInterval) &&
      (o._min == _min) &&
      (o._max == _max) &&
      (o._value == _value) &&
      (o._scope == _scope) &&
      (o._current == _current) &&
      (o._origin == _origin) &&
      (o._minWeekdaysExtent == _minWeekdaysExtent) &&
      (o._maxWeekdaysExtent == _maxWeekdaysExtent);

  int get hashCode =>
    (_min?.hashCode ?? 0) ^
    (_max?.hashCode ?? 0) ^
    (_value?.hashCode ?? 0) ^
    (_scope?.hashCode ?? 0) ^
    (_current?.hashCode ?? 0) ^
    (_origin?.hashCode ?? 0) ^
    (_minWeekdaysExtent?.hashCode ?? 0) ^
    (_maxWeekdaysExtent?.hashCode ?? 0);

  @override
  bool match(int value, { DateTime orgDate, List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    if (value != null) {
      if (_min != null) {
        int minValue = _min.value(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
        minValue = _HealthRuleInterval.applyWeekdayExtent(_minWeekdaysExtent, orgDate, minValue, -1, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params) ?? minValue;
        if ((minValue == null) || (minValue > value)) {
          return false;
        }
      }
      if (_max != null) {
        int maxValue = _max.value(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
        maxValue = _HealthRuleInterval.applyWeekdayExtent(_maxWeekdaysExtent, orgDate, maxValue, 1, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params) ?? maxValue;
        if ((maxValue == null) || (maxValue < value)) {
          return false;
        }
      }
      if (_value != null) {
        int valueValue = _value.value(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);

        int minValue = _HealthRuleInterval.applyWeekdayExtent(_minWeekdaysExtent, orgDate, valueValue, -1, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
        if ((minValue != null) && (minValue > value)) {
          return false;
        }
        int maxValue = _HealthRuleInterval.applyWeekdayExtent(_maxWeekdaysExtent, orgDate, valueValue,  1, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
        if ((maxValue != null) && (maxValue < value)) {
          return false;
        }

        if ((valueValue == null) || (valueValue != value)) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override bool valid({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })   {
    return ((_min == null) || _min.valid(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params)) &&
           ((_max == null) || _max.valid(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params)) &&
           ((_value == null) || _value.valid(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params));
  }

  @override int  value({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })   { return _value?.value(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params); }
  @override int  scope({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })   { return _scope; }
  @override bool current({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) { return _current; }
  @override HealthRuleIntervalOrigin origin({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) { return _origin; }

  static int _scopeFromJson(dynamic value) {
    if (value is String) {
      if (value == 'future') {
        return FutureScope;
      }
      else if (value == 'future-and-current') {
        return FutureAndCurrentScope;
      }
      else if (value == 'past') {
        return PastScope;
      }
      else if (value == 'past-and-current') {
        return PastAndCurrentScope;
      }
    }
    else if (value is int) {
      if (0 < value) {
        return min(value, FutureAndCurrentScope);
      }
      else if (value < 0) {
        return max(value, PastAndCurrentScope);
      }
    }
    return null;
  }

  static String _scopeToJson(int value) {
    if (value == FutureScope) {
      return 'future';
    }
    else if (value == FutureAndCurrentScope) {
      return 'future-and-current';
    }
    else if (value == PastScope) {
      return 'past';
    }
    else if (value == PastAndCurrentScope) {
      return 'past-and-current';
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

  static String _originToJson(HealthRuleIntervalOrigin value) {
    if (value == HealthRuleIntervalOrigin.historyDate) {
      return 'historyDate';
    }
    else if (value == HealthRuleIntervalOrigin.referenceDate) {
      return 'referenceDate';
    }
    else {
      return null;
    }
  }
}

///////////////////////////////
// HealthRuleIntervalSet

class HealthRuleIntervalSet extends _HealthRuleInterval {
  List<_HealthRuleInterval> _entries;

  HealthRuleIntervalSet({List<_HealthRuleInterval> entries}) :
    _entries = entries;

  factory HealthRuleIntervalSet.fromJson(List<dynamic> json) {
    List<_HealthRuleInterval> entries = _HealthRuleInterval.listFromJson(json);
    return (entries != null) ? HealthRuleIntervalSet(entries: entries) : null;
  }

  @override
  dynamic toJson() {
    return _HealthRuleInterval.listToJson(_entries);
  }

  bool operator ==(o) =>
    (o is HealthRuleIntervalSet) &&
      DeepCollectionEquality().equals(o._entries, _entries);

  int get hashCode =>
    (DeepCollectionEquality().hash(_entries) ?? 0);

  @override
  bool match(int value, { DateTime orgDate, List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    for (_HealthRuleInterval entry in _entries) {
      if (entry.match(value, orgDate: orgDate, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params)) {
        return true;
      }
    }
    return false;
  }
  
  @override
  bool valid({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    for (_HealthRuleInterval entry in _entries) {
      if (!entry.valid(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params)) {
        return false;
      }
    }
    return 0 < _entries.length;
  }
  
  @override int  value({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) { return null; }
  @override int  scope({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) { return null; }
  @override bool current({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) { return null; }
  @override HealthRuleIntervalOrigin origin({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) { return null; }
}

///////////////////////////////
// HealthRuleIntervalReference

class HealthRuleIntervalReference extends _HealthRuleInterval {
  final String _reference;

  HealthRuleIntervalReference({String reference}) :
    _reference = reference;

  factory HealthRuleIntervalReference.fromJson(dynamic json) {
    return (json is String) ? HealthRuleIntervalReference(reference: json) : null;
  }

  @override
  dynamic toJson() {
    return _reference;
  }

  bool operator ==(o) =>
    (o is HealthRuleIntervalReference) &&
      (o._reference == _reference);

  int get hashCode =>
    (_reference?.hashCode ?? 0);

  _HealthRuleInterval _referenceInterval({HealthRulesSet rules, Map<String, dynamic> params }) {
    _HealthRuleInterval referenceParamInterval = (params != null) ? _HealthRuleInterval.fromJson(params[_reference]) : null;
    return (referenceParamInterval != null) ? referenceParamInterval : rules?._getInterval(_reference);
  }

  @override
  bool match(int value, { DateTime orgDate, List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    return _referenceInterval(rules: rules, params: params)?.match(value, orgDate: orgDate, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params) ?? false;
  }
  
  @override bool valid({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })   { return _referenceInterval(rules: rules, params: params)?.valid(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params) ?? false; }
  @override int  value({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })   { return _referenceInterval(rules: rules, params: params)?.value(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params); }
  @override int  scope({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params })   { return _referenceInterval(rules: rules, params: params)?.scope(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params); }
  @override bool current({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) { return _referenceInterval(rules: rules, params: params)?.current(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params); }
  @override HealthRuleIntervalOrigin origin({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) { return _referenceInterval(rules: rules, params: params)?.origin(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params); }
}

///////////////////////////////
// HealthRuleIntervalCondition

class HealthRuleIntervalCondition extends _HealthRuleInterval with HealthRuleCondition {
  final String condition;
  final Map<String, dynamic> conditionParams;
  final _HealthRuleInterval successInterval;
  final _HealthRuleInterval failInterval;
  
  HealthRuleIntervalCondition({this.condition, this.conditionParams, this.successInterval, this.failInterval});

  factory HealthRuleIntervalCondition.fromJson(Map<String, dynamic> json) {
    return (json is Map) ? HealthRuleIntervalCondition(
      condition: json['condition'],
      conditionParams: json['params'],
      successInterval: _HealthRuleInterval.fromJson(json['success']) ,
      failInterval: _HealthRuleInterval.fromJson(json['fail']),
    ) : null;
  }

  @override
  dynamic toJson() {
    return {
      'condition': condition,
      'params': conditionParams,
      'success': successInterval?.toJson(),
      'fail': failInterval?.toJson(),
    };
  }

  static bool isJsonCompatible(dynamic json) {
    return (json is Map) && (json['condition'] is String);
  }

  bool operator ==(o) =>
    (o is HealthRuleIntervalCondition) &&
      (o.condition == condition) &&
      (DeepCollectionEquality().equals(o.conditionParams, conditionParams)) &&
      (o.successInterval == successInterval) &&
      (o.failInterval == failInterval);

  int get hashCode =>
    (condition?.hashCode ?? 0) ^
    (DeepCollectionEquality().hash(conditionParams)) ^
    (successInterval?.hashCode ?? 0) ^
    (failInterval?.hashCode ?? 0);

  @override
  bool match(int value, { DateTime orgDate, List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    HealthRuleConditionResult conditionResult = evalCondition(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    _HealthRuleInterval interval = (conditionResult?.result != null) ? (conditionResult.result ? successInterval : failInterval) : null;
    return interval?.match(value, orgDate: orgDate, history: history, historyIndex: historyIndex, referenceIndex: conditionResult?.referenceIndex ?? referenceIndex, rules: rules, params: params) ?? false;
  }
  
  @override
  bool valid({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    HealthRuleConditionResult conditionResult = evalCondition(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    _HealthRuleInterval interval = (conditionResult?.result != null) ? (conditionResult.result ? successInterval : failInterval) : null;
    return interval?.valid(history: history, historyIndex: historyIndex, referenceIndex: conditionResult?.referenceIndex ?? referenceIndex, rules: rules, params: params) ?? false;
  }
  
  @override
  int value({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    HealthRuleConditionResult conditionResult = evalCondition(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    _HealthRuleInterval interval = (conditionResult?.result != null) ? (conditionResult.result ? successInterval : failInterval) : null;
    return interval?.value(history: history, historyIndex: historyIndex, referenceIndex: conditionResult?.referenceIndex ?? referenceIndex, rules: rules, params: params);
  }
  
  @override
  int scope({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    HealthRuleConditionResult conditionResult = evalCondition(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    _HealthRuleInterval interval = (conditionResult?.result != null) ? (conditionResult.result ? successInterval : failInterval) : null;
    return interval?.scope(history: history, historyIndex: historyIndex, referenceIndex: conditionResult?.referenceIndex ?? referenceIndex, rules: rules, params: params);
  }
  
  @override
  bool current({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    HealthRuleConditionResult conditionResult = evalCondition(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    _HealthRuleInterval interval = (conditionResult?.result != null) ? (conditionResult.result ? successInterval : failInterval) : null;
    return interval?.current(history: history, historyIndex: historyIndex, referenceIndex: conditionResult?.referenceIndex ?? referenceIndex, rules: rules, params: params);
  }
  
  @override
  HealthRuleIntervalOrigin origin({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    HealthRuleConditionResult conditionResult = evalCondition(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    _HealthRuleInterval interval = (conditionResult?.result != null) ? (conditionResult.result ? successInterval : failInterval) : null;
    return interval?.origin(history: history, historyIndex: historyIndex, referenceIndex: conditionResult?.referenceIndex ?? referenceIndex, rules: rules, params: params);
  }
}

///////////////////////////////
// HealthRuleCondition

abstract class HealthRuleCondition {
  String get condition;
  Map<String, dynamic> get conditionParams;

  HealthRuleConditionResult evalCondition({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    dynamic result;
    if (condition == 'require-test') {
      // (index >= 0) / -1 / null
      result = _evalRequireEntry([HealthHistoryType.test, HealthHistoryType.manualTestVerified], history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    }
    else if (condition == 'require-symptoms') {
      // (index >= 0) / -1 / null
      result = _evalRequireEntry(HealthHistoryType.symptoms, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    }
    else if (condition == 'require-contact-trace') {
      // (index >= 0) / -1 / null
      result = _evalRequireEntry(HealthHistoryType.contactTrace, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    }
    else if (condition == 'require-vaccine') {
      // (index >= 0) / -1 / null
      result = _evalRequireEntry(HealthHistoryType.vaccine, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    }
    else if (condition == 'require-action') {
      // (index >= 0) / -1 / null
      result = _evalRequireEntry(HealthHistoryType.action, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    }
    else if (condition == 'timeout') {
      // true / false / null
      result = _evalTimeout(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    }
    else if (condition == 'test-user') {
      // true / false / null
      result = _evalTestUser(conditionParams, rules: rules, params: params);
    }
    else if (condition == 'test-interval') {
      // true / false / null
      result = _evalTestInterval(conditionParams, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
    }
  
    if (result is bool) {
      return HealthRuleConditionResult(result: result);
    }
    else if (result is int) {
      if (0 <= result) {
        return HealthRuleConditionResult(result: true, referenceIndex: result);
      }
      else {
        return HealthRuleConditionResult(result: false);
      }
    }
    else {
      return null;
    }
  }

  dynamic _evalRequireEntry(dynamic historyType, { List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    _HealthRuleInterval interval = (conditionParams != null) ? _HealthRuleInterval.fromJson(conditionParams['interval']) : null;
    if (interval == null) {
      return null;
    }

    int originIndex = (interval.origin(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params) == HealthRuleIntervalOrigin.referenceDate) ? referenceIndex : historyIndex;
    HealthHistory originEntry = ((history != null) && (originIndex != null) && (0 <= originIndex) && (originIndex < history.length)) ? history[originIndex] : null;
    DateTime originDateMidnightLocal = originEntry?.dateMidnightLocal;
    if (originDateMidnightLocal == null) {
      return null;
    }

    int scope = interval.scope(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params) ?? HealthRuleInterval.NoScope;
    if (HealthRuleInterval.NoScope < scope) { // check only newer items than the current
      int startIndex = (HealthRuleInterval.FutureScope < scope) ? originIndex : (originIndex - 1);
      for (int index = startIndex; 0 <= index; index--) {
        if (_evalRequireEntryFulfills(history[index], historyType, originDateMidnightLocal: originDateMidnightLocal, interval: interval, rules: rules, params: params)) {
          return index;
        }
      }
    }
    else if (scope < HealthRuleInterval.NoScope) { // check only older items than the current
      int startIndex = (scope < HealthRuleInterval.PastScope) ? originIndex : (originIndex + 1);
      for (int index = startIndex; index < history.length; index++) {
        if (_evalRequireEntryFulfills(history[index], historyType, originDateMidnightLocal: originDateMidnightLocal, interval: interval, rules: rules, params: params)) {
          return index;
        }
      }
    }
    else { // check all history items
      for (int index = 0; index < history.length; index++) {
        if ((index != originIndex) && _evalRequireEntryFulfills(history[index], historyType, originDateMidnightLocal: originDateMidnightLocal, interval: interval, rules: rules, params: params)) {
          return index;
        }
      }
    }

    // If positive time interval is not already expired - do not return failed status yet.
    if ((interval.current(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params) == true) && _evalCurrentIntervalFulfills(interval, originDateMidnightLocal, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params)) {
      return originIndex;
    }

    return -1;
  }

  bool _evalRequireEntryFulfills(HealthHistory entry, dynamic historyType, { DateTime originDateMidnightLocal, _HealthRuleInterval interval, List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    if (_matchValue(historyType, entry.type)) {
      DateTime entryDateMidnightLocal = entry.dateMidnightLocal;
      
      //#572 Building access calculation issue 
      //int difference = entryDateMidnightLocal.difference(originDateMidnightLocal).inDays;
      int difference = AppDateTime.midnightsDifferenceInDays(originDateMidnightLocal, entryDateMidnightLocal);
      if (interval.match(difference, orgDate: originDateMidnightLocal, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params)) {

        // check filters before returning successfull match
        if (_matchValue(historyType, HealthHistoryType.test)) {
          dynamic category = (conditionParams != null) ? conditionParams['category'] : null;
          if (category != null) {
            HealthTestRuleResult entryRuleResult = rules?.tests?.matchRuleResult(blob: entry?.blob);
            return _matchStringTarget(source: entryRuleResult?.category, target: category);
          }
        }
        else if (_matchValue(historyType, HealthHistoryType.action)) {
          dynamic type = (conditionParams != null) ? conditionParams['type'] : null;
          if ((type != null) && !_matchStringTarget(source: entry?.blob?.actionType, target: entry)) {
            return false;
          }
        }
        else if (_matchValue(historyType, HealthHistoryType.vaccine)) {
          dynamic vaccine = (conditionParams != null) ? conditionParams['vaccine'] : null;
          if ((vaccine != null) && !_matchStringTarget(source: entry?.blob?.vaccine, target: vaccine)) {
            return false;
          }
        }

        return true;
      }
    }
    return false;
  }

  dynamic _evalTimeout({ List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    _HealthRuleInterval interval = (conditionParams != null) ? _HealthRuleInterval.fromJson(conditionParams['interval']) : null;
    if (interval == null) {
      return null;
    }

    int originIndex = (interval.origin(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params) == HealthRuleIntervalOrigin.referenceDate) ? referenceIndex : historyIndex;
    HealthHistory originEntry = ((history != null) && (originIndex != null) && (0 <= originIndex) && (originIndex < history.length)) ? history[originIndex] : null;
    DateTime originDateMidnightLocal = originEntry?.dateMidnightLocal;
    if (originDateMidnightLocal == null) {
      return null;
    }

    // while current time is within interval 'timeout' condition fails
    return !_evalCurrentIntervalFulfills(interval, originDateMidnightLocal, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
  }

  static bool _evalCurrentIntervalFulfills(_HealthRuleInterval currentInterval, DateTime originDateMidnightLocal, { List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params } ) {
    if (currentInterval != null) {
      //#572 Building access calculation issue 
      //int difference = AppDateTime.todayMidnightLocal.difference(originDateMidnightLocal).inDays;
      int difference = AppDateTime.midnightsDifferenceInDays(originDateMidnightLocal, AppDateTime.todayMidnightLocal);
      if (currentInterval.match(difference, orgDate: originDateMidnightLocal, history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params)) {
        return true;
      }
    }
    return false;
  }

  static bool _evalTestInterval(Map<String, dynamic> conditionParams, { List<HealthHistory> history, int historyIndex, int referenceIndex, HealthRulesSet rules, Map<String, dynamic> params }) {
    dynamic interval = (conditionParams != null) ? _HealthRuleInterval.fromJson(conditionParams['interval']) : null;
    return interval?.valid(history: history, historyIndex: historyIndex, referenceIndex: referenceIndex, rules: rules, params: params);
  }

  static bool _evalTestUser(Map<String, dynamic> conditionParams, { HealthRulesSet rules, Map<String, dynamic> params }) {
    
    dynamic role = (conditionParams != null) ? conditionParams['role'] : null;
    if ((role != null) && !_matchStringTarget(target: UserRole.userRolesToList(UserProfile().roles), source: role)) {
      return false;
    }
    
    dynamic login = (conditionParams != null) ? conditionParams['login'] : null;
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
    
    dynamic cardRole = (conditionParams != null) ? conditionParams['card.role'] : null;
    if ((cardRole != null) && !_matchStringTarget(target: Auth().authCard?.role, source: cardRole)) {
      return false;
    }
    
    dynamic cardStudentLevel = (conditionParams != null) ? conditionParams['card.student_level'] : null;
    if ((cardStudentLevel != null) && !_matchStringTarget(target: Auth().authCard?.studentLevel, source: cardStudentLevel)) {
      return false;
    }

    return true;
  }

  static bool _matchValue(dynamic values, dynamic value) {
    return (values == value) || ((values is List) && values.contains(value)) || ((values is Set) && values.contains(value));
  }

  static bool _matchStringTarget({dynamic source, dynamic target}) {
    if (target is String) {
      if (source is String) {
        return source.toLowerCase() == target.toLowerCase();
      }
      else if (source is Iterable) {
        for (dynamic sourceEntry in source) {
          if (_matchStringTarget(source: sourceEntry, target: target)) {
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

class HealthRuleConditionResult {
  final bool result;
  final int  referenceIndex;
  HealthRuleConditionResult({this.result, this.referenceIndex});
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



