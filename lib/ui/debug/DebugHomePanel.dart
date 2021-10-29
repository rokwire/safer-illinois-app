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

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:illinois/model/Organization.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Organizations.dart';
import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/ui/debug/DebugCreateEventPanel.dart';
import 'package:illinois/ui/debug/DebugDirectionsPanel.dart';
import 'package:illinois/ui/debug/DebugHealthKeysPanel.dart';
import 'package:illinois/ui/debug/DebugSymptomsReportPanel.dart';
import 'package:illinois/ui/debug/DebugContactTraceReportPanel.dart';
import 'package:illinois/ui/debug/DebugHttpProxyPanel.dart';
import 'package:illinois/ui/debug/DebugFirebaseMessagingPanel.dart';
import 'package:illinois/ui/debug/DebugHealthRulesPanel.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';

import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';

class DebugHomePanel extends StatefulWidget {
  @override
  _DebugHomePanelState createState() => _DebugHomePanelState();
}

class _DebugHomePanelState extends State<DebugHomePanel> implements NotificationsListener {

  List<Organization> _organizations;
  Organization _organization;
  bool _organizationProgress;

  String _environment;
  bool _switchingEnvironment;
  bool _removingHistory;

  @override
  void initState() {

    NotificationService().subscribe(this, [
      Organizations.notifyOrganizationChanged,
      Organizations.notifyEnvironmentChanged,
    ]);

    _organization = Organizations().organization; 
    _environment = Organizations().environment;

    setState(() {
      _organizationProgress = true;
    });
    Organizations().ensureOrganizations().then((List<Organization> organizations) {
      setState(() {
        _organizations = organizations;
        _organizationProgress = false;
      });
    });
    
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  String get _userDebugData{
    String userDataText = prettyPrintJson((UserProfile()?.data?.toJson()));
    String authUserText = prettyPrintJson(Auth()?.authUser?.toJson());
    String userData =  "Profile: " + (userDataText ?? "unknown") + "\n\n" +
        "Auth: " + (authUserText ?? "unknown");
    return userData;
  }

  @override
  Widget build(BuildContext context) {
    String userUuid = UserProfile().uuid;
    String pid = Storage().userPid;
    String firebaseProjectId = FirebaseMessaging().projectID;

    List<Widget> content = <Widget>[
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
    ];

    Widget organizations = _buildOrganizations();
    if (organizations != null) {
      content.addAll(<Widget>[
        Padding(padding: EdgeInsets.only(top: 5), child: Container(height: 1, color: Styles().colors.surfaceAccent)),
        organizations,
      ]);
    }
    
    Widget environments = _buildEnvironments();
    if (environments != null) {
      content.addAll(<Widget>[
        Padding(padding: EdgeInsets.only(top: 5), child: Container(height: 1, color: Styles().colors.surfaceAccent)),
        environments,
      ]);
    }

    if ((organizations != null) || (environments != null)) {
      content.add(
        Padding(padding: EdgeInsets.only(bottom: 10), child: Container(height: 1, color: Styles().colors.surfaceAccent)),
      );
    }

    content.addAll(<Widget>[
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: RoundedButton(
              label: "User Info",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onUserProfileInfoClicked(context))),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: RoundedButton(
              label: "Messaging",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onMessagingClicked())),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: RoundedButton(
              label: "Directions",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onTapDirections)),
      Visibility(
        visible: Organizations().isDevEnvironment,
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: RoundedButton(
                label: "Http Proxy",
                backgroundColor: Styles().colors.background,
                fontSize: 16.0,
                textColor: Styles().colors.fillColorPrimary,
                borderColor: Styles().colors.fillColorPrimary,
                onTap: _onTapHttpProxy)),
      ),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: RoundedButton(
              label: "Test Crash",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onTapTestCrash)),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: RoundedButton(
              label: "COVID-19 Keys",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onTapCovid19Keys)),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: RoundedButton(
              label: "COVID-19 Rules",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onTapCovid19Rules)),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: RoundedButton(
              label: "COVID-19 Create Event",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onTapCreateEvent)),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Stack(children: [
            RoundedButton(
              label: "COVID-19 Clear History",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onTapClearHistory),
            Visibility(visible:  _removingHistory == true, child:
              Padding(padding: EdgeInsets.symmetric(vertical: 12), child:
                Center(child: 
                  Container(width: 24, height: 24, child:
                    CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorPrimary)),
                  ),
                ),
              ),
            ),
            
          ],),),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: RoundedButton(
              label: "COVID-19 Report Symptoms",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onTapReportCovid19Symptoms)),
      Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: RoundedButton(
              label: "COVID-19 Create Exposure",
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorPrimary,
              onTap: _onTapTraceCovid19Exposure)),
      Padding(padding: EdgeInsets.only(top: 10), child: Container()),
    ]);

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
                  color: Styles().colors.background,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: content,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Organizations.notifyOrganizationChanged){
      setState(() {
        _organization = Organizations().organization;
      });
    }
    else if (name == Organizations.notifyEnvironmentChanged){
      setState(() {
        _environment = Organizations().environment;
      });
    }
  }

  // Helpers

  Function _onMessagingClicked() {
    return () {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugFirebaseMessagingPanel()));
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
                        color: Styles().colors.fillColorPrimary,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Container(width: 20,),
                            Expanded(
                              child: RoundedButton(
                                label: "Copy to clipboard",
                                borderColor: Styles().colors.fillColorSecondary,
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
                                      fontFamily: Styles().fontFamilies.medium,
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
                          child: Container(color: Styles().colors.background, child:Text(_userDebugData))
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
      Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugHealthKeysPanel()));
  }

  void _onTapCreateEvent() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugCreateEventPanel()));
  }

  void _onTapClearHistory() {
    if (_removingHistory != true) {
      showDialog(context: context, builder: (context) => _buildRemoveHistoryDialog(context));
    }
  }

  void _onTapReportCovid19Symptoms() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugSymptomsReportPanel()));
  }

  void _onTapTraceCovid19Exposure() {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugContactTraceReportPanel()));
  }

  void _onTapCovid19Rules(){
    Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugHealthRulesPanel()));
  }

  void _onTapTestCrash(){
    FirebaseCrashlytics.instance.crash();
  }

  void _onTapHttpProxy() {
    if(Organizations().isDevEnvironment) {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugHttpProxyPanel()));
    }
  }

  void _onTapDirections() {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => DebugDirectionsPanel()));
  }

  String prettyPrintJson(var input){
    if(input == null)
      return input;

    JsonEncoder encoder = JsonEncoder.withIndent('  ');
    var prettyString = encoder.convert(input);

    return prettyString;
  }

  //////////////////////////
  // Organizations

  Widget _buildOrganizations() {
    List<DropdownMenuItem<Organization>> organizations = <DropdownMenuItem<Organization>>[];
    if (_organizations != null) {
      for (Organization organization in _organizations) {
        organizations.add(DropdownMenuItem<Organization>(
          value: organization,
          child: Text(organization.name ?? '',
            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
          ),
        ));
      }
    }

    Widget content;
    double progressSize, progressHeight;
    String title = (_organization != null) ? ((_organization.name != null) ? _organization.name : "Unknown") : "Select organization...";
    if (1 < organizations.length) {
      content = Container(decoration: BoxDecoration(color: Styles().colors.white, border: Border.all(color: Colors.black, width: 1), borderRadius: BorderRadius.all(Radius.circular(4))), child: 
        Padding(padding: EdgeInsets.only(left: 12, right: 16), child: 
          DropdownButtonHideUnderline(child: 
            DropdownButton(
                icon: Image.asset('images/icon-down-orange.png', excludeFromSemantics: true,),
                isExpanded: true,
                style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.textBackground,),
                hint: Text(title, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
                items: organizations,
                onChanged: _onOrganizationSelected
            ),
          ),
        ),
      );
      progressHeight = 48; progressSize = 24;
    }
    else {
      content = Text(title, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),);
      progressHeight = progressSize = 16;
    }

    return Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(padding: EdgeInsets.only(bottom: 5), child:Text('Organization: ')),
          Stack(children: [
            content,
            Visibility(visible: (_organizationProgress == true), child: 
              Container(height: progressHeight, child:
                Align(alignment: Alignment.center, child:
                  SizedBox(height: progressSize, width: progressSize, child: 
                    CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), )
                  ),
                ),
              ),
            ),
          ],),
      ],),
    );
  }

  void _onOrganizationSelected(Organization organization) {
    if ((organization is Organization) && (organization?.id != _organization?.id) && (_organizationProgress != true) && (_switchingEnvironment != true)) {
      String currentOrg = _organization?.name;
      String newOrg = organization?.name;
      String message = "Are you sure you want to switch the current organization from $currentOrg to $newOrg?";
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          content: Text(message),
            actions: <Widget>[
              TextButton(child: Text("Yes"), onPressed: () { Navigator.pop(context, true); }),
              TextButton(child: Text("No"), onPressed: () { Navigator.pop(context, false); }),
            ]);
      }).then((result) {
        if (result == true) {
          _switchOrganization(organization);
        }
      });
    }
  }

  void _switchOrganization(Organization organization) {
    setState(() {
      _organizationProgress = true;
    });

    Organizations().setOrganization(organization).then((_) {
      setState(() {
        _organizationProgress = false;
      });
    });
  }

  //////////////////////////
  // Environments

  Widget _buildEnvironments() {
    List<DropdownMenuItem<String>> environments = <DropdownMenuItem<String>>[];
    if (Organizations().organization?.environments != null) {
      for (String environment in Organizations().organization.environments.keys) {
        environments.add(DropdownMenuItem<String>(
          value: environment,
          child: Text(environment,
            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
          ),
        ));
      }
    }

    Widget content; 
    double progressSize, progressHeight;
    if (1 < environments.length) {
      content = Container(decoration: BoxDecoration(color: Styles().colors.white, border: Border.all(color: Colors.black, width: 1), borderRadius: BorderRadius.all(Radius.circular(4))), child: 
        Padding(padding: EdgeInsets.only(left: 12, right: 16), child: 
          DropdownButtonHideUnderline(child: 
            DropdownButton(
                icon: Image.asset('images/icon-down-orange.png', excludeFromSemantics: true,),
                isExpanded: true,
                style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.textBackground,),
                hint: Text(_environment ?? "Select environment...", style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
                items: environments,
                onChanged: _onEnvironmentSelected
            ),
          ),
        ),
      );
      progressHeight = 48; progressSize = 24;
    }
    else {
      content = Text(_environment ?? "unknown", style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),);
      progressHeight = progressSize = 16;
    }

    return Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(padding: EdgeInsets.only(bottom: 5), child:Text('Environment: ')),
          Stack(children: [
            content,
            Visibility(visible: (_switchingEnvironment == true), child: 
              Container(height: progressHeight, child:
                Align(alignment: Alignment.center, child:
                  SizedBox(height: progressSize, width: progressSize, child: 
                    CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), )
                  ),
                ),
              ),
            ),
          ],),
      ],),
    );
  }

  void _onEnvironmentSelected(String environment) {
    if ((environment is String) && (environment != _environment) && (_organizationProgress != true) && (_switchingEnvironment != true)) {
      String currentEnv = _environment?.toUpperCase();
      String newEnv = environment?.toUpperCase();
      String message = "Are you sure you want to switch the application environment from $currentEnv to $newEnv?";
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          content: Text(message),
            actions: <Widget>[
              TextButton(child: Text("Yes"), onPressed: () { Navigator.pop(context, true); }),
              TextButton(child: Text("No"), onPressed: () { Navigator.pop(context, false); }),
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


  //////////////////////////
  // Delete History

  Widget _buildRemoveHistoryDialog(BuildContext context) {
    return StatefulBuilder(builder: (context, setState) {
      return ClipRRect(borderRadius: BorderRadius.all(Radius.circular(8)), child:
        Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),), child:
          Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Row(children: <Widget>[
              Expanded(child:
                Container(decoration: BoxDecoration(color: Styles().colors.fillColorPrimary, borderRadius: BorderRadius.vertical(top: Radius.circular(8)),), child:
                  Padding(padding: EdgeInsets.all(8), child:
                    Row(children: <Widget>[
                      Expanded(child:
                        Center(child:
                          Text("Clear COVID-19 event history?", style: TextStyle(fontSize: 20, color: Colors.white),),
                        ),
                      ),
                      GestureDetector(onTap: () => Navigator.pop(context), child:
                        Container(height: 30, width: 30, decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(15)), border: Border.all(color: Styles().colors.white, width: 2), ), child:
                          Center(child:
                            Text('\u00D7', style: TextStyle(fontSize: 24, color: Colors.white, ), ),
                          ),
                        ),
                      ),
                    ],),
                  ),
                ),
              ),
            ],),
            Container(height: 26,),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child:
              Text("This will permanently remove all COVID-19 event history.", textAlign: TextAlign.left, style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),),
            ),
            Container(height: 26,),
            Text("Are you sure?", textAlign: TextAlign.center, style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Colors.black), ),
            Container(height: 16,),
            Padding(padding: const EdgeInsets.all(8.0), child:
              Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                Expanded(child:
                  RoundedButton(
                    onTap: () { Navigator.pop(context); },
                    backgroundColor: Colors.transparent,
                    borderColor: Styles().colors.fillColorPrimary,
                    textColor: Styles().colors.fillColorPrimary,
                    label: 'No'),
                ),
                Container(width: 10,),
                Expanded(child:
                  RoundedButton(
                    onTap: () => _onClearHistory(),
                    backgroundColor: Styles().colors.fillColorSecondaryVariant,
                    borderColor: Styles().colors.fillColorSecondaryVariant,
                    textColor: Styles().colors.surface,
                    label: 'Yes',
                    height: 48,),
                ),
              ],),
            ),
          ],),
        ),
      );
    },);
  }

  void _onClearHistory() {
    Navigator.pop(context);

    if (_removingHistory != true) {
      setState(() { _removingHistory = true; });
      Health().clearHistory().then((bool result) {
        setState(() {_removingHistory = false;});
        AppAlert.showDialogResult(context, (result == true) ? 'COVID-19 event history successfully cleared.' : 'Failed to clear COVID-19 event history.');
      });
    }
  }
}
