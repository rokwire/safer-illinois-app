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
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:http/http.dart';
import 'package:firebase_messaging/firebase_messaging.dart' as FirebaseMessagingPlugin;
import 'package:illinois/model/Health.dart';
import 'package:illinois/model/UserProfile.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/FirebaseService.dart';
import 'package:illinois/service/Health.dart';

import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Organizations.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/service/LocalNotifications.dart';
import 'package:illinois/utils/Utils.dart';

class FirebaseMessaging with Service implements NotificationsListener {

  static const String notifyToken                 = "edu.illinois.rokwire.firebase.messaging.token";
  static const String notifyPopupMessage          = "edu.illinois.rokwire.firebase.messaging.message.popup";
  static const String notifyConfigUpdate          = "edu.illinois.rokwire.firebase.messaging.config.update";
  static const String notifySettingUpdated        = "edu.illinois.rokwire.firebase.messaging.setting.updated";
  static const String notifyCovid19Notification   = "edu.illinois.rokwire.firebase.messaging.health.covid19.notification";

  static const String _commonTopicCategory        = "common";
  static const String _notifyTopicCategory        = "notify";
  static const String _roleTopicCategory          = "role";
  static const String _healthStatusTopicCategory  = "health-status";

  // Topic names
  static const List<String> _permanentTopics = [
    "$_commonTopicCategory.config-update",
    "$_commonTopicCategory.popup-message",
  ];

  // Settings entry : topic name
  static const Map<String, String> _notifySettingTopics = {
    'notify_covid19'   : '$_notifyTopicCategory.covid19'
  };


  String   _token;
  String   _projectID;
  DateTime _pausedDateTime;
  
  List<Map<String, dynamic>> _messagesCache;

  // Singletone instance

  FirebaseMessaging._internal();
  static final FirebaseMessaging _firebase = FirebaseMessaging._internal();
  FirebaseMessagingPlugin.FirebaseMessaging _firebaseMessaging = FirebaseMessagingPlugin.FirebaseMessaging();

  factory FirebaseMessaging() {
    return _firebase;
  }

  static FirebaseMessaging get instance {
    return _firebase;
  }

  // Public getters

  String get token => _token;
  String get projectID => _projectID;
  bool get hasToken => AppString.isStringNotEmpty(_token);

  // Service

  @override
  void createService() {
    NotificationService().subscribe(this, [
      UserProfile.notifyRolesUpdated,
      UserProfile.notifyProfileUpdated,
      UserProfile.notifyProfileDeleted,
      Health.notifyUserUpdated,
      Health.notifyStatusUpdated,
      LocalNotifications.notifySelected,
      AppLivecycle.notifyStateChanged,
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {
    
    // Cache messages until UI is displayed
    _messagesCache = List<Map<String, dynamic>>();

    _firebaseMessaging.configure(
      onMessage: _onFirebaseMessage,
      onBackgroundMessage: null, // causes exception in FirebaseMessaging plugin 
      onLaunch: _onFirebaseLaunch,
      onResume: _onFirebaseResume,
    );
    
    _firebaseMessaging.getToken().then((String token) {
      _token = token;
      Log.d('FCM: token: $token');
      NotificationService().notify(notifyToken, null);
      _updateSubscriptions();
    });
    
    //The project id is not given via the lib so we need to get it via NativeCommunicator
    NativeCommunicator().queryFirebaseInfo().then((String info) {
      _projectID = info;
    });
  }

  @override
  void initServiceUI() {
    _processCachedMessages();
  }

  @override
  Future<void> clearService() async {
    _clearSubscriptions();
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([FirebaseService(), Storage(), Config(), UserProfile()]);
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == UserProfile.notifyRolesUpdated) {
      _updateRolesSubscriptions();
    }
    else if (name == UserProfile.notifyProfileUpdated) {
      _updateSubscriptions();
    }
    else if (name == UserProfile.notifyProfileDeleted) {
      _updateSubscriptions();
    }
    else if (name == Health.notifyUserUpdated) {
      _updateHealthStatusSubscriptions();
    }
    else if (name == Health.notifyStatusUpdated) {
      _updateHealthStatusSubscriptions(status: Health().status);
    }
    else if (name == LocalNotifications.notifySelected) {
      _processDataMessage(AppJson.decode(param));
    }
    else if (name == AppLivecycle.notifyStateChanged) {
      _onAppLivecycleStateChanged(param); 
    }
  }

  void _onAppLivecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
    }
    else if (state == AppLifecycleState.resumed) {
      if (_pausedDateTime != null) {
        Duration pausedDuration = DateTime.now().difference(_pausedDateTime);
        if (Config().refreshTimeout < pausedDuration.inSeconds) {
          _updateSubscriptions();
        }
      }
    }
  }

