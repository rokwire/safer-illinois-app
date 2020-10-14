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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/UserData.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/ScalableScrollView.dart';

class OnboardingLoginNetIdPanel extends StatefulWidget with OnboardingPanel {
  
  final Map<String, dynamic> onboardingContext;
  
  OnboardingLoginNetIdPanel({this.onboardingContext});
  
  _OnboardingLoginNetIdPanelState createState() => _OnboardingLoginNetIdPanelState();

  @override
  bool get onboardingCanDisplay {
    return User().isStudentOrEmployee;
  }
}

class _OnboardingLoginNetIdPanelState extends State<OnboardingLoginNetIdPanel> implements NotificationsListener {
  bool _progress = false;

  @override
  void initState() {
    NotificationService().subscribe(this, [Auth.notifyLoginSucceeded, Auth.notifyLoginFailed, Auth.notifyStarted]);
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String titleString = Localization().getStringEx('panel.onboarding.login.netid.label.title', 'Connect your NetID');
    String skipTitle = Localization().getStringEx('panel.onboarding.login.netid.button.dont_continue.title', 'Not right now');
    return Scaffold(
        backgroundColor: Styles().colors.background,
        body: Stack(
          children: <Widget>[

            ScalableScrollView(
            scrollableChild: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(child: Image.asset('images/background-onboarding-squares-dark.png', excludeFromSemantics: true,fit: BoxFit.fitWidth,)),
                          ],
                        ),
                      ],
                    ),
                    Container(margin: EdgeInsets.only(top: 80, bottom: 20),child: Center(child: Image.asset('images/icon-orange-i.png', excludeFromSemantics: true,))),
                    Align(
                      alignment: Alignment.topLeft,
                      child: OnboardingBackButton(padding: EdgeInsets.only(top: 24, left:12.5, right: 20, bottom: 20),
                          onTap: () {
                            Analytics.instance.logSelect(target: "Back");
                            Navigator.pop(context);
                      }),
                    )
                  ],
                ),
                Container(
                  height: 24,
                ),
                Semantics(
                  label: titleString,
                  hint: Localization().getStringEx('panel.onboarding.login.netid.label.title.hint', ''),
                  excludeSemantics: true,
                  child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Center(
                        child: Text(titleString,
                            textAlign: TextAlign.center, style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 36, color: Styles().colors.fillColorPrimary)),
                      )),
                ),
                Container(
                  height: 24,
                ),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(Localization().getStringEx('panel.onboarding.login.netid.label.description', 'Log in with your NetID'),
                        textAlign: TextAlign.center, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color: Styles().colors.fillColorPrimary))),
                Container(
                  height: 32,
                ),
                ]),
                bottomNotScrollableWidget:
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                Padding(
                    padding: EdgeInsets.all(24),
                    child: ScalableRoundedButton(
                        label: Localization().getStringEx('panel.onboarding.login.netid.button.continue.title', 'Log in with NetID'),
                        hint: Localization().getStringEx('panel.onboarding.login.netid.button.continue.hint', ''),
                        borderColor: Styles().colors.fillColorSecondary,
                        backgroundColor: Styles().colors.background,
                        textColor: Styles().colors.fillColorPrimary,
                        onTap: () => _onLoginTapped()),
                  ),
                Row(
                  children: <Widget>[
                    Expanded(
                        child: GestureDetector(
                      onTap: () => _onSkipTapped(),
                      child: Semantics(
                          label: skipTitle,
                          hint: Localization().getStringEx('panel.onboarding.login.netid.button.dont_continue.hint', 'Skip verification'),
                          button: true,
                          excludeSemantics: true,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Text(
                              skipTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Styles().colors.fillColorPrimary,
                                decoration: TextDecoration.underline,
                                decorationColor: Styles().colors.fillColorSecondary,
                                fontFamily: Styles().fontFamilies.medium,
                                fontSize: 16,
                              ),
                            ),
                          )),
                    )),
                  ],
                )
              ])),
            _progress
                ? Container(
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(),
                  )
                : Container(),
          ],
        ));
  }

  Widget _buildDialogWidget(BuildContext context) {
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
                Localization().getStringEx('panel.onboarding.login.label.login_failed', 'Unable to login. Please try again later'),
                textAlign: TextAlign.left,
                style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FlatButton(
                    onPressed: () {
                      Analytics.instance.logAlert(text: "Unable to login", selection: "Ok");
                      Navigator.pop(context);
                      //_finish();
                    },
                    child: Text(Localization().getStringEx('dialog.ok.title', 'OK')))
              ],
            )
          ],
        ),
      ),
    );
  }

  void _onLoginTapped() {
    Analytics.instance.logSelect(target: 'Log in with NetID');
    Auth().authenticateWithShibboleth();
  }

  void _onSkipTapped() {
    Analytics.instance.logSelect(target: 'Not right now');
    if (Auth().isShibbolethLoggedIn) {
      widget.onboardingContext["shouldDisplayQrCode"] = true;
    }
    Onboarding().next(context, widget);
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Auth.notifyStarted) {
      _onLoginStarted();
    } else if (name == Auth.notifyLoginSucceeded) {
      onLoginResult(true);
    } else if (name == Auth.notifyLoginFailed) {
      onLoginResult(false);
    }
  }

  void _onLoginStarted() {
    setState(() { _progress = true; });
  }
  void onLoginResult(bool success) {
    if (mounted) {
      setState(() { _progress = false; });
      if (success) {
        Onboarding().next(context, widget);
      } else {
        showDialog(context: context, builder: (context) => _buildDialogWidget(context));
      }
    }
  }

}
