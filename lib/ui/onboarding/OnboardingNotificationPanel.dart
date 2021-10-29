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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:url_launcher/url_launcher.dart';

/*

"notification":{
  "id":"lorem.ipsum.1",
  "title":"Lorem Ipsum"
  "text":"Sed elit est, tincidunt quis porttitor nec, convallis eget turpis. Integer pulvinar, purus a mattis aliquam, mauris diam pellentesque est, nec laoreet nisi ligula pellentesque ante. Etiam lacinia aliquet nibh vel laoreet.",
  "can_close":true,
  "display_once":false,
  "buttons":[
    {"title":"Vivamus Aliquam", "url":"https://illinois.edu", "url~android":"market://details?id=edu.illinois.rokwire", "url~ios":"itms-apps://itunes.apple.com/us/app/apple-store/id1476075513"}
  ],
}
*/

class OnboardingNotificationPanel extends StatefulWidget {
  
  final Map<String, dynamic> notification;
  final void Function(Map<String, dynamic> notification) onClose;
  OnboardingNotificationPanel({Key key, this.notification, this.onClose})
      : super(key: key);

  @override
  _OnboardingNotificationPanelState createState() => _OnboardingNotificationPanelState();
}

class _OnboardingNotificationPanelState extends State<OnboardingNotificationPanel> {

  @override
  Widget build(BuildContext context) {
    bool canClose = AppJson.boolValue(_notificationEntry('can_close')) ?? false;

    return Scaffold(backgroundColor: Styles().colors.background, body:
      SafeArea(child:
        Stack(children: [
          Visibility(visible: canClose, child:
            Align(alignment: Alignment.topRight, child:
              Semantics(button: true, label: Localization().getStringEx("dialog.close.title", "Close"), child:
                InkWell(onTap: _onTapClose, child:
                  Padding(padding: (0 < MediaQuery.of(context).padding.top) ? EdgeInsets.only(right: MediaQuery.of(context).padding.top / 2) : EdgeInsets.only(top: 24, right: 24), child:
                    Container(width: 48, height: 48, alignment: Alignment.center, child:
                      Image.asset('images/close-blue.png', excludeFromSemantics: true,)
                    ),
                  ),
                ),
              ),          
            ),
          ),
          _buildContent(),
        ],),
      ),
    );
  }

  Widget _buildContent() {
    String title = _notificationText('title');
    bool titleIsHtml = title?.contains(RegExp(r'<>')) ?? false;
    
    String text = _notificationText('text');
    bool textIsHtml = text?.contains(RegExp(r'<>')) ?? false;
    
    List<dynamic> buttons = AppJson.listValue(_notificationEntry('buttons'));

    return Padding(padding: EdgeInsets.symmetric(horizontal: 32, vertical: 32), child:
      Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(flex: 1, child: Container()),
        AppString.isStringNotEmpty(title) ? 
          Padding(padding: EdgeInsets.only(bottom: 40), child:
            titleIsHtml ?
              Html(data: title ?? '',
                onLinkTap: (url) => _onTapLink(url),
                style: { "body": Style(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.extraBold, fontSize: FontSize(36), padding: EdgeInsets.zero, margin: EdgeInsets.zero), },) :
              Text(title ?? '', style: TextStyle(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.extraBold, fontSize: 36, ),),
          ) : Container(),
          AppString.isStringNotEmpty(text) ?
            Padding(padding: EdgeInsets.only(), child:
              textIsHtml ?
                Html(data: text ?? '',
                  onLinkTap: (url) => _onTapLink(url),
                  style: { "body": Style(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.medium, fontSize: FontSize(20), padding: EdgeInsets.zero, margin: EdgeInsets.zero), },) :
                Text(AppString.getDefaultEmptyString(value: text), style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.medium, fontSize: 20, ),),
            ) : Container(),
          _buildButtons(buttons),
        Expanded(flex: 2, child: Container()),
      ],),
    );
  }

  Widget _buildButtons(List<dynamic> buttonsJsonContent) {
    if (AppCollection.isCollectionEmpty(buttonsJsonContent)) {
      return Container();
    }
    List<Widget> buttons = [];
    for (Map<String, dynamic> buttonContent in buttonsJsonContent) {
      String title = _platformText(buttonContent, 'title') ;
      buttons.add(Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        RoundedButton(
          label: AppString.getDefaultEmptyString(value: title),
          padding: EdgeInsets.symmetric(horizontal: 14),
          textColor: Styles().colors.fillColorPrimary,
          borderColor: Styles().colors.fillColorSecondary,
          backgroundColor: Styles().colors.white,
          onTap: () => _onTapButton(buttonContent),
        ),],
      ));
    }
    return Padding(padding: EdgeInsets.only(top: 30), child:
      Wrap(runSpacing: 8, spacing: 16, children: buttons),
    );
  }

  static dynamic _platformEntry(Map<String, dynamic> json, String key, {String os}) {
    return (json != null) ? (json["$key~${os ?? Platform.operatingSystem.toLowerCase()}"] ?? json[key]) : null;
  }

  static String _platformText(Map<String, dynamic> json, String key, {String locale }) {
    return AppJson.stringValue(_platformEntry(json, "$key~${locale ?? Platform.localeName.toLowerCase()}") ?? _platformEntry(json, key));
  }

  dynamic _notificationEntry(String key) {
    return _platformEntry(widget.notification, key);
  }
  
  String _notificationText(String key) {
    return _platformText(widget.notification, key);
  }

  void _onTapClose() {
    Analytics.instance.logSelect(target: "OnboardingNotificationPanel: Close");
    if (widget.onClose != null) {
      widget.onClose(widget.notification);
    }
  }

  void _onTapButton(Map<String, dynamic> button) {
    String title = _platformText(button, 'title', locale: 'en');
    Analytics.instance.logSelect(target: "OnboardingNotificationPanel: $title");
    
    String url = AppJson.stringValue(_platformEntry(button, 'url'));
    if (AppString.isStringNotEmpty(url)) {
      launch(url);
    }
  }

  void _onTapLink(String url) {
    if (AppString.isStringNotEmpty(url)) {
      launch(url);
    }
  }
}
