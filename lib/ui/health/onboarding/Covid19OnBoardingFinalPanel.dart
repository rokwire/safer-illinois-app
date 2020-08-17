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
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';

class Covid19OnBoardingFinalPanel extends StatelessWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;

  Covid19OnBoardingFinalPanel({this.onboardingContext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Styles().colors.fillColorPrimary,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SafeArea(child:
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(child: Image.asset('images/background-onboarding-squares-light.png', excludeFromSemantics: true,fit: BoxFit.fitWidth,)),
                          ],
                        ),
                      ],
                    ),
                    Container(margin: EdgeInsets.only(top: 80, bottom: 20),child: Center(child: Image.asset('images/icon-all-set-header.png', excludeFromSemantics: true,))),
                    Align(
                      alignment: Alignment.topLeft,
                      child: OnboardingBackButton(padding: EdgeInsets.only(top: 24, left:12.5, right: 20, bottom: 20), onTap: () => _goBack(context)),
                    )
                  ],
                ),
                Container(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
                        child: Text(Localization().getStringEx("panel.health.onboarding.covid19.final.label.title", "You’re all set!"),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color: Styles().colors.white),
                        ))
                ),
              ],)
            ),
            Container(height: 11,),
            Expanded(child: _buildMiddleContent()),
            Padding(
              padding: EdgeInsets.only(top: 16, bottom: 22, left: 16, right: 16),
              child: RoundedButton(
                label: Localization().getStringEx("panel.health.onboarding.covid19.final.button.continue.title", "Get Started"),
                hint: Localization().getStringEx("panel.health.onboarding.covid19.final.button.continue.hint", ""),
                borderColor: Styles().colors.lightBlue,
                backgroundColor: Styles().colors.fillColorPrimary,
                textColor: Styles().colors.white,
                onTap: () => _goNext(context),
              ),
            )
          ],
        ));
  }

  Widget _buildMiddleContent(){
    if(Auth().isLoggedIn){
      if(Auth().isShibbolethLoggedIn){
        return _buildVerifiedMiddleContent();
      }
      else if(Auth().isPhoneLoggedIn && (Auth()?.userPiiData?.hasPasportInfo ?? false)){
        return _buildVerifiedMiddleContent();
      }
    }
    return _buildUnverifiedMiddleContent();
  }

  Widget _buildVerifiedMiddleContent(){
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            Localization().getStringEx(
                "panel.health.onboarding.covid19.final.label.description", "You've been verified, and a status card has been added to your profile."),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.white),
          ),
        ),
        Expanded(
          child: Container(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            Localization().getStringEx(
                "panel.health.onboarding.covid19.final.label.bottom.description","You can now use this app as your companion in the fight against COVID-19."),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildUnverifiedMiddleContent(){
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            Localization().getStringEx(
                "panel.health.onboarding.covid19.final.label.unverified.description", "You can now use this app as your companion in the fight against COVID-19."),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.white),
          ),
        ),
        Expanded(
          child: Container(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            Localization().getStringEx(
                "panel.health.onboarding.covid19.final.label.unverified.bottom.description", "To access your COVID-19 status, you will need to upload a Government ID. You can add this any time in the COVID-19 settings."),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.white),
          ),
        ),
      ],
    );
  }


  void _goBack(BuildContext context) {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }

  void _goNext(BuildContext context) {
    Analytics.instance.logSelect(target: "Continue");
    Onboarding().next(context, this);
  }
}
