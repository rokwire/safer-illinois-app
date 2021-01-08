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
import 'package:http/http.dart';
import 'package:illinois/model/Organization.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/utils/Utils.dart';

class Organizations with Service {

  static const String notifyOrganizationChanged  = "edu.illinois.rokwire.organizations.organization.changed";
  static const String notifyEnvironmentChanged   = "edu.illinois.rokwire.organizations.environment.changed";

  Organization       _organization;
  List<Organization> _organizations;

  // Singletone Instance

  Organizations._internal();
  static final Organizations _instance = Organizations._internal();

  factory Organizations() {
    return _instance;
  }
  
  static Organizations get instance {
    return _instance;
  }

  // Service

  @override
  Future<void> initService() async {
    _organization = Storage().organization;
    if (_organization?.id == null) {
      _organizations = await _loadOrganizations();
      if (_organizations?.length == 1) {
        Storage().organization = _organization = _organizations.first;
      }
      else if (Storage().onBoardingPassed == true) {
        Storage().organization = _organization = Organization.findInList(_organizations, isDefault: true);
      }
    }
  }

  @override
  Future<void> clearService() async {
    _organization = null;
    _organizations = null;
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Storage()]);
  }

  // Implementation

  List<Organization> get organizations {
    return _organizations;
  }

  Organization get organization {
    return _organization;
  }

  Future<void> setOrganization(Organization organization, {bool notifyChanged = true}) async {
    if ((organization?.id != null) && (_organization?.id != organization.id)) {
      String environment = Storage().configEnvironment;
      List<Organization> organizations = _organizations;
      await Services().clear();
      _organizations = organizations;
      Storage().organization = organization;
      if (organization.hasEnvironment(environment)) {
        Storage().configEnvironment = environment;
      }
      await Services().init();
      if (notifyChanged == true) {
        NotificationService().notify(notifyOrganizationChanged);
      }
    }
  }

  String get environment {
    if (_organization != null) {
      String storageEnvironment = Storage().configEnvironment;
      if (_organization.hasEnvironment(storageEnvironment)) {
        return storageEnvironment;
      }
      return _organization.defaultEnvironment;
    }
    return null;
  }

  Future<void> setEnvironment(String value, {bool notifyChanged = true}) async {
    if ((_organization != null) && _organization.hasEnvironment(value) && (environment != value)) {
      Organization organization = _organization;
      List<Organization> organizations = _organizations;
      await Services().clear();
      _organizations = organizations;
      Storage().organization = organization;
      Storage().configEnvironment = (organization.defaultEnvironment != value) ? value : null;
      await Services().init();
      if (notifyChanged == true) {
        NotificationService().notify(notifyEnvironmentChanged);
      }
    }
  }

  bool get isDevEnvironment {
    return this.environment == 'dev';
  }

  bool get isTestEnvironment {
    return this.environment == 'test';
  }

  ApiHook get configApiHook {
    return _organization?.apiHook(environment: this.environment);
  }

  Future<List<Organization>> ensureOrganizations() async {
    if (_organizations == null) {
      _organizations = await _loadOrganizations();
    }
    return _organizations;
  }

  static Future<List<Organization>> _loadOrganizations() async {
    if (!Auth().isLoggedIn) {
      return null;
    }
    String url = AppWeb.host() + '/assets/buckets/items/organizations';
    Response response;
    try {
      response = await Network().get(url);
    } catch (e) {
      Log.e(e.toString());
    }
    String responseString = (response?.statusCode == 200) ? response.body : null;
    List<dynamic> responseJson = (responseString != null) ? AppJson.decodeList(responseString) : null;
    return (responseJson != null) ? Organization.listFromJson(responseJson) : null;
  }
}