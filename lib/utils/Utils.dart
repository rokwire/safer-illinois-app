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
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';
import 'package:illinois/service/Styles.dart';
import 'package:path/path.dart' as Path;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/Network.dart';

class AppBytes{
  static Uint8List decodeBase64Bytes(String base64String){
    return base64Decode(base64String);
  }
}

class AppString {

  static bool isStringEmpty(String stringToCheck) {
    return (stringToCheck == null || stringToCheck.isEmpty);
  }

  static bool isStringNotEmpty(String stringToCheck) {
    return !isStringEmpty(stringToCheck);
  }

  static String getDefaultEmptyString({String value, String defaultValue = ''}) {
    if (isStringEmpty(value)) {
      return defaultValue;
    }
    return value;
  }

  static String getMaskedPhoneNumber(String phoneNumber) {
    if(AppString.isStringEmpty(phoneNumber)) {
      return "*********";
    }
    int phoneNumberLength = phoneNumber.length;
    int lastXNumbers = min(phoneNumberLength, 4);
    int starsCount = (phoneNumberLength - lastXNumbers);
    String replacement = "*" * starsCount;
    String maskedPhoneNumber = phoneNumber.replaceRange(0, starsCount, replacement);
    return maskedPhoneNumber;
  }

  static String capitalize(String value) {
    if (value == null) {
      return null;
    }
    else if (value.length == 0) {
      return '';
    }
    else if (value.length == 1) {
      return value[0].toUpperCase();
    }
    else {
      return "${value[0].toUpperCase()}${value.substring(1).toLowerCase()}";
    }
  }
}

class AppCollection {
  static bool isCollectionNotEmpty(Iterable<Object> collection) {
    return collection != null && collection.isNotEmpty;
  }

  static bool isCollectionEmpty(Iterable<Object> collection) {
    return !isCollectionNotEmpty(collection);
  }
}

class AppVersion {

  static int compareVersions(String versionString1, String versionString2) {
    List<String> versionList1 = (versionString1 is String) ? versionString1.split('.') : [];
    List<String> versionList2 = (versionString2 is String) ? versionString2.split('.') : [];
    int minLen = min(versionList1.length, versionList2.length);
    for (int index = 0; index < minLen; index++) {
      String s1 = versionList1[index], s2 = versionList2[index];
      int n1 = int.tryParse(s1), n2 = int.tryParse(s2);
      int result = ((n1 != null) && (n2 != null)) ? n1.compareTo(n2) : s1.compareTo(s2);
      if (result != 0) {
        return result;
      }
    }
    if (versionList1.length < versionList2.length) {
      return -1;
    }
    else if (versionList1.length > versionList2.length) {
      return 1;
    }
    else {
      return 0;
    }
  }

  static bool matchVersions(String versionString1, String versionString2) {
    List<String> versionList1 = (versionString1 is String) ? versionString1.split('.') : [];
    List<String> versionList2 = (versionString2 is String) ? versionString2.split('.') : [];
    int minLen = min(versionList1.length, versionList2.length);
    for (int index = 0; index < minLen; index++) {
      String s1 = versionList1[index], s2 = versionList2[index];
      int n1 = int.tryParse(s1), n2 = int.tryParse(s2);
      int result = ((n1 != null) && (n2 != null)) ? n1.compareTo(n2) : s1.compareTo(s2);
      if (result != 0) {
        return false;
      }
    }
    return true;
  }

  static String majorVersion(String versionString, int versionsLength) {
    if (versionString is String) {
      List<String> versionList = versionString.split('.');
      if (versionsLength < versionList.length) {
        versionList = versionList.sublist(0, versionsLength);
      }
      return versionList.join('.');
    }
    return null;
  }
}

class AppUrl {
  
  static String getScheme(String url) {
    try {
      Uri uri = (url != null) ? Uri.parse(url) : null;
      return (uri != null) ? uri.scheme : null;
    } catch(e) {}
    return null;
  }

  static String getExt(String url) {
    try {
      Uri uri = (url != null) ? Uri.parse(url) : null;
      String path = (uri != null) ? uri.path : null;
      return (path != null) ? Path.extension(path) : null;
    } catch(e) {}
    return null;
  }

  static bool isPdf(String url) {
    return (getExt(url) == '.pdf');
  }

  static bool isWebScheme(String url) {
    String scheme = getScheme(url);
    return (scheme == 'http') || (scheme == 'https');
  }

  static bool launchInternal(String url) {
    return AppUrl.isWebScheme(url) && !(Platform.isAndroid && AppUrl.isPdf(url));
  }
}

class AppLocation {
  static final double defaultLocationLat = 40.096230;
  static final double defaultLocationLng = -88.235899;
  static final int defaultLocationRadiusInMeters = 1000;

