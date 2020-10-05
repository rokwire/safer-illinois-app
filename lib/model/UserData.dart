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
import 'package:illinois/service/Localization.dart';

class UserData {

  final Map<String, dynamic> content;
  
  static const String analyticsUuid = 'UUIDxxxxxx';

  UserData({this.content});

  factory UserData.fromJson(Map<String, dynamic> json) {
    return (json != null) ? UserData(content: json) : null;
  }

  toJson() {
    return Map.from(content);
  }

  toShortJson() {
    return toJson();
  }

  String get uuid {
    return content['uuid'];
  }
  
  Set<String> get fcmTokens {
    dynamic fcmTokens = content['fcmTokens'];
    return (fcmTokens != null) ? Set.from(content['fcmTokens']) : null;
  }

  set fcmTokens(Set<String> value) {
    content['fcmTokens'] = (value != null) ? List.from(value) : null;
  }

  bool applyFCMToken(String fcmToken) {
    if (fcmToken != null) {
      Set<String> tokens = fcmTokens;
      if (tokens == null) {
        fcmTokens = Set.from([fcmToken]);
        return true;
      }
      else if (!tokens.contains(fcmToken)) {
        tokens.add(fcmToken);
        fcmTokens = tokens;
        return true;
      }
    }
    return false;
  }

  bool removeFCMToken(String fcmToken) {
    if (fcmToken != null) {
      Set<String> tokens = this.fcmTokens;
      if ((tokens != null) && tokens.contains(fcmToken)) {
        tokens.remove(fcmToken);
        fcmTokens = tokens;
        return true;
      }
    }
    return false;
  }

  Set<UserRole> get roles {
    return UserRole.userRolesFromList(content["roles"]);
  }

  set roles(Set<UserRole> value) {
    content["roles"] = UserRole.userRolesToList(value);
  }
}

class UserRole {
  static const student = const UserRole._internal('student');
  static const employee = const UserRole._internal('employee');
  static const resident = const UserRole._internal('resident');

  static List<UserRole> get values {
    return [student, employee, resident];
  }

  final String _value;

  const UserRole._internal(this._value);

  factory UserRole.fromString(String userRoleString) {
    if (userRoleString != null) {
      if (userRoleString == 'student') {
        return UserRole.student;
      }
      else if (userRoleString == 'employee') {
        return UserRole.employee;
      }
      else if (userRoleString == 'resident') {
        return UserRole.resident;
      }
    }
    return null;
  }

  toString() => _value;
  toJson() => _value;

  String toDisplayString() {
    if (this == student) {
      return Localization().getStringEx('model.user.role.student.title', 'Student');
    } else if (this == employee) {
      return Localization().getStringEx('model.user.role.employee.title', 'Employee');
    } else if (this == resident) {
      return Localization().getStringEx('model.user.role.resident.title', 'Resident');
    }
    else {
      return null;
    }
  }

  @override
  bool operator== (dynamic obj) {
    if (obj is UserRole) {
      return obj._value == _value;
    }
    return false;
  }

  @override
  int get hashCode => _value.hashCode;

  // Static Helpers

  static Set<UserRole> userRolesFromList(List<dynamic> userRolesList) {
    Set<UserRole> userRoles;
    if (userRolesList != null) {
      userRoles = new Set<UserRole>();
      for (dynamic userRole in userRolesList) {
        if (userRole is String) {
          userRoles.add(UserRole.fromString(userRole));
        }
      }
    }
    return userRoles;
  }

  static List<dynamic> userRolesToList(Set<UserRole> userRoles) {
    List<String> userRolesList;
    if (userRoles != null) {
      userRolesList = new List<String>();
      for (UserRole userRole in userRoles) {
        userRolesList.add(userRole.toString());
      }
    }
    return userRolesList;
  }
}
