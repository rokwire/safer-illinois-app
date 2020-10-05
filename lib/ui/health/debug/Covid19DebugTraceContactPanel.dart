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
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19DebugTraceContactPanel extends StatefulWidget {

  Covid19DebugTraceContactPanel();

  @override
  _Covid19DebugTraceContactPanelState createState() => _Covid19DebugTraceContactPanelState();
}

class _Covid19DebugTraceContactPanelState extends State<Covid19DebugTraceContactPanel> {
  static const double kFieldWidth = 142;

  DateTime _selectedDate;
  TextEditingController _durationController;
  FocusNode _durationNode;
  bool _submitting;
  
  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(text: '');
    _durationNode = FocusNode();
  }

  @override
  void dispose() {
    super.dispose();
    _durationController.dispose();
    _durationNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.health.covid19.debug.trace.heading.title","COVID-19 Contact Trace"), style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
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
              Text(Localization().getStringEx("panel.health.covid19.debug.trace.label.contact","Trace COVID-19 Contact"), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
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
                  child: Container(height: 48, width: kFieldWidth,
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
                child: Text("Duration (mins)", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
              ),
              Semantics(textField: true, child:Container(width: kFieldWidth, color: Styles().colors.white,
                child: TextField(
                  controller: _durationController,
                  focusNode: _durationNode,
                  decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0)), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
                ),
              )),
            ],),
          ),
      ]),
    );
  }

  Widget _buildSubmit() {
    return Padding(padding: EdgeInsets.all(16),
      child: Stack(children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Container(),),
          RoundedButton(label: "Submit Contact Trace",
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
        AppAlert.showDialogResult(context, Localization().getStringEx("panel.health.covid19.debug.trace.message.date.text","Please select a date")).then((_) {
          _onTapPickDate();
        });
        return;
      }
      DateTime dateUtc = _selectedDate.toUtc();

      int duration = int.tryParse(_durationController.text);
      if (duration == null) {
        AppAlert.showDialogResult(context,Localization().getStringEx("panel.health.covid19.debug.trace.message.duration.text", "Please enter an integer duration")).then((_) {
          _durationNode.requestFocus();
        });
        return;
      }

      setState(() {
        _submitting = true;
      });
      Health().processContactTrace(dateUtc: dateUtc, duration: duration * 60 * 1000 /* in milliseconds */).then((bool result) {
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
