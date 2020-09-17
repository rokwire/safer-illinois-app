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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/UserData.dart';
import 'package:illinois/service/AppDateTime.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';
import 'package:intl/intl.dart';
import "package:pointycastle/export.dart";

///////////////////////////////
// Covid19News

class Covid19News implements Favorite {
  final String          id;
  final DateTime        date;
  final String          title;
  final String          description;
  final String          htmlContent;
  final String          link;

  Covid19News({this.id, this.date, this.title, this.description, this.htmlContent, this.link});

  factory Covid19News.fromJson(Map<String, dynamic> json) {
    return Covid19News(
      id: json['id'],
      date: healthDateTimeFromString(json['date']),
      title: json['title'],
      description: json['description'],
      htmlContent: json['htmlContent'],
      link: json['link'],
    );
  }

  String get displayDate {
    return AppDateTime().formatDateTime(date, format: AppDateTime.covid19NewsCardDateFormat);
  }

  dynamic toJson() {
    return {
      'id': id,
      'date': healthDateTimeToString(date),
      'title': title,
      'description': description,
      'htmlContent': htmlContent,
      'link': link,
    };
  }

  // Favorite implementation

  static String favoriteKeyName = "covid19NewsIds";

  @override
  String get favoriteId => id;

  @override
  String get favoriteKey => favoriteKeyName;
}

///////////////////////////////
// Covid19FAQEntry

class Covid19FAQEntry {
  final String          title;
  final String          description;
  final String          link;

  Covid19FAQEntry({this.title, this.description, this.link});

  factory Covid19FAQEntry.fromJson(Map<String, dynamic> json) {
    return Covid19FAQEntry(
      title: json['title'],
      description: json['description'],
      link: json['link'],
    );
  }

  dynamic toJson() {
    return {
      'title': title,
      'description': description,
      'link': link,
    };
  }

  static List<Covid19FAQEntry> fromJsonList(List<dynamic> jsonList) {
    List<Covid19FAQEntry> faqs;
    if (jsonList != null) {
      faqs = List();
      for (dynamic jsonEntry in jsonList) {
        faqs.add(Covid19FAQEntry.fromJson(jsonEntry));
      }
    }
    return faqs;
  }

  static List<dynamic> toJsonList(List<Covid19FAQEntry> faqs) {
    List<dynamic> jsonList;
    if (faqs != null) {
      jsonList = List();
      for (Covid19FAQEntry faq in faqs) {
        jsonList.add(faq.toJson());
      }
    }
    return jsonList;
  }
}

///////////////////////////////
// Covid19FAQSection

class Covid19FAQSection {
  final String                title;
  final List<Covid19FAQEntry> questions;

  Covid19FAQSection({this.title, this.questions});

  factory Covid19FAQSection.fromJson(Map<String, dynamic> json) {
    return Covid19FAQSection(
      title: json['title'],
      questions: Covid19FAQEntry.fromJsonList(json['questions']),
    );
  }

  dynamic toJson() {
    return {
      'title': title,
      'questions': Covid19FAQEntry.toJsonList(questions),
    };
  }

  static List<Covid19FAQSection> fromJsonList(List<dynamic> jsonList) {
    List<Covid19FAQSection> sections;
    if (jsonList != null) {
      sections = List();
      for (dynamic jsonEntry in jsonList) {
        sections.add(Covid19FAQSection.fromJson(jsonEntry));
      }
    }
    return sections;
  }

  static List<dynamic> toJsonList(List<Covid19FAQSection> sections) {
    List<dynamic> jsonList;
    if (sections != null) {
      jsonList = List();
      for (Covid19FAQSection section in sections) {
        jsonList.add(section.toJson());
      }
    }
    return jsonList;
  }
}

class Covid19FAQ {
  DateTime                dateUpdated;
  List<Covid19FAQSection> sections;
  List<Covid19FAQEntry>   general;

  Covid19FAQ({this.dateUpdated, this.sections, this.general});

  factory Covid19FAQ.fromJson(Map<String, dynamic> json) {
    return Covid19FAQ(
      dateUpdated: healthDateTimeFromString(json['dateUpdated']),
      sections: Covid19FAQSection.fromJsonList(json['sections']),
      general: Covid19FAQEntry.fromJsonList(json['general']),
    );
  }

  dynamic toJson() {
    return {
      'dateUpdated': healthDateTimeToString(dateUpdated),
      'sections': Covid19FAQSection.fromJsonList(sections),
      'general': Covid19FAQEntry.toJsonList(general),
    };
  }
}

///////////////////////////////
// Covid19Resource

class Covid19Resource {
  final String          title;
  final String          icon;
  final String          link;