  // Subscription APIs

  Future<bool> subscribeToTopic(String topic) async {
    if (topic == null) {
      return false;
    }

    if (_token == null) {
      Log.e("FCM: Unable to subscribe to $topic topic (missing token)");
      return false;
    }

    try {
      if (Config().sportsServiceUrl != null) {
        String url =  "${Config().sportsServiceUrl}/api/subscribe";
        String body = json.encode({'token': _token, 'topic': topic});
        Response response = await Network().post(url, body: body, auth: NetworkAuth.App, headers: { Network.RokwireAppId: Config().appId });
        if ((response != null) && (response.statusCode == 200)) {
          Log.d("FCM: Succesfully subscribed for $topic topic");
          Storage().addFirebaseSubscriptionTopic(topic);
          return true;
        } else {
          Log.e("FCM: Error occured on subscribing for $topic topic");
        }
      }
    } catch (e) {
      Log.e(e.toString());
    }
    return false;
  }

  Future<bool> unsubscribeFromTopic(String topic) async {
    if (topic == null) {
      return false;
    }

    if (_token == null) {
      Log.e("FCM: Unable to unsubscribe to $topic topic (missing token)");
      return false;
    }

    try {
      if (Config().sportsServiceUrl != null) {
        String url =  "${Config().sportsServiceUrl}/api/unsubscribe";
        String body = json.encode({'token': _token, 'topic': topic});
        Response response = await Network().post(url, body: body, auth: NetworkAuth.App, headers: { Network.RokwireAppId: Config().appId });
        if ((response != null) && (response.statusCode == 200)) {
          Log.d("FCM: Succesfully unsubscribed from $topic topic");
          Storage().removeFirebaseSubscriptionTopic(topic);
          return true;
        } else {
          Log.e("FCM: Error occured on unsubscribe from $topic topic");
        }
      }
    } catch (e) {
      Log.e(e.toString());
    }
    return false;
  }

  Future<bool> send({String topic, dynamic message}) async {
    try {
      if (Config().sportsServiceUrl != null) {
        String url = "${Config().sportsServiceUrl}/api/message";
        String body = json.encode({'topic': topic, 'message': message});
        final response = await Network().post(url, timeout: 10, body: body, auth: NetworkAuth.App, headers: {
          "Accept": "application/json",
          "content-type": "application/json",
          Network.RokwireAppId : Config().appId
        });
        if ((response != null) && (response.statusCode == 200)) {
          return true;
        }
      }
    } catch (e) {
      Log.e(e.toString());
    }
    return false;
  }

  // Message Processing

  Future<dynamic> _onFirebaseMessage(Map<String, dynamic> message) async {
    Log.d("FCM: onFirebaseMessage");
    _onMessageProcess(message);
  }

  Future<dynamic> _onFirebaseLaunch(Map<String, dynamic> message) async {
    Log.d("FCM: onFirebaseLaunch");
    _onMessageProcess(message);
  }

  Future<dynamic> _onFirebaseResume(Map<String, dynamic> message) async {
    Log.d("FCM: onFirebaseResume");
    _onMessageProcess(message);
  }

  ///We need to process Android and iOS differently as the plugin gives different format for the both platforms.

  ///Android
  ///{
  ///    notification: {title: null, body: null},
  ///    data: {Period: 1, VisitingScore: 20, HomeScore: 14, Path: football, Type: football, IsComplete: false, ClockSeconds: -1, Custom: {"Possession":"","LastPlay":"","Clock":"","Phase":"Pregame"}, GameId: 16692, HasStarted: false}
  ///}

  ///iOS
  ///{GameId: 16692, IsComplete: false, gcm.message_id: 1572250193655080, VisitingScore: 20, HomeScore: 14, Custom: {"Possession":"","LastPlay":"","Clock":"","Phase":"Pregame"}, Type: football, Path: football, aps: {content-available: 1}, ClockSeconds: -1, HasStarted: false, Period: 1}
  void _onMessageProcess(Map<String, dynamic> message) {
    if (message != null) {
      if (_messagesCache != null) {
        Log.d("FCM: cacheMessage: $message");
        _messagesCache.add(message);
      }
      else {
        _processMessage(message);
      }
    }
  }

