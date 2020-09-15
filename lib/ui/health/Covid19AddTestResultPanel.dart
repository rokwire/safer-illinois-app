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
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/OSFHealth.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/health/Covid19ReportTestPanel.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19AddTestResultPanel extends StatefulWidget {

  Covid19AddTestResultPanel();

  @override
  _Covid19AddTestResultPanelState createState() => _Covid19AddTestResultPanelState();
}

class _Covid19AddTestResultPanelState extends State<Covid19AddTestResultPanel> implements NotificationsListener {

  bool __loading = false;
  bool get _loading => __loading;
  set _loading(bool value){
    setState(() {
      __loading = value;
    });
  }


  bool __retrieving = false;
  bool get _retrieving => __retrieving;
  set _retrieving(bool value){
    setState(() {
      __retrieving = value;
    });
  }



  List<ProviderDropDownItem>_providerItems;
  ProviderDropDownItem _selectedProviderItem;
  HealthServiceProvider _initialProvider;

  @override
  void initState() {
    _initialProvider = Storage().lastHealthProvider;
    NotificationService().subscribe(this, [
      OSFHealth.notifyOnFetchBegin, OSFHealth.notifyOnFetchFinished
    ]);
    _loadProviders();
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  void handleOnFinished(dynamic param){
    if(param is Map){
      int processedEntriesCount = param['processedEntriesCount'];
      if(processedEntriesCount == null || processedEntriesCount == 0){
        AppAlert.showDialogResult(context, Localization().getStringEx("panel.health.covid19.add_test.message.no_result_found", "No results found",)).then((value) => Navigator.pop(context));
      } else {
        Navigator.pop(context);
      }
    }
  }

  // NotificationsListener
  
  @override
  void onNotification(String name, dynamic param) {
    if (name == OSFHealth.notifyOnFetchBegin) {
      _retrieving = true;
    } else if (name == OSFHealth.notifyOnFetchFinished) {
      _retrieving = false;
      handleOnFinished(param);
    }
  }

  void _loadProviders() {
    _loading = true;
    Health().loadHealthServiceProviders().then((List<HealthServiceProvider> providers){
      _providerItems = List<ProviderDropDownItem>();
      if(providers?.isNotEmpty?? false) {
        _providerItems.addAll(providers?.map((HealthServiceProvider provider) {
          ProviderDropDownItem item = ProviderDropDownItem(type: ProviderDropDownItemType.provider, item: provider);
          //Initial selection
          if (_selectedProviderItem == null && _initialProvider != null) {
            // If we don't have selection but have previously selected providerId
            if (provider?.id == _initialProvider?.id) {
              _selectedProviderItem = item;
            }
          }
          return item;
        })?.toList());
      }
      // "Hide 'Other' as a provider in manual test panel"
      // _providerItems.add(ProviderDropDownItem(type: ProviderDropDownItemType.other, item: null));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SimpleHeaderBarWithBack(
          context: context,
          titleWidget: Text(Localization().getStringEx("panel.health.covid19.add_test.heading.title","Add Test Result"), style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
        ),
        backgroundColor: Styles().colors.white,
        body: _loading? _buildLoading() : _buildContent());
  }

  Widget _buildContent() {
    bool manualTestsDisabledVisible = (_selectedProviderItem != null) && (!_canManuallyEnterResult && !_canRetrieve) && !_retrieving;
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child:
              Container(
                color: Styles().colors.background,
                padding: EdgeInsets.only(left: 24, right: 24,top: 23, bottom: 2),
                child: Text(Localization().getStringEx("panel.health.covid19.add_test.label.where_question","Where was the test taken?"), textAlign:TextAlign.left,style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20, fontFamily: Styles().fontFamilies.bold),),
              )),
            ],),
          Container(
          color: Styles().colors.background,
          child:Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child:
              Container(
                padding: EdgeInsets.only(left: 24, right: 5, bottom: 19, top: 5),
                child: Text(Localization().getStringEx("panel.health.covid19.add_test.label.information","Why is this information needed?"), textAlign:TextAlign.left,style: TextStyle(color: Styles().colors.textSurface, fontSize: 14, fontFamily: Styles().fontFamilies.regular),),
            ),),
            Container(
              child: Semantics(
                label: Localization().getStringEx( "panel.health.covid19.history.label.more_info.title","More Info"),
              child: InkWell(
                onTap: _onTapMoreInfo,
                child:Container(
                  padding: EdgeInsets.all(5),
                  child: Image.asset("images/icon-more-info.png")),
              ))
            ),
          ],)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: <Widget>[
                Container(height: 29,),
                Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Localization().getStringEx("panel.health.covid19.add_test.label.provider.title","Healthcare Provider"),
                    style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold,letterSpacing: 0.86),
                  ),
                ),
                Container(height: 8,),
                Container(
                  decoration: BoxDecoration(
                  border: Border.all(
                  color: Styles().colors.surfaceAccent,
                  width: 1),
                  borderRadius:
                  BorderRadius.all(Radius.circular(4))),
                  child: Padding(
                  padding: EdgeInsets.only(left: 12, right: 16),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton(
                    icon: Image.asset(
                    'images/icon-down-orange.png'),
                    isExpanded: true,
                    style: TextStyle(
                    color: Styles().colors.mediumGray,
                    fontSize: 16,
                    fontFamily:
                    Styles().fontFamilies.regular),
                    hint: Text(_selectedProviderItem?.title ?? Localization().getStringEx("panel.health.covid19.add_test.label.provider.empty_hint","Select a provider")),
                    items: _buildProviderDropDownItems(),
                    onChanged: (ProviderDropDownItem value)=>setState((){
                      Analytics.instance.logSelect(target: "Selected provider: "+value?.title);
                      _selectedProviderItem = value;
                      if(value!= null && ProviderDropDownItemType.provider == value.type ){
                        Storage().lastHealthProvider= value.item;
                      }
                    }),
                    )),
                  ),
                ),
                Row(children: <Widget>[
                  Expanded(child: Container( alignment: Alignment.center,
                    child: Visibility(
                      visible: manualTestsDisabledVisible,
                      child: Text(Localization().getStringEx( "panel.health.covid19.add_test.label.manual_tests_disabled","Test results from this health care provider will automatically appear if you have consented to Health Provider Test Results in settings and you are connected with your NetID."),
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textSurface),))
                  ),),
                ],),
            ])),
          Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 36),
          alignment: Alignment.bottomCenter,
            child:
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,children: <Widget>[
                _canRetrieve ? Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    ScalableRoundedButton(
                      label: Localization().getStringEx("panel.health.covid19.add_test.button.retreive.title","Retrieve Results"),
                      onTap: _canRetrieve?_onTapRetrieveResult: (){},
                      enabled: _canRetrieve,
                      backgroundColor: Styles().colors.white,
                      borderColor: _canRetrieve? Styles().colors.fillColorSecondary : Styles().colors.surfaceAccent ,
                      textColor: _canRetrieve? Styles().colors.fillColorSecondary : Styles().colors.surfaceAccent ,
                      showExternalLink: true,
                    ),
                    _retrieving ? Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),)) : Container(),
                  ],
                ) : Container(),
                Container(height: (_canRetrieve && _canManuallyEnterResult) ? 12 : 0,),
                _canManuallyEnterResult ? ScalableRoundedButton(
                    label:  Localization().getStringEx("panel.health.covid19.add_test.button.enter_manually.title","Manually Enter"),
                    onTap: _canManuallyEnterResult?_onTapEnterManualTest : (){},
                    enabled: _canManuallyEnterResult,
                    backgroundColor: Styles().colors.white,
                    borderColor:_canManuallyEnterResult? Styles().colors.fillColorSecondary : Styles().colors.surfaceAccent ,
                    textColor: _canManuallyEnterResult? Styles().colors.fillColorSecondary : Styles().colors.surfaceAccent ) : Container(),
                Container(height: 26,)
      ],))]));
  }

  List<DropdownMenuItem<ProviderDropDownItem>> _buildProviderDropDownItems() {
    int itemsCount = _providerItems?.length ?? 0;
    if (itemsCount == 0) {
      return null;
    }
    List<DropdownMenuItem<ProviderDropDownItem>> items = List<DropdownMenuItem<ProviderDropDownItem>>();
    try{
      items.addAll(_providerItems.map((ProviderDropDownItem item) {
        return DropdownMenuItem<ProviderDropDownItem>(
          value: item,
          child: Text(item?.title),
        );
      }).toList());
    } catch(e){
      print(e);
    }

    return items;
  }

  Widget _buildLoading(){
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,),),
          )
        ]);
  }

  void _onTapRetrieveResult() {
    if(_canRetrieve && !_retrieving) {
      Analytics.instance.logSelect(target: "Retrieve Results");
      OSFHealth().authenticate();
    }
  }



  //Future<void> _loadData() async{}

  void _onTapEnterManualTest() {
    Analytics.instance.logSelect(target: "Manually Enter");
    Navigator.push(context, CupertinoPageRoute(builder: (context)=>Covid19ReportTestPanel(provider: _selectedProviderItem.item,))).then((success){
      if(success!= null)
        Navigator.pop(context);
    });
  }

  void _onTapMoreInfo(){
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              color: Styles().colors.fillColorPrimary,
              padding: EdgeInsets.all(18),
              child:Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                  Expanded(child:
                    Container(child:
                      Semantics(container: true,child:
                        Column(children: <Widget>[
                         RichText(
                          textScaleFactor: MediaQuery.textScaleFactorOf(context),
                          maxLines: 50,
                          text: new TextSpan(
                            // Note: Styles for TextSpans must be explicitly defined.
                            // Child text spans will inherit styles from parent
                            style: new TextStyle(
                            fontSize: 16.0,
                            color: Styles().colors.white,
                          ),
                          children: <TextSpan>[
                            new TextSpan(text: Localization().getStringEx("panel.health.covid19.add_test.label.info.retrieved.text1", "Results ")),
                            new TextSpan(text: Localization().getStringEx("panel.health.covid19.add_test.label.info.retrieved.text2", "retrieved "), style: new TextStyle(fontWeight: FontWeight.bold)),
                            new TextSpan(text: Localization().getStringEx("panel.health.covid19.add_test.label.info.retrieved.text3", "from your healthcare provider are instantly verified. Any changes to your health status will be reflected instantly.")),
                          ],
                        )),
                        Container(height: 20,),
                        RichText(
                            textScaleFactor: MediaQuery.textScaleFactorOf(context),
                            maxLines: 50,
                            text: new TextSpan(
                              // Note: Styles for TextSpans must be explicitly defined.
                              // Child text spans will inherit styles from parent
                              style: new TextStyle(
                                fontSize: 16.0,
                                color: Styles().colors.white,
                              ),
                              children: <TextSpan>[
                                new TextSpan(text: Localization().getStringEx("panel.health.covid19.add_test.label.info.manually.text1", "Results ")),
                                new TextSpan(text: Localization().getStringEx("panel.health.covid19.add_test.label.info.manually.text2", "entered manually "), style: new TextStyle(fontWeight: FontWeight.bold)),
                                new TextSpan(text: Localization().getStringEx("panel.health.covid19.add_test.label.info.manually.text3", "will be reviewed and verified by a public healthcare provider. Once verified, status changes may occur.")),
                              ]
                            )
                        )])))),
                  Container(width: 8,),
                  Container(child:
                    Semantics(label: Localization().getStringEx("dialog.close.title", "Close"), button: true,child:
                      GestureDetector(
                          onTap: (){Navigator.pop(context);},
                          child: Container(child:Image.asset("images/close-orange.png", excludeFromSemantics: true,)),
                      )  ))
          ],)))]);
      },
    );
  }

  bool get _canRetrieve {
    if (_selectedProviderItem?.item == null) { //'Other' provider
      return false;
    }
    bool allowManualTest = (_selectedProviderItem?.item?.allowManualTest ?? false);
    bool isEpicMechanism = (_selectedProviderItem?.item?.availableMechanisms?.contains(HealthServiceMechanism.epic) ?? false);
    if (isEpicMechanism && !allowManualTest) {
      return true;
    }
    if (!allowManualTest) {
      return false;
    }
    return true;
  }

  bool get _canManuallyEnterResult {
    if (_selectedProviderItem == null) {
      return false;
    } else if (_selectedProviderItem.type == ProviderDropDownItemType.other) {
      return true;
    }
    return (_selectedProviderItem?.item?.allowManualTest ?? false);
  }
}

enum ProviderDropDownItemType{
  provider, other
}

class ProviderDropDownItem{
  final ProviderDropDownItemType type;
  final HealthServiceProvider item;

  ProviderDropDownItem({this.type, this.item});

  String get title{
    if(type == ProviderDropDownItemType.other){
      return Localization().getStringEx("app.common.label.other", "Other");
    } else {
      return item?.name ?? "";
    }
  }

  String get providerId{
    if(type == ProviderDropDownItemType.other){
      return null;
    } else {
      return item?.id;
    }
  }
}