  Covid19Resource({this.title, this.icon, this.link});

  factory Covid19Resource.fromJson(Map<String, dynamic> json) {
    return Covid19Resource(
      title: json['title'],
      icon: json['icon'],
      link: json['link'],
    );
  }

  dynamic toJson() {
    return {
      'title': title,
      'icon': icon,
      'link': link,
    };
  }
}

////////////////////////////////
// Covid19Status

class Covid19Status {
  final String id;
  final String userId;
  final DateTime dateUtc;
  final String encryptedKey;
  final String encryptedBlob;
  Covid19StatusBlob blob;

  Covid19Status({this.id, this.userId, this.dateUtc, this.encryptedKey, this.encryptedBlob, this.blob});

  factory Covid19Status.fromJson(Map<String, dynamic> json) {
    return (json != null) ? Covid19Status(
      id: json['id'],
      userId: json['user_id'],
      dateUtc: healthDateTimeFromString(json['date']),
      encryptedKey: json['encrypted_key'],
      encryptedBlob: json['encrypted_blob'],
        ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': healthDateTimeToString(dateUtc),
      'encrypted_key': encryptedKey,
      'encrypted_blob': encryptedBlob,
    };
  }

  static Future<Covid19Status> decryptedFromJson(Map<String, dynamic> json, PrivateKey privateKey) async {
    try {
      Covid19Status value = Covid19Status.fromJson(json);
      if ((value != null) && (value.encryptedKey != null) && (value.encryptedBlob != null) && (privateKey != null)) {
        String blobString = await compute(_decryptBlob, {
          'encryptedKey': value.encryptedKey,
          'encryptedBlob': value.encryptedBlob,
          'privateKey': privateKey
        });
        value.blob = Covid19StatusBlob.fromJson(AppJson.decodeMap(blobString));
      }
      return value;
    }
    catch(e) { print(e?.toString()); }
    return null;
  }

  Future<Covid19Status> encrypted(PublicKey publicKey) async {
    Map<String, dynamic> encrypted = await compute(_encryptBlob, {
      'blob': AppJson.encode(blob?.toJson()),
      'publicKey': publicKey
    });
    return Covid19Status(
      id: id,
      userId: userId,
      dateUtc: dateUtc,
      encryptedKey: encrypted['encryptedKey'],
      encryptedBlob: encrypted['encryptedBlob'],
    );
  }
}

///////////////////////////////
// Covid19StatusBlob

class Covid19StatusBlob {
  final String healthStatus;
  final int priority;
  final String nextStep;
  final String nextStepHtml;
  final DateTime nextStepDateUtc;
  final String reason;
  final String warning;
  final Covid19HistoryBlob historyBlob;

  static const String _nextStepDateMacro = '{next_step_date}';
  static const String _nextStepDateFormat = 'EEEE, MMM d';

  Covid19StatusBlob({this.healthStatus, this.priority, this.nextStep, this.nextStepHtml, this.nextStepDateUtc, this.reason, this.warning, this.historyBlob});