  void _processMessage(Map<String, dynamic> message) {
    Log.d("FCM: onMessageProcess: $message");
    if (message != null) {
      try {
        if (Platform.isIOS) {
          Log.d("FCM: iOS message");
          _processDataMessage(message.cast<String, dynamic>());
        } else {
          dynamic data = message["data"];
          dynamic notification = message["notification"];
          String title = (notification != null) ? notification["title"] : null;
          String body = (notification != null) ? notification["body"] : null;
          if (AppString.isStringNotEmpty(title) || AppString.isStringNotEmpty(body)) {
            Log.d("FCM: Android notification message");
            //Explicitly show it only when in foreground
            String notificationPayload = (data != null) ? json.encode(data) : null;
            LocalNotifications().showNotification(title: title, message: body, payload: notificationPayload);
          }
          else if (data != null) {
            Log.d("FCM: Android data message");
            _processDataMessage(data.cast<String, dynamic>());
          }
        }
      }
      catch(e) {
        print(e.toString());
      }
    }
  }

  void _processDataMessage(Map<String, dynamic> data) {
    String type = _getMessageType(data);
    if (type == "config_update") {
      _onConfigUpdate(data);
    }
    else if (type == "popup_message") {
      NotificationService().notify(notifyPopupMessage, data);
    }
    else if (type == "health.covid19.notification") {
      NotificationService().notify(notifyCovid19Notification, data);
    }
    else {
      Log.d("FCM: unknown message type: $type");
    }
  }

  String _getMessageType(Map<String, dynamic> data) {
    if (data == null)
      return null;

    //1. check type
    String type = data["type"];
    if (type != null)
      return type;

    //2. check Type - deprecated!
    String type2 = data["Type"];
    if (type2 != null)
      return type2;

    //3. check Path - deprecated!
    String path = data["Path"];
    if (path != null) {
      String gameId = data['GameId'];
      dynamic hasStarted = data['HasStarted'];
      // Handle 'Game Started / Ended' notification which does not contain key 'HasStarted'
      if (AppString.isStringNotEmpty(gameId) && (hasStarted == null)) {
        return 'athletics_game_started';
      } else {
        return path;
      }
    }

    //treat everything else as config update - the backend gives it without "type"!
    return "config_update";
  }

  void _onConfigUpdate(Map<String, dynamic> data) {
    int interval = 5 * 60; // 5 minutes
    var rng = new Random();
    int delay = rng.nextInt(interval);
    Log.d("FCM: Scheduled config update after ${delay.toString()} seconds");
    Timer(Duration(seconds: delay), () {
      Log.d("FCM: Perform config update");
      NotificationService().notify(notifyConfigUpdate, data);
    });
  }

  void _processCachedMessages() {
    if (_messagesCache != null) {
      List<Map<String, dynamic>> messagesCache = _messagesCache;
      _messagesCache = null;

      for (Map<String, dynamic> message in messagesCache) {
        _processMessage(message);
      }
    }
  }

  // Settings topics

  bool get notifyCovid19                      { return _getNotifySetting('notify_covid19'); } 
       set notifyCovid19(bool value)          { _setNotifySetting('notify_covid19', value); }

  bool _getNotifySetting(String name) {
    return Storage().getNotifySetting(name) ?? true;
  } 

  void _setNotifySetting(String name, bool value) {
    if (_getNotifySetting(name) != value) {
      Storage().setNotifySetting(name, value);
      NotificationService().notify(notifySettingUpdated, name);

      Set<String> subscribedTopics = Storage().firebaseSubscriptionTopis;
      _processNotifySettingSubscription(topic: _topicName(_notifySettingTopics[name]), value: value, subscribedTopics: subscribedTopics);
    }
  }

  // Subscription Management

  void _updateSubscriptions() {
    if (hasToken) {
      Set<String> subscribedTopics = Storage().firebaseSubscriptionTopis;
      _processPermanentSubscriptions(subscribedTopics: subscribedTopics);
      _processRolesSubscriptions(subscribedTopics: subscribedTopics);
      _processHealthStatusSubscriptions(subscribedTopics: subscribedTopics);
      _processNotifySettingsSubscriptions(subscribedTopics: subscribedTopics);
    }
  }

