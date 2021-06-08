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

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:illinois/model/Auth.dart';
import 'package:illinois/utils/Utils.dart';

class UserProfileData {

  final Map<String, dynamic> content;
  
  static const String analyticsUuid = 'UUIDxxxxxx';

  UserProfileData({this.content});

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return (json != null) ? UserProfileData(content: json) : null;
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
  static const nonUniversityMember = const UserRole._internal('non_university_member');

  static List<UserRole> get values {
    return [student, employee, resident, nonUniversityMember];
  }

  static Set<Set<UserRole>> get groups {
    return Set.from([
      Set<UserRole>.from([UserRole.student, UserRole.employee, UserRole.resident]),
      Set<UserRole>.from([UserRole.nonUniversityMember]),
    ]);
  }
  
  final String _value;

  const UserRole._internal(this._value);

  factory UserRole.fromString(String userRoleString) {
    return (userRoleString != null) ? UserRole._internal(userRoleString) : null;
  }

  toString() => _value;
  toJson() => _value;

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
      userRolesList = <String>[];
      for (UserRole userRole in userRoles) {
        userRolesList.add(userRole.toString());
      }
    }
    return userRolesList;
  }
}

class UserPiiData {
  String pid;
  String uin;
  String netId;

  String userName;
  String firstName;
  String lastName;
  String middleName;
  int birthYear;

  String email;
  String phone;
  String address;
  String state;
  String zip;
  String country;

  UserDocumentType documentType;
  String photoBase64;
  String imageUrl;
  
  List<dynamic> rawUuidList;
  List<String> uuidList;
  
  UserPiiData({
    this.pid, this.uin, this.netId, 
    this.firstName, this.lastName, this.middleName, this.userName, this.birthYear, 
    this.email, this.phone, this.address, this.state, this.zip, this.country,
    this.documentType, this.photoBase64, this.imageUrl,
    this.rawUuidList, this.uuidList,
  });

  factory UserPiiData.fromJson(Map<String, dynamic> json) {
    return (json != null) ? UserPiiData(
      pid: json['pid'],
      uin: json['uin'],
      netId: json['netid'],

      firstName: json['firstname'],
      lastName: json['lastname'],
      middleName: json['middlename'],
      userName: json['username'],
      birthYear: json['birthYear'],

      email: json['email'],
      phone: json['phone'],
      address: json['address'],
      state: json['state'],
      zip: json['zipCode'],
      country: json['country'],

      documentType: userDocumentTypeFromString(json['documentType']) ,
      photoBase64: json['photoImageBase64'],
      imageUrl: json['imageUrl'],

      rawUuidList: json['uuid'],
      uuidList: _buildUuidList(json['uuid']),
    ) : null;
  }

  toJson() {
    return {
      'pid': pid,
      'uin': uin,
      'netid': netId,

      'firstname': firstName,
      'lastname': lastName,
      'middlename': middleName,
      'username': userName,
      'birthYear': birthYear,

      'email': email,
      'phone': phone,
      'address': address,
      'state': state,
      'zipCode': zip,
      'country': country,

      'documentType': userDocumentTypeToString(documentType),
      'photoImageBase64': photoBase64,
      'imageUrl': imageUrl,

      'uuid': rawUuidList,
    };
  }

  toShortJson() {
    return {
      'pid': pid,
      'uin': uin,
      'netid': netId,

      'firstname': firstName,
      'lastname': lastName,
      'middlename': middleName,
      'username': userName,
      'birthYear': birthYear,

      'email': email,
      'phone': phone,
      'address': address,
      'state': state,
      'zipCode': zip,
      'country': country,

      'documentType': userDocumentTypeToString(documentType),
    };
  }

  factory UserPiiData.fromObject(dynamic o){
    return (o is UserPiiData) ? UserPiiData(
        pid: o.pid,
        uin: o.uin,
        netId: o.netId,

        firstName: o.firstName,
        lastName: o.lastName,
        middleName: o.middleName,
        userName: o.userName,
        birthYear: o.birthYear,

        email: o.email,
        phone: o.phone,
        address: o.address,
        state: o.state,
        zip: o.zip,
        country: o.country,

        documentType: o.documentType,
        photoBase64: o.photoBase64,
        imageUrl: o.imageUrl,

        rawUuidList: o.rawUuidList,
        uuidList: o.uuidList,
    ) : null;
  }


  bool operator ==(o) =>
      o is UserPiiData &&
          o.pid == pid &&
          o.uin == uin &&
          o.netId == netId &&

          o.firstName == firstName &&
          o.lastName == lastName &&
          o.middleName == middleName &&
          o.userName == userName &&
          o.birthYear == birthYear &&
          
          o.email == email &&
          o.phone == phone &&
          o.address == address &&
          o.state == state &&
          o.zip == zip &&
          o.country == country &&

          o.documentType == documentType &&
          o.photoBase64 == photoBase64 &&
          o.imageUrl == imageUrl &&

          DeepCollectionEquality().equals(rawUuidList, o.rawUuidList);
  

  int get hashCode =>

