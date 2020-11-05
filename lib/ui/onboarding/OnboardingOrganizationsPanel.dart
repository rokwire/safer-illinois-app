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
import 'package:illinois/model/Organization.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Organizations.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/ui/widgets/RoleGridButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';

class OnboardingOrganizationsPanel extends StatefulWidget with OnboardingPanel {
  final Map<String, dynamic> onboardingContext;
  final _Data data = _Data();
  
  OnboardingOrganizationsPanel({this.onboardingContext});

  @override
  _OnboardingOrganizationsPanelState createState() => _OnboardingOrganizationsPanelState();

  @override
  Future<bool> get onboardingCanDisplayAsync async {
    data.organizations = await Organizations().ensureOrganizations();
    return (1 < (data?.organizations?.length ?? 0));
  }
}

class _Data {
  List<Organization> organizations;
  _Data({this.organizations});
}

class _OnboardingOrganizationsPanelState extends State<OnboardingOrganizationsPanel> {

  Organization _selectedOrganization;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _selectedOrganization = Organizations().organization ?? Organization.findInList(widget.data.organizations, isDefault: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles().colors.background,
      body: SafeArea(child: Column( children: <Widget>[
        Padding(padding: EdgeInsets.only(top: 10, bottom: 10),
          child: Row(children: <Widget>[
            OnboardingBackButton(image: 'images/chevron-left.png', padding: const EdgeInsets.only(left: 10,),
                onTap:() {
                  Analytics.instance.logSelect(target: "Back");
                  Navigator.pop(context);
                }),
            Expanded(child: Column(children: <Widget>[
              Semantics(
                label: 'Select Organization',
                hint: 'Header 1',
                excludeSemantics: true,
                child: Text('Select Organization',
                  style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 24, color: Styles().colors.fillColorPrimary),
                ),
              ),
            ],),),
            Padding(padding: EdgeInsets.only(left: 42),),
          ],),
        ),

        Expanded(child: SingleChildScrollView(child: Padding(padding: EdgeInsets.only(left: 16, right: 8, ), child:
            Column(children: _buildOrganizations()
            ),),),),

        Padding(padding: EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 20),
          child: Stack(children:<Widget>[
            ScalableRoundedButton(
                label: _allowNext ? 'Confirm' : 'Select one',
                hint: '',
                enabled: _allowNext,
                backgroundColor: (_allowNext ? Styles().colors.white : Styles().colors.background),
                borderColor: (_allowNext
                    ? Styles().colors.fillColorSecondary
                    : Styles().colors.fillColorPrimaryTransparent03),
                textColor: (_allowNext
                    ? Styles().colors.fillColorPrimary
                    : Styles().colors.fillColorPrimaryTransparent03),
                onTap: () => _onConfirm()),
            Visibility(
              visible: _updating,
              child: Container(
                height: 48,
                child: Align(
                  alignment:Alignment.center,
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),),),),),),
          ]),
        ),

      ],),),
    );
  }

  List<Widget> _buildOrganizations() {
    final double gridSpacing = 5;
    final int colCount = 2;
    List<Widget> row = <Widget>[];
    List<Widget> rows = <Widget>[];
    if (0 < (widget.data?.organizations?.length ?? 0)) {
      for (Organization organization in widget.data.organizations) {
        if (row.length == colCount) {
          rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: row));
          row = <Widget>[];
        }
        if (0 < row.length) {
          row.add(Container(height: gridSpacing,),);
        }
        row.add(Flexible(flex: 1, child: RoleGridButton(
          title: organization.name,
          hint: '',
          iconUrl: organization.iconUrl,
          selectedBackgroundColor: Styles().colors.accentColor3,
          selected: organization.id == _selectedOrganization?.id,
          data: organization,
          onTap: _onRoleGridButton,
        ),));
      }
      if (0 < row.length) {
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: row));
      }
    }
    return rows;
  }

  bool get _allowNext {
    return (_selectedOrganization != null);
  }

  void _onRoleGridButton(RoleGridButton button) {
    if (button != null) {
      Organization organization = button.data as Organization;
      Analytics.instance.logSelect(target: "Organization: " + organization.id);

      setState(() {
        _selectedOrganization = (organization.id != _selectedOrganization?.id) ? organization : null;
      });
    }
  }

  void _onConfirm() {
    Analytics.instance.logSelect(target:"Confirm");
    if (_selectedOrganization != null && !_updating) {
      setState(() {
        _updating = true;
      });
      Organizations().setOrganization(_selectedOrganization, notifyChanged: false).then((_) {
        if (mounted) {
          setState((){
            _updating = false;
          });
          Onboarding().next(context, widget);
        }
      });
    }
  }
}


