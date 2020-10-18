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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/PopupDialog.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:sprintf/sprintf.dart';

class Covid19HistoryPanel extends StatefulWidget {
  @override
  _Covid19HistoryPanelState createState() => _Covid19HistoryPanelState();

  static show(BuildContext context, {Function onContinueTap}){
    showDialog(
        context: context,
        builder: (_) => Material(
          type: MaterialType.transparency,
          child: Covid19HistoryPanel(),
        )
    );
  }
}

class _Covid19HistoryPanelState extends State<Covid19HistoryPanel> implements NotificationsListener {
  
  List<Covid19History> _statusHistory = List();
  bool _isLoading = false;
  bool _isDeleting = false;
  bool _isReposting = false;


  @override
  void initState() {
    super.initState();

    NotificationService().subscribe(this, [
      Health.notifyUserUpdated,
      Health.notifyHistoryUpdated,
      Health.notifyProcessingFinished,
    ]);

    _loadHistory();
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);
  }

  @override
  void onNotification(String name, param) {
    if(name == Health.notifyUserUpdated){
      if (mounted) {
        setState(() {});
      }
    }
    else if (name == Health.notifyHistoryUpdated) {
      if (mounted) {
        if (param != null) {
          setState(() {
            _statusHistory = param;
            _isLoading = false;
          });
        }
        else {
          _loadHistory();
        }
      }
    }
    else if (name == Health.notifyProcessingFinished) {
      if ((param != null) && mounted) {
        setState(() {
          _statusHistory = param?.history;
          _isLoading = false;
        });
      }
    }
  }

  void _loadHistory() {

    if (_isLoading != true) {
      setState(() { _isLoading = true; });
      
      Health().loadUpdatedHistory().then((List<Covid19History> history) {
        if (mounted) {
          setState(() {
            if (history != null) {
              _statusHistory = Covid19History.pastList(history);
            }
            _isLoading = (Health().processing == true);
          });
        }
      });
    }
  }

  void _repostHistory(){

    if(!_isReposting) {
      setState(() {
        _isReposting = true;
      });
      Health().repostHealthHistory().whenComplete((){
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
        child:Container(
         padding: EdgeInsets.symmetric(horizontal: 16),
        color:  Styles().colors.background,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              (_isLoading == true) ?
              Expanded(child:_buildProgress()):

              Expanded(
                child:
                _statusHistory==null || _statusHistory.isEmpty? _buildEmpty(): _buildHistoryList()
              )
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
        itemCount: _statusHistory.length + ((!kReleaseMode || Config().isDev) ? 2 : 1),
        itemBuilder: (BuildContext ctxt, int index) {
          if (index < _statusHistory.length) {
            return _Covid19HistoryEntry(history: _statusHistory[index]);
          }
          else if (index == _statusHistory.length) {
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
      Health().clearUserData().then((bool result) {
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

class _Covid19HistoryEntry extends StatefulWidget{
  final Covid19History history;

  const _Covid19HistoryEntry({Key key, this.history}) : super(key: key);

  @override
  _Covid19HistoryEntryState createState() => _Covid19HistoryEntryState();

}

class _Covid19HistoryEntryState extends State<_Covid19HistoryEntry> with SingleTickerProviderStateMixin{
  bool _expanded = false;
  AnimationController _controller;

  bool _isLoading = false;

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
    
    if (widget.history?.isTestVerified ?? false) {
      content.addAll(<Widget>[
        _buildMoreButton(),
        _buildResult(),
        _buildAdditionalInfo(),
      ]);
    }
    
    content.add(Container(height: 16,));
    
    return Container(
      padding: EdgeInsets.symmetric(),
      child: Column(children: content,),
    );
  }
  Widget _buildCommonInfo(){
    String title;
    Widget details;
    bool isVerifiedTest = false;
    bool isTest = false;
    String dateFormat = kReleaseMode ? 'MMMM d, yyyy' : 'MMMM d, yyyy HH:mm:ss';
    if (widget.history != null) {
      if (widget.history.isTest) {
        isTest = true;
        bool isManualTest = widget.history?.isManualTest ?? false;
        isVerifiedTest = widget.history?.isTestVerified ?? false;
        title = widget.history?.blob?.testType ?? Localization().getStringEx("app.common.label.other", "Other");
        details = Row(children: <Widget>[
          Image.asset(isManualTest? "images/u.png": "images/provider.png", excludeFromSemantics: true,),
          Container(width: 11,),
          Expanded(child:
            Semantics(label: Localization().getStringEx("panel.health.covid19.history.label.provider.hint", "provider: "), child:
              Text( isManualTest? Localization().getStringEx("panel.health.covid19.history.label.provider.self_reported", "Self reported"):
                (widget.history?.blob?.provider ?? Localization().getStringEx("app.common.label.other", "Other")),
                 style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface,))
          ))
        ],);
      }
      else if (widget.history.isSymptoms) {
        title = Localization().getStringEx("panel.health.covid19.history.label.self_reported.title","Self Reported Symptoms");
        details =
          Row(children: <Widget>[
            Expanded(child:
              Semantics(label: Localization().getStringEx("panel.health.covid19.history.label.self_reported.symptoms","symptoms: "), child:
               Text(widget.history.blob?.symptomsDisplayString ?? '', style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground,))
              )
            )
          ],);
      }
      else if (widget.history.isContactTrace) {
        title = Localization().getStringEx("panel.health.covid19.history.label.contact_trace.title","Contact Trace");
        details =
          Row(children: <Widget>[
            Expanded(child:
              Semantics(label: Localization().getStringEx("panel.health.covid19.history.label.contact_trace.details","contact trace: "), child:
                Text(widget.history.blob?.traceDurationDisplayString ?? '', style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground,))
          ))]);
      }
      else if (widget.history.isAction) {
        title = Localization().getStringEx("panel.health.covid19.history.label.action.title","Action Required");
        details = Semantics(label: Localization().getStringEx("panel.health.covid19.history.label.action.details","action: "), child:
            Text(widget.history.blob?.actionDisplayString ?? '', style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground,))
          );
      }
    }

      return
        Semantics(
          sortKey: OrdinalSortKey(1),
          container: true,
          child: Container(color: Styles().colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
           children: <Widget>[
             Text(AppDateTime.formatDateTime(widget.history?.dateUtc?.toLocal(), format:dateFormat) ?? '',style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface,)),
             Container(height: 4,),
             Row(children: <Widget>[
              Expanded(child:
                Text(title ?? '', style:TextStyle(fontSize: 20, fontFamily: Styles().fontFamilies.extraBold, color: Styles().colors.fillColorPrimary,)),
             )]),
             Container(height: 9,),
              details ?? Container(),
              !isTest? Container():
                Container(height: 9,),
              !isTest? Container():
              Row(children: <Widget>[
               Image.asset(isVerifiedTest? "images/certified-copy.png": "images/pending.png"),
               Container(width: 10,),
                Expanded(child:   isVerifiedTest?
                  Text(Localization().getStringEx("panel.health.covid19.history.label.verified","Verified"),style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface,)):
                  Text(Localization().getStringEx("panel.health.covid19.history.label.verification_pending","Verification Pending"),style:TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface,)),
                )
             ],),
           ],
          )
      ));
  }

  Widget _buildResult(){
    return !_expanded || widget.history?.blob?.testResult==null? Container():
    Semantics(
        sortKey: OrdinalSortKey(3),
        container: true,
        child:
        Container(color: Styles().colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child:
            Column(children: <Widget>[
              Container(height: 14,),
              Row(
                children: <Widget>[
                  Image.asset("images/selected-black.png",excludeFromSemantics: true,),
                  Container(width: 6,),
                  Text(Localization().getStringEx("panel.health.covid19.history.label.result.title","Result: "),
                    style: TextStyle(color: Styles().colors.textBackground,fontSize: 14, fontFamily: Styles().fontFamilies.bold,),
                  ),
                  Expanded(child:Container()),
                  Text(widget.history.blob?.testResult,
                    style: TextStyle(color: Styles().colors.textBackground,fontSize: 14, fontFamily: Styles().fontFamilies.regular,),
                  )
                ],
              ),
              Container(height: 14,),
              Container(height:1, color: Styles().colors.surfaceAccent,)
            ],)
        )
    );
  }

  Widget _buildAdditionalInfo(){
    return
      !_expanded ? Container():
      Semantics(
        sortKey: OrdinalSortKey(4),
        container: true,
        child:
        Container(color: Styles().colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: <Widget>[
              (_isLoading == true) ? Center(child: SizedBox(height: 24, width: 24, child:CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),))):
              widget.history?.blob?.location==null? Container():
                _buildDetail(Localization().getStringEx("panel.health.covid19.history.label.location.title","Test Location"), widget.history?.blob?.location, onTapData: (widget.history?.blob?.location != null) ? (){ _onTapLocation(); } : null, onTapHint: "Double tap to show location"),

              //_buildDetail(Localization().getStringEx("panel.health.covid19.history.label.technician_name.title","Technician Name"), widget.history?.technician),
              //_buildDetail(Localization().getStringEx("panel.health.covid19.history.label.technician_id.title","Technician ID"), widget.history?.technicianId),
            ],
          )
        )
      );
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
                  child: Image.asset("images/icon-down-orange.png")),

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
            Text(sprintf("%s: ",[title],),
              style: TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.bold, color: Styles().colors.textBackground),
            ),
          ),
          Expanded(child: Container()),
          dataWidget,
        ],
    );
  }

  void _onTapLocation() {
    Analytics().logSelect(target: widget.history?.blob?.locationId);
    String locationId = widget.history?.blob?.locationId;
    if(locationId!=null){
      setState(() => _isLoading = true);
      Health().loadHealthServiceLocation(locationId: locationId).then((location){
        setState(() => _isLoading = false);
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
}