  void _clearSubscriptions() {
    if (hasToken) {
      Set<String> subscribedTopics = Storage().firebaseSubscriptionTopis;
      if (subscribedTopics != null) {
        for (String topic in subscribedTopics) {
          unsubscribeFromTopic(topic);
        }
      }
    }
  }

  void _updateRolesSubscriptions() {
    if (hasToken) {
      _processRolesSubscriptions(subscribedTopics: Storage().firebaseSubscriptionTopis);
    }
  }

  void _updateHealthStatusSubscriptions({ HealthStatus status}) {
    if (hasToken) {
      _processHealthStatusSubscriptions(status: status, subscribedTopics: Storage().firebaseSubscriptionTopis);
    }
  }

  void _processPermanentSubscriptions({Set<String> subscribedTopics}) {
    for (String permanentTopicsEntry in _permanentTopics) {
      String permanentTopic = _topicName(permanentTopicsEntry);
      if ((subscribedTopics == null) || !subscribedTopics.contains(permanentTopic)) {
        subscribeToTopic(permanentTopic);
      }
    }
  }

  void _processRolesSubscriptions({Set<String> subscribedTopics}) {
    Set<UserRole> roles = UserProfile().roles;
    for (UserRole role in UserRole.values) {
      String roleTopic = _topicName("$_roleTopicCategory.${role.toString()}");
      bool roleSubscribed = (subscribedTopics != null) && subscribedTopics.contains(roleTopic);
      bool roleSelected = (roles != null) && roles.contains(role);
      if (roleSelected && !roleSubscribed) {
        subscribeToTopic(roleTopic);
      }
      else if (!roleSelected && roleSubscribed) {
        unsubscribeFromTopic(roleTopic);
      }
    }
  }

  void _processHealthStatusSubscriptions({ HealthStatus status, Set<String> subscribedTopics}) {
    if (!Health().isUserLoggedIn) {
      _processHealthStatusTopicsSubscriptions(statusTopics: null, subscribedTopics: subscribedTopics);
    }
    else if (status != null) {
      _processHealthStatusTopicsSubscriptions(statusTopics: status?.blob?.fcmTopics, subscribedTopics: subscribedTopics);
    }
  }

  void _processHealthStatusTopicsSubscriptions({Set<String> statusTopics, Set<String> subscribedTopics}) {
    // Add all statusTopics entries that does not persist in subscribedTopics
    if (statusTopics != null) {
      for (String statusTopic in statusTopics) {
        String topic = _topicName("$_healthStatusTopicCategory.$statusTopic");
        if ((subscribedTopics == null) || !subscribedTopics.contains(topic)) {
          subscribeToTopic(topic);
        }
      }
    }

    // Remove all health status entries from subscribedTopics that does not persist in statusTopics
    if (subscribedTopics != null) {
      String healthStatusPrefix = _topicName("$_healthStatusTopicCategory.");
      for (String subscribedTopic in subscribedTopics) {
        if (subscribedTopic.startsWith(healthStatusPrefix)) {
          String topic = subscribedTopic.substring(healthStatusPrefix.length);
          if ((statusTopics == null) || !statusTopics.contains(topic)) {
            unsubscribeFromTopic(topic);
          }
        }
      }
    }
  }
  
  void _processNotifySettingsSubscriptions({Set<String> subscribedTopics}) {
    _notifySettingTopics.forEach((String setting, String topic) {
      bool value = _getNotifySetting(setting);
      _processNotifySettingSubscription(topic: _topicName(topic), value: value, subscribedTopics: subscribedTopics);
    });
  }

  void _processNotifySettingSubscription({String topic, bool value, Set<String> subscribedTopics}) {
    if (topic != null) {
      bool itemSubscribed = (subscribedTopics != null) && subscribedTopics.contains(topic);
      if (value && !itemSubscribed) {
        subscribeToTopic(topic);
      }
      else if (!value && itemSubscribed) {
        unsubscribeFromTopic(topic);
      }
    }
  }

  String _topicName(String topicKey) {
    return (Organizations().organization.id != null) ? "${Organizations().organization.id}.$topicKey" : topicKey;
  }

}
