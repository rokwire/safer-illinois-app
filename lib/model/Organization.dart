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
  final Map<String, UrlEntryPoint> environments;

  Organization({this.id, this.name, this.iconUrl, this.environments});

  factory Organization.fromJson(Map<String, dynamic> json) {
    return (json != null) ? Organization(
      id: json['id'],
      name: json['name'],
      iconUrl: json['icon_url'],
      environments: UrlEntryPoint.mapFromJson(json['environments']),
    ) : null;
  }

  dynamic toJson() {
    return {
      'id': id,
      'name': name,
      'icon_url': iconUrl,
      'environments': UrlEntryPoint.mapToJson(environments)
    };
  }

  UrlEntryPoint entryPoint({String environment}) {
    return ((environments != null) && (environment != null)) ? environments[environment] : null;
  }

  bool hasEnvironment(String environment) {
    return (entryPoint(environment: environment) != null);
  }

  String get defaultEnvironment {
    if (environments != null) {

      for (String environment in environments.keys) {
        if (environments[environment].isDefault) {
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
}

class UrlEntryPoint {
  final String url;
  final String apiKey;
  final dynamic _isDefault;

  UrlEntryPoint({this.url, this.apiKey, dynamic isDefault}) :
    _isDefault = isDefault;

  factory UrlEntryPoint.fromJson(Map<String, dynamic> json) {
    return (json != null) ? UrlEntryPoint(
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
    if (_isDefault is bool) {
      return _isDefault;
    }
    else if (_isDefault is String) {
      if (_isDefault == 'release') {
        return kReleaseMode;
      }
      else if (_isDefault == 'debug') {
        return !kReleaseMode;
      }
      else if (_isDefault == 'true') {
        return true;
      }
      else if (_isDefault == 'false') {
        return false;
      }
    }
    return null;
  }

  static Map<String, UrlEntryPoint> mapFromJson(Map<String, dynamic> json) {
    Map<String, UrlEntryPoint> result;
    if (json != null) {
      result = Map<String, UrlEntryPoint>();
      json.forEach((String key, dynamic value) {
        result[key] = UrlEntryPoint.fromJson(value);
      });
    }
    return result;
  }

  static dynamic mapToJson(Map<String, UrlEntryPoint> map) {
    Map<String, dynamic> result;
    if (map != null) {
      result = Map<String, dynamic>();
      map.forEach((String key, UrlEntryPoint value) {
        result[key] = value.toJson();
      });
    }
    return result;
  }
}