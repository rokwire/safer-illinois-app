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

import 'package:flutter/material.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';

class Covid19AboutPanel extends StatefulWidget {

  Covid19AboutPanel();

  @override
  _Covid19AboutPanelState createState() => _Covid19AboutPanelState();
}

class _Covid19AboutPanelState extends State<Covid19AboutPanel> {
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SimpleHeaderBarWithBack(
          context: context,
          titleWidget: Text(Localization().getStringEx("panel.health.covid19.about.heading.title","About"), style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
        ),
        backgroundColor: Styles().colors.white,
        body:  SingleChildScrollView(
          child:Container(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child:Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(height: 16,),
                Container(
                    child: Text(
                      Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.heading.title", "How it works"),
                      textAlign: TextAlign.left,
                      style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color:Styles().colors.fillColorPrimary),
                    )
                ),
                Container(height: 16,),
                Text(
                  Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line1.title", "Testing and limiting exposure are key to slowing the spread of COVID-19."),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                ),
                Container(height: 16,),
                Text(
                  Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line2.title", "You can use this app to:"),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                ),
                Container(height: 16,),
                Text(
                  Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line3.title", "Provide any COVID-19 symptoms you experience"),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                ),
                Container(height: 16,),
                Text(
                  Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line4.title", "Automatically receive or enter test results from your healthcare provider"),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                ),
                Container(height: 16,),
                Text(
                  Localization().getStringEx("panel.health.onboarding.covid19.how_it_works.line5.title", "Allow your phone to send exposure notifications to you and the people you’ve come in contact with during the last 14 days"),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                ),
              ],))
          ));
  }
}