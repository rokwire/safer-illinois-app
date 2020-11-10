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

import 'package:illinois/service/Service.dart';
// import 'package:firebase_core/firebase_core.dart' as GoogleFirebase;

//TBD: DD - web
class FirebaseService extends Service{
  static final FirebaseService _instance = new FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }
  FirebaseService._internal();


  @override
  Future<void> initService() async{
    await super.initService();

    // await GoogleFirebase.Firebase.initializeApp();
  }
}