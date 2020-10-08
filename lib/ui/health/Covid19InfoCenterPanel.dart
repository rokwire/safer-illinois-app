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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Connectivity.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/WebPanel.dart';
import 'package:illinois/ui/health/Covid19AddTestResultPanel.dart';
import 'package:illinois/ui/health/Covid19CareTeamPanel.dart';
import 'package:illinois/ui/health/Covid19GuidelinesPanel.dart';
import 'package:illinois/ui/health/Covid19StatusPanel.dart';
import 'package:illinois/ui/health/Covid19SymptomsPanel.dart';
import 'package:illinois/ui/health/Covid19TestLocations.dart';
import 'package:illinois/ui/health/Covid19HistoryPanel.dart';
import 'package:illinois/ui/health/Covid19WellnessCenter.dart';
//import 'package:illinois/ui/settings/SettingsNewHomePanel.dart';
import 'package:illinois/ui/settings/SettingsHomePanel.dart';
import 'package:illinois/ui/widgets/LinkTileButton.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/ui/widgets/SectionTitlePrimary.dart';
import 'package:illinois/ui/widgets/StatusInfoDialog.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:url_launcher/url_launcher.dart';

class Covid19InfoCenterPanel extends StatefulWidget {

  Covid19InfoCenterPanel({Key key}) : super(key: key);

  @override
  _Covid19InfoCenterPanelState createState() => _Covid19InfoCenterPanelState();
}

class _Covid19InfoCenterPanelState extends State<Covid19InfoCenterPanel> implements NotificationsListener {