  factory Covid19StatusBlob.fromJson(Map<String, dynamic> json) {
    return (json != null) ? Covid19StatusBlob(
      healthStatus: json['health_status'],
      priority: json['priority'],
      nextStep: json['next_step'],
      nextStepHtml: json['next_step_html'],
      nextStepDateUtc: healthDateTimeFromString(json['next_step_date']),
      reason: json['reason'],
      warning: json['warning'],
      historyBlob: Covid19HistoryBlob.fromJson(json['history_blob']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'health_status': healthStatus,
      'priority': priority,
      'next_step': nextStep,
      'next_step_html': nextStepHtml,
      'next_step_date': healthDateTimeToString(nextStepDateUtc),
      'reason': reason,
      'warning': warning,
      'history_blob': historyBlob?.toJson(),
    };
  }

  String get displayNextStep {
    return _processMacros(nextStep);
  }

  String get displayNextStepHtml {
    return _processMacros(nextStepHtml);
  }

  String get displayReason {
    return _processMacros(reason);
  }

  String get displayWarning {
    return _processMacros(warning);
  }

  String _processMacros(String value) {
    if ((value != null) && (nextStepDateUtc != null) && value.contains(_nextStepDateMacro)) {
      String nextStepDateString = AppDateTime().formatDateTime(nextStepDateUtc.toLocal(), format: _nextStepDateFormat);
      return value.replaceAll(_nextStepDateMacro, nextStepDateString);
    }
    return value;
  }

  bool get requiresTest {
    // TBD
    return (nextStep?.toLowerCase()?.contains("test") ?? false) ||
      (nextStepHtml?.toLowerCase()?.contains("test") ?? false);  
  }

  String get localizedHealthStatus {
    return localizedHealthStatusFromKey(healthStatus);
  }

  String get localizedHealthStatusType {
    return localizedHealthStatusTypeFromKey(healthStatus);
  }

  String get localizedHealthStatusDescription {
    return localizedHealthStatusDescriptionFromKey(healthStatus);
  }

  static String localizedHealthStatusFromKey(String key) {
    return _localizedHealthStatusFromKey("com.illinois.covid19.status.long.${key.toLowerCase()}", AppString.capitalize(key));
  }

  static String localizedHealthStatusTypeFromKey(String key) {
    return _localizedHealthStatusFromKey("com.illinois.covid19.status.type.${key.toLowerCase()}", AppString.capitalize(key));
  }

  static String localizedHealthStatusDescriptionFromKey(String key) {
    return _localizedHealthStatusFromKey("com.illinois.covid19.status.description.${key.toLowerCase()}", AppString.capitalize(key));
  }

  static String _localizedHealthStatusFromKey(String key, String defaultValue) {
    if(key != null){
      return Localization().getStringEx(key, defaultValue);
    }
    return defaultValue;
  }
}

///////////////////////////////
// Covid19HealthStatus

const String kCovid19HealthStatusRed       = 'red';
const String kCovid19HealthStatusOrange    = 'orange';
const String kCovid19HealthStatusYellow    = 'yellow';
const String kCovid19HealthStatusGreen     = 'green';
const String kCovid19HealthStatusUnchanged = 'no change';

Color covid19HealthStatusColor(String status) {
  switch (status) {
    case kCovid19HealthStatusRed:    return Styles().colors.healthStatusRed;
    case kCovid19HealthStatusOrange: return Styles().colors.healthStatusOrange;
    case kCovid19HealthStatusYellow: return Styles().colors.healthStatusYellow;
    case kCovid19HealthStatusGreen:  return Styles().colors.healthStatusGreen;
    default:                         return null;
  }
}

bool covid19HealthStatusIsValid(String status) {
  return (status != null) && (status != kCovid19HealthStatusUnchanged);
}

int covid19HealthStatusWeight(String status) {
  switch (status) {
    case kCovid19HealthStatusRed:    return 4;
    case kCovid19HealthStatusOrange: return 3;
    case kCovid19HealthStatusYellow: return 2;
    case kCovid19HealthStatusGreen:  return 1;
    default:                         return 0;
  }
}

////////////////////////////////
// Covid19Access

const String kCovid19AccessGranted   = 'granted';
const String kCovid19AccessDenied    = 'denied';


///////////////////////////////
// Covid19History

class Covid19History {
  final String id;
  final String userId;
  final DateTime dateUtc;
  final Covid19HistoryType type;

  final String encryptedKey;
  final String encryptedBlob;
  
  final String locationId;
  final String countyId;
  final String encryptedImageKey;
  final String encryptedImageBlob;

  Covid19HistoryBlob blob;

  Covid19History({this.id, this.userId, this.dateUtc, this.type, this.encryptedKey, this.encryptedBlob, this.locationId, this.countyId, this.encryptedImageKey, this.encryptedImageBlob });

  factory Covid19History.fromJson(Map<String, dynamic> json) {
    return (json != null) ? Covid19History(
      id: json['id'],
      userId: json['user_id'],
      dateUtc: healthDateTimeFromString(json['date']),
      type: covid19HistoryTypeFromString(json['type']),

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
      'user_id': userId,
      'date': healthDateTimeToString(dateUtc),
      'type': covid19HistoryTypeToString(type),

      'encrypted_key': encryptedKey,
      'encrypted_blob': encryptedBlob,

      'location_id': locationId,
      'county_id': countyId,
      'encrypted_image_key': encryptedImageKey,
      'encrypted_image_blob': encryptedImageBlob,
    };
  }

  static Future<Covid19History> decryptedFromJson(Map<String, dynamic> json, Map<Covid19HistoryType, PrivateKey> privateKeys ) async {
    try {
      Covid19History value = Covid19History.fromJson(json);
      PrivateKey privateKey = privateKeys[value.type];
      if ((value != null) && (value.encryptedKey != null) && (value.encryptedBlob != null) && (privateKey != null)) {
        String blobString = await compute(_decryptBlob, {
          'encryptedKey': value.encryptedKey,
          'encryptedBlob': value.encryptedBlob,
          'privateKey': privateKey
        });
        value.blob = Covid19HistoryBlob.fromJson(AppJson.decodeMap(blobString));
      }
      return value;
    }
    catch(e) { print(e?.toString()); }
    return null;
  }

