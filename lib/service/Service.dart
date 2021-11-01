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


import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Connectivity.dart';
import 'package:illinois/service/FirebaseService.dart';
import 'package:illinois/service/FirebaseCrashlytics.dart';
import 'package:illinois/service/DeepLink.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/FlexUI.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/HttpProxy.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/LocationServices.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/OSFHealth.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Organizations.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/service/UserProfile.dart';

abstract class Service {
  
  void createService() {
  }

  void destroyService() {
  }

  Future<void> initService() async {
  }

  void initServiceUI() {
  }

  Future<void> clearService() async {
  }

  Set<Service> get serviceDependsOn {
    return null;
  }
}

class Services {
  static final Services _instance = Services._internal();
  
  factory Services() {
    return _instance;
  }

  Services._internal();
  
  static Services get instance {
    return _instance;
  }

  List<Service> _services = [
    // Add highest priority services at top
    FirebaseService(),
    FirebaseCrashlytics(),
    Storage(),
    Organizations(),
    Config(),
    HttpProxy(),

    AppLivecycle(),
    Connectivity(),
    LocationServices(),
    NativeCommunicator(),
    DeepLink(),

    Localization(),
    Styles(),

    Auth(),
    UserProfile(),
    Analytics(),
    FirebaseMessaging(),
    Health(),
    OSFHealth(),
    
    FlexUI(),
    Onboarding(),

    // These do not rely on Service initialization API so they are not registered as services.
    // ...
  ];

  void create() {
    _sort();
    for (Service service in _services) {
      service.createService();
    }
  }

  void destroy() {
    for (Service service in _services) {
      service.destroyService();
    }
  }

  Future<void> init() async {
    for (Service service in _services) {
      await service.initService();
    }
  }

  void initUI() {
    for (Service service in _services) {
      service.initServiceUI();
    }
  }

  Future<void> clear() async {
    for (Service service in _services) {
      await service.clearService();
    }
  }

  void _sort() {
    
    List<Service> queue = <Service>[];
    while (_services.isNotEmpty) {
      // start with lowest priority service
      Service svc = _services.last;
      _services.removeLast();
      
      // Move to TBD anyone from Queue that depends on svc
      Set<Service> svcDependents = svc.serviceDependsOn;
      if (svcDependents != null) {
        for (int index = queue.length - 1; index >= 0; index--) {
          Service queuedSvc = queue[index];
          if (svcDependents.contains(queuedSvc)) {
            queue.removeAt(index);
            _services.add(queuedSvc);
          }
        }
      }

      // Move svc from TBD to Queue, mark it as processed
      queue.add(svc);
    }
    
    _services = queue.reversed.toList();
  }

}

