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

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/UserData.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:http/http.dart' as http;

class User with Service implements NotificationsListener {

  static const String notifyUserUpdated = "edu.illinois.rokwire.user.updated";
  static const String notifyUserDeleted = "edu.illinois.rokwire.user.deleted";
  static const String notifyRolesUpdated  = "edu.illinois.rokwire.user.roles.updated";

  UserData _userData;

  http.Client _client = http.Client();

  static final User _service = new User._internal();

  factory User() {
    return _service;
  }

  User._internal();

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

    _userData = Storage().userData;
    
    if (_userData == null) {
      await _createUser();
    } else if (_userData.uuid != null) {
      await _loadUser();
    }
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
      //_loadUser();
    }
  }

  // User

  String get uuid {
    return _userData?.uuid;
  }
  
  UserData get data {
    return _userData;
  }

  static String get analyticsUuid {
    return UserData.analyticsUuid;
  }

  Future<void> _createUser() async {  
    UserData userData = await _requestCreateUser();
    applyUserData(userData);
    Storage().localUserUuid = userData?.uuid;
  }

  Future<void> _loadUser() async {
    // silently refresh user profile
    requestUser(_userData.uuid).then((UserData userData) {
      if (userData != null) {
        applyUserData(userData);
      }
    })
    .catchError((_){
        _clearStoredUserData();
      }, test: (error){return error is UserNotFoundException;});
  }

  Future<void> _updateUser() async {

    if (_userData == null) {
      return;
    }

    // Stop previous request
    if (_client != null) {
      _client.close();
    }

    http.Client client;
    _client = client = http.Client();

    String userUuid = _userData.uuid;
    String url = (Config().userProfileUrl != null) ? "${Config().userProfileUrl}/$userUuid" : null;
    Map<String, String> headers = {"Accept": "application/json","content-type":"application/json"};
    final response = await Network().put(url, body: json.encode(_userData.toJson()), headers: headers, client: _client, auth: NetworkAuth.App);
    String responseBody = response?.body;
    bool success = ((response != null) && (responseBody != null) && (response.statusCode == 200));
    
    if (!success) {
      //error
      String message = "Error on updating user - " + (response != null ? response.statusCode.toString() : "null");
      Crashlytics().log(message);
    }
    else if (_client == client) {
      _client = null;
      Map<String, dynamic> jsonData = AppJson.decode(responseBody);
      UserData update = UserData.fromJson(jsonData);
      if (update != null) {
        Storage().userData = _userData = update;
        //_notifyUserUpdated();
      }
    }
    else {
      Log.d("Updating user canceled");
    }

  }

  Future<UserData> requestUser(String uuid) async {
    String url = ((Config().userProfileUrl != null) && (uuid != null) && (0 < uuid.length)) ? '${Config().userProfileUrl}/$uuid' : null;

    final response = await Network().get(url, auth: NetworkAuth.App);

    if(response != null) {
      if (response?.statusCode == 404) {
        throw UserNotFoundException();
      }

      String responseBody = ((response != null) && (response?.statusCode == 200)) ? response?.body : null;
      Map<String, dynamic> jsonData = AppJson.decode(responseBody);
      if (jsonData != null) {
        return UserData.fromJson(jsonData);
      }
    }

    return null;
  }

  Future<UserData> _requestCreateUser() async {
    try {
      final response = await Network().post(Config().userProfileUrl, auth: NetworkAuth.App, timeout: 10);
      if ((response != null) && (response.statusCode == 200)) {
        String responseBody = response.body;
        Map<String, dynamic> jsonData = AppJson.decode(responseBody);
        return UserData.fromJson(jsonData);
      } else {
        return null;
      }
    } catch(e){
      Log.e('Failed to create user');
      Log.e(e.toString());
      return null;
    }
  }

  Future<void> deleteUser() async{
    String userUuid = _userData?.uuid;
    if((Config().userProfileUrl != null) && (userUuid != null)) {
      await Network().delete("${Config().userProfileUrl}/$userUuid", headers: {"Accept": "application/json", "content-type": "application/json"}, auth: NetworkAuth.App);

      _clearStoredUserData();
      _notifyUserDeleted();

      try {
        _userData = await requestUser(Storage().localUserUuid);
      } on UserNotFoundException catch (_) {
        _userData = await _requestCreateUser();
        if (_userData?.uuid != null) {
          Storage().localUserUuid = _userData?.uuid;
        }
      }
      if (_userData != null) {
        Storage().userData = _userData;
        _notifyUserUpdated();
      }
    }

  }

  void applyUserData(UserData userData) {
    
    // 1. We might need to remove FCM token from current user
    String applyUserUuid = userData?.uuid;
    String currentUserUuid = _userData?.uuid;
    bool userSwitched = (currentUserUuid != null) && (currentUserUuid != applyUserUuid);
    if (userSwitched && _removeFCMToken(_userData)) {
      String url = "${Config().userProfileUrl}/${_userData.uuid}";
      Map<String, String> headers = {"Accept": "application/json","content-type":"application/json"};
      String post = json.encode(_userData.toJson());
      Network().put(url, body: post, headers: headers, auth: NetworkAuth.App);
    }

    // 2. We might need to add FCM token and user roles from Storage to new user
    bool applyUserUpdated = _applyFCMToken(userData);

    Storage().userData = _userData = userData;

    if (userSwitched) {
      _notifyUserUpdated();
    }
    
    if (applyUserUpdated) {
      _updateUser();
    }
  }

  void _clearStoredUserData(){
    Storage().userData = _userData = null;
    Auth().logout();
    Storage().onBoardingPassed = false;
  }

  // FCM Tokens

  void _updateFCMToken() {
    if (_applyFCMToken(_userData)) {
      _updateUser();
    }
  }

  static bool _applyFCMToken(UserData userData) {
    return userData?.applyFCMToken(FirebaseMessaging().token) ?? false;
  }

  static bool _removeFCMToken(UserData userData) {
    return userData?.removeFCMToken(FirebaseMessaging().token) ?? false;
  }

  //UserRoles

  Set<UserRole> get roles {
    return _userData?.roles;
  }

  set roles(Set<UserRole> userRoles) {
    if (_userData != null) {
      _userData.roles = userRoles;
      _updateUser().then((_){
        _notifyUserRolesUpdated();
      });
    }
  }

  // Notifications

  void _notifyUserUpdated() {
    NotificationService().notify(notifyUserUpdated, null);
  }

  void _notifyUserDeleted() {
    NotificationService().notify(notifyUserDeleted, null);
  }

  void _notifyUserRolesUpdated() {
    NotificationService().notify(notifyRolesUpdated, null);
  }
}

class UserNotFoundException implements Exception{
  final String message;
  UserNotFoundException({this.message});

  @override
  String toString() {
    return message;
  }
}