  static Future<Covid19History> encryptedFromBlob({String id, String userId, DateTime dateUtc, Covid19HistoryType type, Covid19HistoryBlob blob, String locationId, String countyId, String image, PublicKey publicKey}) async {
    Map<String, dynamic> encrypted = await compute(_encryptBlob, {
      'blob': AppJson.encode(blob?.toJson()),
      'publicKey': publicKey
    });
    Map<String, dynamic> encryptedImage = (image != null) ? await compute(_encryptBlob, {
      'blob': image,
      'publicKey': publicKey
    }) : null;
    return Covid19History(
      id: id,
      userId: userId,
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
    return (type == Covid19HistoryType.test) || (type == Covid19HistoryType.manualTestNotVerified) || (type == Covid19HistoryType.manualTestVerified);
  }

  bool get isManualTest {
    return (type == Covid19HistoryType.manualTestNotVerified) || (type == Covid19HistoryType.manualTestVerified);
  }

  bool get isTestVerified {
    return (type == Covid19HistoryType.test) || (type == Covid19HistoryType.manualTestVerified);
  }

  bool get canTestUpdateStatus {
    return (type == Covid19HistoryType.test) || (type == Covid19HistoryType.manualTestVerified);
  }

  bool get isSymptoms {
    return (type == Covid19HistoryType.symptoms);
  }

  bool get isContactTrace {
    return (type == Covid19HistoryType.contactTrace);
  }

  bool get isAction {
    return (type == Covid19HistoryType.action);
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

  bool matchEvent(Covid19Event event) {
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
        (this.blob?.actionText == event?.blob?.actionText);
    }
    else {
      return false;
    }
  }

  static Future<List<Covid19History>> listFromJson(List<dynamic> json, Map<Covid19HistoryType, PrivateKey> privateKeys) async {
    List<Covid19History> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          Covid19History value = await Covid19History.decryptedFromJson((entry as Map)?.cast<String, dynamic>(), privateKeys);
          values.add(value);
      }
    }
    return values;
  }

  /*static List<dynamic> listToJson(List<Covid19History> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (Covid19History value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }*/

  static Covid19History traceInList(List<Covid19History> values, { String tek }) {
    if ((values != null) && (tek != null)) {
      for (Covid19History history in values) {
        if ((history.type == Covid19HistoryType.contactTrace) && (history.blob?.traceTEK == tek)) {
          return history;
        }
      }
    }
    return null;
  }

  static bool listContainsEvent(List<Covid19History> histories, Covid19Event event) {
    if ((histories != null) && (event != null)) {
      for (Covid19History history in histories) {
         if (history.matchEvent(event)) {
           return true;
         }
      }
    }
    return false;
  }

  static Covid19History mostRecent(List<Covid19History> histories) {
    if (histories != null) {
      DateTime nowUtc = DateTime.now().toUtc();
      for (int index = 0; index < histories.length; index++) {
        Covid19History history = histories[index];
        if ((history.dateUtc != null) && (history.dateUtc.isBefore(nowUtc))) {
          return history;
        }
      }
    }
    return null;
  }

  static Covid19History mostRecentTest(List<Covid19History> histories) {
    if (histories != null) {
      DateTime nowUtc = DateTime.now().toUtc();
      for (int index = 0; index < histories.length; index++) {
        Covid19History history = histories[index];
        if (history.isTestVerified && (history.dateUtc != null) && (history.dateUtc.isBefore(nowUtc))) {
          return history;
        }
      }
    }
    return null;
  }

  static List<Covid19History> pastList(List<Covid19History> histories) {
    List<Covid19History> result;
    if (histories != null) {
      result = List<Covid19History>();
      DateTime nowUtc = DateTime.now().toUtc();
      for (int index = 0; index < histories.length; index++) {
        Covid19History history =  histories[index];
        if ((history.dateUtc != null) && (history.dateUtc.isBefore(nowUtc))) {
          result.add(history);
        }
      }
    }
    return result;
  }
}

////////////////////////////////
// Covid19HistoryBlob

class Covid19HistoryBlob {
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
  final String actionText;

  Covid19HistoryBlob({
    this.provider, this.providerId, this.location, this.locationId, this.countyId, this.testType, this.testResult,
    this.symptoms,
    this.traceDuration, this.traceTEK,
    this.actionType, this.actionText,
  });