  static double distance(double lat1, double lon1, double lat2, double lon2) {
    double theta = lon1 - lon2;
    double dist = sin(deg2rad(lat1)) 
                    * sin(deg2rad(lat2))
                    + cos(deg2rad(lat1))
                    * cos(deg2rad(lat2))
                    * cos(deg2rad(theta));
    dist = acos(dist);
    dist = rad2deg(dist);
    dist = dist * 60 * 1.1515;
    return (dist);
  }

  static double deg2rad(double deg) {
      return (deg * pi / 180.0);
  }

  static double rad2deg(double rad) {
      return (rad * 180.0 / pi);
  }  
}

class AppJson {

  static List<dynamic> encodeList(List items) {
    List<dynamic> result = new List();
    if (items != null && items.isNotEmpty) {
      items.forEach((item) {
        result.add(item.toJson());
      });
    }

    return result;
  }

  static List<String> castToStringList(List<dynamic> items) {
    if (items == null)
      return null;

    List<String> result = new List();
    if (items != null && items.isNotEmpty) {
      items.forEach((item) {
        result.add(item is String ? item : item.toString());
      });
    }

    return result;
  }

  static String encode(dynamic value) {
    String result;
    if (value != null) {
      try {
        result = json.encode(value);
      } catch (e) {
        Log.e(e?.toString());
      }
    }
    return result;
  }

  // TBD: Use everywhere decodeMap or decodeList to guard type cast
  static dynamic decode(String jsonString) {
    dynamic jsonContent;
    if (AppString.isStringNotEmpty(jsonString)) {
      try {
        jsonContent = json.decode(jsonString);
      } catch (e) {
        Log.e(e?.toString());
      }
    }
    return jsonContent;
  }

  static List<dynamic> decodeList(String jsonString) {
    try {
      return (decode(jsonString) as List)?.cast<dynamic>();
    } catch (e) {
      print(e?.toString());
      return null;
    }
  }

  static Map<String, dynamic> decodeMap(String jsonString) {
    try {
      return (decode(jsonString) as Map)?.cast<String, dynamic>();
    } catch (e) {
      print(e?.toString());
      return null;
    }
  }

  static String stringValue(dynamic value) {
    if (value is String) {
      return value;
    }
    else if (value != null) {
      try { return value.toString(); }
      catch(e) { print(e?.toString()); }
    }
    return null;
  }

  static int intValue(dynamic value) {
    return (value is int) ? value : null;
  }

  static bool boolValue(dynamic value) {
    return (value is bool) ? value : null;
  }

  static double doubleValue(dynamic value) {
    if (value is double) {
      return value;
    }
    else if (value is int) {
      return value.toDouble();
    }
    else if (value is String) {
      return double.tryParse(value);
    }
    else {
      return null;
    }
  }
}

class AppToast {
  static void show(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
      timeInSecForIosWeb: 3,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Styles().colors.blackTransparent06,
    );
  }
}

class AppAlert {
  static Future<bool> showDialogResult(
      BuildContext builderContext, String message) async {
    if(builderContext != null) {
      bool alertDismissed = await showDialog(
        context: builderContext,
        builder: (context) {
          return AlertDialog(
            content: Text(message),
            actions: <Widget>[
              FlatButton(
                  child: Text(Localization().getStringEx("dialog.ok.title", "OK")),
                  onPressed: () {
                    Analytics.instance.logAlert(text: message, selection: "Ok");
                    Navigator.pop(context, true);
                  }
              ) //return dismissed 'true'
            ],
          );
        },
      );
      return alertDismissed;
    }
    return true; // dismissed
  }

  static Future<bool> showCustomDialog(
    {BuildContext context, Widget contentWidget, List<Widget> actions, EdgeInsets contentPadding = const EdgeInsets.all(18), }) async {
    bool alertDismissed = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(content: contentWidget, actions: actions,contentPadding: contentPadding,);
      },
    );
    return alertDismissed;
  }

  static Future<bool> showOfflineMessage(BuildContext context, [String message]) async {
    return showDialog(context: context, builder: (context) {
      return AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(Localization().getStringEx("app.offline.message.title", "You appear to be offline"), style: TextStyle(fontSize: 18),),
          Container(height: AppString.isStringNotEmpty(message) ? 16 : 0),
          AppString.isStringNotEmpty(message) ? Text(message, textAlign: TextAlign.center,) : Container(),
        ],),
        actions: <Widget>[
          FlatButton(
              child: Text(Localization().getStringEx("dialog.ok.title", "OK")),
              onPressed: (){
                Analytics.instance.logAlert(text: message, selection: "OK");
                  Navigator.pop(context, true);
              }
          ) //return dismissed 'true'
        ],
      );
    },);

  }
}

class AppMapPathKey {
  static dynamic entry(Map<String, dynamic> map, dynamic key) {
    if ((map != null) && (key != null)) {
      if (key is String) {
        return _pathKeyEntry(map, key);
      }
      else if (key is List) {
        return _listKeyEntry(map, key);
      }
    }
    return null;
  }
  
