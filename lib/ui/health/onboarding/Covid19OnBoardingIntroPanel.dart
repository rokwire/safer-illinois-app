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
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';

class Covid19OnBoardingIntroPanel extends StatelessWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;

  Covid19OnBoardingIntroPanel({this.onboardingContext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Styles().colors.fillColorPrimary,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Align(
              alignment: Alignment.topLeft,
              child: OnboardingBackButton(padding: EdgeInsets.only(top: 24, left: 12.5, right: 20, bottom: 20), onTap: () => _goBack(context)),
            ),
            ExcludeSemantics(child: Padding(padding: EdgeInsets.only(top: 34), child: Image.asset('images/covid19-header-blue.png'),)),
            Padding(
                padding: EdgeInsets.only(left: 24, right: 24, top: 32, bottom: 17),
                child: Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
                child:Text(Localization().getStringEx('panel.health.onboarding.covid19.intro.label.title', 'Join the fight against COVID-19'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color: Styles().colors.white),
                ))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                Localization().getStringEx(
                    'panel.health.onboarding.covid19.intro.label.description', 'Track and manage your health to help keep our Illinois community safe'),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.white),
              ),
            ),
            Expanded(
              child: Container(),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: RoundedButton(
                label: Localization().getStringEx('panel.health.onboarding.covid19.intro.button.continue.title', 'Continue'),
                hint: Localization().getStringEx('panel.health.onboarding.covid19.intro.button.continue.hint', ''),
                borderColor: Styles().colors.lightBlue,
                backgroundColor: Styles().colors.fillColorPrimary,
                textColor: Styles().colors.white,
                onTap: () => _goNext(context),
              ),
            )
          ],
        ));
  }

  void _goBack(BuildContext context) {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }

  void _goNext(BuildContext context) {
    Analytics.instance.logSelect(target: "Continue") ;
    return Onboarding().next(context, this);
  }
}
