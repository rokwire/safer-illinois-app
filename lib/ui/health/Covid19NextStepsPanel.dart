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
import 'package:flutter_html/flutter_html.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/WebPanel.dart';
import 'package:illinois/ui/health/Covid19CareTeamPanel.dart';
import 'package:illinois/ui/health/Covid19TestLocations.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:url_launcher/url_launcher.dart';

class Covid19NextStepsPanel extends StatefulWidget {
  final Covid19Status status;

  Covid19NextStepsPanel({this.status} );

  @override
  _Covid19NextStepsPanelState createState() => _Covid19NextStepsPanelState();
}

class _Covid19NextStepsPanelState extends State<Covid19NextStepsPanel> {

  @override
  void initState() {

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Styles().colors.fillColorPrimary,
        body:Container(
          child: Column(
            children: <Widget>[
              Expanded(
                child: _buildContent(),
              ),
//              _buildPageIndicator(),
              Container(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: ScalableRoundedButton(
                  label: _nextStepRequiresTest? Localization().getStringEx("panel.health.next_steps.button.continue.title.find_locatio","Find location") :
                  Localization().getStringEx("panel.health.next_steps.button.continue.title.care_team","Get in Touch with Care Team") ,
                  backgroundColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  textColor: Styles().colors.white,
                  onTap:_onTapContinue,
                ),
              )
            ],
          ),
        )
    );
  }

  Widget _buildContent(){
    List<Widget> content = <Widget>[
      Container(height: 125,),
      Text(Localization().getStringEx("panel.health.next_steps.label.next_steps","NEXT STEPS"), style: TextStyle(color: Colors.white, fontSize: 28, fontFamily: Styles().fontFamilies.bold)),
      Container(height: 29,),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Container(height: 1, color: Styles().colors.surfaceAccent ,),
      ),
      Container(height: 24,),
    ];
    
    String nextStepTitle = widget.status?.blob?.displayNextStep;
    if (AppString.isStringNotEmpty(nextStepTitle)) {
      content.addAll(<Widget>[
        Container(height: 12,),
        Padding(padding: EdgeInsets.symmetric(horizontal: 32), child:
          Text(widget.status?.blob?.displayNextStep ?? " ", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20, fontFamily: Styles().fontFamilies.extraBold),),
        ),
      ]);
    }

    String nextStepHtml = widget.status?.blob?.displayNextStepHtml;
    if (AppString.isStringNotEmpty(nextStepHtml)) {
      content.addAll(<Widget>[
          Container(height: 12,),
          Padding(padding: EdgeInsets.symmetric(horizontal: 32), child:
            Html(data: nextStepHtml, onLinkTap: (url) => _onTapLink(url), defaultTextStyle: TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Colors.white),),
          ),
      ]);
    }

    return SingleChildScrollView(
      child: Column(children: content,),
    );
  }

  void _onTapLink(String url) {
    if (AppString.isStringNotEmpty(url)) {
      if (AppUrl.launchInternal(url)) {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => WebPanel(url: url)));
      } else {
        launch(url);
      }
    }
  }

  void _onTapContinue(){
    if(_nextStepRequiresTest) {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19TestLocationsPanel())).then((dynamic) {
        Navigator.pop(context);
      });
    }
    else {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19CareTeamPanel())).then((dynamic) {
        Navigator.pop(context);
      });
    }
  }

  bool get _nextStepRequiresTest{
    return widget.status?.blob?.requiresTest ?? false; 
  }
}