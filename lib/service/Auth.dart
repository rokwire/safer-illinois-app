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

import 'dart:io';
import 'dart:convert' as json;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as Http;
import 'package:http/http.dart';
import 'package:illinois/model/Auth.dart';
import 'package:illinois/model/UserProfile.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/utils/Utils.dart';

class Auth with Service implements NotificationsListener {

  static const String REDIRECT_URI = 'edu.illinois.covid://covid.illinois.edu/shib-auth';

  static const String notifyStarted  = "edu.illinois.rokwire.auth.started";
  static const String notifyAuthTokenChanged  = "edu.illinois.rokwire.auth.authtoken.changed";
  static const String notifyLoggedOut  = "edu.illinois.rokwire.auth.logged_out";
  static const String notifyLoginSucceeded  = "edu.illinois.rokwire.auth.login_succeeded";
  static const String notifyLoginFailed  = "edu.illinois.rokwire.auth.login_failed";
  static const String notifyLoginChanged  = "edu.illinois.rokwire.auth.login_changed";
  static const String notifyUserChanged  = "edu.illinois.rokwire.auth.user.changed";
  static const String notifyUserPiiDataChanged  = "edu.illinois.rokwire.auth.pii.changed";
  static const String notifyCardChanged  = "edu.illinois.rokwire.auth.card.changed";

  static const String _authCardName   = "idCard.json";
  static const String _userPiiFileName   = "piiData.json";

  AuthToken _authToken;
  AuthUser _authUser;
  String _csrfToken;

  RokmetroUser _rokmetroUser;

  UserPiiData _userPiiData;
  File _userPiiCacheFile;

  AuthCard _authCard;
  File _authCardCacheFile;

  // Singletone Instance
  
  static final Auth _auth = Auth._internal();
  
  factory Auth() {
    return _auth;
  }
  
  Auth._internal();

  // Service

  @override
  void createService() {
    NotificationService().subscribe(this, [
      AppLivecycle.notifyStateChanged,
      UserProfile.notifyProfileDeleted,
      Config.notifyConfigChanged,
    ]);
  }

  @override
  Future<void> initService() async {
    if (isLoggedIn) {
      await _loadCsrfToken();
    }
    _authToken = Storage().authToken;
    _authUser = Storage().authUser;

    _rokmetroUser = Storage().rokmetroUser;

    _authCardCacheFile = await _getAuthCardCacheFile();
    _authCard = await _loadAuthCardFromCache();

    _userPiiCacheFile = await _getUserPiiCacheFile();
    _userPiiData = await _loadUserPiiDataFromCache();

    // Backward compatability - no rokmetro data stored from previous versions
    await _ensureRokmetroData();

    _syncProfilePiiDataIfNeed(); // No need for await
  }

