


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

import 'package:flutter/material.dart';

///////////////////////////////
// ExposureTEK

class ExposureTEK {
  final String tek;
  final int timestamp;
  final int expirestamp;

  ExposureTEK({this.tek, this.timestamp, this.expirestamp});

  factory ExposureTEK.fromJson(Map<String, dynamic> json) {
    return (json != null) ? ExposureTEK(
        tek: json['tek'],
        timestamp: json['timestamp'],
        expirestamp: json['expirestamp'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'tek': tek,
      'timestamp': timestamp,
      'expirestamp': expirestamp,
    };
  }

  DateTime get dateUtc {
    return (timestamp != null) ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true) : null;
  }

  DateTime get expireUtc {
    return (expirestamp != null) ? DateTime.fromMillisecondsSinceEpoch(expirestamp, isUtc: true) : null;
  }

  static List<ExposureTEK> listFromJson(List<dynamic> json) {
    List<ExposureTEK> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
        ExposureTEK value;
        try { value = ExposureTEK.fromJson((entry as Map)?.cast<String, dynamic>()); }
        catch(e) { print(e?.toString()); }
        values.add(value);
      }
    }
    return values;
  }

  static List<dynamic> listToJson(List<ExposureTEK> values) {
    List<dynamic> json;
    if (values != null) {
      json = [];
      for (ExposureTEK value in values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }

  static Map<String, ExposureTEK> mapFromJson(List<dynamic> json) {
    Map<String, ExposureTEK> result;
    if (json != null) {
      result = Map<String, ExposureTEK>();
      for (dynamic entry in json) {
        ExposureTEK value;
        try { value = ExposureTEK.fromJson((entry as Map)?.cast<String, dynamic>()); }
        catch(e) { print(e?.toString()); }
        if (value.tek != null) {
          result[value.tek] = value;
        }
      }
    }
    return result;
  }

  static List<dynamic> mapToJson(Map<String, ExposureTEK> entries) {
    List<dynamic> json;
    if (entries != null) {
      json = [];
      for (ExposureTEK value in entries.values) {
        json.add(value?.toJson());
      }
    }
    return json;
  }
}

///////////////////////////////
// ExposureRecord

class ExposureRecord {
  final int    id;
  final String rpi;
  final int    timestamp;
  final int    duration;

  ExposureRecord({this.id, this.rpi, this.timestamp, this.duration});

  DateTime get dateUtc {
    return (timestamp != null) ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true) : null;
  }

  int get durationInMinutes {
    return (duration ~/ 60000); // milliseconds -> minutes
  }

  String get durationDisplayString {
    int durationInSeconds = (duration != null) ? duration ~/ 1000 : null;
    if (durationInSeconds != null) {
      if (durationInSeconds < 60) {
        return "$durationInSeconds sec" + (1 != durationInSeconds ? "s" : "");
      }
      else {
        int durationInMinutes = durationInSeconds ~/ 60;
        if (durationInMinutes < TimeOfDay.minutesPerHour) {
          return "$durationInMinutes min" + (1 != durationInMinutes ? "s" : "");
        } else {
          int exposureHours = durationInMinutes ~/ TimeOfDay.minutesPerHour;
          return "$exposureHours hr" + (1 != exposureHours ? "s" : "");
        }

      }
    }
    return null;
  }
}
