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

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Organizations.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/ui/health/debug/Covid19DebugActionPanel.dart';
import 'package:illinois/ui/health/debug/Covid19DebugCreateEventPanel.dart';
import 'package:illinois/ui/health/debug/Covid19DebugExposureLogsPanel.dart';
import 'package:illinois/ui/health/debug/Covid19DebugExposurePanel.dart';
import 'package:illinois/ui/health/debug/Covid19DebugKeysPanel.dart';
import 'package:illinois/ui/health/debug/Covid19DebugSymptomsPanel.dart';
import 'package:illinois/ui/health/debug/Covid19DebugPendingEventsPanel.dart';
import 'package:illinois/ui/health/debug/Covid19DebugTraceContactPanel.dart';
import 'package:illinois/ui/settings/debug/HttpProxySettingsPanel.dart';
import 'package:illinois/ui/settings/debug/SettingsDebugMessagingPanel.dart';
import 'package:illinois/ui/health/debug/Covid19DebugRulesPanel.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';

import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';

class SettingsDebugPanel extends StatefulWidget {
  @override
  _SettingsDebugPanelState createState() => _SettingsDebugPanelState();
}

class _SettingsDebugPanelState extends State<SettingsDebugPanel> implements NotificationsListener {

  bool _switchingEnvironment;
  String _environment;

