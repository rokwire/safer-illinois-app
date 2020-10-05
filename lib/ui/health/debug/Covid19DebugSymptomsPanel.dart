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
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19DebugSymptomsPanel extends StatefulWidget {

  Covid19DebugSymptomsPanel({Key key}) : super(key: key);

  @override
  _Covid19DebugSymptomsPanelState createState() => _Covid19DebugSymptomsPanelState();
}

class _Covid19DebugSymptomsPanelState extends State<Covid19DebugSymptomsPanel> {

  DateTime _selectedDate;
  List<HealthSymptomsGroup> _symptoms;
  Map<String, String> _symptomsGroups;
  Set<String> _selectedSymptoms = Set<String>();
  bool _loadingSymptoms;
  bool _submittingSymptoms;

  @override
  void initState() {
    super.initState();
    _loadingSymptoms = true;
    Health().loadSymptomsGroups().then((List<HealthSymptomsGroup> groups) {
      setState(() {
        _loadingSymptoms = false;
        _symptoms = groups;
        _symptomsGroups = _buildSymptomsGroups(groups);
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Styles().colors.background,
      body:SafeArea(
        child: Column(children: <Widget>[
          Stack(children: <Widget>[
            Align(alignment: Alignment.topLeft,
              child: OnboardingBackButton(image: 'images/chevron-left-blue.png', padding: EdgeInsets.only(left: 4, top: 16, right: 20, bottom: 20), onTap: () => _goBack()),
            ),
            Align(alignment: Alignment.topCenter,
              child: Padding(padding: EdgeInsets.only(left: 64, right: 64, bottom: 16, top: 20),
                child: Text("COVID-19 Symptoms", style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary),),
              ),
            ),
          ],),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: _buildContent()
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_loadingSymptoms == true) {
      return _buildLoadingContent(); 
    }
    else if (_symptomsCount == 0) {
      return _buildStatusContent(Localization().getStringEx("panel.health.symptoms.label.error.loading","Failed to load symptoms."));
    }
    else {
      return _buildSymptomsContent();
    }
  }

  List<Widget> _buildSymptomsContent() {
    List<Widget> result = <Widget>[];
    result.add(_buildDatePicker());
    
    if (_symptoms != null) {
      result.add(Padding(padding: EdgeInsets.only(bottom: 4),
        child: Text("Symptoms", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      ),);
      
      for (HealthSymptomsGroup group in _symptoms) {
        if ((group.symptoms != null) && (group.visible != false)) {
          for (HealthSymptom symptom in group.symptoms) {
            result.add(_buildSymptom(symptom));
          }
        }
      }
    }

    if (0 < result.length) {
      result.add(_bulldSubmit());
    }
    return result;
  }

  static Map<String, String> _buildSymptomsGroups(List<HealthSymptomsGroup> symptoms) {
    Map<String, String> symptomsGroups;
    if (symptoms != null) {
      symptomsGroups = Map<String, String>();
      for (HealthSymptomsGroup group in symptoms) {
        if ((group.group != null) && (group.symptoms != null)) {
          for (HealthSymptom symptom in group.symptoms) {
            if (symptom.id != null) {
              symptomsGroups[symptom.id] = group.group;
            }
          }
        }
      }
    }
    return symptomsGroups;
  }
  
  Widget _buildSymptom(HealthSymptom symptom) {
    bool _selected = _selectedSymptoms.contains(symptom.id);
    String imageName = _selected ? 'images/icon-selected-checkbox.png' : 'images/icon-deselected-checkbox.png';
    return Semantics(
      label: symptom.name,
      value: (_selected?Localization().getStringEx("toggle_button.status.checked", "checked",) :
      Localization().getStringEx("toggle_button.status.unchecked", "unchecked")) +
      ", "+ Localization().getStringEx("toggle_button.status.checkbox", "checkbox"),
      button:true,
      excludeSemantics: true,
      child: Padding(padding: EdgeInsets.only(bottom: 10), child:
          InkWell(onTap: () => _onTapSymptom(symptom), child:
            Container(padding: EdgeInsets.all(16), color: Colors.white, child:
              Row(children: <Widget>[
                Image.asset(imageName),
                Expanded(child:
                  Padding(padding: EdgeInsets.only(left: 16), child:
                    Text(symptom.name, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.fillColorPrimary),),
                  ),
                ),
              ],)
            ),
          ),
    ));
  }

  Widget _bulldSubmit() {
    bool enabled = (0 < _selectedSymptoms.length);
    return Padding(padding: EdgeInsets.only(top: 20, bottom: 20), child:
      Stack(children: <Widget>[
        RoundedButton(label: Localization().getStringEx("panel.health.symptoms.button.submit.title","Submit"),
          backgroundColor: enabled ? Styles().colors.white : Styles().colors.whiteTransparent01,
          textColor: enabled ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColorTwo,
          fontFamily: Styles().fontFamilies.bold,
          fontSize: 16,
          padding: EdgeInsets.symmetric(horizontal: 32, ),
          borderColor: enabled ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColorTwo,
          borderWidth: 2,
          height: 48,
          onTap:() { _onSubmit();  }
        ),
          Visibility(visible: (_submittingSymptoms == true), child:
            Center(child:
              Padding(padding: EdgeInsets.only(top: 12), child:
               Container(width: 24, height:24, child:
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
                ),
              ),
            ),
          ),
      ],)
    );
  }

  Widget _buildDatePicker() {
    String dateText = _selectedDate != null ? AppDateTime.formatDateTime(_selectedDate, format: 'MM/dd/yyyy') : "-";
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Padding(padding: EdgeInsets.only(bottom: 4),
        child: Text(Localization().getStringEx("panel.health.covid19.debug.trace.label.date","Date"), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
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
      Padding(padding: EdgeInsets.only(bottom: 10), child: Container()),
    ],);

  }

  List<Widget> _buildLoadingContent() {
    return <Widget>[
      Padding(padding:EdgeInsets.symmetric(vertical: 200), child:
          Align(alignment: Alignment.center, child:
            Container(width: 42, height: 42, child:
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorPrimary), strokeWidth: 2,)
            ),
          ),
      )];
  }

  List<Widget> _buildStatusContent(String text) {
    return <Widget>[Padding(padding: EdgeInsets.only(left: 32, right:32, top: 200),
        child:Align(alignment: Alignment.center, child:
          Text(text, style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
        ),
      )];
  }

  int get _symptomsCount {
    int count = 0;
    if (_symptomsGroups != null) {
      for (HealthSymptomsGroup group in _symptoms) {
        count += (group.symptoms?.length ?? 0);
      }
    }
    return count;
  }

  void _goBack() {
    Analytics.instance.logSelect(target: 'Back');
    Navigator.of(context).pop();
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

  void _onTapSymptom(HealthSymptom symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom.id)) {
        _selectedSymptoms.remove(symptom.id);
      }
      else {
        String symptomGroup = (_symptomsGroups != null) ? _symptomsGroups[symptom.id] : null;
        if (symptomGroup != null) {
          for (String selectedSymptomId in List.from(_selectedSymptoms)) {
            String selectedSymptomGroup = (_symptomsGroups != null) ? _symptomsGroups[selectedSymptomId] : null;
            if ((selectedSymptomGroup != null) && (selectedSymptomGroup != symptomGroup)) {
              _selectedSymptoms.remove(selectedSymptomId);
            }
          }
        }

        _selectedSymptoms.add(symptom.id);
      }
      AppSemantics.announceCheckBoxStateChange(context, _selectedSymptoms?.contains(symptom.id), symptom.name);
    });
  }

  void _onSubmit() {
    Analytics.instance.logSelect(target: "Submit");

    if (AppCollection.isCollectionEmpty(_selectedSymptoms)) {
      AppAlert.showDialogResult(context, Localization().getStringEx("panel.health.symptoms.label.error.no_selection", "Please select at least one symptom"));
      return;
    }

    if (_selectedDate == null) {
      AppAlert.showDialogResult(context, "Please select a date");
      return;
    }

    if (_submittingSymptoms == true) {
      return;
    }
    setState(() {
      _submittingSymptoms = true;
    });

    Health().processSymptoms(groups: _symptoms, selected: _selectedSymptoms, dateUtc: _selectedDate?.toUtc()).then((dynamic result) {
      if (mounted) {
        setState(() {
          _submittingSymptoms = false;
        });
        if (result == null) {
          AppAlert.showDialogResult(context, Localization().getStringEx("panel.health.symptoms.label.error.submit", "Failed to submit symptoms."));
        }
        else if (result is Covid19History) {
          AppAlert.showDialogResult(context,Localization().getStringEx("panel.health.symptoms.label.success.submit.message", "Your symptoms have been processed.")).then((_){
            Navigator.of(context).pop();
          });
        }
        else if (result is Covid19Status) {
          Navigator.of(context).pop(); // pop immidiately as status update panel will be pushed.
        }
      }
    });
  }
}