      (pid?.hashCode ?? 0) ^
      (uin?.hashCode ?? 0) ^
      (netId?.hashCode ?? 0) ^

      (firstName?.hashCode ?? 0) ^
      (lastName?.hashCode ?? 0) ^
      (middleName?.hashCode ?? 0) ^
      (userName?.hashCode ?? 0) ^
      (birthYear?.hashCode ?? 0) ^

      (email?.hashCode ?? 0) ^
      (phone?.hashCode ?? 0) ^
      (address?.hashCode ?? 0) ^
      (state?.hashCode ?? 0) ^
      (zip?.hashCode ?? 0) ^
      (country?.hashCode ?? 0) ^

      (documentType?.hashCode ?? 0) ^
      (photoBase64?.hashCode ?? 0) ^
      (imageUrl?.hashCode ?? 0) ^

      (rawUuidList?.hashCode ?? 0);

  String get fullName {
    return AppString.fullName([firstName, middleName, lastName]);
  }

  String get uuid {
    return (0 < (uuidList?.length ?? 0)) ? uuidList.first : null;
  }

  bool get identityVerified{
    return (AppString.isStringNotEmpty(firstName) ||
        AppString.isStringNotEmpty(middleName) ||
        AppString.isStringNotEmpty(lastName)) &&
        (AppString.isStringNotEmpty(netId) ||
            AppString.isStringNotEmpty(phone));
  }

  Future<Uint8List> get photoBytes async{
    return (photoBase64 != null) ? await compute(AppBytes.decodeBase64Bytes, photoBase64) : null;
  }

  bool get hasPasportInfo{
    return (documentType != null);
  }

  bool updateFromAuthUser(AuthUser authUser) {
    bool updated = false;

    if (AppString.isStringNotEmpty(authUser?.firstName) && (firstName != authUser.firstName)) {
      firstName = authUser.firstName; updated = true;
    }
    
    if (AppString.isStringNotEmpty(authUser?.middleName) && (middleName != authUser.middleName)) {
      middleName = authUser.middleName; updated = true;
    }
    
    if (AppString.isStringNotEmpty(authUser?.lastName) && (lastName != authUser.lastName)) {
      lastName = authUser.lastName; updated = true;
    }

    if (AppString.isStringNotEmpty(authUser?.uin) && (uin != authUser.uin)) {
      uin = authUser.uin; updated = true;
    }

    if (AppString.isStringNotEmpty(authUser?.email) && (email != authUser.email)) {
      email = authUser.email; updated = true;
    }

    if (AppString.isStringNotEmpty(authUser?.netId) && (netId != authUser.netId)) {
      netId = authUser.netId; updated = true;
    }
    
    if (AppString.isStringNotEmpty(authUser?.phone) && (phone != authUser.phone)) {
      phone = authUser.phone; updated = true;
    }

    if (authUser is PhoneAuthUser) {

      int authBirthYear = authUser.birthDate?.year;
      if ((authBirthYear != null) && (authBirthYear != birthYear)) {
        birthYear = authBirthYear; updated = true;
      }

      if (AppString.isStringNotEmpty(authUser?.address1) && (address != authUser.address1)) {
        address = authUser.address1; updated = true;
      }

      if (AppString.isStringNotEmpty(authUser?.state) && (state != authUser.state)) {
        state = authUser.state; updated = true;
      }

      if (AppString.isStringNotEmpty(authUser?.zip) && (zip != authUser.zip)) {
        zip = authUser.zip; updated = true;
      }
    }


    return updated;
  }


  static List<String> _buildUuidList(List<dynamic> list, { List<String> uuidList, RegExp uuidRegExp }) {

    if (list != null) {
      
      if (uuidList == null) {
        uuidList = <String>[];
      }

      if (uuidRegExp == null) {
        uuidRegExp = RegExp('[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}');
      }

      for (dynamic entry in list) {
        if (entry is String) {
          Iterable<RegExpMatch> matches = uuidRegExp.allMatches(entry);
          if (matches != null) {
            for (RegExpMatch match in matches) {
              String matchString = match.input.substring(match.start, match.end);
              if (!uuidList.contains(matchString)) {
                uuidList.add(matchString);
              }
            }
          }
        }
        else if (entry is List) {
          _buildUuidList(entry, uuidList: uuidList, uuidRegExp: uuidRegExp);
        }
      }
    }

    return uuidList;
  }

  void addProfileUuid(String uuid){
    if(AppString.isStringNotEmpty(uuid)) {
      uuidList.add(uuid);
      rawUuidList.add(uuid);
    }
  }

 }

///////////////////////////////
// UserDocumentType

enum UserDocumentType { drivingLicense, passport }

UserDocumentType userDocumentTypeFromString(String value) {
  if (value == 'passport') {
    return UserDocumentType.passport;
  }
  else if (value == 'drivingLicense') {
    return UserDocumentType.drivingLicense;
  }
  else {
    return null;
  }
}

String userDocumentTypeToString(UserDocumentType value) {
  switch (value) {
    case UserDocumentType.passport: return 'passport';
    case UserDocumentType.drivingLicense: return 'drivingLicense';
  }
  return null;
}
