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
import 'package:flutter/foundation.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/utils/Utils.dart';

abstract class AuthToken {
  String get idToken => null;
  String get accessToken => null;
  String get refreshToken => null;
  String get tokenType => null;
  int get expiresIn => null;

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    if (json != null) {
      if (json.containsKey("phone")) {
        return PhoneToken.fromJson(json);
      }
    }
    return null;
  }

  toJson() => {};
}

class PhoneToken with AuthToken {
  final String phone;
  final String idToken;
  final String tokenType = "Bearer"; // missing data from the phone validation

  PhoneToken({this.phone, this.idToken});

  factory PhoneToken.fromJson(Map<String, dynamic> json) {
    return (json != null) ? PhoneToken(
      phone: json['phone'],
      idToken: json['id_token'],
    ) : null;
  }

  toJson() {
    return {
      'phone': phone,
      'id_token': idToken,
    };
  }

  bool operator ==(o) =>
      o is PhoneToken &&
          o.phone == phone &&
          o.idToken == idToken;

  int get hashCode =>
      phone.hashCode ^
      idToken.hashCode;
}

abstract class AuthUser {
  
  String get uin => null;
  String get netId => null;
  String get email => null;
  String get phone => null;

  String get firstName => null;
  String get middleName => null;
  String get lastName => null;
  String get fullName => null;

  Set<String> get groupMembership => null;

  static const analyticsUin = 'UINxxxxxx';
  static const analyticsFirstName = 'FirstNameXXXXXX';
  static const analyticsLastName = 'LastNameXXXXXX';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    if (json != null) {
      if (json.containsKey('phone')) {
       return PhoneAuthUser.fromJson(json);
      }
      else {
       return ShibbolethAuthUser.fromJson(json);
      }
    }
    else {
      return null;
    }
  }

  Map<String, dynamic> toJson();
}

class ShibbolethAuthUser with AuthUser {

  final String uin;
  final String sub;
  final String email;
  final String netId;

  final String firstName;
  final String middleName;
  final String lastName;
  final String _fullName;

  final Set<String> groupMembership;

  ShibbolethAuthUser({String fullName, this.firstName, this.middleName, this.lastName,
    this.netId, this.uin, this.sub, this.email, this.groupMembership}) :
    _fullName = fullName;

  factory ShibbolethAuthUser.fromJson(Map<String, dynamic> json) {
    return (json != null) ? ShibbolethAuthUser(
        uin: json['uiucedu_uin'],
        sub: json['sub'],
        email: json['email'],
        netId: json['preferred_username'],

        firstName: json['given_name'],
        middleName: json['middle_name'],
        lastName: json['family_name'],
        fullName: json['name'],

        groupMembership: (json['uiucedu_is_member_of'] != null) ? Set.from(json['uiucedu_is_member_of']) : null,
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      "uiucedu_uin": uin,
      "sub": sub,
      "email": email,
      "preferred_username": netId,

      "given_name": firstName,
      "middle_name": middleName,
      "family_name": lastName,
      "name": _fullName,

      "uiucedu_is_member_of": groupMembership?.toList()
    };
  }

  String get fullName {
    return AppString.isStringNotEmpty(_fullName) ? _fullName : AppString.fullName([firstName, middleName, lastName]);
  }
}

class PhoneAuthUser with AuthUser {
  final String uin;
  final String email;
  final String phone;

  final String firstName;
  final String middleName;
  final String lastName;

  final String gender;
  final String birthDateString;
  final String badgeType;

  final String address1;
  final String address2;
  final String address3;
  final String city;
  final String state;
  final String zip;

  PhoneAuthUser({this.uin, this.email, this.phone,
    this.firstName, this.middleName, this.lastName,
    this.gender, this.birthDateString, this.badgeType,
    this.address1, this.address2, this.address3,
    this.city, this.state, this.zip
  });

  factory PhoneAuthUser.fromJson(Map<String, dynamic> json) {
    return (json != null) ? PhoneAuthUser(
        uin: json['uin'],
        email: json['email'],
        phone: json['phone'],

        firstName: json['first_name'],
        middleName: json['middle_name'],
        lastName: json['last_name'],
        
        gender: json['gender'],
        birthDateString: json['birth_date'],
        badgeType: json['badge_type'],

        address1: json['address1'],
        address2: json['address2'],
        address3: json['address3'],
        city: json['city'],
        state: json['state'],
        zip: json['zip'],
    ) : null;
  }

