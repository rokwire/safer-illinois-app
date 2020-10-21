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

import 'package:flutter/foundation.dart';

class Organization {
  final String id;
  final String name;
  final String iconUrl;
  final dynamic _isDefault;
  final Map<String, ApiHook> environments;

  Organization({this.id, this.name, this.iconUrl, dynamic isDefault, this.environments}) :
    _isDefault = isDefault;

  factory Organization.fromJson(Map<String, dynamic> json) {
    return (json != null) ? Organization(
      id: json['id'],
      name: json['name'],
      iconUrl: json['icon_url'],
      isDefault: json['default'],
      environments: ApiHook.mapFromJson(json['environments']),
    ) : null;
  }

  dynamic toJson() {
    return {
      'id': id,
      'name': name,
      'icon_url': iconUrl,
      'default': _isDefault,
      'environments': ApiHook.mapToJson(environments)
    };
  }

  bool get isDefault {
    return _parseDefault(_isDefault);
  }

  ApiHook apiHook({String environment}) {
    return ((environments != null) && (environment != null)) ? environments[environment] : null;
  }

  bool hasEnvironment(String environment) {
    return (apiHook(environment: environment) != null);
  }

  String get defaultEnvironment {
    if (environments != null) {

      for (String environment in environments.keys) {
        if (environments[environment].isDefault == true) {
          return environment;
        }
      }
      
      if (kReleaseMode && environments['production'] != null) {
        return 'production';
      }
      else if (!kReleaseMode && environments['dev'] != null) {
        return 'dev';
      }
    }

    return null;
  }

  static List<Organization> listFromJson(List<dynamic> json) {
    List<Organization> values;
    if (json != null) {
      values = <Organization>[];
      for (dynamic entry in json) {
        try { values.add(Organization.fromJson((entry as Map)?.cast<String, dynamic>())); }
        catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static Organization findInList(List<Organization> organizations, { String organizationId, bool isDefault }) {
    if (organizations != null) {
      for (Organization organization in organizations) {
        if (((organizationId != null) && (organization.id == organizationId)) ||
            ((isDefault != null) && (organization.isDefault == isDefault))) {
          return organization;
        }
      }
    }
    return null;
  }
}

class ApiHook {
  final String url;
  final String apiKey;
  final dynamic _isDefault;

  ApiHook({this.url, this.apiKey, dynamic isDefault}) :
    _isDefault = isDefault;

  factory ApiHook.fromJson(Map<String, dynamic> json) {
    return (json != null) ? ApiHook(
      url: json['url'],
      apiKey: json['api_key'],
      isDefault: json['default'],
    ) : null;
  }

  dynamic toJson() {
    return {
      'url': url,
      'api_key': apiKey,
      'default': _isDefault,
    };
  }

  bool get isDefault {
    return _parseDefault(_isDefault);
  }

  static Map<String, ApiHook> mapFromJson(Map<String, dynamic> json) {
    Map<String, ApiHook> result;
    if (json != null) {
      result = Map<String, ApiHook>();
      json.forEach((String key, dynamic value) {
        result[key] = ApiHook.fromJson(value);
      });
    }
    return result;
  }

  static dynamic mapToJson(Map<String, ApiHook> map) {
    Map<String, dynamic> result;
    if (map != null) {
      result = Map<String, dynamic>();
      map.forEach((String key, ApiHook value) {
        result[key] = value.toJson();
      });
    }
    return result;
  }
}

bool _parseDefault(dynamic value) {
    if (value is bool) {
      return value;
    }
    else if (value is String) {
      if (value == 'release') {
        return kReleaseMode;
      }
      else if (value == 'debug') {
        return !kReleaseMode;
      }
      else if (value == 'true') {
        return true;
      }
      else if (value == 'false') {
        return false;
      }
    }
    return null;
}