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
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/DeepLink.dart';
import 'package:illinois/service/FlexUI.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/ui/health/Covid19HistoryPanel.dart';
import 'package:illinois/ui/health/Covid19InfoCenterPanel.dart';
import 'package:illinois/ui/health/Covid19StatusPanel.dart';
import 'package:illinois/ui/health/Covid19StatusUpdatePanel.dart';
import 'package:illinois/ui/widgets/PopupDialog.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/utils/Utils.dart';

class RootPanel extends StatefulWidget {

  @override
  _RootPanelState createState() => _RootPanelState();
}

class _RootPanelState extends State<RootPanel> with SingleTickerProviderStateMixin implements NotificationsListener {

  static const String HEALTH_STATUS_URI = 'edu.illinois.covid://covid.illinois.edu/health/status';

  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [
      FirebaseMessaging.notifyPopupMessage,
      FirebaseMessaging.notifyCovid19Notification,
      Localization.notifyStringsUpdated,
      Config.notifyEnvironmentChanged,
      FlexUI.notifyChanged,
      Health.notifyStatusUpdated,
      DeepLink.notifyUri,
    ]);

    Services().initUI();
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == FirebaseMessaging.notifyPopupMessage) {
      _onFirebasePopupMessage(param);
    }
    else if (name == Localization.notifyStringsUpdated) {
      setState(() { });
    }
    else if (name == FlexUI.notifyChanged) {
      setState(() { });
    }
    else if (name == Config.notifyEnvironmentChanged) {
      setState(() { });
    }
    else if (name == Health.notifyStatusUpdated) {
      _presentHealthStatusUpdate(param);
    }
    else if (name == FirebaseMessaging.notifyCovid19Notification) {
      _onFirebaseCovid19Notification(param);
    }
    else if(name == DeepLink.notifyUri) {
      _onDeeplinkUri(param);
    }
  }

  @override
  Widget build(BuildContext context) {
    Analytics().accessibilityState = MediaQuery.of(context).accessibleNavigation;

    return WillPopScope(
        child: Covid19InfoCenterPanel(),
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
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19HistoryPanel()));
    } else if(notificationType == 'status-changed'){
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19StatusPanel()));
    }
  }

  void _presentHealthStatusUpdate(Map<String, dynamic> params) {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19StatusUpdatePanel(status: params['status'], previousHealthStatus: params['lastHealthStatus'],)));
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
        Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19StatusPanel()));
      }
    }
  }
}
