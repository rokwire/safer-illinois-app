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


import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/service/Styles.dart';
import 'package:sprintf/sprintf.dart';

class HealthGuidelinesPanel extends StatefulWidget {

  HealthGuidelinesPanel({Key key}) : super(key: key);

  @override
  _HealthGuidelinesPanelState createState() => _HealthGuidelinesPanelState();
}

class _HealthGuidelinesPanelState extends State<HealthGuidelinesPanel> {
  
  LinkedHashMap<String, HealthCounty> _counties;
  List<HealthGuidelineItem> _statusGuidelines;
  static const Map<String, dynamic> _guidelineImages = {
    "home": "images/icon-stay-at-home.png",
    "separate": "images/icon-separate-people.png",
    "distance": "images/icon-social-distance.png",
    "mask": "images/icon-face-mask.png"
  };

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    
    _loadCounties();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadCounties(){
    setState(() {
      _loading = true;
    });
  
    Health().loadCounties(guidelines: true).then((List<HealthCounty> counties) {
      if (mounted) {
        setState(() {
          _loading = false;
          _counties = HealthCounty.listToMap(counties);
          _statusGuidelines = _buildGuidelines();
        });
      }
    });
  }

  List<HealthGuidelineItem> _buildGuidelines() {
    HealthGuideline statusGuideline;
    String statusCode = this._currentStatusCode;
    List<HealthGuideline> guidelines = _selectedCounty?.guidelines;
    if ((guidelines != null) && guidelines.isNotEmpty && (statusCode != null) && statusCode.isNotEmpty) {
      for (HealthGuideline guideline in guidelines) {
        if (guideline.name?.toLowerCase() == statusCode) {
          statusGuideline = guideline;
          break;
        }
      }
    }
    return statusGuideline?.items ?? <HealthGuidelineItem>[
      HealthGuidelineItem(icon: 'home', description: Localization().getStringEx('panel.covid19_guidelines.no.status', 'There are no specific guidelines for your status in this county.'))
    ];
  }

  String get _currentStatusCode {
    return Health().status?.blob?.code?.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    String statusCode = Health().status?.blob?.code;
    String statusName = Health().rules?.codes[statusCode]?.name(rules: Health().rules) ?? "Unknown";
    int guidelinesCount = _statusGuidelines?.length ?? 0;

    return Scaffold(
      backgroundColor: Styles().colors.background,
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(
          Localization().getStringEx('panel.covid19_guidelines.header.title', 'County Guidelines'),
          style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),
        ),
      ),
      body: ((_loading == true)
          ? Align(alignment: Alignment.center, child: CircularProgressIndicator(),)
          : SingleChildScrollView(
              child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(left: 10, right: 10, bottom: 0),
                    child: Text(
                      Localization()
                          .getStringEx('panel.covid19_guidelines.description.title', 'Help stop the spread of COVID-19 by following these current guidelines.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Styles().colors.textSurface, fontSize: 16, fontFamily: Styles().fontFamilies.regular),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 10, right: 10, bottom: 10),
                    child: Text(
                      sprintf(Localization().getStringEx('panel.covid19_guidelines.status.title', 'These are based on your %s status in the following county:'),
                          [statusName]),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Styles().colors.textSurface, fontSize: 16, fontFamily: Styles().fontFamilies.regular),
                    ),
                  ),
                  _buildCountyDropdown(),
                  Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Health().rules?.codes[this._currentStatusCode]?.color ?? Styles().colors.background, borderRadius: BorderRadius.circular(4), border: Border.all(color: Styles().colors.surfaceAccent, width: 1)), child:
                  (guidelinesCount == 0 ? Container() : ListView.separated(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Styles().colors.surfaceAccent,),
                      itemCount: guidelinesCount,
                      itemBuilder: (BuildContext context, int index) {
                        HealthGuidelineItem guideline = _statusGuidelines[index];
                        String guidelineImage = _getGuidelineItemImageRes(guideline);
                        return Container(
                          padding: EdgeInsets.all(10),
                          color: Styles().colors.white,
//                          height: 104,
                          child: Center(child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                            Padding(padding: EdgeInsets.only(right: 10), child:guidelineImage!=null? Image.asset(guidelineImage, excludeFromSemantics: true,) : Container(width: 72,),),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                              Text(guideline.description ?? '', style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.regular),), //TBD : Localization
                              Text(guideline.type ?? '', style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),), //TBD : Localization
                            ],),)
                          ],),),
                        );
                      })))
                ],
              ),
            ))),
    );
  }

  //County
  Widget _buildCountyDropdown(){
    bool editable = _counties!=null && _counties.length>1;
    String countyName = _selectedCounty?.displayName ?? "";
    return Padding(padding: EdgeInsets.symmetric(horizontal: 32, vertical: 0),
        child: Column(crossAxisAlignment:CrossAxisAlignment.center, children: <Widget>[
          Semantics(container: true, child:
          Padding(padding: EdgeInsets.only(bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
              editable?
                Container(
                child: Padding(padding: EdgeInsets.only(left: 12, right: 16),
                    child:
                    DropdownButtonHideUnderline(
                        child:DropdownButton(
                          icon: Icon(Icons.arrow_drop_down, color:Styles().colors.fillColorPrimary, semanticLabel: null,),
                          isExpanded: true,
                          style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary,),
                          hint: Text(countyName != null ? "$countyName ${Localization().getStringEx("app.common.label.county", "County")}": Localization().getStringEx("panel.covid19_guidelines.label.county.empty","Select a county..."),
                            style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary,),),
                          items: _buildCountyDropdownItems(),
                          onChanged: (value) { _switchCounty(value); },
                        )
                    )
                ),
              ) :
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(child:
                    Text(countyName != null ? "$countyName ${Localization().getStringEx("app.common.label.county", "County")}":"",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary,),),
                  )
              ],))
            ],),
          ),
          ),
          Container(height: 12,)
        ]));
  }

  List <DropdownMenuItem> _buildCountyDropdownItems(){
    List <DropdownMenuItem> result;
    if (_counties?.isNotEmpty ?? false) {
      result = <DropdownMenuItem>[];
      for (HealthCounty county in _counties.values) {
        result.add(DropdownMenuItem<dynamic>(
          value: county.id,
          child: Text(county.displayName ?? ''),
        ));
      }
    }
    return result;
  }

  //Guidelines Image res mapping
  String _getGuidelineItemImageRes(HealthGuidelineItem guideline){
    return _guidelineImages[guideline.icon];
  }

  HealthCounty get _selectedCounty {
    return ((_counties != null) && (0 < _counties.length)) ? (_counties[Health().county?.id] ?? _counties.values.first) : null;
  }

  void _switchCounty(String countyId) {
    setState(() {
      _loading = true;
    });
    Health().setCounty(_counties[countyId]).then((_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusGuidelines = _buildGuidelines();
        });
      }
    });
  }
}