  static dynamic _pathKeyEntry(Map<String, dynamic> map, String key) {
    String field;
    dynamic entry;
    int position, start = 0;
    Map<String, dynamic> source = map;

    while (0 <= (position = key.indexOf('.', start))) {
      field = key.substring(start, position);
      entry = source[field];
      if ((entry != null) && (entry is Map)) {
        source = entry;
        start = position + 1;
      }
      else {
        break;
      }
    }

    if (0 < start) {
      field = key.substring(start);
      return source[field];
    }
    else {
      return source[key];
    }
  }

  static dynamic _listKeyEntry(Map<String, dynamic> map, List keys) {
    dynamic entry;
    Map<String, dynamic> source = map;
    for (dynamic key in keys) {
      if (source == null) {
        return null;
      }

      entry = source[key];

      if (entry != null) {
        source = (entry is Map) ? entry : null;
      }
      else {
        return null;
      }
    }

    return source ?? entry;
  }

}

class AppSemantics {
    static void announceCheckBoxStateChange(BuildContext context, bool checked, String name){
      if(context!=null) {
        String message = (AppString.isStringNotEmpty(name)?name+", " :"")+
            (checked ?
              Localization().getStringEx("toggle_button.status.checked", "checked",) :
              Localization().getStringEx("toggle_button.status.unchecked", "unchecked"));

        context.findRenderObject().sendSemanticsEvent(AnnounceSemanticsEvent(message,TextDirection.ltr)); // !toggled because we announce before it got changed
      }
    }
}

class AppImage {
  static Map<String, String> getAuthImageHeaders() {
    Map<String, String> headers;
      String rokwireApiKey = Config().rokwireApiKey;
      if (AppString.isStringNotEmpty(rokwireApiKey)) {
        headers = Map();
        headers[Network.RokwireApiKey] = rokwireApiKey;
      }
    return headers;
  }

  static MemoryImage memoryImageWithBytes( Uint8List bytes){
    if(AppCollection.isCollectionNotEmpty(bytes)) {
      return MemoryImage(bytes);
    }
    return null;
  }
}

class AppDeviceOrientation {
  
  static DeviceOrientation fromStr(String value) {
    switch (value) {
      case 'portraitUp': return DeviceOrientation.portraitUp;
      case 'portraitDown': return DeviceOrientation.portraitDown;
      case 'landscapeLeft': return DeviceOrientation.landscapeLeft;
      case 'landscapeRight': return DeviceOrientation.landscapeRight;
    }
    return null;
  }

  static String toStr(DeviceOrientation value) {
      switch(value) {
        case DeviceOrientation.portraitUp: return "portraitUp";
        case DeviceOrientation.portraitDown: return "portraitDown";
        case DeviceOrientation.landscapeLeft: return "landscapeLeft";
        case DeviceOrientation.landscapeRight: return "landscapeRight";
      }
      return null;
  }

  static List<DeviceOrientation> fromStrList(List<dynamic> stringsList) {
    
    List<DeviceOrientation> orientationsList;
    if (stringsList != null) {
      orientationsList = List();
      for (dynamic string in stringsList) {
        if (string is String) {
          DeviceOrientation orientation = fromStr(string);
          if (orientation != null) {
            orientationsList.add(orientation);
          }
        }
      }
    }
    return orientationsList;
  }

  static List<String> toStrList(List<DeviceOrientation> orientationsList) {
    
    List<String> stringsList;
    if (orientationsList != null) {
      stringsList = List();
      for (DeviceOrientation orientation in orientationsList) {
        String orientationString = toStr(orientation);
        if (orientationString != null) {
          stringsList.add(orientationString);
        }
      }
    }
    return stringsList;
  }

}

class AppGeometry {

  static Size scaleSizeToFit(Size size, Size boundsSize) {
    double fitW = boundsSize.width;
    double fitH = boundsSize.height;
    double ratioW = (0.0 < boundsSize.width) ? (size.width / boundsSize.width) : double.maxFinite;
    double ratioH = (0.0 < boundsSize.height) ? (size.height / boundsSize.height) : double.maxFinite;
    if(ratioW < ratioH)
      fitW = (0.0 < size.height) ? (size.width * boundsSize.height / size.height) : boundsSize.width;
    else if(ratioH < ratioW)
      fitH = (0.0 < size.width) ? (size.height * boundsSize.width / size.width) : boundsSize.height;
    return Size(fitW, fitH);
  }

  static Size scaleSizeToFill(Size size, Size boundsSize) {
    double fitW = boundsSize.width;
    double fitH = boundsSize.height;
    double ratioW = (0.0 < boundsSize.width) ? (size.width / boundsSize.width) : double.maxFinite;
    double ratioH = (0.0 < boundsSize.height) ? (size.height / boundsSize.height) : double.maxFinite;
    if(ratioW < ratioH)
  		fitH = (0.0 < size.width) ? (size.height * boundsSize.width / size.width) : boundsSize.height;
    else if(ratioH < ratioW)
  		fitW = (0.0 < size.height) ? (size.width * boundsSize.height / size.height) : boundsSize.width;
    return Size(fitW, fitH);
  }
}