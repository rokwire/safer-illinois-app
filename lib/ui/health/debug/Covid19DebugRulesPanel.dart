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

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19DebugRulesPanel extends StatefulWidget{
  Covid19DebugRulesPanel();

  _Covid19DebugRulesPanelState createState() => _Covid19DebugRulesPanelState();
}

class _Covid19DebugRulesPanelState extends State<Covid19DebugRulesPanel>{

  bool _countiesLoading = false;
  bool _rulesLoading = false;

  TextEditingController _rulesValueController = TextEditingController();

  LinkedHashMap<String, HealthCounty> _counties;
  String _selectedCountyId;
  dynamic _userTestMonitorInterval = false; 

  @override
  void initState() {
    super.initState();

    _selectedCountyId = Health().currentCountyId;
    _loadCounties();
  }

  void _loadCounties() {
    setState(() {
      _countiesLoading = true;
    });
    Health().loadCounties().then((List<HealthCounty> counties) {
      if (mounted) {
        setState(() {
          // apply counties
          try { _counties = (counties != null) ? Map<String, HealthCounty>.fromIterable(counties, key: ((county) => county.id)): null; }
          catch(e) { Log.e(e.toString()); }
  
          // fix couty selection, if needed
          if ((_counties != null) && (0 < _counties.length) && (_counties[_selectedCountyId] == null)) {
            _selectedCountyId = counties[0].id;
          }

          _countiesLoading = false;
        });

        _loadRules();
      }
    });
  }

  Future<void> _loadRules() async {
    
    if (_selectedCountyId != null) {
    
      setState(() {
        _rulesLoading = true;
         _rulesValueController.text = "";
      });

      List<Future<dynamic>> futures = <Future>[
        Health().loadRules2Json(countyId: _selectedCountyId),
      ];

      if (_userTestMonitorInterval is bool) {
        futures.add(Health().loadUserTestMonitorInterval());
      }

      List<dynamic> results = await Future.wait(futures);

      Map<String, dynamic> rules = ((results != null) && (0 < results.length)) ? results[0] : null;

      if ((results != null) && (1 < results.length)) {
        _userTestMonitorInterval = results[1];
      }

      if ((rules != null) && (_userTestMonitorInterval is int)) {
        dynamic constants = rules['constants'];
        if (constants == null) {
          rules['constants'] = constants = {};
        }
        if (constants is Map) {
          constants[HealthRulesSet.UserTestMonitorInterval] = _userTestMonitorInterval;
        }
      }

      if (mounted) {
        setState(() {
          _rulesValueController.text = AppJson.encode(rules, prettify: true) ?? "";
          _rulesLoading = false;
        });
      }
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
            child: _buildContent(),
          ),
        ],),
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildContent(){
    if (_countiesLoading) {
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
          Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Container()),
          Expanded(child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Padding(padding: EdgeInsets.only(bottom: 4),
                child: Text("Rules", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
              ),
              Expanded(child:
                Stack(alignment: Alignment.center, children: <Widget>[
                  TextField(controller: _rulesValueController, expands: true, maxLines: null, readOnly: true,
                    decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))),
                    style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
                  ),
                  Visibility(visible: _rulesLoading, child: Align(alignment: Alignment.center,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),),
                  ),),
                  Visibility(visible: (0 < _rulesValueController.text.length),
                    child: Positioned.fill(
                      child: Align(alignment: Alignment.topRight,
                        child: Semantics (button: true, label: "Copy",
                          child: GestureDetector(onTap: () { _onTapCopyRules(); },
                            child: Container(width: 36, height: 36,
                              child: Align(alignment: Alignment.center,
                                child: Semantics( excludeSemantics: true, child: Image.asset('images/icon-copy.png')),
                              ),
                            ),
                          ),
                        )
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
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

  HealthCounty get _selectedCounty {
    return _selectedCountyId != null && _counties != null ? _counties[_selectedCountyId] : null;
  }

  void _onTapCopyRules() {
    Clipboard.setData(ClipboardData(text: _rulesValueController.text));
    AppAlert.showDialogResult(context, "Rules copied to Clipboard");
  }
}