  @override
  void initState() {

    NotificationService().subscribe(this, [
      Organizations.notifyEnvironmentChanged,
    ]);

    _environment = Organizations().environment;
    
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  String get _userDebugData{
    String userDataText = prettyPrintJson((User()?.data?.toJson()));
    String authInfoText = prettyPrintJson(Auth()?.authInfo?.toJson());
    String userData =  "UserData: " + (userDataText ?? "unknown") + "\n\n" +
        "AuthInfo: " + (authInfoText ?? "unknown");
    return userData;
  }

  @override
  Widget build(BuildContext context) {
    String userUuid = User().uuid;
    String pid = Storage().userPid;
    String firebaseProjectId = FirebaseMessaging().projectID;
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(
          Localization().getStringEx("panel.debug.header.title", "Debug"),
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: SafeArea(
                child: Container(
                  color: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(padding: EdgeInsets.only(top: 4), child: Container()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        child: Text(AppString.isStringNotEmpty(userUuid) ? 'Uuid: $userUuid' : "unknown uuid"),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        child: Text(AppString.isStringNotEmpty(pid) ? 'PID: $pid' : "unknown pid"),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        child: Text('Firebase: $firebaseProjectId'),
                      ),
                      
                      Padding(padding: EdgeInsets.only(top: 5), child: Container(height: 1, color: (Styles().colors?.surfaceAccent ?? UiColors.fromHex('#DADDE1')))),
                      
                      Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16), child:
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Padding(padding: EdgeInsets.only(bottom: 5), child:Text('Config Environment: ')),
                            Stack(children: [
                              Container(decoration: BoxDecoration(color: Styles().colors?.white ?? UiColors.fromHex('#FFFFFF'), border: Border.all(color: Colors.black, width: 1), borderRadius: BorderRadius.all(Radius.circular(4))), child: 
                                Padding(padding: EdgeInsets.only(left: 12, right: 16), child: 
                                  DropdownButtonHideUnderline(child: 
                                    DropdownButton(
                                        icon: Image.asset('images/icon-down-orange.png', excludeFromSemantics: true,),
                                        isExpanded: true,
                                        style: TextStyle(fontFamily: (Styles().fontFamilies?.bold ?? 'ProximaNovaBold'), fontSize: 16, color: (Styles().colors?.textBackground ?? UiColors.fromHex('#404040')),),
                                        hint: Text(_environment ?? "Select environment...", style: TextStyle(fontFamily: (Styles().fontFamilies?.regular ?? 'ProximaNovaRegular'), fontSize: 16, color: (Styles().colors?.textBackground ?? UiColors.fromHex('#404040')),),),
                                        items: _dropdownEnvironments,
                                        onChanged: _onEnvironmentSelected
                                    ),
                                  ),
                                ),
                              ),
                              Visibility(visible: (_switchingEnvironment == true), child: 
                                Container(height: 48, child:
                                  Align(alignment: Alignment.center, child:
                                    SizedBox(height: 24, width: 24, child: 
                                      CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>((Styles().colors?.fillColorSecondary ?? UiColors.fromHex('#E84A27'))), )
                                    ),
                                  ),
                                ),
                              ),
                            ],),
                        ],),
                      ),
                      Padding(padding: EdgeInsets.only(bottom: 10), child: Container(height: 1, color: (Styles().colors?.surfaceAccent ?? UiColors.fromHex('#DADDE1')))),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "Messaging",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onMessagingClicked())),
                      Visibility(
                        visible: true,
                        child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            child: RoundedButton(
                                label: "User Profile Info",
                                backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                                fontSize: 16.0,
                                textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                                borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                                onTap: _onUserProfileInfoClicked(context))),
                      ),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "COVID-19: Keys",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onTapCovid19Keys)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "COVID-19 Rules",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onTapCovid19Rules)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "COVID-19 Create Event",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onTapCreateCovid19Event)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "COVID-19 Pending Events",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onTapCovid19PendingEvents)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "COVID-19 Trace Contact",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onTapTraceCovid19Contact)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "COVID-19 Report Symptoms",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onTapReportCovid19Symptoms)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "COVID-19 Create Action",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onTapCreateCovid19Action)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "COVID-19 Exposures",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onTapCovid19Exposures)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: RoundedButton(
                              label: "COVID-19 Exposure Logs",
                              backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                              fontSize: 16.0,
                              textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                              onTap: _onTapCovid19ExposureLogs)),
                      Padding(padding: EdgeInsets.only(top: 5), child: Container()),
                      Visibility(
                        visible: Organizations().isDevEnvironment,
                        child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            child: RoundedButton(
                                label: "Http Proxy",
                                backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
                                fontSize: 16.0,
                                textColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                                borderColor: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                                onTap: _onTapHttpProxy)),
                      ),
                      Padding(padding: EdgeInsets.only(top: 5), child: Container()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')),
    );
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Organizations.notifyEnvironmentChanged){
      setState(() {
        _environment = Organizations().environment;
      });
    }
  }

  // Helpers

  Function _onMessagingClicked() {
    return () {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsDebugMessagingPanel()));
    };
  }

  Function _onUserProfileInfoClicked(BuildContext context) {
    return () {
      showDialog(
          context: context,
          builder: (_) => Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
            child:
            Dialog(
              //backgroundColor: Color(0x00ffffff),
                child:Container(
                  child: Column(
                    children: <Widget>[
                      Container(
                        color: (Styles().colors?.fillColorPrimary ?? UiColors.fromHex('#002855')),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Container(width: 20,),
                            Expanded(
                              child: RoundedButton(
                                label: "Copy to clipboard",
                                borderColor: (Styles().colors?.fillColorSecondary ?? UiColors.fromHex('#E84A27')),
                                onTap: _onTapCopyToClipboard,
                              ),
                            ),
                            Container(width: 20,),
                            GestureDetector(
                              onTap:  ()=>Navigator.of(context).pop(),
                              child: Padding(
                                padding: EdgeInsets.only(right: 10, top: 10),
                                child: Text('\u00D7',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: (Styles().fontFamilies?.medium ?? 'ProximaNovaMedium'),
                                      fontSize: 50
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container( child:
                            SingleChildScrollView(
                          child: Container(color: (Styles().colors?.background ?? UiColors.fromHex('F5F5F5')), child:Text(_userDebugData))
                        )
                        )
                      )
                    ]
                  )
                )
            )
          )
      );
    };
  }

  void _onTapCopyToClipboard(){
    Clipboard.setData(ClipboardData(text:_userDebugData)).then((_){
      AppToast.show("User data has been copied to the clipboard!");
    });
  }

  void _onTapCovid19Keys() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19DebugKeysPanel()));
  }

  void _onTapCreateCovid19Event() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19DebugCreateEventPanel()));
  }

  void _onTapCovid19PendingEvents() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19DebugPendingEventsPanel()));
  }

  void _onTapTraceCovid19Contact() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19DebugTraceContactPanel()));
  }

  void _onTapReportCovid19Symptoms() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19DebugSymptomsPanel()));
  }

  void _onTapCreateCovid19Action() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19DebugActionPanel()));
  }

  void _onTapCovid19Exposures() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19DebugExposurePanel()));
  }

  void _onTapCovid19ExposureLogs() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19DebugExposureLogsPanel()));
  }

  void _onTapCovid19Rules(){
    Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19DebugRulesPanel()));
  }

  String prettyPrintJson(var input){
    if(input == null)
      return input;

    JsonEncoder encoder = JsonEncoder.withIndent('  ');
    var prettyString = encoder.convert(input);

    return prettyString;
  }

  List<DropdownMenuItem<String>> get _dropdownEnvironments {
    List<DropdownMenuItem<String>> environments = <DropdownMenuItem<String>>[];
    if (Organizations().organization.environments != null) {
      for (String environment in Organizations().organization.environments.keys) {
        environments.add(DropdownMenuItem<String>(
          value: environment,
          child: Text(environment,
            style: TextStyle(fontFamily: (Styles().fontFamilies?.regular ?? 'ProximaNovaRegular'), fontSize: 16, color: (Styles().colors?.textBackground ?? UiColors.fromHex('#404040')),),
          ),
        ));
      }
    }
    return environments;
  }

  void _onEnvironmentSelected(String environment) {
    if ((environment is String) && (environment != _environment) && (_switchingEnvironment != true)) {
      String currentEnv = _environment?.toUpperCase();
      String newEnv = environment?.toUpperCase();
      String message = "Are you sure you want to switch the application environment from $currentEnv to $newEnv?";
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          content: Text(message),
            actions: <Widget>[
              FlatButton(child: Text("Yes"), onPressed: () { Navigator.pop(context, true); }),
              FlatButton(child: Text("No"), onPressed: () { Navigator.pop(context, false); }),
            ]);
      }).then((result) {
        if (result == true) {
          _switchEnvirnment(environment);
        }
      });
    }
  }

  void _switchEnvirnment(String configEnvironment) {
    setState(() {
      _switchingEnvironment = true;
    });

    Organizations().setEnvironment(configEnvironment).then((_) {
      setState(() {
        _switchingEnvironment = false;
      });
    });
  }

  void _onTapHttpProxy() {
    if(Organizations().isDevEnvironment) {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => HttpProxySettingsPanel()));
    }
  }
}
