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

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/DeepLink.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Organizations.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/ui/health/HealthHistoryPanel.dart';
import 'package:illinois/ui/health/HealthHomePanel.dart';
import 'package:illinois/ui/health/HealthStatusPanel.dart';
import 'package:illinois/ui/health/HealthStatusUpdatePanel.dart';
import 'package:illinois/ui/settings/SettingsPendingFamilyMemberPanel.dart';
import 'package:illinois/ui/widgets/PopupDialog.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/utils/Utils.dart';

class RootPanel extends StatefulWidget with AnalyticsPageAnonymous {

  @override
  _RootPanelState createState() => _RootPanelState();

  @override
  bool get analyticsPageAnonymous {
    return false;
  }
}

class _RootPanelState extends State<RootPanel> with SingleTickerProviderStateMixin implements NotificationsListener {

  static const String HEALTH_STATUS_URI = 'edu.illinois.covid://covid.illinois.edu/health/status';

  HealthFamilyMember _pendingFamilyMember;
  Set<String> _promptedPendingFamilyMembers = Set<String>();
  DateTime _pausedDateTime;

  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [
      AppLivecycle.notifyStateChanged,
      FirebaseMessaging.notifyForegroundMessage,
      FirebaseMessaging.notifyPopupMessage,
      FirebaseMessaging.notifyCovid19Notification,
      Localization.notifyStringsUpdated,
      Organizations.notifyOrganizationChanged,
      Organizations.notifyEnvironmentChanged,
      Health.notifyStatusUpdated,
      Health.notifyFamilyMembersChanged,
      Health.notifyCheckPendingFamilyMember,
      DeepLink.notifyUri,
    ]);

    Services().initUI();

    Health().refreshNone().then((_) => _checkForPendingFamilyMembers());
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == AppLivecycle.notifyStateChanged) {
      _onAppLivecycleStateChanged(param); 
    }
    else if (name == FirebaseMessaging.notifyForegroundMessage){
      _onFirebaseForegroundMessage(param);
    }
    else if (name == FirebaseMessaging.notifyPopupMessage) {
      _onFirebasePopupMessage(param);
    }
    else if (name == Localization.notifyStringsUpdated) {
      setState(() { });
    }
    else if (name == Organizations.notifyOrganizationChanged) {
      setState(() { });
    }
    else if (name == Organizations.notifyEnvironmentChanged) {
      setState(() { });
    }
    else if (name == Health.notifyStatusUpdated) {
      _presentHealthStatusUpdate();
    }
    else if (name == Health.notifyFamilyMembersChanged) {
      _checkForPendingFamilyMembers();
    }
    else if (name == Health.notifyCheckPendingFamilyMember) {
      _promptedPendingFamilyMembers.clear();
      _checkForPendingFamilyMembers();
    }
    else if (name == FirebaseMessaging.notifyCovid19Notification) {
      _onFirebaseCovid19Notification(param);
    }
    else if(name == DeepLink.notifyUri) {
      _onDeeplinkUri(param);
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
          _promptedPendingFamilyMembers.clear();
          Health().refreshNone().then((_) => _checkForPendingFamilyMembers());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics().accessibilityState = MediaQuery.of(context).accessibleNavigation;

    return WillPopScope(
        child: HealthHomePanel(),
        onWillPop: _onWillPop);
  }



  Future<bool> _onWillPop() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _buildExitDialog(context);
      },
    );
  }

  Widget _buildExitDialog(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    color: Styles().colors.fillColorPrimary,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          Localization().getStringEx("app.title", "Safer Illinois"),
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(height: 26,),
            Text(
              Localization().getStringEx(
                  "app.exit_dialog.message", "Are you sure you want to exit?"),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16,
                  color: Colors.black),
            ),
            Container(height: 26,),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  RoundedButton(
                      onTap: () {
                        Analytics.instance.logAlert(
                            text: "Exit", selection: "Yes");
                        Navigator.of(context).pop(true);
                      },
                      backgroundColor: Colors.transparent,
                      borderColor: Styles().colors.fillColorSecondary,
                      textColor: Styles().colors.fillColorPrimary,
                      label: Localization().getStringEx("dialog.yes.title", 'Yes')),
                  Container(height: 10,),
                  RoundedButton(
                      onTap: () {
                        Analytics.instance.logAlert(
                            text: "Exit", selection: "No");
                        Navigator.of(context).pop(false);
                      },
                      backgroundColor: Colors.transparent,
                      borderColor: Styles().colors.fillColorSecondary,
                      textColor: Styles().colors.fillColorPrimary,
                      label: Localization().getStringEx("dialog.no.title", 'No'))
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onFirebaseForegroundMessage(Map<String, dynamic> content) {
    String body = content["body"];
    Function completion = content["onComplete"];
    AppAlert.showDialogResult(context, body).then((value){
      if(completion != null){
        completion();
      }
    });
  }

  void _onFirebasePopupMessage(Map<String, dynamic> content) {
    String displayText = content["display_text"];
    String positiveButtonText = content["positive_button_text"];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopupDialog(displayText: displayText, positiveButtonText: positiveButtonText);
      },
    );
  }

  Future<void> _onFirebaseCovid19Notification(Map<String, dynamic> notification) async {
    /*notification = {
      "type": "health.covid19.notification",
      "health.covid19.notification.type": "process-pending-tests",
    }*/

    String notificationType = AppJson.stringValue(notification['health.covid19.notification.type']);
    if (notificationType == 'process-pending-tests') {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => HealthHistoryPanel()));
    } else if(notificationType == 'status-changed'){
      Navigator.push(context, CupertinoPageRoute(builder: (context) => HealthStatusPanel()));
    }
  }

  void _presentHealthStatusUpdate() {
    String oldStatusCode = Health().previousStatus?.blob?.code;
    String newStatusCode = Health().status?.blob?.code;
    if ((oldStatusCode != null) && (newStatusCode != null) && (oldStatusCode != newStatusCode)) {
      Timer(Duration(milliseconds: 100), () {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => HealthStatusUpdatePanel(status: Health().status, previousStatusCode: oldStatusCode,)));
      });
    }
  }

  void _checkForPendingFamilyMembers() {
    _processPendingFamilyMember(Health().pendingFamilyMember);
  }

  void _processPendingFamilyMember(HealthFamilyMember pendingFamilyMember) {
    if ((_pendingFamilyMember == null) && (pendingFamilyMember != null) && !_promptedPendingFamilyMembers.contains(pendingFamilyMember.id)) {
      _pendingFamilyMember = pendingFamilyMember;
      _promptedPendingFamilyMembers.add(pendingFamilyMember.id);
      Navigator.push(context, PageRouteBuilder(opaque: false, pageBuilder: (context, _, __) => SettingsPendingFamilyMemberPanel(familyMember: _pendingFamilyMember))).then((_) {
        _pendingFamilyMember = null;
        
        HealthFamilyMember nextPendingFamilyMember = Health().pendingFamilyMember;
        if ((nextPendingFamilyMember != null) && (nextPendingFamilyMember != pendingFamilyMember)) {
          _processPendingFamilyMember(nextPendingFamilyMember);
        }
      });
    }
  }

  void _onDeeplinkUri(Uri uri) {
    if (uri != null) {
      Uri healthStatusUri;
      try { healthStatusUri = Uri.parse(HEALTH_STATUS_URI); }
      catch(e) { print(e?.toString()); }

      if ((healthStatusUri != null) &&
          (healthStatusUri.scheme == uri.scheme) &&
          (healthStatusUri.authority == uri.authority) &&
          (healthStatusUri.path == uri.path))
      {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => HealthStatusPanel()));
      }
    }
  }
}
