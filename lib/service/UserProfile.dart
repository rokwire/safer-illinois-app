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
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:illinois/model/UserProfile.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/FirebaseCrashlytics.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:http/http.dart' as http;

class UserProfile with Service implements NotificationsListener {

  static const String notifyProfileUpdated = "edu.illinois.rokwire.user.profile.updated";
  static const String notifyProfileDeleted = "edu.illinois.rokwire.user.profile.deleted";
  static const String notifyRolesUpdated  = "edu.illinois.rokwire.user.profile.roles.updated";

  UserProfileData _profileData;

  http.Client _client = http.Client();

  static final UserProfile _service = new UserProfile._internal();

  factory UserProfile() {
    return _service;
  }

  UserProfile._internal();

  @override
  void createService() {
    NotificationService().subscribe(this, [
      AppLivecycle.notifyStateChanged,
      FirebaseMessaging.notifyToken,
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {

    _profileData = Storage().userProfile;
    
    if (_profileData == null) {
      await _createProfile();
    } else if (_profileData.uuid != null) {
      await _loadProfile();
    }
  }

  @override
  Future<void> clearService() async {
    _profileData = null;
  }

  Set<Service> get serviceDependsOn {
    return Set.from([Storage(), Config()]);
  }

  // NotificationsListener
  @override
  void onNotification(String name, dynamic param) {
    if (name == FirebaseMessaging.notifyToken) {
      _updateFCMToken();
    }
    else if(name == AppLivecycle.notifyStateChanged && param == AppLifecycleState.resumed){
      //_loadProfile();
    }
  }

  // User Profile Data

  String get uuid {
    return _profileData?.uuid;
  }
  
  UserProfileData get data {
    return _profileData;
  }

  static String get analyticsUuid {
    return UserProfileData.analyticsUuid;
  }

  Future<void> _createProfile() async {  
    UserProfileData profileData = await _requestCreateProfile();
    applyProfileData(profileData);
    Storage().localProfileUuid = profileData?.uuid;
  }

  Future<void> _loadProfile() async {
    // silently refresh user profile
    requestProfile(_profileData?.uuid).then((UserProfileData profileData) {
      if (profileData != null) {
        applyProfileData(profileData);
      }
    })
    .catchError((_){
        _clearStoredProfile();
      }, test: (error){return error is UserProfileNotFoundException;});
  }

  Future<void> _updateProfile() async {

    if (_profileData == null) {
      return;
    }

    // Stop previous request
    if (_client != null) {
      _client.close();
    }

    http.Client client;
    _client = client = http.Client();

    String profileUuid = _profileData.uuid;
    String url = (Config().userProfileUrl != null) ? "${Config().userProfileUrl}/$profileUuid" : null;
    Map<String, String> headers = {"Accept": "application/json","content-type":"application/json"};
    final response = (url != null) ? await Network().put(url, body: json.encode(_profileData.toJson()), headers: headers, client: _client, auth: Network.AppAuth) : null;
    String responseBody = response?.body;
    bool success = ((response != null) && (responseBody != null) && (response.statusCode == 200));
    
    if (!success) {
      //error
      String message = "Error on updating user - " + (response != null ? response.statusCode.toString() : "null");
      FirebaseCrashlytics().log(message);
    }
    else if (_client == client) {
      _client = null;
      Map<String, dynamic> jsonData = AppJson.decode(responseBody);
      UserProfileData update = UserProfileData.fromJson(jsonData);
      if (update != null) {
        Storage().userProfile = _profileData = update;
        //_notifyProfileUpdated();
      }
    }
    else {
      Log.d("Updating user canceled");
    }

  }

  Future<UserProfileData> requestProfile(String uuid) async {
    String url = ((Config().userProfileUrl != null) && (uuid != null) && (0 < uuid.length)) ? '${Config().userProfileUrl}/$uuid' : null;

    final response = (url != null) ? await Network().get(url, auth: Network.AppAuth) : null;

    if(response != null) {
      if (response?.statusCode == 404) {
        throw UserProfileNotFoundException();
      }

      String responseBody = ((response != null) && (response?.statusCode == 200)) ? response?.body : null;
      Map<String, dynamic> jsonData = AppJson.decode(responseBody);
      if (jsonData != null) {
        return UserProfileData.fromJson(jsonData);
      }
    }

    return null;
  }

  Future<UserProfileData> _requestCreateProfile() async {
    try {
      final response = (Config().userProfileUrl != null) ? await Network().post(Config().userProfileUrl, auth: Network.AppAuth, timeout: 10) : null;
      if ((response != null) && (response.statusCode == 200)) {
        String responseBody = response.body;
        Map<String, dynamic> jsonData = AppJson.decode(responseBody);
        return UserProfileData.fromJson(jsonData);
      } else {
        return null;
      }
    } catch(e){
      Log.e('Failed to create user');
      Log.e(e.toString());
      return null;
    }
  }

  Future<void> deleteProfile() async{
    String profileUuid = _profileData?.uuid;
    if((Config().userProfileUrl != null) && (profileUuid != null)) {
      try {
        await Network().delete("${Config().userProfileUrl}/$profileUuid", headers: {"Accept": "application/json", "content-type": "application/json"}, auth: Network.AppAuth);
      }
      finally {
        _clearStoredProfile();
        _notifyProfileDeleted();

        try {
          _profileData = await requestProfile(Storage().localProfileUuid);
        } on UserProfileNotFoundException catch (_) {
          _profileData = await _requestCreateProfile();
          if (_profileData?.uuid != null) {
            Storage().localProfileUuid = _profileData?.uuid;
          }
        }
        if (_profileData != null) {
          Storage().userProfile = _profileData;
          _notifyProfileUpdated();
        }
      }
    }

  }

  void applyProfileData(UserProfileData profileData) {
    
    // 1. We might need to remove FCM token from current user
    String applyProfileUuid = profileData?.uuid;
    String currentProfileUuid = _profileData?.uuid;
    bool profileSwitched = (currentProfileUuid != null) && (currentProfileUuid != applyProfileUuid);
    if (profileSwitched && (Config().userProfileUrl != null) && (_profileData?.uuid != null) && _removeFCMToken(_profileData)) {
      String url = "${Config().userProfileUrl}/${_profileData?.uuid}";
      Map<String, String> headers = {"Accept": "application/json","content-type":"application/json"};
      String post = json.encode(_profileData.toJson());
      Network().put(url, body: post, headers: headers, auth: Network.AppAuth);
    }

    // 2. We might need to add FCM token and user roles from Storage to new user
    bool applyProfileUpdated = _applyFCMToken(profileData);

    Storage().userProfile = _profileData = profileData;

    if (profileSwitched) {
      _notifyProfileUpdated();
    }
    
    if (applyProfileUpdated) {
      _updateProfile();
    }
  }

  void _clearStoredProfile(){
    Storage().userProfile = _profileData = null;
    Auth().logout();
    Storage().onBoardingPassed = false;
  }

  // FCM Tokens

  void _updateFCMToken() {
    if (_applyFCMToken(_profileData)) {
      _updateProfile();
    }
  }

  static bool _applyFCMToken(UserProfileData profileData) {
    return profileData?.applyFCMToken(FirebaseMessaging().token) ?? false;
  }

  static bool _removeFCMToken(UserProfileData profileData) {
    return profileData?.removeFCMToken(FirebaseMessaging().token) ?? false;
  }

  //UserRoles

  Set<UserRole> get roles {
    return _profileData?.roles;
  }

  set roles(Set<UserRole> userRoles) {
    if (_profileData != null) {
      _profileData.roles = (userRoles != null) ? Set<UserRole>.from(userRoles) : null;
      _updateProfile().then((_){
        _notifyUserRolesUpdated();
      });
    }
  }

  bool get isStudent {
    return _profileData?.roles?.contains(UserRole.student) ?? false;
  }

  bool get isEmployee {
    return _profileData?.roles?.contains(UserRole.employee) ?? false;
  }

  bool get isStudentOrEmployee {
    Set<UserRole> roles = _profileData?.roles;
    return (roles != null) && (roles.contains(UserRole.student) || roles.contains(UserRole.employee));
  }

  // Notifications

  void _notifyProfileUpdated() {
    NotificationService().notify(notifyProfileUpdated, null);
  }

  void _notifyProfileDeleted() {
    NotificationService().notify(notifyProfileDeleted, null);
  }

  void _notifyUserRolesUpdated() {
    NotificationService().notify(notifyRolesUpdated, null);
  }
}

class UserProfileNotFoundException implements Exception{
  final String message;
  UserProfileNotFoundException({this.message});

  @override
  String toString() {
    return message;
  }
}