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
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19DebugRulesPanel extends StatefulWidget{
  Covid19DebugRulesPanel();

  _Covid19DebugRulesPanelState createState() => _Covid19DebugRulesPanelState();
}

class _Covid19DebugRulesPanelState extends State<Covid19DebugRulesPanel>{

  static const List<String> validGroups = [
    "urn:mace:uiuc.edu:urbana:authman:app-rokwire-service-policy-rokwire public health",
    "urn:mace:uiuc.edu:urbana:authman:app-rokwire-service-policy-rokwire admin app"
  ];



  bool _submitting = false;
  bool _countiesLoading = false;
  bool _rulesLoading = false;

  TextEditingController _rulesValueController = TextEditingController();

  String _selectedCountyId;
  LinkedHashMap<String, HealthCounty> _counties;

  @override
  void initState() {
    super.initState();

    _selectedCountyId = Health().currentCountyId;

    setState(() {
      _countiesLoading = true;
    });
    Health().loadCounties().then((counties){
      if(AppCollection.isCollectionNotEmpty(counties)){
        if (mounted) {
          setState(() {
            try {
              _counties = (counties != null) ? Map<String,HealthCounty>.fromIterable(counties, key: ((county) => county.id)): null;
            }
            catch(e) {
              Log.e(e.toString());
            }
          });
        }
      }
    }).whenComplete((){
      setState(() {
        _countiesLoading = false;
      });
      _loadRules();
    });
  }

  void _loadRules(){
    if(_selectedCountyId != null) {
      setState(() {
        _rulesLoading = true;
      });
      Health().loadRules2String(countyId: _selectedCountyId, force: true).then((value) {
        _rulesValueController.text = value ?? "";
      }).whenComplete((){
        setState(() {
          _rulesLoading = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text("COVID-19 Rules", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
      ),
      body: SafeArea(child:
      Column(children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            child: _buildContent(),
          ),
        ),
        _buildSubmit(),
      ],),
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildContent(){
    if(_countiesLoading){
      return Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Padding(padding: EdgeInsets.only(bottom: 4),
              child: Text("County", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
            ),
            Container(decoration: BoxDecoration(color: Styles().colors.white, border: Border.all(color: Colors.black, width: 1), borderRadius: BorderRadius.all(Radius.circular(4))),
              child: Padding(padding: EdgeInsets.only(left: 12, right: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton(
                      icon: Image.asset('images/icon-down-orange.png', excludeFromSemantics: true,),
                      isExpanded: true,
                      style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
                      hint: Text(_selectedCounty?.name ?? "Select a county...",style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
                      items: _buildProviderDropDownItems(_counties?.values),
                      onChanged: (value) { setState(() {
                        _selectedCountyId = value?.id;
                        _loadRules();
                      });}
                  ),
                ),
              ),
            )
          ],),
          Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Padding(padding: EdgeInsets.only(bottom: 4),
                child: Text("Rules", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
              ),
              Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Semantics(textField: true, child:Container(color: Styles().colors.white,
                        child: TextField(
                          maxLines: 15,
                          controller: _rulesValueController,
                          decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
                        ),
                      )
                    ),
                    _rulesLoading ? Align(alignment: Alignment.center,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),),
                    ) : Container(),
                    Positioned.fill(
                      child: Align(alignment: Alignment.topRight,
                        child: Semantics (button: true, label: "Clear",
                          child: GestureDetector(onTap: () { _onTapClearRules(); },
                            child: Container(width: 36, height: 36,
                              child: Align(alignment: Alignment.center,
                                child: Semantics( excludeSemantics: true,child:Text('X', style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.fillColorPrimary,),)),
                              ),
                            ),
                          ),
                        )),
                    ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmit() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Stack(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Container(),
              ),
              RoundedButton(
                  label: "Save",
                  textColor: Health().isUserLoggedIn && hasValidGroup ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
                  borderColor: Health().isUserLoggedIn  && hasValidGroup ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColor,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32,
                  ),
                  borderWidth: 2,
                  height: 42,
                  onTap: () {
                    _onSubmit();
                  }),
              Expanded(
                child: Container(),
              ),
            ],
          ),
          Visibility(
            visible: (_submitting == true),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 10.5),
                child: Container(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),
                      strokeWidth: 2,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<dynamic>> _buildProviderDropDownItems(Iterable<HealthCounty> items) {
    return (items != null) ? items.map((HealthCounty item) {
      return DropdownMenuItem<dynamic>(value: item, child: Text(item.name),);
    }).toList() : null;
  }

  HealthCounty get _selectedCounty{
    return _selectedCountyId != null && _counties != null ? _counties[_selectedCountyId] : null;
  }

  String get validGroup{
    for(String group in validGroups){
      if(Auth()?.authInfo?.userGroupMembership?.contains(group) ?? false){
        return group;
      }
    }
    return null;
  }

  bool get hasValidGroup{
    return AppString.isStringNotEmpty(validGroup);
  }

  void _onSubmit(){
    if(!_submitting && hasValidGroup) {
      setState(() {
        _submitting = true;
      });
      Health().saveRules(countyId: _selectedCountyId, rulesContent: _rulesValueController.text, userGroup: validGroup).then((value){
        setState(() {
          _submitting = false;
        });
      }).catchError((error){
        setState(() {
          _submitting = false;
        });
        AppAlert.showDialogResult(context, error.toString());
      });
    }
  }

  void _onTapClearRules(){
    _rulesValueController.text = "";
  }
}