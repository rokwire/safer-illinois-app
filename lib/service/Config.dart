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
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:illinois/model/Organization.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Organizations.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:package_info/package_info.dart';
import 'package:collection/collection.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class Config with Service implements NotificationsListener {

  static const String _configFileName           = "config.json";

  static const String notifyUpgradeRequired        = "edu.illinois.rokwire.config.upgrade.required";
  static const String notifyUpgradeAvailable       = "edu.illinois.rokwire.config.upgrade.available";
  static const String notifyOnboardingRequired     = "edu.illinois.rokwire.config.onboarding.required";
  static const String notifyNotificationAvailable  = "edu.illinois.rokwire.config.notification.available";
  static const String notifyConfigChanged          = "edu.illinois.rokwire.config.changed";

  Map<String, dynamic> _config;
  
  PackageInfo          _packageInfo;
  Directory            _appDocumentsDir; 
  DateTime             _pausedDateTime;
  
  final Set<String>    _reportedUpgradeVersions = Set<String>();

  // Singletone Instance

  Config._internal();
  static final Config _instance = Config._internal();

  factory Config() {
    return _instance;
  }
  
  static Config get instance {
    return _instance;
  }
  // Service

  @override
  void createService() {
    NotificationService().subscribe(this, [
      AppLivecycle.notifyStateChanged,
      FirebaseMessaging.notifyConfigUpdate
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {

    if (_packageInfo == null) {
      _packageInfo = await PackageInfo.fromPlatform();
    }

    if (_appDocumentsDir == null) {
      _appDocumentsDir = await getApplicationDocumentsDirectory();
      Log.d('Application Documents Directory: ${_appDocumentsDir.path}');
    }

    _config = await _loadFromFile(_configFile);

    if (_config != null) {
        _checkUpgrade();
        _checkOnboarding();
        _checkNotification();
        _updateFromNet();
    }
    else if (Organizations().organization != null) {
      String configString = await _loadAsStringFromNet(apiHook: Organizations().configApiHook);

      _config = (configString != null) ? _configFromJsonString(configString) : null;
      if (_config != null) {
        _configFile.writeAsStringSync(configString, flush: true);
        NotificationService().notify(notifyConfigChanged, null);
        
        _checkUpgrade();
        _checkOnboarding();
        _checkNotification();
      }
    }
    else {
        // Unable to load
    }
  }

  @override
  Future<void> clearService() async {
    AppFile.delete(_configFile);
    _config = null;
    _reportedUpgradeVersions.clear();
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Organizations()]);
  }

  File get _configFile {
    String configFilePath = join(_appDocumentsDir.path, _configFileName);
    return File(configFilePath);
  }

  Future<Map<String, dynamic>> _loadFromFile(File configFile) async {
    try {
      String configContent = (configFile != null) ? await configFile.readAsString() : null;
      return _configFromJsonString(configContent);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<String> _loadAsStringFromNet({ApiHook apiHook}) async {
    try {
      String requestUrl = apiHook?.url ?? this.appConfigUrl;
      String requestApiKey = apiHook?.apiKey ?? this.rokwireApiKey;
      http.Response response = await Network().get(requestUrl, headers: {
        Network.RokwireApiKey : requestApiKey
      });
      return ((response != null) && (response.statusCode == 200)) ? response.body : null;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Map<String, dynamic> _configFromJsonString(String configJsonString) {
    dynamic configJson =  AppJson.decode(configJsonString);
    List<dynamic> jsonList = (configJson is List) ? configJson : null;
    if (jsonList != null) {
      
      jsonList.sort((dynamic cfg1, dynamic cfg2) {
        return ((cfg1 is Map) && (cfg2 is Map)) ? AppVersion.compareVersions(cfg1['mobileAppVersion'], cfg2['mobileAppVersion']) : 0;
      });

      for (int index = jsonList.length - 1; index >= 0; index--) {
        Map<String, dynamic> cfg = jsonList[index];
        if (AppVersion.compareVersions(cfg['mobileAppVersion'], appVersion) <= 0) {
          _decodeSecretKeys(cfg);
          return cfg;
        }
      }
    }

    return null;
  }

  bool _decodeSecretKeys(Map<String, dynamic> config) {
    dynamic secretKeys = (config != null) ? config['secretKeys'] : null;
    if (secretKeys is String) {
      String jsonString = AESCrypt.decode(secretKeys);
      dynamic jsonData = AppJson.decode(jsonString);
      if (jsonData is Map) {
        config['secretKeys'] = jsonData;
        return true;
      }
    }
    return false;
  }

  void _updateFromNet() {
    _loadAsStringFromNet().then((String configString) {
      Map<String, dynamic> config = _configFromJsonString(configString);
      if ((config != null) && (AppVersion.compareVersions(_config['mobileAppVersion'], config['mobileAppVersion']) <= 0) && !DeepCollectionEquality().equals(_config, config))  {
        _config = config;
        _configFile.writeAsString(configString, flush: true);
        NotificationService().notify(notifyConfigChanged, null);

        _checkUpgrade();
        _checkOnboarding();
        _checkNotification();
      }
    });
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == AppLivecycle.notifyStateChanged) {
      _onAppLivecycleStateChanged(param);
    }
    else if (name == FirebaseMessaging.notifyConfigUpdate) {
      _updateFromNet();
    }
  }

  void _onAppLivecycleStateChanged(AppLifecycleState state) {
    
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      if (_pausedDateTime != null) {
        Duration pausedDuration = DateTime.now().difference(_pausedDateTime);
        if (refreshTimeout < pausedDuration.inSeconds) {
          _updateFromNet();
        }
      }
    }
  }

  // Upgrade

  String get appId {
    return _packageInfo?.packageName;
  }

  String get appVersion {
    return _packageInfo?.version;
  }

  String get upgradeRequiredVersion {
    dynamic requiredVersion = _upgradeStringEntry('required_version');
    if ((requiredVersion is String) && (AppVersion.compareVersions(appVersion, requiredVersion) < 0)) {
      return requiredVersion;
    }
    return null;
  }

  String get upgradeAvailableVersion {
    dynamic availableVersion = _upgradeStringEntry('available_version');
    bool upgradeAvailable = (availableVersion is String) &&
        (AppVersion.compareVersions(appVersion, availableVersion) < 0) &&
        !Storage().reportedUpgradeVersions.contains(availableVersion) &&
        !_reportedUpgradeVersions.contains(availableVersion);
    return upgradeAvailable ? availableVersion : null;
  }

  String get upgradeUrl {
    return _upgradeStringEntry('url');
  }

  void setUpgradeAvailableVersionReported(String version, { permanent : false }) {
    if (permanent) {
      Storage().reportedUpgradeVersion = version;
    }
    else {
      _reportedUpgradeVersions.add(version);
    }
  }

  void _checkUpgrade() {
    String value;
    if ((value = this.upgradeRequiredVersion) != null) {
      NotificationService().notify(notifyUpgradeRequired, value);
    }
    else if ((value = this.upgradeAvailableVersion) != null) {
      NotificationService().notify(notifyUpgradeAvailable, value);
    }
  }

  String _upgradeStringEntry(String key) {
    dynamic entry = upgradeInfo[key];
    if (entry is String) {
      return entry;
    }
    else if (entry is Map) {
      dynamic value = entry[Platform.operatingSystem.toLowerCase()];
      return (value is String) ? value : null;
    }
    else {
      return null;
    }
  }

  // Onboarding

  String get onboardingRequiredVersion {
    dynamic requiredVersion = onboardingInfo['required_version'];
    if ((requiredVersion is String) && (AppVersion.compareVersions(requiredVersion, appVersion) <= 0)) {
      return requiredVersion;
    }
    return null;
  }

  void _checkOnboarding() {
    String value;
    if ((value = this.onboardingRequiredVersion) != null) {
      NotificationService().notify(notifyOnboardingRequired, value);
    }
  }

  // Notification

  void _checkNotification() {
    Map<String, dynamic> value;
    if ((value = this.notification) != null) {
      NotificationService().notify(notifyNotificationAvailable, value);
    }
  }

  // Assets cache path

  Directory get appDocumentsDir {
    return _appDocumentsDir;
  }

  Directory get assetsCacheDir  {

    String assetsUrl = this.assetsUrl;
    String assetsCacheDir = _appDocumentsDir?.path;
    if ((assetsCacheDir != null) && (assetsUrl != null)) {
      try {
        Uri assetsUri = Uri.parse(assetsUrl);
        if (assetsUri?.pathSegments != null) {
          for (String pathSegment in assetsUri.pathSegments) {
            assetsCacheDir = join(assetsCacheDir, pathSegment);
          }
        }
      }
      on Exception catch(e) {
        print(e.toString());
      }
    }

    return (assetsCacheDir != null) ? Directory(assetsCacheDir) : null;
  }


  // Config Getters

  Map<String, dynamic> get otherUniversityServices { return (_config != null) ? (_config['otherUniversityServices'] ?? {}) : {}; }
  Map<String, dynamic> get platformBuildingBlocks  { return (_config != null) ? (_config['platformBuildingBlocks'] ?? {}) : {}; }
  Map<String, dynamic> get thirdPartyServices      { return (_config != null) ? (_config['thirdPartyServices'] ?? {}) : {}; }

  Map<String, dynamic> get oidc                    { return (_config != null) ? (_config['oidc'] ?? {}) : {}; }

  Map<String, dynamic> get secretKeys              { return (_config != null) ? (_config['secretKeys'] ?? {}) : {}; }
  Map<String, dynamic> get secretRokwire           { return secretKeys['rokwire'] ?? {}; }
  Map<String, dynamic> get secretOidc              { return secretKeys['oidc'] ?? {}; }
  Map<String, dynamic> get secretOsf               { return secretKeys['osf'] ?? {}; }
  Map<String, dynamic> get secretHealth            { return secretKeys['health'] ?? {}; }
  
  Map<String, dynamic> get settings                { return (_config != null) ? (_config['settings'] ?? {}) : {}; }
  Map<String, dynamic> get upgradeInfo             { return (_config != null) ? (_config['upgrade'] ?? {}) : {}; }
  Map<String, dynamic> get onboardingInfo          { return (_config != null) ? (_config['onboarding'] ?? {}) : {}; }
  Map<String, dynamic> get notification            { return (_config != null) ? _config['notification'] : null; }

  String get assetsUrl              { return otherUniversityServices['assets_url']; }         // "https://rokwire-assets.s3.us-east-2.amazonaws.com"
  String get getHelpUrl             { return otherUniversityServices['get_help_url']; }       // "https://forms.illinois.edu/sec/4961936"
  String get iCardUrl               { return otherUniversityServices['icard_url']; }          // "https://www.icard.uillinois.edu/rest/rw/rwIDData/rwCardInfo"
  String get privacyPolicyUrl       { return otherUniversityServices['privacy_policy_url']; } // "https://www.vpaa.uillinois.edu/resources/web_privacy"

  String get oidcAuthUrl            { return oidc['auth_url']; }                              // "https://shibboleth.illinois.edu/idp/profile/oidc/authorize"
  String get oidcTokenUrl           { return oidc['token_url']; }                             // "https://{oidc_client_id}:{oidc_client_secret}@shibboleth.illinois.edu/idp/profile/oidc/token"
  String get oidcUserUrl            { return oidc['user_url']; }                              // "https://shibboleth.illinois.edu/idp/profile/oidc/userinfo"
  String get oidcRedirectUrl        { return oidc['redirect_url']; }                          // "edu.illinois.covid://covid.illinois.edu/shib-auth"
  String get oidcScope              { return oidc['scope']; }                                 // "openid profile email offline_access"
  String get oidcClaims             { return oidc['claims']; }                                // "{\"userinfo\":{\"uiucedu_uin\":{\"essential\":true}}}"
  bool   get oidcUsePkce            { return oidc['pkce']; }                              // true | false | null

  String get appConfigUrl           { return platformBuildingBlocks['appconfig_url']; }       // "https://api-dev.rokwire.illinois.edu/app/configs"
  String get loggingUrl             { return platformBuildingBlocks['logging_url']; }         // "https://api-dev.rokwire.illinois.edu/logs"
  String get userProfileUrl         { return platformBuildingBlocks['user_profile_url']; }    // "https://api-dev.rokwire.illinois.edu/profiles"
  String get rokwireAuthUrl         { return platformBuildingBlocks['rokwire_auth_url']; }    // "https://api-dev.rokwire.illinois.edu/authentication"
  String get groupsUrl              { return platformBuildingBlocks["groups_url"]; }          // "https://api-dev.rokwire.illinois.edu/gr/api";
  String get rokmetroAuthUrl        { return platformBuildingBlocks['rokmetro_auth_url']; }   // "https://api-dev.rokwire.illinois.edu/authbb/77779"
  String get sportsServiceUrl       { return platformBuildingBlocks['sports_service_url']; }  // "https://api-dev.rokwire.illinois.edu/sports-service";
  String get healthUrl              { return platformBuildingBlocks['health_url']; }          // "https://api-dev.rokwire.illinois.edu/health"
  String get transportationUrl      { return platformBuildingBlocks["transportation_url"]; }  // "https://api-dev.rokwire.illinois.edu/transportation"
  String get imagesServiceUrl       { return platformBuildingBlocks['images_service_url']; }  // "https://api-dev.rokwire.illinois.edu/images-service";
  
  String get osfBaseUrl             { return thirdPartyServices['osf_base_url']; }            // "https://ssproxy.osfhealthcare.org/fhir-proxy"
  String get vaccinationAppointUrl  { return thirdPartyServices['vaccination_appointment_url']; }            // "https://ssproxy.osfhealthcare.org/fhir-proxy"

  String get rokwireApiKey          { return secretRokwire['api_key']; }

  String get oidcClientId           { return secretOidc['client_id']; }
  String get oidcClientSecret       { return secretOidc['client_secret']; }

  String get osfClientId            { return secretOsf['client_id']; }

  String get healthPublicKey        { return secretHealth['public_key']; }
  String get healthApiKey           { return secretHealth['api_key']; }

  int get refreshTimeout            { return kReleaseMode ? (settings['refreshTimeout'] ?? 0) : 0; }

  bool get residentRoleEnabled      { return false; }
  bool get capitolStaffRoleEnabled  { return (settings['roleCapitolStaffEnabled'] == true); }

}

