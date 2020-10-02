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


import 'package:flutter/services.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as timezone;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

class AppDateTime with Service {
  static final AppDateTime _instance = new AppDateTime._internal();

  static final iso8601DateTimeFormat = 'yyyy-MM-ddTHH:mm:ss';
  static final eventsServerCreateDateTimeFormat =  'yyyy/MM/ddTHH:mm:ss';
  static final scheduleServerQueryDateTimeFormat = 'MM/dd/yyyy';
  static final serverResponseDateTimeFormat = 'E, dd MMM yyyy HH:mm:ss v';
  static final gameResponseDateTimeFormat = 'yyyy-MM-ddTHH:mm:ssZ';
  static final gameResponseDateTimeFormat2 = 'MM/dd/yyyy HH:mm:ss a';
  static final illiniCashTransactionHistoryDateFormat = 'MM-dd-yyyy';
  static final eventFilterDisplayDateFormat = 'MM/dd';
  static final voterDateFormat = "yyyy/MM/dd";
  static final parkingEventDateFormat = "yyyy-MM-ddTHH:mm:ssZ";
  static final covid19UpdateDateFormat = "MMMM dd, yyyy";
  static final covid19QrDateFormat = "MMMM dd, yyyy, HH:mm:ss a";
  static final covid19NewsCardDateFormat = "MMMM dd";
  static final covid19ServerDateFormat = "yyyy-MM-ddTHH:mm:ss.SSSZ";
  static final covid19OSFServerDateFormat = "yyyy-MM-ddTHH:mm:ssZ";
  static final covid19ReportTestDateFormat = 'MM/dd/yyyy h:mm a';

  factory AppDateTime() {
    return _instance;
  }

  AppDateTime._internal();

  timezone.Location _universityLocation;
  String _localTimeZone;

  @override
  Future<void> initService() async {
    _init();
  }

  _init() async {
    _loadDefaultData().then((rawData) {
      timezone.initializeDatabase(rawData);
      timezone.Location deviceLocation = timezone.getLocation(_localTimeZone);
      timezone.setLocalLocation(deviceLocation);
      _universityLocation = timezone.getLocation('America/Chicago');
    });
  }

  Future<List<int>> _loadDefaultData() async {
    _localTimeZone = await FlutterNativeTimezone.getLocalTimezone();
    var byteData = await rootBundle.load('assets/timezone2019a.tzf');
    return byteData.buffer.asUint8List();
  }

  DateTime dateTimeFromString(String dateTimeString, {String format, bool isUtc = false}) {
    if (AppString.isStringEmpty(dateTimeString)) {
      return null;
    }
    DateFormat dateFormat;
    DateTime dateTime;
    if (AppString.isStringNotEmpty(format)) {
      dateFormat = DateFormat(format);
    }
    try {
      dateTime =
      (dateFormat != null) ? dateFormat.parse(dateTimeString, isUtc) : DateTime.parse(
          dateTimeString);
    }
    on Exception catch (e) {
      Log.e(e.toString());
    }
    return dateTime;
  }

  DateTime getUniLocalTimeFromUtcTime(DateTime dateTimeUtc) {
    return (dateTimeUtc != null) ? timezone.TZDateTime.from(dateTimeUtc, _universityLocation) : null;
  }

  String formatUniLocalTimeFromUtcTime(DateTime dateTimeUtc, String format) {
    if(dateTimeUtc != null && format != null){
      DateTime uniTime = getUniLocalTimeFromUtcTime(dateTimeUtc);
      return DateFormat(format).format(uniTime);
    }
    return null;
  }

  String formatDateTime(DateTime dateTime,
      {String format, bool ignoreTimeZone = false, bool showTzSuffix = false}) {
    if (dateTime == null) {
      return null;
    }
    if (AppString.isStringEmpty(format)) {
      format = iso8601DateTimeFormat;
    }
    String formattedDateTime;
    DateFormat dateFormat = DateFormat(format);
    if (ignoreTimeZone) {
      try { formattedDateTime = dateFormat.format(dateTime); }
      catch (e) { print(e?.toString()); }
    } else {
      timezone.TZDateTime tzDateTime = timezone.TZDateTime.from(
          dateTime, _universityLocation);
      try { formattedDateTime = dateFormat.format(tzDateTime); }
      catch(e) { print(e?.toString()); } 
    }
    if (showTzSuffix) {
      formattedDateTime += ' CT';
    }
    return formattedDateTime;
  }

  String getDayGreeting() {
    int currentHour = DateTime.now().hour;
    if (currentHour > 7 && currentHour < 12) {
      return Localization().getStringEx("logic.date_time.greeting.morning", "Good morning");
    }
    else if (currentHour >= 12 && currentHour < 19) {
      return Localization().getStringEx("logic.date_time.greeting.afternoon", "Good afternoon");
    }
    else {
      return Localization().getStringEx("logic.date_time.greeting.evening", "Good evening");
    }
  }

  static int getWeekDayFromString(String weekDayName){
    switch (weekDayName){
      case "monday"   : return 1;
      case "tuesday"  : return 2;
      case "wednesday": return 3;
      case "thursday" : return 4;
      case "friday"   : return 5;
      case "saturday" : return 6;
      case "sunday"   : return 7;
      default: return 0;
    }
  }

  static DateTime midnight(DateTime date) {
    return (date != null) ? DateTime(date.year, date.month, date.day) : null;
  }

  static DateTime get todayMidnightLocal {
    return midnight(DateTime.now());
  }

  static DateTime get tomorrowMidnightLocal {
    return midnight(DateTime.now()).add(Duration(days: 1));
  }

  static DateTime get yesterdayMidnightLocal {
    return midnight(DateTime.now()).add(Duration(days: -1));
  }
}