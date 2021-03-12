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

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/BluetoothServices.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/ScalableScrollView.dart';
import 'package:illinois/ui/widgets/SwipeDetector.dart';
import 'package:illinois/ui/widgets/TrianglePainter.dart';

class OnboardingAuthBluetoothPanel extends StatefulWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;

  OnboardingAuthBluetoothPanel({this.onboardingContext});

  _OnboardingAuthBluetoothPanelState createState() => _OnboardingAuthBluetoothPanelState();

  @override
  bool get onboardingCanDisplay {
    return Platform.isIOS && (BluetoothServices().status != BluetoothStatus.PermissionAllowed);
  }
}

class _OnboardingAuthBluetoothPanelState extends State<OnboardingAuthBluetoothPanel> {

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String notRightNow = Localization().getStringEx(
        'panel.onboarding.bluetooth.button.dont_allow.title',
        'Not right now');
    return Scaffold(
        backgroundColor: Styles().colors.background,
        body: SwipeDetector(
            onSwipeLeft: () => _goNext(),
            onSwipeRight: () => _goBack(),
            child:
            ScalableScrollView(
                scrollableChild: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Stack(
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Container(height: 90,color: Styles().colors.surface,),
                            CustomPaint(
                              painter: InvertedTrianglePainter(painterColor: Styles().colors.surface, left : true, ),
                              child: Container(
                                height: 67,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(child: Image.asset('images/background-onboarding-squares-dark.png', excludeFromSemantics: true,fit: BoxFit.fitWidth,)),
                              ],
                            ),
                          ],
                        ),
                        Container(margin: EdgeInsets.only(top: 80, bottom: 20),child: Center(child: Image.asset('images/enable-bluetooth-header.png', excludeFromSemantics: true,))),
                        Align(
                          alignment: Alignment.topLeft,
                          child: OnboardingBackButton(padding: EdgeInsets.only(top: 24, left:12.5, right: 20, bottom: 20), onTap: () => _goBack()),
                        )
                      ],
                    ),
                    Container(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
                            child:Text(Localization().getStringEx('panel.onboarding.bluetooth.label.title', "Enable Bluetooth"),
                              textAlign: TextAlign.left,
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color:Styles().colors.fillColorPrimary),
                            ))
                    ),
                    Container(height: 12, ),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Text(
                            Localization().getStringEx(
                                'panel.onboarding.bluetooth.label.description',
                                "Use Bluetooth to alert you to potential exposure to COVID-19."),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: Styles().fontFamilies.regular,
                                fontSize: 20,
                                color: Styles().colors.fillColorPrimary),
                          ),
                        ))
                ]),
                bottomNotScrollableWidget:
                Container(color: Styles().colors.white, child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16,vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ScalableRoundedButton(
                        label: Localization().getStringEx(
                            'panel.onboarding.bluetooth.button.allow.title',
                            'Continue'),
                        hint: Localization().getStringEx(
                            'panel.onboarding.bluetooth.button.allow.hint',
                            ''),
                        borderColor: Styles().colors.lightBlue,
                        backgroundColor: Styles().colors.white,
                        textColor: Styles().colors.fillColorPrimary,
                        onTap: () => _requestBluetooth(context),
                      ),
                      GestureDetector(
                        onTap: () {
                          Analytics.instance.logSelect(target: 'Not right now') ;
                          return  _goNext();
                        },
                        child: Semantics(
                            label: notRightNow,
                            hint: Localization().getStringEx(
                                'panel.onboarding.bluetooth.button.dont_allow.hint',
                                ''),
                            button: true,
                            excludeSemantics: true,
                            child: Padding(
                                padding: EdgeInsets.only(top: 15),
                                child: Text(
                                  notRightNow,
                                  style: TextStyle(
                                      fontFamily: Styles().fontFamilies.medium,
                                      fontSize: 16,
                                      color: Styles().colors.fillColorPrimary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Styles().colors.lightBlue,
                                      decorationThickness: 1,
                                      decorationStyle:
                                      TextDecorationStyle.solid),
                                ))),
                      )
                    ],
                  ),
                )
            ))));
  }

  void _requestBluetooth(BuildContext context) {

    Analytics.instance.logSelect(target: 'Enable Bluetooth') ;

    BluetoothStatus authStatus = BluetoothServices().status;
    if (authStatus == BluetoothStatus.PermissionNotDetermined) {
      BluetoothServices().requestStatus().then((_){
        _goNext();
      });
    }
    else if (authStatus == BluetoothStatus.PermissionDenied) {
      String message = Localization().getStringEx('panel.onboarding.bluetooth.label.access_denied', 'You have already denied access to this app.');
      showDialog(context: context, builder: (context) => _buildDialogWidget(context, message: message, pushNext: false));
    }
    else if (authStatus == BluetoothStatus.PermissionAllowed) {
      String message = Localization().getStringEx('panel.onboarding.bluetooth.label.access_granted', 'You have already granted access to this app.');
      showDialog(context: context, builder: (context) => _buildDialogWidget(context, message: message, pushNext: true));
    }
  }

  Widget _buildDialogWidget(BuildContext context, {String message, bool pushNext}) {
    String okTitle = Localization().getStringEx('dialog.ok.title', 'OK');
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              Localization().getStringEx('app.title', 'Safer Illinois'),
              style: TextStyle(fontSize: 24, color: Colors.black),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Text(
                message,
                textAlign: TextAlign.left,
                style: TextStyle(
                    fontFamily: Styles().fontFamilies.medium,
                    fontSize: 16,
                    color: Colors.black),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FlatButton(
                    onPressed: () {
                      Analytics.instance.logAlert(text: message, selection:okTitle);
                      if (pushNext) {
                        _goNext(replace : true);
                      }
                      else {
                        _closeDialog(context);
                      }
                     },
                    child: Text(okTitle))
              ],
            )
          ],
        ),
      ),
    );
  }

  void _closeDialog(BuildContext context) {
    Navigator.pop(context, true);
  }

  void _goNext({bool replace = false}) {
    Onboarding().next(context, widget, replace: replace);
  }

  void _goBack() {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }
}
