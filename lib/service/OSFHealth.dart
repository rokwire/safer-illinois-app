


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

import 'package:http/http.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/DeepLink.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class OSFHealth with Service implements NotificationsListener {

  static const String notifyOnFetchBegin              = "edu.illinois.rokwire.osfhealth.fetch.begin";
  static const String notifyOnFetchFinished           = "edu.illinois.rokwire.osfhealth.fetch.finished";

  static const OSF_REDIRECT_URI = 'https://osf.rokwire.illinois.edu/oauth';

  // Singletone Instance

  OSFHealth._internal();

  static final OSFHealth _instance = new OSFHealth._internal();

  factory OSFHealth() {
    return _instance;
  }

  // Initialization

  @override
  void createService() {
    NotificationService().subscribe(this, [
      DeepLink.notifyUri,
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Storage(), Config(), Auth()]);
  }

  Future<void> authenticate() async{
    var uriStr = '${Config().osfBaseUrl}/oauth2/authorize?response_type=code&client_id=${Config().osfClientId}&redirect_uri=$OSF_REDIRECT_URI';
    url_launcher.canLaunch(uriStr).then((bool result) {
      if (result) {
        url_launcher.launch(uriStr,);
      }
    });
  }

  Future<void> _handleOSFAuthentication(String code) async{
    NotificationService().notify(notifyOnFetchBegin, null);
    NativeCommunicator().dismissSafariVC();
    int processedEntriesCount = 0;
    try {
      Response response = await Network().post("${Config().osfBaseUrl}/oauth2/token",
          headers: {"Accept": "application/json"},
          body: {
            "code": code,
            'grant_type': 'authorization_code',
            'redirect_uri': OSF_REDIRECT_URI,
            "client_id": Config().osfClientId,
          }
      );
      if (response?.statusCode == 200) {
        String responseBody = (response?.statusCode == 200) ? response.body : null;
        Map<String, dynamic> responseJson = (responseBody != null) ? AppJson.decode(responseBody) : null;
        if (responseJson != null) {
          AppToast.show("Logged in successfully");
          HealthOSFAuth _osfAuth = HealthOSFAuth.fromJson(responseJson);

          Response observationResponse = await Network().get("${Config().osfBaseUrl}/api/FHIR/DSTU2/Observation/?patient=${_osfAuth.patient}&category=laboratory",
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer ${_osfAuth.accessToken}"
            },
          );
          if (observationResponse?.statusCode == 200) {
            String observationBody = (observationResponse?.statusCode == 200) ? observationResponse.body : null;
            print(observationBody);
            List<Covid19OSFTest> osfTests = List<Covid19OSFTest>();
            Map<String, dynamic> observJson = (observationBody != null) ? AppJson.decode(observationBody) : null;
            if(observJson != null){
              List<dynamic> resultsList = observJson["entry"];
              if(resultsList is List){
                for(Map<String, dynamic> resultEntry in resultsList){
                  if(resultEntry is Map){
                    String code = AppMapPathKey.entry(resultEntry, "resource.code.text");
                    String dateStr = AppMapPathKey.entry(resultEntry, "resource.issued");
                    String valueStr = AppMapPathKey.entry(resultEntry, "resource.valueCodeableConcept.text");
                    if(valueStr == null){
                      valueStr = AppMapPathKey.entry(resultEntry, "resource.valueString");
                    }
                    if(code != null && dateStr != null && valueStr != null){
                      DateTime dateUtc;
                      try {
                        dateUtc = DateFormat("yyyy-MM-ddTHH:mm:ssZ").parse(dateStr, true);
                      } catch(e){ print(e); }
                      osfTests.add(Covid19OSFTest(
                          dateUtc: dateUtc,
                          provider: Storage().lastHealthProvider?.name,
                          providerId: Storage().lastHealthProvider?.id,
                          testType: code,
                          testResult: valueStr
                      ));
                    }
                    //AppJson
                  }
                }
              }
            }
            if(osfTests.isNotEmpty){
              processedEntriesCount = await Health().processOsfTests(osfTests: osfTests);
            }
          }
        }
      }
      else {
        AppToast.show("POST ${response.request.url.toString()} \n${response.reasonPhrase}");
      }
    } finally {
      NotificationService().notify(notifyOnFetchFinished, {"processedEntriesCount": processedEntriesCount});
    }
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == DeepLink.notifyUri) {
      _onDeepLinkUri(param);
    }
  }

  // Deeplink

  void _onDeepLinkUri(Uri uri) {
    if (uri != null) {
      Uri osfRedirectUri;
      try { osfRedirectUri = Uri.parse(OSF_REDIRECT_URI); }
      catch(e) { print(e?.toString()); }

      var code = uri.queryParameters['code'];
      if ((osfRedirectUri != null) &&
          (osfRedirectUri.scheme == uri.scheme) &&
          (osfRedirectUri.authority == uri.authority) &&
          (osfRedirectUri.path == uri.path) &&
          ((code != null) && code.isNotEmpty))
      {
        _handleOSFAuthentication(code);
      }
    }
  }
}