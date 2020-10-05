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


import 'package:illinois/utils/Utils.dart';
import 'package:intl/intl.dart';

class AppDateTime {

  static DateTime parseDateTime(String dateTimeString, {String format, bool isUtc = false}) {
    if (AppString.isStringNotEmpty(dateTimeString)) {
      if (AppString.isStringNotEmpty(format)) {
        try { return DateFormat(format).parse(dateTimeString, isUtc); }
        catch (e) { print(e?.toString()); }
      }
      else {
        return DateTime.tryParse(dateTimeString);
      }
    }
    return null;
  }

  static String formatDateTime(DateTime dateTime, { String format = 'yyyy-MM-ddTHH:mm:ss' }) {
    if ((dateTime != null) && (format != null)) {
      try { return DateFormat(format).format(dateTime); }
      catch (e) { print(e?.toString()); }
    }
    return null;
  }

  static AppTimeOfDay timeOfDay({DateTime dateTime}) {
    int hour = (dateTime != null) ? dateTime.hour : DateTime.now().hour;
    if (hour > 7 && hour < 12) {
      return AppTimeOfDay.Morning;
    }
    else if (hour >= 12 && hour < 19) {
      return AppTimeOfDay.Afternoon;
    }
    else {
      return AppTimeOfDay.Evening;
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

enum AppTimeOfDay {
  Morning,
  Afternoon,
  Evening
}