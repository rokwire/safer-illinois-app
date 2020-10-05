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
import 'package:illinois/service/Assets.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/service/Styles.dart';
import 'package:sprintf/sprintf.dart';

class Covid19GuidelinesPanel extends StatefulWidget {
  final Covid19Status status;

  Covid19GuidelinesPanel({Key key, this.status}) : super(key: key);

  @override
  _Covid19GuidelinesPanelState createState() => _Covid19GuidelinesPanelState();
}

class _Covid19GuidelinesPanelState extends State<Covid19GuidelinesPanel> implements NotificationsListener {
  
  Covid19Status _covid19Status;
  List<HealthGuidelineItem> _statusGuidelines;


  LinkedHashMap<String, HealthCounty> _counties;

  Map<String, dynamic> _guidelineImages;

  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    
    NotificationService().subscribe(this, [
      Assets.notifyChanged
    ]);
    
    _guidelineImages  = Assets()['covid19_guidelines.icons'];
    
    _loadCovidCounties();
    
    if (widget.status != null) {
      _covid19Status = widget.status;
      _statusGuidelines = _loadGuidelines();
    }
    else {
      _loadCovid19Status();
    }
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  void _loadCovidCounties(){
    setState(() {
      _loadingProgress++;
    });
  
    Health().loadCounties().then((List<HealthCounty> counties) {
      if (mounted) {
        setState(() {
          _loadingProgress--;
          _counties = HealthCounty.listToMap(counties);
          if (_loadingProgress == 0) {
            _statusGuidelines = _loadGuidelines();
          }
        });
      }
    });
  }

  void _loadCovid19Status() {

    setState(() {
      _loadingProgress++;
    });

    Health().loadCovid19Status().then((Covid19Status status) {
      if (mounted) {
        setState(() {
          _loadingProgress--;
          _covid19Status = status;
          if (_loadingProgress == 0) {
            _statusGuidelines = _loadGuidelines();
          }
        });
      }
    });
  }

  List<HealthGuidelineItem> _loadGuidelines() {
    HealthGuideline statusGuideline;
    String statusName = this._currentHealthStatus;
    List<HealthGuideline> guidelines = _selectedCounty?.guidelines;
    if ((guidelines != null) && guidelines.isNotEmpty && (statusName != null) && statusName.isNotEmpty) {
      for (HealthGuideline guideline in guidelines) {
        if (guideline.name?.toLowerCase() == statusName) {
          statusGuideline = guideline;
          break;
        }
      }
    }
    return statusGuideline?.items ?? <HealthGuidelineItem>[
      HealthGuidelineItem(icon: 'home', description: Localization().getStringEx('panel.covid19_guidelines.no.status', 'There are no specific guidelines for your status in this county.'))
    ];
  }

  String get _currentHealthStatus {
    return _covid19Status?.blob?.healthStatus?.toLowerCase() ?? kCovid19HealthStatusYellow;
  }

  @override
  Widget build(BuildContext context) {
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
      body: ((0 < _loadingProgress)
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
                          [_covid19Status?.blob?.localizedHealthStatus??"unknown"]),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Styles().colors.textSurface, fontSize: 16, fontFamily: Styles().fontFamilies.regular),
                    ),
                  ),
                  _buildCountyDropdown(),
                  Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: (covid19HealthStatusColor(this._currentHealthStatus) ?? Styles().colors.background), borderRadius: BorderRadius.circular(4), border: Border.all(color: Styles().colors.surfaceAccent, width: 1)), child:
                  (guidelinesCount == 0 ? Container() : ListView.separated(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Styles().colors.surfaceAccent,),
                      itemCount: guidelinesCount,
                      itemBuilder: (BuildContext context, int index) {
                        HealthGuidelineItem guideline = _statusGuidelines[index];
                        String guidelineImage = _getGuidelineItemImageRes(guideline);
                        return Container(
                          padding: EdgeInsets.only(left: 24, right: 5),
                          color: Styles().colors.white,
//                          height: 104,
                          child: Center(child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                            Padding(padding: EdgeInsets.only(right: 24), child:guidelineImage!=null? Image.asset(guidelineImage, excludeFromSemantics: true,) : Container(width: 72,),),
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
    String countyName = _selectedCounty?.nameDisplayText??"";
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
      result = List <DropdownMenuItem>();
      for (HealthCounty county in _counties.values) {
        result.add(DropdownMenuItem<dynamic>(
          value: county.id,
          child: Text(county.nameDisplayText),
        ));
      }
    }
    return result;
  }

  //Guidelines Image res mapping
  String _getGuidelineItemImageRes(HealthGuidelineItem guideline){
    String iconRes = _guidelineImages[guideline.icon];
    return iconRes!=null?"images/$iconRes" : null;
  }

  HealthCounty get _selectedCounty {
    if(Health().currentCountyId==null && (_counties?.length==1??false)){ // if only one county
      return _counties[0];
    }
    return (_counties != null) ? _counties[Health().currentCountyId] : null;
  }

  void _switchCounty(String countyId) {
    setState(() {
      _loadingProgress++;
    });
    Health().switchCounty(countyId).then((Covid19Status status) {
      if (mounted) {
        setState(() {
          _loadingProgress--;
          if(status!=null) {
            _covid19Status = status;
          }
          _statusGuidelines = _loadGuidelines();
        });
      }
    });
  }

  @override
  void onNotification(String name, param) {
    if (name == Assets.notifyChanged) {
      if (mounted) {
        setState(() {
          _statusGuidelines = _loadGuidelines();
        });
      }
    }
  }
}

