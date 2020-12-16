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
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/utils/Utils.dart';

class StatusInfoDialog extends StatelessWidget{
  final String currentCountyName;

  const StatusInfoDialog({Key key, this.currentCountyName}) : super(key: key);

  static show(BuildContext context, countyName){
    showDialog(context: context,child: StatusInfoDialog(currentCountyName: countyName,));
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> contentList = <Widget>[
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
    ];

    List<HealthCodeData> codes = Health().rules?.codes?.list;
    if (codes != null) {
      for (HealthCodeData code in codes) {
        if (code.visible != false) {
          contentList.add(Container(height: 10,));
          contentList.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Image.asset('images/icon-member.png', excludeFromSemantics: true, color: code.color,),
            Container(width: 8,),
            Expanded(child: 
              Text(code.longDescription(rules: Health().rules), style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
              ),
            ),
          ],),);
        }
      }
    }

    List<String> infoList = Health().rules?.codes?.info(rules: Health().rules);
    if (infoList != null) {
      for (String info in infoList) {
        if (AppString.isStringNotEmpty(info)) {
          contentList.add(Container(height: 10,));
          contentList.add(Text(info, style: TextStyle(color: Styles().colors.textSurface, fontFamily: Styles().fontFamilies.regular, fontSize: 16),),);
        }
      }
    }

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
                            children:contentList,
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