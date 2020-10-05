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

import 'package:flutter/material.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19DebugActionPanel extends StatefulWidget {

  Covid19DebugActionPanel();

  @override
  _Covid19DebugActionPanelState createState() => _Covid19DebugActionPanelState();
}

class _Covid19DebugActionPanelState extends State<Covid19DebugActionPanel> {

  DateTime _selectedDate;
  TextEditingController _typeController;
  FocusNode _typeNode;

  TextEditingController _textController;
  FocusNode _textNode;

  TextEditingController _intervalController;
  FocusNode _intervalNode;

  bool _submitting;
  
  @override
  void initState() {
    super.initState();
    _typeController = TextEditingController(text: 'quarantine');
    _typeNode = FocusNode();

    _textController = TextEditingController(text: 'You are quarantined. Take two PCR tests after 4 days.');
    _textNode = FocusNode();

    _intervalController = TextEditingController(text: '2');
    _intervalNode = FocusNode();
  }

  @override
  void dispose() {
    super.dispose();
    _typeController.dispose();
    _typeNode.dispose();

    _textController.dispose();
    _textNode.dispose();

    _intervalController.dispose();
    _intervalNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text("COVID-19 Action", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildHeading(),
                      _buildContent(),
                    ],
                  ),
              ),
            ),
            _buildSubmit(),
          ],
        ),
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildHeading() {

    return Semantics(container: true, child:
      Container(color:Colors.white,
      child: Padding(padding: EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children:<Widget>[
            Row(children: <Widget>[
              Padding(padding: EdgeInsets.only(right: 4), child: Image.asset('images/campus-tools-blue.png',excludeFromSemantics: true,)),
              Text("Create COVID-19 Action", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
            ],),
          ]),
      ),
    ));
  }


  Widget _buildContent() {
    String dateText = _selectedDate != null ? AppDateTime.formatDateTime(_selectedDate, format: 'MM/dd/yyyy') : "-";
    return Padding(padding: EdgeInsets.all(32),
      child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: <Widget>[
          Semantics(container: true, child:
            Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Padding(padding: EdgeInsets.only(bottom: 4),
                  child: Text(Localization().getStringEx("panel.health.covid19.debug.trace.label.date","Date"), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
                ),
                GestureDetector(onTap: _onTapPickDate,
                  child: Container(height: 48,
                    decoration: BoxDecoration(
                        border: Border.all(color: Styles().colors.surfaceAccent, width: 1),
                        borderRadius: BorderRadius.all(Radius.circular(4))),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          AppString.getDefaultEmptyString(value: dateText, defaultValue: '-'),
                          style: TextStyle(
                              color: Styles().colors.fillColorPrimary,
                              fontSize: 16,
                              fontFamily: Styles().fontFamilies.medium),
                        ),
                        Image.asset('images/icon-down-orange.png')
                      ],
                    ),
                  ),
                ),
              ],),
            ),
          ),


          Padding(padding: EdgeInsets.symmetric(vertical: 8), child: 
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Padding(padding: EdgeInsets.only(bottom: 4),
                child: Text("Type", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
              ),
              Semantics(textField: true, child:Container(color: Styles().colors.white,
                child: TextField(
                  controller: _typeController,
                  focusNode: _typeNode,
                  decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0)), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
                ),
              )),
            ],),
          ),

          Padding(padding: EdgeInsets.symmetric(vertical: 8), child: 
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Padding(padding: EdgeInsets.only(bottom: 4),
                child: Text("Text", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
              ),
              Semantics(textField: true, child:Container(color: Styles().colors.white,
                child: TextField(
                  controller: _textController,
                  focusNode: _textNode,
                  decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0)), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
                ),
              )),
            ],),
          ),

          /*Padding(padding: EdgeInsets.symmetric(vertical: 8), child: 
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Padding(padding: EdgeInsets.only(bottom: 4),
                child: Text("Interval (days)", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
              ),
              Semantics(textField: true, child:Container(color: Styles().colors.white,
                child: TextField(
                  controller: _intervalController,
                  focusNode: _intervalNode,
                  decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0)), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
                ),
              )),
            ],),
          ),*/

      ]),
    );
  }

  Widget _buildSubmit() {
    return Padding(padding: EdgeInsets.all(16),
      child: Stack(children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Container(),),
          RoundedButton(label: "Submit Action",
            textColor: Styles().colors.fillColorPrimary,
            borderColor: Styles().colors.fillColorSecondary,
            backgroundColor: Styles().colors.white,
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16,
            padding: EdgeInsets.symmetric(horizontal: 32, ),
            borderWidth: 2,
            height: 42,
            onTap:() { _onSubmit();  }
          ),
          Expanded(child: Container(),),
        ],),
        Visibility(visible: (_submitting == true), child:
          Center(child:
            Padding(padding: EdgeInsets.only(top: 10.5), child:
              Container(width: 21, height:21, child:
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
              ),
            ),
          ),
        ),
      ],),
    );
  }

  void _onTapPickDate() {
    DateTime initialDate = (_selectedDate != null) ? _selectedDate : DateTime.now();
    DateTime firstDate = initialDate.subtract(new Duration(days: 365 * 5));
    DateTime lastDate = initialDate.add(new Duration(days: 365 * 5));
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (BuildContext context, Widget child) {
        return Theme(data: ThemeData.light(), child: child,);
      },
    ).then((DateTime result) {
      if (mounted && (result != null)) {
        setState(() {
          _selectedDate = result;
        });
      }
    });
  }

  void _onSubmit() {
      if (_selectedDate == null) {
        AppAlert.showDialogResult(context, "Please select a date").then((_) {
          _onTapPickDate();
        });
        return;
      }
      DateTime dateUtc = _selectedDate.toUtc();

      String actionType = _typeController.text;
      if (AppString.isStringEmpty(actionType)) {
        AppAlert.showDialogResult(context, "Please enter an type").then((value) {
          _typeNode.requestFocus();
        });
        return;
      }

      String actionText = _textController.text;
      if (AppString.isStringEmpty(actionText)) {
        AppAlert.showDialogResult(context, "Please enter an text").then((value) {
          _textNode.requestFocus();
        });
        return;
      }

      /*int actionInterval = int.tryParse(_intervalController.text);
      if (actionInterval == null) {
        AppAlert.showDialogResult(context, "Please enter an integer interval").then((value) {
          _intervalNode.requestFocus();
        });
        return;
      }*/

      setState(() {
        _submitting = true;
      });
      
      Health().processAction({
        'health.covid19.action.date': healthDateTimeToString(dateUtc),
        'health.covid19.action.type': actionType,
        'health.covid19.action.text': actionText,
      }).then((bool result) {
        if (mounted) {
          setState(() {
            _submitting = false;
          });
          if (result != true) {
            AppAlert.showDialogResult(context,Localization().getStringEx("panel.health.covid19.debug.trace.error.submit.text", "Failed to submit contact trace data."));
          }
          else {
            Navigator.of(context).pop();
          }
        }
      });
  }
}
