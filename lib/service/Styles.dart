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

import 'dart:io';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

class Styles extends Service implements NotificationsListener{
  static const String notifyChanged    = "edu.illinois.rokwire.styles.changed";
  static const String _assetsName      = "styles.json";

  File      _cacheFile;
  DateTime  _pausedDateTime;

  Map<String, dynamic> _stylesData;
  
  UiColors _colors;
  UiColors get colors => _colors;

  UiFontFamilies _fontFamilies;
  UiFontFamilies get fontFamilies => _fontFamilies;
  
  Map<String, TextStyle> _textStylesMap;
  UiStyles _uiStyles;
  UiStyles get uiStyles => _uiStyles;

  static final Styles _logic = Styles._internal();

  factory Styles() {
    return _logic;
  }

  Styles._internal();

  // Initialization

  @override
  void createService() {
    NotificationService().subscribe(this, AppLivecycle.notifyStateChanged);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {
    await _getCacheFile();
    await _loadFromCache();
    if (_stylesData == null) {
      await _loadFromAssets();
    }
    _loadFromNet();
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Config()]);
  }

  // Public

  TextStyle getTextStyle(String key){
    dynamic style = _textStylesMap[key];
    return (style is TextStyle) ? style : null;
  }

  // Private

  Future<void> _getCacheFile() async {
    Directory assetsDir = Config().assetsCacheDir;
    if ((assetsDir != null) && !await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }
    String cacheFilePath = (assetsDir != null) ? join(assetsDir.path, _assetsName) : null;
    _cacheFile = (cacheFilePath != null) ? File(cacheFilePath) : null;
  }

  Future<void> _loadFromCache() async {
    try {
      String stylesContent = ((_cacheFile != null) && await _cacheFile.exists()) ? await _cacheFile.readAsString() : null;
      await _applyContent(stylesContent);
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _loadFromAssets() async {
    try {
      String stylesContent = await rootBundle.loadString('assets/$_assetsName');
      await _applyContent(stylesContent);
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _loadFromNet() async {
    try {
      http.Response response = (Config().assetsUrl != null) ? await Network().get("${Config().assetsUrl}/$_assetsName") : null;
      String stylesContent =  ((response != null) && (response.statusCode == 200)) ? response.body : null;
      if(stylesContent != null) {
        await _applyContent(stylesContent, cacheContent: true, notifyUpdate: true);
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _applyContent(String stylesContent, {bool cacheContent = false, bool notifyUpdate = false}) async {
    try {
      Map<String, dynamic> styles = (stylesContent != null) ? AppJson.decode(stylesContent) : null;
      if ((styles != null) && styles.isNotEmpty) {
        if ((_stylesData == null) || !DeepCollectionEquality().equals(_stylesData, styles)) {
          _stylesData = styles;
          if ((_cacheFile != null) && cacheContent) {
            await _cacheFile.writeAsString(stylesContent, flush: true);
          }
        }
      }
      _buildData();
      if (notifyUpdate) {
        NotificationService().notify(notifyChanged, null);
      }
    } catch (e) {
      print(e.toString());
    }
  }

  void _buildData(){
    _buildColorsData();
    _buildFontFamiliesData();
    _buildStylesData();
  }

  void _buildColorsData(){
    if(_stylesData != null) {
      dynamic colorsData = _stylesData["color"];
      Map<String, Color> colors = Map<String, Color>();
      if(colorsData is Map){
        colorsData.forEach((dynamic key, dynamic value){
          if(key is String && value is String){
            if(value.startsWith("#")){
              colors[key] = UiColors.fromHex(value);
            } else if(value.contains(".")){
              colors[key] = UiColors.fromHex(AppMapPathKey.entry(_stylesData, value));
            }
          }
        });
      }
      _colors = UiColors(colors);
    }
  }

  void _buildFontFamiliesData(){
    if(_stylesData != null) {
      dynamic familyData = _stylesData["font_family"];
      if(familyData is Map) {
        Map<String, String> castedData = familyData.cast();
        _fontFamilies = UiFontFamilies(castedData);
      }
    }
  }

  void _buildStylesData(){
    if(_stylesData != null) {
      dynamic stylesData = _stylesData["text_style"];
      Map<String, TextStyle> styles = Map<String, TextStyle>();
      if(stylesData is Map){
        stylesData.forEach((dynamic key, dynamic value){
          if(key is String && value is Map){
            double fontSize = value['size'];
            String fontFamily = value['font_family'];
            String rawColor = value['color'];
            Color color = rawColor != null ? (rawColor.startsWith("#") ? UiColors.fromHex(rawColor) : colors.getColor(rawColor)) : null;
            double letterSpacing = value['letter_spacing']; // Not mandatory
            styles[key] = TextStyle(fontFamily: fontFamily, fontSize: fontSize, color: color, letterSpacing: letterSpacing, );
          }
        });
      }
      _textStylesMap = styles;
    }
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == AppLivecycle.notifyStateChanged) {
      _onAppLivecycleStateChanged(param);
    }
  }

  void _onAppLivecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
    }
    else if (state == AppLifecycleState.resumed) {
      if (_pausedDateTime != null) {
        Duration pausedDuration = DateTime.now().difference(_pausedDateTime);
        if (Config().refreshTimeout < pausedDuration.inSeconds) {
          _loadFromNet();
        }
      }
    }
  }
}

class UiColors {

  final Map<String,Color> _colorMap;

  UiColors(this._colorMap);

  Color get fillColorPrimary                   => _colorMap['fillColorPrimary'];
  Color get fillColorPrimaryTransparent03      => _colorMap['fillColorPrimaryTransparent03'];
  Color get fillColorPrimaryTransparent05      => _colorMap['fillColorPrimaryTransparent05'];
  Color get fillColorPrimaryTransparent09      => _colorMap['fillColorPrimaryTransparent09'];
  Color get fillColorPrimaryTransparent015     => _colorMap['fillColorPrimaryTransparent015'];
  Color get fillColorPrimaryTransparent80      => _colorMap['fillColorPrimaryTransparent80'];
  Color get textColorPrimary                   => _colorMap['textColorPrimary'];
  Color get fillColorPrimaryVariant            => _colorMap['fillColorPrimaryVariant'];
  Color get textColorPrimaryVariant            => _colorMap['textColorPrimaryVariant'];
  Color get fillColorSecondary                 => _colorMap['fillColorSecondary'];
  Color get fillColorSecondaryTransparent05    => _colorMap['fillColorSecondaryTransparent05'];
  Color get textColorSecondary                 => _colorMap['textColorSecondary'];
  Color get fillColorSecondaryVariant          => _colorMap['fillColorSecondaryVariant'];
  Color get textColorSecondaryVariant          => _colorMap['textColorSecondaryVariant'];

  Color get surface                    => _colorMap['surface'];
  Color get textSurface                => _colorMap['textSurface'];
  Color get surfaceAccent              => _colorMap['surfaceAccent'];
  Color get textSurfaceAccent          => _colorMap['textSurfaceAccent'];
  Color get background                 => _colorMap['background'];
  Color get textBackground             => _colorMap['textBackground'];
  Color get backgroundVariant          => _colorMap['backgroundVariant'];
  Color get textBackgroundVariant      => _colorMap['textBackgroundVariant'];

  Color get accentColor1               => _colorMap['accentColor1'];
  Color get accentColor2               => _colorMap['accentColor2'];
  Color get accentColor3               => _colorMap['accentColor3'];

  Color get iconColor                  => _colorMap['iconColor'];

  Color get eventColor                 => _colorMap['eventColor'];
  Color get diningColor                => _colorMap['diningColor'];
  Color get placeColor                 => _colorMap['placeColor'];

  Color get white                      => _colorMap['white'];
  Color get whiteTransparent01         => _colorMap['whiteTransparent01'];
  Color get whiteTransparent06         => _colorMap['whiteTransparent06'];
  Color get blackTransparent06         => _colorMap['blackTransparent06'];
  Color get blackTransparent018        => _colorMap['blackTransparent018'];

  Color get mediumGray                 => _colorMap['mediumGray'];
  Color get mediumGray1                => _colorMap['mediumGray1'];
  Color get mediumGray2                => _colorMap['mediumGray2'];
  Color get lightGray                  => _colorMap['lightGray'];
  Color get disabledTextColor          => _colorMap['disabledTextColor'];
  Color get disabledTextColorTwo       => _colorMap['disabledTextColorTwo'];

  Color get healthStatusGreen          => _colorMap['healthStatusGreen'];
  Color get healthStatusYellow         => _colorMap['healthStatusYellow'];
  Color get healthStatusOrange         => _colorMap['healthStatusOrange'];
  Color get healthStatusRed            => _colorMap['healthStatusRed'];

  Color get lightBlue                  => _colorMap['lightBlue'];

  Color get healthLocationWaitTimeColorRed        => _colorMap['healthLocationWaitTimeColorRed'];
  Color get healthLocationWaitTimeColorYellow     => _colorMap['healthLocationWaitTimeColorYellow'];
  Color get healthLocationWaitTimeColorGreen      => _colorMap['healthLocationWaitTimeColorGreen'];
  Color get healthLocationWaitTimeColorGrey       => _colorMap['healthLocationWaitTimeColorGrey'];

  Color getColor(String key){
    dynamic color = _colorMap[key];
    return (color is Color) ? color : null;
  }

  static Color fromHex(String value) {
    if (value != null) {
      final buffer = StringBuffer();
      if (value.length == 6 || value.length == 7) {
        buffer.write('ff');
      }
      buffer.write(value.replaceFirst('#', ''));

      try { return Color(int.parse(buffer.toString(), radix: 16)); }
      on Exception catch (e) { print(e.toString()); }
    }
    return null;
  }

  static String toHex(Color value, {bool leadingHashSign = true}) {
    if (value != null) {
      return "${leadingHashSign ? '#' : ''}" +
          "${value.alpha.toRadixString(16)}" +
          "${value.red.toRadixString(16)}" +
          "${value.green.toRadixString(16)}" +
          "${value.blue.toRadixString(16)}";
    }
    return null;
  }
}

class UiFontFamilies{
  final Map<String, String> _familyMap;
  UiFontFamilies(this._familyMap);

  String get black        => _familyMap["black"];
  String get blackIt      => _familyMap["black_italic"];
  String get bold         => _familyMap["bold"];
  String get boldIt       => _familyMap["bold_italic"];
  String get extraBold    => _familyMap["extra_bold"];
  String get extraBoldIt  => _familyMap["extra_bold_italic"];
  String get light        => _familyMap["light"];
  String get lightIt      => _familyMap["light_italic"];
  String get medium       => _familyMap["medium"];
  String get mediumIt     => _familyMap["medium_italic"];
  String get regular      => _familyMap["regular"];
  String get regularIt    => _familyMap["regular_italic"];
  String get semiBold     => _familyMap["semi_bold"];
  String get semiBoldIt   => _familyMap["semi_bold_italic"];
  String get thin         => _familyMap["thin"];
  String get thinIt       => _familyMap["thin_italic"];
}

class UiStyles {

  final Map<String, TextStyle> _styleMap;
  UiStyles(this._styleMap);

  TextStyle get headerBar          => _styleMap['header_bar'];
}