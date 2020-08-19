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

import 'package:flutter/material.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoleGridButton.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/model/UserData.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';

class SettingsRolesPanel extends StatefulWidget {
  _SettingsRolesPanelState createState() => _SettingsRolesPanelState();
}

class _SettingsRolesPanelState extends State<SettingsRolesPanel> implements NotificationsListener {
  //User _user;
  Set<UserRole> _selectedRoles = Set<UserRole>();
  bool _isResident;

  Timer _saveRolesTimer;

  @override
  void initState() {
    NotificationService().subscribe(this, User.notifyRolesUpdated);
    _selectedRoles = User().roles ?? Set<UserRole>();
    _isResident = _selectedRoles.contains(UserRole.resident);
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    if (_saveRolesTimer != null) {
      _stopSaveRolesTimer();
      _saveSelectedRoles();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(
          Localization().getStringEx('panel.onboarding.roles.label.title', 'WHO YOU ARE'),
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
      ),
      body: _buildContent(),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildContent() {
    final double gridSpacing = 5;

    return SingleChildScrollView(
      child: Container(
        color: Styles().colors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  Localization().getStringEx('panel.onboarding.roles.label.description', 'Select all that apply'),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 16, top: 8, right: 8, bottom: 16),
              child:

              Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Row(children: <Widget>[
                  Expanded(child: RoleGridButton(
                    title: Localization().getStringEx('panel.onboarding.roles.button.student.title', 'University Student'),
                    hint: Localization().getStringEx('panel.onboarding.roles.button.student.hint', ''),
                    iconPath: 'images/icon-persona-student-normal.png',
                    selectedIconPath: 'images/icon-persona-student-selected.png',
                    selectedBackgroundColor: Styles().colors.fillColorSecondary,
                    selected: (_selectedRoles.contains(UserRole.student)),
                    data: UserRole.student,
                    sortOrder: 1,
                    onTap: _onRoleGridButton,
                  ),),
                  Container(width: gridSpacing,),
                  Expanded(child: RoleGridButton(
                    title: Localization().getStringEx('panel.onboarding.roles.button.employee.title', 'Employee/Affiliate'),
                    hint: Localization().getStringEx('panel.onboarding.roles.button.employee.hint', ''),
                    iconPath: 'images/icon-persona-employee-normal.png',
                    selectedIconPath: 'images/icon-persona-employee-selected.png',
                    selectedBackgroundColor: Styles().colors.accentColor3,
                    selected: (_selectedRoles.contains(UserRole.employee)),
                    data: UserRole.employee,
                    sortOrder: 4,
                    onTap: _onRoleGridButton,
                  ),),
                ]),
                Container(height: gridSpacing,),
                _isResident ? Row(children: <Widget>[
                  Expanded(child: RoleGridButton(
                    title: Localization().getStringEx('panel.onboarding.roles.button.resident.title', 'Resident'),
                    hint: Localization().getStringEx('panel.onboarding.roles.button.resident.hint', ''),
                    iconPath: 'images/icon-persona-resident-normal.png',
                    selectedIconPath: 'images/icon-persona-resident-selected.png',
                    selectedBackgroundColor: Styles().colors.fillColorPrimary,
                    selectedTextColor: Colors.white,
                    selected:(_selectedRoles.contains(UserRole.resident)),
                    data: UserRole.resident,
                    sortOrder: 7,
                    onTap: _onRoleGridButton,
                  ),),
                  Container(width: gridSpacing,),
                  Expanded(child: Container()),
                ]) : Container(),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _onRoleGridButton(RoleGridButton button) {

    if (button != null) {

      UserRole role = button.data as UserRole;

      Analytics.instance.logSelect(target: "Role: " + role.toString());
      
        if (_selectedRoles.contains(role)) {
          _selectedRoles.remove(role);
        } else {
          _selectedRoles.add(role);
        }

      AppSemantics.announceCheckBoxStateChange(context, _selectedRoles.contains(role), button.title);

      setState(() {});

      _startSaveRolesTimer();
    }
  }

  void _startSaveRolesTimer() {
    _stopSaveRolesTimer();
    _saveRolesTimer = Timer(Duration(seconds: 3), _saveSelectedRoles);
  }

  void _stopSaveRolesTimer() {
    if (_saveRolesTimer != null) {
      _saveRolesTimer.cancel();
      _saveRolesTimer = null;
    }
  }

  void _saveSelectedRoles() {
    User().roles = _selectedRoles;
    _saveRolesTimer = null;
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == User.notifyRolesUpdated) {
      setState(() {
        _selectedRoles = User().roles ?? Set<UserRole>();
      });
    }
  }
}

