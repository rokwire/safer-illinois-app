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
import 'package:illinois/ui/widgets/TrianglePainter.dart';

class OnboardingHealthHowItWorksPanel extends StatelessWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;

  OnboardingHealthHowItWorksPanel({this.onboardingContext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Styles().colors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SafeArea(child:
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      Container(margin: EdgeInsets.only(top: 80, bottom: 20),child: Center(child: Image.asset('images/icon-big-onboarding-health.png', excludeFromSemantics: true,))),
                      Align(
                        alignment: Alignment.topLeft,
                        child: OnboardingBackButton(padding: EdgeInsets.only(top: 24, left:12.5, right: 20, bottom: 20), onTap: () => _goBack(context)),
                      )
                    ],
                  ),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
                      child:Text(Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.heading.title", "How it works"),
                      textAlign: TextAlign.left,
                      style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color:Styles().colors.fillColorPrimary),
                    ))
                  ),
            ],)
            ),
            Container(height: 11,),
            Expanded( child:
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child:
              SingleChildScrollView(
                child:Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line1.title", "Testing and limiting exposure are key to slowing the spread of COVID-19."),
                      style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                    ),
                    Container(height: 16,),
                    Text(
                      Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line2.title", "You can use this app to:"),
                      style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color:Styles().colors.fillColorPrimary),
                    ),
                    Container(height: 16,),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Bullet(),
                        Expanded(
                          child: Text(
                            Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line3.title", "Self-report your COVID-19 symptoms and in doing so update your status."),
                            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                          ),
                        ),
                      ],
                    ),
                    Container(height: 16,),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Bullet(),
                        Expanded(
                          child: Text(
                            Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line4.title", "Automatically receive test results and vaccine information from your healthcare provider."),
                            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                          ),
                        ),
                      ],
                    ),
                    Container(height: 16,),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Bullet(),
                        Expanded(
                          child: Text(
                            Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line5.title", "Allow your phone to send exposure notifications when you’ve been in proximity to people who test positive."),
                            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              ),
            ),),
            Container(color: Styles().colors.white, child: Padding(
              padding: const EdgeInsets.all(16),
              child: ScalableRoundedButton(
                label: Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.button.next.title", "Next"),
                hint: Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.button.next.hint", ""),
                borderColor: Styles().colors.lightBlue,
                backgroundColor: Styles().colors.surface,
                textColor: Styles().colors.fillColorPrimary,
                onTap: ()=>_goNext(context),
              ),
            ),)
          ],
        ),
    );
  }

  void _goBack(BuildContext context) {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }

  void _goNext(BuildContext context) {
    Analytics.instance.logSelect(target: "Continue") ;
    Onboarding().next(context, this);
  }
}


class _Bullet extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return new Container(
      height: 5.0,
      width: 5.0,
      margin: EdgeInsets.only(right: 10, top: 7,),
      decoration: new BoxDecoration(
        color: Styles().colors.lightBlue,
        shape: BoxShape.circle,
      ),
    );
  }
}
