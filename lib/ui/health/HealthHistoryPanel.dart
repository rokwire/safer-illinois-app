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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:intl/intl.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Organizations.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/PopupDialog.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_html_to_pdf/flutter_html_to_pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';

class HealthHistoryPanel extends StatefulWidget {
  @override
  _HealthHistoryPanelState createState() => _HealthHistoryPanelState();
}

class _HealthHistoryPanelState extends State<HealthHistoryPanel> implements NotificationsListener {
  
  List<HealthHistory> _history = List();
  bool _isRefreshing = false;
  bool _isDeleting = false;
  bool _isReposting = false;

  @override
  void initState() {
    super.initState();

    NotificationService().subscribe(this, [
      Health.notifyUserUpdated,
      Health.notifyHistoryUpdated,
    ]);

    _history = HealthHistory.pastList(Health().history);
    _refreshHistory();
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);
  }

  @override
  void onNotification(String name, param) {
    if (name == Health.notifyUserUpdated) {
      if (mounted) {
        setState(() {});
      }
    }
    else if (name == Health.notifyHistoryUpdated) {
      if (mounted) {
        setState(() {
          _history = HealthHistory.pastList(Health().history);
        });
      }
    }
  }

  void _refreshHistory() {

    if (_isRefreshing != true) {
      setState(() { _isRefreshing = true; });
      
      Health().refreshStatus().then((_) {
        if (mounted) {
          setState(() {
            _history = HealthHistory.pastList(Health().history);
            _isRefreshing = false;
          });
        }
      });
    }
  }

  void _repostHistory() {

    if(!_isReposting) {
      setState(() {
        _isReposting = true;
      });
      Health().repostUser().whenComplete((){
        setState(() {
          _isReposting = false;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return PopupDialog(displayText: Localization().getStringEx("panel.health.covid19.history.message.request_tests","Your request has been submitted. You should receive your latest test within an hour"), positiveButtonText: Localization().getStringEx("dialog.ok.title","OK"));
            },
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:  SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.health.covid19.history.header.title","Your COVID-19 Event History"),
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: Styles().fontFamilies.extraBold,
              letterSpacing: 1.0),
        ),
      ),
      backgroundColor: Styles().colors.background,
      body: Container(
//        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 75),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          color:  Styles().colors.background,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Expanded(child:
              Stack(children: [
                ((_history != null) && (0 < _history.length)) ? _buildHistoryList() : _buildEmpty(),
                Visibility(visible: (_isRefreshing == true), child: _buildProgress()),
              ],),
            ),
          ]),
        )
    ));
  }

  Widget _buildProgress(){
    return  Center(child: CircularProgressIndicator(),);
  }

  Widget _buildEmpty(){
    return Container(
        padding: EdgeInsets.all(16),
        child:Center(
            child:
            Column(
              children: <Widget>[
                Expanded(child: Container(),),
                Text(Localization().getStringEx("panel.health.covid19.history.label.empty.title","No History"),
                    style: TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface)),
                Expanded(child: Container(),),
                _buildRepostButton(),
                Container(height: 10,),
              ],
            )));
  }

  Widget _buildHistoryList(){
    return Container(child:
    Column(children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(Localization().getStringEx("panel.health.covid19.history.label.description","View your COVID-19 event history.",),
              style: TextStyle(color: Styles().colors.textSurface, fontSize: 16, fontFamily: Styles().fontFamilies.regular),
          ),
        ),
        Expanded(child:
        new ListView.builder(
        itemCount: _history.length + ((!kReleaseMode || Organizations().isDevEnvironment) ? 2 : 1),
        itemBuilder: (BuildContext ctxt, int index) {
          if (index < _history.length) {
            return _HealthHistoryEntry(historyEntry: _history[index]);
          }
          else if (index == _history.length) {
            return _buildRepostButton();
          }
          else {
            return _buildRemoveMyInfoButton();            
          }
        }
    ))
    ],)
    );
  }

  Widget _buildRepostButton(){

    return Padding(padding: EdgeInsets.symmetric(vertical: 5), child:
      Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ScalableRoundedButton(
            label: Localization().getStringEx("panel.health.covid19.history.button.repost_history.title", "Request my latest test again"),
            hint: Localization().getStringEx("panel.health.covid19.history.button.repost_history.hint", ""),
            backgroundColor: Styles().colors.surface,
            fontSize: 16.0,
            textColor:  Styles().colors.fillColorSecondary,
            borderColor: Styles().colors.surfaceAccent,
            onTap: _onRepostClicked,
          ),
          Visibility(
              visible: _isReposting,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary)),
                        ),
                      ),
                    ),
                  ),
                ],
              )),
        ],
      ),);
  }

  Widget _buildRemoveMyInfoButton() {
    return Padding(padding: EdgeInsets.symmetric(vertical: 5), child:
      Stack(children: <Widget>[
        ScalableRoundedButton(
          label: 'Delete my COVID-19 Events History',
          hint: '',
          backgroundColor: Styles().colors.surface,
          fontSize: 16.0,
          textColor: Styles().colors.fillColorSecondary,
          borderColor: Styles().colors.surfaceAccent,
          onTap: _onRemoveMyInfoClicked,
        ),
        Visibility(visible:  _isDeleting, child:
          Row(children: <Widget>[
            Expanded(child:
              Padding(padding: EdgeInsets.only(top: 12), child:
                Center(child: 
                  Container(width: 24, height:24, child:
                    CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary)),
                  ),
                ),
              ),
            ),
          ],)
        ),
      ],),);
  }

  Widget _buildRemoveMyInfoDialog(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState){
        return ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Styles().colors.fillColorPrimary,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Center(
                                  child: Text(
                                    "Delete your COVID-19 event history?",
                                    style: TextStyle(fontSize: 20, color: Colors.white),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  height: 30,
                                  width: 30,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular(15)),
                                    border: Border.all(color: Styles().colors.white, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '\u00D7',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 26,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    "This will permanently delete all of your COVID-19 event history information. Are you sure you want to continue?",
                    textAlign: TextAlign.left,
                    style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
                  ),
                ),
                Container(
                  height: 26,
                ),
                Text(
                  "Are you sure?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Colors.black),
                ),
                Container(
                  height: 16,
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: RoundedButton(
                            onTap: () => _onCancelRemoveMyInfo(),
                            backgroundColor: Colors.transparent,
                            borderColor: Styles().colors.fillColorPrimary,
                            textColor: Styles().colors.fillColorPrimary,
                            label: 'No'),
                      ),
                      Container(
                        width: 10,
                      ),
                      Expanded(child:
                        RoundedButton(
                          onTap: () => _onConfirmRemoveMyInfo(),
                          backgroundColor: Styles().colors.fillColorSecondaryVariant,
                          borderColor: Styles().colors.fillColorSecondaryVariant,
                          textColor: Styles().colors.surface,
                          label: Localization().getStringEx("panel.profile_info.dialog.remove_my_information.yes.title", "Yes"),
                          height: 48,),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onRepostClicked(){
    _repostHistory();
  }

  void _onRemoveMyInfoClicked() {
  Analytics.instance.logSelect(target: 'Delete my COVID-19 Information');
  if (!_isDeleting) {
      showDialog(context: context, builder: (context) => _buildRemoveMyInfoDialog(context));
    }
  }

  void _onConfirmRemoveMyInfo() {
    Analytics.instance.logAlert(text: "Remove My Information", selection: "Yes");
    Navigator.pop(context);

    if (!_isDeleting) {
      setState(() {
        _isDeleting = true;
      });
      Health().clearHistory().then((bool result) {
        setState(() {
          _isDeleting = false;
        });
        if (result) {
          Navigator.pop(context);
        }
        else {
          AppAlert.showDialogResult(context, Localization().getStringEx('panel.health.covid19.history.message.clear_failed', 'Failed to clear COVID-19 event history'));
        }
      });
    }
  }

  void _onCancelRemoveMyInfo() {
    Analytics.instance.logAlert(text: "Remove My Information", selection: "No");
    Navigator.pop(context);
  }
}

class _HealthHistoryEntry extends StatefulWidget{
  final HealthHistory historyEntry;

  const _HealthHistoryEntry({Key key, this.historyEntry}) : super(key: key);

  @override
  _HealthHistoryEntryState createState() => _HealthHistoryEntryState();

}

class _HealthHistoryEntryState extends State<_HealthHistoryEntry> with SingleTickerProviderStateMixin{
  bool _expanded = false;
  AnimationController _controller;

  bool _sharing = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    _controller = AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    
    List<Widget> content = <Widget>[];
    content.add(Container(height: 16,));
    content.add(_buildCommonInfo(),);
    
    if ((widget.historyEntry?.isTestVerified ?? false) || HealthEventExtra.listHasVisible(widget.historyEntry?.blob?.extras)) {
      content.add(_buildMoreButton());
      
      if (_expanded) {
        
        Widget testResult = ((widget.historyEntry?.isTestVerified ?? false) && (widget.historyEntry?.blob?.testResult != null)) ? _buildTestResult() : null;
        Widget additionalInfo = _buildAdditionalInfo();
        
        if (testResult != null) {
          content.add(testResult);
        }

        if ((testResult != null) && (additionalInfo != null)) {
          content.add(_buildSplitter());
        }

        if (additionalInfo != null) {
          content.add(additionalInfo);
        }
      }
    }
    
    content.add(Container(height: 16,));
    
    return Column(children: content,);
  }

  Widget _buildCommonInfo(){
    String title;
    List<Widget> details = <Widget>[];
    String dateFormat = 'MMMM d, yyyy H:mm a';
    if (widget.historyEntry != null) {
      if (widget.historyEntry.isTest) {
        title = widget.historyEntry?.blob?.testType ?? Localization().getStringEx("app.common.label.other", "Other");

        bool isManualTest = widget.historyEntry?.isManualTest ?? false;
        String providerIcon = isManualTest? "images/u.png": "images/provider.png";
        String providerTitle = isManualTest ?
          Localization().getStringEx("panel.health.covid19.history.label.provider.self_reported", "Self reported") :
          (widget.historyEntry?.blob?.provider ?? Localization().getStringEx("app.common.label.other", "Other"));

        bool isVerifiedTest = widget.historyEntry?.isTestVerified ?? false;
        String verifiedIcon = isVerifiedTest ? "images/certified-copy.png": "images/pending.png";
        String verifiedTitle = isVerifiedTest ?
          Localization().getStringEx("panel.health.covid19.history.label.verified", "Verified") :
          Localization().getStringEx("panel.health.covid19.history.label.verification_pending", "Verification Pending");

        details.addAll(<Widget>[
          Row(children: <Widget>[
            Image.asset(providerIcon, color: Styles().colors.fillColorSecondary, excludeFromSemantics: true,),
            Container(width: 10,),
            Semantics(label: Localization().getStringEx("panel.health.covid19.history.label.provider.hint", "provider: "), child:
              Text(providerTitle, style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface,))
            )
          ],),
          Row(children: <Widget>[
            Image.asset(verifiedIcon, excludeFromSemantics: true,),
            Container(width: 10,),
            Expanded(child: Text(verifiedTitle, style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface,))),
          ],),
        ]);
      }
      else if (widget.historyEntry.isSymptoms) {
        title = Localization().getStringEx("panel.health.covid19.history.label.self_reported.title", "Self Reported Symptoms");
        details.add(Semantics(label: Localization().getStringEx("panel.health.covid19.history.label.self_reported.symptoms","symptoms: "), child:
          Text(widget.historyEntry.blob?.symptomsDisplayString(rules: Health().rules) ?? '', style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground,))
        ),);
      }
      else if (widget.historyEntry.isContactTrace) {
        dateFormat = 'MMMM d, yyyy';
        title = Localization().getStringEx("panel.health.covid19.history.label.contact_trace.title", "Contact Trace");
        details.add(Semantics(label: Localization().getStringEx("panel.health.covid19.history.label.contact_trace.details","contact trace: "), child:
          Text(widget.historyEntry.blob?.traceDurationDisplayString ?? '', style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground,))
        ),);
      }
      else if (widget.historyEntry.isVaccine) {
        title = (widget.historyEntry?.blob?.vaccinated == true) ?
          Localization().getStringEx("panel.health.covid19.history.label.vaccinated.title", "VACCINATED") :
          Localization().getStringEx("panel.health.covid19.history.label.vaccination.title", "VACCINATION");
        String providerTitle = widget.historyEntry?.blob?.provider ?? Localization().getStringEx("app.common.label.other", "Other");
        details.addAll(<Widget>[
          Row(children: <Widget>[
            Image.asset("images/provider.png", color: Styles().colors.fillColorSecondary, excludeFromSemantics: true,),
            Container(width: 10,),
            Semantics(label: Localization().getStringEx("panel.health.covid19.history.label.provider.hint", "provider: "), child:
              Text(providerTitle, style: TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface,))
            )
          ],),
          Row(children: <Widget>[
            Image.asset("images/certified-copy.png", excludeFromSemantics: true,),
            Container(width: 10,),
            Expanded(child: 
              Text(Localization().getStringEx("panel.health.covid19.history.label.verified", "Verified"),                         style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface,)),
            )
          ],),
        ]);
      }
      else if (widget.historyEntry.isAction) {
        title = widget.historyEntry.blob?.localeActionTitle ?? Localization().getStringEx("panel.health.covid19.history.label.action.title", "Action Required");
        details.add(Semantics(label: Localization().getStringEx("panel.health.covid19.history.label.action.details","action: "), child:
          Text(widget.historyEntry.blob?.localeActionText ?? '', style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground,))
        ));
      }
    }

    List<Widget> contentList = <Widget>[
      Padding(padding: EdgeInsets.only(bottom: 4), child: Text(AppDateTime.formatDateTime(widget.historyEntry?.dateUtc?.toLocal(), format: dateFormat, locale: Localization().currentLocale?.languageCode) ?? '', style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface,)),),
      Padding(padding: EdgeInsets.only(), child: Text(title ?? '', style:TextStyle(fontSize: 20, fontFamily: Styles().fontFamilies.extraBold, color: Styles().colors.fillColorPrimary,))),
    ];

    for (Widget detail in details) {
      contentList.add(Padding(padding: EdgeInsets.only(top: 9), child: detail));
    }

    return Semantics(sortKey: OrdinalSortKey(1), container: true, child:
      Stack(children: [
        Container(color: Styles().colors.white, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16), child:
          Row(children: <Widget>[
            Expanded(child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: contentList,),
            ),
          ]),
        ),
        _buildShareButton(),
      ]),
    );
  }

  Widget _buildTestResult() {
    bool hasDisclaimer = AppString.isStringNotEmpty(Health().rules?.localeDisclaimerHtml(widget.historyEntry?.blob));
    Widget contentData = Row(children: <Widget>[
      Padding(padding: EdgeInsets.only(left: 16), child:
        Image.asset("images/selected-black.png",excludeFromSemantics: true,),
      ),
      Container(width: 6,),
      Text(Localization().getStringEx("panel.health.covid19.history.label.result.title", "Result"),
        style: TextStyle(color: Styles().colors.textBackground,fontSize: 14, fontFamily: Styles().fontFamilies.bold,),
      ),
      Expanded(child:Container(height: 48)),
      Padding(padding: EdgeInsets.only(right: hasDisclaimer ? 36: 16), child:
        Text(widget.historyEntry.blob?.testResult,
          style: TextStyle(color: Styles().colors.textBackground,fontSize: 14, fontFamily: Styles().fontFamilies.regular,),
        ),
      ),
    ]);

    Widget contentLine = hasDisclaimer ?
      Stack(children: <Widget>[
        contentData,
        Container(alignment: Alignment.topRight, child: 
          InkWell(onTap: _onTapDisclaimer, child:
            Container(/*color: Color(0x20000000),*/ width: 48, height: 48, alignment: Alignment.center, child:
              Image.asset('images/icon-info-orange.png')
            ),
          ),
        ),
      ],) :
      contentData;

    return Semantics(sortKey: OrdinalSortKey(3), container: true, child:
      Container(color: Styles().colors.white, child:
        Column(children: <Widget>[
          contentLine,
        ],)
      ),
    );
  }

  Widget _buildSplitter() {
    return Container(color: Styles().colors.white, child:
      Column(children: <Widget>[
        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child:
          Container(height:1, color: Styles().colors.surfaceAccent,)
        ),
      ],)
    );
  }

  Widget _buildAdditionalInfo() {
    List<Widget> content = <Widget>[];
    if (_isLoadingLocation == true) {
      content.add(Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),))));
    }
    else if (widget.historyEntry?.blob?.location != null) {
      content.add(_buildDetail(
        Localization().getStringEx("panel.health.covid19.history.label.location.title", "Test Location"),
        widget.historyEntry?.blob?.location,
        onTapData: _onTapLocation,
        onTapHint: "Double tap to show location"));
    }

    if (AppCollection.isCollectionNotEmpty(widget.historyEntry?.blob?.extras)) {
      for (HealthEventExtra extra in widget.historyEntry?.blob?.extras) {
        if (extra.isVisible) {
          content.add(_buildDetail(
            extra.localeDisplayName,
            extra.localeDisplayValue ?? '-'));
        }
      }
    }

    //content.add(_buildDetail(Localization().getStringEx("panel.health.covid19.history.label.technician_name.title","Technician Name"), widget.historyEntry?.technician)),
    //content.add(_buildDetail(Localization().getStringEx("panel.health.covid19.history.label.technician_id.title","Technician ID"), widget.historyEntry?.technicianId)),

    return  (0 < content.length) ? Semantics(sortKey: OrdinalSortKey(4), container: true, child:
      Container(color: Styles().colors.white, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child:
        Column(children: content,
          )
        )
      ) : null;
  }

  Widget _buildMoreButton(){
    final Animatable<double> _halfTween = Tween<double>(begin: 0.0, end: 0.5);
    final Animatable<double> _easeInTween = CurveTween(curve: Curves.easeIn);
    Animation<double> _iconTurns = _controller.drive(_halfTween.chain(_easeInTween));

    return
      Semantics(
        sortKey: OrdinalSortKey(2),
        container: true,
        button: true,
        child: InkWell(
          onTap: (){
            setState(() {
              _expanded = !_expanded;
            });
            if (_expanded) {
              _controller.forward();
            } else {
              _controller.reverse();
            }
          },
          child: Container(
            decoration: BoxDecoration(color: Styles().colors.background, border: Border.all(color: Styles().colors.surfaceAccent,)),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: <Widget>[
              Text(Localization().getStringEx("panel.health.covid19.history.label.more_info.title","More Info"),
                style: TextStyle(color: Styles().colors.fillColorPrimary,fontSize: 16, fontFamily: Styles().fontFamilies.bold,),
              ),
              Expanded(child: Container(),),
              Container(width: 4,),
              RotationTransition(
                  turns: _iconTurns,
                  child: Image.asset("images/icon-down-orange.png", color: Styles().colors.fillColorSecondary, excludeFromSemantics: true,)),

            ],)
      )));
  }

  Widget _buildDetail(String title, String data, {GestureTapCallback onTapData, String onTapHint}) {

    TextStyle dataTextStyle = (onTapData != null) ?
      TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.fillColorSecondary, decoration: TextDecoration.underline) :
      TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground);

    Widget dataContentWidget = Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text(data ?? "", style: dataTextStyle, ));

    Widget dataWidget = (onTapData != null) ?
      GestureDetector(onTap: () { onTapData(); } ,
        child: Semantics(label: data, hint: onTapHint, button: true, excludeSemantics: true,
            child: dataContentWidget
      )) :
      dataContentWidget;

    return
      Row(crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(padding: EdgeInsets.symmetric(vertical: 4), child:
            Text(title,
              style: TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.bold, color: Styles().colors.textBackground),
            ),
          ),
          Expanded(child: Container()),
          dataWidget,
        ],
    );
  }

  Widget _buildShareButton() {
    return Visibility(visible: (widget.historyEntry.isTest == true), child:
      Align(alignment: Alignment.topRight, child:
        Semantics (button: true, label: "Share", child:
          GestureDetector(onTap: () { _onTapShare(); }, child:
            Container(width: 36, height: 36, child:
              Stack(children: [
                Align(alignment: Alignment.center, child:
                  Semantics(excludeSemantics: true, child:
                    Image.asset('images/icon-share.png')
                  ),
                ),
                Visibility(visible: _sharing, child:
                  Align(alignment: Alignment.center, child:
                    Container(width: 16, height: 16, child:
                      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
                    ),
                  ),
                ),
              ],),
            ),
          ),
        ),
      ),
    );
  }

  void _onTapLocation() {
    Analytics().logSelect(target: widget.historyEntry?.blob?.locationId);
    String locationId = widget.historyEntry?.blob?.locationId;
    if(locationId!=null){
      setState(() => _isLoadingLocation = true);
      Health().loadLocation(locationId: locationId).then((location){
        setState(() => _isLoadingLocation = false);
        if(location!=null){
          NativeCommunicator().launchMap(
              target: {
                'latitude': location?.latitude,
                'longitude': location?.longitude,
                'zoom': 17,
              },
              markers: [{
                'name': location?.name,
                'latitude': location?.latitude,
                'longitude': location?.longitude,
                'description': null,
              }]
          );
        } else {
          //error
          AppToast.show("Unable to load location");
        }
      });
    } else {
      //missing location id
      AppToast.show("Missing location id");
    }
  }

  void _onTapDisclaimer() {
    Analytics.instance.logSelect(target: "Disclaimer");
    String disclaimerHtml = Health().rules?.localeDisclaimerHtml(widget.historyEntry?.blob);
    if (AppString.isStringNotEmpty(disclaimerHtml)) {
      showDialog(context: context, builder: (context) => _buildDisclaimerDialog(context, disclaimerHtml));
    }
  }

  Widget _buildDisclaimerDialog(BuildContext context, String htmlContent) {
    Style htmlStyle = Style(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.bold, fontSize: FontSize(16));
    return ClipRRect(borderRadius: BorderRadius.all(Radius.circular(8)), child:
      Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),), child:
        Stack(children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16), child:
            SingleChildScrollView(child: 
              Html(data: htmlContent, style: { 'body': htmlStyle }, onLinkTap: (url) => launch(url)),
            ),
          ),
          Container(alignment: Alignment.topRight, height: 42, child: InkWell(onTap: _onCloseDisclaimerDialog, child: Container(width: 42, height: 42, alignment: Alignment.center, child: Image.asset('images/close-orange.png')))),
        ],),
      ),
    );
  }

  void _onCloseDisclaimerDialog() {
    Analytics.instance.logSelect(target: "Close Disclaimer");
    Navigator.of(context).pop();
  }

  void _onTapShare() {
    if (!_sharing) {
      setState(() {
        _sharing = true;
      });
      _createTestResultPdf().then((File pdfFile) {
        if (mounted) {
          setState(() {
            _sharing = false;
          });
          if (pdfFile != null) {
            String subject = "${widget?.historyEntry?.blob?.testType} test result";
            String text = "${widget?.historyEntry?.blob?.testType} test result";
            String mimeType = "application/pdf";
            String pdfFilePath = pdfFile.path;
            try {
              Share.shareFiles([pdfFilePath], subject: subject, text: text, mimeTypes: [mimeType]);
            }
            catch(e) {
              print(e?.toString());
              AppAlert.showDialogResult(context, "Unable to share test result document");
            }
          }
          else {
            AppAlert.showDialogResult(context, "Unable to prepare test result document");
          }
        }
      });
    }
  }

  Future<File> _createTestResultPdf() async {
    String htmlSource = await rootBundle.loadString('assets/test.result.html');

    DateTime testTime = widget?.historyEntry?.dateUtc?.toLocal();
    htmlSource = htmlSource.replaceAll('{USER_NAME}', Auth().fullUserName?.toUpperCase() ?? '');
    htmlSource = htmlSource.replaceAll('{PROVIDER_NAME}', widget?.historyEntry?.blob?.provider ?? '');
    htmlSource = htmlSource.replaceAll('{TEST_NAME}', widget?.historyEntry?.blob?.testType?.toUpperCase() ?? '');
    htmlSource = htmlSource.replaceAll('{TEST_RESULT}', widget?.historyEntry?.blob?.testResult?.toUpperCase() ?? '');
    htmlSource = htmlSource.replaceAll('{TEST_DATE}', (testTime != null) ? DateFormat("M/d/yy").format(testTime) : '-');
    htmlSource = htmlSource.replaceAll('{TEST_TIME}', (testTime != null) ? DateFormat("H:mm a").format(testTime) : '');
    
    Directory appDocDir = await getTemporaryDirectory();
    String targetPath = appDocDir.path;
    String targetFileName = "test-result";

    try { return await FlutterHtmlToPdf.convertFromHtmlContent(htmlSource, targetPath, targetFileName); }
    catch(e) { print(e?.toString()); }
    return null;
  }

}