  Covid19Status _status;
  bool          _loadingStatus;
  Covid19History _lastHistory;
  String _currentCountyName;

  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [
      Health.notifyStatusChanged,
      Health.notifyProcessingFinished,
      Health.notifyUserUpdated,
      Health.notifyHistoryUpdated,
    ]);

    _loadStatus();
    _loadCountyName();
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);
  }

  @override
  void onNotification(String name, param) {
    if (name == Health.notifyStatusChanged) {
      _updateStatus(param);
    }
    else if (name == Health.notifyProcessingFinished) {
      _updateStatus(param?.status);
    }
    else if (name == Health.notifyUserUpdated) {
      if (mounted && (_status?.blob == null)) {
        _loadStatus();
      }
    } else if (name == Health.notifyHistoryUpdated) {
      if (mounted) {
        if (param != null) {
          setState(() {
            _lastHistory = Covid19History.mostRecent(param);
          });
        }
        else {
          _loadHistory();
        }
      }
    }
  }

  void _loadStatus() {
    setState(() {
      _loadingStatus = true;
    });
    Health().currentCountyStatus.then((Covid19Status status) {
      _updateStatus(status);
    });
  }

  void _updateStatus(Covid19Status status) {
    if (mounted) {
      setState(() {
        _status = status;
        _loadingStatus = (Health().processing == true);
        if (Health().processing != true) {
          _loadHistory();
        }
      });
    }
  }

  void _loadHistory(){
    Health().loadCovid19History().then((List<Covid19History> history) {
      if (mounted) {
       setState(() {
         _lastHistory = Covid19History.mostRecent(history);
       });
      }
    });
  }

  void _loadCountyName(){
    Health().loadCounties().then((List<HealthCounty> counties) {
      LinkedHashMap<String, HealthCounty> _counties = HealthCounty.listToMap(counties);
      if(counties != null && _counties.containsKey(Health().currentCountyId)) {
        if(mounted){
          setState((){
            _currentCountyName = _counties[Health().currentCountyId].nameDisplayText;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles().colors.background,
      appBar: _Covid19HomeHeaderBar(context: context,),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildNextStepPrimarySection(),
              _buildHealthPrimarySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextStepPrimarySection() {
    if (Health().isUserLoggedIn) {
      
      List<Widget> entries = <Widget>[
        _buildMostRecentEvent(),
        _buildNextStepSection(),
        _buildSymptomCheckInSection(),
        _buildAddTestResultSection(),
      ];
      
      List<Widget> content = <Widget>[];
      for (Widget entry in entries) {
        if (entry != null) {
          if (content.isNotEmpty) {
            content.add(Container(height: 10,),);
          }
          content.add(entry);
        }
      }
      
      if (content.isNotEmpty) {
        content.add(Container(height: 20,),);
      }

      return SectionTitlePrimary(
        title: Localization().getStringEx("panel.covid19home.top_heading.title", "Stay Healthy"),
        iconPath: 'images/icon-health.png',
        children: content,);
    }
    else {
      return Container();
    }
  }

  Widget _buildHealthPrimarySection() {
    bool isLoggedIn = Health().isUserLoggedIn;
    return SectionTitlePrimary(
      title: Localization().getStringEx("panel.covid19home.label.health.title","Your Health"),
      iconPath: 'images/icon-member.png',
      children: <Widget>[
        isLoggedIn ? _buildStatusSection() : Container(),
        isLoggedIn ? Container(height: 10,) : Container(),
        _buildTileButtons(),
        Container(height: 5,),
        isLoggedIn ? _buildViewHistoryButton() : _buildFindTestLocationsButton(),
        Container(height: 10,),
        _buildCovidWellnessCenter(),
      ]);

  }
  Widget _buildMostRecentEvent(){
    if(_lastHistory?.blob == null) {
      return null;
    }
    String headingText = Localization().getStringEx("panel.covid19home.label.most_recent_event.title", "MOST RECENT EVENT");
    String dateText = AppDateTime.formatDateTime(_lastHistory?.dateUtc?.toLocal(), format:"MMMM dd, yyyy") ?? '';
    String eventExplanationText = _status?.blob?.displayEventExplanation;
    String eventExplanationHtml = _status?.blob?.displayEventExplanationHtml;
    String historyTitle = "", info = "";
    Covid19HistoryBlob blob = _lastHistory.blob;
    if(blob.isTest){
      bool isManualTest = _lastHistory.isManualTest ?? false;
      historyTitle = blob?.testType ?? Localization().getStringEx("app.common.label.other", "Other");
      info = isManualTest? Localization().getStringEx("panel.covid19home.label.provider.self_reported", "Self reported"):
            (blob?.provider ?? Localization().getStringEx("app.common.label.other", "Other"));
    } else if(blob.isAction){
      historyTitle = Localization().getStringEx("panel.covid19home.label.action_required.title", "Action Required");
      info = blob.actionDisplayString?? "";
    } else if(blob.isContactTrace){
      historyTitle = Localization().getStringEx("panel.covid19home.label.contact_trace.title", "Contact Trace");
      info = blob.traceDurationDisplayString;
    } else if(blob.isSymptoms){
      historyTitle = Localization().getStringEx("panel.covid19home.label.reported_symptoms.title", "Self Reported Symptoms");
      info = blob.symptomsDisplayString;
    }

    List <Widget> content = <Widget>[
      Row(children: <Widget>[
        Flexible(
          flex: 3,
          fit: FlexFit.tight,
          child: Text(headingText, style: TextStyle(letterSpacing: 0.5, fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
        ),
        Flexible(
          flex: 2,
          fit: FlexFit.loose,
          child:
          Text(dateText, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 12, color: Styles().colors.textSurface),)
        )
      ],),
      Container(height: 12,),
      Text(historyTitle, style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary),),
    ];

    if (AppString.isStringNotEmpty(info)) {
      content.addAll(<Widget>[
        Container(height: 12,),
        Text(info,style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textSurface),),
      ]);
    }

    if (AppString.isStringNotEmpty(eventExplanationText)) {
      content.addAll(<Widget>[
          Container(height: 12,),
          Text(eventExplanationText, style: TextStyle(fontSize:16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),),
      ]);
    }

    if (AppString.isStringNotEmpty(eventExplanationHtml)) {
      content.addAll(<Widget>[
          Container(height: 12,),
          Html(data: eventExplanationHtml, onLinkTap: (url) => _onTapLink(url), defaultTextStyle: TextStyle(fontSize:16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),),
      ]);
    }

    return Semantics(container: true, child: Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Styles().colors.surface, borderRadius: BorderRadius.all(Radius.circular(4)), boxShadow: [BoxShadow(color: Styles().colors.blackTransparent018, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(2, 2))] ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Stack(children: <Widget>[
          Visibility(visible: (_loadingStatus != true),
            child: Padding(padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: content,),
            ),
          ),
          Visibility(visible: (_loadingStatus == true),
            child: Container(
              height: 60,
              child: Align(alignment: Alignment.center,
                child: SizedBox(height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), )
                ),
              ),
            ),
          ),
        ],),

        Container(margin: EdgeInsets.only(top: 14, bottom: 14), height: 1, color: Styles().colors.fillColorPrimaryTransparent015,),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(explicitChildNodes: true, child: ScalableRoundedButton(
            label: Localization().getStringEx("panel.covid19home.button.view_history.title", "View Health History"),
            hint: Localization().getStringEx("panel.covid19home.button.view_history.hint", ""),
            borderColor: Styles().colors.fillColorSecondary,
            backgroundColor: Styles().colors.surface,
            textColor: Styles().colors.fillColorPrimary,
            onTap: _onTapTestHistory,
          )),
        )
      ],),
    ));
  }

  Widget _buildNextStepSection() {
    String nextStepText = _status?.blob?.displayNextStep;
    String nextStepHtml = _status?.blob?.displayNextStepHtml;
    String warningTitle = _status?.blob?.displayWarning;
    bool hasNextStep = AppString.isStringNotEmpty(nextStepText) || AppString.isStringNotEmpty(nextStepHtml) || AppString.isStringNotEmpty(warningTitle);
    String headingText = hasNextStep ? Localization().getStringEx("panel.covid19home.label.next_step.title", "NEXT STEP") : '';
    String headingDate = (hasNextStep && (_status?.blob?.nextStepDateUtc != null)) ? AppDateTime.formatDateTime(_status.blob.nextStepDateUtc.toLocal(), format: "MMMM dd, yyyy") : '';

    List<Widget> content = <Widget>[
      Row(children: <Widget>[
        Text(headingText, style: TextStyle(letterSpacing: 0.5, fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
        Expanded(child: Container(),),
        Text(headingDate, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 12, color: Styles().colors.textSurface),)
      ],),
    ];

    if (AppString.isStringNotEmpty(nextStepText)) {
      content.addAll(<Widget>[
          Container(height: 12,),
          Text(nextStepText, style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary),),
      ]);
    }

    if (AppString.isStringNotEmpty(nextStepHtml)) {
      content.addAll(<Widget>[
          Container(height: 12,),
          Html(data: nextStepHtml, onLinkTap: (url) => _onTapLink(url), defaultTextStyle: TextStyle(fontSize:16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),),
      ]);
    }

    if (AppString.isStringNotEmpty(warningTitle)) {
      content.addAll(<Widget>[
          Container(height: 12,),
          Text(warningTitle, style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      ]);
    }

    return Semantics(container: true, child: Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Styles().colors.surface, borderRadius: BorderRadius.all(Radius.circular(4)), boxShadow: [BoxShadow(color: Styles().colors.blackTransparent018, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(2, 2))] ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Stack(children: <Widget>[
          Visibility(visible: (_loadingStatus != true),
            child: Padding(padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: content),
            ),
          ),
          Visibility(visible: (_loadingStatus == true),
            child: Container(
              height: 60,
              child: Align(alignment: Alignment.center,
                child: SizedBox(height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), )
                ),
              ),
            ),
          ),
        ],),
        
        Container(margin: EdgeInsets.only(top: 14, bottom: 14), height: 1, color: Styles().colors.fillColorPrimaryTransparent015,),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(explicitChildNodes: true, child: ScalableRoundedButton(
            label: Localization().getStringEx("panel.covid19home.button.find_test_locations.title", "Find test locations"),
            hint: Localization().getStringEx("panel.covid19home.button.find_test_locations.hint", ""),
            borderColor: Styles().colors.fillColorSecondary,
            backgroundColor: Styles().colors.surface,
            textColor: Styles().colors.fillColorPrimary,
            onTap: ()=> _onTapFindLocations(),
          )),
        )
      ],),
    ));
  }


  Widget _buildSymptomCheckInSection() {
    String title = Localization().getStringEx("panel.covid19home.label.check_in.title","Symptom Check-in");
    String description = Localization().getStringEx("panel.covid19home.label.check_in.description","Self-report any symptoms to see if you should get tested or stay home");
    return Semantics(container: true, child: 
      InkWell(onTap: _onTapSymptomCheckIn, child:
        Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16
          ),
          decoration: BoxDecoration(color: Styles().colors.surface, borderRadius: BorderRadius.all(Radius.circular(4)), boxShadow: [BoxShadow(color: Styles().colors.blackTransparent018, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(2, 2))] ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              Expanded(child:
                Text(title, style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary),),
              ),
              Image.asset('images/chevron-right.png'),
            ],),
            Padding(padding: EdgeInsets.only(top: 5), child:
              Text(description, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textSurface),),
            ),
          ],),),),
      );
  }

  Widget _buildAddTestResultSection() {
    String title = Localization().getStringEx("panel.covid19home.label.result.title","Add Test Result");
    String description = Localization().getStringEx("panel.covid19home.label.result.description","To keep your status up-to-date");
    return Semantics(container: true, child: 
      InkWell(onTap: () => _onTapReportTest(), child:
        Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16
          ),
          decoration: BoxDecoration(color: Styles().colors.surface, borderRadius: BorderRadius.all(Radius.circular(4)), boxShadow: [BoxShadow(color: Styles().colors.blackTransparent018, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(2, 2))] ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              Expanded(child:
                Text(title, style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary),),
              ),
              Image.asset('images/chevron-right.png'),
            ],),
            Padding(padding: EdgeInsets.only(top: 5), child:
              Text(description, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textSurface),),
            ),
          ],),),),
      );
  }

  Widget _buildStatusSection() {
    String statusName = _status?.blob?.localizedHealthStatus;
    Color statusColor = covid19HealthStatusColor(_status?.blob?.healthStatus) ?? Styles().colors.textSurface;
    bool hasStatusCard  = Health().isUserLoggedIn;
    return Semantics(container: true, child: Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Styles().colors.surface, borderRadius: BorderRadius.all(Radius.circular(4)), boxShadow: [BoxShadow(color: Styles().colors.blackTransparent018, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(2, 2))] ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Stack(children: <Widget>[
          Visibility(visible: (_loadingStatus != true),
            child: Padding(padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Row(children: <Widget>[
                  Expanded(child:
                    Text(Localization().getStringEx("panel.covid19home.label.status.title","Current Status:"), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
                  ),
                  Semantics(
                    explicitChildNodes: true,
                    child: Semantics(
                      label: Localization().getStringEx("panel.covid19home.button.info.title","Info "),
                      button: true,
                      excludeSemantics: true,
                      child:  IconButton(icon: Image.asset('images/icon-info-orange.png'), onPressed: () =>  StatusInfoDialog.show(context, _currentCountyName), padding: EdgeInsets.all(10),)
                  ))
                ],),
                Container(height: 6,),
                Row(
                  children: <Widget>[
                    Visibility(visible:AppString.isStringNotEmpty(statusName), child: Image.asset('images/icon-member.png', color: statusColor,),),
                    Visibility(visible:AppString.isStringNotEmpty(statusName), child: Container(width: 4,),),
                    Expanded(child:
                      Text(AppString.isStringNotEmpty(statusName) ? statusName : Localization().getStringEx('panel.covid19home.label.status.na', 'Not Available'), style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Styles().colors.textSurface),),
                    )
                  ],
                )
              ],),
            ),
          ),
          Visibility(visible: (_loadingStatus == true),
            child: Container(
              height: 16,
              child: Align(alignment: Alignment.center,
                child: SizedBox(height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), )
                ),
              ),
            ),
          ),
          Container(height: 16,),
        ],),

        hasStatusCard
            ? Container(margin: EdgeInsets.only(top: 14, bottom: 14), height: 1, color: Styles().colors.fillColorPrimaryTransparent015,)
            : Container(),

        hasStatusCard
          ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(explicitChildNodes: true, child: ScalableRoundedButton(
              label: Localization().getStringEx("panel.covid19home.button.show_status_card.title","Show Status Card"),
              hint: '',
              borderColor: Styles().colors.fillColorSecondary,
              backgroundColor: Styles().colors.surface,
              textColor: Styles().colors.fillColorPrimary,
              onTap: ()=> _onTapShowStatusCard(),
            )),
          )
            : Container()
      ],),
    ));
  }

  Widget _buildTileButtons(){
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: LinkTileSmallButton(
                width: double.infinity,
                iconPath: 'images/icon-country-guidelines.png',
                label: Localization().getStringEx("panel.covid19home.button.country_guidelines.title", "County\nGuidelines"),
                hint: Localization().getStringEx("panel.covid19home.button.country_guidelines.hint", ""),
                onTap: ()=>_onTapCountryGuidelines(),
              ),
            ),
            Container(width: 8,),
            Expanded(
              child: LinkTileSmallButton(
                width: double.infinity,
                iconPath: 'images/icon-your-care-team.png',
                label: Localization().getStringEx( "panel.covid19home.button.care_team.title", "Your\nCare Team"),
                hint: Localization().getStringEx( "panel.covid19home.button.care_team.hint", ""),
                onTap: () => _onTapCareTeam(),
              ),
            ),
          ],
        ),
        Container(height: 8,),
        /*Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: LinkTileSmallButton(
                width: double.infinity,
                iconPath: 'images/icon-report-test.png',
                label: Localization().getStringEx("panel.covid19home.button.report_test.title", "Report a Test Result"),
                hint: Localization().getStringEx("panel.covid19home.button.report_test.hint", ""),
                onTap: ()=> _onTapReportTest(),
              ),
            ),
            Container(width: 8,),
            Expanded(
              child: LinkTileSmallButton(
                width: double.infinity,
                iconPath: 'images/icon-test-history.png',
                label: Localization().getStringEx("panel.covid19home.button.test_history.title", "Your Testing History"),
                hint: Localization().getStringEx("panel.covid19home.button.test_history.hint", ""),
                onTap: ()=>_onTapTestHistory(),
              ),
            ),
          ],
        )*/
      ],
    );
  }

  Widget _buildViewHistoryButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Color.fromRGBO(19, 41, 75, 0.3), spreadRadius: 2.0, blurRadius: 8.0, offset: Offset(0, 2))],
      ),
      child: RibbonButton(
        label: Localization().getStringEx("panel.covid19.button.health_history.title", "View Health History"),
        borderRadius: BorderRadius.circular(4),
        height: null,
        onTap: ()=>_onTapTestHistory(),
      ),
    );
  }

  Widget _buildCovidWellnessCenter() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Color.fromRGBO(19, 41, 75, 0.3), spreadRadius: 2.0, blurRadius: 8.0, offset: Offset(0, 2))],
      ),
      child: RibbonButton(
        label: Localization().getStringEx("panel.covid19.button.covid_wellness_center.title", "COVID-19 Wellness Answer Center"),
        borderRadius: BorderRadius.circular(4),
        onTap: ()=>_onTapCovidWellnessCenter(),
        height: null,
      ),
    );
  }

  Widget _buildFindTestLocationsButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Color.fromRGBO(19, 41, 75, 0.3), spreadRadius: 2.0, blurRadius: 8.0, offset: Offset(0, 2))],
      ),
      child: RibbonButton(
        label: Localization().getStringEx("panel.covid19home.button.find_test_locations.title", "Find test locations"),
        hint: Localization().getStringEx("panel.covid19home.button.find_test_locations.hint", ""),
        borderRadius: BorderRadius.circular(4),
        height: null,
        onTap: ()=>_onTapFindLocations(),
      ),
    );
  }

  void _onTapCountryGuidelines() {
    if(Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "COVID-19 County Guidlines");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19GuidelinesPanel(status: _status)));
    } else{
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapCareTeam() {
    if(Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Your Care Team");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19CareTeamPanel(status: _status,)));
    } else{
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapReportTest(){
    if(Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "COVID-19 Report Test");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19AddTestResultPanel()));
    } else{
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapTestHistory(){
    if(Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "COVID-19 Test History");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19HistoryPanel()));
    } else{
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapFindLocations(){
    if(Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "COVID-19 Find Test Locations");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19TestLocationsPanel()));
    } else{
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapShowStatusCard(){
    if(Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Show Status Card");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19StatusPanel()));
    } else{
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapSymptomCheckIn() {
    if(Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Symptom Check-in");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19SymptomsPanel()));
    } else{
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapCovidWellnessCenter(){
    if(Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Wellness Center");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19WellnessCenter()));
    } else{
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapLink(String url) {
    if (Connectivity().isNotOffline) {
      if (AppString.isStringNotEmpty(url)) {
        if (AppUrl.launchInternal(url)) {
          Navigator.push(context, CupertinoPageRoute(builder: (context) => WebPanel(url: url)));
        } else {
          launch(url);
        }
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }
}

class _Covid19HomeHeaderBar extends AppBar {
  final BuildContext context;
  final Widget titleWidget;
  final bool searchVisible;
  final bool rightButtonVisible;
  final String rightButtonText;
  final GestureTapCallback onRightButtonTap;

  static Color get _titleColor  {
    if (Config().isDev) {
      return Colors.yellow;
    }
    else if (Config().isTest) {
      return Colors.green;
    }
    else {
      return Colors.white;
    }
  }

  _Covid19HomeHeaderBar({@required this.context, this.titleWidget, this.searchVisible = false,
    this.rightButtonVisible = false, this.rightButtonText, this.onRightButtonTap})
      : super(
      backgroundColor: Styles().colors.fillColorPrimaryVariant,
      title: Text(Localization().getStringEx("panel.covid19home.header.title", "Safer Illinois Home"),
        style: TextStyle(color: _titleColor, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),
      ),
      actions: <Widget>[
        Semantics(
            label: Localization().getStringEx('headerbar.settings.title', 'Settings'),
            hint: Localization().getStringEx('headerbar.settings.hint', ''),
            button: true,
            excludeSemantics: true,
            child: IconButton(
                icon: Image.asset('images/settings-white.png'),
                onPressed: () {
                  Analytics.instance.logSelect(target: "Settings");
                  //TMP: Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsNewHomePanel()));
                  Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsHomePanel()));
                }))
      ],
      centerTitle: true);
}