  Map<String, dynamic> toJson() {
    return {
        'uin': uin,
        'email': email,
        'phone': phone,

        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        
        'gender': gender,
        'birth_date': birthDateString,
        'badge_type': badgeType,

        'address1': address1,
        'address2': address2,
        'address3': address3,
        'city': city,
        'state': state,
        'zip': zip,
    };
  }

  String get fullName {
    return AppString.fullName([firstName, middleName, lastName]);
  }

  DateTime get birthDate {
    return AppDateTime.parseDateTime(birthDateString, format: "MM/dd/yy");
  }
}

class AuthCard {

  final String uin;
  final String fullName;
  final String role;
  final String studentLevel;
  final String cardNumber;
  final String expirationDate;
  final String libraryNumber;
  final String magTrack2;
  final String photoBase64;

  AuthCard({this.uin, this.cardNumber, this.libraryNumber, this.expirationDate, this.fullName, this.role, this.studentLevel, this.magTrack2, this.photoBase64});

  factory AuthCard.fromJson(Map<String, dynamic> json) {
    return (json != null) ? AuthCard(
      uin: json['UIN'],
      fullName: json['full_name'],
      role: json['role'],
      studentLevel: json['student_level'],
      cardNumber: json['card_number'],
      expirationDate: json['expiration_date'],
      libraryNumber: json['library_number'],
      magTrack2: json['mag_track2'],
      photoBase64: json['photo_base64'],
    ) : null;
  }

  toJson() {
    return {
      'UIN': uin,
      'full_name': fullName,
      'role': role,
      'student_level': studentLevel,
      'card_number': cardNumber,
      'expiration_date': expirationDate,
      'library_number': libraryNumber,
      'mag_track2': magTrack2,
      'photo_base64': photoBase64,
    };
  }

  toShortJson() {
    return {
      'UIN': uin,
      'full_name': fullName,
      'role': role,
      'student_level': studentLevel,
      'card_number': cardNumber,
      'expiration_date': expirationDate,
      'library_number': libraryNumber,
      'mag_track2': magTrack2,
      'photo_base64_len': photoBase64?.length,
    };
  }

  bool operator ==(o) =>
      o is AuthCard &&
          o.uin == uin &&
          o.fullName == fullName &&
          o.role == role &&
          o.studentLevel == studentLevel &&
          o.cardNumber == cardNumber &&
          o.expirationDate == expirationDate &&
          o.libraryNumber == libraryNumber &&
          o.magTrack2 == magTrack2 &&
          o.photoBase64 == photoBase64;

  int get hashCode =>
      uin.hashCode ^
      fullName.hashCode ^
      role.hashCode ^
      studentLevel.hashCode ^
      cardNumber.hashCode ^
      expirationDate.hashCode ^
      libraryNumber.hashCode ^
      magTrack2.hashCode ^
      photoBase64.hashCode;

  Future<Uint8List> get photoBytes async{
    return (photoBase64 != null) ? await compute(AppBytes.decodeBase64Bytes, photoBase64) : null;
  }

  String get roleDisplayString{
    if(role == "Undergraduate" && studentLevel != "1U"){
      return Localization().getStringEx("panel.covid19_passport.label.update_i_card", "Update your i-card");
    }
    return role;
  }
}

class RokmetroUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String groups;
  final String auth;
  final String type;
  final String iss;
  final int exp;

  RokmetroUser({this.uid, this.name, this.email, this.phone, this.groups, this.auth, this.type, this.iss, this.exp});  

  factory RokmetroUser.fromJson(Map<String, dynamic> json) {
    return (json != null) ? RokmetroUser(
      uid: AppJson.stringValue(json['uid']),
      name: AppJson.stringValue(json['name']),
      email: AppJson.stringValue(json['email']),
      phone: AppJson.stringValue(json['phone']),
      groups: AppJson.stringValue(json['groups']),
      auth: AppJson.stringValue(json['auth']),
      type: AppJson.stringValue(json['type']),
      iss: AppJson.stringValue(json['iss']),
      exp: AppJson.intValue(json['exp']),
    ) : null;
  }

  dynamic toJson() {
    return {
      "uid" : uid,
      "name" : name,
      "email" : email,
      "phone" : phone,
      "groups" : groups,
      "auth" : auth,
      "type" : type,
      "iss" : iss,
      "exp" : exp,
    };
  }
}
