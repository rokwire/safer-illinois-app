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
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19SymptomsPanel extends StatefulWidget {

  Covid19SymptomsPanel({Key key}) : super(key: key);

  @override
  _Covid19SymptomsPanelState createState() => _Covid19SymptomsPanelState();
}

class _Covid19SymptomsPanelState extends State<Covid19SymptomsPanel> {

  List<HealthSymptomsGroup> _symptomsGroups;
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
        _symptomsGroups = groups;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String title = Localization().getStringEx("panel.health.symptoms.heading.title","Are you experiencing any of these symptoms?");
    return Scaffold(backgroundColor: Styles().colors.background,
      body:SafeArea(
        child: Column(children: <Widget>[
          Stack(children: <Widget>[
            Align(alignment: Alignment.topLeft,
              child: OnboardingBackButton(image: 'images/chevron-left-blue.png', padding: EdgeInsets.only(left: 4, top: 16, right: 20, bottom: 20), onTap: () => _goBack()),
            ),
            Align(alignment: Alignment.topCenter,
              child: Padding(padding: EdgeInsets.only(left: 64, right: 64, bottom: 16, top: 20),
                child: Text(title, style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary),),
              ),
            ),
          ],),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(padding: EdgeInsets.all(24),
                child: Column(
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
    if (_symptomsGroups != null) {
      for (HealthSymptomsGroup group in _symptomsGroups) {
        if (group.visible != false) {
          result.addAll(_buildGroup(group));
        }
      }
    }
    if (0 < result.length) {
      result.add(_bulldSubmit());
    }
    return result;
  }

  List<Widget> _buildGroup(HealthSymptomsGroup group) {
    List<Widget> result = <Widget>[];
    if (group.symptoms != null) {
      for (HealthSymptom symptom in group.symptoms) {
        result.addAll(_buildSymptom(symptom));
      }
    }
    return result;
  }
  
  List<Widget> _buildSymptom(HealthSymptom symptom) {
    bool _selected = _selectedSymptoms.contains(symptom.id);
    String imageName = _selected ? 'images/icon-selected-checkbox.png' : 'images/icon-deselected-checkbox.png';
    return <Widget>[
    Semantics(
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
      )),
    ];
  }

  Widget _bulldSubmit() {
    bool enabled = (0 < _selectedSymptoms.length);
    return Padding(padding: EdgeInsets.only(top: 20, bottom: 20), child:
      Stack(children: <Widget>[
        ScalableRoundedButton(label: Localization().getStringEx("panel.health.symptoms.button.submit.title","Submit"),
          backgroundColor: enabled ? Styles().colors.white : Styles().colors.whiteTransparent01,
          textColor: enabled ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColorTwo,
          fontFamily: Styles().fontFamilies.bold,
          fontSize: 16,
          borderColor: enabled ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColorTwo,
          borderWidth: 2,
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
      for (HealthSymptomsGroup group in _symptomsGroups) {
        count += (group.symptoms?.length ?? 0);
      }
    }
    return count;
  }

  void _goBack() {
    Analytics.instance.logSelect(target: 'Back');
    Navigator.of(context).pop();
  }

  void _onTapSymptom(HealthSymptom symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom.id)) {
        _selectedSymptoms.remove(symptom.id);
      }
      else {
        _selectedSymptoms.add(symptom.id);
      }
      AppSemantics.announceCheckBoxStateChange(context, _selectedSymptoms?.contains(symptom.id), symptom.name);
    });
  }

  void _onSubmit() {
    Analytics.instance.logSelect(target: "Submit");
    if (_submittingSymptoms == true) {
      return;
    }
    setState(() {
      _submittingSymptoms = true;
    });

    Health().processSymptoms(groups: _symptomsGroups, selected: _selectedSymptoms).then((dynamic result) {
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