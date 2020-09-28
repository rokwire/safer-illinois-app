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
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';

class StatusInfoDialog extends StatelessWidget{
  final String currentCountyName;

  const StatusInfoDialog({Key key, this.currentCountyName}) : super(key: key);

  static show(BuildContext context, countyName){
    showDialog(context: context,child: StatusInfoDialog(currentCountyName: countyName,));
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState){
        return ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: Dialog(
            backgroundColor: Styles().colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(child:Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          container: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(Localization().getStringEx("panel.health.status_update.info_dialog.label1", "Status color definitions can change depending on different counties."),
                                style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                              ),
                              Container(height: 10,),
                              RichText(
                                textScaleFactor: MediaQuery.textScaleFactorOf(context),
                                text: TextSpan(
                                  text: Localization().getStringEx("panel.health.status_update.info_dialog.label2", "Status colors for "),
                                  style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                                  children: <TextSpan>[
                                    TextSpan(text: currentCountyName, style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.bold, fontSize: 16)),
                                    TextSpan(text: ':', style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                              Container(height: 10,),
                              Row(
                                children: <Widget>[
                                  Image.asset('images/icon-member.png', excludeFromSemantics: true, color: covid19HealthStatusColor(kCovid19HealthStatusYellow),),
                                  Container(width: 8,),
                                  Expanded(
                                    child: Text(Localization().getStringEx("com.illinois.covid19.status.info.description.yellow", "Yellow: Recent negative test"),
                                      style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              Container(height: 10,),
                              Row(
                                children: <Widget>[
                                  Image.asset('images/icon-member.png', excludeFromSemantics: true, color: covid19HealthStatusColor(kCovid19HealthStatusOrange),),
                                  Container(width: 8,),
                                  Expanded(
                                    child: Text(Localization().getStringEx("com.illinois.covid19.status.info.description.orange", "Orange: First time user, Past due for test, Self-reported symptoms, Received exposure notification or Quarantined"),
                                      style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              Container(height: 10,),
                              Row(
                                children: <Widget>[
                                  Image.asset('images/icon-member.png', excludeFromSemantics: true, color: covid19HealthStatusColor(kCovid19HealthStatusRed),),
                                  Container(width: 8,),
                                  Expanded(
                                    child: Text(Localization().getStringEx("com.illinois.covid19.status.info.description.red", "Red: Positive test"),
                                      style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              Container(height: 10,),
                              Text(Localization().getStringEx("panel.health.status_update.info_dialog.label3", "Default status for new users is set to Orange."),
                                style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                              ),
                              Container(height: 10,),
                              Text(Localization().getStringEx("panel.health.status_update.info_dialog.label4", "An up-to-date on-campus negative test result will reset your COVID-19 status to Yellow, and Building Entry will change to Granted."),
                                style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                              ),
                            ],
                          )
                        ),
                      ),
                      Container(height: 10,),
                      Semantics(
                        label: Localization().getStringEx("dialog.close.title", "Close"),
                        button: true,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 30,
                            width: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(15)),
                              border: Border.all(color: Styles().colors.fillColorSecondary, width: 2),
                            ),
                            child: Center(
                              child:
                              ExcludeSemantics(child:
                                  Column(children: [
                                    Expanded(child:
                                      Row(children: [
                                        Expanded(child:
                                          RichText(textAlign: TextAlign.center, text: TextSpan(
                                            text: '\u00D7',
                                            style: TextStyle(
                                              fontSize: 24,
                                              color: Styles().colors.fillColorSecondary,
                                            ),
                                          ),
                                        ),
                                        )
                                      ],)
                                      )
                                  ],)

                              )
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            )),
          ),
        );
      },
    );
  }

}