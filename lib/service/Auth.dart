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
import 'package:illinois/model/UserData.dart';
import 'package:illinois/model/UserPiiData.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/DeepLink.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'package:illinois/service/User.dart';
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

  static final Auth _auth = Auth._internal();

  AuthToken _authToken;
  AuthToken get authToken { return _authToken; }

  ShibbolethToken get shibbolethToken { return _authToken is ShibbolethToken ? _authToken : null; }
  PhoneToken get phoneToken { return _authToken is PhoneToken ? _authToken : null; }

  AuthUser _authUser;
  AuthUser get authUser { return _authUser; }

  RokmetroToken _rokmetroToken;
  RokmetroToken get rokmetroToken { return _rokmetroToken; }

  RokmetroUser _rokmetroUser;
  RokmetroUser get rokmetroUser { return _rokmetroUser; }

  UserPiiData _userPiiData;
  UserPiiData get userPiiData { return _userPiiData; }
  File _userPiiCacheFile;

  AuthCard _authCard;
  AuthCard get authCard { return _authCard; }
  File _authCardCacheFile;

  Future<Http.Response> _refreshTokenFuture;

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

  factory Auth() {
    return _auth;
  }

  Auth._internal();

  @override
  void createService() {
    NotificationService().subscribe(this, [
      DeepLink.notifyUri,
      AppLivecycle.notifyStateChanged,
      User.notifyUserDeleted,
      Config.notifyConfigChanged,
    ]);
  }

  @override
  Future<void> initService() async {
    _authToken = Storage().authToken;
    _authUser = Storage().authUser;

    _rokmetroToken = Storage().rokmetroToken;
    _rokmetroUser = Storage().rokmetroUser;

    _authCardCacheFile = await _getAuthCardCacheFile();
    _authCard = await _loadAuthCardFromCache();

    _userPiiCacheFile = await _getUserPiiCacheFile();
    _userPiiData = await _loadUserPiiDataFromCache();

    _syncProfilePiiDataIfNeed(); // No need for await
  }

  @override
  Future<void> clearService() async {
    _authToken = null;
    _authUser = null;

    _rokmetroToken = null;
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

  bool get isLoggedIn {
    return _authToken != null;
  }

  bool get isShibbolethLoggedIn {
    return shibbolethToken != null;
  }

  bool get isPhoneLoggedIn {
    return phoneToken != null;
  }

  bool get hasUIN {
    return (0 < (_authUser?.uin?.length ?? 0));
  }

  bool get isEventEditor {
    return _authUser?.userGroupMembership?.contains('urn:mace:uiuc.edu:urbana:authman:app-rokwire-service-policy-rokwire event approvers') ?? false;
  }

  bool get isStadiumPollManager {
    return _authUser?.userGroupMembership?.contains('urn:mace:uiuc.edu:urbana:authman:app-rokwire-service-policy-rokwire stadium poll manager') ?? false;
  }

  bool get isDebugManager {
    return _authUser?.userGroupMembership?.contains('urn:mace:uiuc.edu:urbana:authman:app-rokwire-service-policy-rokwire debug') ?? false;
  }

  bool isMemberOf(String groupName) {
    return _authUser?.userGroupMembership?.contains(groupName) ?? false;
  }

  bool get isCapitolStaff {
    return isPhoneLoggedIn && hasUIN;
  }

  void logout(){
    _clear(true);
  }

  void _clear([bool notify = false]){
    _authToken = null;
    _authUser = null;
    _rokmetroToken = null;
    _rokmetroUser = null;
    _authCard = null;

    _applyUserPiiData(null, null);

    _saveAuthToken();
    _saveAuthUser();
    _saveRokmetroToken();
    _saveRokmetroUser();
    _clearAuthCard();

    if(notify) {
      _notifyAuthUserChanged();
      _notifyAuthCardChanged();
      _notifyAuthTokenChanged();
      _notifyAuthLoggedOut();
    }
  }

  ////////////////////////
  // Shibboleth Oauth

  void authenticateWithShibboleth(){
    
    if ((Config().shibbolethOidcAuthUrl != null) && (Config().shibbolethClientId != null)) {
      Uri uri = Uri.tryParse(Config().shibbolethOidcAuthUrl)?.replace(queryParameters: {
        'scope': "openid profile email offline_access",
        'response_type': 'code',
        'redirect_uri': REDIRECT_URI,
        'client_id': Config().shibbolethClientId,
        'claims': json.jsonEncode({
          'userinfo': {
            'uiucedu_uin': {'essential': true},
          },
        }),
      });
      var uriStr = uri?.toString();
      if (uriStr != null) {
        _launchUrl(uriStr);
      }
    }
  }

  Future<void> _handleShibbolethAuthentication(code) async {

    _notifyAuthStarted();

    NativeCommunicator().dismissSafariVC();

    // 1. Request Tokens 
    AuthToken newAuthToken = await _loadShibbolethAuthTokenWithCode(code);
    if (newAuthToken == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    // 2. Request Rokmetro token
    RokmetroToken newRokmetroToken = await _loadRokmetroToken(optAuthToken: newAuthToken);
    if (newRokmetroToken == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    // 3. Request AuthUser & RokmetroUser
    List<dynamic> userResults = await Future.wait([
      _loadShibbolethAuthUser(optAuthToken: newAuthToken),
      _loadRokmetroUser(optRokmetroToken: newRokmetroToken)
    ]);

    AuthUser newAuthUser = ((userResults != null) && (0 < userResults.length)) ? userResults[0] : null;
    if (newAuthUser == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    RokmetroUser newRokmetroUser = ((userResults != null) && (1 < userResults.length)) ? userResults[1] : null;
    if (newRokmetroUser == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    // 4. Request User Pii Pid
    String newUserPiiPid = await _loadPidWithShibbolethAuth(email: newAuthUser?.email, optAuthToken: newAuthToken);
    if (newUserPiiPid == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    // 5. Request UserPiiData
    String newUserPiiDataString = await _loadUserPiiDataStringFromNet(pid: newUserPiiPid, optAuthToken: newAuthToken);
    UserPiiData newUserPiiData = _userPiiDataFromJsonString(newUserPiiDataString);
    if(newUserPiiData == null || AppCollection.isCollectionEmpty(newUserPiiData?.uuidList)){
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    // 6. Request UserData &  AuthCard
    List<Future<dynamic>> dataFutures = <Future>[
      _loadUserProfile(userUuid: newUserPiiData.uuid),
    ];
    if (0 < (newAuthUser?.uin?.length ?? 0)) {
      dataFutures.add(
        _loadAuthCardStringFromNet(optAuthToken: newAuthToken, optAuthUser: newAuthUser)
      );
    }
    List<dynamic> dataResults = await Future.wait(dataFutures);

    UserData newUserProfile = ((dataResults != null) && (0 < dataResults.length)) ? dataResults[0] : null;
    if (newUserProfile == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
      return;
    }

    String authCardString = ((dataResults != null) && (1 < dataResults.length)) ? dataResults[1] : null;
    AuthCard authCard = _authCardFromJsonString(authCardString);

    // Everything is fine - cleanup and store new tokens and data
    // 7. Clear everything before proceed further. Notification is not required at this stage
    _clear(false);

    // 8. Store everythong and notify everyone
    // 8.1 AuthToken && AuthUser
    _authToken = newAuthToken;
    _authUser = newAuthUser;

    _saveAuthToken();
    _saveAuthUser();

    _notifyAuthTokenChanged();
    _notifyAuthUserChanged();

    // 8.2 RokmetroToken & RokmetroUser
    _rokmetroToken = newRokmetroToken;
    _rokmetroUser = newRokmetroUser;

    _saveRokmetroToken();
    _saveRokmetroUser();

    // 8.3 UserPiiData
    if(newUserPiiData.updateFromAuthUser(newAuthUser)){
      storeUserPiiData(newUserPiiData);
    }
    else {
      _applyUserPiiData(newUserPiiData, newUserPiiDataString);
    }

    // 8.4 UserProfile
    _applyUserProfile(newUserProfile);

    // 8.5 AuthCard
    _applyAuthCard(authCard, authCardString);

    _notifyAuthLoginSucceeded(analyticsAction: Analytics.LogAuthLoginNetIdActionName);
  }

  Future<void> _syncProfilePiiDataIfNeed() async {
    if(isShibbolethLoggedIn){
      UserPiiData piiData = userPiiData;
      if((piiData != null) && piiData.updateFromAuthUser(_authUser)){
        storeUserPiiData(piiData);
      }
    }
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
        return ShibbolethToken.fromJson(jsonData);
      }
    }
    catch(e) { print(e?.toString()); }
    return null;
  }

  Future<AuthUser> _loadShibbolethAuthUser({AuthToken optAuthToken}) async {
    optAuthToken = (optAuthToken != null) ? optAuthToken : _authToken;
    if (Config().shibbolethOidcUserUrl != null) {
      try {
        Http.Response userDataResp = await Network().get(Config().shibbolethOidcUserUrl, headers: {HttpHeaders.authorizationHeader : "${optAuthToken?.tokenType} ${optAuthToken?.accessToken}"});
        String responseBody = ((userDataResp != null) && (userDataResp.statusCode == 200)) ? userDataResp.body : null;
        if ((responseBody != null) && (userDataResp.statusCode == 200)) {
          var userDataMap = (responseBody != null) ? AppJson.decode(responseBody) : null;
          return (userDataMap != null) ? AuthUser.fromJson(userDataMap) : null;
        }
      }
      catch(e) { print(e.toString()); }
    }
    return null;
  }

  Future<RokmetroToken> _loadRokmetroToken({AuthToken optAuthToken}) async {
    if ((Config().rokmetroAuthUrl != null) && (Config().rokmetroApiKey != null)) {
      try {
        String url = "${Config().rokmetroAuthUrl}/swap-token";
        AuthToken token = optAuthToken ?? _authToken;
        String idToken = token?.idToken;
        String tokenType = token?.tokenType ?? 'Bearer';
        Map <String, String> headers = {
          Network.RokwireApiKey : Config().rokmetroApiKey,
          HttpHeaders.authorizationHeader: "$tokenType $idToken"
        };
        Http.Response response = await Network().get(url, headers: headers);
        String responseBody = (response?.statusCode == 200) ? response.body : null;
        return (responseBody != null) ? RokmetroToken(idToken: responseBody) : null;
      } catch(e) {
        print(e?.toString());
      }
    }
    return null;
  }

  Future<RokmetroUser> _loadRokmetroUser({RokmetroToken optRokmetroToken}) async {
    if ((Config().rokmetroAuthUrl != null) && (Config().rokmetroApiKey != null)) {
      try {
        String url = "${Config().rokmetroAuthUrl}/user-info";
        RokmetroToken token = optRokmetroToken ?? _rokmetroToken;
        String idToken = token?.idToken;
        String tokenType = token?.tokenType ?? 'Bearer';
        Map <String, String> headers = {
          Network.RokwireApiKey : Config().rokmetroApiKey,
          HttpHeaders.authorizationHeader: "$tokenType $idToken"
        };
        Http.Response response = await Network().get(url, headers: headers);
        String responseBody = (response?.statusCode == 200) ? response.body : null;
        Map<String, dynamic> responseJson = (responseBody != null) ? AppJson.decodeMap(responseBody) : null;
        return (responseJson != null) ? RokmetroUser.fromJson(responseJson) : null;
      } catch(e) {
        print(e?.toString());
      }
    }
    return null;
  }

  void _launchUrl(urlStr) async {
    try {
      if (await url_launcher.canLaunch(urlStr)) {
        await url_launcher.launch(urlStr);
      }
    }
    catch(e) {
      print(e);
    }
  }

  //Phone verification

  ///Returns 'true' if code was send, otherwise - false
  Future<bool> initiatePhoneNumber(String phoneNumberCandidate, VerificationMethod verifyMethod) async {
    if (AppString.isStringEmpty(phoneNumberCandidate) || verifyMethod == null || AppString.isStringEmpty(Config().rokwireAuthUrl)) {
      return false;
    }
    String channel = (verifyMethod == VerificationMethod.call) ? 'call' : 'sms';
    String phoneInitiateBody = '{"phoneNumber":"$phoneNumberCandidate", "channel":"$channel"}';
    var headers = {
      "Content-Type": "application/json"
    };
    final response = await Network().post(
        '${Config().rokwireAuthUrl}/phone-initiate', body: phoneInitiateBody, headers: headers, auth: NetworkAuth.App);
    if (response != null) {
      return (response.statusCode >= 200 && response.statusCode <= 300);
    }
    else {
      return false;
    }
  }

  ///Returns 'true' if phone number was validate successfully, otherwise - false
  Future<bool> validatePhoneNumber(String code, String phoneNumber) async {

    _notifyAuthStarted();

    if (AppString.isStringEmpty(phoneNumber) || AppString.isStringEmpty(code) || AppString.isStringEmpty(Config().rokwireAuthUrl)) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginPhoneActionName);
      return false;
    }

    // 1. Validate phone and code
    AuthToken newAuthToken = await _validatePhoneCode(phone: phoneNumber, code: code);
    if(newAuthToken == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginPhoneActionName);
      return false;
    }

    // 2. Request AuthUser
    // Do not fail if Aith Info is NA
    AuthUser newAuthUser = Config().capitolStaffRoleEnabled ? await _loadPhoneAuthUser(optAuthToken: newAuthToken) : null;

    // 3. Pii Pid
    String newUserPiiPid = await _loadPidWithPhoneAuth(phone: phoneNumber, optAuthToken: newAuthToken);
    if(newUserPiiPid == null) {
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginPhoneActionName);
      return false;
    }

    // 4. UserPiiData
    String newUserPiiDataString = await _loadUserPiiDataStringFromNet(pid: newUserPiiPid, optAuthToken: newAuthToken);
    UserPiiData newUserPiiData = _userPiiDataFromJsonString(newUserPiiDataString);
    if(newUserPiiData == null || AppCollection.isCollectionEmpty(newUserPiiData?.uuidList)){
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginPhoneActionName);
      return false;
    }

    // 5. UserData
    UserData newUserProfile;
    try {
      newUserProfile = await User().requestUser(newUserPiiData.uuidList.first);
    } on UserNotFoundException catch (_) {}
    if(newUserProfile == null){
      _notifyAuthLoginFailed(analyticsAction: Analytics.LogAuthLoginPhoneActionName);
      return false;
    }

    // Everything is fine - cleanup and store new tokens and data
    // 6. Clear everything before proceed further. Notification is not required at this stage
    _clear(false);

    // 7. Store everything and notify everyone
    // 7.1 AuthToken
    _authToken = newAuthToken;
    _saveAuthToken();
    _notifyAuthTokenChanged();

    // 7.2 AuthUser
    _authUser = newAuthUser;
    _saveAuthUser();
    _notifyAuthUserChanged();

    // 7.3 UserPiiData

    // 7.4 Update UserPiiData if need and then apply
    if(newAuthUser != null && newUserPiiData.updateFromAuthUser(newAuthUser)){
      storeUserPiiData(newUserPiiData);
    }
    else {
      _applyUserPiiData(newUserPiiData, newUserPiiDataString);
    }

    // 7.5 apply UserData
    User().applyUserData(newUserProfile);

    // 7.6 notifyLoggedIn event
    _notifyAuthLoginSucceeded(analyticsAction: Analytics.LogAuthLoginPhoneActionName);

    return true;
  }

  Future<AuthToken> _validatePhoneCode({String phone, String code}) async {
    String phoneVerifyBody = '{"phoneNumber":"$phone", "code":"$code"}';
    var headers = {
      "Content-Type": "application/json"
    };
    final response = await Network().post(
        '${Config().rokwireAuthUrl}/phone-verify', body: phoneVerifyBody, headers: headers, auth: NetworkAuth.App);
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

  Future<AuthUser> _loadPhoneAuthUser({AuthToken optAuthToken}) async {
    dynamic result = await _loadCapitolStaffUIN(optAuthToken: optAuthToken);
    return (result is AuthUser) ? result : null;
  }

  Future<dynamic> _loadCapitolStaffUIN({AuthToken optAuthToken}) async {
    optAuthToken = (optAuthToken != null) ? optAuthToken : _authToken;
    PhoneToken phoneToken = (optAuthToken is PhoneToken) ? optAuthToken : null;
    if ((Config().healthUrl != null) && (phoneToken?.phone != null)) {
      String url = "${Config().healthUrl}/covid19/rosters/phone/${phoneToken.phone}";
      Http.Response userDataResp = await Network().get(url, auth: NetworkAuth.App);
      if ((userDataResp != null) && (userDataResp.statusCode == 200)) {
        Map<String, dynamic> responseJson = AppJson.decodeMap(userDataResp.body);
        //TMP: return AuthUser(uin: '000000000');
        // AuthUser or null, if the user does not bellong to roster
        return (responseJson != null) ? AuthUser.fromRosterJson(responseJson) : null;
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

  /// UserPIIData

  Future<String> _loadPidWithPhoneAuth({String phone, AuthToken optAuthToken}) async {
    return await _loadPidWithData(
      data:{'uuid' : User().uuid, 'phone': phone},
      optAuthToken: optAuthToken
    );
  }

  Future<String> _loadPidWithShibbolethAuth({String email, AuthToken optAuthToken}) async {
    return await _loadPidWithData(
        data:{'uuid' : User().uuid, 'email': email,},
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
          auth: NetworkAuth.User
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
          auth: NetworkAuth.User
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
        _notifyAuthUserPiiDataChanged();
      }
    }
  }

  Future<File> _getUserPiiCacheFile() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String cacheFilePath = join(appDocDir.path, _userPiiFileName);
    return File(cacheFilePath);
  }

  Future<String> _loadUserPiiDataStringFromCache() async {
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

  Future<UserData> _loadUserProfile({String userUuid}) async {
    try { return await User().requestUser(userUuid); }
    catch (_) { return null; }
  }

  void _applyUserProfile(UserData userProfile) {
    User().applyUserData(userProfile);
  }

  // Auth Card

  void _applyAuthCard(AuthCard authCard, String authCardJson) {
    _authCard = authCard;
    _saveAuthCardStringToCache(authCardJson);
    _notifyAuthCardChanged();
  }

  Future<File> _getAuthCardCacheFile() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String cacheFilePath = join(appDocDir.path, _authCardName);
    return File(cacheFilePath);
  }

  Future<String> _loadAuthCardStringFromCache() async {
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

  // Refresh Token

  Future<void> doRefreshToken() async {
    if (isShibbolethLoggedIn && (Config().shibbolethOidcTokenUrl != null) && (Config().shibbolethClientId != null) && (Config().shibbolethClientSecret != null)) {
      if(_refreshTokenFuture != null){
        Log.d("Auth: will await refresh token");
        await _refreshTokenFuture;
        Log.d("Auth: did await refresh token");
      }
      else {
        try {
          Log.d("Auth: will refresh token");

          String tokenUriStr = Config().shibbolethOidcTokenUrl
              ?.replaceAll("{shibboleth_client_id}", Config().shibbolethClientId ?? '')
              ?.replaceAll("{shibboleth_client_secret}", Config().shibbolethClientSecret ?? '');
          
          Map<String, String> body = {
            "refresh_token": authToken?.refreshToken,
            "grant_type": "refresh_token",
          };

          _refreshTokenFuture = Network().post(tokenUriStr, body: body);
          Response tokenResponse = await _refreshTokenFuture;
          _refreshTokenFuture = null;

          String tokenResponseBody = ((tokenResponse != null) && (tokenResponse.statusCode == 200)) ? tokenResponse.body : null;
          Map<String, dynamic> bodyMap = (tokenResponseBody != null) ? AppJson.decodeMap(tokenResponseBody) : null;
          ShibbolethToken token = (bodyMap != null) ? ShibbolethToken.fromJson(bodyMap) : null;
          if (token?.idToken != null) {
            Log.d("Auth: did refresh token: ${authToken?.idToken}");
            _authToken = token;
            _saveAuthToken();
            _notifyAuthTokenChanged();
          }
        }
        catch(e) {
          print(e.toString());
          _refreshTokenFuture = null; // make sure to clear this in case something went wrong.
        }
      }
    }
  }

  // Utils

  void _saveAuthToken() {
    Storage().authToken = _authToken;
  }

  void _saveAuthUser() {
    Storage().authUser = _authUser;
  }

  void _saveRokmetroToken() {
    Storage().rokmetroToken = _rokmetroToken;
  }

  void _saveRokmetroUser() {
    Storage().rokmetroUser = _rokmetroUser;
  }

  void _clearAuthCard(){
    if (_authCard != null) {
      _authCard = null;
      _saveAuthCardStringToCache(null);
    }
  }

  ////////
  // AuthListeners

  void _notifyAuthStarted(){
    NotificationService().notify(notifyStarted, null);
  }

  void _notifyAuthTokenChanged(){
    NotificationService().notify(notifyAuthTokenChanged, null);
  }

  void _notifyAuthUserChanged(){
    NotificationService().notify(notifyUserChanged, null);
  }

  void _notifyAuthCardChanged(){
    NotificationService().notify(notifyCardChanged, null);
  }

  void _notifyAuthLoginSucceeded({String analyticsAction}){
    if (analyticsAction != null) {
      Analytics().logAuth(action: analyticsAction, result: true);
    }
    NotificationService().notify(notifyLoginSucceeded, null);
    _notifyAuthLoginChanged();
  }

  void _notifyAuthLoggedOut(){
    Analytics().logAuth(action: Analytics.LogAuthLogoutActionName);
    NotificationService().notify(notifyLoggedOut, null);
    _notifyAuthLoginChanged();
  }

  void _notifyAuthLoginFailed({String analyticsAction}){
    if (analyticsAction != null) {
      Analytics().logAuth(action: analyticsAction, result: false);
    }
    NotificationService().notify(notifyLoginFailed, null);
  }

  void _notifyAuthLoginChanged(){
    NotificationService().notify(notifyLoginChanged, null);
  }

  void _notifyAuthUserPiiDataChanged(){
    NotificationService().notify(notifyUserPiiDataChanged, null);
  }

  // NotificationsListener
  
  @override
  void onNotification(String name, dynamic param) {
    if (name == DeepLink.notifyUri) {
      _onDeepLinkUri(param);
    }
    else if (name == AppLivecycle.notifyStateChanged) {
      if (param == AppLifecycleState.resumed) {
        _reloadAuthCardIfNeeded();
        _reloadUserPiiDataIfNeeded();
        _checkCapitolStaffRosterEnabled();
      }
    }
    else if (name == User.notifyUserDeleted) {
      logout();
    }
    else if (name == Config.notifyConfigChanged) {
      _checkCapitolStaffConfigEnabled();
    }
  }

  void _onDeepLinkUri(Uri uri) {
    if (uri != null) {
      Uri shibbolethRedirectUri;
      try { shibbolethRedirectUri = Uri.parse(REDIRECT_URI); }
      catch(e) { print(e?.toString()); }

      var code = uri.queryParameters['code'];
      if ((shibbolethRedirectUri != null) &&
          (shibbolethRedirectUri.scheme == uri.scheme) &&
          (shibbolethRedirectUri.authority == uri.authority) &&
          (shibbolethRedirectUri.path == uri.path) &&
          ((code != null) && code.isNotEmpty))
      {
        _handleShibbolethAuthentication(code);
      }
    }
  }

}

enum VerificationMethod { call, sms }