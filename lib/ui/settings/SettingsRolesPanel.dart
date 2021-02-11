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
import 'package:illinois/service/Config.dart';
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
  Set<UserRole> _userRoles;
  Set<UserRole> _selectedRoles;

  Timer _saveRolesTimer;

  @override
  void initState() {
    NotificationService().subscribe(this, User.notifyRolesUpdated);
    _userRoles = User().roles ?? Set<UserRole>();
    _selectedRoles = (_userRoles != null) ? Set<UserRole>.from(_userRoles) : Set<UserRole>();
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
                  Localization().getStringEx('panel.onboarding.roles.label.description', 'Select one'),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 16, top: 8, right: 8, bottom: 16),
              child:

              Column(crossAxisAlignment: CrossAxisAlignment.start, children: _rolesWidgets),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> get _rolesWidgets {
    final double gridSpacing = 5;
    final int colsCount = 2;
    List<Widget> rows = <Widget>[], row = <Widget>[];
    int rowEntries = 0;
    for (UserRole role in UserRole.values) {
      RoleGridButton roleButton = _roleButton(role);
      if (roleButton != null) {
        if (0 < row.length) {
          row.add(Container(width: gridSpacing));
        }
        row.add(Expanded(child: roleButton));
        rowEntries++;
        if (rowEntries >= colsCount) {
          if (0 < rows.length) {
            rows.add(Container(height: gridSpacing));
          }
          rows.add(Row(children:row));
          row = <Widget>[];
          rowEntries = 0;
        }
      }
    }
    if (0 < rowEntries) {
      while (rowEntries < colsCount) {
        row.add(Container(width: gridSpacing));
        row.add(Expanded(child: Container()));
        rowEntries++;
      }
      if (0 < rows.length) {
        rows.add(Container(height: gridSpacing));
      }
      rows.add(Row(children:row));
    }
    return rows;
  }

  RoleGridButton _roleButton(UserRole role) {
    if (role == UserRole.student) {
      return _studentButton;
    }
    else if (role == UserRole.employee) {
      return _employeeButton;
    }
    else if (role == UserRole.resident) {
      return _residentButton;
    }
    else if (role == UserRole.nonUniversityMember) {
      return _capitolStaffButton;
    }
    else {
      return null;
    }
  }

  RoleGridButton get _studentButton {
    return RoleGridButton(
      title: Localization().getStringEx('panel.onboarding.roles.button.student.title', 'University Student'),
      hint: Localization().getStringEx('panel.onboarding.roles.button.student.hint', ''),
      iconPath: 'images/icon-persona-student-normal.png',
      selectedIconPath: 'images/icon-persona-student-selected.png',
      selectedBackgroundColor: Styles().colors.fillColorSecondary,
      selected: (_selectedRoles.contains(UserRole.student)),
      data: UserRole.student,
      sortOrder: 1,
      onTap: _onRoleGridButton,
    );
  }

  RoleGridButton get _employeeButton {
    return RoleGridButton(
      title: Localization().getStringEx('panel.onboarding.roles.button.employee.title', 'Employee/Affiliate'),
      hint: Localization().getStringEx('panel.onboarding.roles.button.employee.hint', ''),
      iconPath: 'images/icon-persona-employee-normal.png',
      selectedIconPath: 'images/icon-persona-employee-selected.png',
      selectedBackgroundColor: Styles().colors.accentColor3,
      selected: (_selectedRoles.contains(UserRole.employee)),
      data: UserRole.employee,
      sortOrder: 4,
      onTap: _onRoleGridButton,
    );
  }

  RoleGridButton get _residentButton {
    return (Config().residentRoleEnabled || _userRoles.contains(UserRole.resident)) ? RoleGridButton(
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
    ) : null;
  }

  RoleGridButton get _capitolStaffButton {
    return (Config().capitolStaffRoleEnabled || _userRoles.contains(UserRole.nonUniversityMember)) ? RoleGridButton(
      title: Localization().getStringEx("panel.onboarding.roles.button.capitol_staff.title","Non University Member"),
      hint: Localization().getStringEx('panel.onboarding.roles.button.capitol_staff.hint', ''),
      iconPath: 'images/icon-persona-capitol-normal.png',
      selectedIconPath: 'images/icon-persona-capitol-selected.png',
      selectedBackgroundColor: Styles().colors.accentColor2,
      selectedTextColor: Colors.white,
      selected:(_selectedRoles.contains(UserRole.nonUniversityMember)),
      data: UserRole.nonUniversityMember,
      sortOrder: 7,
      onTap: _onRoleGridButton,
    ) : null;
  }

  void _onRoleGridButton(RoleGridButton button) {

    if (button != null) {

      UserRole role = button.data as UserRole;

      Analytics.instance.logSelect(target: "Role: " + role.toString());
      
        if (_selectedRoles.contains(role)) {
          _selectedRoles.remove(role);
        } else {
          
          // Unselect all roles that bellog to other roles groups
          for (Set<UserRole> group in UserRole.groups) {
            if (!group.contains(role)) {
              _selectedRoles.removeAll(group);
            }
          }

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
        _selectedRoles = (_userRoles != null) ? Set<UserRole>.from(_userRoles) : Set<UserRole>();
      });
    }
  }
}

