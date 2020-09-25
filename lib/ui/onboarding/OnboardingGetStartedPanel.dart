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
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/ui/widgets/SwipeDetector.dart';
import 'package:illinois/service/Styles.dart';

class OnboardingGetStartedPanel extends StatelessWidget with OnboardingPanel {
  
  final Map<String, dynamic> onboardingContext;
  OnboardingGetStartedPanel({this.onboardingContext});

  @override
  Widget build(BuildContext context) {
    
    Analytics().accessibilityState = MediaQuery.of(context).accessibleNavigation;

    String strWelcome = Localization().getStringEx(
        'panel.onboarding.get_started.image.welcome.title',
        'Welcome to Illinois');

    return Scaffold(body: SwipeDetector(
        onSwipeLeft: () => _goNext(context),
        child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Image.asset('images/background-image.png', fit: BoxFit.cover, excludeFromSemantics: true, semanticLabel: strWelcome,
                height: double.infinity,
                width: double.infinity,),
              Container(color: Styles().colors.fillColorPrimaryTransparent80, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                Semantics(
                    label: Localization().getStringEx("panel.onboarding.get_started.image.safer_in_illinois.title","Safer in Illinois"),
                    image: true,
                    excludeSemantics:true,
                    child: Image.asset('images/safer-illinois.png')
                ),
                Semantics(
                    label: Localization().getStringEx("panel.onboarding.get_started.image.powered.title","Powered by Rokwire"),
                    image: true,
                    excludeSemantics:true,
                    child: Padding(padding: EdgeInsets.only(top: 17), child: Image.asset('images/powered-by.png'),)
                )
              ],),),),
              Column(children: <Widget>[Expanded(child: Container(),), Padding(
                padding: EdgeInsets.all(16),
                child: ScalableRoundedButton(
                  label: Localization().getStringEx(
                      'panel.onboarding.get_started.button.get_started.title',
                      'Get Started'),
                  hint: Localization().getStringEx(
                      'panel.onboarding.get_started.button.get_started.hint',
                      ''),
                  backgroundColor: Styles().colors.fillColorPrimary,
                  textColor: Styles().colors.white,
                  onTap: () => _goNext(context),
                  borderColor: Styles().colors.white,
                ),
              )
              ],)
            ])));
  }

  void _goNext(BuildContext context) {
    Analytics.instance.logSelect(target: "Get Started") ;
    return Onboarding().next(context, this);
  }
}