  factory Covid19HistoryBlob.fromJson(Map<String, dynamic> json) {
    return (json != null) ? Covid19HistoryBlob(
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

  String get symptomsDisplayString {
    String result = "";
    if (symptoms != null) {
      for (HealthSymptom symptom in symptoms) {
        if (0 < result.length) {
          result += ", ";
        }
        result += symptom.name;
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

  String get actionDisplayString {
    return actionText ?? actionType;
  }
}

////////////////////////////////
// Covid19HistoryType

enum Covid19HistoryType { test, manualTestVerified, manualTestNotVerified, symptoms, contactTrace, action }

Covid19HistoryType covid19HistoryTypeFromString(String value) {
  if (value == 'received_test') {
    return Covid19HistoryType.test;
  }
  else if (value == 'verified_manual_test') {
    return Covid19HistoryType.manualTestVerified;
  }
  else if (value == 'unverified_manual_test') {
    return Covid19HistoryType.manualTestNotVerified;
  }
  else if (value == 'symptoms') {
    return Covid19HistoryType.symptoms;
  }
  else if (value == 'trace') {
    return Covid19HistoryType.contactTrace;
  }
  else if (value == 'action') {
    return Covid19HistoryType.action;
  }
  else {
    return null;
  }
}

String covid19HistoryTypeToString(Covid19HistoryType value) {
  switch (value) {
    case Covid19HistoryType.test: return 'received_test';
    case Covid19HistoryType.manualTestVerified: return 'verified_manual_test';
    case Covid19HistoryType.manualTestNotVerified: return 'unverified_manual_test';
    case Covid19HistoryType.symptoms: return 'symptoms';
    case Covid19HistoryType.contactTrace: return 'trace';
    case Covid19HistoryType.action: return 'action';
  }
  return null;
}

///////////////////////////////
// Covid19Event

class Covid19Event {
  final String   id;
  final String   provider;
  final String   providerId;
  final String   userId;
  final String   encryptedKey;
  final String   encryptedBlob;
  final bool     processed;
  final DateTime dateCreated;
  final DateTime dateUpdated;

  Covid19EventBlob blob;

  Covid19Event({this.id, this.provider, this.providerId, this.userId, this.encryptedKey, this.encryptedBlob, this.processed, this.dateCreated, this.dateUpdated});

  factory Covid19Event.fromJson(Map<String, dynamic> json) {
    return (json != null) ? Covid19Event(
      id:            AppJson.stringValue(json['id']),
      provider:      AppJson.stringValue(json['provider']),
      providerId:    AppJson.stringValue(json['provider_id']),
      userId:        AppJson.stringValue(json['user_id']),
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
    json['user_id']         = userId;
    json['encrypted_key']   = encryptedKey;
    json['encrypted_blob']  = encryptedBlob;
    json['processed']       = processed;
    json['date_created']    = healthDateTimeToString(dateCreated);
    json['date_updated']    = healthDateTimeToString(dateUpdated);
    return json;
  }

  static Future<Covid19Event> decryptedFromJson(Map<String, dynamic> json, PrivateKey privateKey) async {
    try {
      Covid19Event value = Covid19Event.fromJson(json);
      if ((value != null) && (value.encryptedKey != null) && (value.encryptedBlob != null) && (privateKey != null)) {
        String blobString = await compute(_decryptBlob, {
          'encryptedKey': value.encryptedKey,
          'encryptedBlob': value.encryptedBlob,
          'privateKey': privateKey
        });
        value.blob = Covid19EventBlob.fromJson(AppJson.decodeMap(blobString));
      }
      return value;
    }
    catch(e) { print(e?.toString()); }
    return null;
  }

  static Future<List<Covid19Event>> listFromJson(List<dynamic> json, PrivateKey privateKey) async {
    List<Covid19Event> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          Covid19Event value = await Covid19Event.decryptedFromJson(entry, privateKey);
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
// Covid19EventBlob

class Covid19EventBlob {
  final DateTime dateUtc;

  final String   testType;
  final String   testResult;

  final String   actionType;
  final String   actionText;

  Covid19EventBlob({this.dateUtc, this.testType, this.testResult, this.actionType, this.actionText});

  factory Covid19EventBlob.fromJson(Map<String, dynamic> json) {
    return (json != null) ? Covid19EventBlob(
      dateUtc:       healthDateTimeFromString(AppJson.stringValue(json['Date'])),
      testType:      AppJson.stringValue(json['TestName']),
      testResult:    AppJson.stringValue(json['Result']),
      actionType:    AppJson.stringValue(json['ActionType']),
      actionText:    AppJson.stringValue(json['ActionText']),
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
}


///////////////////////////////
// Covid19OSFTest

class Covid19OSFTest {
  final String provider;
  final String providerId;
  final String testType;
  final String testResult;
  final DateTime dateUtc;

  Covid19OSFTest({this.provider, this.providerId,  this.testType, this.testResult, this.dateUtc,});
}


///////////////////////////////
// Covid19ManualTest

class Covid19ManualTest {
  final String provider;
  final String providerId;
  final String location;
  final String locationId;
  final String countyId;
  final String testType;
  final String testResult;
  final DateTime dateUtc;
  final String image;

  Covid19ManualTest({this.provider, this.providerId, this.location, this.locationId, this.countyId, this.testType, this.testResult, this.dateUtc, this.image});
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
  String encryptedKey;
  String encryptedBlob;

  HealthUser({this.uuid, this.publicKeyString, PublicKey publicKey, this.consent, this.exposureNotification, this.repost, this.encryptedKey, this.encryptedBlob}) {
    _publicKey = publicKey;
  }

  factory HealthUser.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthUser(
      uuid: json['uuid'],
      publicKeyString: json['public_key'],
      consent: json['consent'],
      exposureNotification: json['exposure_notification'],
      repost: json['re_post'],
      encryptedKey: json['encrypted_key'],
      encryptedBlob: json['encrypted_blob'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'public_key': publicKeyString,
      'consent': consent,
      'exposure_notification': exposureNotification,
      're_post': repost,
      'encrypted_key': encryptedKey,
      'encrypted_blob': encryptedBlob,
    };
  }

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

  bool operator ==(o) =>
      o is HealthUser &&
          o.uuid == uuid &&
          o.publicKeyString == publicKeyString &&
          o.consent == consent &&
          o.exposureNotification == exposureNotification &&
          o.repost == repost &&
          o.encryptedKey == encryptedKey &&
          o.encryptedBlob == encryptedBlob;

  int get hashCode =>
      (uuid?.hashCode ?? 0) ^
      (publicKeyString?.hashCode ?? 0) ^
      (consent?.hashCode ?? 0) ^
      (exposureNotification?.hashCode ?? 0) ^
      (repost?.hashCode ?? 0) ^
      (encryptedKey?.hashCode ?? 0) ^
      (encryptedBlob?.hashCode ?? 0);
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
// HealthServiceProvider

class HealthServiceProvider {
  String id;
  String name;
  bool allowManualTest;
  List<HealthServiceMechanism> availableMechanisms;

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
  String id;
  String name;
  String contact;
  String city;
  String address1;
  String address2;
  String state;
  String country;
  String zip;
  String url;
  String notes;
  double latitude;
  double longitude;
  HealthLocationWaitTimeColor waitTimeColor;
  List<String> availableTests;
  List<HealthLocationDayOfOperation> daysOfOperation;
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

  static String waitTimeColorToDisplayString(HealthLocationWaitTimeColor color) {
    switch (color) {
      case HealthLocationWaitTimeColor.red:
        return Localization().getStringEx('model.covid19.location.wait_time.color.red', 'Long');
      case HealthLocationWaitTimeColor.yellow:
        return Localization().getStringEx('model.covid19.location.wait_time.color.yellow', 'Medium');
      case HealthLocationWaitTimeColor.green:
        return Localization().getStringEx('model.covid19.location.wait_time.color.green', 'Short');
      case HealthLocationWaitTimeColor.grey:
        return Localization().getStringEx('model.covid19.location.wait_time.color.grey', 'Closed');
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
      case HealthLocationWaitTimeColor.grey:
        return Styles().colors.healthLocationWaitTimeColorGrey;
      default:
        return Styles().colors.whiteTransparent06;
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
    DateTime dateTime = (time != null) ? AppDateTime().dateTimeFromString(time.toUpperCase(), format: format) : null;
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
  String id;
  String name;
  List<HealthTestTypeResult> results;

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
  String id;
  String name;
  String nextStep;
  int nextStepOffset;
  int nextStepExpiresOffset;

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
  String id;
  String name;
  String nameDisplayText;
  String state;
  String country;
  List<HealthGuideline> guidelines;

  HealthCounty({this.id, this.name, this.nameDisplayText, this.state, this.country,this.guidelines});

  factory HealthCounty.fromJson(Map<String, dynamic> json) {
    String name = json['name'];
    String state = json['state_province'];
    String nameDisplayText = AppString.isStringNotEmpty(state) ? "$name, $state" : name;
    return (json != null) ? HealthCounty(
      id: json['id'],
      name: name,
      nameDisplayText: nameDisplayText,
      state: state,
      country: json['country'],
      guidelines: HealthGuideline.fromJsonList(json['guidelines']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'state': state,
      'country': country,
      'guidelines': HealthGuideline.listToJson(guidelines),
    };
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

  static List<HealthCounty> listFromJson(List<dynamic> json) {
    List<HealthCounty> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthCounty value;
          try { value = HealthCounty.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthCounty> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthCounty value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}


///////////////////////////////
// HealthGuideline

class HealthGuideline {
  String id;
  String name;
  List<HealthGuidelineItem> items;

  HealthGuideline({this.id,this.name,this.items});

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
  String icon;
  String description;
  String type;

  HealthGuidelineItem({this.icon,this.description,this.type});

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
// HealthTestRule

class HealthTestRule {
  String testTypeId;
  String testType;
  List<HealthTestRuleResult> results;

  HealthTestRule({this.testTypeId, this.testType, this.results});

  factory HealthTestRule.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRule(
      testTypeId: json['test_type_id'],
      testType: json['test_type'],
      results: HealthTestRuleResult.listFromJson(json['results']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'test_type_id': testTypeId,
      'test_type': testType,
      'results': HealthTestRuleResult.listToJson(results),
    };
  }

  static HealthTestRuleResult matchResult(List<HealthTestRule> rules, {String testType, String testResult}) {
    if (rules != null) {
      for (HealthTestRule rule in rules) {
        if ((rule?.testType != null) && (rule.testType.toLowerCase() == testType?.toLowerCase()) && (rule?.results != null)) {
          for (HealthTestRuleResult ruleResult in rule.results) {
            if ((ruleResult?.testResult != null) && (ruleResult.testResult.toLowerCase() == testResult?.toLowerCase())) {
              return ruleResult;
            }
          }
        }
      }
    }
    return null;
  }

  static List<HealthTestRule> listFromJson(List<dynamic> json) {
    List<HealthTestRule> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthTestRule value;
          try { value = HealthTestRule.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthTestRule> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
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
  String testResult;
  String healthStatus;
  String nextStep;
  int nextStepTimeInterval;

  HealthTestRuleResult({this.testResult, this.healthStatus, this.nextStep, this.nextStepTimeInterval});

  factory HealthTestRuleResult.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRuleResult(
      testResult: json['result'],
      healthStatus: json['health_status'],
      nextStep: json['result_next_step'],
      nextStepTimeInterval: json['result_next_step_time_interval']
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'result': testResult,
      'health_status': healthStatus,
      'result_next_step': nextStep,
      'result_next_step_time_interval': nextStepTimeInterval,
    };
  }

  DateTime nextStepDate(DateTime testDate) {
    return ((testDate != null) && (nextStepTimeInterval != null)) ?
      testDate.add(Duration(hours: nextStepTimeInterval)) : null;
  }

  static List<HealthTestRuleResult> listFromJson(List<dynamic> json) {
    List<HealthTestRuleResult> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthTestRuleResult value;
          try { value = HealthTestRuleResult.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthTestRuleResult> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthTestRuleResult value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
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
  final bool visible;
  final List<HealthSymptom> symptoms;

  HealthSymptomsGroup({this.id, this.name, this.visible, this.symptoms});

  factory HealthSymptomsGroup.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptomsGroup(
      id: json['id'],
      name: json['name'],
      visible: json['visible'],
      symptoms: HealthSymptom.listFromJson(json['symptoms']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'visible': visible,
      'symptoms': HealthSymptom.listToJson(symptoms),
    };
  }

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
// HealthSymptomsRule

class HealthSymptomsRule {
  String id;
  int group1Count;
  int group2Count;
  List<HealthSymptomsRuleResult> results;

  HealthSymptomsRule({this.id, this.group1Count, this.group2Count, this.results});

  factory HealthSymptomsRule.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptomsRule(
      id: json['id'],
      group1Count: json['gr1_count'],
      group2Count: json['gr2_count'],
      results: HealthSymptomsRuleResult.listFromJson(json['items']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gr1_count': group1Count,
      'gr2_count': group2Count,
      'items': HealthSymptomsRuleResult.listToJson(results),
    };
  }

  HealthSymptomsRuleResult matchResult(Map<String, int> counts) {
    if (counts != null) {
      int gr1Count = counts['gr1'] ?? 0;
      bool gr1Fulfilled = (gr1Count >= group1Count);
      
      int gr2Count = counts['gr2'] ?? 0;
      bool gr2Fulfilled = (gr2Count >= group2Count);

      if (results != null) {
        for (HealthSymptomsRuleResult result in results) {
          if ((result.group1 == gr1Fulfilled) && (result.group2 == gr2Fulfilled)) {
            return result;
          }
        }
      }
    }
    return null;
  }

  static List<HealthSymptomsRule> listFromJson(List<dynamic> json) {
    List<HealthSymptomsRule> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthSymptomsRule value;
          try { value = HealthSymptomsRule.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthSymptomsRule> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthSymptomsRule value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// HealthSymptomsRuleResult

class HealthSymptomsRuleResult {
  bool group1, group2;
  String healthStatus;
  String nextStep;

  HealthSymptomsRuleResult({this.group1, this.group2, this.healthStatus, this.nextStep});

  factory HealthSymptomsRuleResult.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptomsRuleResult(
      group1: json['gr1'],
      group2: json['gr2'],
      healthStatus: json['health_status'],
      nextStep: json['next_step'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'group1': group1,
      'group2': group2,
      'health_status': healthStatus,
      'next_step': nextStep,
    };
  }

  static List<HealthSymptomsRuleResult> listFromJson(List<dynamic> json) {
    List<HealthSymptomsRuleResult> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthSymptomsRuleResult value;
          try { value = HealthSymptomsRuleResult.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthSymptomsRuleResult> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthSymptomsRuleResult value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// HealthContactTraceRule

class HealthContactTraceRule {
  int timeout;
  List<HealthContactTraceRuleResult> results;

  HealthContactTraceRule({this.timeout, this.results});

  factory HealthContactTraceRule.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthContactTraceRule(
      timeout: json['timeout'],
      results: HealthContactTraceRuleResult.listFromJson(json['items']),
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'timeout': timeout,
      'items': HealthContactTraceRuleResult.listToJson(results),
    };
  }

  HealthContactTraceRuleResult _matchResult({int traceTimeout, int traceDuration}) {

    if (((timeout == null) || (traceTimeout <= timeout)) && (results != null)) {
      for (HealthContactTraceRuleResult result in results) {
        if (result.matches(traceDuration: traceDuration)) {
          return result;
        }
      }
    }

    return null;
  }

  static HealthContactTraceRuleResult matchResult(List<HealthContactTraceRule> rules, {DateTime traceDate, int traceDuration}) {
    if ((rules != null) && (traceDate != null) && (traceDuration != null)) {
      int traceTimeout = DateTime.now().toUtc().difference(traceDate).inHours;
      for (HealthContactTraceRule rule  in rules) {
        HealthContactTraceRuleResult result = rule._matchResult(traceTimeout: traceTimeout, traceDuration: traceDuration);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  static List<HealthContactTraceRule> listFromJson(List<dynamic> json) {
    List<HealthContactTraceRule> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthContactTraceRule value;
          try { value = HealthContactTraceRule.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthContactTraceRule> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthContactTraceRule value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// HealthContactTraceRuleResult

class HealthContactTraceRuleResult {
  int duration;
  String healthStatus;
  String nextStep;

  HealthContactTraceRuleResult({this.duration, this.healthStatus, this.nextStep});

  factory HealthContactTraceRuleResult.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthContactTraceRuleResult(
      duration: json['duration'],
      healthStatus: json['health_status'],
      nextStep: json['next_step'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'duration': duration,
      'health_status': healthStatus,
      'next_step': nextStep,
    };
  }

  bool matches({int traceDuration}) {
    return ((duration == null) || (traceDuration >= duration));
  }

  static List<HealthContactTraceRuleResult> listFromJson(List<dynamic> json) {
    List<HealthContactTraceRuleResult> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          HealthContactTraceRuleResult value;
          try { value = HealthContactTraceRuleResult.fromJson((entry as Map)?.cast<String, dynamic>()); }
          catch(e) { print(e?.toString()); }
          values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<HealthContactTraceRuleResult> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (HealthContactTraceRuleResult value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// Health DateTime

// AppDateTime.covid19ServerDateFormat

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
// HealthOSFAuth

class HealthOSFAuth{
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
// Blob Encryption & Decryption

String _decryptBlob(Map<String, dynamic> param) {
  String encKey = (param != null) ? param['encryptedKey'] : null;
  String encBlob = (param != null) ? param['encryptedBlob'] : null;
  PrivateKey privateKey = (param != null) ? param['privateKey'] : null;

  String aesKey = ((privateKey != null) && (encKey != null)) ? RSACrypt.decrypt(encKey, privateKey) : null;
  String blob = ((aesKey != null) && (encBlob != null)) ? AESCrypt.decrypt(encBlob, aesKey) : null;
  return blob;
}

Map<String, dynamic> _encryptBlob(Map<String, dynamic> param) {
  String blob = (param != null) ? param['blob'] : null;
  PublicKey publicKey =  (param != null) ? param['publicKey'] : null;
  String aesKey = AESCrypt.randomKey();

  String encryptedBlob = ((blob != null) && (aesKey != null)) ? AESCrypt.encrypt(blob, aesKey) : null;
  String encryptedKey = ((blob != null) && (aesKey != null) && (publicKey != null)) ? RSACrypt.encrypt(aesKey, publicKey) : null;

  return {
    'encryptedKey': encryptedKey,
    'encryptedBlob': encryptedBlob,
  };
}