  @override
  Future<void> clearService() async {
    _authToken = null;
    _authUser = null;

    _rokmetroUser = null;

    AppFile.delete(_authCardCacheFile);
    _authCard = null;

    AppFile.delete(_userPiiCacheFile);
    _userPiiData = null;
  }


  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Storage()]);
  }

  // NotificationsListener
  
  @override
  void onNotification(String name, dynamic param) {
    if (name == AppLivecycle.notifyStateChanged) {
      if (param == AppLifecycleState.resumed) {
        _reloadAuthCardIfNeeded();
        _reloadUserPiiDataIfNeeded();
        _checkCapitolStaffRosterEnabled();
      }
    }
    else if (name == UserProfile.notifyProfileDeleted) {
      logout();
    }
    else if (name == Config.notifyConfigChanged) {
      _checkCapitolStaffConfigEnabled();
    }
  }

  // Shibboleth Oauth

  void authenticateWithShibboleth() {
    String authUrl = AppWeb.appHost() + '/auth/login';
    _launchUrl(authUrl);
  }

  //TBD: Leave it as a reference. Remove it after we have proper login and proper retrieving of a user details
  Future<void> _handleShibbolethAuthentication(code) async {
    
    List<dynamic> results;
    NotificationService().notify(notifyStarted);


    // 1. Request Tokens 
    AuthToken newAuthToken = await _loadShibbolethAuthTokenWithCode(code);
    if (newAuthToken == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    // 2. Request Rokmetro token
    // RokmetroToken newRokmetroToken = await _loadRokmetroToken(optAuthToken: newAuthToken);
    // if (newRokmetroToken == null) {
    //   _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
    //   return;
    // }

    // 3. Request AuthUser & RokmetroUser
    // results = await Future.wait([
    //   _loadShibbolethAuthUser(optAuthToken: newAuthToken),
    //   _loadRokmetroUser(optRokmetroToken: newRokmetroToken)
    // ]);

    AuthUser newAuthUser = ((results != null) && (0 < results.length)) ? results[0] : null;
    if (newAuthUser == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    RokmetroUser newRokmetroUser = ((results != null) && (1 < results.length)) ? results[1] : null;
    if (newRokmetroUser == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    // 4. Request UserProfile PersonalData and AuthCard
    results = await Future.wait([
      _loadUserPersonalDataWithShibbolethAuth(optAuthToken: newAuthToken, optAuthUser: newAuthUser),
      _loadAuthCardStringFromNet(optAuthToken: newAuthToken, optAuthUser: newAuthUser),
    ]);

    _UserPersonalData userPersonalData = ((results != null) && (0 < results.length)) ? results[0] : null;
    String newUserPiiDataString = userPersonalData?.userPiiDataString;
    UserPiiData newUserPiiData = userPersonalData?.userPiiData;
    UserProfileData newUserProfile = userPersonalData?.userProfile;
    if ((newUserPiiDataString == null) || (newUserPiiData == null) || (newUserProfile == null)) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    String authCardString = ((results != null) && (1 < results.length)) ? results[1] : null;
    AuthCard authCard = _authCardFromJsonString(authCardString);

    // Everything is fine - cleanup and store new tokens and data
    // 5. Clear everything before proceed further. Notification is not required at this stage
    _clear(false);

    // 6. Store everythong and notify everyone
    // 6.1 AuthToken
    Storage().authToken = _authToken = newAuthToken;
    NotificationService().notify(notifyAuthTokenChanged);

    // 6.2 AuthUser
    Storage().authUser = _authUser = newAuthUser;
    NotificationService().notify(notifyUserChanged);

    // 6.3 RokmetroToken
    // Storage().rokmetroToken = _rokmetroToken = newRokmetroToken;

    // 6.4 RokmetroUser
    Storage().rokmetroUser = _rokmetroUser = newRokmetroUser;
   
    // 5.5 Update UserPiiData if need and then apply
    if(newUserPiiData.updateFromAuthUser(newAuthUser)){
      storeUserPiiData(newUserPiiData);
    }
    else {
      _applyUserPiiData(newUserPiiData, newUserPiiDataString);
    }

    // 6.6 apply UserProfile
    _applyUserProfile(newUserProfile);

    // 6.7 AuthCard
    _applyAuthCard(authCard, authCardString);

    // 6.8 notifyLoggedIn event
    _notifyAuthLoginSucceeded(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
  }

  Future<AuthToken> _loadShibbolethAuthTokenWithCode(String code) async {

    String tokenUriStr = Config().shibbolethOidcTokenUrl
        ?.replaceAll("{shibboleth_client_id}", Config().shibbolethClientId ?? '')
        ?.replaceAll("{shibboleth_client_secret}", Config().shibbolethClientSecret ?? '');

    Map<String,dynamic> bodyData = {
      'code': code,
      'grant_type': 'authorization_code',
      'redirect_uri': REDIRECT_URI,
    };
    Http.Response response;
    try {
      response = (tokenUriStr != null) ? await Network().post(tokenUriStr,body: bodyData) : null;
      String responseBody = (response != null && response.statusCode == 200) ? response.body : null;
      Map<String,dynamic> jsonData = AppString.isStringNotEmpty(responseBody) ? AppJson.decode(responseBody) : null;
      if(jsonData != null){
        //TBD: DD - web - to be removed
        // return ShibbolethToken.fromJson(jsonData);
        return null;
      }
    }
    catch(e) { print(e?.toString()); }
    return null;
  }

  // Phone verification

  // Returns 'true' if code was send, otherwise - false
  Future<bool> initiatePhoneNumber(String phoneNumberCandidate, VerificationMethod verifyMethod) async {
    if (AppString.isStringEmpty(phoneNumberCandidate) || verifyMethod == null || AppString.isStringEmpty(Config().rokwireAuthUrl)) {
      return false;
    }

    String url = "${Config().rokwireAuthUrl}/phone-initiate";
    String channel = (verifyMethod == VerificationMethod.call) ? 'call' : 'sms';
    String body = AppJson.encode({
      "phoneNumber":"$phoneNumberCandidate",
      "channel":"$channel"
    });
    var headers = {
      "Content-Type": "application/json"
    };
    final response = await Network().post(url, body: body, headers: headers, auth: Network.AppAuth);
    if (response != null) {
      return (response.statusCode >= 200 && response.statusCode <= 300);
    }
    else {
      return false;
    }
  }

  // Returns 'true' if phone number was validate successfully, otherwise - false
  Future<bool> validatePhoneNumber(String code, String phoneNumber) async {

    if (AppString.isStringEmpty(phoneNumber) || AppString.isStringEmpty(code) || AppString.isStringEmpty(Config().rokwireAuthUrl)) {
      return false;
    }

    List<dynamic> results;
    NotificationService().notify(notifyStarted);

    // 1. Validate phone and code
    AuthToken newAuthToken = await _validatePhoneCode(phone: phoneNumber, code: code);
    if (newAuthToken == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginPhoneActionName);
      return false;
    }

    // 2. Request Rokmetro token
    // RokmetroToken newRokmetroToken = await _loadRokmetroToken(optAuthToken: newAuthToken);
    // if (newRokmetroToken == null) {
    //   _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
    //   return false;
    // }

    // 3. Request RokmetroUser && AuthUser
    results = await Future.wait([
      // _loadRokmetroUser(optRokmetroToken: newRokmetroToken),
      _loadRokmetroUser(),
      Config().capitolStaffRoleEnabled ? _loadPhoneAuthUser(optAuthToken: newAuthToken) : Future<AuthUser>.value(null),
      _loadUserPersonalDataWithPhoneAuth(phone: phoneNumber, optAuthToken: newAuthToken)
    ]);

    RokmetroUser newRokmetroUser = ((results != null) && (0 < results.length)) ? results[0] : null;
    if (newRokmetroUser == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return false;
    }

    // Do not fail if Aith User is NA, keep allowing regular phone flow
    AuthUser newAuthUser = ((results != null) && (1 < results.length)) ? results[1] : null;

    _UserPersonalData userPersonalData = ((results != null) && (2 < results.length)) ? results[2] : null;
    String newUserPiiDataString = userPersonalData?.userPiiDataString;
    UserPiiData newUserPiiData = userPersonalData?.userPiiData;
    UserProfileData newUserProfile = userPersonalData?.userProfile;
    if ((newUserPiiDataString == null) || (newUserPiiData == null) || (newUserProfile == null)) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return false;
    }

    // Everything is fine - cleanup and store new tokens and data
    // 4. Clear everything before proceed further. Notification is not required at this stage
    _clear(false);

    // 5. Store everything and notify everyone
    // 5.1 AuthToken
    Storage().authToken = _authToken = newAuthToken;
    NotificationService().notify(notifyAuthTokenChanged);

    // 5.2 AuthUser
    Storage().authUser = _authUser = newAuthUser;
    NotificationService().notify(notifyUserChanged);

    // 5.3 RokmetroToken
    // Storage().rokmetroToken = _rokmetroToken = newRokmetroToken;

    // 5.4 RokmetroUser
    Storage().rokmetroUser = _rokmetroUser = newRokmetroUser;
   
    // 5.5 Update UserPiiData if need and then apply
    if(newAuthUser != null && newUserPiiData.updateFromAuthUser(newAuthUser)){
      storeUserPiiData(newUserPiiData);
    }
    else {
      _applyUserPiiData(newUserPiiData, newUserPiiDataString);
    }

    // 5.6 apply UserProfile
    _applyUserProfile(newUserProfile);

    // 5.7 notifyLoggedIn event
    _notifyAuthLoginSucceeded(analyticsAction: Analytics.LogAuthLoginPhoneActionName);

    return true;
  }

  Future<AuthToken> _validatePhoneCode({String phone, String code}) async {
    String phoneVerifyBody = '{"phoneNumber":"$phone", "code":"$code"}';
    var headers = {
      "Content-Type": "application/json"
    };
    final response = await Network().post(
        '${Config().rokwireAuthUrl}/phone-verify', body: phoneVerifyBody, headers: headers, auth: Network.AppAuth);
    if ((response != null) &&
        (response.statusCode >= 200 && response.statusCode <= 300)) {
      Map<String, dynamic> jsonData = AppJson.decode(response.body);
      if (jsonData != null) {
        bool succeeded = jsonData['success'];
        if (succeeded && jsonData.containsKey("id_token")) {
          return PhoneToken(phone: phone, idToken:jsonData["id_token"]);
        }
      }
    }
    return null;
  }

  // Clear / Logout
  
  void logout() {
    _logout().then((success) {
      if (success) {
        _clear(true);
      }
    });
  }

  void _clear([bool notify = false]) {
    Storage().authToken = _authToken = null;
    Storage().authUser = _authUser = null;
    // Storage().rokmetroToken = _rokmetroToken = null;
    Storage().rokmetroUser = _rokmetroUser = null;
    _authCard = null;

    _applyUserPiiData(null, null);

    _clearAuthCard();

    if(notify) {
      NotificationService().notify(notifyUserChanged);
      NotificationService().notify(notifyCardChanged);
      NotificationService().notify(notifyAuthTokenChanged);
      _notifyAuthLoggedOut();
    }
  }

  Future<bool> _logout() async {
    String host = AppWeb.appHost();
    if (AppString.isStringEmpty(host)) {
      return false;
    }
    String signOutUrl = '$host/auth/logout';
    try {
      Response response = await Network().get(signOutUrl);
      bool success = (response.statusCode == 200);
      if (!success) {
        Log.e('Failed to logout. Reason:');
        Log.e(response.body);
      }
      return success;
    } catch (e) {
      print(e.toString());
    }
    return false;
  }

  // Public accessories

  AuthToken get authToken {
    return _authToken;
  }
  
  PhoneToken get phoneToken {
    return _authToken is PhoneToken ? _authToken : null;
  }

  AuthUser get authUser {
    return _authUser;
  }

  RokmetroUser get rokmetroUser {
    return _rokmetroUser;
  }

  UserPiiData get userPiiData {
    return _userPiiData;
  }

  AuthCard get authCard {
    return _authCard;
  }

  bool get isLoggedIn {
    String swcSessCookie = AppWeb.getCookie('swc-sess');
    return AppString.isStringNotEmpty(swcSessCookie);
  }

  bool get isShibbolethLoggedIn {
    String rokmetroUserAuth = _rokmetroUser?.auth;
    return 'oidc' == rokmetroUserAuth;
  }

  bool get isPhoneLoggedIn {
    return phoneToken != null;
  }

  bool get hasUIN {
    return (0 < (_authUser?.uin?.length ?? 0));
  }

  bool get isEventEditor {
    return _authUser?.groupMembership?.contains('urn:mace:uiuc.edu:urbana:authman:app-rokwire-service-policy-rokwire event approvers') ?? false;
  }

  bool get isStadiumPollManager {
    return _authUser?.groupMembership?.contains('urn:mace:uiuc.edu:urbana:authman:app-rokwire-service-policy-rokwire stadium poll manager') ?? false;
  }

  bool get isDebugManager {
    return _authUser?.groupMembership?.contains('urn:mace:uiuc.edu:urbana:authman:app-rokwire-service-policy-rokwire debug') ?? false;
  }

  bool isMemberOf(String groupName) {
    return _authUser?.groupMembership?.contains(groupName) ?? false;
  }

  bool get isCapitolStaff {
    return isPhoneLoggedIn && hasUIN;
  }

  Future<Uint8List> get photoImageBytes async {
    Uint8List bytes;
    if(Auth().isShibbolethLoggedIn){
      bytes = await Auth().authCard.photoBytes;
    }
    else if(Auth().isPhoneLoggedIn){
      bytes = await Auth().userPiiData.photoBytes;
    }
    return bytes;
  }

  String get fullUserName {
    String userName = authUser?.fullName;
    if (AppString.isStringEmpty(userName)) {
      userName = userPiiData?.fullName;
    }
    return userName;
  }

  // Auth User

  Future<AuthUser> _loadShibbolethAuthUser({AuthToken optAuthToken}) async {
    optAuthToken = (optAuthToken != null) ? optAuthToken : _authToken;
    if (Config().shibbolethOidcUserUrl != null) {
      try {
        Http.Response userDataResp = await Network().get(Config().shibbolethOidcUserUrl, headers: {HttpHeaders.authorizationHeader : "${optAuthToken?.tokenType} ${optAuthToken?.accessToken}"});
        String responseBody = ((userDataResp != null) && (userDataResp.statusCode == 200)) ? userDataResp.body : null;
        if ((responseBody != null) && (userDataResp.statusCode == 200)) {
          var userDataMap = (responseBody != null) ? AppJson.decode(responseBody) : null;
          return (userDataMap != null) ? ShibbolethAuthUser.fromJson(userDataMap) : null;
        }
      }
      catch(e) { print(e.toString()); }
    }
    return null;
  }

  Future<AuthUser> _loadPhoneAuthUser({AuthToken optAuthToken}) async {
    dynamic result = await _loadCapitolStaffUIN(optAuthToken: optAuthToken);
    return (result is AuthUser) ? result : null;
  }

  Future<dynamic> _loadCapitolStaffUIN({AuthToken optAuthToken}) async {
    optAuthToken = (optAuthToken != null) ? optAuthToken : _authToken;
    PhoneToken phoneToken = (optAuthToken is PhoneToken) ? optAuthToken : null;
    if ((Config().healthUrl != null) && (phoneToken?.phone != null)) {
      String url = "${Config().healthUrl}/covid19/rosters/phone/${phoneToken.phone}";
      Http.Response userDataResp = await Network().get(url, auth: Network.AppAuth);
      if ((userDataResp != null) && (userDataResp.statusCode == 200)) {
        Map<String, dynamic> responseJson = AppJson.decodeMap(userDataResp.body);
        //TMP: return AuthUser(uin: '000000000');
        // AuthUser or null, if the user does not bellong to roster
        return (responseJson != null) ? PhoneAuthUser.fromJson(responseJson) : null;
      }
      else {
        // Request failed
        return Exception("${userDataResp?.statusCode} ${userDataResp?.body}");
      }
    }
    else {
      // Not Available
      return false;
    }
  }

  bool _checkCapitolStaffConfigEnabled() {
    if (!isCapitolStaff) {
      return null;
    }
    else if (Config().capitolStaffRoleEnabled) {
      return true;
    }
    else {
      logout();
      return false;
    }
  }

  void _checkCapitolStaffRosterEnabled() {
    if (_checkCapitolStaffConfigEnabled() == true) {
      _loadCapitolStaffUIN().then((dynamic result) {
        if (result == null) {
          logout();
        }
      });
    }
  }

  /// Rokmetro User

  Future<RokmetroUser> _loadRokmetroUser() async {
    if ((Config().rokmetroAuthUrl != null)) {
      try {
        String url = "${Config().rokmetroAuthUrl}/user-info";
        Http.Response response = await Network().get(url);
        String responseBody = (response?.statusCode == 200) ? response.body : null;
        Map<String, dynamic> responseJson = (responseBody != null) ? AppJson.decodeMap(responseBody) : null;
        return (responseJson != null) ? RokmetroUser.fromJson(responseJson) : null;
      } catch (e) {
        print(e?.toString());
      }
    }
    return null;
  }

  Future<void> _ensureRokmetroData() async {
    // if ((_authToken != null) && (_rokmetroToken == null)) {
    //   Storage().rokmetroToken = _rokmetroToken = await _loadRokmetroToken(optAuthToken: _authToken);
    // }
    if (_rokmetroUser == null) {
      Storage().rokmetroUser = _rokmetroUser = await _loadRokmetroUser();
    }
  }

  /// UserPIIData

  Future<String> _loadPidWithPhoneAuth({String phone, AuthToken optAuthToken}) async {
    return await _loadPidWithData(
      data:{'uuid' : UserProfile().uuid, 'phone': phone},
      optAuthToken: optAuthToken
    );
  }

  Future<String> _loadPidWithShibbolethAuth({String email, AuthToken optAuthToken}) async {
    return await _loadPidWithData(
        data:{'uuid' : UserProfile().uuid, 'email': email,},
        optAuthToken: optAuthToken
    );
  }

  Future<String> _loadPidWithData({Map<String,String> data, AuthToken optAuthToken}) async {
    String url = (Config().userProfileUrl != null) ? '${Config().userProfileUrl}/pii' : null;
    optAuthToken = (optAuthToken != null) ? optAuthToken : authToken;

    final response = (url != null) ? await Network().post(url,
        headers: {'Content-Type':'application/json', HttpHeaders.authorizationHeader: "${optAuthToken?.tokenType} ${optAuthToken?.idToken}"},
        body: json.jsonEncode(data),
    ) : null;
    String responseBody = ((response != null) && (response.statusCode == 200)) ? response.body : null;
    Map<String, dynamic> jsonData = (responseBody != null) ? AppJson.decode(responseBody) : null;
    String userPid = (jsonData != null) ? jsonData['pid'] : null;
    return userPid;
  }

  Future<UserPiiData> storeUserPiiData(UserPiiData piiData) async {
    if(piiData != null) {
      String url = (Config().userProfileUrl != null) ? '${Config().userProfileUrl}/pii/${piiData.pid}' : null;
      String body = json.jsonEncode(piiData.toJson());
      final response = (url != null) ? await Network().put(url,
          headers: {'Content-Type':'application/json'},
          body: body,
          auth: Network.ShibbolethUserAuth
      ) : null;

      String responseBody = ((response != null) && (response.statusCode == 200)) ? response.body : null;
      Map<String, dynamic> jsonData = (responseBody != null) ? AppJson.decode(responseBody) : null;
      UserPiiData userPiiData = (jsonData != null) ? UserPiiData.fromJson(jsonData) : null;
      if(userPiiData != null) {
        _applyUserPiiData(userPiiData, responseBody);
        return userPiiData;
      } else {
        // This is a kind of workaround if the backend fails - still to save the data locally
        _applyUserPiiData(piiData, json.jsonEncode(piiData.toJson()));
        return piiData;
      }

    }
    return null;
  }

  Future<void> deleteUserPiiData() async {
    if (Config().userProfileUrl != null) {
      String url = '${Config().userProfileUrl}/pii/${Storage().userPid}';

      await Network().delete(url,
          headers: {'Content-Type':'application/json'},
          auth: Network.ShibbolethUserAuth
      ).whenComplete((){
        _applyUserPiiData(null, null);
      });
    }
  }

  void _applyUserPiiData(UserPiiData userPiiData, String userPiiDataString, [bool notify = true]) {
    if (_userPiiData != userPiiData) {
      _userPiiData = userPiiData;
      Storage().userPid = userPiiData?.pid;
      _saveUserPiiDataStringToCache(userPiiDataString);
      if(notify) {
        NotificationService().notify(notifyUserPiiDataChanged);
      }
    }
  }

  Future<void> _syncProfilePiiDataIfNeed() async {
    if(isShibbolethLoggedIn){
      UserPiiData piiData = userPiiData;
      if((piiData != null) && piiData.updateFromAuthUser(_authUser)){
        storeUserPiiData(piiData);
      }
    }
  }

  Future<File> _getUserPiiCacheFile() async {
    //TBD: DD - web
    if (kIsWeb) {
      return null;
    }
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String cacheFilePath = join(appDocDir.path, _userPiiFileName);
    return File(cacheFilePath);
  }

  Future<String> _loadUserPiiDataStringFromCache() async {
    //TBD: DD - web
    if (kIsWeb) {
      return null;
    }
    try {
      return ((_userPiiCacheFile != null) && await _userPiiCacheFile.exists()) ? await _userPiiCacheFile.readAsString() : null;
    }
    on Exception catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<void> _saveUserPiiDataStringToCache(String value) async {
    try {
      if (_userPiiCacheFile != null) {
        if (value != null) {
          await _userPiiCacheFile.writeAsString(value, flush: true);
        }
        else if (await _userPiiCacheFile.exists()) {
          await _userPiiCacheFile.delete();
        }
      }
    }
    on Exception catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<UserPiiData> _loadUserPiiDataFromCache() async {
    return _userPiiDataFromJsonString(await _loadUserPiiDataStringFromCache());
  }

  Future<String> _loadUserPiiDataStringFromNet({String pid, AuthToken optAuthToken}) async {
    pid = (pid != null) ? pid : Storage().userPid;
    optAuthToken = (optAuthToken != null) ? optAuthToken : authToken;
    try {
      String url = (Config().userProfileUrl != null) ? '${Config().userProfileUrl}/pii/$pid' : null;
      final response = (url != null) ? await Network().get(url, headers: {
        HttpHeaders.authorizationHeader: "${optAuthToken?.tokenType} ${optAuthToken?.idToken}"
      }) : null;
      return ((response != null) && (response.statusCode == 200)) ? response.body : null;
    }
    catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<void> _reloadUserPiiDataIfNeeded() async {
    if (this.isLoggedIn) {
      DateTime now = DateTime.now();
      int timeUpdate = Storage().userPiiDataTime;
      DateTime dateUpdate = (0 < timeUpdate) ? DateTime.fromMillisecondsSinceEpoch(timeUpdate) : null;
      if (!kReleaseMode || (dateUpdate == null) || (now.difference(dateUpdate).inSeconds < (3600 * 24))) {
        await reloadUserPiiData();
        Storage().userPiiDataTime = now.millisecondsSinceEpoch;
      }
    }
  }

  Future<UserPiiData> reloadUserPiiData({String pid, AuthToken optAuthToken}) async {
    String jsonString = await _loadUserPiiDataStringFromNet(pid: pid, optAuthToken: optAuthToken);
    UserPiiData userPiiData = _userPiiDataFromJsonString(jsonString);
    if(userPiiData != null && userPiiData != _userPiiData) { // Redo: Ensure the request is not failed - do not remove it!!!!
      _applyUserPiiData(userPiiData, jsonString);
    }
    return _userPiiData;
  }

  UserPiiData _userPiiDataFromJsonString(String jsonString) {
    try {
      Map<String, dynamic> jsonData = (jsonString != null) ? AppJson.decode(jsonString) : null;
      return (jsonData != null) ? UserPiiData.fromJson(jsonData) : null;
    } on Exception catch (e) {
      print(e.toString());
    }
    return null;
  }

  // User Profile Data

  Future<UserProfileData> _loadUserProfile({String userUuid}) async {
    try { return (userUuid != null) ? await UserProfile().requestProfile(userUuid) : null; }
    catch (_) { return null; }
  }

  void _applyUserProfile(UserProfileData userProfile) {
    UserProfile().applyProfileData(userProfile);
  }

  // User Personal Data

  Future<_UserPersonalData> _loadUserPersonalDataWithShibbolethAuth({AuthToken optAuthToken, AuthUser optAuthUser}) async {
    optAuthToken = (optAuthToken != null) ? optAuthToken : _authToken;
    optAuthUser = (optAuthUser != null) ? optAuthUser : _authUser;

    String userPiiPid = await _loadPidWithShibbolethAuth(email: optAuthUser?.email, optAuthToken: optAuthToken);
    String userPiiDataString = (userPiiPid != null) ? await _loadUserPiiDataStringFromNet(pid: userPiiPid, optAuthToken: optAuthToken) : null;
    UserPiiData userPiiData = (userPiiDataString != null) ? _userPiiDataFromJsonString(userPiiDataString) : null;
    UserProfileData userProfile = (userPiiData?.uuid != null) ? await _loadUserProfile(userUuid: userPiiData.uuid) : null;
    return _UserPersonalData(userPiiDataString: userPiiDataString, userPiiData: userPiiData, userProfile: userProfile );
  }

  Future<_UserPersonalData> _loadUserPersonalDataWithPhoneAuth({AuthToken optAuthToken, String phone}) async {
    optAuthToken = (optAuthToken != null) ? optAuthToken : _authToken;

    String userPiiPid = await _loadPidWithPhoneAuth(phone: phone, optAuthToken: optAuthToken);
    String userPiiDataString = (userPiiPid != null) ? await _loadUserPiiDataStringFromNet(pid: userPiiPid, optAuthToken: optAuthToken) : null;
    UserPiiData userPiiData = (userPiiDataString != null) ? _userPiiDataFromJsonString(userPiiDataString) : null;
    UserProfileData userProfile = (userPiiData?.uuid != null) ? await _loadUserProfile(userUuid: userPiiData.uuid) : null;
    return _UserPersonalData(userPiiDataString: userPiiDataString, userPiiData: userPiiData, userProfile: userProfile );
  }

  // Auth Card

  void _applyAuthCard(AuthCard authCard, String authCardJson) {
    _authCard = authCard;
    _saveAuthCardStringToCache(authCardJson);
    NotificationService().notify(notifyCardChanged);
  }

  Future<File> _getAuthCardCacheFile() async {
    //TBD: DD - web
    if (kIsWeb) {
      return null;
    }
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String cacheFilePath = join(appDocDir.path, _authCardName);
    return File(cacheFilePath);
  }

  Future<String> _loadAuthCardStringFromCache() async {
    //TBD: DD - web
    if (kIsWeb) {
      return null;
    }
    try {
      return ((_authCardCacheFile != null) && await _authCardCacheFile.exists()) ? await _authCardCacheFile.readAsString() : null;
    }
    on Exception catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<void> _saveAuthCardStringToCache(String value) async {
    try {
      if (_authCardCacheFile != null) {
        if (value != null) {
          await _authCardCacheFile.writeAsString(value, flush: true);
        }
        else if (await _authCardCacheFile.exists()) {
          await _authCardCacheFile.delete();
        }
      }
    }
    on Exception catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<AuthCard> _loadAuthCardFromCache() async {
    return _authCardFromJsonString(await _loadAuthCardStringFromCache());
  }

  Future<String> _loadAuthCardStringFromNet({AuthToken optAuthToken, AuthUser optAuthUser}) async {
    optAuthToken = (optAuthToken != null) ? optAuthToken : _authToken;
    optAuthUser = (optAuthUser != null) ? optAuthUser : _authUser;
    try {
      String url = Config().iCardUrl;
      Map<String, String> headers = {
        'UIN': optAuthUser?.uin,
        'access_token': optAuthToken?.accessToken
      };
      Response response = (url != null) ? await Network().post(url, headers: headers) : null;
      return (response != null) && (response.statusCode == 200) ? response.body : null;
    }
    catch(e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> _reloadAuthCardIfNeeded() async {
    if (this.hasUIN) {
      DateTime now = DateTime.now();
      int timeUpdate = Storage().authCardTime;
      DateTime dateUpdate = (0 < timeUpdate) ? DateTime.fromMillisecondsSinceEpoch(timeUpdate) : null;
      if (!kReleaseMode || (dateUpdate == null) || (now.difference(dateUpdate).inSeconds > (3600 * 24))) {
        await _reloadAuthCard();
        Storage().authCardTime = now.millisecondsSinceEpoch;
      }
    }
  }

  Future<void> _reloadAuthCard() async {
    String jsonString = await _loadAuthCardStringFromNet();
    AuthCard authCard = _authCardFromJsonString(jsonString);
    if(authCard != null && _authCard != authCard) { // Redo: Ensure the request is not failed - do not remove it!!!!
      _applyAuthCard(authCard, jsonString);
    }
  }

  AuthCard _authCardFromJsonString(String jsonString) {
    try {
      Map<String, dynamic> jsonData = (jsonString != null) ? AppJson.decode(jsonString) : null;
      return (jsonData != null) ? AuthCard.fromJson(jsonData) : null;
    } on Exception catch (e) {
      print(e.toString());
    }
    return null;
  }

  void _clearAuthCard() {
    if (_authCard != null) {
      _authCard = null;
      _saveAuthCardStringToCache(null);
    }
  }

  // CSRF Token

  Future<void> _loadCsrfToken() async {
    String url = AppWeb.appHost() + '/csrf-token';
    Response response = await Network().get(url);
    int responseCode = response?.statusCode ?? -1;
    bool success = (responseCode == 200);
    String responseBody = response?.body;
    if (success) {
      _csrfToken = responseBody;
    } else {
      _csrfToken = null;
      Log.e('Failed to load csrf token. Reason:');
      Log.e(responseBody);
    }
  }

  String get csrfToken {
    return _csrfToken;
  }

  // Deep Links

  void _launchUrl(urlStr) async {
    // Open the url under the same tab
    html.window.location.href = urlStr;
  }

  // AuthListeners

  void _notifyAuthLoginSucceeded({String analyticsAction}){
    if (analyticsAction != null) {
      Analytics().logAuth(action: analyticsAction, result: true);
    }
    NotificationService().notify(notifyLoginSucceeded);
    NotificationService().notify(notifyLoginChanged);
  }

  void _notifyAuthLoginFailed({String analyticsAction}){
    if (analyticsAction != null) {
      Analytics().logAuth(action: analyticsAction, result: false);
    }
    NotificationService().notify(notifyLoginFailed);
  }

  void _notifyAuthLoggedOut(){
    Analytics().logAuth(action: Analytics.LogAuthLogoutActionName);
    NotificationService().notify(notifyLoggedOut);
    NotificationService().notify(notifyLoginChanged);
  }

}

enum VerificationMethod { call, sms }

class _UserPersonalData {
  final UserPiiData userPiiData;
  final String userPiiDataString;
  final UserProfileData userProfile;
  _UserPersonalData({this.userPiiData, this.userPiiDataString, this.userProfile});
}